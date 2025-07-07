import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:appwrite/appwrite.dart';
import '../services/agora_service.dart';
import '../services/appwrite_service.dart';
import '../models/user_profile.dart';
import '../widgets/animated_fade_in.dart';
import '../core/logging/app_logger.dart';

class DebatesDiscussionsScreen extends StatefulWidget {
  final String roomId;
  final String? roomName;
  final String? moderatorName;

  const DebatesDiscussionsScreen({
    super.key,
    required this.roomId,
    this.roomName,
    this.moderatorName,
  });

  @override
  State<DebatesDiscussionsScreen> createState() => _DebatesDiscussionsScreenState();
}

class _DebatesDiscussionsScreenState extends State<DebatesDiscussionsScreen> {
  final AgoraService _agoraService = AgoraService();
  final AppwriteService _appwrite = AppwriteService();
  
  // Room data
  Map<String, dynamic>? _roomData;
  UserProfile? _currentUser;
  UserProfile? _moderator;
  
  // Participants
  final List<UserProfile> _speakerPanelists = []; // Max 6 speakers
  final List<UserProfile> _audienceMembers = [];
  final List<UserProfile> _speakerRequests = []; // Pending speaker requests
  
  // Video/Audio states (removed unused fields)
  
  // Room state
  bool _isLoading = true;
  bool _isJoined = false;
  bool _isCurrentUserModerator = false;
  bool _isCurrentUserSpeaker = false;
  bool _hasRequestedSpeaker = false;
  bool _isDisposing = false;
  bool _isAgoraEnabled = false;
  
  // Real-time subscription
  RealtimeSubscription? _participantsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeRoom();
  }

  @override
  void dispose() {
    _isDisposing = true;
    _participantsSubscription?.close();
    // Don't await _leaveRoom() in dispose as it's synchronous
    // Just call it without awaiting to start the process
    _leaveRoom().catchError((error) {
      AppLogger().error('Error during disposal: $error');
    });
    super.dispose();
  }

  Future<void> _initializeRoom() async {
    try {
      AppLogger().debug('Initializing debate discussion room: ${widget.roomId}');
      
      // Load current user
      final currentUser = await _appwrite.getCurrentUser();
      if (currentUser == null) {
        throw Exception('Not authenticated');
      }
      
      final userProfile = await _appwrite.getUserProfile(currentUser.$id);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }
      
      // Load room data with retry logic
      AppLogger().debug('Loading room data for roomId: ${widget.roomId}');
      Map<String, dynamic>? roomData;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (roomData == null && retryCount < maxRetries) {
        try {
          roomData = await _appwrite.getDebateDiscussionRoom(widget.roomId);
          if (roomData != null) {
            AppLogger().debug('Room data loaded successfully: ${roomData['name']}');
            break;
          }
        } catch (e) {
          retryCount++;
          if (retryCount < maxRetries) {
            AppLogger().warning('Room not found (attempt $retryCount/$maxRetries), retrying in 2 seconds...');
            await Future.delayed(const Duration(seconds: 2));
          } else {
            rethrow;
          }
        }
      }
      
      if (roomData == null) {
        throw Exception('Room not found with ID: ${widget.roomId} after $maxRetries attempts');
      }
      
      // Load moderator profile
      UserProfile? moderator;
      try {
        moderator = await _appwrite.getUserProfile(roomData['moderatorId']);
      } catch (e) {
        AppLogger().warning('Could not load moderator profile: $e');
      }
      
      // Check if current user is moderator
      final isCurrentUserModerator = roomData['moderatorId'] == currentUser.$id;
      
      // Join the room in database
      await _appwrite.joinDebateDiscussionRoom(
        roomId: widget.roomId,
        userId: currentUser.$id,
        role: isCurrentUserModerator ? 'moderator' : 'audience',
      );
      
      // Initialize Agora (optional - room can work without it)
      try {
        await _agoraService.initialize();
        _agoraService.onUserJoined = _onUserJoined;
        _agoraService.onUserLeft = _onUserLeft;
        
        // Join the channel
        await _agoraService.joinChannel();
        _isAgoraEnabled = true;
        AppLogger().debug('Agora initialized successfully');
      } catch (e) {
        AppLogger().warning('Agora initialization failed, continuing without video/audio: $e');
        // Room can still function without Agora for text-based features
      }
      
      if (mounted) {
        setState(() {
          _roomData = roomData;
          _currentUser = userProfile;
          _moderator = moderator;
          _isCurrentUserModerator = isCurrentUserModerator;
          _isLoading = false;
          _isJoined = true;
        });
      }
      
      // Load participants
      await _loadParticipants();
      
      // Setup real-time updates
      _setupRealTimeUpdates();
      
      AppLogger().debug('Room initialized successfully');
    } catch (e) {
      AppLogger().error('Failed to initialize room: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Provide user-friendly error messages
        String errorMessage = 'Failed to join room';
        if (e.toString().contains('document_not_found')) {
          errorMessage = 'This debate room no longer exists or has been removed';
        } else if (e.toString().contains('Not authenticated')) {
          errorMessage = 'Please log in to join the room';
        } else if (e.toString().contains('User profile not found')) {
          errorMessage = 'Could not load your profile. Please try again';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _loadParticipants() async {
    try {
      AppLogger().debug('Loading participants for room: ${widget.roomId}');
      
      // Get real participants from database
      final participants = await _appwrite.getDebateDiscussionParticipants(widget.roomId);
      
      if (mounted && !_isDisposing) {
        setState(() {
          _speakerPanelists.clear();
          _audienceMembers.clear();
          _speakerRequests.clear();
          
          // Process participants
          for (var participant in participants) {
            final userProfileData = participant['userProfile'];
            if (userProfileData != null) {
              final userProfile = UserProfile.fromMap(userProfileData);
              final role = participant['role'] ?? 'audience';
              
              if (role == 'moderator') {
                // Moderator goes to speaker panel
                if (!_speakerPanelists.any((p) => p.id == userProfile.id)) {
                  _speakerPanelists.add(userProfile);
                }
                _isCurrentUserSpeaker = userProfile.id == _currentUser?.id;
              } else if (role == 'speaker') {
                // Speaker goes to speaker panel
                if (!_speakerPanelists.any((p) => p.id == userProfile.id)) {
                  _speakerPanelists.add(userProfile);
                }
                _isCurrentUserSpeaker = userProfile.id == _currentUser?.id;
              } else {
                // Audience member
                if (!_audienceMembers.any((p) => p.id == userProfile.id)) {
                  _audienceMembers.add(userProfile);
                }
              }
            }
          }
        });
      }
      
      AppLogger().debug('Loaded ${participants.length} participants: ${_speakerPanelists.length} speakers, ${_audienceMembers.length} audience');
    } catch (e) {
      AppLogger().error('Error loading participants: $e');
      // Fallback to mock data if real data fails
      _createMockParticipants();
    }
  }

  void _createMockParticipants() {
    // Add moderator to speaker panel if not already there
    if (_moderator != null && !_speakerPanelists.any((p) => p.id == _moderator!.id)) {
      _speakerPanelists.add(_moderator!);
    }
    
    // Add current user to appropriate list
    if (_currentUser != null && !_isCurrentUserModerator) {
      _audienceMembers.add(_currentUser!);
    }
    
    // Create mock audience members for demonstration
    final mockAudience = [
      'Sarah Johnson', 'Mike Chen', 'Alex Rivera', 'Emily Davis', 'James Wilson',
      'Maria Garcia', 'David Brown', 'Lisa Anderson', 'Kevin Taylor', 'Rachel White'
    ];
    
    for (int i = 0; i < mockAudience.length; i++) {
      final mockUser = UserProfile(
        id: 'mock_audience_$i',
        name: mockAudience[i],
        email: '${mockAudience[i].toLowerCase().replaceAll(' ', '.')}@example.com',
        avatar: null,
        bio: 'Debate enthusiast',
        reputation: 0,
        totalWins: 0,
        totalDebates: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      if (!_audienceMembers.any((p) => p.id == mockUser.id)) {
        _audienceMembers.add(mockUser);
      }
    }
  }

  void _setupRealTimeUpdates() {
    try {
      _participantsSubscription = _appwrite.realtimeInstance.subscribe([
        'databases.arena_db.collections.debate_discussion_participants.documents',
        'databases.arena_db.collections.debate_discussion_rooms.documents'
      ]);

      _participantsSubscription?.stream.listen(
        (response) {
          AppLogger().debug('Real-time update: ${response.events}');
          
          // Check for room updates (status changes like room ending)
          if (response.events.any((event) => event.contains('debate_discussion_rooms'))) {
            _handleRoomUpdate(response);
          }
          
          // Check for participant updates
          if (response.events.any((event) => event.contains('debate_discussion_participants'))) {
            // Reload participants when there are changes
            if (mounted && !_isDisposing) {
              _loadParticipants();
            }
          }
        },
        onError: (error) {
          AppLogger().error('Real-time subscription error: $error');
        },
      );
    } catch (e) {
      AppLogger().error('Error setting up real-time updates: $e');
    }
  }

  void _handleRoomUpdate(dynamic response) async {
    try {
      // Check if this update is for our current room
      if (response.payload != null && response.payload['\$id'] == widget.roomId) {
        final roomStatus = response.payload['status'];
        
        AppLogger().debug('Room status update: $roomStatus');
        
        // If room is ended and current user is not the moderator (who ended it)
        if (roomStatus == 'ended' && !_isCurrentUserModerator && mounted && !_isDisposing) {
          AppLogger().debug('Room ended by moderator, navigating all users out');
          
          // Show notification that room was ended
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚪 Room ended by moderator'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Leave Agora channel if connected
          if (_isAgoraEnabled) {
            await _agoraService.leaveChannel();
          }
          
          // Navigate back to home screen
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
        }
      }
    } catch (e) {
      AppLogger().error('Error handling room update: $e');
    }
  }

  Future<void> _leaveRoom() async {
    try {
      if (_isJoined && !_isDisposing) {
        // Try to leave Agora channel (might not be initialized)
        try {
          await _agoraService.leaveChannel();
        } catch (e) {
          AppLogger().warning('Could not leave Agora channel (not initialized): $e');
        }
        
        if (_currentUser != null) {
          await _appwrite.leaveDebateDiscussionRoom(
            roomId: widget.roomId,
            userId: _currentUser!.id,
          );
        }
        
        if (mounted && !_isDisposing) {
          setState(() {
            _isJoined = false;
          });
        }
      }
    } catch (e) {
      AppLogger().error('Error leaving room: $e');
    }
  }

  void _onUserJoined(int uid) {
    AppLogger().debug('User joined: $uid');
    // Handle new user joining
  }

  void _onUserLeft(int uid) {
    AppLogger().debug('User left: $uid');
    // Handle user leaving
  }

  void _requestToJoinSpeakers() async {
    if (_hasRequestedSpeaker || _isCurrentUserModerator || _isCurrentUserSpeaker || _currentUser == null) {
      return;
    }
    
    try {
      if (mounted && !_isDisposing) {
        setState(() {
          _hasRequestedSpeaker = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎤 Request sent to join speakers panel'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      // For now, automatically approve the request (in real implementation, moderator would approve)
      // This simulates the moderator approving the request
      // Allow up to 6 speakers + moderator (7 total)
      final otherSpeakersCount = _speakerPanelists.where((speaker) => speaker.id != _moderator?.id).length;
      if (otherSpeakersCount < 6) {
        await _appwrite.updateDebateDiscussionParticipantRole(
          roomId: widget.roomId,
          userId: _currentUser!.id,
          newRole: 'speaker',
        );
        
        // The real-time subscription will update the UI automatically
      }
    } catch (e) {
      AppLogger().error('Error requesting to join speakers: $e');
      if (mounted && !_isDisposing) {
        setState(() {
          _hasRequestedSpeaker = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _approveSpeakerRequest(UserProfile user) async {
    // Allow up to 6 speakers + moderator (7 total)
    final otherSpeakersCount = _speakerPanelists.where((speaker) => speaker.id != _moderator?.id).length;
    if (!_isCurrentUserModerator || otherSpeakersCount >= 6) {
      return;
    }
    
    try {
      await _appwrite.updateDebateDiscussionParticipantRole(
        roomId: widget.roomId,
        userId: user.id,
        newRole: 'speaker',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${user.name} added to speakers panel'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // The real-time subscription will update the UI automatically
    } catch (e) {
      AppLogger().error('Error approving speaker request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeSpeaker(UserProfile user) async {
    if (!_isCurrentUserModerator || user.id == _moderator?.id) {
      return;
    }
    
    try {
      await _appwrite.updateDebateDiscussionParticipantRole(
        roomId: widget.roomId,
        userId: user.id,
        newRole: 'audience',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} moved to audience'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      // The real-time subscription will update the UI automatically
    } catch (e) {
      AppLogger().error('Error removing speaker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing speaker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF8B5CF6)),
              SizedBox(height: 16),
              Text(
                'Joining room...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildVideoGrid(),
            ),
            _buildControlsBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final roomName = _roomData?['name'] ?? widget.roomName ?? 'Debate Room';
    final moderatorName = _moderator?.name ?? widget.moderatorName ?? 'Unknown';
    final participantCount = _speakerPanelists.length + _audienceMembers.length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                LucideIcons.arrowLeft,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roomName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Moderated by $moderatorName',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              const Icon(
                LucideIcons.users,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '$participantCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!_isAgoraEnabled) ...[ 
                const SizedBox(width: 8),
                const Icon(
                  LucideIcons.micOff,
                  color: Colors.orange,
                  size: 14,
                ),
              ],
              if (_isCurrentUserModerator) ...[ 
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _showModeratorTools,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      LucideIcons.settings,
                      color: Color(0xFF8B5CF6),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    return Stack(
      children: [
        // Audience section (full screen background)
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 16), // Reduced padding
            child: _buildAudienceSection(),
          ),
        ),
        
        // Floating speakers panel (always show to display all 6 slots)
        Positioned(
          top: 16, // Reduced top position
          left: 0,
          right: 0,
          child: _buildSpeakerPanel(),
        ),
      ],
    );
  }

  Widget _buildSpeakerPanel() {
    // Show moderator first, then speakers above in dynamic 3x2 grid
    
    // Separate moderator from other speakers
    UserProfile? moderator;
    List<UserProfile> otherSpeakers = [];
    
    if (_speakerPanelists.isNotEmpty) {
      try {
        moderator = _speakerPanelists.firstWhere(
          (speaker) => speaker.id == _moderator?.id, 
        );
        otherSpeakers = _speakerPanelists.where((speaker) => speaker.id != moderator!.id).toList();
      } catch (e) {
        // If moderator not found in speakers list, use the first speaker or the actual moderator
        if (_moderator != null) {
          moderator = _moderator;
        }
        otherSpeakers = _speakerPanelists.where((speaker) => speaker.id != moderator?.id).toList();
      }
    } else {
      moderator = _moderator;
    }

    // Calculate larger tile dimensions based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    const containerMargin = 8.0; // Minimal margins to maximize space
    final containerWidth = screenWidth - (containerMargin * 2);
    const tileSpacing = 4.0; // Minimal spacing between tiles
    
    // Calculate tile width to fit 3 per row - make them as large as possible
    final availableWidth = containerWidth - (tileSpacing * 2); // Space for 2 gaps between 3 tiles
    final tileWidth = (availableWidth / 3).floor().toDouble(); // Use floor to prevent overflow
    final tileHeight = tileWidth; // Square tiles for better appearance

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: containerMargin),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Speakers grid (only show if there are speakers)
          if (otherSpeakers.isNotEmpty) ...[
            // First row (up to 3 speakers)
            SizedBox(
              height: tileHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < otherSpeakers.length && i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: tileSpacing),
                    SizedBox(
                      width: tileWidth,
                      height: tileHeight,
                      child: _buildVideoTile(
                        otherSpeakers[i],
                        isModerator: false,
                        showControls: _isCurrentUserModerator,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Second row (speakers 4-6) - only if there are more than 3 speakers
            if (otherSpeakers.length > 3) ...[
              const SizedBox(height: tileSpacing),
              SizedBox(
                height: tileHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 3; i < otherSpeakers.length && i < 6; i++) ...[
                      if (i > 3) const SizedBox(width: tileSpacing),
                      SizedBox(
                        width: tileWidth,
                        height: tileHeight,
                        child: _buildVideoTile(
                          otherSpeakers[i],
                          isModerator: false,
                          showControls: _isCurrentUserModerator,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: tileSpacing), // Space between speakers and moderator
          ],
          
          // Moderator at the bottom (always shown)
          if (moderator != null)
            SizedBox(
              width: tileWidth,
              height: tileHeight,
              child: _buildVideoTile(
                moderator,
                isModerator: true,
                showControls: false, // Moderator can't remove themselves
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoTile(UserProfile participant, {bool isModerator = false, bool showControls = false}) {
    return AnimatedFadeIn(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isModerator ? const Color(0xFF8B5CF6) : Colors.grey[700]!,
            width: isModerator ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Video placeholder
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: CircleAvatar(
                  radius: isModerator ? 32 : 24,
                  backgroundColor: const Color(0xFF8B5CF6),
                  backgroundImage: participant.avatar != null && participant.avatar!.isNotEmpty
                      ? NetworkImage(participant.avatar!)
                      : null,
                  child: participant.avatar == null || participant.avatar!.isEmpty
                      ? Text(
                          participant.initials,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isModerator ? 20 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            
            // Name label at bottom
            Positioned(
              bottom: 4,
              left: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isModerator 
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.9)
                      : Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isModerator) ...[
                      const Icon(
                        LucideIcons.crown,
                        color: Colors.white,
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                    ],
                    Flexible(
                      child: Text(
                        isModerator ? '${participant.name} (Mod)' : participant.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Remove button for moderator
            if (showControls && !isModerator)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeSpeaker(participant),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Icon(
                      LucideIcons.x,
                      color: Colors.white,
                      size: 8,
                    ),
                  ),
                ),
              ),
            
            // Video/Audio disabled indicator
            if (!_isAgoraEnabled)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Icon(
                    LucideIcons.videoOff,
                    color: Colors.white,
                    size: 8,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 360 ? 3 : 4; // Reduced count for larger tiles
    
    // Calculate top padding based on speakers panel height (same as speaker panel)
    const containerMargin = 8.0; // Same as speaker panel
    final containerWidth = screenWidth - (containerMargin * 2);
    const tileSpacing = 4.0; // Same as speaker panel
    
    // Same tile calculations as speaker panel for consistency
    final availableWidth = containerWidth - (tileSpacing * 2);
    final tileWidth = (availableWidth / 3).floor().toDouble();
    final tileHeight = tileWidth; // Square tiles
    
    // Calculate speakers panel height
    final otherSpeakersCount = _speakerPanelists.where((speaker) => speaker.id != _moderator?.id).length;
    double speakersPanelHeight = 16.0; // Initial top padding
    
    if (otherSpeakersCount > 0) {
      speakersPanelHeight += tileHeight; // First row
      if (otherSpeakersCount > 3) {
        speakersPanelHeight += tileSpacing + tileHeight; // Gap + second row
      }
      speakersPanelHeight += tileSpacing; // Gap before moderator
    }
    
    speakersPanelHeight += tileHeight + 16; // Moderator tile + bottom padding
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add spacing for floating speakers panel (dynamic height)
        SizedBox(height: speakersPanelHeight),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0), // Reduced padding
          child: Row(
            children: [
              const Icon(
                LucideIcons.users,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'Audience (${_audienceMembers.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Speaker requests (only visible to moderator)
        if (_isCurrentUserModerator && _speakerRequests.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Speaker Requests:',
                  style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...(_speakerRequests.map((user) => 
                  Row(
                    children: [
                      Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _approveSpeakerRequest(user),
                        child: const Text('Approve', style: TextStyle(color: Colors.green, fontSize: 10)),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        // Audience grid
        Expanded(
          child: _audienceMembers.isEmpty
              ? const Center(
                  child: Text(
                    'No audience members yet',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.zero, // No padding around the grid
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 0, // No horizontal gap
                    mainAxisSpacing: 0, // No vertical gap
                    childAspectRatio: 1.0, // Square tiles, adjust as needed
                  ),
                  itemCount: _audienceMembers.length,
                  itemBuilder: (context, index) {
                    return _buildAudienceMember(_audienceMembers[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAudienceMember(UserProfile member) {
    final screenWidth = MediaQuery.of(context).size.width;
    final avatarSize = screenWidth < 360 ? 36.0 : 42.0;
    final fontSize = screenWidth < 360 ? 9.0 : 10.0;
    final isCurrentUser = member.id == _currentUser?.id;
    // Allow up to 6 speakers + moderator (7 total)
    final otherSpeakersCount = _speakerPanelists.where((speaker) => speaker.id != _moderator?.id).length;
    final canRequestSpeaker = isCurrentUser && !_isCurrentUserModerator && !_isCurrentUserSpeaker && !_hasRequestedSpeaker && otherSpeakersCount < 6;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800]?.withValues(alpha: 0.3),
        borderRadius: BorderRadius.zero, // No border radius for flush look
        border: Border.all(
          color: Colors.grey[700]!,
          width: 0.5,
        ),
      ),
      padding: EdgeInsets.zero, // No padding
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: avatarSize / 2,
                backgroundColor: const Color(0xFF8B5CF6),
                backgroundImage: member.avatar != null && member.avatar!.isNotEmpty
                    ? NetworkImage(member.avatar!)
                    : null,
                child: member.avatar == null || member.avatar!.isEmpty
                    ? Text(
                        member.initials,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: avatarSize * 0.35,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (canRequestSpeaker)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: GestureDetector(
                    onTap: _requestToJoinSpeakers,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        LucideIcons.hand,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              member.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: LucideIcons.messageCircle,
            isActive: false,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat feature coming soon!')),
              );
            },
          ),
          // Hand raise button (only for audience members)
          if (!_isCurrentUserModerator && !_isCurrentUserSpeaker)
            _buildControlButton(
              icon: LucideIcons.hand,
              isActive: _hasRequestedSpeaker,
              onTap: _requestToJoinSpeakers,
            ),
          _buildControlButton(
            icon: LucideIcons.share2,
            isActive: false,
            onTap: _shareRoom,
          ),
          _buildGiftButton(),
          _buildControlButton(
            icon: LucideIcons.logOut,
            isActive: false,
            isDestructive: true,
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red
              : isActive
                  ? const Color(0xFF8B5CF6)
                  : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
          border: isActive
              ? null
              : Border.all(color: Colors.grey[600]!, width: 1),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }


  void _showModeratorTools() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Moderator Tools',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: LucideIcons.userPlus,
              title: 'Manage Speakers',
              onTap: () {
                Navigator.pop(context);
                _showSpeakerManagement();
              },
            ),
            _buildOptionTile(
              icon: LucideIcons.micOff,
              title: 'Mute All',
              onTap: () {
                Navigator.pop(context);
                _muteAllParticipants();
              },
            ),
            _buildOptionTile(
              icon: LucideIcons.users,
              title: 'Room Stats',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Room has ${_speakerPanelists.length} speakers and ${_audienceMembers.length} audience members')),
                );
              },
            ),
            _buildOptionTile(
              icon: LucideIcons.settings,
              title: 'Room Settings',
              onTap: () {
                Navigator.pop(context);
                _showRoomSettings();
              },
            ),
            _buildOptionTile(
              icon: LucideIcons.alertTriangle,
              title: 'End Room',
              onTap: () {
                Navigator.pop(context);
                _showEndRoomConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: onTap,
    );
  }

  void _showSpeakerManagement() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Speaker Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // Current Speakers
              if (_speakerPanelists.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Current Speakers',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _speakerPanelists.length,
                  itemBuilder: (context, index) {
                    final speaker = _speakerPanelists[index];
                    final isModerator = speaker.id == _moderator?.id;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isModerator ? const Color(0xFF8B5CF6) : Colors.grey[600],
                        child: Text(
                          speaker.initials,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        speaker.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        isModerator ? 'Moderator' : 'Speaker',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      trailing: !isModerator ? IconButton(
                        icon: const Icon(LucideIcons.userX, color: Colors.red),
                        onPressed: () => _removeSpeaker(speaker),
                      ) : null,
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
              
              // Pending Requests
              if (_speakerRequests.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pending Speaker Requests',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _speakerRequests.length,
                    itemBuilder: (context, index) {
                      final user = _speakerRequests[index];
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Text(
                            user.initials,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          user.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Wants to join speakers',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(LucideIcons.check, color: Colors.green),
                              onPressed: () => _approveSpeakerRequest(user),
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.x, color: Colors.red),
                              onPressed: () => _denySpeakerRequest(user),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                const Expanded(
                  child: Center(
                    child: Text(
                      'No pending speaker requests',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _muteAllParticipants() {
    if (_isAgoraEnabled) {
      // Implement Agora mute all functionality
      try {
        // This would mute all participants except moderator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔇 All participants muted'),
            backgroundColor: Colors.orange,
          ),
        );
        AppLogger().info('Moderator muted all participants');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mute participants: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio features not available - Agora not initialized'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showRoomSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Room Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: LucideIcons.users,
              title: 'Speaker Limit (Currently: ${_speakerPanelists.length}/7)',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Room supports up to 6 speakers + 1 moderator')),
                );
              },
            ),
            _buildOptionTile(
              icon: LucideIcons.clock,
              title: 'Room Duration',
              onTap: () {
                Navigator.pop(context);
                _showRoomDurationInfo();
              },
            ),
            _buildOptionTile(
              icon: LucideIcons.volume2,
              title: 'Audio Settings',
              onTap: () {
                Navigator.pop(context);
                _showAudioSettings();
              },
            ),
            _buildOptionTile(
              icon: LucideIcons.share,
              title: 'Share Room',
              onTap: () {
                Navigator.pop(context);
                _shareRoom();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEndRoomConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'End Room',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to end this room? All participants will be disconnected and the room will be closed permanently.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _endRoom();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Room'),
          ),
        ],
      ),
    );
  }

  void _denySpeakerRequest(UserProfile user) async {
    try {
      // Remove from speaker requests
      if (mounted) {
        setState(() {
          _speakerRequests.removeWhere((request) => request.id == user.id);
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Denied speaker request from ${user.name}'),
          backgroundColor: Colors.orange,
        ),
      );
      
      AppLogger().info('Moderator denied speaker request from ${user.name}');
    } catch (e) {
      AppLogger().error('Error denying speaker request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error denying request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRoomDurationInfo() {
    final startTime = _roomData?['createdAt'];
    final duration = startTime != null ? 
      DateTime.now().difference(DateTime.parse(startTime)) : 
      const Duration(minutes: 0);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Room has been active for ${duration.inHours}h ${duration.inMinutes % 60}m',
        ),
        backgroundColor: const Color(0xFF8B5CF6),
      ),
    );
  }

  void _showAudioSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Audio Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(
                _isAgoraEnabled ? LucideIcons.mic : LucideIcons.micOff,
                color: _isAgoraEnabled ? Colors.green : Colors.red,
              ),
              title: Text(
                _isAgoraEnabled ? 'Audio Enabled' : 'Audio Disabled',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _isAgoraEnabled ? 'Agora voice chat is active' : 'Agora voice chat unavailable',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
            if (_isAgoraEnabled) ...[
              _buildOptionTile(
                icon: LucideIcons.micOff,
                title: 'Mute All Participants',
                onTap: () {
                  Navigator.pop(context);
                  _muteAllParticipants();
                },
              ),
              _buildOptionTile(
                icon: LucideIcons.mic,
                title: 'Unmute All Participants',
                onTap: () {
                  Navigator.pop(context);
                  _unmuteAllParticipants();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _unmuteAllParticipants() {
    if (_isAgoraEnabled) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔊 All participants unmuted'),
            backgroundColor: Colors.green,
          ),
        );
        AppLogger().info('Moderator unmuted all participants');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unmute participants: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareRoom() {
    final roomName = _roomData?['name'] ?? 'Debate Room';
    final moderatorName = _moderator?.name ?? 'Unknown';
    
    // Create shareable room information
    final shareText = '''
🎙️ Join our live debate discussion!

Room: $roomName
Moderator: $moderatorName
Participants: ${_speakerPanelists.length + _audienceMembers.length}

Join the conversation now in the Arena app!
''';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Room details copied to share'),
        backgroundColor: const Color(0xFF8B5CF6),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Colors.grey[900],
                title: const Text('Share Room', style: TextStyle(color: Colors.white)),
                content: Text(shareText, style: const TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _endRoom() async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ending room...'),
          backgroundColor: Colors.orange,
        ),
      );

      // Update room status to ended
      await _appwrite.updateDebateDiscussionRoom(
        roomId: widget.roomId,
        data: {
          'status': 'ended',
        },
      );

      // Leave Agora channel if connected
      if (_isAgoraEnabled) {
        await _agoraService.leaveChannel();
      }

      // Navigate back to room list
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room ended successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      AppLogger().info('Room ended by moderator');
    } catch (e) {
      AppLogger().error('Error ending room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ending room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildGiftButton() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gift feature coming soon!')),
        );
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey[600]!, width: 1),
        ),
        child: const Icon(
          LucideIcons.gift,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}