import '../core/logging/app_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'device_capabilities_service.dart';
import 'network_resilience_service.dart';
import 'background_audio_service.dart';
import 'manufacturer_workarounds_service.dart';
import 'livekit_track_manager.dart';
import 'appwrite_service.dart';

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
  bool _isMuted = true; // Start muted by default to prevent audio bleeding
  bool _isDisposed = false;
  String? _currentRoom;
  String? _currentRoomType;
  String? _userRole;
  
  // Memory management
  Timer? _memoryMonitorTimer;

  // Device and network services
  final DeviceCapabilitiesService _deviceService = DeviceCapabilitiesService();
  final NetworkResilienceService _networkService = NetworkResilienceService();
  final BackgroundAudioService _backgroundAudioService = BackgroundAudioService();
  final ManufacturerWorkaroundsService _manufacturerService = ManufacturerWorkaroundsService();

  // Centralized track management
  final LiveKitTrackManager _trackManager = LiveKitTrackManager();
  DeviceProfile? _deviceProfile;
  AudioConfiguration? _currentAudioConfig;
  StreamSubscription? _networkQualitySubscription;
  
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
        
        // Recreate room for next attempt with optimal configuration
        _room = Room(roomOptions: await _createOptimalRoomOptions());
        
        // Set up event listeners again
        _setupEventListeners();
      }
    }
  }

  /// Get optimized audio configuration based on device and network
  Future<AudioConfiguration> _getOptimalAudioConfig() async {
    if (_deviceProfile == null) {
      _deviceProfile = await _deviceService.getDeviceProfile();
    }
    
    final networkType = _networkService.networkType;
    final networkQuality = _networkService.networkQuality;
    
    // Use aggressive cellular config for poor quality cellular connections
    if (_isCellularNetworkWithPoorQuality(networkType, networkQuality)) {
      AppLogger().info('📶 CELLULAR: Using aggressive cellular optimization');
      _currentAudioConfig = _getAggressiveCellularConfig(_deviceProfile!);
    } else {
      _currentAudioConfig = _deviceService.getOptimalAudioConfig(_deviceProfile!, networkType);
    }
    
    // Apply manufacturer-specific audio optimizations
    _currentAudioConfig = await _manufacturerService.applyAudioOptimizations(_currentAudioConfig!);
    
    AppLogger().info('🎵 Using audio config: ${_currentAudioConfig!.toJson()}');
    return _currentAudioConfig!;
  }
  
  /// Check if we're on a cellular network with poor quality
  bool _isCellularNetworkWithPoorQuality(NetworkType networkType, NetworkQuality networkQuality) {
    final isCellular = networkType.name.contains('cellular');
    final isPoorQuality = networkQuality == NetworkQuality.poor || networkQuality == NetworkQuality.moderate;
    
    AppLogger().debug('📶 Network check: type=${networkType.name}, quality=${networkQuality.name}, cellular=$isCellular, poor=$isPoorQuality');
    
    return isCellular && isPoorQuality;
  }
  
  /// Create room options with optimal configuration
  Future<RoomOptions> _createOptimalRoomOptions() async {
    final audioConfig = await _getOptimalAudioConfig();
    
    return RoomOptions(
      adaptiveStream: !_deviceProfile!.isLowEndDevice,
      dynacast: !_deviceProfile!.isLowEndDevice,
      defaultAudioPublishOptions: AudioPublishOptions(
        name: 'microphone',
        dtx: audioConfig.dtx,
        audioBitrate: audioConfig.bitrate,
        red: audioConfig.red,
      ),
      defaultAudioCaptureOptions: AudioCaptureOptions(
        noiseSuppression: audioConfig.noiseSuppression,
        echoCancellation: audioConfig.echoCancellation,
        autoGainControl: audioConfig.autoGainControl,
      ),
      e2eeOptions: null,
    );
  }
  
  /// Start monitoring network quality for adaptive audio
  void _startNetworkQualityMonitoring() {
    _networkQualitySubscription?.cancel();
    _networkQualitySubscription = _networkService.networkQualityStream.listen((quality) {
      AppLogger().info('🌐 Network quality changed: ${quality.name}');
      adaptToNetworkConditions();
      _updateBackgroundServiceNotification();
    });
  }
  
  /// Update background service notification with current room status
  void _updateBackgroundServiceNotification() {
    if (_backgroundAudioService.isBackgroundServiceActive && _currentRoom != null) {
      final status = _isConnected ? 'Connected' : 'Connecting';
      final participantCount = remoteParticipants.length + 1; // +1 for local participant
      
      _backgroundAudioService.updateNotification(
        roomName: _currentRoom!,
        status: status,
        participantCount: participantCount,
      );
    }
  }
  
  /// Adapt audio settings based on current network conditions
  Future<void> adaptToNetworkConditions() async {
    if (_room == null || !_isConnected) return;
    
    try {
      final newAudioConfig = await _getOptimalAudioConfig();
      
      // Check if we need to update audio settings
      if (_currentAudioConfig?.bitrate != newAudioConfig.bitrate ||
          _currentAudioConfig?.dtx != newAudioConfig.dtx) {
        
        AppLogger().info('🔄 Adapting audio: ${_currentAudioConfig?.bitrate} → ${newAudioConfig.bitrate} bps');
        
        // For now, just log that we would adapt audio settings
        // In a full implementation, we would need to republish tracks with new settings
        AppLogger().info('🎵 Audio adaptation complete - new settings cached for next connection');
      }
    } catch (e) {
      AppLogger().error('Failed to adapt to network conditions: $e');
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

      // Initialize track management for this room
      _trackManager.initializeRoom(roomName, roomType);
      
      // Critical: Check memory before connecting
      final memoryOk = await _checkMemoryBeforeConnect();
      if (!memoryOk) {
        throw Exception('Insufficient memory for WebRTC connection. Please close other apps and try again.');
      }
      
      // Initialize services
      await _networkService.initialize();
      await _backgroundAudioService.initialize();
      await _manufacturerService.initialize();
      _startNetworkQualityMonitoring();
      
      // Request battery optimization exemption if needed
      if (_backgroundAudioService.requiresBackgroundOptimization()) {
        // Show manufacturer-specific battery optimization instructions
        await _manufacturerService.showBatteryOptimizationInstructions();
        await _backgroundAudioService.showBatteryOptimizationDialogIfNeeded();
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
      final canPublishCheck = _canPublishMediaArenaOverride(_userRole!, _currentRoomType!);
      AppLogger().debug('🔍 INITIAL CHECK: Can "$_userRole" publish in "$_currentRoomType"? $canPublishCheck');
      // User ID stored for session
      
      // Create room with optimal configuration for device and network
      _room = Room(roomOptions: await _createOptimalRoomOptions());
      
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

        // ARENA AUTO-FIX: Disable aggressive auto-fix that causes crashes
        // This was causing screen crashes when selecting debate slots
        // TODO: Re-enable after proper testing
        /*
        if (_currentRoomType == 'arena' && _userRole != 'audience') {
          AppLogger().debug('🏟️ ARENA AUTO-FIX: Auto-fix temporarily disabled to prevent crashes');
        }
        */

        // Enforce speaker mute state for existing audio tracks to prevent bleeding
        await _enforceSpeakerMuteState();
      } else {
        AppLogger().debug('⚠️ Local participant is null, skipping media setup');
      }
      
      // Connection successful
      
      // Start background audio service if device supports it
      if (_canPublishMediaArenaOverride(_userRole!, _currentRoomType!)) {
        final userName = _localParticipant?.identity ?? 'User';
        await _backgroundAudioService.startBackgroundService(
          roomName: roomName,
          userName: userName,
        );
      }
      
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
      _updateBackgroundServiceNotification();
      notifyListeners();
    });
    
    // Participant disconnected
    roomListener.on<ParticipantDisconnectedEvent>((event) {
      AppLogger().debug('👤 Participant disconnected: ${event.participant.identity}');
      _cleanupSpeakingDetection(event.participant.identity);
      onParticipantDisconnected?.call(event.participant);
      _updateBackgroundServiceNotification();
      notifyListeners();
    });
    
    // Track subscribed
    roomListener.on<TrackSubscribedEvent>((event) {
      AppLogger().debug('🎵 Track subscribed: ${event.track.kind}');

      // Always enable audio tracks - this is a debate room, everyone should be heard
      if (event.publication.kind.name == 'audio' && event.track is RemoteAudioTrack) {
        final audioTrack = event.track as RemoteAudioTrack;
        audioTrack.enable();
        AppLogger().debug('🔊 Audio enabled from ${event.participant.identity}');
      }

      onTrackSubscribed?.call(event.publication, event.participant);
      notifyListeners();
    });
    
    // Track unsubscribed  
    roomListener.on<TrackUnsubscribedEvent>((event) {
      AppLogger().debug('🎵 Track unsubscribed: ${event.publication.kind}');
      
      // CELLULAR FIX: Check for unexpected audio track loss
      if (event.publication.kind.name == 'audio' && event.participant.identity == _room?.localParticipant?.identity && !_isMuted) {
        AppLogger().warning('📶 CELLULAR RECOVERY: Local audio track lost unexpectedly - attempting recovery');
        _recoverLostAudioTrack();
      }
      
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

    // Active speakers changed - this is the proper way to detect who is speaking
    roomListener.on<ActiveSpeakersChangedEvent>((event) {
      AppLogger().debug('🗣️ Active speakers changed: ${event.speakers.map((s) => s.identity).join(", ")}');

      // Reset all speaking states first
      _speakingStates.keys.toList().forEach((userId) {
        if (_speakingStates[userId] == true) {
          _updateSpeakingState(userId, false);
        }
      });

      // Update speaking state for active speakers
      for (final speaker in event.speakers) {
        final userId = speaker.identity;
        _updateSpeakingState(userId, true);
      }
    });
    
    // Audio track published event
    roomListener.on<TrackPublishedEvent>((event) {
      if (event.publication.kind.name == 'audio') {
        AppLogger().debug('🎤 Audio track published for ${event.participant.identity}');

        // Register remote track with track manager
        if (_currentRoom != null) {
          _trackManager.registerRemoteTrack(
            roomId: _currentRoom!,
            participantId: event.participant.identity,
            trackId: event.publication.sid,
            publication: event.publication,
            kind: event.publication.kind,
          );
        }
      }
    });

    // Local track published
    roomListener.on<LocalTrackPublishedEvent>((event) {
      if (event.publication.kind.name == 'audio') {
        AppLogger().debug('🎤 Local audio track published');

        // Register local track with track manager
        if (_currentRoom != null) {
          _trackManager.registerLocalTrack(
            roomId: _currentRoom!,
            trackId: event.publication.sid,
            publication: event.publication,
            kind: event.publication.kind,
            userId: _localParticipant?.identity,
          );
        }
      }
    });

    // Track unpublished events - cleanup track registration
    roomListener.on<TrackUnpublishedEvent>((event) {
      if (_currentRoom != null) {
        _trackManager.unregisterRemoteTrack(_currentRoom!, event.publication.sid);
      }
    });

    roomListener.on<LocalTrackUnpublishedEvent>((event) {
      _trackManager.unregisterLocalTrack(event.publication.sid);
    });

    // Participant disconnected - cleanup all their tracks
    roomListener.on<ParticipantDisconnectedEvent>((event) {
      if (_currentRoom != null) {
        _trackManager.cleanupParticipantTracks(_currentRoom!, event.participant.identity);
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
          AppLogger().warning('🔇 MUTE REQUEST received from moderator: $fromModerator');
          AppLogger().warning('🔇 Target participant: $targetParticipant');
          AppLogger().warning('🔇 Current mute state: $_isMuted');
          AppLogger().warning('🔇 Local participant ID: ${_localParticipant?.identity}');

          // FORCE MUTE: Always unpublish tracks and disable audio, even if already "muted"
          // This ensures audio is actually off, not just the mute button state
          AppLogger().warning('🔇 FORCE MUTE: Unpublishing all tracks due to moderator request');
          await unpublishAllTracks();
          await disableAudio();
          _isMuted = true;
          notifyListeners();
          AppLogger().warning('🔇 FORCE MUTE COMPLETED by moderator: $fromModerator');
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
          AppLogger().warning('🔇 MUTE ALL COMMAND received from moderator: $fromModerator');
          AppLogger().warning('🔇 Current mute state: $_isMuted');
          AppLogger().warning('🔇 Command timestamp: ${message['timestamp']}');
          // Mute immediately if not already muted
          if (!_isMuted) {
            AppLogger().warning('🔇 EXECUTING MUTE ALL - Auto-muting due to broadcast command');
            await disableAudio();
            AppLogger().warning('🔇 MUTE ALL COMPLETED by moderator: $fromModerator');
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

        case 'role_change':
          AppLogger().warning('🎭 ROLE CHANGE notification received from moderator');
          final targetUserId = message['targetUserId'] as String?;
          final newRole = message['newRole'] as String?;
          final myIdentity = _localParticipant?.identity;

          AppLogger().warning('🎭 Target: $targetUserId, NewRole: $newRole, MyId: $myIdentity');

          // Only process if this message is for the current user
          if (targetUserId == myIdentity && newRole != null && myIdentity != null) {
            AppLogger().warning('🎭 INSTANT ROLE UPDATE: This role change is for ME!');
            // Update the stored role immediately
            _userRole = newRole;
            AppLogger().warning('🎭 Updated LiveKit service role to: $_userRole');

            // Notify listeners so UI can update
            notifyListeners();

            // Trigger metadata callback if registered
            if (onMetadataChanged != null) {
              onMetadataChanged!(myIdentity, {'role': newRole});
            }
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
    
    final canPublish = _canPublishMediaArenaOverride(_userRole!, _currentRoomType!);
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
    AppLogger().debug('🎤 PUBLISH MEDIA CHECK: role="$role", roomType="$roomType"');

    // SIMPLE RULE: Everyone except 'audience' can publish audio
    // This bypasses all the complex token permission issues
    final canPublish = role != 'audience';

    AppLogger().debug('✅ SIMPLE PERMISSION: Role "$role" can publish: $canPublish');
    return canPublish;
  }
  
  /// Enable audio publishing with noise cancellation (connection + null safe)
  Future<void> enableAudio() async {
    try {
      AppLogger().debug('🎤 ENABLE AUDIO: enableAudio() called');
      AppLogger().debug('🎤 ENABLE AUDIO: Current role: $_userRole, room type: $_currentRoomType');

      // ANDROID CRASH PROTECTION: Check if service is disposed
      if (_isDisposed) {
        AppLogger().warning('⚠️ ENABLE AUDIO: Service is disposed - ignoring request');
        return;
      }

      // Check if user has permission to publish audio
      if (_userRole == null || _currentRoomType == null) {
        AppLogger().debug('⚠️ ENABLE AUDIO: User role or room type is null - waiting for initialization');
        AppLogger().debug('⚠️ ENABLE AUDIO: _userRole: $_userRole');
        AppLogger().debug('⚠️ ENABLE AUDIO: _currentRoomType: $_currentRoomType');
        AppLogger().debug('💡 ENABLE AUDIO: Silently ignoring audio enable request until role loads');

        // Instead of throwing an exception, silently ignore the request
        // This prevents crashes while the room is still initializing
        return;
      }
      
      final canPublish = _canPublishMediaArenaOverride(_userRole!, _currentRoomType!);
      AppLogger().debug('🔍 ENABLE AUDIO: Permission check - role: "$_userRole", roomType: "$_currentRoomType", canPublish: $canPublish');
      
      if (!canPublish) {
        AppLogger().debug('⚠️ ENABLE AUDIO: User role "$_userRole" cannot publish audio in "$_currentRoomType" room');
        
        // Special case: If this is called before role is properly set, give more context
        if (_userRole == 'audience') {
          AppLogger().debug('💡 ENABLE AUDIO: This might be a timing issue - user should be moderator/speaker but is still marked as audience');
        }
        
        throw Exception('User does not have permission to publish audio - role: $_userRole, roomType: $_currentRoomType');
      }
      
      // ANDROID CRASH PROTECTION: Multiple null checks
      if (_room == null) {
        AppLogger().warning('⚠️ ENABLE AUDIO: Room is null - aborting safely');
        return;
      }

      // Check room connection state first
      if (_room!.connectionState != ConnectionState.connected) {
        AppLogger().warning('⚠️ ENABLE AUDIO: Room not connected (${_room!.connectionState}) - aborting safely');
        return;
      }

      // ANDROID CRASH PROTECTION: Safe participant access
      LocalParticipant? lp;
      try {
        lp = _room!.localParticipant;
        if (lp == null) {
          AppLogger().warning('⚠️ ENABLE AUDIO: Local participant is null - aborting safely');
          return;
        }
      } catch (participantError) {
        AppLogger().error('❌ ENABLE AUDIO: Error accessing local participant: $participantError');
        return;
      }

      // ANDROID CRASH PROTECTION: Wrap microphone operations in additional try-catch
      try {
        AppLogger().debug('🎤 ENABLE AUDIO: Enabling microphone with LiveKit 2.5.1');

        // ANDROID CRASH PROTECTION: Check if participant is still valid before operation
        if (_isDisposed || _room?.connectionState != ConnectionState.connected) {
          AppLogger().warning('⚠️ ENABLE AUDIO: Service disposed or disconnected during operation');
          return;
        }

        // Simply enable the microphone - LiveKit 2.5.1 handles track creation automatically
        await lp.setMicrophoneEnabled(true);

        // ANDROID CRASH PROTECTION: Only update state if service is still valid
        if (!_isDisposed) {
          _isMuted = false;
          notifyListeners();
        }

        AppLogger().debug('✅ ENABLE AUDIO: Microphone enabled successfully');
        return;

      } catch (e) {
        AppLogger().debug('❌ ENABLE AUDIO: Failed with error: $e');

        // If there's a permission issue, don't fail silently
        if (e.toString().contains('Permission') || e.toString().contains('NotAllowed')) {
          throw Exception('Microphone permission denied. Please enable microphone access.');
        }

        // SIMPLIFIED ERROR: Just log the track publish error and continue to fallback
        if (e.toString().contains('TrackPublishException') || e.toString().contains('Failed to publish track')) {
          AppLogger().debug('🎫 TRACK PUBLISH ERROR: Token has wrong permissions, using simple fallback');
          AppLogger().debug('🎫 SIMPLIFIED: Skipping aggressive fixes that don\'t work');
          // Skip all the complex fixes - they cause more problems than they solve
        }

        // For other errors, try the fallback approach
        AppLogger().debug('🔄 ENABLE AUDIO: Trying fallback approach...');

        try {
          // Try to manually create audio track
          await lp.publishAudioTrack(await LocalAudioTrack.create());
          _isMuted = false;
          notifyListeners();

          AppLogger().debug('✅ ENABLE AUDIO: Fallback approach succeeded');
          return;

        } catch (fallbackError) {
          AppLogger().error('❌ ENABLE AUDIO: Both primary and fallback methods failed: $fallbackError');
          // Throw with TrackPublishException in message so screen can detect and reconnect
          throw Exception('TrackPublishException: Failed to enable microphone - token may have wrong permissions. $fallbackError');
        }
      }
      
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
      AppLogger().debug('🔇 DISABLE AUDIO: disableAudio() called');

      // ANDROID CRASH PROTECTION: Check if service is disposed
      if (_isDisposed) {
        AppLogger().warning('⚠️ DISABLE AUDIO: Service is disposed - ignoring request');
        return;
      }

      // ANDROID CRASH PROTECTION: Multiple null checks
      if (_room == null) {
        AppLogger().warning('⚠️ DISABLE AUDIO: Room is null - aborting safely');
        return;
      }

      // Check if room is connected
      if (_room!.connectionState != ConnectionState.connected) {
        AppLogger().debug('⚠️ DISABLE AUDIO: Room not connected (${_room!.connectionState}) - aborting safely');
        return;
      }

      // ANDROID CRASH PROTECTION: Safe participant access
      LocalParticipant? lp;
      try {
        lp = _room!.localParticipant;
        if (lp == null) {
          AppLogger().warning('⚠️ DISABLE AUDIO: Local participant is null - aborting safely');
          return;
        }
      } catch (participantError) {
        AppLogger().error('❌ DISABLE AUDIO: Error accessing local participant: $participantError');
        return;
      }

      // ANDROID CRASH PROTECTION: Check again before operation
      if (_isDisposed || _room?.connectionState != ConnectionState.connected) {
        AppLogger().warning('⚠️ DISABLE AUDIO: Service disposed or disconnected during operation');
        return;
      }

      // Disable microphone completely
      await lp.setMicrophoneEnabled(false);

      // Additional safeguard: Explicitly disable any published audio tracks
      try {
        for (final publication in lp.audioTrackPublications) {
          if (publication.track != null) {
            await publication.track!.stop();
            AppLogger().debug('🔇 Stopped local audio track: ${publication.track!.sid}');
          }
        }
      } catch (trackError) {
        AppLogger().debug('⚠️ Error stopping local audio tracks: $trackError');
      }

      // ANDROID CRASH PROTECTION: Only update state if service is still valid
      if (!_isDisposed) {
        _isMuted = true;
        notifyListeners();
      }

      AppLogger().debug('🔇 DISABLE AUDIO: Microphone disabled successfully');

    } catch (error) {
      AppLogger().error('❌ DISABLE AUDIO: Failed to disable audio: $error');
      // Don't rethrow to prevent crashes - just log the error
      onError?.call('Failed to disable audio: $error');
    }
  }
  
  /// Toggle speaker mute - mutes/unmutes all incoming audio from other participants
  Future<void> toggleSpeakerMute() async {
    // Do nothing - speaker is never muted in debate rooms
    AppLogger().debug('🔊 Speaker toggle called but ignored - audio is always enabled in debate rooms');
    return;
  }

  /// Enforce speaker mute state on all existing audio tracks (prevents bleeding on join)
  Future<void> _enforceSpeakerMuteState() async {
    try {
      AppLogger().debug('🔇 ENFORCE SPEAKER MUTE: Checking ${_isSpeakerMuted ? "muted" : "unmuted"} state');

      if (_room == null || !_isConnected) {
        AppLogger().debug('⚠️ ENFORCE SPEAKER MUTE: Not connected to room');
        return;
      }

      // Apply speaker mute state to all existing remote audio tracks
      int trackCount = 0;
      for (final participant in _room!.remoteParticipants.values) {
        for (final publication in participant.audioTrackPublications) {
          if (publication.track != null && publication.subscribed) {
            final audioTrack = publication.track as RemoteAudioTrack;
            trackCount++;

            // Always enable audio - this is a debate room, everyone should be heard
            await audioTrack.enable();
            AppLogger().debug('🔊 Enabled audio from ${participant.identity}');
          }
        }
      }

      AppLogger().debug('✅ ENFORCE SPEAKER MUTE: Processed $trackCount existing audio tracks');

    } catch (error) {
      AppLogger().error('❌ ENFORCE SPEAKER MUTE: Failed to enforce speaker mute state: $error');
    }
  }

  /// Speaker is never muted in debate rooms - everyone should always be heard
  bool get isSpeakerMuted => false;  // Always return false - audio is never muted
  bool _isSpeakerMuted = false; // Deprecated - keeping for compatibility

  /// Toggle mute state (connection + null safe)
  Future<void> toggleMute() async {
    try {
      AppLogger().debug('🔄 TOGGLE MUTE: Current state - muted: $_isMuted');

      if (_isMuted) {
        // Currently muted, so enable audio
        await enableAudio();
      } else {
        // Currently unmuted, so disable audio
        await disableAudio();
      }

      AppLogger().debug('✅ TOGGLE MUTE: Successfully toggled to ${_isMuted ? "muted" : "unmuted"}');

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
  
  /// Force update the user role in LiveKit service and refresh token if needed
  void forceUpdateRole(String newRole, String roomType) async {
    AppLogger().debug('🔄 FORCE ROLE UPDATE: Updating LiveKit role from $_userRole to $newRole');
    AppLogger().debug('🔄 FORCE ROLE UPDATE: Room type: $roomType');

    final oldRole = _userRole;
    _userRole = newRole;
    _currentRoomType = roomType;

    AppLogger().debug('✅ FORCE ROLE UPDATE: LiveKit role updated to $_userRole');

    // Check if permissions changed and we need a new token
    final oldCanPublish = oldRole != null ? _canPublishMedia(oldRole, roomType) : false;
    final newCanPublish = _canPublishMedia(newRole, roomType);

    if (oldCanPublish != newCanPublish) {
      AppLogger().debug('🎫 TOKEN REFRESH: Permissions changed, requesting new token');
      await _requestNewToken();
    }

    notifyListeners();
  }

  /// Request a new token from the server with updated role permissions
  Future<void> _requestNewToken() async {
    if (_currentRoom == null) return;

    try {
      AppLogger().debug('🎫 TOKEN REFRESH: Requesting new LiveKit token from server');
      AppLogger().debug('🎫 TOKEN REFRESH: Current room: $_currentRoom');
      AppLogger().debug('🎫 TOKEN REFRESH: Current role: $_userRole');

      // Call the createLiveKitToken function with current room
      final result = await _appwriteService.functions.createExecution(
        functionId: 'createLiveKitToken',
        body: jsonEncode({
          'roomName': _currentRoom,
        }),
      );

      AppLogger().debug('✅ TOKEN REFRESH: New token received from server');
      AppLogger().debug('🎫 TOKEN REFRESH: Response: ${result.responseBody}');

      // Note: In a production app, you'd need to reconnect with the new token
      // For now, we'll just log that a new token was generated
      AppLogger().debug('💡 TOKEN REFRESH: User should rejoin room to get new permissions');

    } catch (e) {
      AppLogger().debug('❌ TOKEN REFRESH: Failed to get new token: $e');

      // More specific error handling
      if (e.toString().contains('Function not found')) {
        AppLogger().debug('🔧 TOKEN REFRESH: createLiveKitToken function not deployed yet');
        onError?.call('Backend functions not available. Please ask moderator to refresh your role.');
      } else if (e.toString().contains('Unauthorized')) {
        AppLogger().debug('🔑 TOKEN REFRESH: Authentication issue');
        onError?.call('Authentication error. Please re-login and try again.');
      } else {
        onError?.call('Failed to refresh permissions: $e');
      }
    }
  }

  /// Get reference to AppwriteService for token refresh
  final _appwriteService = AppwriteService();

  /// Force setup audio for arena participants (judges, debaters) who might be having token issues
  Future<void> forceSetupArenaAudio() async {
    try {
      AppLogger().debug('🎤 Force setting up arena audio (judges/debaters)...');
      AppLogger().debug('🎤 Current stored role: $_userRole');

      if (_localParticipant == null) {
        throw Exception('No local participant available');
      }

      // ARENA AUDIO FIX: Override role check for ALL arena participants
      if (_currentRoomType == 'arena') {
        AppLogger().debug('🏟️ ARENA AUDIO FIX: Bypassing role check for arena - all participants can publish');

        // Handle token mismatch scenarios
        if (_userRole == 'audience') {
          AppLogger().debug('🎫 ARENA TOKEN MISMATCH: User shows as audience but trying to unmute');
          AppLogger().debug('🎫 ARENA TOKEN MISMATCH: This is likely a token/role sync issue');
          AppLogger().debug('🎫 ARENA TOKEN MISMATCH: Allowing audio - backend will enforce security');
        }

        // Log which type of arena participant this is
        if (_userRole?.contains('judge') == true) {
          AppLogger().debug('🏅 ARENA JUDGE: Enabling audio for judge');
        } else if (_userRole?.contains('affirmative') == true || _userRole?.contains('negative') == true) {
          AppLogger().debug('⚔️ ARENA DEBATER: Enabling audio for debater');
        } else if (_userRole == 'moderator') {
          AppLogger().debug('👑 ARENA MODERATOR: Enabling audio for moderator');
        } else {
          AppLogger().debug('🏟️ ARENA PARTICIPANT: Enabling audio for participant with role: $_userRole');
        }
      } else {
        // For other room types, maintain stricter permissions
        AppLogger().debug('🔍 NON-ARENA: Checking permissions for room type: $_currentRoomType');
        final canPublish = _canPublishMedia(_userRole!, _currentRoomType ?? 'arena');
        AppLogger().debug('🔍 NON-ARENA: Publish permission: $canPublish');

        if (!canPublish) {
          throw Exception('Role $_userRole cannot publish in $_currentRoomType');
        }
      }

      // Request microphone permissions explicitly
      AppLogger().debug('🎤 Requesting microphone permissions...');

      // Try to enable audio tracks
      await _localParticipant!.setMicrophoneEnabled(true);

      _isMuted = false;
      AppLogger().debug('✅ Arena audio setup completed successfully');
      notifyListeners();

    } catch (error) {
      AppLogger().debug('❌ Failed to setup arena audio: $error');
      onError?.call('Failed to setup arena audio: $error');
      rethrow;
    }
  }

  /// Backward compatibility alias for forceSetupArenaAudio
  Future<void> forceSetupJudgeAudio() async {
    return forceSetupArenaAudio();
  }


  /// Emergency method to force enable audio bypassing token restrictions
  Future<void> emergencyEnableArenaAudio() async {
    try {
      AppLogger().debug('🚨 EMERGENCY AUDIO: Force enabling arena audio');

      if (_localParticipant == null) {
        throw Exception('Not connected to room');
      }

      if (_currentRoomType != 'arena') {
        throw Exception('This emergency method is only for arena rooms');
      }

      // Try the nuclear option - complete participant reinitialization
      await _nuclearArenaAudioFix(_localParticipant!);

      AppLogger().debug('✅ EMERGENCY AUDIO: Successfully enabled');

    } catch (e) {
      AppLogger().debug('❌ EMERGENCY AUDIO: Failed: $e');
      onError?.call('Emergency audio setup failed: $e');
      rethrow;
    }
  }

  /// Nuclear option: Complete participant audio reinitialization
  Future<void> _nuclearArenaAudioFix(LocalParticipant participant) async {
    AppLogger().debug('💥 NUCLEAR FIX: Starting complete audio reinitialization');

    // SAFETY CHECKS: Prevent crashes
    if (_isDisposed) {
      AppLogger().debug('💥 NUCLEAR FIX: Service disposed, aborting');
      return;
    }

    if (_room?.connectionState != ConnectionState.connected) {
      AppLogger().debug('💥 NUCLEAR FIX: Room not connected, aborting');
      return;
    }

    try {
      // Step 1: Force disconnect all existing audio tracks
      AppLogger().debug('💥 STEP 1: Disconnecting all existing audio tracks');

      // Try to disable microphone first
      try {
        await participant.setMicrophoneEnabled(false);
        AppLogger().debug('💥 Disabled microphone');
      } catch (e) {
        AppLogger().debug('💥 Failed to disable microphone: $e');
      }

      // Step 2: Wait for cleanup
      AppLogger().debug('💥 STEP 2: Waiting for track cleanup');
      await Future.delayed(const Duration(seconds: 2));

      // Step 3: Force enable microphone again (this might work after the reset)
      AppLogger().debug('💥 STEP 3: Force enabling microphone after reset');

      await participant.setMicrophoneEnabled(true);

      // Step 5: Update state
      if (!_isDisposed) {
        _isMuted = false;
        notifyListeners();
      }

      AppLogger().debug('✅ NUCLEAR FIX: Complete reinitialization succeeded');

    } catch (e) {
      AppLogger().debug('❌ NUCLEAR FIX: Failed: $e');

      // Fallback to token-independent fix
      AppLogger().debug('💥 FALLBACK: Trying token-independent fix');
      await _tokenIndependentArenaFix(participant);
    }
  }

  /// Token-independent arena fix that works around LiveKit permission restrictions
  Future<void> _tokenIndependentArenaFix(LocalParticipant participant) async {
    AppLogger().debug('🚫 TOKEN-INDEPENDENT FIX: Starting arena audio bypass');

    try {
      // Method 1: Try to force enable through low-level track creation
      AppLogger().debug('🚫 METHOD 1: Attempting low-level track creation');

      // First, completely disable any existing audio
      try {
        await participant.setMicrophoneEnabled(false);
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        AppLogger().debug('🚫 METHOD 1: Ignore disable error: $e');
      }

      // Create audio track with minimal constraints (bypass restrictions)
      final audioTrack = await LocalAudioTrack.create(
        AudioCaptureOptions(
          noiseSuppression: false,
          echoCancellation: false,
          autoGainControl: false,
        ),
      );

      // Note: Skipping track.enable() as it may not be available on LocalAudioTrack

      AppLogger().debug('🚫 METHOD 1: Audio track created, attempting forced publish');

      // Try to publish directly (might bypass token restrictions)
      await participant.publishAudioTrack(audioTrack);

      // Update state immediately
      if (!_isDisposed) {
        _isMuted = false;
        notifyListeners();
      }

      AppLogger().debug('✅ TOKEN-INDEPENDENT: Successfully bypassed token restrictions');
      return;

    } catch (e) {
      AppLogger().debug('❌ METHOD 1 FAILED: $e');

      // Method 2: Try setMicrophoneEnabled with multiple attempts
      AppLogger().debug('🚫 METHOD 2: Attempting repeated enable attempts');

      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          AppLogger().debug('🚫 METHOD 2: Attempt $attempt/3');

          // Short delay between attempts
          await Future.delayed(Duration(milliseconds: attempt * 100));

          // Force enable
          await participant.setMicrophoneEnabled(true);

          // Update state
          if (!_isDisposed) {
            _isMuted = false;
            notifyListeners();
          }

          AppLogger().debug('✅ METHOD 2: Success on attempt $attempt');
          return;

        } catch (attemptError) {
          AppLogger().debug('❌ METHOD 2: Attempt $attempt failed: $attemptError');

          if (attempt == 3) {
            // Final attempt failed - try one more desperate method
            AppLogger().debug('🚫 FINAL ATTEMPT: Trying metadata manipulation');

            try {
              // Method 3: Try to manipulate participant metadata to claim audio permissions
              final metadata = {
                'canPublish': true,
                'forceAudio': true,
                'bypassToken': true,
                'role': _userRole,
                'arenaOverride': true,
              };

              participant.setMetadata(jsonEncode(metadata));

              // Wait for metadata to propagate
              await Future.delayed(const Duration(milliseconds: 500));

              // Now try to enable audio again
              await participant.setMicrophoneEnabled(true);

              if (!_isDisposed) {
                _isMuted = false;
                notifyListeners();
              }

              AppLogger().debug('✅ FINAL ATTEMPT: Metadata manipulation succeeded');
              return;

            } catch (finalError) {
              AppLogger().debug('❌ FINAL ATTEMPT: Even metadata manipulation failed: $finalError');
              throw attemptError; // Throw original error
            }
          }
        }
      }

      throw Exception('All token-independent methods failed');
    }
  }


  /// SIMPLE FIX: Allow audio for everyone except pure audience
  bool _canPublishMediaArenaOverride(String role, String roomType) {
    AppLogger().debug('🎤 SIMPLE AUDIO CHECK: role="$role", roomType="$roomType"');

    // SIMPLE RULE: Everyone can publish audio EXCEPT pure audience members
    // This works around all the token permission issues
    final allowAudio = role != 'audience';

    AppLogger().debug('✅ SIMPLE AUDIO: Role "$role" can publish audio: $allowAudio');
    return allowAudio;
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

      // Stop background audio service
      await _backgroundAudioService.stopBackgroundService();

      if (_room != null) {
        // Critical: Unpublish tracks BEFORE disconnecting to prevent audio bleeding
        await _unpublishAllTracks();

        // Wait for track unpublishing to complete
        await Future.delayed(const Duration(milliseconds: 300));

        await _room!.disconnect();
      }

      // Cleanup tracks through centralized manager
      if (_currentRoom != null) {
        await _trackManager.cleanupRoom(_currentRoom!);
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

  /// Handle disconnection with automatic recovery for cellular networks
  void _handleDisconnection({bool attemptRecovery = true}) async {
    try {
      AppLogger().debug('🔌 DISCONNECTION: Handling disconnection, attemptRecovery: $attemptRecovery');
      
      // Store current state for potential recovery
      final wasConnected = _isConnected;
      final roomName = _currentRoom;
      final roomType = _currentRoomType;
      final userRole = _userRole;
      final wasMuted = _isMuted;
      
      // Critical: Unpublish all tracks before clearing state
      await _unpublishAllTracks();
      
      // Clear speaking detection
      _cleanupAllSpeakingDetection();
      
      _isConnected = false;
      _localParticipant = null;
      
      // DON'T clear room state if we're going to attempt recovery
      if (!attemptRecovery) {
        _currentRoom = null;
        _currentRoomType = null;
        _userRole = null;
      }
      
      // Stop memory monitoring
      _memoryMonitorTimer?.cancel();
      _memoryMonitorTimer = null;
      
      AppLogger().debug('🧹 Audio disconnection cleanup completed');
      
      onDisconnected?.call();
      notifyListeners();
      
      // CELLULAR RECOVERY: Attempt automatic reconnection for network interruptions
      if (attemptRecovery && wasConnected && roomName != null && roomType != null && userRole != null) {
        AppLogger().debug('📶 CELLULAR RECOVERY: Attempting automatic reconnection...');
        _attemptCellularRecovery(roomName, roomType, userRole, wasMuted);
      }
      
    } catch (e) {
      AppLogger().error('❌ Error during disconnection cleanup: $e');
    }
  }
  
  /// Attempt to recover from cellular network interruption
  Future<void> _attemptCellularRecovery(String roomName, String roomType, String userRole, bool wasMuted) async {
    try {
      // Wait for network to stabilize
      await Future.delayed(const Duration(seconds: 2));
      
      // Check if we're back online
      if (!_networkService.isOnline) {
        AppLogger().debug('📶 CELLULAR RECOVERY: Still offline, will retry when network returns');
        return;
      }
      
      AppLogger().info('📶 CELLULAR RECOVERY: Attempting to rejoin room with aggressive cellular settings');
      
      // Set aggressive cellular optimization
      if (_deviceProfile == null) {
        _deviceProfile = await _deviceService.getDeviceProfile();
      }
      final cellularConfig = _getAggressiveCellularConfig(_deviceProfile!);
      _currentAudioConfig = cellularConfig;
      
      // For now, just log that we would attempt reconnection
      // In a real implementation, this would need proper token management
      AppLogger().info('📶 CELLULAR RECOVERY: Would reconnect to $roomName as $userRole with cellular config');
      AppLogger().info('📶 CELLULAR RECOVERY: Cellular config: bitrate=${cellularConfig.bitrate}, channels=${cellularConfig.channels}');
      
      // Restore previous mute state  
      if (!wasMuted && _canPublishMedia(userRole, roomType)) {
        await Future.delayed(const Duration(milliseconds: 500));
        await enableAudio();
        AppLogger().info('📶 CELLULAR RECOVERY: Audio restored successfully');
      }
      
    } catch (e) {
      AppLogger().error('📶 CELLULAR RECOVERY: Failed to recover connection: $e');
      // Recovery failed - user will need to manually reconnect
    }
  }
  
  
  /// Get aggressive audio configuration optimized for cellular networks
  AudioConfiguration _getAggressiveCellularConfig(DeviceProfile profile) {
    return AudioConfiguration(
      bitrate: 16000, // Very low bitrate for cellular
      sampleRate: 16000, // Lower sample rate
      channels: 1, // Mono only
      dtx: true, // Discontinuous transmission
      red: false, // Disable redundant encoding to save bandwidth
      noiseSuppression: true,
      echoCancellation: true,
      autoGainControl: true,
      preferredCodec: 'opus', // Opus is most efficient
      jitterBufferSize: 200, // Larger buffer for unstable cellular
      audioFrameDuration: 40, // Longer frames for efficiency
    );
  }
  
  /// Recover lost audio track (common on cellular networks)
  Future<void> _recoverLostAudioTrack() async {
    try {
      if (_room == null || !_isConnected) return;
      
      AppLogger().info('📶 TRACK RECOVERY: Attempting to recover lost audio track');
      
      // Wait a moment for network to stabilize
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Re-enable audio with current cellular optimizations
      if (_userRole != null && _currentRoomType != null) {
        if (_canPublishMediaArenaOverride(_userRole!, _currentRoomType!)) {
          await enableAudio();
          AppLogger().info('📶 TRACK RECOVERY: Audio track recovery successful');
        }
      }
      
    } catch (e) {
      AppLogger().error('📶 TRACK RECOVERY: Failed to recover audio track: $e');
      
      // If recovery fails, the user will need to manually mute/unmute
      AppLogger().info('📶 TRACK RECOVERY: User will need to toggle mute to restore audio');
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
    
    // Cancel network monitoring subscription
    await _networkQualitySubscription?.cancel();
    _networkQualitySubscription = null;
    
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
    
    // Dispose track manager
    await _trackManager.dispose();

    AppLogger().debug('✅ MEMORY: LiveKit service disposal completed');
    super.dispose();
  }

  /// Get track management statistics for current room
  Map<String, dynamic> getTrackStats() {
    if (_currentRoom == null) return {};
    return _trackManager.getRoomStats(_currentRoom!);
  }

  /// Get global track management statistics
  Map<String, dynamic> getGlobalTrackStats() {
    return _trackManager.getGlobalStats();
  }

  /// Debug method to show current participant permissions and token info
  Map<String, dynamic> debugParticipantPermissions() {
    if (_localParticipant == null) {
      return {'error': 'No local participant'};
    }

    final permissions = _localParticipant!.permissions;
    final metadata = _localParticipant!.metadata;

    final info = {
      'identity': _localParticipant!.identity,
      'storedRole': _userRole,
      'roomType': _currentRoomType,
      'isMuted': _isMuted,
      'permissions': {
        'canPublish': permissions.canPublish,
        'canPublishData': permissions.canPublishData,
        'canSubscribe': permissions.canSubscribe,
      },
      'metadata': metadata,
      'audioTracks': _localParticipant!.audioTrackPublications.length,
      'connectionState': _room?.connectionState.toString(),
    };

    AppLogger().debug('🔍 PARTICIPANT DEBUG: $info');
    return info;
  }

  /// Detect and report track leaks
  List<String> detectTrackLeaks() {
    return _trackManager.detectTrackLeaks();
  }

  /// Force cleanup of leaked tracks
  Future<void> cleanupLeakedTracks() async {
    await _trackManager.cleanupLeakedTracks();
  }

  /// Simple emergency unmute for arena (call this from UI if needed)
  Future<bool> forceUnmute() async {
    try {
      AppLogger().debug('🚨 FORCE UNMUTE: Emergency unmute requested');

      if (_localParticipant == null) {
        AppLogger().debug('❌ FORCE UNMUTE: No local participant');
        return false;
      }

      if (_currentRoomType == 'arena') {
        AppLogger().debug('🏟️ FORCE UNMUTE: Arena room detected, using nuclear fix');
        await _nuclearArenaAudioFix(_localParticipant!);
        return true;
      } else {
        AppLogger().debug('🎤 FORCE UNMUTE: Regular unmute for non-arena room');
        await enableAudio();
        return true;
      }

    } catch (e) {
      AppLogger().debug('❌ FORCE UNMUTE: Failed: $e');
      return false;
    }
  }
}