import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../models/timer_state.dart' as timer_models;
import '../services/websocket_webrtc_service.dart';
import '../services/appwrite_service.dart';
import '../services/firebase_gift_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/user_profile_bottom_sheet.dart';
import '../widgets/instant_message_bell.dart';
import '../widgets/challenge_bell.dart';
import '../widgets/appwrite_timer_widget.dart';
import '../screens/email_compose_screen.dart';
import '../widgets/mattermost_chat_widget.dart';
import '../models/discussion_chat_message.dart';
import '../constants/appwrite.dart';
import '../core/logging/app_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:audio_session/audio_session.dart' as audio_session;

class OpenDiscussionRoomScreen extends StatefulWidget {
  final Room room;

  const OpenDiscussionRoomScreen({
    super.key,
    required this.room,
  });

  @override
  State<OpenDiscussionRoomScreen> createState() => _OpenDiscussionRoomScreenState();
}

class _OpenDiscussionRoomScreenState extends State<OpenDiscussionRoomScreen> {
  final AppwriteService _appwriteService = AppwriteService();
  final FirebaseGiftService _firebaseGiftService = FirebaseGiftService();
  // final SimpleWebRTCService _audioService = SimpleWebRTCService();
  // Using WebSocketWebRTCService for Open Discussion (was connecting successfully)
  final WebSocketWebRTCService _audioService = WebSocketWebRTCService();
  
  // Wrapper properties for WebSocketWebRTCService compatibility
  bool get _audioServiceIsMuted => _isMuted;
  int get _audioServiceConnectedPeersCount => 0; // WebSocket doesn't track this
  
  Future<void> _audioServiceToggleMute() async {
    // WebSocketWebRTCService doesn't have built-in mute, handle locally
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (final track in audioTracks) {
        track.enabled = _isMuted; // Toggle
      }
      if (mounted) {
        setState(() {
          _isMuted = !_isMuted;
        });
      }
    }
  }

  Future<void> _toggleMute() async {
    if (_isAudioConnected) {
      await _audioServiceToggleMute();
      if (mounted) {
        setState(() {
          _isMuted = _audioServiceIsMuted;
        });
      }
      debugPrint("🔇 Audio ${_isMuted ? 'muted' : 'unmuted'}");
    }
  }
  
  bool _isHandRaised = false;
  String? _currentAppwriteUserId; // Current user's Appwrite ID
  Map<String, dynamic>? _userParticipation; // Current user's room participation data
  final List<Map<String, dynamic>> _participants = []; // Real participants from Appwrite
  final Map<String, UserProfile> _userProfiles = {}; // Cache of user profiles
  StreamSubscription? _realtimeSubscription; // Real-time subscription
  StreamSubscription? _unreadMessagesSubscription; // Instant messages subscription
  int _currentUserCoinBalance = 0; // Firebase coin balance (separate from Appwrite profile)
  final Set<String> _handsRaised = {}; // Track users with hands raised
  int _reconnectAttempts = 0; // Track reconnection attempts
  static const int _maxReconnectAttempts = 5; // Maximum reconnection attempts
  
  // Chat state - now handled via modal bottom sheet
  bool _isRealtimeHealthy = true; // Track realtime connection health
  
  // Timer functionality
  int _speakingTime = 300; // Start with 5 minutes (300 seconds) for countdown
  Timer? _speakingTimer;
  Timer? _fallbackRefreshTimer; // Fallback timer for when realtime fails
  
  // Audio player for timer sounds
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _thirtySecondChimePlayed = false; // Track if 30-sec chime already played
  
  // Audio state
  bool _isAudioConnected = false;
  bool _isAudioConnecting = false;
  bool _isMuted = false;
  String? _previousUserRole; // Track previous role to detect role changes
  // Video state removed - audio-only for now
  
  // Audio stream management for SimpleMediaSoupService
  final Map<String, RTCVideoRenderer> _remoteAudioRenderers = {};
  final Map<String, MediaStream> _remoteStreams = {};
  MediaStream? _localStream;
  
  // Scarlet and Purple theme colors (matching app theme)
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color lightScarlet = Color(0xFFFFF1F0);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);
  static const Color darkGray = Color(0xFF2D2D2D);
  
  @override
  void initState() {
    super.initState();
    _initializeAudioPlayer();
    _initializeRoom();
    _initializeInstantMessaging();
    _initializeAudio();
  }


  @override
  void dispose() {
    debugPrint('🧹 Disposing OpenDiscussionRoomScreen');
    
    // Remove audio service listener
    // WebSocketWebRTCService doesn't have listeners
    // _audioService.removeListener(_onAudioServiceChanged);
    
    _realtimeSubscription?.cancel();
    _unreadMessagesSubscription?.cancel();
    _speakingTimer?.cancel();
    _fallbackRefreshTimer?.cancel();
    _audioPlayer.dispose();
    _audioService.disconnect();
    
    // Clean up audio renderers
    for (var renderer in _remoteAudioRenderers.values) {
      renderer.srcObject = null;
      renderer.dispose();
    }
    _remoteAudioRenderers.clear();
    _remoteStreams.clear();
    
    // Clear audio service callbacks to prevent setState after dispose
    _audioService.onConnected = null;
    _audioService.onError = null;
    _audioService.onDisconnected = null;
    _audioService.onLocalStream = null;
    _audioService.onRemoteStream = null;
    _audioService.onPeerJoined = null;
    _audioService.onPeerLeft = null;
    
    _leaveRoomData();
    super.dispose();
  }

  Future<void> _initializeAudioPlayer() async {
    try {
      // Initialize audio player
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      debugPrint('🎵 Audio player initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing audio player: $e');
    }
  }

  Future<void> _createAudioRenderer(String peerId, MediaStream stream) async {
    try {
      // Create and initialize audio renderer if it doesn't exist
      if (!_remoteAudioRenderers.containsKey(peerId)) {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        
        debugPrint("🎧 Initialized audio renderer for $peerId");
        
        _remoteAudioRenderers[peerId] = renderer;
      }
      
      // Assign the stream to the renderer
      _remoteAudioRenderers[peerId]!.srcObject = stream;
      debugPrint("🔊 Audio stream assigned to renderer for $peerId");
      
      // For debugging - check audio tracks
      final audioTracks = stream.getAudioTracks();
      debugPrint("🎵 Stream has ${audioTracks.length} audio tracks");
      for (var track in audioTracks) {
        debugPrint("🎵 Audio track: id=${track.id}, enabled=${track.enabled}, kind=${track.kind}");
      }
      
    } catch (e) {
      debugPrint("❌ Failed to create audio renderer for $peerId: $e");
    }
  }

  void _resumeWebAudioContext() async {
    if (kIsWeb) {
      try {
        // On web, audio context is suspended by default and needs user interaction
        debugPrint('🔊 [Web] Ensuring audio context is resumed for WebRTC playback');
        
        // Force update the UI to ensure audio renderers are properly mounted
        if (mounted) {
          setState(() {
            // This triggers a rebuild which can help with audio renderer mounting
          });
        }
        
        // For each audio renderer, ensure the stream is properly assigned
        for (var entry in _remoteAudioRenderers.entries) {
          final peerId = entry.key;
          final renderer = entry.value;
          if (_remoteStreams.containsKey(peerId)) {
            renderer.srcObject = _remoteStreams[peerId];
            debugPrint('🔊 [Web] Re-assigned stream to renderer for $peerId');
          }
        }
        
      } catch (e) {
        debugPrint('⚠️ [Web] Audio context warning: $e');
      }
    }
  }

  Future<void> _initializeInstantMessaging() async {
    try {
      // Instant messaging disabled (Agora removed)
      AppLogger().debug('📱 Instant messaging disabled in open discussion (Agora removed)');
    } catch (e) {
      debugPrint('❌ Failed to initialize instant messaging: $e');
    }
  }

  Future<void> _initializeAudio() async {
    debugPrint('🎤 Initializing WebRTC audio for Open Discussion room');
    
    // Set up audio service callbacks
    _audioService.onConnected = () {
      debugPrint('🔄 [OpenDiscussion] onConnected callback triggered');
      
      // Always update audio state for functionality
      _isAudioConnected = true;
      _isAudioConnecting = false;
      _isMuted = _audioServiceIsMuted;
      
      if (mounted) {
        setState(() {
          _isAudioConnected = true;
          _isAudioConnecting = false;
          _isMuted = _audioServiceIsMuted; // Sync mute state
        });
        debugPrint('✅ [OpenDiscussion] Audio connected - UI updated (connected: $_isAudioConnected, connecting: $_isAudioConnecting)');
      } else {
        debugPrint('✅ [OpenDiscussion] Audio connected - state updated (widget not mounted, UI not updated)');
      }
    };
    
    _audioService.onDisconnected = () {
      if (mounted) {
        setState(() {
          _isAudioConnected = false;
          _isAudioConnecting = false;
        });
        debugPrint('📡 Audio disconnected from Open Discussion room');
      }
    };
    
    _audioService.onError = (error) {
      if (mounted) {
        setState(() {
          _isAudioConnecting = false;
        });
        debugPrint('❌ Audio error: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio connection error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    };
    
    // Listen to audio service changes for peer count updates
    // WebSocketWebRTCService doesn't have listeners
    // _audioService.addListener(_onAudioServiceChanged);
    
    // Handle remote audio streams
    _audioService.onRemoteStream = (peerId, stream, userId, role) async {
      debugPrint('🎵 [OpenDiscussion] Received remote audio stream from peer: $peerId');
      debugPrint('🎵 [OpenDiscussion] Audio tracks in stream: ${stream.getAudioTracks().length}');
      
      // Create audio renderer for this peer (always do this for audio functionality)
      await _createAudioRenderer(peerId, stream);
      
      // Enable audio tracks for playback (always do this for audio)
      final audioTracks = stream.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = true;
        debugPrint('🔊 [OpenDiscussion] Enabled audio track from $peerId: ${track.id}');
      }
      
      // For web: Ensure audio context is resumed (browser autoplay policy)
      if (kIsWeb) {
        _resumeWebAudioContext();
      }
      
      if (mounted) {
        setState(() {
          _remoteStreams[peerId] = stream;
          _isAudioConnected = true; // Ensure connected state when we receive audio
          _isAudioConnecting = false;
        });
      } else {
        // Still store streams even if not mounted for audio functionality
        _remoteStreams[peerId] = stream;
        _isAudioConnected = true;
        _isAudioConnecting = false;
      }
      
      debugPrint('✅ [OpenDiscussion] Audio stream from $peerId is now active and rendering');
      debugPrint('🎤 [OpenDiscussion] Remote streams count: ${_remoteStreams.length}');
    };
    
    // Handle local audio stream
    _audioService.onLocalStream = (stream) {
      debugPrint('🎤 Received local audio stream');
      debugPrint('🎤 Local audio tracks: ${stream.getAudioTracks().length}');
      
      // Always store local stream for audio functionality
      _localStream = stream;
      _isMuted = _audioServiceIsMuted;
      
      if (mounted) {
        setState(() {
          _localStream = stream;
          _isMuted = _audioServiceIsMuted;
        });
      }
    };
    
    // Handle peer events
    _audioService.onPeerJoined = (peerId, userId, role) {
      debugPrint('👤 Peer joined audio: $peerId');
      if (mounted) {
        setState(() {
          // Trigger UI update to show new peer count
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A participant joined the audio'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    };
    
    _audioService.onPeerLeft = (peerId) {
      debugPrint('👋 Peer left audio: $peerId');
      if (mounted) {
        setState(() {
          _remoteStreams.remove(peerId);
          // Trigger UI update to show updated peer count
          _remoteAudioRenderers[peerId]?.srcObject = null;
          _remoteAudioRenderers[peerId]?.dispose();
          _remoteAudioRenderers.remove(peerId);
        });
      }
    };
  }

  Future<void> _initializeRoom() async {
    try {
      // Get current user
      final user = await _appwriteService.getCurrentUser();
      if (user != null) {
        _currentAppwriteUserId = user.$id;
        
        // Load current user's profile
        await _loadUserProfile(user.$id);
        
        // Load Firebase coin balance
        await _loadFirebaseCoinBalance();
        
        // Join the room as a participant
        await _joinRoom();
        
        // Load real participants from database
        await _loadRoomParticipants();
        
        // Load hand raises from participant metadata
        await _loadHandRaisesFromParticipants();
        
        // Load initial timer state from database
        await _loadInitialTimerState();
        
        // Set up real-time subscription for participant changes
        _setupRealtimeSubscription();
        
        // Auto-connect to audio if user is speaker or moderator (after participants are loaded)
        await _checkAndAutoConnectAudio();
      }
    } catch (e) {
      debugPrint('Error initializing room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining room: $e'),
            backgroundColor: scarletRed,
          ),
        );
      }
    }
  }
  
  Future<void> _joinRoom() async {
    try {
      // Determine initial role - creator is moderator, others start as audience
      final isCurrentUserModerator = widget.room.createdBy == _currentAppwriteUserId;
      final initialRole = isCurrentUserModerator ? 'moderator' : 'audience';
      
      // Join the room in the database
      await _appwriteService.joinRoom(
        roomId: widget.room.id,
        userId: _currentAppwriteUserId!,
        role: initialRole,
      );
      
      debugPrint('✅ Joined room ${widget.room.id} as $initialRole');
    } catch (e) {
      debugPrint('❌ Error joining room: $e');
      // Continue anyway - user might already be in room
    }
  }
  
  Future<void> _loadRoomParticipants() async {
    try {
      // Get room data with participants
      final roomData = await _appwriteService.getRoom(widget.room.id);
      if (roomData != null) {
        // Extract participants from room data
        final participants = roomData['participants'] as List<dynamic>? ?? [];
        _participants.clear();
        
        debugPrint('🔍 Loading ${participants.length} participants from database');
        
        // Load each participant's profile and build participants list
        for (final participantData in participants) {
          final userId = participantData['userId'];
          final role = participantData['role'];
          
          debugPrint('👤 Found participant: $userId with role: $role');
          
          // Add to participants list
          Map<String, dynamic> metadata = {};
          try {
            final metadataField = participantData['metadata'];
            if (metadataField != null) {
              if (metadataField is String) {
                metadata = json.decode(metadataField);
              } else if (metadataField is Map<String, dynamic>) {
                metadata = metadataField;
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error parsing metadata for user $userId: $e');
            metadata = {};
          }
          
          _participants.add({
            'userId': userId,
            'role': role,
            'status': participantData['status'],
            'joinedAt': participantData['joinedAt'],
            'metadata': metadata,
          });
          
          // Load user profile if not already cached
          if (!_userProfiles.containsKey(userId)) {
            await _loadUserProfile(userId);
          }
        }
        
        // Set current user's participation data
        _userParticipation = _participants.firstWhere(
          (p) => p['userId'] == _currentAppwriteUserId,
          orElse: () => {
            'userId': _currentAppwriteUserId!,
            'role': 'audience',
            'status': 'joined',
          },
        );
        
        debugPrint('✅ Loaded ${_participants.length} participants');
        debugPrint('📊 Speakers: ${_speakers.length}, Audience: ${_audience.length}, Moderator: ${_moderator != null ? 1 : 0}');
        debugPrint('🎭 Current user role: ${_userParticipation?['role']}');
        
        // Check for role changes and handle audio connection appropriately
        final userRole = _userParticipation?['role'];
        final previousRole = _previousUserRole; // Store previous role to detect changes
        _previousUserRole = userRole; // Update previous role for next comparison
        
        debugPrint('🎭 Role change detection: previous=$previousRole, current=$userRole');
        
        if (userRole == 'speaker' || userRole == 'moderator') {
          debugPrint('🎤 User role detected as $userRole, checking audio connection...');
          debugPrint('🔍 Current audio state: connecting=$_isAudioConnecting, connected=$_isAudioConnected');
          
          // Check if we need to reinitialize audio for speaker role
          // This happens when user was connected as audience and is now promoted to speaker
          if (_isAudioConnected && userRole == 'speaker' && previousRole == 'audience') {
            debugPrint('🔄 User promoted from audience to speaker - reinitializing audio with microphone access...');
            await _reinitializeAudioForSpeaker();
          } else if (!_isAudioConnected && !_isAudioConnecting) {
            debugPrint('🎤 Starting new audio connection...');
            _connectToAudio();
          } else {
            debugPrint('🎤 Audio already connected/connecting, skipping...');
          }
        } else if (userRole == 'audience') {
          // Handle demotion from speaker/moderator to audience
          if (_isAudioConnected && (previousRole == 'speaker' || previousRole == 'moderator')) {
            debugPrint('🔽 User demoted from $previousRole to audience - reinitializing as receive-only...');
            await _reinitializeAudioForAudience();
          } else if (!_isAudioConnected && !_isAudioConnecting) {
            debugPrint('👂 Starting audience audio connection (receive-only)...');
            _connectToAudio();
          }
        }
        
        // Debug: Print all participants with their roles
        debugPrint('👥 DEBUG: All participants list:');
        for (int i = 0; i < _participants.length; i++) {
          final p = _participants[i];
          debugPrint('👥 DEBUG: [$i] userId: ${p['userId']}, role: ${p['role']}, status: ${p['status']}');
        }
        
        // Load hand raises from participant metadata
        await _loadHandRaisesFromParticipants();
        
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading room participants: $e');
    }
  }
  
  void _setupRealtimeSubscription() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ Maximum realtime reconnection attempts reached. Operating in offline mode.');
      if (mounted) {
        setState(() {
          _isRealtimeHealthy = false;
        });
      }
      _startFallbackRefresh(); // Start fallback refresh when max attempts reached
      return;
    }

    try {
      // Cancel any existing subscription first
      _realtimeSubscription?.cancel();
      
      debugPrint('🔄 Setting up realtime subscription (attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts)');
      
      // Subscribe to room participants changes
      final subscription = _appwriteService.realtimeInstance.subscribe([
        'databases.arena_db.collections.room_participants.documents',
        'databases.arena_db.collections.rooms.documents',
      ]);
      
      _realtimeSubscription = subscription.stream.listen(
        (response) {
          try {
            // Reset reconnect attempts on successful message
            _reconnectAttempts = 0;
            
            if (!mounted) return;
            
            // Note: response is guaranteed to be non-null by the realtime API
            
            // Check payload type
            final payload = response.payload as Map;
            
            debugPrint('🔔 Room participant real-time update received');
            
            // Check if this update affects our room
            if (payload['roomId'] == widget.room.id) {
              debugPrint('🔄 Refreshing participants for room update');
              
              // Update realtime health status
              if (!_isRealtimeHealthy && mounted) {
                setState(() {
                  _isRealtimeHealthy = true;
                });
                debugPrint('✅ Realtime connection restored');
                _stopFallbackRefresh(); // Stop fallback refresh when realtime is restored
              }
              
              _loadRoomParticipants();
            }
            
            // Check for room document updates (including timer state)
            if (response.events.any((event) => event.contains('rooms.documents'))) {
              debugPrint('🏠 Room document updated, checking for timer changes');
              _handleRoomDocumentUpdate(Map<String, dynamic>.from(payload));
            }
          } catch (e) {
            debugPrint('❌ Error processing room participant update: $e');
            // Don't rethrow - just log and continue
          }
        },
        onError: (error) {
          debugPrint('❌ Room participant subscription error: $error');
          _reconnectAttempts++;
          
          if (mounted) {
            setState(() {
              _isRealtimeHealthy = false;
            });
          }
          
          // Exponential backoff: 2^attempt seconds (2, 4, 8, 16, 32)
          final delaySeconds = 2 << _reconnectAttempts.clamp(0, 5);
          
          if (_reconnectAttempts < _maxReconnectAttempts) {
            debugPrint('🔄 Scheduling realtime reconnection in ${delaySeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
            
            Future.delayed(Duration(seconds: delaySeconds), () {
              if (mounted) {
                _setupRealtimeSubscription();
              }
            });
          } else {
            debugPrint('❌ Maximum realtime reconnection attempts reached');
          }
          
          // Start fallback refresh when realtime connection is unhealthy
          _startFallbackRefresh();
        },
        onDone: () {
          debugPrint('⚠️ Room participant subscription closed');
          if (mounted) {
            setState(() {
              _isRealtimeHealthy = false;
            });
          }
          
          // Start fallback refresh when realtime connection is unhealthy
          _startFallbackRefresh();
        },
      );
      
      debugPrint('🔔 Real-time room participant subscription active');
    } catch (e) {
      debugPrint('❌ Error setting up real-time subscription: $e');
      _reconnectAttempts++;
      
      if (mounted) {
        setState(() {
          _isRealtimeHealthy = false;
        });
      }
      
      // Exponential backoff for setup errors too
      final delaySeconds = 2 << _reconnectAttempts.clamp(0, 5);
      
      if (_reconnectAttempts < _maxReconnectAttempts) {
        Future.delayed(Duration(seconds: delaySeconds), () {
          if (mounted) {
            _setupRealtimeSubscription();
          }
        });
      }
      
      // Start fallback refresh when realtime connection is unhealthy
      _startFallbackRefresh();
    }
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      final profile = await _appwriteService.getUserProfile(userId);
      if (profile != null && mounted) {
        setState(() {
          _userProfiles[userId] = profile;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile for $userId: $e');
    }
  }

  Future<void> _loadFirebaseCoinBalance() async {
    debugPrint('🎁 DEBUG: _loadFirebaseCoinBalance called');
    debugPrint('🎁 DEBUG: _currentAppwriteUserId = $_currentAppwriteUserId');
    
    if (_currentAppwriteUserId == null) {
      debugPrint('🎁 DEBUG: No current user ID, cannot load coin balance');
      return;
    }
    
    try {
      debugPrint('🎁 DEBUG: Calling FirebaseGiftService.getUserCoinBalance...');
      final balance = await _firebaseGiftService.getUserCoinBalance(_currentAppwriteUserId!);
      debugPrint('🎁 DEBUG: Firebase returned balance: $balance');
      
      if (mounted) {
        setState(() {
          _currentUserCoinBalance = balance;
        });
      }
      debugPrint('✅ Firebase: Loaded coin balance: $balance for user $_currentAppwriteUserId');
    } catch (e) {
      debugPrint('❌ Firebase: Error loading coin balance: $e');
      // Set default 100 coins if Firebase fails
      if (mounted) {
        setState(() {
          _currentUserCoinBalance = 100;
        });
      }
      debugPrint('🎁 DEBUG: Set default 100 coins due to Firebase error');
    }
  }




  void _handleRoomDocumentUpdate(Map<String, dynamic> payload) {
    try {
      // Only non-moderators should sync timer state from database
      if (_isCurrentUserModerator) {
        debugPrint('🕐 Ignoring timer update for moderator');
        return;
      }

      final settings = payload['settings'] as Map<String, dynamic>?;
      if (settings == null) return;

      final timerState = settings['timer'] as Map<String, dynamic>?;
      if (timerState == null) return;

      final updatedBy = timerState['updatedBy'] as String?;
      if (updatedBy == _currentAppwriteUserId) {
        debugPrint('🕐 Ignoring timer update from self');
        return;
      }

      final newSpeakingTime = timerState['speakingTime'] as int? ?? 300;

      debugPrint('🕐 Received timer update from moderator: ${newSpeakingTime}s');

      if (mounted) {
        setState(() {
          _speakingTime = newSpeakingTime;
          _thirtySecondChimePlayed = false; // Reset chime for new timer state
        });
      }

    } catch (e) {
      debugPrint('❌ Error handling timer update: $e');
    }
  }

  void _startLocalTimer() {
    _speakingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_speakingTime > 0) {
        if (mounted) {
          setState(() {
            _speakingTime--;
            
            // Play chime at 30 seconds remaining (only once)
            if (_speakingTime == 30 && !_thirtySecondChimePlayed) {
              _thirtySecondChimePlayed = true;
              _playChimeSound();
            }
          });
        }
        
      } else {
        // Timer reached zero
        timer.cancel();
        _playBuzzerSound();
        
        if (mounted) {
          setState(() {
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Timer finished! ⏰'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  Future<void> _loadInitialTimerState() async {
    try {
      final roomData = await _appwriteService.getRoom(widget.room.id);
      if (roomData == null) return;

      final settings = roomData['settings'] as Map<String, dynamic>?;
      if (settings == null) return;

      final timerState = settings['timer'] as Map<String, dynamic>?;
      if (timerState == null) return;

      final speakingTime = timerState['speakingTime'] as int? ?? 300;
      final isRunning = timerState['isTimerRunning'] as bool? ?? false;
      final isPaused = timerState['isTimerPaused'] as bool? ?? false;

      debugPrint('🕐 Loading initial timer state: ${speakingTime}s, running: $isRunning, paused: $isPaused');

      if (mounted) {
        setState(() {
          _speakingTime = speakingTime;
          _thirtySecondChimePlayed = false;
        });
      }

      // Start timer if it should be running
      if (isRunning && !isPaused) {
        _startLocalTimer();
      }

    } catch (e) {
      debugPrint('❌ Error loading initial timer state: $e');
    }
  }


  // Load hand raises from participant metadata (no database collection needed)
  Future<void> _loadHandRaisesFromParticipants() async {
    debugPrint('🔍 Loading hand raises from participants...');
    
    final newHandsRaised = <String>{};
    for (final participant in _participants) {
      final metadata = participant['metadata'] as Map<String, dynamic>? ?? {};
      final handRaised = metadata['handRaised'] as bool? ?? false;
      final userId = participant['userId'];
      
      if (handRaised && userId != null) {
        newHandsRaised.add(userId);
        
        // Show notification to moderator for new hand raises
        if (_isCurrentUserModerator && !_handsRaised.contains(userId) && userId != _currentAppwriteUserId) {
          _showHandRaiseModalToModerator(userId);
        }
      }
      
    }
    
    if (mounted) {
      setState(() {
        _handsRaised.clear();
        _handsRaised.addAll(newHandsRaised);
        _isHandRaised = _handsRaised.contains(_currentAppwriteUserId);
      });
    }
    
    debugPrint('✋ Loaded ${_handsRaised.length} hand raises from participants');
  }

  void _showHandRaiseModalToModerator(String userId) {
    if (!mounted) return;
    
    final userProfile = _userProfiles[userId];
    final userName = userProfile?.displayName ?? 'User';
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pan_tool, color: Colors.orange),
            SizedBox(width: 8),
            Text('Hand Raised'),
          ],
        ),
        content: Text('$userName has raised their hand and wants to speak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _promoteToSpeaker(userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Promote to Speaker'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleHandRaise() async {
    if (_currentAppwriteUserId == null) return;

    try {
      final currentRole = _userParticipation?['role'];
      
      // Handle speakers wanting to leave the panel
      if (currentRole == 'speaker') {
        // Show confirmation modal for leaving the panel
        final shouldLeave = await _showLeavePanelConfirmation();
        if (shouldLeave == true) {
          debugPrint('🔽 Speaker confirmed leaving panel - moving back to audience...');
          
          // First update local state to ensure UI updates
          setState(() {
            _isHandRaised = false;
            _handsRaised.remove(_currentAppwriteUserId!);
          });
          
          // Use the same logic as moderator demotion
          debugPrint('🔽 Speaker leaving panel - using moderator demotion logic');
          await _demoteToAudience(_currentAppwriteUserId!);
        }
        return; // Exit - either they left or cancelled
      }
      
      // Handle audience hand raise/lower
      final newHandRaiseState = !_isHandRaised;
      
      // Normal hand raise/lower for audience members
      await _appwriteService.updateParticipantMetadata(
        roomId: widget.room.id,
        userId: _currentAppwriteUserId!,
        metadata: {'handRaised': newHandRaiseState},
      );
      
      if (mounted) {
        setState(() {
          _isHandRaised = newHandRaiseState;
          if (newHandRaiseState) {
            _handsRaised.add(_currentAppwriteUserId!);
          } else {
            _handsRaised.remove(_currentAppwriteUserId!);
          }
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newHandRaiseState 
                ? 'Hand raised! Waiting for moderator approval.'
                : 'Hand lowered.'),
            backgroundColor: newHandRaiseState ? Colors.orange : Colors.grey,
          ),
        );
      }
      
      debugPrint(newHandRaiseState 
        ? '✋ Hand raised by $_currentAppwriteUserId' 
        : '🫴 Hand lowered by $_currentAppwriteUserId');
        
    } catch (e) {
      debugPrint('❌ Error toggling hand raise: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isHandRaised ? 'lower' : 'raise'} hand'),
            backgroundColor: scarletRed,
          ),
        );
      }
    }
  }

  Future<void> _checkAndAutoConnectAudio() async {
    final userRole = _userParticipation?['role'];
    debugPrint('🎤 Checking auto-audio: userRole=$userRole, participation=$_userParticipation');
    
    // In Open Discussion rooms, ALL users (audience, speaker, moderator) can connect to audio
    debugPrint('🎤 Open Discussion room - connecting audio for all users (role: $userRole)');
    
    // Only connect if not already connected or connecting
    if (!_isAudioConnected && !_isAudioConnecting) {
      debugPrint('🎤 Starting audio connection for all users...');
      await _connectToAudio();
    } else {
      debugPrint('🎤 Audio already connected/connecting, skipping...');
    }
  }

  Future<void> _reinitializeAudioForSpeaker() async {
    try {
      debugPrint('🔄 Reinitializing audio connection for speaker role...');
      
      // Disconnect existing audio service if connected
      if (_isAudioConnected) {
        debugPrint('🔌 Disconnecting existing audio connection...');
        await _audioService.disconnect();
        if (mounted) {
          setState(() {
            _isAudioConnected = false;
            _isAudioConnecting = false;
          });
        }
      }
      
      // Brief delay to ensure cleanup
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Reconnect with speaker role
      debugPrint('🎤 Reconnecting with speaker role...');
      await _connectToAudio();
      
    } catch (e) {
      debugPrint('❌ Error reinitializing audio for speaker: $e');
      // Continue anyway - user can try manual connect
    }
  }

  Future<void> _reinitializeAudioForAudience() async {
    try {
      debugPrint('🔽 Reinitializing audio connection for audience role (receive-only)...');
      
      // Disconnect existing audio service if connected
      if (_isAudioConnected) {
        debugPrint('🔌 Disconnecting existing audio connection...');
        await _audioService.disconnect();
        if (mounted) {
          setState(() {
            _isAudioConnected = false;
            _isAudioConnecting = false;
            _isMuted = true; // Force muted state for audience
          });
        }
      }
      
      // Brief delay to ensure cleanup
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Reconnect with audience role (receive-only)
      debugPrint('👂 Reconnecting with audience role (receive-only)...');
      await _connectToAudio();
      
    } catch (e) {
      debugPrint('❌ Error reinitializing audio for audience: $e');
      // Continue anyway - connection should still work for listening
    }
  }

  Future<bool?> _showLeavePanelConfirmation() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap a button
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: darkGray,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: accentPurple, width: 1),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Leave Speakers Panel?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'You are about to move back to the audience. You will lose your speaking privileges and need to raise your hand again to return to the speakers panel.\n\nAre you sure you want to continue?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Cancel
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                foregroundColor: Colors.white70,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Cancel'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Confirm
              style: TextButton.styleFrom(
                backgroundColor: scarletRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Leave Panel'),
              ),
            ),
          ],
        );
      },
    );
  }


  Future<void> _connectToAudio() async {
    debugPrint('🔄 _connectToAudio called - connecting: $_isAudioConnecting, connected: $_isAudioConnected');
    
    // Don't connect if already connected
    if (_isAudioConnected) {
      debugPrint('✅ Audio already connected, skipping connection attempt');
      return;
    }
    
    // Don't allow multiple concurrent connection attempts
    if (_isAudioConnecting) {
      debugPrint('⏭️ Audio connection already in progress, skipping');
      return;
    }
    
    debugPrint('🎤 Starting audio connection to Open Discussion room...');
    if (mounted) {
      setState(() {
        _isAudioConnected = false;
        _isAudioConnecting = true;
      });
    }

    try {
      // Connect to audio using the working SimpleMediaSoupService with audio-only mode
      debugPrint('🎤 Connecting to audio service for Open Discussion');
      debugPrint('🎤 Room ID: ${widget.room.id}');
      debugPrint('🎤 User ID: $_currentAppwriteUserId');
      
      final audioRoomId = 'open-discussion-${widget.room.id}';
      final userId = _currentAppwriteUserId ?? 'guest-${DateTime.now().millisecondsSinceEpoch % 10000}';
      
      // Determine user role for audio connection (same logic as Debates & Discussions)
      String userRole = 'audience'; // Default to audience
      if (_userParticipation?['role'] == 'moderator') {
        userRole = 'moderator';
      } else if (_userParticipation?['role'] == 'speaker') {
        userRole = 'speaker';
      }
      // All others remain as 'audience' for listen-only mode
      
      debugPrint('🎤 Audio connection details:');
      debugPrint('🎤 Server: 172.236.109.9:3006 (Linode WebSocket WebRTC server)');
      debugPrint('🎤 Room ID: $audioRoomId');
      debugPrint('🎤 User ID: $userId');
      debugPrint('🎤 User Role: $userRole');
      
      // Add timeout to prevent getting stuck
      await _audioService.connect(
        '172.236.109.9:3006', // Linode server WebSocket WebRTC
        audioRoomId, // Room ID specific to this discussion
        userId, // User ID
        audioOnly: true, // Audio-only for stability
        role: userRole, // Pass the user's role (now works for all users)
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('❌ Audio connection timeout after 30 seconds');
          throw Exception('Audio connection timeout. Please check your microphone permissions and try again.');
        },
      );
      
      // Wait a bit for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 500));
      
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
        
        debugPrint('🔊 Audio session configured for maximum speaker output');
      } catch (e) {
        debugPrint('❌ Failed to configure audio session: $e');
        // Continue anyway - audio might still work
      }
      
      // Start muted by default
      _isMuted = true;
      await _audioServiceToggleMute();
      
      // Force UI update to show connected state
      if (mounted) {
        setState(() {
          _isAudioConnected = true;
          _isAudioConnecting = false;
          _isMuted = _audioServiceIsMuted;
        });
      }
      
      debugPrint('🎤 Successfully connected to Open Discussion audio - UI state updated');
      
    } catch (e) {
      debugPrint('❌ Error connecting to audio: $e');
      if (mounted) {
        setState(() {
          _isAudioConnecting = false;
          _isAudioConnected = false;
        });
        
        String errorMessage = e.toString();
        if (errorMessage.contains('Permission denied') || 
            errorMessage.contains('NotAllowedError') ||
            errorMessage.contains('Microphone permission denied')) {
          errorMessage = 'Microphone permission required. Please allow microphone access and try again.';
        } else if (errorMessage.contains('timeout')) {
          errorMessage = 'Connection timeout. Check microphone permissions or try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to audio: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _connectToAudio(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _forceResetAudioConnection() async {
    debugPrint('🔄 Force resetting audio connection...');
    
    try {
      // Force disconnect from audio service
      await _audioService.disconnect();
      
      // Reset all audio state
      if (mounted) {
        setState(() {
          _isAudioConnected = false;
          _isAudioConnecting = false;
          _isMuted = false;
        });
      }
      
      // Clear audio renderers
      for (var renderer in _remoteAudioRenderers.values) {
        renderer.srcObject = null;
        renderer.dispose();
      }
      _remoteAudioRenderers.clear();
      _remoteStreams.clear();
      _localStream = null;
      
      debugPrint('✅ Audio connection reset complete');
      
      // Wait a bit before allowing new connections
      await Future.delayed(const Duration(milliseconds: 1000));
      
    } catch (e) {
      debugPrint('⚠️ Error during audio reset: $e');
    }
  }

  /*
  // OLD WEBRTC METHODS - COMMENTED OUT TO FIX COMPILATION
  // All functionality moved to SimpleMediaSoupService
  
  Future<void> _getUserMedia() async {
    try {
      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': false, // Disable to preserve audio volume
          'autoGainControl': true,
          'googEchoCancellation': true,
          'googAutoGainControl': true,
          'googNoiseSuppression': false,
          'googHighpassFilter': false,
          'googAudioMirroring': false,
        },
        'video': false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      debugPrint("🎤 Got audio stream: ${_localStream?.getAudioTracks().length} tracks");
      
      // Ensure local audio tracks are enabled for transmission
      final audioTracks = _localStream!.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = true; // Will be controlled by mute/unmute
        debugPrint("🎙️ Enabled local audio track: ${track.id}");
      }
      
    } catch (e) {
      debugPrint("❌ Failed to get microphone: $e");
      rethrow;
    }
  }

  Future<void> _connectToWebRTCServer() async {
    // DISABLED: WebRTC P2P connection - using MediaSoup SFU instead
    debugPrint('🔌 WebRTC P2P connection disabled - using MediaSoup SFU via SimpleMediaSoupService');
    return;
    
    /*
    try {
      debugPrint('🔌 Creating socket connection to WebRTC server...');
      // DISABLED: WebRTC socket conflicts with MediaSoup PollingOnlySocketIO
      // _socket = io.io('http://172.236.109.9:3000', 
      //   io.OptionBuilder()
      //     .setTransports(['websocket', 'polling'])
      //     .disableAutoConnect()
      //     .setTimeout(15000)
      //     .enableForceNew()
      //     .build()
      // );
      debugPrint('✅ Socket created, setting up event handlers...');

      _socket!.on('connect', (_) {
        debugPrint("🔌 Connected to WebRTC server");
        
        _socket!.emit('join-room', {
          'roomId': widget.room.id,
          'userId': _currentAppwriteUserId ?? 'guest',
          'userName': _userProfiles[_currentAppwriteUserId]?.name ?? 'Guest',
          'roomType': 'open-discussion',
          'isModerator': _userParticipation?['role'] == 'moderator',
        });
      });

      _socket!.on('disconnect', (_) {
        debugPrint("🔌 Disconnected from WebRTC server");
        if (mounted) {
          setState(() {
            _isAudioConnected = false;
          });
        }
      });

      _socket!.on('connect_error', (error) {
        debugPrint("❌ WebRTC connection error: $error");
        if (mounted) {
          setState(() {
            _isAudioConnecting = false;
          });
          // Show user-friendly error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Audio connection failed. Retrying...'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });

      _socket!.on('connect_timeout', (_) {
        debugPrint("❌ Socket connection timeout");
        if (mounted) {
          setState(() {
            _isAudioConnecting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Audio connection timeout. Please check your connection.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });

      _socket!.on('reconnect', (attemptNumber) {
        debugPrint("🔄 Socket reconnected after $attemptNumber attempts");
        if (mounted) {
          setState(() {
            _isAudioConnected = true;
            _isAudioConnecting = false;
          });
        }
      });

      _socket!.on('reconnect_error', (error) {
        debugPrint("❌ Socket reconnection error: $error");
      });

      _socket!.on('reconnect_failed', (_) {
        debugPrint("❌ Socket reconnection failed after all attempts");
        if (mounted) {
          setState(() {
            _isAudioConnecting = false;
            _isAudioConnected = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Audio connection lost. Please try reconnecting manually.'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _connectToAudio(),
              ),
            ),
          );
        }
      });

      // Handle room events
      _socket!.on('joined-room', (data) => _handleWebRTCMessage(data));
      _socket!.on('participant-joined', (data) => _handleWebRTCMessage({...data, 'type': 'participant-joined'}));
      _socket!.on('participant-left', (data) => _handleWebRTCMessage({...data, 'type': 'participant-left'}));
      
      // Handle WebRTC signaling
      _socket!.on('offer', (data) => _handleWebRTCMessage({...data, 'type': 'offer'}));
      _socket!.on('answer', (data) => _handleWebRTCMessage({...data, 'type': 'answer'}));
      _socket!.on('ice-candidate', (data) => _handleWebRTCMessage({...data, 'type': 'ice-candidate'}));

      debugPrint('🚀 Initiating socket connection...');
      _socket!.connect();
      debugPrint('✅ Socket connection initiated');
      
    } catch (e) {
      debugPrint("❌ Failed to connect to WebRTC server: $e");
      rethrow;
    }
    */
  }

  void _handleWebRTCMessage(Map<String, dynamic> data) {
    debugPrint("📨 WebRTC message: $data");
    
    // Log current WebRTC room state
    if (data.containsKey('participants')) {
      final participants = data['participants'] as List;
      debugPrint("🎯 WebRTC room now has ${participants.length} participants:");
      for (var participant in participants) {
        debugPrint("  - ${participant['userName']} (${participant['userId']})");
      }
    }
    
    // Handle WebRTC signaling and room events
    switch (data['type']) {
      case 'participant-joined':
        debugPrint("🎉 New participant joined WebRTC: ${data['userId']} (${data['userName'] ?? 'Unknown'})");
        _createOffer(data['userId']);
        break;
        
      case 'participant-left':
        final userId = data['userId'];
        
        // Clean up audio renderer
        final renderer = _remoteAudioRenderers.remove(userId);
        if (renderer != null) {
          renderer.srcObject = null;
          renderer.dispose();
          debugPrint("🎧 Disposed audio renderer for $userId");
        }
        
        // Clean up streams and peer connections
        _remoteStreams.remove(userId);
        _peerConnections[userId]?.close();
        _peerConnections.remove(userId);
        break;
        
      case 'offer':
        _handleOffer(data['offer'], data['userId']);
        break;
        
      case 'answer':
        _handleAnswer(data['answer'], data['userId']);
        break;
        
      case 'ice-candidate':
        _handleIceCandidate(data['candidate'], data['userId']);
        break;
    }
  }

  Future<void> _createOffer(String targetUserId) async {
    // DISABLED: WebRTC P2P - using MediaSoup SFU instead
    return;
    /*
    try {
      final pc = await _createPeerConnection(targetUserId);
      
      RTCSessionDescription offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      
      _socket?.emit('offer', {
        'offer': offer.toMap(),
        'roomId': widget.room.id,
        'userId': _currentAppwriteUserId ?? 'guest',
        'targetUserId': targetUserId,
      });
      
      debugPrint("📤 Sent offer to $targetUserId");
    } catch (e) {
      debugPrint("❌ Failed to create offer: $e");
    }
    */
  }

  Future<RTCPeerConnection> _createPeerConnection(String peerId) async {
    try {
      final Map<String, dynamic> configuration = {
        'iceServers': _iceServers,
        'sdpSemantics': 'unified-plan',
      };

      final Map<String, dynamic> constraints = {
        'mandatory': {},
        'optional': [
          {'DtlsSrtpKeyAgreement': true},
        ]
      };

      final pc = await createPeerConnection(configuration, constraints);

      if (_localStream != null) {
        for (var track in _localStream!.getTracks()) {
          await pc.addTrack(track, _localStream!);
        }
      }

      pc.onIceCandidate = (RTCIceCandidate candidate) {
        _socket?.emit('ice-candidate', {
          'candidate': candidate.toMap(),
          'roomId': widget.room.id,
          'userId': _currentAppwriteUserId ?? 'guest',
          'targetUserId': peerId,
        });
      };

      pc.onTrack = (RTCTrackEvent event) {
        debugPrint("🎧 Remote audio track added from $peerId");
        debugPrint("📊 Track kind: ${event.track.kind}, streams: ${event.streams.length}");
        
        if (event.streams.isNotEmpty && mounted) {
          final stream = event.streams[0];
          debugPrint("🎵 Remote stream ID: ${stream.id}, audio tracks: ${stream.getAudioTracks().length}");
          
          // Create audio renderer for this peer if it doesn't exist
          _createAudioRenderer(peerId, stream);
          
          setState(() {
            _remoteStreams[peerId] = stream;
          });
          
          // CRITICAL: Enable audio playback for the remote stream
          final audioTracks = stream.getAudioTracks();
          for (var track in audioTracks) {
            track.enabled = true;
            // Set maximum volume for better audio clarity
            try {
              // Enable the track and ensure it's not muted
              track.enabled = true;
              debugPrint("🔊 Enabled audio playback for track ${track.id} from $peerId");
              debugPrint("🎤 Track settings: enabled=${track.enabled}, muted=${track.muted}");
            } catch (e) {
              debugPrint("⚠️ Could not set audio track properties: $e");
            }
          }
          
          debugPrint("🎧 Audio renderer created and stream assigned for $peerId");
          debugPrint("🎯 Total audio renderers: ${_remoteAudioRenderers.length}");
          
          // Play a brief audio confirmation (like a "ringing" to confirm audio is working)
          _playAudioConfirmation();
          
          debugPrint("🎯 Total remote streams now: ${_remoteStreams.length}");
        }
      };

      _peerConnections[peerId] = pc;
      return pc;
      
    } catch (e) {
      debugPrint("❌ Failed to create peer connection for $peerId: $e");
      rethrow;
    }
  }

  Future<void> _createAudioRenderer(String peerId, MediaStream stream) async {
    try {
      // Create and initialize audio renderer if it doesn't exist
      if (!_remoteAudioRenderers.containsKey(peerId)) {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        
        debugPrint("🎧 Initialized audio renderer for $peerId");
        
        _remoteAudioRenderers[peerId] = renderer;
      }
      
      // Assign the stream to the renderer
      _remoteAudioRenderers[peerId]!.srcObject = stream;
      debugPrint("🔊 Audio stream assigned to renderer for $peerId");
      
      // For debugging - check audio tracks
      final audioTracks = stream.getAudioTracks();
      debugPrint("🎵 Stream has ${audioTracks.length} audio tracks");
      for (var track in audioTracks) {
        debugPrint("🎵 Audio track: id=${track.id}, enabled=${track.enabled}, kind=${track.kind}");
      }
      
    } catch (e) {
      debugPrint("❌ Failed to create audio renderer for $peerId: $e");
    }
  }

  void _playAudioConfirmation() {
    try {
      // Simple audio feedback to confirm WebRTC audio is working
      // This will help the user know when audio connections are established
      debugPrint("🔔 Audio connection confirmed - audio rendering active");
      
      // Optional: Could play a brief system sound here if needed
      // SystemSound.play(SystemSoundType.click);
      
    } catch (e) {
      debugPrint("❌ Audio confirmation error: $e");
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> offerMap, String fromUserId) async {
    // DISABLED: WebRTC P2P - using MediaSoup SFU instead
    return;
    /*
    try {
      final pc = await _createPeerConnection(fromUserId);
      
      RTCSessionDescription offer = RTCSessionDescription(
        offerMap['sdp'],
        offerMap['type'],
      );
      
      await pc.setRemoteDescription(offer);
      
      RTCSessionDescription answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      
      _socket?.emit('answer', {
        'answer': answer.toMap(),
        'roomId': widget.room.id,
        'userId': _currentAppwriteUserId ?? 'guest',
        'targetUserId': fromUserId,
      });
      
      debugPrint("📤 Sent answer to $fromUserId");
    } catch (e) {
      debugPrint("❌ Failed to handle offer: $e");
    }
    */
  }

  Future<void> _handleAnswer(Map<String, dynamic> answerMap, String fromUserId) async {
    try {
      final pc = _peerConnections[fromUserId];
      if (pc == null) {
        debugPrint("❌ No peer connection found for $fromUserId");
        return;
      }
      
      // Check if we're in the correct state to receive an answer
      final state = await pc.getConnectionState();
      debugPrint("🔍 Peer connection state for $fromUserId: $state");
      
      // Only set remote description if we're in the right state
      if (pc.signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        RTCSessionDescription answer = RTCSessionDescription(
          answerMap['sdp'],
          answerMap['type'],
        );
        
        await pc.setRemoteDescription(answer);
        debugPrint("📥 Received answer from $fromUserId");
      } else {
        debugPrint("⚠️ Ignoring answer from $fromUserId - wrong signaling state: ${pc.signalingState}");
      }
    } catch (e) {
      debugPrint("❌ Failed to handle answer: $e");
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> candidateMap, String fromUserId) async {
    try {
      final pc = _peerConnections[fromUserId];
      if (pc == null) return;
      
      RTCIceCandidate candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );
      
      await pc.addCandidate(candidate);
      debugPrint("🧊 Added ICE candidate from $fromUserId");
    } catch (e) {
      debugPrint("❌ Failed to handle ICE candidate: $e");
    }
  }

  Future<void> _toggleMute() async {
    if (_isAudioConnected) {
      await _audioServiceToggleMute();
      if (mounted) {
        setState(() {
          _isMuted = _audioServiceIsMuted;
        });
      }
      debugPrint("🔇 Audio ${_isMuted ? 'muted' : 'unmuted'}");
    }
  }

  Future<void> _configureAudioRouting() async {
    try {
      // Configure audio session for proper playback
      debugPrint("🔊 Configuring audio routing for WebRTC playback");
      
      // For Flutter WebRTC, audio should play automatically through system speakers/earpiece
      // The important part is ensuring remote tracks are enabled (done in onTrack)
      
    } catch (e) {
      debugPrint("⚠️ Could not configure audio routing: $e");
    }
  }

  Future<void> _cleanupWebRTC() async {
    try {
      // DISABLED: WebRTC socket cleanup - using MediaSoup instead
      /*
      if (_socket != null) {
        _socket!.off('connect');
        _socket!.off('disconnect');
        _socket!.off('connect_error');
        _socket!.off('connect_timeout');
        _socket!.off('reconnect');
        _socket!.off('reconnect_error');
        _socket!.off('reconnect_failed');
        _socket!.off('joined-room');
        _socket!.off('participant-joined');
        _socket!.off('participant-left');
        _socket!.off('offer');
        _socket!.off('answer');
        _socket!.off('ice-candidate');
        _socket!.disconnect();
        _socket!.dispose();
        _socket = null;
      }
      */
      
      for (var pc in _peerConnections.values) {
        await pc.close();
      }
      _peerConnections.clear();
      
      // Dispose audio renderers first
      for (var renderer in _remoteAudioRenderers.values) {
        renderer.srcObject = null;
        await renderer.dispose();
      }
      _remoteAudioRenderers.clear();
      debugPrint("🎧 Disposed all audio renderers");
      
      for (var stream in _remoteStreams.values) {
        stream.getTracks().forEach((track) {
          track.stop();
        });
        stream.dispose();
      }
      _remoteStreams.clear();
      
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          track.stop();
        });
        _localStream!.dispose();
        _localStream = null;
      }
    } catch (e) {
      debugPrint("❌ WebRTC cleanup error: $e");
    }
  }
  */
  // END OF OLD WEBRTC METHODS

  // Video toggle removed - audio-only for now
  // Future video update will re-add this functionality

  Future<void> _leaveRoomData() async {
    try {
      if (_currentAppwriteUserId != null) {
        await _appwriteService.leaveRoom(
          roomId: widget.room.id,
          userId: _currentAppwriteUserId!,
        );
        debugPrint('✅ Left room ${widget.room.id}');
      }
    } catch (e) {
      debugPrint('❌ Error leaving room: $e');
    }
  }

  Future<void> _leaveRoom() async {
    await _leaveRoomData();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _toggleChat() {
    final currentUser = _getCurrentUserProfile();
    if (currentUser == null) return;
    
    // Convert participants to chat participants format
    final chatParticipants = _participants.map((p) {
      final userProfile = _userProfiles[p['userId']];
      return ChatParticipant(
        userId: p['userId'],
        username: userProfile?.name ?? 'Unknown User',
        role: p['role'],
        avatar: userProfile?.avatar,
        isOnline: true,
        joinedAt: DateTime.now(),
      );
    }).toList();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => MattermostChatWidget(
        currentUserId: _currentAppwriteUserId!,
        currentUser: currentUser,
        roomId: widget.room.id,
        participants: chatParticipants,
        onClose: () {
          // Dismiss keyboard first, then close modal
          FocusScope.of(context).unfocus();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showUserProfile(UserProfile userProfile, String? userRole) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => UserProfileBottomSheet(
        user: userProfile,
        onFollow: () {
          // TODO: Implement follow functionality
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Following ${userProfile.name}'),
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
                content: Text('Challenge sent to ${userProfile.name}'),
                backgroundColor: const Color(0xFFDC2626),
              ),
            );
          }
        },
        onEmail: () {
          if (mounted && _getCurrentUserProfile() != null) {
            final currentUser = _getCurrentUserProfile()!;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmailComposeScreen(
                  currentUserId: currentUser.id,
                  currentUsername: currentUser.name,
                  recipient: userProfile,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  /// Get current user profile for chat
  UserProfile? _getCurrentUserProfile() {
    if (_currentAppwriteUserId == null) return null;
    return _userProfiles[_currentAppwriteUserId!];
  }


  // Moderation methods
  Future<void> _promoteToSpeaker(String userId) async {
    try {
      await _appwriteService.updateParticipantRole(
        roomId: widget.room.id,
        userId: userId,
        newRole: 'speaker',
      );
      
      // Clear hand raise via metadata when promoting to speaker
      await _appwriteService.updateParticipantMetadata(
        roomId: widget.room.id,
        userId: userId,
        metadata: {'handRaised': false},
      );
      
      // Remove from hands raised if they were raising hand
      if (mounted) {
        setState(() {
          _handsRaised.remove(userId);
        });
      }
      
      // If this is the current user being promoted, update state and reinitialize audio with speaker role
      if (userId == _currentAppwriteUserId) {
        if (mounted) {
          setState(() {
            _isHandRaised = false; // Lower hand since they're now a speaker
          });
        }
        // Reinitialize WebRTC connection with speaker role to enable microphone
        await _reinitializeAudioForSpeaker();
      }
      
      // Reload participants to reflect changes
      await _loadRoomParticipants();
      
      final userProfile = _userProfiles[userId];
      final userName = userProfile?.displayName ?? 'User';
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userName promoted to speaker'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error promoting user to speaker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error promoting user: $e'),
            backgroundColor: scarletRed,
          ),
        );
      }
    }
  }

  Future<void> _demoteToAudience(String userId) async {
    try {
      await _appwriteService.updateParticipantRole(
        roomId: widget.room.id,
        userId: userId,
        newRole: 'audience',
      );
      
      // Clear hand raised state when demoting
      await _appwriteService.updateParticipantMetadata(
        roomId: widget.room.id,
        userId: userId,
        metadata: {'handRaised': false},
      );
      
      // If this is the current user being demoted, disconnect audio and become audience
      if (userId == _currentAppwriteUserId) {
        // Update local state
        if (mounted) {
          setState(() {
            _isHandRaised = false;
            _handsRaised.remove(userId);
          });
        }
        
        // Disconnect audio since audience members can't use mic
        if (_isAudioConnected) {
          await _audioService.disconnect();
          if (mounted) {
            setState(() {
              _isAudioConnected = false;
              _isAudioConnecting = false;
              _isMuted = false;
            });
          }
        }
      }
      
      // Reload participants to reflect changes
      await _loadRoomParticipants();
      
      final userProfile = _userProfiles[userId];
      final userName = userProfile?.displayName ?? 'User';
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userId == _currentAppwriteUserId 
              ? 'You have been moved back to the audience' 
              : '$userName moved to audience'),
            backgroundColor: userId == _currentAppwriteUserId ? Colors.grey : Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error demoting user to audience: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error moving user: $e'),
            backgroundColor: scarletRed,
          ),
        );
      }
    }
  }

  Future<void> _closeRoom() async {
    try {
      // Show confirmation dialog
      final shouldClose = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Close Room'),
          content: const Text('Are you sure you want to close this room? All participants will be removed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: scarletRed),
              child: const Text('Close Room'),
            ),
          ],
        ),
      );

      if (shouldClose == true) {
        // Update room status to closed
        await _appwriteService.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: AppwriteConstants.roomsCollection,
          documentId: widget.room.id,
          data: {
            'status': 'closed',
            'endedAt': DateTime.now().toIso8601String(),
          },
        );

        // Leave room and navigate back
        await _leaveRoom();
      }
    } catch (e) {
      debugPrint('❌ Error closing room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error closing room: $e'),
            backgroundColor: scarletRed,
          ),
        );
      }
    }
  }


  // Get users who are currently speakers (broadcasters) from Appwrite data - EXCLUDING moderators
  List<Map<String, dynamic>> get _speakers {
    return _participants.where((p) => 
      p['role'] == 'speaker' // REMOVED moderator from speakers list
    ).toList();
  }

  // Get users who are audience (non-speakers) from Appwrite data
  List<Map<String, dynamic>> get _audience {
    return _participants.where((p) => p['role'] == 'audience').toList();
  }

  // Get the moderator specifically
  Map<String, dynamic>? get _moderator {
    try {
      return _participants.firstWhere((p) => p['role'] == 'moderator');
    } catch (e) {
      // Fallback to room creator as moderator
      return {
        'userId': widget.room.createdBy,
        'role': 'moderator',
      };
    }
  }

  // Check if current user is moderator
  bool get _isCurrentUserModerator {
    final isModerator = _userParticipation?['role'] == 'moderator';
    final isRoomCreator = _currentAppwriteUserId == widget.room.createdBy;
    return isModerator || isRoomCreator;
  }
  
  // Role getters removed - audio-only implementation
  // Future video update will re-add role-based video permissions

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
          children: [
            // Main room interface
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    scarletRed.withValues(alpha: 0.05),
                    accentPurple.withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header with room info and controls
                    _buildHeader(),
                    
                    // Main content area
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Moderator section
                            _buildModeratorSection(),
                            
                            const SizedBox(height: 24),
                            
                            // Speaker's panel
                            _buildSpeakersPanel(),
                            
                            const SizedBox(height: 24),
                            
                            // Audience section
                            _buildAudienceSection(),
                            
                            // Extra bottom padding for Android and chat button
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                    
                    // Bottom controls
                    _buildBottomControls(),
                  ],
                ),
              ),
            ),
            
            // Hidden audio renderers - required for WebRTC audio playback
            ..._remoteAudioRenderers.entries.map((entry) => 
              Positioned(
                left: -1000, // Hide off-screen
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: RTCVideoView(
                    entry.value,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    mirror: false,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
            ).toList(),
            
            // Chat now handled via Mattermost-inspired widget in _toggleChat()
          ],
        ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: scarletRed.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: scarletRed.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Leave room button (door exit icon)
          GestureDetector(
            onTap: _leaveRoom,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scarletRed.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
                border: Border.all(
                  color: scarletRed.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.exit_to_app,
                color: scarletRed,
                size: 16,
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Room info (left side)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.room.title,
                  style: const TextStyle(
                    color: deepPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    // Room participants count
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        '${_participants.length} in room (${_remoteStreams.length + (_isAudioConnected ? 1 : 0)} audio)',
                        style: const TextStyle(
                          color: accentPurple,
                          fontSize: 8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Realtime sync status
                    const SizedBox(width: 2),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: _isRealtimeHealthy ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 1),
                    Text(
                      _isRealtimeHealthy ? 'sync' : 'offline',
                      style: TextStyle(
                        color: _isRealtimeHealthy ? Colors.green : Colors.red,
                        fontSize: 6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 4),
          
          // Centered Timer
          Expanded(
            flex: 3,
            child: Center(
              child: AppwriteTimerWidget(
                roomId: widget.room.id,
                roomType: timer_models.RoomType.openDiscussion,
                isModerator: _isCurrentUserModerator,
                userId: _currentAppwriteUserId ?? '',
                compact: true,
                showControls: _isCurrentUserModerator,
                showConnectionStatus: false,
              ),
            ),
          ),
          
          const SizedBox(width: 2),
          
          // Right side controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Room count icon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: accentPurple.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people,
                      color: accentPurple,
                      size: 8,
                    ),
                    const SizedBox(width: 1),
                    Text(
                      '${_participants.length}',
                      style: const TextStyle(
                        color: accentPurple,
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 4),
              
              // Instant Message Bell
              const InstantMessageBell(
                iconColor: Color(0xFF8B5CF6),
                iconSize: 16,
              ),
              
              const SizedBox(width: 4),
              
              // Challenge Bell
              const ChallengeBell(
                iconColor: Color(0xFFFF2400),
                iconSize: 16,
              ),
              
              const SizedBox(width: 4),
              
              // Moderation controls (only for moderators)
              if (_isCurrentUserModerator)
                Stack(
                  children: [
                    IconButton(
                      onPressed: _showModerationModal,
                      icon: const Icon(
                        Icons.admin_panel_settings,
                        color: scarletRed,
                        size: 16,
                      ),
                      tooltip: 'Moderation Controls',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                    // Notification badge for hands raised
                    if (_handsRaised.isNotEmpty)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(1),
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 10,
                            minHeight: 10,
                          ),
                          child: Text(
                            '${_handsRaised.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeratorSection() {
    final moderator = _moderator;
    if (moderator == null) return const SizedBox(); // No moderator section if no moderator

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Room Moderator',
          style: TextStyle(
            color: deepPurple,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 15),
        Center(
          child: _buildUserAvatar(
            userId: moderator['userId'],
            name: moderator['userId'] == _currentAppwriteUserId ? 'You' : 'Moderator',
            size: 80,
            isSpeaking: false, // No voice functionality
            showModerator: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSpeakersPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Speakers (${_speakers.length})',
          style: const TextStyle(
            color: deepPurple,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 15),
        
        if (_speakers.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No speakers yet.\nRaise your hand to become a speaker!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: deepPurple.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          // Two rows of speakers (4 per row)
          for (int i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int j = 0; j < 4; j++)
                    if (i * 4 + j < _speakers.length) ...[
                      Builder(
                        builder: (context) {
                          final speaker = _speakers[i * 4 + j];
                          final isCurrentUser = speaker['userId'] == _currentAppwriteUserId;
                          final userProfile = _userProfiles[speaker['userId']];
                          final hasAudio = isCurrentUser ? _isAudioConnected : false; // For now, only track local audio
                          final isSpeakerMuted = isCurrentUser ? _isMuted : false; // Can't know remote mute state
                          
                          return _buildUserAvatar(
                            userId: speaker['userId'],
                            name: isCurrentUser 
                              ? 'You' 
                              : userProfile?.displayName ?? 'Speaker',
                            size: 60,
                            isSpeaking: hasAudio && !isSpeakerMuted,
                          );
                        },
                      ),
                    ] else
                      _buildEmptySpeakerSlot(),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildAudienceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Audience (${_audience.length})',
          style: const TextStyle(
            color: deepPurple,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 15),
        
        // Show message if no audience
        if (_audience.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No audience members yet.\nInvite friends to join the discussion!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: deepPurple.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          // Audience grid (4 per row)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1,
            ),
            itemCount: _audience.length,
            itemBuilder: (context, index) {
              final audienceMember = _audience[index];
              final isCurrentUser = audienceMember['userId'] == _currentAppwriteUserId;
              final userProfile = _userProfiles[audienceMember['userId']];
              
              return _buildUserAvatar(
                userId: audienceMember['userId'],
                name: isCurrentUser 
                  ? 'You' 
                  : userProfile?.displayName ?? 'Listener',
                size: 50,
                isSpeaking: false, // Audience can't speak
              );
            },
          ),
      ],
    );
  }

  Widget _buildUserAvatar({
    required String userId,
    required String name,
    required double size,
    bool isSpeaking = false,
    bool showModerator = false,
  }) {
    final isCurrentUser = userId == _currentAppwriteUserId;
    final userProfile = _userProfiles[userId];
    
    // Load profile if not already loaded and it's a real user
    if (userProfile == null && !isCurrentUser) {
      _loadUserProfile(userId);
    }
    
    // Determine display name
    String displayName;
    if (isCurrentUser) {
      displayName = 'You';
    } else if (userProfile != null) {
      displayName = userProfile.displayName;
    } else {
      displayName = name;
    }
    
    return GestureDetector(
      onTap: () async {
        UserProfile? profileToShow = userProfile;
        
        // If profile isn't loaded, load it now
        if (profileToShow == null && !isCurrentUser) {
          try {
            AppLogger().debug('👤 Loading profile for user: $userId');
            profileToShow = await _appwriteService.getUserProfile(userId);
            if (profileToShow != null) {
              setState(() {
                _userProfiles[userId] = profileToShow!;
              });
            }
          } catch (e) {
            AppLogger().error('❌ Failed to load user profile: $e');
          }
        }
        
        // Show profile if we have it (either was already loaded or just loaded)
        if (profileToShow != null) {
          String? role;
          if (showModerator) {
            role = 'moderator';
          } else if (_handsRaised.contains(userId)) {
            role = 'pending';
          } else {
            // Determine if user is speaker or audience
            final participant = _participants.firstWhere(
              (p) => p['userId'] == userId,
              orElse: () => <String, dynamic>{},
            );
            role = participant['role'] ?? 'audience';
          }
          AppLogger().debug('👤 Showing profile for ${profileToShow.name} with role: $role');
          _showUserProfile(profileToShow, role);
        } else {
          // Show a message if profile couldn't be loaded
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to load user profile'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isSpeaking ? scarletRed : accentPurple).withValues(alpha: 0.2),
                      blurRadius: isSpeaking ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: UserAvatarStatus(
                  avatarUrl: userProfile?.avatar,
                  initials: userProfile?.initials ?? 
                      (isCurrentUser ? 'YOU' : userId.substring(0, 2).toUpperCase()),
                  radius: size / 2,
                  isOnline: true, // Could be enhanced with real online status
                  isSpeaking: isSpeaking,
                ),
              ),
            
            // Moderator crown or hand raised indicator
            if (showModerator)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: size * 0.3,
                  height: size * 0.3,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.star,
                    size: size * 0.2,
                    color: Colors.white,
                  ),
                ),
              )
            else if (_isHandRaised && isCurrentUser)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: size * 0.3,
                  height: size * 0.3,
                  decoration: const BoxDecoration(
                    color: scarletRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.pan_tool,
                    size: size * 0.2,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 6),
        
        // User name and status
        SizedBox(
          width: size + 10,
          child: Column(
            children: [
              Text(
                displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isCurrentUser ? scarletRed : deepPurple,
                  fontSize: size > 60 ? 12 : 10,
                  fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              
              // Status badges
              if (showModerator)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(
                    color: scarletRed,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: const Text(
                    'MODERATOR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (isSpeaking)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildEmptySpeakerSlot() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: accentPurple.withValues(alpha: 0.3),
              width: 2,
              style: BorderStyle.solid,
            ),
            color: lightScarlet,
          ),
          child: Icon(
            Icons.add,
            size: 30,
            color: accentPurple.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Open',
          style: TextStyle(
            color: deepPurple.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: scarletRed.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: scarletRed.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status text
          Text(
            _isCurrentUserModerator
              ? '👑 You are the moderator • Mic access enabled'
              : _userParticipation?['role'] == 'speaker'
                ? '🎙️ You are a speaker • Mic access enabled'
                : '👂 You are in the audience • Raise hand for mic access${_isHandRaised ? ' • Hand raised' : ''}',
            style: TextStyle(
              color: _isCurrentUserModerator
                ? Colors.green
                : _userParticipation?['role'] == 'speaker'
                  ? Colors.green
                  : accentPurple,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Chat
              _buildControlButton(
                icon: Icons.chat_bubble,
                label: 'Chat',
                color: const Color(0xFF8B5CF6), // Purple to match chat theme
                onTap: _toggleChat,
              ),
              
              // Audio toggle with role-based access (only speakers and moderators)
              if (_userParticipation?['role'] == 'speaker' || _userParticipation?['role'] == 'moderator')
                _buildControlButton(
                  icon: _isAudioConnected 
                    ? (_isMuted ? Icons.volume_off : Icons.volume_up)
                    : (_isAudioConnecting ? Icons.hourglass_empty : Icons.speaker),
                  label: _isAudioConnected 
                    ? (_isMuted ? 'Unmuted Audio ($_audioServiceConnectedPeersCount peers)' : 'Audio On ($_audioServiceConnectedPeersCount peers)')
                    : (_isAudioConnecting ? 'Connecting...' : 'Join Audio'),
                  color: _isAudioConnected 
                    ? (_isMuted ? Colors.red : Colors.green)
                    : (_isAudioConnecting ? Colors.orange : Colors.blue),
                  onTap: _isAudioConnected 
                    ? () => _toggleMute() 
                    : (_isAudioConnecting ? () => _forceResetAudioConnection() : () => _connectToAudio()),
                )
              else
                // Show disabled audio for audience members
                _buildControlButton(
                  icon: Icons.volume_off,
                  label: 'Audio (Speakers Only)',
                  color: Colors.grey,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Only speakers and moderators can use audio. Raise your hand to become a speaker!'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              
              // Video removed for future update - audio-only for now
              
              // Raise hand
              _buildControlButton(
                icon: _isHandRaised ? Icons.back_hand : Icons.back_hand_outlined,
                label: _userParticipation?['role'] == 'moderator'
                  ? 'Moderator' // Moderators can't use hand raise
                  : _userParticipation?['role'] == 'speaker'
                    ? 'Leave Panel' // Speakers can leave the panel
                    : (_isHandRaised ? 'Lower' : 'Raise'), // Audience can raise/lower hand
                color: _userParticipation?['role'] == 'speaker' 
                  ? scarletRed // Red for leaving panel
                  : _isHandRaised ? scarletRed : accentPurple,
                onTap: _userParticipation?['role'] == 'moderator' 
                  ? () {} // Moderators can't use hand raise
                  : _toggleHandRaise, // Speakers and audience can use this
              ),
              
              // Send Gift
              _buildControlButton(
                icon: Icons.card_giftcard,
                label: 'Gift',
                color: Colors.amber,
                onTap: _showGiftModal,
              ),
            ],
          ),
          
          // Web-specific audio enable button
          if (kIsWeb && _remoteStreams.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: () {
                  _resumeWebAudioContext();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔊 Audio enabled for web browser'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.volume_up, size: 16),
                label: const Text('Enable Audio', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: lightScarlet,
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Gift modal methods
  void _showGiftModal() {
    debugPrint('🎁 DEBUG: Gift modal button pressed');
    debugPrint('🎁 DEBUG: Current user ID: $_currentAppwriteUserId');
    debugPrint('🎁 DEBUG: Current coin balance: $_currentUserCoinBalance');
    
    // Get available recipients (speakers + moderators, excluding self)
    final recipients = <Map<String, dynamic>>[];
    
    // Add moderator
    if (_moderator != null && _moderator!['userId'] != _currentAppwriteUserId) {
      recipients.add(_moderator!);
      debugPrint('🎁 DEBUG: Added moderator as recipient');
    }
    
    // Add speakers
    for (final speaker in _speakers) {
      if (speaker['userId'] != _currentAppwriteUserId) {
        recipients.add(speaker);
        debugPrint('🎁 DEBUG: Added speaker as recipient: ${speaker['userId']}');
      }
    }
    
    debugPrint('🎁 DEBUG: Total recipients: ${recipients.length}');
    
    if (recipients.isEmpty) {
      debugPrint('🎁 DEBUG: No recipients available');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No speakers or moderators to send gifts to'),
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
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
            
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.card_giftcard,
                    color: Colors.amber,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Send Gift',
                    style: TextStyle(
                      color: deepPurple,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Coin balance display with refresh
                  GestureDetector(
                    onTap: () async {
                      debugPrint('🎁 DEBUG: Manual coin refresh tapped');
                      await _loadFirebaseCoinBalance();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.all(Radius.circular(20)),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$_currentUserCoinBalance',
                            style: TextStyle(
                              color: Colors.amber.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.refresh, color: Colors.amber, size: 12),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    // Tab bar
                    const TabBar(
                      labelColor: deepPurple,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: scarletRed,
                      tabs: [
                        Tab(text: 'Select Gift'),
                        Tab(text: 'Recipients'),
                      ],
                    ),
                    
                    // Tab views
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildGiftSelectionTab(),
                          _buildRecipientSelectionTab(recipients),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          // Gift categories
          ...GiftCategory.values.map((category) => _buildGiftCategorySection(category)),
        ],
      ),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
            ? scarletRed.withValues(alpha: 0.1)
            : (canAfford ? Colors.white : Colors.grey.shade100),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(
            color: isSelected 
              ? scarletRed 
              : (canAfford ? _getTierColor(gift.tier) : Colors.grey.shade300),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: canAfford ? [
            BoxShadow(
              color: _getTierColor(gift.tier).withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gift emoji and effects
            Row(
              children: [
                Text(
                  gift.emoji,
                  style: TextStyle(
                    fontSize: 24,
                    color: canAfford ? null : Colors.grey,
                  ),
                ),
                const Spacer(),
                if (gift.hasVisualEffect)
                  const Icon(Icons.auto_awesome, size: 12, color: Colors.amber),
                if (gift.hasProfileBadge)
                  const Icon(Icons.shield, size: 12, color: Colors.blue),
              ],
            ),
            
            const SizedBox(height: 4),
            
            // Gift name
            Text(
              gift.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: canAfford ? deepPurple : Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 2),
            
            // Gift description
            Text(
              gift.description,
              style: TextStyle(
                fontSize: 10,
                color: canAfford ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const Spacer(),
            
            // Cost
            Row(
              children: [
                Icon(
                  Icons.monetization_on,
                  size: 12,
                  color: canAfford ? Colors.amber : Colors.grey,
                ),
                const SizedBox(width: 2),
                Text(
                  '${gift.cost}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: canAfford ? Colors.amber.shade700 : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientSelectionTab(List<Map<String, dynamic>> recipients) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recipients.length,
      itemBuilder: (context, index) {
        final recipient = recipients[index];
        final userProfile = _userProfiles[recipient['userId']];
        final isSelected = _selectedRecipient?['userId'] == recipient['userId'];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: isSelected 
              ? Border.all(color: scarletRed, width: 2)
              : null,
            color: isSelected 
              ? scarletRed.withValues(alpha: 0.1)
              : null,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: accentPurple.withValues(alpha: 0.2),
              backgroundImage: userProfile?.avatar != null 
                ? NetworkImage(userProfile!.avatar!) 
                : null,
              child: userProfile?.avatar == null 
                ? Text(
                    userProfile?.initials ?? 'U',
                    style: const TextStyle(
                      color: deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
            ),
            title: Text(
              userProfile?.displayName ?? 'User',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              recipient['role'] == 'moderator' ? 'Moderator' : 'Speaker',
              style: TextStyle(
                color: recipient['role'] == 'moderator' ? scarletRed : Colors.green,
                fontSize: 12,
              ),
            ),
            trailing: Icon(
              recipient['role'] == 'moderator' ? Icons.admin_panel_settings : Icons.mic,
              color: recipient['role'] == 'moderator' ? scarletRed : Colors.green,
            ),
            onTap: () => _selectRecipient(recipient),
          ),
        );
      },
    );
  }

  Color _getTierColor(GiftTier tier) {
    switch (tier) {
      case GiftTier.basic:
        return Colors.grey;
      case GiftTier.standard:
        return Colors.blue;
      case GiftTier.premium:
        return Colors.purple;
      case GiftTier.legendary:
        return Colors.amber;
    }
  }

  Gift? _selectedGift;
  Map<String, dynamic>? _selectedRecipient;

  void _selectGift(Gift gift) {
    debugPrint('🎁 DEBUG: Attempting to select gift: ${gift.name}');
    debugPrint('🎁 DEBUG: Gift cost: ${gift.cost}');
    debugPrint('🎁 DEBUG: User balance: $_currentUserCoinBalance');
    debugPrint('🎁 DEBUG: Can afford: ${_currentUserCoinBalance >= gift.cost}');
    
    setState(() {
      _selectedGift = gift;
    });
    
    debugPrint('🎁 DEBUG: Gift selected successfully: ${gift.name}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected ${gift.emoji} ${gift.name}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );

    // If both gift and recipient are selected, show confirmation
    if (_selectedRecipient != null) {
      _showGiftConfirmation();
    }
  }

  void _selectRecipient(Map<String, dynamic> recipient) {
    setState(() {
      _selectedRecipient = recipient;
    });
    
    final userProfile = _userProfiles[recipient['userId']];
    debugPrint('Selected recipient: ${userProfile?.displayName}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected recipient: ${userProfile?.displayName}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );

    // If both gift and recipient are selected, show confirmation
    if (_selectedGift != null) {
      _showGiftConfirmation();
    }
  }

  void _showGiftConfirmation() {
    if (_selectedGift == null || _selectedRecipient == null) return;

    final gift = _selectedGift!;
    final recipient = _selectedRecipient!;
    final recipientProfile = _userProfiles[recipient['userId']];

    Navigator.pop(context); // Close gift modal

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Gift?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send ${gift.emoji} ${gift.name} to ${recipientProfile?.displayName ?? 'Unknown User'}?'),
            const SizedBox(height: 8),
            Text('Cost: ${gift.cost} coins'),
            const SizedBox(height: 8),
            Text('Your balance: $_currentUserCoinBalance coins'),
            if (_currentUserCoinBalance < gift.cost)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Insufficient coins!',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
            onPressed: _currentUserCoinBalance >= gift.cost 
              ? () => _sendGift(gift, recipient)
              : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Gift'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendGift(Gift gift, Map<String, dynamic> recipient) async {
    if (_currentAppwriteUserId == null) return;

    try {
      Navigator.pop(context); // Close confirmation dialog

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 10),
                Text('Sending gift...'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Send gift via Firebase
      await _firebaseGiftService.sendGift(
        giftId: gift.id,
        senderId: _currentAppwriteUserId!,
        recipientId: recipient['userId'],
        roomId: widget.room.id,
        cost: gift.cost,
      );

      // Send gift notification to chat
      // Variables removed since gift notifications are handled by new chat system
      // final senderProfile = _userProfiles[_currentAppwriteUserId!];
      // final recipientProfile = _userProfiles[recipient['userId']];
      
      // Gift notifications will be handled by new chat system
      // await _chatService.sendGiftNotification(
      //   roomId: widget.room.id,
      //   giftId: gift.id,
      //   giftName: '${gift.emoji} ${gift.name}',
      //   senderId: _currentAppwriteUserId!,
      //   senderName: senderProfile?.displayName ?? 'Someone',
      //   recipientId: recipient['userId'],
      //   recipientName: recipientProfile?.displayName ?? 'User',
      //   cost: gift.cost,
      // );

      // Refresh Firebase coin balance
      await _loadFirebaseCoinBalance();

      // Show success notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎁 Gift sent! ${gift.emoji} ${gift.name}'),
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
      debugPrint('Error sending gift: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send gift: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Moderation modal methods
  void _showModerationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
            
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    color: scarletRed,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Moderation Controls',
                    style: TextStyle(
                      color: deepPurple,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hand raised notifications
                    _buildHandRaisedSection(),
                    
                    const SizedBox(height: 30),
                    
                    // Quick actions
                    _buildQuickActions(),
                    
                    const SizedBox(height: 30),
                    
                    // User management
                    _buildUserManagementSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandRaisedSection() {
    final handsRaisedUsers = _participants.where((p) => 
      _handsRaised.contains(p['userId']) && p['role'] == 'audience'
    ).toList();

    if (handsRaisedUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.front_hand_outlined,
              color: Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'No hands raised',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.front_hand,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Hands Raised (${handsRaisedUsers.length})',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...handsRaisedUsers.map((user) => _buildHandRaisedUser(user)),
        ],
      ),
    );
  }

  Widget _buildHandRaisedUser(Map<String, dynamic> user) {
    final userProfile = _userProfiles[user['userId']];
    final displayName = userProfile?.displayName ?? 'User';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // User avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: accentPurple.withValues(alpha: 0.2),
            backgroundImage: userProfile?.avatar != null 
              ? NetworkImage(userProfile!.avatar!) 
              : null,
            child: userProfile?.avatar == null 
              ? Text(
                  userProfile?.initials ?? 'U',
                  style: const TextStyle(
                    color: deepPurple,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
          ),
          const SizedBox(width: 15),
          
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: deepPurple,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Wants to speak',
                  style: TextStyle(
                    color: Colors.orange.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          
          // Promote button
          ElevatedButton.icon(
            onPressed: () {
              _promoteToSpeaker(user['userId']);
              Navigator.pop(context); // Close modal after action
            },
            icon: const Icon(
              Icons.mic,
              size: 16,
              color: Colors.white,
            ),
            label: const Text(
              'Make Speaker',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: deepPurple,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.close,
                label: 'Close Room',
                color: scarletRed,
                onTap: () {
                  Navigator.pop(context);
                  _closeRoom();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserManagementSection() {
    // Get participants with raised hands
    final raisedHands = _participants.where((p) => _handsRaised.contains(p['userId'])).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manage Participants',
          style: TextStyle(
            color: deepPurple,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 15),
        
        // Raised hands section (priority display)
        if (raisedHands.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.pan_tool, color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              Text(
                'Raised Hands (${raisedHands.length})',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...raisedHands.map((participant) => _buildUserManagementTile(
            participant,
            'raised_hand',
            canPromote: true,
            hasRaisedHand: true,
          )),
          const SizedBox(height: 20),
        ],
        
        // Speakers section
        if (_speakers.isNotEmpty) ...[
          Text(
            'Speakers (${_speakers.length})',
            style: const TextStyle(
              color: deepPurple,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          ..._speakers.map((speaker) => _buildUserManagementTile(
            speaker,
            'speaker',
            canDemote: speaker['userId'] != _currentAppwriteUserId,
            hasRaisedHand: _handsRaised.contains(speaker['userId']),
          )),
          const SizedBox(height: 20),
        ],
        
        // Audience section  
        if (_audience.isNotEmpty) ...[
          Text(
            'Audience (${_audience.length})',
            style: const TextStyle(
              color: deepPurple,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          ..._audience.map((audienceMember) => _buildUserManagementTile(
            audienceMember,
            'audience',
            canPromote: true,
            hasRaisedHand: _handsRaised.contains(audienceMember['userId']),
          )),
        ],
      ],
    );
  }

  Widget _buildUserManagementTile(
    Map<String, dynamic> user,
    String role, {
    bool canPromote = false,
    bool canDemote = false,
    bool hasRaisedHand = false,
  }) {
    final userProfile = _userProfiles[user['userId']];
    final displayName = userProfile?.displayName ?? 'User';
    final isCurrentUser = user['userId'] == _currentAppwriteUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser 
          ? accentPurple.withValues(alpha: 0.1) 
          : Colors.grey.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(
          color: isCurrentUser 
            ? accentPurple.withValues(alpha: 0.3)
            : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // User avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: accentPurple.withValues(alpha: 0.2),
            backgroundImage: userProfile?.avatar != null 
              ? NetworkImage(userProfile!.avatar!) 
              : null,
            child: userProfile?.avatar == null 
              ? Text(
                  userProfile?.initials ?? 'U',
                  style: const TextStyle(
                    color: deepPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
          ),
          const SizedBox(width: 12),
          
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isCurrentUser ? '$displayName (You)' : displayName,
                        style: TextStyle(
                          color: deepPurple,
                          fontSize: 14,
                          fontWeight: isCurrentUser ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (hasRaisedHand) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.pan_tool,
                        color: Colors.orange,
                        size: 16,
                      ),
                    ],
                  ],
                ),
                Text(
                  role == 'raised_hand' 
                    ? 'Wants to speak' 
                    : role == 'speaker' 
                      ? 'Can speak' 
                      : 'Listening',
                  style: TextStyle(
                    color: role == 'raised_hand' 
                      ? Colors.orange
                      : role == 'speaker' 
                        ? Colors.green 
                        : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: role == 'raised_hand' ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          
          // Action buttons
          if (canPromote && !isCurrentUser)
            TextButton(
              onPressed: () {
                _promoteToSpeaker(user['userId']);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
              ),
              child: const Text(
                'Promote',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          
          if (canDemote && !isCurrentUser)
            TextButton(
              onPressed: () {
                _demoteToAudience(user['userId']);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
              ),
              child: const Text(
                'Demote',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Timer functionality


  // Audio methods for timer sounds
  Future<void> _playChimeSound() async {
    if (!mounted) return;
    
    try {
      await _audioPlayer.play(AssetSource('audio/30sec.mp3'));
      debugPrint('🔔 Playing 30-second chime');
    } catch (e) {
      debugPrint('❌ Error playing chime sound: $e');
      // Don't rethrow - just log the error
    }
  }

  Future<void> _playBuzzerSound() async {
    if (!mounted) return;
    
    try {
      await _audioPlayer.play(AssetSource('audio/zero.mp3'));
      debugPrint('🔊 Playing timer finished buzzer');
    } catch (e) {
      debugPrint('❌ Error playing buzzer sound: $e');
      // Don't rethrow - just log the error
    }
  }

  void _startFallbackRefresh() {
    // Cancel any existing fallback timer
    _fallbackRefreshTimer?.cancel();
    
    if (!_isRealtimeHealthy && mounted) {
      debugPrint('🔄 Starting fallback refresh timer (every 30 seconds)');
      
      _fallbackRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        if (!_isRealtimeHealthy) {
          debugPrint('🔄 Fallback refresh: updating participants');
          _loadRoomParticipants();
        } else {
          // Stop fallback refresh when realtime is restored
          debugPrint('✅ Realtime restored, stopping fallback refresh');
          timer.cancel();
        }
      });
    }
  }

  void _stopFallbackRefresh() {
    _fallbackRefreshTimer?.cancel();
    _fallbackRefreshTimer = null;
    debugPrint('🛑 Stopped fallback refresh timer');
  }
}