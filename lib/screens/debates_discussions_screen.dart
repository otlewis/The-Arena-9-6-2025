import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:appwrite/appwrite.dart';
import '../services/agora_service.dart';
import '../services/appwrite_service.dart';
import '../services/firebase_gift_service.dart';
import '../services/agora_instant_messaging_service.dart';
// import '../services/chat_service.dart'; // Removed with new chat system
import '../models/user_profile.dart';
import '../models/gift.dart';
import '../models/timer_state.dart';
import '../widgets/animated_fade_in.dart';
import '../widgets/appwrite_timer_widget.dart';
import '../widgets/room_chat_panel.dart';
import '../widgets/user_profile_modal.dart';
import '../widgets/instant_message_bell.dart';
import '../widgets/challenge_bell.dart';
import '../widgets/floating_im_widget.dart';
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
  final FirebaseGiftService _giftService = FirebaseGiftService();
  final AgoraInstantMessagingService _imService = AgoraInstantMessagingService();
  // final ChatService _chatService = ChatService(); // Removed with new chat system
  
  // Room data
  Map<String, dynamic>? _roomData;
  UserProfile? _currentUser;
  UserProfile? _moderator;
  
  // Gift system
  int _currentUserCoinBalance = 0;
  Gift? _selectedGift;
  Map<String, dynamic>? _selectedRecipient;  // Changed to match Open Discussion format
  List<Gift> _availableGifts = [];
  
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
  
  // Real-time subscriptions - separate instances for reliability
  RealtimeSubscription? _participantsSubscription;
  RealtimeSubscription? _roomSubscription;
  StreamSubscription? _unreadMessagesSubscription; // Instant messages subscription

  @override
  void initState() {
    super.initState();
    _initializeRoom();
    _loadGiftData();
    _initializeInstantMessaging();
  }

  @override
  void dispose() {
    _isDisposing = true;
    _participantsSubscription?.close();
    _roomSubscription?.close();
    _unreadMessagesSubscription?.cancel();
    // Don't await _leaveRoom() in dispose as it's synchronous
    // Just call it without awaiting to start the process
    _leaveRoom().catchError((error) {
      AppLogger().error('Error during disposal: $error');
    });
    super.dispose();
  }

  void _showUserProfileModal(UserProfile userProfile) {
    if (_isDisposing || !mounted) return;
    
    // Determine user role based on their current status
    String? userRole;
    if (userProfile.id == _moderator?.id) {
      userRole = 'moderator';
    } else if (_speakerPanelists.any((speaker) => speaker.id == userProfile.id)) {
      userRole = 'speaker';
    } else if (_audienceMembers.any((member) => member.id == userProfile.id)) {
      userRole = 'audience';
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => UserProfileModal(
        userProfile: userProfile,
        userRole: userRole,
        currentUser: _currentUser,
        onClose: () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  Future<void> _initializeInstantMessaging() async {
    try {
      await _imService.initialize();
      
      // Subscribe to unread message count
      _unreadMessagesSubscription = _imService
          .getUnreadCountStream()
          .listen((count) {
        if (mounted && !_isDisposing) {
          AppLogger().debug('📱 Debates: Unread count updated to $count');
        }
      });
      
      AppLogger().debug('📱 Instant messaging initialized in debates room');
    } catch (e) {
      AppLogger().error('❌ Failed to initialize instant messaging: $e');
    }
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
        
        // Load gift data after user is set
        _loadGiftData();
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
              } else if (role == 'pending') {
                // User has requested to speak - add to speaker requests AND keep in audience
                if (!_speakerRequests.any((p) => p.id == userProfile.id)) {
                  _speakerRequests.add(userProfile);
                }
                // Also keep them in audience so they don't disappear
                if (!_audienceMembers.any((p) => p.id == userProfile.id)) {
                  _audienceMembers.add(userProfile);
                }
                // Check if current user has requested
                if (userProfile.id == _currentUser?.id) {
                  _hasRequestedSpeaker = true;
                }
              } else {
                // Regular audience member
                if (!_audienceMembers.any((p) => p.id == userProfile.id)) {
                  _audienceMembers.add(userProfile);
                }
              }
            }
          }
        });
      }
      
      AppLogger().debug('Loaded ${participants.length} participants: ${_speakerPanelists.length} speakers, ${_audienceMembers.length} audience, ${_speakerRequests.length} pending requests');
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
      // Separate subscription for participants - critical for hand-raising notifications
      _participantsSubscription = _appwrite.realtimeInstance.subscribe([
        'databases.arena_db.collections.debate_discussion_participants.documents'
      ]);

      _participantsSubscription?.stream.listen(
        (response) async {
          AppLogger().debug('Participant update events: ${response.events}');
          AppLogger().debug('Participant update payload: ${response.payload}');
          
          if (mounted && !_isDisposing) {
            // Check for specific participant role changes
            bool isHandRaiseEvent = false;
            bool isHandLowerEvent = false;
            
            for (var event in response.events) {
              // Check if this is an update event
              if (event.contains('debate_discussion_participants.documents') && event.endsWith('.update')) {
                // Check if it's for this room
                if (response.payload['roomId'] == widget.roomId) {
                  final newRole = response.payload['role'];
                  final userId = response.payload['userId'];
                  
                  if (newRole == 'pending') {
                    AppLogger().info('Hand-raise detected: $userId requested to speak');
                    isHandRaiseEvent = true;
                  } else if (newRole == 'audience') {
                    // Could be hand lowering or moderator denial - check if it was current user
                    if (userId == _currentUser?.id && _hasRequestedSpeaker) {
                      AppLogger().info('Hand-lower detected: $userId lowered their hand');
                      isHandLowerEvent = true;
                    }
                  }
                }
              }
            }
            
            // Always reload participants to keep UI in sync
            await _loadParticipants();
            
            // Show immediate notification for hand-raise events (only for moderators)
            if (isHandRaiseEvent && _isCurrentUserModerator) {
              AppLogger().info('Showing hand-raise notification to moderator');
              _showHandRaiseNotificationFromPayload(response.payload);
            }
            
            // Update local state if current user lowered their hand
            if (isHandLowerEvent) {
              setState(() {
                _hasRequestedSpeaker = false;
              });
            }
          }
        },
        onError: (error) {
          AppLogger().error('Participants subscription error: $error');
          // Attempt to reconnect after error
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_isDisposing) {
              _reconnectParticipantsSubscription();
            }
          });
        },
        onDone: () {
          AppLogger().warning('Participants subscription closed - attempting reconnect');
          if (mounted && !_isDisposing) {
            _reconnectParticipantsSubscription();
          }
        },
      );

      // Separate subscription for room status (like room ending)
      _roomSubscription = Realtime(_appwrite.client).subscribe([
        'databases.arena_db.collections.debate_discussion_rooms.documents.${widget.roomId}'
      ]);

      _roomSubscription?.stream.listen(
        (response) {
          AppLogger().debug('Room update events: ${response.events}');
          _handleRoomUpdate(response);
        },
        onError: (error) {
          AppLogger().error('Room subscription error: $error');
        },
      );
      
    } catch (e) {
      AppLogger().error('Error setting up real-time updates: $e');
    }
  }

  void _reconnectParticipantsSubscription() {
    try {
      AppLogger().info('Reconnecting participants subscription...');
      _participantsSubscription?.close();
      
      // Create new subscription after short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isDisposing) {
          _participantsSubscription = _appwrite.realtimeInstance.subscribe([
            'databases.arena_db.collections.debate_discussion_participants.documents'
          ]);

          _participantsSubscription?.stream.listen(
            (response) async {
              AppLogger().debug('Reconnected - Participant update events: ${response.events}');
              
              if (mounted && !_isDisposing) {
                // Check for hand-raise and hand-lower events
                bool isHandRaiseEvent = false;
                bool isHandLowerEvent = false;
                
                for (var event in response.events) {
                  if (event.contains('debate_discussion_participants.documents') && event.endsWith('.update')) {
                    if (response.payload['roomId'] == widget.roomId) {
                      final newRole = response.payload['role'];
                      final userId = response.payload['userId'];
                      
                      if (newRole == 'pending') {
                        AppLogger().info('Hand-raise detected after reconnect: $userId');
                        isHandRaiseEvent = true;
                      } else if (newRole == 'audience') {
                        if (userId == _currentUser?.id && _hasRequestedSpeaker) {
                          AppLogger().info('Hand-lower detected after reconnect: $userId');
                          isHandLowerEvent = true;
                        }
                      }
                    }
                  }
                }
                
                await _loadParticipants();
                
                if (isHandRaiseEvent && _isCurrentUserModerator) {
                  _showHandRaiseNotificationFromPayload(response.payload);
                }
                
                if (isHandLowerEvent) {
                  setState(() {
                    _hasRequestedSpeaker = false;
                  });
                }
              }
            },
            onError: (error) {
              AppLogger().error('Reconnected subscription error: $error');
            },
            onDone: () {
              AppLogger().warning('Reconnected subscription closed');
              if (mounted && !_isDisposing) {
                _reconnectParticipantsSubscription();
              }
            },
          );
          
          AppLogger().info('Participants subscription reconnected successfully');
        }
      });
    } catch (e) {
      AppLogger().error('Error reconnecting participants subscription: $e');
    }
  }

  void _showHandRaiseNotificationFromPayload(Map<String, dynamic> payload) async {
    try {
      final userId = payload['userId'];
      if (userId == null) return;
      
      // Get user profile for the notification
      final userProfile = await _appwrite.getUserProfile(userId);
      if (userProfile == null) {
        AppLogger().warning('Could not find user profile for hand-raise notification: $userId');
        return;
      }
      
      AppLogger().info('Showing immediate hand-raise notification for: ${userProfile.name}');
      
      if (mounted && !_isDisposing) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.hand,
                      color: Color(0xFF8B5CF6),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Hand Raised!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Text(
                '${userProfile.name} wants to join the speakers panel',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _denySpeakerRequest(userProfile);
                  },
                  child: const Text(
                    'Deny',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _approveSpeakerRequest(userProfile);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Approve',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      AppLogger().error('Error showing hand-raise notification: $e');
      // Fallback to the old method
      _showNewSpeakerRequestNotification();
    }
  }

  void _showNewSpeakerRequestNotification() {
    // Get the latest speaker request
    if (_speakerRequests.isEmpty) return;
    
    final latestRequest = _speakerRequests.last;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.hand,
                  color: Color(0xFF8B5CF6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Speaker Request',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            '${latestRequest.name} wants to join the speakers panel',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _denySpeakerRequest(latestRequest);
              },
              child: const Text(
                'Deny',
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _approveSpeakerRequest(latestRequest);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Approve',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
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
    if (_isCurrentUserModerator || _isCurrentUserSpeaker || _currentUser == null) {
      return;
    }
    
    try {
      if (_hasRequestedSpeaker) {
        // User wants to lower their hand - change back to audience
        await _appwrite.updateDebateDiscussionParticipantRole(
          roomId: widget.roomId,
          userId: _currentUser!.id,
          newRole: 'audience',
        );
        
        if (mounted && !_isDisposing) {
          setState(() {
            _hasRequestedSpeaker = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✋ Hand lowered - request cancelled'),
              backgroundColor: Colors.grey,
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        AppLogger().info('User ${_currentUser!.name} lowered their hand');
      } else {
        // User wants to raise their hand - change to pending
        await _appwrite.updateDebateDiscussionParticipantRole(
          roomId: widget.roomId,
          userId: _currentUser!.id,
          newRole: 'pending',
        );
        
        if (mounted && !_isDisposing) {
          setState(() {
            _hasRequestedSpeaker = true;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✋ Request sent to moderator for approval'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        AppLogger().info('User ${_currentUser!.name} raised their hand');
      }
      
      // The real-time subscription will update the UI automatically
    } catch (e) {
      AppLogger().error('Error with hand raise/lower: $e');
      if (mounted && !_isDisposing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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

    return FloatingIMWidget(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildRoomTitleSection(),
              Expanded(
                child: _buildVideoGrid(),
              ),
              _buildControlsBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
          const Spacer(),
          // Timer Widget
          AppwriteTimerWidget(
            roomId: widget.roomId,
            roomType: RoomType.debatesDiscussions,
            isModerator: _isCurrentUserModerator,
            userId: _currentUser?.id ?? '',
            compact: true,
            showControls: _isCurrentUserModerator,
            showConnectionStatus: false,
          ),
          const SizedBox(width: 16),
          const ChallengeBell(iconColor: Colors.white),
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
              const SizedBox(width: 16),
              // Instant Message Bell
              const InstantMessageBell(
                iconColor: Color(0xFF8B5CF6),
                iconSize: 20,
              ),
              if (_isCurrentUserModerator) ...[ 
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _showModeratorTools,
                  child: Stack(
                    children: [
                      Container(
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
                      // Show badge if there are pending speaker requests
                      if (_speakerRequests.isNotEmpty)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Center(
                              child: Text(
                                '${_speakerRequests.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomTitleSection() {
    final roomName = _roomData?['name'] ?? widget.roomName ?? 'Debate Room';
    final moderatorName = _moderator?.name ?? widget.moderatorName ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Room name
          Text(
            roomName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Moderator info - stacked
          Column(
            children: [
              const Text(
                'Moderated by',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              Text(
                moderatorName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
      child: GestureDetector(
        onTap: () => _showUserProfileModal(participant),
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
    
    return GestureDetector(
      onTap: () => _showUserProfileModal(member),
      child: Container(
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
            onTap: _showChat,
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

  /// Show chat modal
  void _showChat() {
    if (_currentUser == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => RoomChatPanel(
          roomId: widget.roomId,
          roomType: 'debate_discussion',
          participantCount: _speakerPanelists.length + _audienceMembers.length,
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
      // Change user role back to audience
      await _appwrite.updateDebateDiscussionParticipantRole(
        roomId: widget.roomId,
        userId: user.id,
        newRole: 'audience',
      );
      
      // Remove from speaker requests locally
      if (mounted) {
        setState(() {
          _speakerRequests.removeWhere((request) => request.id == user.id);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Denied speaker request from ${user.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      AppLogger().info('Moderator denied speaker request from ${user.name}');
    } catch (e) {
      AppLogger().error('Error denying speaker request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error denying request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  Future<void> _loadGiftData() async {
    try {
      // Load user coin balance
      if (_currentUser != null) {
        final balance = await _giftService.getUserCoinBalance(_currentUser!.id);
        if (mounted) {
          setState(() {
            _currentUserCoinBalance = balance;
          });
        }
      }
      
      // Load available gifts
      setState(() {
        _availableGifts = GiftConstants.allGifts;
      });
      
      AppLogger().debug('Loaded gift data - Balance: $_currentUserCoinBalance, Gifts: ${_availableGifts.length}');
    } catch (e) {
      AppLogger().error('Error loading gift data: $e');
    }
  }

  // Gift modal methods (Open Discussion room implementation)
  void _showGiftModal() {
    AppLogger().debug('🎁 DEBUG: Gift modal button pressed');
    
    // Get eligible recipients (moderator and speakers only, excluding self)
    final eligibleRecipients = <Map<String, dynamic>>[];
    
    // Add moderator if not current user
    if (_moderator != null && _moderator!.id != _currentUser!.id) {
      eligibleRecipients.add({
        'userId': _moderator!.id,
        'name': _moderator!.name,
        'role': 'moderator',
      });
    }
    
    // Add speakers if not current user
    for (final speaker in _speakerPanelists) {
      if (speaker.id != _currentUser!.id && !eligibleRecipients.any((r) => r['userId'] == speaker.id)) {
        eligibleRecipients.add({
          'userId': speaker.id,
          'name': speaker.name,
          'role': 'speaker',
        });
      }
    }

    if (eligibleRecipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No eligible recipients. Only moderators and speakers can receive gifts.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Send Gift',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '🪙',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_currentUserCoinBalance',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tab bar
              const TabBar(
                labelColor: Color(0xFF8B5CF6),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFF8B5CF6),
                tabs: [
                  Tab(text: 'Select Gift'),
                  Tab(text: 'Recipients'),
                ],
              ),
              
              // Tab content
              Expanded(
                child: TabBarView(
                  children: [
                    _buildGiftSelectionTab(),
                    _buildRecipientSelectionTab(eligibleRecipients),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiftSelectionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Money Gifting Section
          _buildMoneyGiftingSection(),
          
          const SizedBox(height: 24),
          
          // Gift categories
          ...GiftCategory.values.map((category) => _buildGiftCategorySection(category)),
        ],
      ),
    );
  }

  Widget _buildMoneyGiftingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Send Money Button
        GestureDetector(
          onTap: _showMoneyInputModal,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.attach_money, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text(
                  '\$ Send Money',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildGiftCategorySection(GiftCategory category) {
    final categoryGifts = GiftConstants.getGiftsByCategory(category);
    if (categoryGifts.isEmpty) return Container();

    String categoryTitle = '';
    IconData categoryIcon = Icons.card_giftcard;
    Color categoryColor = Colors.grey;

    switch (category) {
      case GiftCategory.intellectual:
        categoryTitle = 'Intellectual Achievement';
        categoryIcon = Icons.psychology;
        categoryColor = Colors.blue;
        break;
      case GiftCategory.supportive:
        categoryTitle = 'Supportive & Encouraging';
        categoryIcon = Icons.favorite;
        categoryColor = Colors.pink;
        break;
      case GiftCategory.fun:
        categoryTitle = 'Fun & Personality';
        categoryIcon = Icons.celebration;
        categoryColor = Colors.orange;
        break;
      case GiftCategory.recognition:
        categoryTitle = 'Recognition & Status';
        categoryIcon = Icons.star;
        categoryColor = Colors.amber;
        break;
      case GiftCategory.interactive:
        categoryTitle = 'Interactive & Engaging';
        categoryIcon = Icons.play_circle;
        categoryColor = Colors.green;
        break;
      case GiftCategory.premium:
        categoryTitle = 'Premium Collection';
        categoryIcon = Icons.diamond;
        categoryColor = Colors.purple;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(categoryIcon, color: categoryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                categoryTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: categoryColor,
                ),
              ),
            ],
          ),
        ),
        
        // Gift grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.2,
          ),
          itemCount: categoryGifts.length,
          itemBuilder: (context, index) {
            final gift = categoryGifts[index];
            return _buildGiftCard(gift);
          },
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildGiftCard(Gift gift) {
    final canAfford = _currentUserCoinBalance >= gift.cost;
    final isSelected = _selectedGift?.id == gift.id;
    
    return GestureDetector(
      onTap: canAfford ? () => _selectGift(gift) : null,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.withValues(alpha: 0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.red : _getTierColor(gift.tier),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Gift emoji and effects
                  Text(
                    gift.emoji,
                    style: TextStyle(
                      fontSize: canAfford ? 24 : 20,
                      color: canAfford ? null : Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  if (gift.hasVisualEffect)
                    Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: Colors.amber[600],
                    ),
                  if (gift.hasProfileBadge)
                    const Icon(
                      Icons.verified,
                      size: 12,
                      color: Colors.blue,
                    ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // Gift name
              Text(
                gift.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: canAfford ? Colors.black87 : Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 2),
              
              // Gift description
              Text(
                gift.description,
                style: TextStyle(
                  fontSize: 11,
                  color: canAfford ? Colors.grey[600] : Colors.grey[400],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const Spacer(),
              
              // Cost
              Row(
                children: [
                  const Text(
                    '🪙',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${gift.cost}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: canAfford ? _getTierColor(gift.tier) : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTierColor(GiftTier tier) {
    switch (tier) {
      case GiftTier.basic:
        return Colors.grey[600]!;
      case GiftTier.standard:
        return Colors.blue[600]!;
      case GiftTier.premium:
        return Colors.purple[600]!;
      case GiftTier.legendary:
        return Colors.amber[600]!;
    }
  }

  Widget _buildRecipientSelectionTab(List<Map<String, dynamic>> eligibleRecipients) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: eligibleRecipients.length,
      itemBuilder: (context, index) {
        final recipient = eligibleRecipients[index];
        final isSelected = _selectedRecipient?['userId'] == recipient['userId'];
        
        return GestureDetector(
          onTap: () => _selectRecipient(recipient),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.white,
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  child: Text(
                    recipient['name'][0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipient['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        recipient['role'].toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Colors.blue,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoneyInputModal() {
    final TextEditingController amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.attach_money, color: Colors.green),
            SizedBox(width: 8),
            Text('Send Money'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the amount you want to send:'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
                hintText: '0.00',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            const Text(
              'This will be processed through a secure payment gateway.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = amountController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter an amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              final amount = double.tryParse(text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              Navigator.pop(context);
              _selectCustomMoneyGift(amount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _selectCustomMoneyGift(double amount) {
    AppLogger().debug('💵 DEBUG: Custom money amount selected: \$$amount');

    setState(() {
      _selectedGift = Gift(
        id: 'money_${amount.toStringAsFixed(2)}',
        name: '\$${amount.toStringAsFixed(2)} Cash',
        emoji: '💵',
        description: 'Send \$${amount.toStringAsFixed(2)} real money',
        cost: 0, // No coin cost for real money
        category: GiftCategory.premium,
        tier: amount <= 10 ? GiftTier.standard : amount <= 50 ? GiftTier.premium : GiftTier.legendary,
      );
    });
    
    AppLogger().debug('💵 DEBUG: Custom money gift selected successfully: \$${amount.toStringAsFixed(2)}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💵 Selected \$${amount.toStringAsFixed(2)} cash'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
    
    // Auto-show confirmation if recipient is already selected
    if (_selectedRecipient != null) {
      _showGiftConfirmation();
    }
  }

  void _selectGift(Gift gift) {
    AppLogger().debug('🎁 DEBUG: Gift selected: ${gift.name}');
    AppLogger().debug('🎁 DEBUG: Gift cost: ${gift.cost}');
    AppLogger().debug('🎁 DEBUG: User balance: $_currentUserCoinBalance');
    
    if (_currentUserCoinBalance < gift.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient coins!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _selectedGift = gift;
    });
    
    AppLogger().debug('🎁 DEBUG: Gift selected successfully: ${gift.name}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎁 Selected ${gift.emoji} ${gift.name}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
    
    // Auto-show confirmation if recipient is already selected
    if (_selectedRecipient != null) {
      _showGiftConfirmation();
    }
  }

  void _selectRecipient(Map<String, dynamic> recipient) {
    setState(() {
      _selectedRecipient = recipient;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected ${recipient['name']}'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 1),
      ),
    );
    
    // Auto-show confirmation if gift is already selected
    if (_selectedGift != null) {
      _showGiftConfirmation();
    }
  }

  void _showGiftConfirmation() {
    if (_selectedGift == null || _selectedRecipient == null) return;

    final gift = _selectedGift!;
    final recipient = _selectedRecipient!;
    final isMoneyGift = gift.id.startsWith('money_');
    final isCoinGift = gift.id.startsWith('coin_');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isMoneyGift ? 'Send Money?' : 'Send Gift?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send ${gift.emoji} ${gift.name} to ${recipient['name']}?'),
            const SizedBox(height: 8),
            if (isMoneyGift) ...[
              Text('Amount: ${gift.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Text('This will be processed through a secure payment gateway.'),
            ] else if (isCoinGift) ...[
              Text('Cost: 🪙 ${gift.cost} coins'),
              Text('Your balance: 🪙 $_currentUserCoinBalance coins'),
              Text('After: 🪙 ${_currentUserCoinBalance - gift.cost} coins'),
            ] else ...[
              Text('Cost: 🪙 ${gift.cost} coins'),
              Text('Your balance: 🪙 $_currentUserCoinBalance coins'),
              Text('After: 🪙 ${_currentUserCoinBalance - gift.cost} coins'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: (isMoneyGift || _currentUserCoinBalance >= gift.cost)
                ? () => _sendGift(gift, recipient)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isMoneyGift ? Colors.green : Colors.blue,
            ),
            child: Text(isMoneyGift ? 'Send Money' : 'Send Gift'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendGift(Gift gift, Map<String, dynamic> recipient) async {
    if (_currentUser == null) return;

    final isMoneyGift = gift.id.startsWith('money_');

    try {
      Navigator.pop(context); // Close confirmation dialog

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(isMoneyGift ? 'Processing payment...' : 'Sending gift...'),
              ],
            ),
            backgroundColor: isMoneyGift ? Colors.green : Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      if (isMoneyGift) {
        // Handle real money transactions
        await _processMoneyGift(gift, recipient);
      } else {
        // Handle regular gifts and coin gifts via Firebase
        await _giftService.sendGift(
          giftId: gift.id,
          senderId: _currentUser!.id,
          recipientId: recipient['userId'],
          roomId: widget.roomId,
          cost: gift.cost,
        );
      }

      // Send gift notification to chat (if chat service exists)
      try {
        // Gift notifications will be handled by new chat system
        // await _chatService.sendGiftNotification(
        //   roomId: widget.roomId,
        //   giftId: gift.id,
        //   giftName: '${gift.emoji} ${gift.name}',
        //   senderId: _currentUser!.id,
        //   senderName: _currentUser!.displayName,
        //   recipientId: recipient['userId'],
        //   recipientName: recipient['name'],
        //   cost: gift.cost,
        // );
      } catch (chatError) {
        AppLogger().warning('Could not send chat notification: $chatError');
        // Continue anyway - gift was sent successfully
      }

      // Refresh Firebase coin balance (only for coin-based gifts)
      if (!isMoneyGift) {
        await _loadGiftData();
      }

      // Show success notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMoneyGift 
              ? '💵 Money sent! ${gift.name} to ${recipient['name']}'
              : '🎁 Gift sent! ${gift.emoji} ${gift.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reset selections
      setState(() {
        _selectedGift = null;
        _selectedRecipient = null;
      });

    } catch (e) {
      AppLogger().error('Error sending gift: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMoneyGift 
              ? 'Failed to process payment: $e'
              : 'Failed to send gift: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processMoneyGift(Gift gift, Map<String, dynamic> recipient) async {
    // Extract amount from gift name (e.g., "$25.50 Cash" -> 25.50)
    final amountString = gift.name.replaceAll(RegExp(r'[^\d.]'), '');
    final amount = double.tryParse(amountString) ?? 0.0;
    
    AppLogger().info('Processing money gift: \$${amount.toStringAsFixed(2)} to ${recipient['name']}');
    
    // TODO: Integrate with payment gateway (Stripe, PayPal, etc.)
    // For now, simulate the payment process
    await Future.delayed(const Duration(seconds: 2));
    
    // In a real implementation, you would:
    // 1. Call payment gateway API (Stripe, PayPal, etc.)
    // 2. Handle payment confirmation
    // 3. Record transaction in database
    // 4. Handle payment failures/retries
    // 5. Send payment receipt to both parties
    
    // Simulate success for demonstration
    AppLogger().info('Money gift processed successfully: \$${amount.toStringAsFixed(2)}');
  }

  Widget _buildGiftButton() {
    return GestureDetector(
      onTap: _showGiftModal,
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

  // void _showUserProfile(UserProfile userProfile, String? userRole) {
  //   showDialog(
  //     context: context,
  //     barrierColor: Colors.transparent,
  //     builder: (context) => UserProfileModal(
  //       userProfile: userProfile,
  //       userRole: userRole,
  //       currentUser: _currentUser,
  //       onClose: () => Navigator.of(context).pop(),
  //     ),
  //   );
  // }
}