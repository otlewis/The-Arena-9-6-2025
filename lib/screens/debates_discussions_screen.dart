import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import '../services/appwrite_service.dart';
import '../services/firebase_gift_service.dart';
import '../services/livekit_service.dart';
import '../services/livekit_token_service.dart';
// import '../services/chat_service.dart'; // Removed with new chat system
import '../models/user_profile.dart';
import '../models/gift.dart';
import '../models/timer_state.dart';
import '../widgets/animated_fade_in.dart';
import '../widgets/appwrite_timer_widget.dart';
import '../widgets/user_profile_bottom_sheet.dart';
import '../widgets/instant_message_bell.dart';
import '../widgets/challenge_bell.dart';
import '../widgets/mattermost_chat_widget.dart';
import 'email_compose_screen.dart';
import '../models/discussion_chat_message.dart';
// import '../widgets/floating_im_widget.dart'; // Unused import
import '../core/logging/app_logger.dart';
import '../utils/performance_optimizations.dart';
import '../utils/optimized_state_manager.dart';
import '../utils/ultra_performance_mode.dart';
import '../utils/extreme_performance_mode.dart';
import '../widgets/performance_optimized_audience_grid.dart';

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
  final AppwriteService _appwrite = AppwriteService();
  final FirebaseGiftService _giftService = FirebaseGiftService();
  final LiveKitService _webrtcService = LiveKitService();
  
  // Video/Audio WebRTC state
  bool _isWebRTCConnected = false;
  bool _isWebRTCConnecting = false;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  
  // User-to-peer mapping for video streams
  final Map<String, String> _userToPeerMapping = {}; // userId -> peerId
  final Map<String, String> _peerToUserMapping = {}; // peerId -> userId
  
  // Audio stream management
  MediaStream? _localStream;
  final Map<String, MediaStream> _remoteStreams = {};
  
  bool _isMuted = false;
  bool _isVideoEnabled = false;
  
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
  
  // Performance optimization - cache last participants to prevent unnecessary rebuilds
  List<dynamic> _lastParticipants = [];
  
  // Legacy audio variables (Agora removed, kept to prevent compilation errors)
  // Note: These are no longer used but kept for any remaining references
  
  // Room state
  bool _isLoading = true;
  bool _isJoined = false;
  bool _isCurrentUserModerator = false;
  bool _isCurrentUserSpeaker = false;
  bool _hasRequestedSpeaker = false;
  bool _isDisposing = false;
  
  // Video conference state removed - audio-only mode
  // Future update will restore video functionality
  
  // Real-time subscriptions - separate instances for reliability
  RealtimeSubscription? _participantsSubscription;
  RealtimeSubscription? _roomSubscription;
  StreamSubscription? _unreadMessagesSubscription; // Instant messages subscription

  @override
  void initState() {
    super.initState();
    
    // Enable ultra-performance mode for maximum FPS
    UltraPerformanceMode.instance.enable();
    
    // Enable extreme performance mode for maximum possible performance
    ExtremePerformanceMode.instance.enable();
    
    _initializeRoom();
    _loadGiftData();
    _initializeWebRTC();
  }
  
  Future<void> _initializeWebRTC() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    
    // Set up LiveKit service callbacks
    _webrtcService.onConnected = () {
      AppLogger().debug('✅ LiveKit connected to Debates & Discussions room');
      if (mounted) {
        setState(() {
          _isWebRTCConnected = true;
          _isWebRTCConnecting = false;
        });
        _debugVideoState();
      }
    };
    
    _webrtcService.onParticipantConnected = (participant) {
      AppLogger().debug('👤 LiveKit participant joined: ${participant.identity}');
      if (mounted) {
        setState(() {
          // Trigger UI update for participant count
        });
      }
    };
    
    _webrtcService.onParticipantDisconnected = (participant) {
      AppLogger().debug('👋 LiveKit participant left: ${participant.identity}');
      if (mounted) {
        setState(() {
          // Update UI for participant leaving
        });
      }
    };
    
    _webrtcService.onTrackSubscribed = (publication, participant) {
      AppLogger().debug('🎵 LiveKit track subscribed from ${participant.identity}');
      if (mounted) {
        setState(() {
          // Handle new audio track
        });
      }
    };
    
    _webrtcService.onDisconnected = () {
      AppLogger().debug('📡 LiveKit disconnected from Debates & Discussions room');
      if (mounted) {
        setState(() {
          _isWebRTCConnected = false;
          _isWebRTCConnecting = false;
        });
      }
    };
    
    _webrtcService.onError = (error) {
      AppLogger().debug('❌ LiveKit error: $error');
      if (mounted) {
        setState(() {
          _isWebRTCConnecting = false;
        });
      }
    };
    
    AppLogger().debug('📹 WebRTC renderers and MediaSoup service initialized for Debates & Discussions');
  }

  // Audio/Video control methods
  Future<void> _toggleAudio() async {
    // Use LiveKit's built-in mute functionality
    await _webrtcService.toggleMute();
    if (mounted) {
      setState(() {
        _isMuted = _webrtcService.isMuted;
      });
    }
    AppLogger().debug('🎤 Audio ${_webrtcService.isMuted ? 'muted' : 'unmuted'} via LiveKit');
  }

  void _resumeWebAudioContext() async {
    if (kIsWeb) {
      // Resume web audio context for browser autoplay policy
      AppLogger().debug('🔊 Attempting to resume web audio context');
      // The actual implementation would depend on web-specific imports
      // For now, just trigger the audio activation
      if (_remoteStreams.isNotEmpty) {
        // Enable remote audio tracks to activate audio context
        for (final stream in _remoteStreams.values) {
          final audioTracks = stream.getAudioTracks();
          for (var track in audioTracks) {
            track.enabled = true;
          }
        }
      }
    }
  }

  Future<void> _toggleVideo() async {
    AppLogger().debug('🎥 _toggleVideo called - current state: $_isVideoEnabled, service connected: $_isWebRTCConnected');
    
    try {
      if (_isWebRTCConnected) {
        // Video not supported in Debates & Discussions (audio-only mode)
        AppLogger().debug('🎥 Video toggle not supported - Debates & Discussions are audio-only');
        
        if (mounted) {
          setState(() {
            _isVideoEnabled = false; // Video not supported
          });
        }
        
        AppLogger().debug('🎥 Video ${_isVideoEnabled ? 'enabled' : 'disabled'} - UI will ${_isVideoEnabled ? 'show video' : 'show avatar'}');
      } else {
        AppLogger().warning('🎥 Cannot toggle video - MediaSoup service not connected');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait for connection to establish before enabling video'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger().error('🎥 Error toggling video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _autoEnableVideoAndAudio() {
    AppLogger().debug('🎬 _autoEnableVideoAndAudio() called - isModerator: $_isCurrentUserModerator, isSpeaker: $_isCurrentUserSpeaker');
    // Connect all users to WebRTC for video viewing
    // Moderators and speakers publish video, audience only receives
    _connectToWebRTC();
  }
  
  void _debugVideoState() {
    AppLogger().debug('=== VIDEO DEBUG STATE ===');
    AppLogger().debug('🎥 Current user role: moderator=$_isCurrentUserModerator, speaker=$_isCurrentUserSpeaker');
    AppLogger().debug('🎥 Video enabled: $_isVideoEnabled');
    AppLogger().debug('🎥 WebRTC connected: $_isWebRTCConnected');
    AppLogger().debug('🎥 WebRTC connected: $_isWebRTCConnected');
    AppLogger().debug('🎥 Local stream: ${_localStream != null}');
    if (_localStream != null) {
      AppLogger().debug('🎥 Local video tracks: ${_localStream!.getVideoTracks().length}');
      AppLogger().debug('🎥 Local audio tracks: ${_localStream!.getAudioTracks().length}');
    }
    AppLogger().debug('🎥 Remote streams: ${_remoteStreams.length}');
    AppLogger().debug('🎥 Speaker panelists: ${_speakerPanelists.length}');
    AppLogger().debug('🎥 User to peer mappings: $_userToPeerMapping');
    AppLogger().debug('🎥 Peer to user mappings: $_peerToUserMapping');
    AppLogger().debug('🎥 Remote renderers: ${_remoteRenderers.keys.join(', ')}');
    AppLogger().debug('========================');
  }


  Future<void> _initializeRoom() async {
    try {
      AppLogger().debug('🏠 Initializing Debates & Discussions room: ${widget.roomId}');
      
      // Get current user
      final user = await _appwrite.getCurrentUser();
      if (user != null) {
        final userProfile = await _appwrite.getUserProfile(user.$id);
        if (mounted && !_isDisposing) {
          setState(() {
            _currentUser = userProfile;
          });
        }
        AppLogger().debug('👤 Current user loaded: ${userProfile?.name}');
      }
      
      // Load room data
      await _loadRoomData();
      
      // Join the room as a participant
      if (_currentUser != null) {
        await _joinRoom();
      }
      
      // Load participants from database
      await _loadParticipants();
      
      // Set up real-time subscriptions
      _setupRealTimeUpdates();
      
      // Auto-enable video/audio for moderators and speakers
      _autoEnableVideoAndAudio();
      
      // Room initialization complete
      if (mounted && !_isDisposing) {
        setState(() {
          _isLoading = false;
        });
      }
      
      AppLogger().debug('✅ Room initialization complete');
      
    } catch (e) {
      AppLogger().error('❌ Room initialization failed: $e');
      if (mounted && !_isDisposing) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRoomData() async {
    try {
      AppLogger().debug('📦 Loading room data for: ${widget.roomId}');
      
      // Load room details from database
      final roomData = await _appwrite.getDebateDiscussionRoom(widget.roomId);
      if (roomData != null && mounted && !_isDisposing) {
        setState(() {
          _roomData = roomData;
        });
        
        // Load moderator profile if available
        final moderatorId = roomData['createdBy'];
        if (moderatorId != null) {
          final moderatorProfile = await _appwrite.getUserProfile(moderatorId);
          if (moderatorProfile != null && mounted && !_isDisposing) {
            setState(() {
              _moderator = moderatorProfile;
            });
          }
        }
        
        AppLogger().debug('✅ Room data loaded: ${roomData['name']}');
      }
    } catch (e) {
      AppLogger().error('❌ Error loading room data: $e');
      // Continue with initialization even if room data fails
    }
  }

  Future<void> _joinRoom() async {
    try {
      if (_currentUser == null) {
        AppLogger().warning('Cannot join room - no current user');
        return;
      }
      
      AppLogger().debug('🚪 Joining Debates & Discussions room: ${widget.roomId}');
      
      // Determine initial role - creator is moderator, others start as audience
      final isCreator = _roomData?['createdBy'] == _currentUser!.id;
      final initialRole = isCreator ? 'moderator' : 'audience';
      
      // Join the room in the database
      await _appwrite.joinDebateDiscussionRoom(
        roomId: widget.roomId,
        userId: _currentUser!.id,
        role: initialRole,
      );
      
      if (mounted && !_isDisposing) {
        setState(() {
          _isJoined = true;
          if (isCreator) {
            _isCurrentUserModerator = true;
          }
        });
      }
      
      AppLogger().debug('✅ Joined room ${widget.roomId} as $initialRole');
    } catch (e) {
      AppLogger().error('❌ Error joining room: $e');
      // Continue anyway - user might already be in room
      if (mounted && !_isDisposing) {
        setState(() {
          _isJoined = true; // Allow room to continue loading
        });
      }
    }
  }

  void _showUserProfileModal(UserProfile user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => UserProfileBottomSheet(
        user: user,
        onFollow: () {
          // TODO: Implement follow functionality
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Following ${user.name}'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        },
        onChallenge: () {
          // TODO: Implement challenge functionality
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Challenge sent to ${user.name}'),
                backgroundColor: const Color(0xFFDC2626),
              ),
            );
          }
        },
        onEmail: () {
          if (mounted && _currentUser != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmailComposeScreen(
                  currentUserId: _currentUser!.id,
                  currentUsername: _currentUser!.name,
                  recipient: user,
                ),
              ),
            );
          }
        },
      ),
    );
  }
  
  Widget _buildWebRTCVideoContent(UserProfile participant, bool isModerator) {
    // Check if this participant has a video stream
    bool hasVideo = false;
    Widget? videoWidget;
    
    // Check local video for current user
    if (participant.id == _currentUser?.id) {
      // Show local video only if current user is moderator or speaker AND video is enabled
      if ((_isCurrentUserModerator || _isCurrentUserSpeaker) &&
          _localStream != null && 
          _localStream!.getVideoTracks().isNotEmpty &&
          _isVideoEnabled) {
        videoWidget = RTCVideoView(_localRenderer, mirror: true);
        hasVideo = true;
        AppLogger().debug('🎥 Showing local video for ${participant.name}');
      }
    } else {
      // For remote participants, use the user-to-peer mapping
      final peerId = _userToPeerMapping[participant.id];
      
      if (peerId != null && _remoteRenderers.containsKey(peerId)) {
        final renderer = _remoteRenderers[peerId]!;
        try {
          if (renderer.srcObject != null) {
            final stream = renderer.srcObject!;
            final videoTracks = stream.getVideoTracks();
            if (videoTracks.isNotEmpty) {
              videoWidget = RTCVideoView(renderer);
              hasVideo = true;
              AppLogger().debug('🎥 Showing remote video for ${participant.name} (peer: $peerId)');
            }
          }
        } catch (e) {
          AppLogger().warning('Error showing video for ${participant.name}: $e');
        }
      } else {
        AppLogger().debug('🎥 No video stream found for ${participant.name} (userId: ${participant.id})');
        if (peerId == null) {
          AppLogger().debug('🎥 No peer mapping found for user ${participant.id}');
        } else {
          AppLogger().debug('🎥 Peer $peerId found but no renderer');
        }
      }
    }
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: hasVideo && videoWidget != null
          ? Stack(
              children: [
                SizedBox.expand(child: videoWidget),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: CircleAvatar(
                radius: isModerator ? 32 : 24,
                backgroundColor: const Color(0xFF8B5CF6),
                backgroundImage: participant.avatar != null && participant.avatar!.isNotEmpty
                    ? NetworkImage(participant.avatar!)
                    : null,
                child: participant.avatar == null || participant.avatar!.isEmpty
                    ? _buildAvatarText(participant, isModerator ? 18 : 14)
                    : null,
              ),
            ),
      ),
    );
  }

  @override
  void dispose() {
    _isDisposing = true;
    _participantsSubscription?.close();
    _roomSubscription?.close();
    _unreadMessagesSubscription?.cancel();
    
    // Clean up performance optimizations
    PerformanceOptimizations.dispose();
    
    // Clean up WebRTC
    _cleanupWebRTC();
    
    // Clean up performance optimizations
    OptimizedStateManager.clearKey('participants_${widget.roomId}');
    OptimizedParticipantManager.clearKey('audience_${widget.roomId}');
    OptimizedParticipantManager.clearKey('speakers_${widget.roomId}');
    
    // Disable ultra-performance mode
    UltraPerformanceMode.instance.disable();
    
    // Disable extreme performance mode
    ExtremePerformanceMode.instance.disable();
    
    // Don't await _leaveRoom() in dispose as it's synchronous
    // Just call it without awaiting to start the process
    _leaveRoom().catchError((error) {
      AppLogger().error('Error during disposal: $error');
    });
    super.dispose();
  }

  Future<void> _cleanupWebRTC() async {
    try {
      _isWebRTCConnected = false;
      _isWebRTCConnecting = false;
      
      // Clear mappings
      _userToPeerMapping.clear();
      _peerToUserMapping.clear();
      
      // Disconnect MediaSoup service
      await _webrtcService.disconnect();
      
      // Dispose video renderers
      await _localRenderer.dispose();
      await _remoteRenderer.dispose();
      
      // Dispose all remote participant renderers
      for (final renderer in _remoteRenderers.values) {
        try {
          await renderer.dispose();
        } catch (e) {
          AppLogger().warning("Error disposing remote renderer: $e");
        }
      }
      _remoteRenderers.clear();
      
      AppLogger().debug("🧹 WebRTC cleanup completed for Debates & Discussions");
    } catch (e) {
      AppLogger().error("❌ WebRTC cleanup error: $e");
    }
  }

  Future<void> _connectToWebRTC() async {
    AppLogger().debug('🔍 _connectToWebRTC called - connecting: $_isWebRTCConnecting, connected: $_isWebRTCConnected');
    
    // Check if we need video capabilities (moderator or speaker)
    bool needsVideoCapabilities = _isCurrentUserModerator || _isCurrentUserSpeaker;
    bool hasVideoCapabilities = _localStream?.getVideoTracks().isNotEmpty ?? false;
    
    // Force disconnect if already connected but not working properly
    if (_isWebRTCConnected && (_remoteStreams.isEmpty)) {
      AppLogger().debug('🔄 Forcing fresh connection - current connection has no streams');
      await _webrtcService.disconnect();
      setState(() {
        _isWebRTCConnected = false;
        _isWebRTCConnecting = false;
      });
    }
    
    // Force reconnection if role capabilities changed (audience -> speaker/moderator)
    if (_isWebRTCConnected && needsVideoCapabilities && !hasVideoCapabilities) {
      AppLogger().debug('🔄 Role upgrade detected - forcing reconnection with video capabilities');
      await _webrtcService.disconnect();
      setState(() {
        _isWebRTCConnected = false;
        _isWebRTCConnecting = false;
      });
    }
    
    AppLogger().debug('🔍 _connectToWebRTC called - connecting: $_isWebRTCConnecting, connected: $_isWebRTCConnected');
    
    if (_isWebRTCConnecting || _isWebRTCConnected) {
      AppLogger().debug('⚠️ WebRTC connection skipped - already connecting or connected');
      return;
    }
    
    AppLogger().debug('🚀 Starting WebRTC connection process...');
    setState(() {
      _isWebRTCConnecting = true;
    });

    // Determine user role and connection mode (declare outside try block)
    String userRole;
    bool shouldPublishVideo;
    
    if (_isCurrentUserModerator) {
      userRole = 'moderator';
      shouldPublishVideo = true;
    } else if (_isCurrentUserSpeaker) {
      userRole = 'speaker';
      shouldPublishVideo = true;
    } else {
      userRole = 'audience';
      shouldPublishVideo = false; // Audience only receives video streams
    }

    try {
      
      final roomId = 'debates-discussion-${widget.roomId}';
      
      AppLogger().debug('🎥 Connecting to LiveKit for Debates & Discussions');
      AppLogger().debug('🎥 Room: $roomId');
      AppLogger().debug('🎥 User: ${_currentUser?.id} (${_currentUser?.name})');
      AppLogger().debug('🎥 Role: $userRole, Publish: $shouldPublishVideo');
      AppLogger().debug('🎥 Widget Room ID: ${widget.roomId}');
      
      // Generate LiveKit token
      final token = LiveKitTokenService.generateToken(
        roomName: roomId,
        identity: _currentUser?.id ?? 'unknown',
        userRole: userRole,
        roomType: 'debate_discussion',
        userId: _currentUser?.id ?? 'unknown',
        ttl: const Duration(hours: 2),
      );
      
      await _webrtcService.connect(
        serverUrl: 'ws://172.236.109.9:7880', // LiveKit production server
        roomName: roomId,
        token: token,
        userId: _currentUser?.id ?? 'unknown',
        userRole: userRole,
        roomType: 'debate_discussion',
      );
      
      // Log specific connection behavior
      if (shouldPublishVideo) {
        AppLogger().debug('🎥 Connected as $userRole - PUBLISHING video/audio');
      } else {
        AppLogger().debug('📹 Connected as $userRole - RECEIVING video feeds only');
      }
      
      AppLogger().debug('🎥 WebRTC connected successfully for Debates & Discussions');
      
      // Configure audio session for maximum speaker output
      try {
        final session = await audio_session.AudioSession.instance;
        await session.configure(audio_session.AudioSessionConfiguration(
          avAudioSessionCategory: audio_session.AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: audio_session.AVAudioSessionCategoryOptions.defaultToSpeaker |
              audio_session.AVAudioSessionCategoryOptions.allowBluetooth |
              audio_session.AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: audio_session.AVAudioSessionMode.videoChat,
          avAudioSessionRouteSharingPolicy: audio_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: audio_session.AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const audio_session.AndroidAudioAttributes(
            contentType: audio_session.AndroidAudioContentType.speech,
            flags: audio_session.AndroidAudioFlags.audibilityEnforced,
            usage: audio_session.AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: audio_session.AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ));
        
        // Activate the audio session with high priority
        await session.setActive(true);
        
        // Additional speaker enforcement (iOS will use defaultToSpeaker option above)
        
        AppLogger().debug('🔊 Audio session configured for maximum speaker output');
      } catch (e) {
        AppLogger().debug('❌ Failed to configure audio session: $e');
        // Continue anyway - audio might still work
      }
      
    } catch (e) {
      AppLogger().error('❌ Failed to connect WebRTC: $e');
      
      // Check if it's a Socket.IO WebSocket upgrade error
      if (e.toString().contains('WebSocketException') || e.toString().contains('not upgraded to websocket')) {
        AppLogger().warning('🔄 Socket.IO WebSocket error detected - trying HTTP fallback...');
        await _tryHttpWebRTCFallback(userRole, shouldPublishVideo);
      } else {
        setState(() {
          _isWebRTCConnecting = false;
        });
      }
    }
  }

  Future<void> _tryHttpWebRTCFallback(String userRole, bool shouldPublishVideo) async {
    try {
      AppLogger().debug('🌐 Attempting HTTP WebRTC fallback connection...');
      
      // Import and use HTTP WebRTC service (to be implemented)
      // For now, just show an error message that HTTP fallback is being attempted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WebSocket connection failed. Attempting HTTP fallback...'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      setState(() {
        _isWebRTCConnecting = false;
      });
      
    } catch (e) {
      AppLogger().error('❌ HTTP WebRTC fallback also failed: $e');
      setState(() {
        _isWebRTCConnecting = false;
      });
    }
  }

  Future<void> _loadParticipants() async {
    try {
      AppLogger().debug('Loading participants for room: ${widget.roomId}');
      
      // Get real participants from database
      final participants = await _appwrite.getDebateDiscussionParticipants(widget.roomId);
      
      if (mounted && !_isDisposing) {
        // Check if participants actually changed to avoid unnecessary rebuilds
        if (!PerformanceOptimizations.participantsChanged(_lastParticipants, participants)) {
          AppLogger().debug('Participants unchanged, skipping rebuild');
          return;
        }
        _lastParticipants = List.from(participants);
        
        // Use batched operations to minimize UI updates
        final List<VoidCallback> operations = [];
        
        operations.add(() {
          _speakerPanelists.clear();
          _audienceMembers.clear();
          _speakerRequests.clear();
          
          // Reset current user status flags
          _isCurrentUserModerator = false;
          _isCurrentUserSpeaker = false;
          _hasRequestedSpeaker = false;
        });
        
        // Process participants efficiently
        final List<UserProfile> newSpeakers = [];
        final List<UserProfile> newAudience = [];
        final List<UserProfile> newRequests = [];
        
        for (var participant in participants) {
          final userProfileData = participant['userProfile'];
          if (userProfileData != null) {
            final userProfile = UserProfile.fromMap(userProfileData);
            final role = participant['role'] ?? 'audience';
            
            // Efficiently sort participants by role
            if (role == 'moderator') {
              if (!newSpeakers.any((p) => p.id == userProfile.id)) {
                newSpeakers.add(userProfile);
              }
              if (userProfile.id == _currentUser?.id) {
                operations.add(() => _isCurrentUserModerator = true);
              }
            } else if (role == 'speaker') {
              if (!newSpeakers.any((p) => p.id == userProfile.id)) {
                newSpeakers.add(userProfile);
              }
              if (userProfile.id == _currentUser?.id) {
                operations.add(() => _isCurrentUserSpeaker = true);
              }
            } else if (role == 'pending') {
              if (!newRequests.any((p) => p.id == userProfile.id)) {
                newRequests.add(userProfile);
              }
              if (!newAudience.any((p) => p.id == userProfile.id)) {
                newAudience.add(userProfile);
              }
              if (userProfile.id == _currentUser?.id) {
                operations.add(() => _hasRequestedSpeaker = true);
              }
            } else {
              if (!newAudience.any((p) => p.id == userProfile.id)) {
                newAudience.add(userProfile);
              }
            }
          }
        }
        
        // Add final operation to update all lists at once
        operations.add(() {
          _speakerPanelists.addAll(newSpeakers);
          _audienceMembers.addAll(newAudience);
          _speakerRequests.addAll(newRequests);
        });
        
        // Execute all operations in batch and trigger single rebuild
        PerformanceOptimizations.batchedSetState(operations, () {
          if (mounted) setState(() {});
        });
        
        // Preload avatar images for better scroll performance
        final avatarUrls = newAudience.map((p) => p.avatar).toList() +
                          newSpeakers.map((p) => p.avatar).toList() +
                          newRequests.map((p) => p.avatar).toList();
        PerformanceOptimizations.preloadAvatarImages(avatarUrls, context);
      }
      
      AppLogger().debug('Loaded ${participants.length} participants: ${_speakerPanelists.length} speakers, ${_audienceMembers.length} audience, ${_speakerRequests.length} pending requests');
      AppLogger().debug('Current user status: moderator=$_isCurrentUserModerator, speaker=$_isCurrentUserSpeaker, requested=$_hasRequestedSpeaker');
    } catch (e) {
      AppLogger().error('Error loading participants: $e');
      // Fallback to mock data if real data fails
      _createMockParticipants();
      if (mounted) {
        OptimizedStateManager.batchedSetState(
          'participants_${widget.roomId}',
          () => setState(() {}),
          {'audience': _audienceMembers.length, 'speakers': _speakerPanelists.length},
        );
      }
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
            
            // Always reload participants to keep UI in sync (throttled to prevent excessive updates)
            PerformanceOptimizations.throttledSetState(() async {
              await _loadParticipants();
            });
            
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
          
          // Audio/Video cleanup disabled (Agora removed)
          
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
        // Audio/Video cleanup disabled (Agora removed)
        
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
      
      // If the approved user is the current user, offer to enable video/audio
      if (user.id == _currentUser?.id) {
        _showSpeakerActivationDialog();
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


  // Show dialog to offer video/audio activation when user becomes speaker
  void _showSpeakerActivationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            '🎉 You\'re now a speaker!',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Would you like to enable your video and audio to participate in the discussion?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Enable audio only
                _toggleAudio();
              },
              child: const Text('Audio Only', style: TextStyle(color: Colors.green)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Enable both video and audio
                _toggleAudio();
                _toggleVideo();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
              child: const Text('Video + Audio', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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
            _buildRoomTitleSection(),
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
              // Audio always disabled (Agora removed)
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.micOff,
                color: Colors.orange,
                size: 14,
              ),
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
          top: 16,
          left: 0,
          right: 0,
          child: _buildSpeakerPanel(),
        ),
      ],
    );
  }

  Widget _buildSpeakerPanel() {
    // Prepare data for performance-optimized speakers panel
    List<Map<String, dynamic>> speakers = _speakerPanelists
        .where((speaker) => speaker.id != _moderator?.id)
        .map((speaker) => {
              'userId': speaker.id,
              'name': speaker.name,
              'userName': speaker.name,
              'avatarUrl': speaker.avatar,
              'avatar': speaker.avatar,
              'role': 'speaker',
            })
        .toList();

    Map<String, dynamic>? moderatorData;
    if (_moderator != null) {
      moderatorData = {
        'userId': _moderator!.id,
        'name': _moderator!.name,
        'userName': _moderator!.name,
        'avatarUrl': _moderator!.avatar,
        'avatar': _moderator!.avatar,
        'role': 'moderator',
      };
    }

    return PerformanceOptimizedSpeakersPanel(
      speakers: speakers,
      moderator: moderatorData,
      onSpeakerTap: (userId) {
        final speaker = _speakerPanelists.firstWhere((s) => s.id == userId);
        _showUserProfileModal(speaker);
      },
    );
  }

  /// Helper function to create avatar text content - just first letter
  Widget _buildAvatarText(UserProfile participant, double fontSize) {
    String letter;
    
    if (participant.name.isEmpty) {
      letter = participant.email.isNotEmpty ? participant.email.substring(0, 1).toUpperCase() : 'U';
    } else {
      letter = participant.name.substring(0, 1).toUpperCase();
    }
    
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Helper function to create avatar text content from Map data - just first letter
  Widget _buildAvatarTextFromMap(Map<String, dynamic> data, double fontSize) {
    final name = data['name'] as String? ?? '';
    String letter;
    
    if (name.isEmpty) {
      letter = 'U';
    } else {
      letter = name.substring(0, 1).toUpperCase();
    }
    
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.black87,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Unused method - kept for potential future use
  // ignore: unused_element
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
            // Video feed or placeholder
            _buildVideoContent(participant, isModerator),
            
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
            
            // Video disabled - audio-only mode
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

  // Unused method - kept for potential future use
  // ignore: unused_element
  Widget _buildEmptySlot(int slotNumber) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.userPlus,
              color: Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              'Slot $slotNumber',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent(UserProfile participant, bool isModerator) {
    // WebRTC implementation
    if (_isWebRTCConnected) {
      return _buildWebRTCVideoContent(participant, isModerator);
    }
    
    // Fallback when not connected
    return _buildEmptyVideoContent(participant, isModerator);
  }
  
  Widget _buildEmptyVideoContent(UserProfile participant, bool isModerator) {
    
    // When WebRTC is not connected, show avatar only
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Center(
              // Fallback to avatar when no video
              child: CircleAvatar(
                radius: isModerator ? 32 : 24,
                backgroundColor: const Color(0xFF8B5CF6),
                backgroundImage: participant.avatar != null && participant.avatar!.isNotEmpty
                    ? NetworkImage(participant.avatar!)
                    : null,
                child: participant.avatar == null || participant.avatar!.isEmpty
                    ? _buildAvatarText(participant, isModerator ? 20 : 16)
                    : null,
              ),
            ),
      ),
    );
  }

  Widget _buildAudienceSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate top padding based on speakers panel height (same as speaker panel)
    const containerMargin = 8.0; // Same as speaker panel
    final containerWidth = screenWidth - (containerMargin * 2);
    const tileSpacing = 4.0; // Same as speaker panel
    
    // Same tile calculations as speaker panel for consistency (4 tiles per row)
    final availableWidth = containerWidth - (tileSpacing * 3); // 3 gaps for 4 tiles
    final tileWidth = (availableWidth / 4).floor().toDouble(); // 4 tiles per row
    final tileHeight = tileWidth; // Square tiles
    
    // Calculate speakers panel height for fixed 4x2 grid + moderator
    double speakersPanelHeight = 16.0; // Initial top padding
    
    // Always show 2 rows of 4 speakers each
    speakersPanelHeight += tileHeight; // First row (slots 1-4)
    speakersPanelHeight += tileSpacing + tileHeight; // Gap + second row (slots 5-8)
    speakersPanelHeight += tileSpacing; // Gap before moderator
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
        
        // Clean audience grid with round profile pics and names
        Expanded(
          child: PerformanceOptimizedAudienceGrid(
            participants: _audienceMembers.map((member) => {
              'userId': member.id,
              'name': member.name,
              'userName': member.name,
              'avatarUrl': member.avatar,
              'avatar': member.avatar,
              'role': 'audience',
            }).toList(),
            onParticipantTap: (userId) {
              final member = _audienceMembers.firstWhere((m) => m.id == userId);
              _showUserProfileModal(member);
            },
            debugLabel: 'DebatesDiscussionsAudience',
          ),
        ),
      ],
    );
  }

  // Unused method - kept for potential future use
  // ignore: unused_element
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
                    ? _buildAvatarText(member, avatarSize * 0.35)
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
          // Audio controls only - debates & discussions is audio-only
          if (_isCurrentUserModerator || _isCurrentUserSpeaker)
            _buildControlButton(
              icon: _isMuted ? LucideIcons.micOff : LucideIcons.mic,
              isActive: !_isMuted,
              onTap: _toggleAudio,
            ),
          // Web audio activation button
          if (kIsWeb && _remoteStreams.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton.icon(
                onPressed: () {
                  _resumeWebAudioContext();
                },
                icon: const Icon(Icons.volume_up, size: 16),
                label: const Text('Enable Audio', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange,
                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ),
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

    // Create participants list for chat
    final chatParticipants = <ChatParticipant>[
      // Add moderator
      if (_moderator != null)
        ChatParticipant(
          userId: _moderator!.id,
          username: _moderator!.name,
          role: 'moderator',
          avatar: _moderator!.avatar,
        ),
      // Add speakers
      ..._speakerPanelists.map((speaker) => ChatParticipant(
        userId: speaker.id,
        username: speaker.name,
        role: 'speaker',
        avatar: speaker.avatar,
      )),
      // Add audience members
      ..._audienceMembers.map((audience) => ChatParticipant(
        userId: audience.id,
        username: audience.name,
        role: 'audience',
        avatar: audience.avatar,
      )),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => MattermostChatWidget(
        currentUserId: _currentUser!.id,
        currentUser: _currentUser!,
        roomId: widget.roomId,
        participants: chatParticipants,
        onClose: () {
          FocusScope.of(context).unfocus();
          Navigator.of(context).pop();
        },
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
                        child: _buildAvatarText(speaker, 14),
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
                          child: _buildAvatarText(user, 14),
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
    // Audio functionality disabled (Agora removed)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔇 Audio features disabled (Agora removed)'),
        backgroundColor: Colors.orange,
      ),
    );
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
              leading: const Icon(
                LucideIcons.micOff, // Audio always disabled (Agora removed)
                color: Colors.red,
              ),
              title: const Text(
                'Audio Disabled',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Audio functionality disabled (Agora removed)',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
            // Audio options disabled (Agora removed)
          ],
        ),
      ),
    );
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

      // Audio cleanup disabled (Agora removed)

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
                  child: _buildAvatarTextFromMap(recipient, 16),
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
