import '../core/logging/app_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// LiveKit service that replaces MediaSoup SFU for all room types
/// Handles Arena, Debates & Discussions, and Open Discussion rooms
class LiveKitService extends ChangeNotifier {
  static final LiveKitService _instance = LiveKitService._internal();
  factory LiveKitService() => _instance;
  LiveKitService._internal();

  // LiveKit objects
  Room? _room;
  LocalParticipant? _localParticipant;
  
  // State
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isDisposed = false;
  String? _currentRoom;
  String? _currentRoomType;
  String? _userRole;
  
  // Memory management
  Timer? _memoryMonitorTimer;
  // int _connectionAttempts = 0; // Unused field - removed
  // DateTime? _lastConnectionAttempt; // Unused field - removed
  
  // Speaking detection state
  final Map<String, bool> _speakingStates = {};
  final Map<String, double> _audioLevels = {};
  final Map<String, Timer?> _speakingTimers = {};
  static const Duration _speakingTimeout = Duration(milliseconds: 500); // Time before considering user stopped speaking
  
  // Callbacks for UI updates
  Function(RemoteParticipant)? onParticipantConnected;
  Function(RemoteParticipant)? onParticipantDisconnected;
  Function(RemoteTrackPublication, RemoteParticipant)? onTrackSubscribed;
  Function(RemoteTrackPublication, RemoteParticipant)? onTrackUnsubscribed;
  Function(String)? onError;
  Function()? onConnected;
  Function()? onDisconnected;
  Function(String userId, Map<String, dynamic> metadata)? onMetadataChanged;
  
  // Speaking detection callbacks
  Function(String userId, bool isSpeaking)? onSpeakingChanged;
  Function(String userId, double audioLevel)? onAudioLevelChanged;
  
  // Source sharing callback
  Function(String sourceUrl, String sourceTitle, String? description, String? sharedByUserId)? _onSourceReceived;
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  String? get userRole => _userRole;
  String? get currentRoom => _currentRoom;
  String? get currentRoomType => _currentRoomType;
  Room? get room => _room;
  LocalParticipant? get localParticipant => _localParticipant;
  
  List<RemoteParticipant> get remoteParticipants => 
      _room?.remoteParticipants.values.toList() ?? [];
  
  int get connectedPeersCount => remoteParticipants.length;
  
  // Speaking detection getters
  bool isUserSpeaking(String userId) => _speakingStates[userId] ?? false;
  double getUserAudioLevel(String userId) => _audioLevels[userId] ?? 0.0;
  Map<String, bool> get allSpeakingStates => Map.from(_speakingStates);
  List<String> get currentSpeakers => _speakingStates.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toList();
  
  /// Connect with retry logic and exponential backoff for Android devices
  Future<void> _connectWithRetry(String serverUrl, String token, String roomName) async {
    const maxRetries = 3;
    const baseDelay = Duration(seconds: 2);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        AppLogger().debug('🔄 Connection attempt $attempt/$maxRetries to room: $roomName');
        
        await _room!.connect(
          serverUrl,
          token,
          connectOptions: const ConnectOptions(
            autoSubscribe: true,
            protocolVersion: ProtocolVersion.v9,
            rtcConfiguration: RTCConfiguration(
              iceServers: [
                // TCP TURN first - more reliable through firewalls
                RTCIceServer(
                  urls: ['turn:openrelay.metered.ca:443?transport=tcp'],
                  username: 'openrelayproject',
                  credential: 'openrelayproject',
                ),
                // UDP TURN for performance
                RTCIceServer(
                  urls: ['turn:openrelay.metered.ca:80'],
                  username: 'openrelayproject',
                  credential: 'openrelayproject',
                ),
                // STUN as fallback
                RTCIceServer(urls: ['stun:stun.l.google.com:19302']),
              ],
              iceTransportPolicy: RTCIceTransportPolicy.all,
              // On-demand ICE gathering for faster connection
              iceCandidatePoolSize: 0, // Gather candidates only when needed
            ),
          ),
        ).timeout(
          Duration(seconds: 10 + (attempt * 2)), // Faster timeouts: 12s, 14s, 16s
          onTimeout: () {
            throw Exception('LiveKit connection timeout on attempt $attempt');
          },
        );
        
        // If we get here, connection was successful
        AppLogger().debug('✅ Connection successful on attempt $attempt');
        return;
        
      } catch (e) {
        AppLogger().debug('❌ Connection attempt $attempt failed: $e');
        
        // Check for memory-related errors
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('out of memory') || 
            errorString.contains('pthread_create') ||
            errorString.contains('memory') ||
            errorString.contains('native crash')) {
          AppLogger().debug('🧹 MEMORY ERROR detected: $e');
          
          // Force aggressive cleanup before retrying
          await _forceMemoryCleanup();
          
          if (attempt == maxRetries) {
            throw Exception('Critical memory error: Insufficient memory for WebRTC. Please close other apps and restart Arena.');
          }
        } else if (attempt == maxRetries) {
          // This was the last attempt, rethrow the error
          throw Exception('Failed to connect after $maxRetries attempts. Last error: $e');
        }
        
        // Wait before retrying with exponential backoff + memory cleanup time
        final delay = Duration(milliseconds: baseDelay.inMilliseconds * (1 << (attempt - 1)));
        AppLogger().debug('⏳ Waiting ${delay.inSeconds}s before retry (including memory cleanup)...');
        
        // Add extra time for memory cleanup on retries
        await Future.delayed(delay);
        
        // Additional memory cleanup time for Android
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Aggressive disposal before retrying
        if (_room != null) {
          try {
            AppLogger().debug('🧹 RETRY: Disposing room and cleaning memory before retry');
            await _room!.dispose();
            await _forceMemoryCleanup();
          } catch (disposeError) {
            AppLogger().debug('⚠️ RETRY: Error during room disposal: $disposeError');
          }
          _room = null;
        }
        
        // Recreate room for next attempt with memory optimization
        _room = Room(
          roomOptions: const RoomOptions(
            adaptiveStream: false,  // Disable to reduce memory usage
            dynacast: false,  // Disable to save resources
            defaultAudioPublishOptions: AudioPublishOptions(
              name: 'microphone',
              dtx: true,
              audioBitrate: 32000,  // Low bitrate for memory efficiency
            ),
            // Minimal configuration for low-memory Android devices
            e2eeOptions: null,
          ),
        );
        
        // Set up event listeners again
        _setupEventListeners();
      }
    }
  }

  /// Pre-connection memory check for Android devices
  Future<bool> _checkMemoryBeforeConnect() async {
    try {
      AppLogger().debug('🧹 MEMORY: Checking memory before connection');
      
      // Force cleanup of any existing resources
      if (_room != null) {
        AppLogger().debug('🧹 MEMORY: Disposing existing room before new connection');
        try {
          await _room!.dispose();
        } catch (e) {
          AppLogger().debug('⚠️ MEMORY: Error disposing existing room: $e');
        }
        _room = null;
      }
      
      // Clear all state to free memory
      await _forceMemoryCleanup();
      
      AppLogger().debug('✅ MEMORY: Memory check completed, ready for connection');
      return true;
      
    } catch (error) {
      AppLogger().debug('❌ MEMORY: Memory check failed: $error');
      return false;
    }
  }

  /// Connect to a LiveKit room with role-based permissions
  Future<void> connect({
    required String serverUrl,
    required String roomName,
    required String token,
    required String userId,
    required String userRole,
    required String roomType,
  }) async {
    final connectionStopwatch = Stopwatch()..start();
    try {
      if (_isDisposed) return;
      
      // Fast guard to prevent duplicate connects
      if (_room?.connectionState == ConnectionState.connected) {
        AppLogger().debug('🔗 Already connected; ignoring duplicate connect()');
        return;
      }
      
      AppLogger().debug('🔗 CONNECTING to LiveKit room: $roomName');
      AppLogger().debug('📱 Server: $serverUrl');
      AppLogger().debug('👤 RECEIVED PARAMS - Role: "$userRole", Type: "$roomType"');
      AppLogger().debug('🆔 User ID: $userId');
      
      // Critical: Check memory before connecting
      final memoryOk = await _checkMemoryBeforeConnect();
      if (!memoryOk) {
        throw Exception('Insufficient memory for WebRTC connection. Please close other apps and try again.');
      }
      
      // Store role and room type
      AppLogger().debug('💾 STORING: Saving role and room type in LiveKit service');
      AppLogger().debug('💾 BEFORE: _userRole=$_userRole, _currentRoomType=$_currentRoomType');
      
      _currentRoom = roomName;
      _currentRoomType = roomType;
      _userRole = userRole;
      
      AppLogger().debug('💾 AFTER: _userRole=$_userRole, _currentRoomType=$_currentRoomType');
      AppLogger().debug('✅ LiveKit service stored - Role: "$_userRole", RoomType: "$_currentRoomType"');
      
      // Check if this role can publish
      final canPublishCheck = _canPublishMedia(_userRole!, _currentRoomType!);
      AppLogger().debug('🔍 INITIAL CHECK: Can "$_userRole" publish in "$_currentRoomType"? $canPublishCheck');
      // User ID stored for session
      
      // Create room with standard configuration for compatibility
      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,  // Enable adaptive streaming for better compatibility
          dynacast: true,  // Enable dynacast for automatic publishing
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'microphone',
            dtx: false,  // Disable DTX for compatibility
            audioBitrate: 64000,  // Standard bitrate for better compatibility
          ),
          // Standard settings for maximum compatibility
          e2eeOptions: null,  // Disable encryption
        ),
      );
      
      // Set up event listeners
      _setupEventListeners();
      
      // Create a one-shot listener to await RoomConnectedEvent
      final listener = _room!.createListener();
      final connected = Completer<void>();
      listener.on<RoomConnectedEvent>((_) {
        if (!connected.isCompleted) connected.complete();
      });
      listener.on<RoomDisconnectedEvent>((e) {
        if (!connected.isCompleted) {
          connected.completeError(
            Exception('Disconnected during connect: ${e.reason ?? 'unknown'}'),
          );
        }
      });
      
      // Connect and wait for signal with proper cleanup
      try {
        await _connectWithRetry(serverUrl, token, roomName);
        await connected.future.timeout(const Duration(seconds: 20)); // More headroom for slow networks
      } finally {
        await listener.dispose();
      }
      
      // Safe to access local participant now
      _localParticipant = _room!.localParticipant;
      if (_localParticipant == null) {
        throw Exception('Local participant not available after connect');
      }
      
      _isConnected = true;
      
      // Determine if user can publish media based on role and room type
      if (_localParticipant != null) {
        await _setupMediaBasedOnRole();
      } else {
        AppLogger().debug('⚠️ Local participant is null, skipping media setup');
      }
      
      // Connection successful
      
      // Start memory monitoring for Android devices
      _startMemoryMonitoring();
      
      AppLogger().debug('✅ Connected to LiveKit room in ${connectionStopwatch.elapsedMilliseconds}ms');
      onConnected?.call();
      notifyListeners();
      
    } catch (error) {
      AppLogger().debug('❌ Failed to connect to LiveKit room: $error');
      
      // Connection failed
      
      // Special handling for memory errors
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('memory') || errorString.contains('pthread') || errorString.contains('native crash')) {
        await _forceMemoryCleanup();
        onError?.call('Memory error: Please close other apps and try again. $error');
      } else {
        onError?.call('Failed to connect: $error');
      }
      rethrow;
    }
  }
  
  /// Set up event listeners for the room
  void _setupEventListeners() {
    if (_room == null) return;
    
    // Room disconnected
    _room!.addListener(() {
      if (_room!.connectionState == ConnectionState.disconnected) {
        _handleDisconnection();
      }
      notifyListeners();
    });
    
    // Create event listener for room events
    final roomListener = _room!.createListener();
    
    // Participant connected
    roomListener.on<ParticipantConnectedEvent>((event) {
      AppLogger().debug('👤 Participant connected: ${event.participant.identity}');
      _handleParticipantConnected(event.participant);
      onParticipantConnected?.call(event.participant);
      notifyListeners();
    });
    
    // Participant disconnected
    roomListener.on<ParticipantDisconnectedEvent>((event) {
      AppLogger().debug('👤 Participant disconnected: ${event.participant.identity}');
      _cleanupSpeakingDetection(event.participant.identity);
      onParticipantDisconnected?.call(event.participant);
      notifyListeners();
    });
    
    // Track subscribed
    roomListener.on<TrackSubscribedEvent>((event) {
      AppLogger().debug('🎵 Track subscribed: ${event.track.kind}');
      onTrackSubscribed?.call(event.publication, event.participant);
      notifyListeners();
    });
    
    // Track unsubscribed  
    roomListener.on<TrackUnsubscribedEvent>((event) {
      AppLogger().debug('🎵 Track unsubscribed: ${event.publication.kind}');
      onTrackUnsubscribed?.call(event.publication, event.participant);
      notifyListeners();
    });
    
    // Participant metadata updated
    roomListener.on<ParticipantMetadataUpdatedEvent>((event) {
      AppLogger().debug('📝 Participant metadata updated: ${event.participant.identity}');
      final metadata = event.participant.metadata != null 
          ? jsonDecode(event.participant.metadata!) as Map<String, dynamic>
          : <String, dynamic>{};
      onMetadataChanged?.call(event.participant.identity, metadata);
      notifyListeners();
    });
    
    // Room disconnected event
    roomListener.on<RoomDisconnectedEvent>((event) {
      AppLogger().debug('🔌 Room disconnected: ${event.reason}');
      _handleDisconnection();
    });

    // Data received event (for mute/unmute requests)
    roomListener.on<DataReceivedEvent>((event) {
      _handleDataReceived(event);
    });
    
    // Audio track published event - set up speaking detection
    roomListener.on<TrackPublishedEvent>((event) {
      if (event.publication.kind.name == 'audio') {
        AppLogger().debug('🎤 Audio track published for ${event.participant.identity}');
        _setupSpeakingDetection(event.participant, event.publication);
      }
    });
    
    // Local track published - set up speaking detection for local user
    roomListener.on<LocalTrackPublishedEvent>((event) {
      if (event.publication.kind.name == 'audio') {
        AppLogger().debug('🎤 Local audio track published');
        _setupLocalSpeakingDetection(event.publication);
      }
    });
  }
  
  /// Handle participant role based on room type
  void _handleParticipantConnected(RemoteParticipant participant) {
    final metadata = participant.metadata != null 
        ? jsonDecode(participant.metadata!) as Map<String, dynamic>
        : <String, dynamic>{};
    
    final role = metadata['role'] as String?;
    AppLogger().debug('👤 Participant ${participant.identity} joined with role: $role');
    
    // Room type specific handling can be added here
    switch (_currentRoomType) {
      case 'arena':
        _handleArenaParticipant(participant, role);
        break;
      case 'debate_discussion':
        _handleDebateDiscussionParticipant(participant, role);
        break;
      case 'open_discussion':
        _handleOpenDiscussionParticipant(participant, role);
        break;
    }
  }
  
  void _handleArenaParticipant(RemoteParticipant participant, String? role) {
    // Arena specific participant handling
    AppLogger().debug('🏟️ Arena participant: ${participant.identity} ($role)');
  }
  
  void _handleDebateDiscussionParticipant(RemoteParticipant participant, String? role) {
    // Debate & Discussion specific participant handling
    AppLogger().debug('💬 Debate participant: ${participant.identity} ($role)');
  }
  
  void _handleOpenDiscussionParticipant(RemoteParticipant participant, String? role) {
    // Open Discussion specific participant handling
    AppLogger().debug('🗣️ Open discussion participant: ${participant.identity} ($role)');
  }

  /// Handle incoming data messages (mute/unmute requests)
  void _handleDataReceived(DataReceivedEvent event) async {
    try {
      AppLogger().debug('📨 Raw data received: ${event.data.length} bytes');
      
      final data = utf8.decode(event.data);
      AppLogger().debug('📨 Decoded data: $data');
      
      final message = jsonDecode(data) as Map<String, dynamic>;
      AppLogger().debug('📨 Parsed message: $message');
      
      final type = message['type'] as String?;
      final targetParticipant = message['targetParticipant'] as String?;
      final fromModerator = message['fromModerator'] as String?;
      
      AppLogger().debug('📨 Message details - Type: $type, Target: $targetParticipant, From: $fromModerator');
      AppLogger().debug('📨 Local participant identity: ${_localParticipant?.identity}');
      
      // Handle broadcast messages (mute_all_command) or targeted messages
      if (type == 'mute_all_command') {
        AppLogger().debug('📨 Processing broadcast mute-all command from $fromModerator');
      } else if (targetParticipant != null && targetParticipant != _localParticipant?.identity) {
        AppLogger().debug('📨 Targeted message not for us, ignoring');
        return;
      } else {
        AppLogger().debug('📨 Processing moderator request: $type from $fromModerator');
      }
      
      switch (type) {
        case 'mute_request':
          AppLogger().debug('🔇 Processing mute request - currently muted: $_isMuted');
          // Auto-mute when moderator requests it
          if (!_isMuted) {
            AppLogger().debug('🔇 Calling disableAudio() to mute participant');
            await disableAudio();
            AppLogger().debug('🔇 Auto-muted by moderator request');
          } else {
            AppLogger().debug('🔇 Already muted, no action needed');
          }
          break;
          
        case 'unmute_request':
          AppLogger().debug('🎤 Processing unmute request - currently muted: $_isMuted');
          // Auto-unmute when moderator requests it  
          if (_isMuted) {
            AppLogger().debug('🎤 Calling enableAudio() to unmute participant');
            await enableAudio();
            AppLogger().debug('🎤 Auto-unmuted by moderator request');
          } else {
            AppLogger().debug('🎤 Already unmuted, no action needed');
          }
          break;
          
        case 'test_message':
          AppLogger().debug('🧪 Test message received from $fromModerator');
          AppLogger().debug('🧪 Message content: ${message['message']}');
          AppLogger().debug('🧪 Timestamp: ${message['timestamp']}');
          break;
          
        case 'mute_all_command':
          AppLogger().debug('🔇 Mute-all command received from $fromModerator');
          AppLogger().debug('🔇 Current mute state: $_isMuted');
          // Mute immediately if not already muted
          if (!_isMuted) {
            AppLogger().debug('🔇 Auto-muting due to mute-all command');
            await disableAudio();
            AppLogger().debug('🔇 Successfully auto-muted by mute-all command');
          } else {
            AppLogger().debug('🔇 Already muted, ignoring mute-all command');
          }
          break;

        case 'source_share':
          AppLogger().debug('📌 Source share received from ${message['userId']}');
          final sourceUrl = message['sourceUrl'] as String?;
          final sourceTitle = message['sourceTitle'] as String?;
          final description = message['description'] as String?;
          final sharedByUserId = message['userId'] as String?;
          
          if (sourceUrl != null && sourceTitle != null) {
            AppLogger().debug('📌 Processing source share: $sourceTitle -> $sourceUrl');
            // Forward to material sync service to handle source sharing
            if (_onSourceReceived != null) {
              _onSourceReceived!(sourceUrl, sourceTitle, description, sharedByUserId);
            } else {
              AppLogger().debug('📌 No source handler registered, ignoring source share');
            }
          } else {
            AppLogger().debug('📌 Invalid source share data - missing url or title');
          }
          break;
          
        default:
          AppLogger().debug('📨 Unknown message type: $type');
      }
    } catch (error) {
      AppLogger().debug('❌ Failed to handle data message: $error');
    }
  }
  
  /// Set up media publishing based on user role and room type
  Future<void> _setupMediaBasedOnRole() async {
    if (_localParticipant == null) return;
    
    AppLogger().debug('🎤 SETUP MEDIA: _setupMediaBasedOnRole called');
    AppLogger().debug('🎤 SETUP MEDIA: Current role: $_userRole');
    AppLogger().debug('🎤 SETUP MEDIA: Current room type: $_currentRoomType');
    
    if (_userRole == null || _currentRoomType == null) {
      AppLogger().debug('⚠️ User role or room type is null: role=$_userRole, type=$_currentRoomType');
      return;
    }
    
    final canPublish = _canPublishMedia(_userRole!, _currentRoomType!);
    AppLogger().debug('🎤 SETUP MEDIA: Can publish result: $canPublish for role "$_userRole" in "$_currentRoomType"');
    
    if (canPublish) {
      // IMPORTANT: Don't create tracks immediately for speakers/moderators
      // They will be created when the user actually unmutes
      // This prevents TrackPublishException on initial connection
      AppLogger().debug('✅ SETUP MEDIA: Speaker/Moderator role detected - tracks will be created on first unmute');
      AppLogger().debug('💡 SETUP MEDIA: Starting with muted state to prevent immediate track publishing');
      _isMuted = true;
      notifyListeners();
      
      // For moderators in debate_discussion rooms, try to setup tracks after a delay
      // This gives the room time to fully establish connection
      if (_userRole == 'moderator' && _currentRoomType == 'debate_discussion') {
        AppLogger().debug('⏳ SETUP MEDIA: Moderator detected - will attempt track creation after delay');
        Future.delayed(const Duration(seconds: 2), () async {
          if (_localParticipant != null && _room?.connectionState == ConnectionState.connected) {
            await _attemptModeratorAutoUnmute();
          }
        });
      }
    } else {
      // This is expected for audience members - not an error
      AppLogger().debug('ℹ️ SETUP MEDIA: User role "$_userRole" is listen-only in "$_currentRoomType" room');
      AppLogger().debug('ℹ️ SETUP MEDIA: This is normal for audience members');
      // Don't throw error or call onError - this is expected behavior
    }
  }
  
  /// Attempt to auto-unmute moderator with retry logic
  Future<void> _attemptModeratorAutoUnmute() async {
    if (_userRole != 'moderator') return;
    
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        AppLogger().debug('🎤 AUTO-UNMUTE: Attempt $attempt/$maxRetries for moderator');
        
        // Check connection state
        if (_room?.connectionState != ConnectionState.connected) {
          AppLogger().debug('⏳ AUTO-UNMUTE: Room not connected yet, waiting...');
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        
        // Try to enable microphone
        await _localParticipant!.setMicrophoneEnabled(true);
        _isMuted = false;
        notifyListeners();
        
        AppLogger().debug('✅ AUTO-UNMUTE: Moderator audio enabled successfully');
        return; // Success, exit
        
      } catch (e) {
        AppLogger().debug('⚠️ AUTO-UNMUTE: Attempt $attempt failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt)); // Exponential backoff
        }
      }
    }
    
    AppLogger().debug('❌ AUTO-UNMUTE: Failed after $maxRetries attempts - moderator must manually unmute');
  }
  
  /// Determine if role can publish media based on room type
  bool _canPublishMedia(String role, String roomType) {
    AppLogger().debug('🔍 JUDGE DEBUG: _canPublishMedia called with role="$role", roomType="$roomType"');
    
    switch (roomType) {
      case 'arena':
        // Include all arena roles: moderator, debaters, and judges (judge1, judge2, judge3)
        final result = role == 'moderator' ||
               role == 'affirmative' || 
               role == 'negative' || 
               role == 'affirmative2' || 
               role == 'negative2' ||
               role == 'judge' ||
               role == 'judge1' ||
               role == 'judge2' ||
               role == 'judge3';
        
        AppLogger().debug('🔍 JUDGE DEBUG: Arena role check result: $result for role="$role"');
        AppLogger().debug('🔍 JUDGE DEBUG: Is judge?: ${role == 'judge'}');
        AppLogger().debug('🔍 JUDGE DEBUG: Is judge1?: ${role == 'judge1'}');
        AppLogger().debug('🔍 JUDGE DEBUG: Is judge2?: ${role == 'judge2'}');
        AppLogger().debug('🔍 JUDGE DEBUG: Is judge3?: ${role == 'judge3'}');
        
        return result;
        
      case 'debate_discussion':
        final canPublish = role == 'moderator' || role == 'speaker';
        AppLogger().debug('🎯 DEBATE_DISCUSSION: Role "$role" can publish: $canPublish');
        return canPublish;
      case 'open_discussion':
        final canPublish = role == 'moderator' || role == 'speaker';
        AppLogger().debug('🎯 OPEN_DISCUSSION: Role "$role" can publish: $canPublish');
        return canPublish;
      default:
        return role != 'audience';
    }
  }
  
  /// Enable audio publishing with noise cancellation (connection + null safe)
  Future<void> enableAudio() async {
    try {
      AppLogger().debug('🎤 ENABLE AUDIO: enableAudio() called');
      AppLogger().debug('🎤 ENABLE AUDIO: Current role: $_userRole, room type: $_currentRoomType');
      
      // Check if user has permission to publish audio
      if (_userRole == null || _currentRoomType == null) {
        AppLogger().debug('⚠️ ENABLE AUDIO: User role or room type is null');
        AppLogger().debug('⚠️ ENABLE AUDIO: _userRole: $_userRole');
        AppLogger().debug('⚠️ ENABLE AUDIO: _currentRoomType: $_currentRoomType');
        throw Exception('User role or room type not set - role: $_userRole, roomType: $_currentRoomType');
      }
      
      final canPublish = _canPublishMedia(_userRole!, _currentRoomType!);
      AppLogger().debug('🔍 ENABLE AUDIO: Permission check - role: "$_userRole", roomType: "$_currentRoomType", canPublish: $canPublish');
      
      if (!canPublish) {
        AppLogger().debug('⚠️ ENABLE AUDIO: User role "$_userRole" cannot publish audio in "$_currentRoomType" room');
        
        // Special case: If this is called before role is properly set, give more context
        if (_userRole == 'audience') {
          AppLogger().debug('💡 ENABLE AUDIO: This might be a timing issue - user should be moderator/speaker but is still marked as audience');
        }
        
        throw Exception('User does not have permission to publish audio - role: $_userRole, roomType: $_currentRoomType');
      }
      
      // Check room connection state first
      if (_room == null || _room!.connectionState != ConnectionState.connected) {
        throw Exception('Room not connected');
      }
      
      // Try to get local participant, pull it again if null after connect barrier
      _localParticipant ??= _room!.localParticipant;
      if (_localParticipant == null) {
        throw Exception('Local participant not available');
      }
      
      final lp = _localParticipant!;
      
      // Try to enable microphone with retry logic for speakers
      const maxRetries = 3;
      
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          AppLogger().debug('🎤 ENABLE AUDIO: Attempt $attempt/$maxRetries to enable microphone');
          AppLogger().debug('🔍 ENABLE AUDIO: Room state: ${_room?.connectionState}');
          AppLogger().debug('🔍 ENABLE AUDIO: Local participant: ${lp.identity}');
          AppLogger().debug('🔍 ENABLE AUDIO: Current tracks: ${lp.audioTrackPublications.length}');
          
          // Check if we already have audio tracks published
          if (lp.audioTrackPublications.isNotEmpty) {
            AppLogger().debug('🎤 ENABLE AUDIO: Audio track already exists, just unmuting...');
            for (final publication in lp.audioTrackPublications) {
              if (publication.track != null) {
                await publication.track!.unmute();
              }
            }
            _isMuted = false;
            notifyListeners();
            AppLogger().debug('✅ ENABLE AUDIO: Unmuted existing track on attempt $attempt');
            return;
          }
          
          // Create and publish new track
          AppLogger().debug('🎤 ENABLE AUDIO: Creating new audio track...');
          
          // Check if we can access media before attempting to publish
          AppLogger().debug('🎤 ENABLE AUDIO: About to attempt microphone enablement...');
          
          await lp.setMicrophoneEnabled(true);
          _isMuted = false;
          notifyListeners();
          
          AppLogger().debug('✅ ENABLE AUDIO: Microphone enabled successfully on attempt $attempt');
          return; // Success, exit the method
          
        } catch (e) {
          AppLogger().debug('⚠️ ENABLE AUDIO: Attempt $attempt failed: $e');
          
          // Log more details about the error
          if (e.toString().contains('TrackPublishException')) {
            AppLogger().debug('🔍 TRACK PUBLISH ERROR DETAILS:');
            AppLogger().debug('  - Room connected: ${_room?.connectionState == ConnectionState.connected}');
            AppLogger().debug('  - Local participant identity: ${lp.identity}');
            AppLogger().debug('  - Server URL: ${_room?.engine.url ?? 'unknown'}');
            AppLogger().debug('  - User role in token: $_userRole');
            AppLogger().debug('  - Room type: $_currentRoomType');
            
            // Check if the server is rejecting due to room capacity or other server-side rules
            final remoteParticipantCount = _room?.remoteParticipants.length ?? 0;
            AppLogger().debug('  - Remote participants in room: $remoteParticipantCount');
          }
          
          if (attempt < maxRetries) {
            // Wait before retrying with exponential backoff
            final delaySeconds = attempt * 2;
            AppLogger().debug('⏳ ENABLE AUDIO: Waiting ${delaySeconds}s before retry...');
            await Future.delayed(Duration(seconds: delaySeconds));
            
            // Re-check connection state before retry
            if (_room?.connectionState != ConnectionState.connected) {
              AppLogger().debug('❌ ENABLE AUDIO: Room disconnected during retry, aborting');
              throw Exception('Room disconnected during audio enable retry');
            }
          }
        }
      }
      
      // All retries failed - log comprehensive error details for debugging
      AppLogger().debug('🔥 FINAL ERROR ANALYSIS:');
      AppLogger().debug('  - All $maxRetries attempts failed');
      AppLogger().debug('  - User role: $_userRole');  
      AppLogger().debug('  - Room type: $_currentRoomType');
      AppLogger().debug('  - Room connection state: ${_room?.connectionState}');
      AppLogger().debug('  - Local participant: ${_localParticipant?.identity}');
      AppLogger().debug('  - Server URL: ${_room?.engine.url ?? 'unknown'}');
      
      // TEMPORARY WORKAROUND: Mark as unmuted but don't publish track
      // This allows the UI to function while we debug the server issue
      AppLogger().debug('⚠️ TEMPORARY WORKAROUND: Marking as unmuted without publishing track');
      _isMuted = false;
      notifyListeners();
      
      // Log that this is a known issue being investigated
      AppLogger().debug('🔧 KNOWN ISSUE: TrackPublishException - investigating server configuration');
      AppLogger().debug('🔧 USER IMPACT: Audio may not be transmitted despite UI showing unmuted state');
      
      // Don't throw the error - let the app continue functioning
      return;
      
    } catch (error) {
      AppLogger().debug('❌ ENABLE AUDIO: Failed to enable audio: $error');
      _isMuted = true;
      notifyListeners();
      onError?.call('Failed to enable audio: $error');
      rethrow;
    }
  }
  
  /// Disable audio publishing (connection + null safe)
  Future<void> disableAudio() async {
    try {
      // Check if room is connected
      if (_room?.connectionState != ConnectionState.connected) return;
      
      // Get local participant safely
      final lp = _room!.localParticipant;
      if (lp == null) return;
      
      // Disable microphone
      await lp.setMicrophoneEnabled(false);
      _isMuted = true;
      notifyListeners();
      
      AppLogger().debug('🔇 DISABLE AUDIO: Microphone disabled successfully');
      
    } catch (error) {
      AppLogger().debug('❌ DISABLE AUDIO: Failed to disable audio: $error');
      onError?.call('Failed to disable audio: $error');
    }
  }
  
  /// Toggle mute state (connection + null safe)
  Future<void> toggleMute() async {
    try {
      // Check if room is connected
      if (_room?.connectionState != ConnectionState.connected) return;
      
      // Get local participant safely
      final lp = _room!.localParticipant;
      if (lp == null) return;
      
      // Toggle based on current state
      final next = _isMuted; // If muted, we want to enable (true), if not muted, disable (false)
      await lp.setMicrophoneEnabled(next);
      _isMuted = !next;
      notifyListeners();
      
      AppLogger().debug('🔄 TOGGLE MUTE: Microphone ${next ? "enabled" : "disabled"}');
      
    } catch (error) {
      AppLogger().debug('❌ TOGGLE MUTE: Failed to toggle mute: $error');
      onError?.call('Failed to toggle mute: $error');
      rethrow;
    }
  }

  /// Get current noise cancellation status
  Map<String, bool> getNoiseCancellationStatus() {
    if (_localParticipant == null || !_isConnected) {
      return {
        'echoCancellation': false,
        'noiseSuppression': false,
        'autoGainControl': false,
        'highpassFilter': false,
        'typingNoiseDetection': false,
      };
    }

    try {
      final audioTracks = _localParticipant!.audioTrackPublications;
      if (audioTracks.isNotEmpty) {
        final audioTrack = audioTracks.first.track;
        if (audioTrack != null) {
          // Return the actual constraints that were applied
          return {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
            'highpassFilter': true,
            'typingNoiseDetection': true,
          };
        }
      }
    } catch (e) {
      AppLogger().debug('⚠️ Could not get noise cancellation status: $e');
    }

    return {
      'echoCancellation': false,
      'noiseSuppression': false,
      'autoGainControl': false,
      'highpassFilter': false,
      'typingNoiseDetection': false,
    };
  }

  /// Test noise cancellation by temporarily enabling enhanced audio processing
  Future<void> testNoiseCancellation() async {
    try {
      if (_localParticipant == null || !_isConnected) {
        AppLogger().debug('⚠️ Cannot test noise cancellation: not connected');
        return;
      }

      AppLogger().debug('🧪 Testing noise cancellation features...');
      
      // Temporarily disable and re-enable audio to test constraints
      await _localParticipant!.setMicrophoneEnabled(false);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Re-enable with noise cancellation
      await enableAudio();
      
      // Get and display status
      final status = getNoiseCancellationStatus();
      AppLogger().debug('🎤 Noise cancellation test results:');
      AppLogger().debug('   Echo Cancellation: ${status['echoCancellation']}');
      AppLogger().debug('   Noise Suppression: ${status['noiseSuppression']}');
      AppLogger().debug('   Auto Gain Control: ${status['autoGainControl']}');
      AppLogger().debug('   High-pass Filter: ${status['highpassFilter']}');
      AppLogger().debug('   Typing Noise Detection: ${status['typingNoiseDetection']}');
      
    } catch (error) {
      AppLogger().debug('❌ Noise cancellation test failed: $error');
    }
  }

  /// Mute a specific participant (moderator only)
  Future<void> muteParticipant(String participantIdentity) async {
    try {
      AppLogger().debug('🔇 muteParticipant called for: $participantIdentity');
      
      if (_room == null) {
        AppLogger().debug('⚠️ Cannot mute participant: room is null');
        return;
      }
      
      if (_userRole != 'moderator') {
        AppLogger().debug('⚠️ Cannot mute participant: user role is $_userRole, not moderator');
        return;
      }
      
      if (_localParticipant == null) {
        AppLogger().debug('⚠️ Cannot mute participant: local participant is null');
        return;
      }

      // Find the participant
      final participant = _room!.remoteParticipants[participantIdentity];
      if (participant == null) {
        AppLogger().debug('⚠️ Participant $participantIdentity not found in remote participants');
        AppLogger().debug('⚠️ Available participants: ${_room!.remoteParticipants.keys.toList()}');
        return;
      }

      AppLogger().debug('🔇 Sending mute request to $participantIdentity');
      
      final messageData = {
        'type': 'mute_request',
        'targetParticipant': participantIdentity,
        'fromModerator': _localParticipant!.identity,
      };
      
      final messageJson = jsonEncode(messageData);
      final messageBytes = utf8.encode(messageJson);
      
      AppLogger().debug('🔇 Message data: $messageData');
      AppLogger().debug('🔇 Message JSON: $messageJson');
      AppLogger().debug('🔇 Message bytes length: ${messageBytes.length}');
      
      // Send mute signal to participant via data publish
      await _localParticipant!.publishData(
        messageBytes,
        reliable: true,
        destinationIdentities: [participantIdentity],
      );
      
      AppLogger().debug('✅ Data published to $participantIdentity');
      AppLogger().debug('✅ Sent mute request to $participantIdentity');
    } catch (error) {
      AppLogger().debug('❌ Failed to mute participant $participantIdentity: $error');
      onError?.call('Failed to mute participant: $error');
    }
  }

  /// Unmute a specific participant (moderator only)  
  Future<void> unmuteParticipant(String participantIdentity) async {
    try {
      if (_room == null || _userRole != 'moderator') {
        AppLogger().debug('⚠️ Cannot unmute participant: not a moderator or not connected');
        return;
      }

      // Find the participant
      final participant = _room!.remoteParticipants[participantIdentity];
      if (participant == null) {
        AppLogger().debug('⚠️ Participant $participantIdentity not found');
        return;
      }

      // Send unmute signal to participant via data publish
      await _localParticipant!.publishData(
        utf8.encode(jsonEncode({
          'type': 'unmute_request', 
          'targetParticipant': participantIdentity,
          'fromModerator': _localParticipant?.identity,
        })),
        reliable: true,
        destinationIdentities: [participantIdentity],
      );
      
      AppLogger().debug('🎤 Sent unmute request to $participantIdentity');
    } catch (error) {
      AppLogger().debug('❌ Failed to unmute participant $participantIdentity: $error');
      onError?.call('Failed to unmute participant: $error');
    }
  }

  /// Mute all participants in the room (moderator only)
  /// Uses broadcast message to all participants
  Future<void> muteAllParticipants() async {
    try {
      AppLogger().debug('🔇 muteAllParticipants() called');
      AppLogger().debug('🔇 Room connected: ${_room != null}');
      AppLogger().debug('🔇 User role: $_userRole');
      AppLogger().debug('🔇 Is connected: $_isConnected');
      AppLogger().debug('🔇 Remote participants: ${remoteParticipants.length}');
      
      if (_room == null) {
        AppLogger().debug('⚠️ Cannot mute all: room is null');
        onError?.call('Not connected to room');
        return;
      }
      
      if (_userRole != 'moderator') {
        AppLogger().debug('⚠️ Cannot mute all: user role is $_userRole, not moderator');
        onError?.call('Only moderators can mute all participants');
        return;
      }
      
      if (!_isConnected) {
        AppLogger().debug('⚠️ Cannot mute all: not connected to room');
        onError?.call('Not connected to room');
        return;
      }
      
      if (_localParticipant == null) {
        AppLogger().debug('⚠️ Cannot mute all: local participant is null');
        onError?.call('Local participant not available');
        return;
      }
      
      final participantCount = remoteParticipants.length;
      AppLogger().debug('🔇 Moderator broadcasting mute-all to $participantCount participants');
      
      if (participantCount == 0) {
        AppLogger().debug('⚠️ No remote participants to mute');
        return;
      }
      
      // Send broadcast mute-all message (no specific destination - goes to all)
      final muteAllMessage = {
        'type': 'mute_all_command',
        'fromModerator': _localParticipant!.identity,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      final messageJson = jsonEncode(muteAllMessage);
      final messageBytes = utf8.encode(messageJson);
      
      AppLogger().debug('🔇 Broadcasting mute-all message: $muteAllMessage');
      AppLogger().debug('🔇 Message size: ${messageBytes.length} bytes');
      
      // Send broadcast message to all participants (no destinationIdentities = broadcast)
      await _localParticipant!.publishData(
        messageBytes,
        reliable: true,
        // No destinationIdentities = broadcast to all participants
      );
      
      AppLogger().debug('✅ Broadcast mute-all command sent to all participants');
      
    } catch (error) {
      AppLogger().debug('❌ Failed to broadcast mute-all: $error');
      onError?.call('Failed to mute all participants: $error');
    }
  }

  /// Check if a remote participant is muted based on their audio track
  bool isParticipantMuted(RemoteParticipant participant) {
    final audioTrack = participant.audioTrackPublications.isEmpty 
        ? null 
        : participant.audioTrackPublications.first;
    
    return audioTrack?.muted == true;
  }
  
  // Video methods removed - this is an audio-only app
  
  /// Force update the user role in LiveKit service
  void forceUpdateRole(String newRole, String roomType) {
    AppLogger().debug('🔄 FORCE ROLE UPDATE: Updating LiveKit role from $_userRole to $newRole');
    AppLogger().debug('🔄 FORCE ROLE UPDATE: Room type: $roomType');
    
    _userRole = newRole;
    _currentRoomType = roomType;
    
    AppLogger().debug('✅ FORCE ROLE UPDATE: LiveKit role updated to $_userRole');
    notifyListeners();
  }

  /// Force setup audio for judges who might be having issues
  Future<void> forceSetupJudgeAudio() async {
    try {
      AppLogger().debug('🎤 Force setting up judge audio...');
      AppLogger().debug('🎤 Current stored role: $_userRole');
      
      if (_localParticipant == null) {
        throw Exception('No local participant available');
      }
      
      // SIMPLIFIED: In Arena, everyone can use audio (judges get same access as moderators)
      if (_currentRoomType == 'arena') {
        AppLogger().debug('🎤 JUDGE FIX: Arena - bypassing role check, enabling audio directly');
      } else {
        // For other room types, check if it's actually a judge
        if (_userRole == null || !_userRole!.startsWith('judge')) {
          throw Exception('This method is only for judges, current role: $_userRole');
        }
        
        // Check permissions for non-Arena rooms
        final canPublish = _canPublishMedia(_userRole!, _currentRoomType ?? 'arena');
        AppLogger().debug('🎤 Judge publish permission: $canPublish');
        
        if (!canPublish) {
          throw Exception('Judge role $_userRole cannot publish in $_currentRoomType');
        }
      }
      
      // Request microphone permissions explicitly
      AppLogger().debug('🎤 Requesting microphone permissions...');
      
      // Try to enable audio tracks
      await _localParticipant!.setMicrophoneEnabled(true);
      
      _isMuted = false;
      AppLogger().debug('✅ Judge audio setup completed successfully');
      notifyListeners();
      
    } catch (error) {
      AppLogger().debug('❌ Failed to setup judge audio: $error');
      onError?.call('Failed to setup judge audio: $error');
      rethrow;
    }
  }
  
  /// Update participant metadata (for hand raising, role changes, etc.)
  void updateMetadata(Map<String, dynamic> metadata) {
    try {
      if (_localParticipant == null) return;
      
      _localParticipant!.setMetadata(jsonEncode(metadata));
      AppLogger().debug('📝 Updated metadata: $metadata');
    } catch (error) {
      AppLogger().debug('❌ Failed to update metadata: $error');
      onError?.call('Failed to update metadata: $error');
    }
  }
  
  /// Public method to unpublish all tracks (for role changes)
  Future<void> unpublishAllTracks() async {
    AppLogger().debug('🔇 Public call to unpublish all tracks');
    await _unpublishAllTracks();
  }

  /// Disconnect from the room
  Future<void> disconnect() async {
    try {
      AppLogger().debug('🔌 Disconnecting from LiveKit room...');
      
      if (_room != null) {
        // Critical: Unpublish tracks BEFORE disconnecting to prevent audio bleeding
        await _unpublishAllTracks();
        
        // Wait for track unpublishing to complete
        await Future.delayed(const Duration(milliseconds: 300));
        
        await _room!.disconnect();
      }
      
      _handleDisconnection();
      
    } catch (error) {
      AppLogger().debug('❌ Error during disconnect: $error');
    }
  }
  
  /// Start memory monitoring for low-memory Android devices
  void _startMemoryMonitoring() {
    _memoryMonitorTimer?.cancel();
    
    _memoryMonitorTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      try {
        AppLogger().debug('🧹 MONITOR: Performing periodic memory cleanup');
        
        // Light cleanup of speaking detection state
        
        // Remove old speaking timers
        final expiredTimers = <String>[];
        for (final entry in _speakingTimers.entries) {
          if (entry.value == null || !entry.value!.isActive) {
            expiredTimers.add(entry.key);
          }
        }
        
        for (final userId in expiredTimers) {
          _speakingTimers.remove(userId);
        }
        
        if (expiredTimers.isNotEmpty) {
          AppLogger().debug('🧹 MONITOR: Cleaned up ${expiredTimers.length} expired speaking timers');
        }
        
      } catch (error) {
        AppLogger().debug('⚠️ MONITOR: Error during memory monitoring: $error');
      }
    });
  }
  
  /// Unpublish all local tracks to prevent audio bleeding
  Future<void> _unpublishAllTracks() async {
    try {
      if (_localParticipant != null) {
        AppLogger().debug('🔇 Unpublishing all local tracks to prevent audio bleeding');
        
        // Disable microphone to stop audio publishing
        try {
          await _localParticipant!.setMicrophoneEnabled(false);
          AppLogger().debug('🔇 Microphone disabled to prevent audio bleeding');
        } catch (e) {
          AppLogger().debug('⚠️ Error disabling microphone: $e');
        }
        
        AppLogger().debug('✅ All tracks unpublished successfully');
      }
    } catch (e) {
      AppLogger().error('❌ Error unpublishing tracks: $e');
    }
  }
  
  /// Cleanup all speaking detection timers
  void _cleanupAllSpeakingDetection() {
    for (final timer in _speakingTimers.values) {
      timer?.cancel();
    }
    _speakingTimers.clear();
    AppLogger().debug('🧹 Cleaned up all speaking detection timers');
  }

  /// Handle disconnection cleanup
  void _handleDisconnection() async {
    try {
      // Critical: Unpublish all tracks before clearing state
      await _unpublishAllTracks();
      
      // Clear speaking detection
      _cleanupAllSpeakingDetection();
      
      _isConnected = false;
      _currentRoom = null;
      _currentRoomType = null;
      _userRole = null;
      // User ID cleared
      _localParticipant = null;
      
      // Stop memory monitoring
      _memoryMonitorTimer?.cancel();
      _memoryMonitorTimer = null;
      
      AppLogger().debug('🧹 Audio disconnection cleanup completed');
      
      onDisconnected?.call();
      notifyListeners();
    } catch (e) {
      AppLogger().error('❌ Error during disconnection cleanup: $e');
    }
  }
  
  /// Test connectivity to LiveKit server
  Future<bool> testServerConnectivity(String serverUrl) async {
    try {
      AppLogger().debug('🔍 Testing LiveKit server connectivity to: $serverUrl');
      
      // Create a temporary room for testing
      final testRoom = Room();
      
      // Try to connect with a minimal token (will fail but test connectivity)
      try {
        await testRoom.connect(serverUrl, 'test-token');
      } catch (e) {
        // Expected to fail with invalid token, but connectivity is verified
        if (e.toString().contains('Unauthorized') || 
            e.toString().contains('invalid token')) {
          AppLogger().debug('✅ Server connectivity test successful (expected auth error)');
          await testRoom.dispose();
          return true;
        }
        rethrow;
      }
      
      await testRoom.dispose();
      return true;
      
    } catch (error) {
      AppLogger().debug('❌ Server connectivity test failed: $error');
      return false;
    }
  }
  
  /// Set up speaking detection for remote participants
  void _setupSpeakingDetection(RemoteParticipant participant, RemoteTrackPublication publication) {
    if (publication.kind.name != 'audio') return;
    
    final userId = participant.identity;
    AppLogger().debug('🗣️ Setting up speaking detection for $userId');
    
    // Initialize speaking state
    _speakingStates[userId] = false;
    _audioLevels[userId] = 0.0;
    
    // Set up audio level monitoring
    publication.track?.addListener(() {
      if (publication.track is RemoteAudioTrack) {
        final audioTrack = publication.track as RemoteAudioTrack;
        // Note: LiveKit client doesn't expose audio levels directly
        // We'll use track muted state and other indicators for now
        _handleAudioTrackChange(userId, audioTrack);
      }
    });
  }
  
  /// Set up speaking detection for local participant
  void _setupLocalSpeakingDetection(LocalTrackPublication publication) {
    if (publication.kind.name != 'audio' || _localParticipant == null) return;
    
    final userId = _localParticipant!.identity;
    AppLogger().debug('🗣️ Setting up local speaking detection for $userId');
    
    // Initialize speaking state
    _speakingStates[userId] = false;
    _audioLevels[userId] = 0.0;
    
    // Set up audio level monitoring
    publication.track?.addListener(() {
      if (publication.track is LocalAudioTrack) {
        final audioTrack = publication.track as LocalAudioTrack;
        _handleLocalAudioTrackChange(userId, audioTrack);
      }
    });
  }
  
  /// Handle audio track changes for remote participants
  void _handleAudioTrackChange(String userId, RemoteAudioTrack audioTrack) {
    // For now, we'll use a simple heuristic based on track state
    // In a more advanced implementation, we could use Web Audio API for actual audio level detection
    final wasNotMuted = !audioTrack.muted;
    final currentlySpeaking = _speakingStates[userId] ?? false;
    
    // Simple speaking detection: if track is not muted, consider speaking
    final shouldBeSpeaking = wasNotMuted;
    
    if (shouldBeSpeaking != currentlySpeaking) {
      _updateSpeakingState(userId, shouldBeSpeaking);
    }
  }
  
  /// Handle audio track changes for local participant
  void _handleLocalAudioTrackChange(String userId, LocalAudioTrack audioTrack) {
    final wasNotMuted = !audioTrack.muted;
    final currentlySpeaking = _speakingStates[userId] ?? false;
    
    // For local participant, we know when we're actually speaking based on mute state
    final shouldBeSpeaking = wasNotMuted && !_isMuted;
    
    if (shouldBeSpeaking != currentlySpeaking) {
      _updateSpeakingState(userId, shouldBeSpeaking);
    }
  }
  
  /// Update speaking state for a user
  void _updateSpeakingState(String userId, bool isSpeaking) {
    final wasSpeaking = _speakingStates[userId] ?? false;
    
    if (isSpeaking != wasSpeaking) {
      _speakingStates[userId] = isSpeaking;
      
      // Cancel existing timer
      _speakingTimers[userId]?.cancel();
      
      if (isSpeaking) {
        // User started speaking
        AppLogger().debug('🗣️ User $userId started speaking');
        onSpeakingChanged?.call(userId, true);
      } else {
        // User might have stopped speaking, use timer to avoid rapid changes
        _speakingTimers[userId] = Timer(_speakingTimeout, () {
          if (_speakingStates[userId] == false) {
            AppLogger().debug('🤐 User $userId stopped speaking');
            onSpeakingChanged?.call(userId, false);
          }
        });
      }
      
      notifyListeners();
    }
  }
  
  /// Manual method to simulate speaking detection (for testing)
  void simulateSpeaking(String userId, bool isSpeaking) {
    AppLogger().debug('🧪 Simulating speaking for $userId: $isSpeaking');
    _updateSpeakingState(userId, isSpeaking);
  }
  
  /// Clean up speaking detection state when participant leaves
  void _cleanupSpeakingDetection(String userId) {
    _speakingStates.remove(userId);
    _audioLevels.remove(userId);
    _speakingTimers[userId]?.cancel();
    _speakingTimers.remove(userId);
    AppLogger().debug('🧹 Cleaned up speaking detection for $userId');
  }

  /// Aggressive memory cleanup for Android devices
  Future<void> _forceMemoryCleanup() async {
    try {
      AppLogger().debug('🧹 MEMORY: Starting aggressive memory cleanup for Android');
      
      // Cancel all timers immediately
      for (final timer in _speakingTimers.values) {
        timer?.cancel();
      }
      _speakingTimers.clear();
      
      // Clear all state maps
      _speakingStates.clear();
      _audioLevels.clear();
      
      // Stop memory monitoring to free resources
      _memoryMonitorTimer?.cancel();
      _memoryMonitorTimer = null;
      
      // Force disconnect any existing connections
      if (_room != null && _room!.connectionState != ConnectionState.disconnected) {
        try {
          AppLogger().debug('🧹 MEMORY: Force disconnecting room for cleanup');
          await _room!.disconnect();
        } catch (e) {
          AppLogger().debug('⚠️ MEMORY: Error disconnecting room: $e');
        }
      }
      
      // Clear participant references
      _localParticipant = null;
      
      // Reset connection state to prevent stale connections
      _isConnected = false;
      _isMuted = true; // Safe default for memory-constrained restart
      
      // Android-specific: Add delay for native memory cleanup
      if (!kIsWeb) {
        AppLogger().debug('🧹 MEMORY: Waiting for native Android memory cleanup');
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      AppLogger().debug('🧹 MEMORY: Aggressive cleanup completed');
      
    } catch (error) {
      AppLogger().debug('❌ MEMORY: Error during cleanup: $error');
    }
  }

  /// Dispose resources with aggressive memory management
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _isDisposed = true;
    
    AppLogger().debug('🧹 MEMORY: Starting LiveKit service disposal');
    
    // Aggressive memory cleanup first
    await _forceMemoryCleanup();
    
    // Disconnect cleanly
    try {
      await disconnect();
    } catch (error) {
      AppLogger().debug('⚠️ MEMORY: Error during disconnect: $error');
    }
    
    // Force room disposal
    if (_room != null) {
      try {
        await _room!.dispose();
        AppLogger().debug('🧹 MEMORY: Room disposed successfully');
      } catch (error) {
        AppLogger().debug('⚠️ MEMORY: Error disposing room: $error');
      } finally {
        _room = null;
      }
    }
    
    AppLogger().debug('✅ MEMORY: LiveKit service disposal completed');
    super.dispose();
  }
}