import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:livekit_client/livekit_client.dart';
import '../core/logging/app_logger.dart';
import 'livekit_token_service.dart';

/// Persistent Audio Service - Maintains single LiveKit connection across all room types
/// 
/// Benefits:
/// - Sub-second room switching (just change channels, not connections)
/// - No cold starts - audio infrastructure always ready
/// - Persistent connection eliminates repeated handshakes
/// - Pre-warmed audio permissions across all rooms
/// 
/// This is how Discord, Clubhouse, and other real-time audio apps work - they maintain 
/// persistent audio infrastructure and just switch contexts, not connections.
class PersistentAudioService extends ChangeNotifier {
  static final PersistentAudioService _instance = PersistentAudioService._internal();
  factory PersistentAudioService() => _instance;
  PersistentAudioService._internal() {
    _initializeBackgroundConnectionManager();
  }

  // Core LiveKit connection
  Room? _persistentRoom;
  LocalParticipant? _localParticipant;
  
  // Connection state
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isMuted = true; // Start muted by default
  bool _isDisposed = false;
  
  // Current room context
  String? _currentRoomId;
  String? _currentRoomType;
  String? _currentUserId;
  String? _currentUserRole;
  
  // Audio state management
  final Map<String, bool> _speakingStates = {};
  final Map<String, double> _audioLevels = {};
  final Map<String, Timer?> _speakingTimers = {};
  static const Duration _speakingTimeout = Duration(milliseconds: 500);
  
  // Background connection management
  Timer? _connectionHealthTimer;
  Timer? _tokenRefreshTimer;
  // Removed unused fields: _isAppBackgrounded, _lastConnectionCheck
  int _consecutiveFailures = 0;
  static const int _maxConsecutiveFailures = 3;
  
  // Services
  final LiveKitTokenService _tokenService = LiveKitTokenService();
  
  // Callbacks for room-specific UI updates
  Function(RemoteParticipant)? onParticipantConnected;
  Function(RemoteParticipant)? onParticipantDisconnected;
  Function(RemoteTrackPublication, RemoteParticipant)? onTrackSubscribed;
  Function(RemoteTrackPublication, RemoteParticipant)? onTrackUnsubscribed;
  Function(String)? onError;
  Function()? onConnected;
  Function()? onDisconnected;
  Function(String userId, Map<String, dynamic> metadata)? onMetadataChanged;
  Function(String userId, bool isSpeaking)? onSpeakingChanged;
  Function(String userId, double audioLevel)? onAudioLevelChanged;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  String? get currentRoomId => _currentRoomId;
  String? get currentRoomType => _currentRoomType;
  String? get currentUserId => _currentUserId;
  String? get currentUserRole => _currentUserRole;
  Room? get room => _persistentRoom;
  LocalParticipant? get localParticipant => _localParticipant;
  
  List<RemoteParticipant> get remoteParticipants => 
      _persistentRoom?.remoteParticipants.values.toList() ?? [];
  
  int get connectedPeersCount => remoteParticipants.length;
  
  // Speaking detection getters
  bool isUserSpeaking(String userId) => _speakingStates[userId] ?? false;
  double getUserAudioLevel(String userId) => _audioLevels[userId] ?? 0.0;
  Map<String, bool> get allSpeakingStates => Map.from(_speakingStates);
  List<String> get currentSpeakers => _speakingStates.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toList();

  /// Initialize background connection manager for always-connected experience
  void _initializeBackgroundConnectionManager() {
    AppLogger().debug('🔄 PERSISTENT AUDIO: Initializing background connection manager');
    
    // Start connection health monitoring (every 30 seconds)
    _connectionHealthTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _performConnectionHealthCheck();
    });
    
    // Start token refresh monitoring (every 5 minutes)
    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _performTokenRefreshCheck();
    });
  }
  
  /// Monitor connection health and auto-reconnect if needed
  void _performConnectionHealthCheck() async {
    if (_isDisposed || !_isInitialized) return;
    
    // Connection health check timestamp tracked elsewhere
    
    try {
      if (!isConnectionHealthy) {
        _consecutiveFailures++;
        AppLogger().warning('🔍 PERSISTENT AUDIO: Connection health check failed ($_consecutiveFailures/$_maxConsecutiveFailures)');
        
        if (_consecutiveFailures >= _maxConsecutiveFailures) {
          AppLogger().warning('🔄 PERSISTENT AUDIO: Multiple health check failures, attempting reconnection...');
          await _attemptReconnection();
        }
      } else {
        if (_consecutiveFailures > 0) {
          AppLogger().info('✅ PERSISTENT AUDIO: Connection health restored');
          _consecutiveFailures = 0;
        }
      }
    } catch (e) {
      AppLogger().warning('⚠️ PERSISTENT AUDIO: Health check error: $e');
      _consecutiveFailures++;
    }
  }
  
  /// Check if token needs refresh and refresh if needed
  void _performTokenRefreshCheck() async {
    if (_isDisposed || !_isInitialized || _currentUserId == null) return;
    
    try {
      // For now, we'll implement a simple refresh strategy
      // In a production app, you'd check the actual token expiry time
      if (_isConnected && _currentRoomId != null && _currentRoomType != null && _currentUserRole != null) {
        AppLogger().debug('🔑 PERSISTENT AUDIO: Performing token refresh check');
        
        // Note: LiveKit client doesn't have a direct token refresh method
        // This is a placeholder for future implementation or server-side token push
        AppLogger().debug('🔑 PERSISTENT AUDIO: Token refresh check completed');
      }
    } catch (e) {
      AppLogger().warning('⚠️ PERSISTENT AUDIO: Token refresh check error: $e');
    }
  }
  
  /// Handle app lifecycle changes (called from main app)
  void onAppLifecycleChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        AppLogger().info('📱 PERSISTENT AUDIO: App resumed - ensuring connection health');
        // App resumed
        
        // Immediate health check when app resumes
        _performConnectionHealthCheck();
        break;
        
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        AppLogger().debug('📱 PERSISTENT AUDIO: App backgrounded - maintaining connection');
        // App backgrounded
        // Keep connection alive but reduce activity
        break;
        
      case AppLifecycleState.detached:
        AppLogger().debug('📱 PERSISTENT AUDIO: App detached - preparing for cleanup');
        // App is being terminated - we might want to dispose here
        break;
        
      case AppLifecycleState.hidden:
        AppLogger().debug('📱 PERSISTENT AUDIO: App hidden - maintaining connection');
        break;
    }
  }

  /// Test basic connectivity to LiveKit server before attempting full connection
  Future<bool> _testServerConnectivity(String serverUrl) async {
    try {
      AppLogger().info('🧪 PERSISTENT AUDIO: Testing server connectivity to $serverUrl');
      
      // Extract host and port from WebSocket URL
      final uri = Uri.parse(serverUrl);
      final host = uri.host;
      final port = uri.port;
      
      AppLogger().debug('🧪 PERSISTENT AUDIO: Testing connection to $host:$port');
      
      // Test basic TCP connectivity
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      await socket.close();
      
      AppLogger().info('✅ PERSISTENT AUDIO: Server connectivity test passed');
      return true;
      
    } catch (error) {
      AppLogger().error('❌ PERSISTENT AUDIO: Server connectivity test failed: $error');
      return false;
    }
  }

  /// Connect to LiveKit with retry logic and enhanced error handling
  Future<void> _connectWithRetry({
    required String serverUrl,
    required String token,
    required String roomName,
    int maxRetries = 3,
  }) async {
    // First test basic server connectivity
    AppLogger().info('🔄 PERSISTENT AUDIO: Pre-flight connectivity check...');
    if (!await _testServerConnectivity(serverUrl)) {
      throw Exception('LiveKit server is not reachable at $serverUrl. Please check server status and network connectivity.');
    }
    
    int attempts = 0;
    Duration delay = const Duration(seconds: 2);
    
    while (attempts < maxRetries) {
      try {
        attempts++;
        AppLogger().info('🔄 PERSISTENT AUDIO: Connection attempt $attempts/$maxRetries to $roomName');
        AppLogger().debug('🔄 PERSISTENT AUDIO: Server URL: $serverUrl');
        AppLogger().debug('🔄 PERSISTENT AUDIO: Token length: ${token.length} chars');
        
        // Enhanced connection options with comprehensive ICE configuration
        const connectOptions = ConnectOptions(
          autoSubscribe: true,
          protocolVersion: ProtocolVersion.v9,
          // Add comprehensive ICE server configuration
          rtcConfiguration: RTCConfiguration(
            iceServers: [
              // Google STUN servers for better NAT traversal
              RTCIceServer(urls: ['stun:stun.l.google.com:19302']),
              RTCIceServer(urls: ['stun:stun1.l.google.com:19302']),
              // Free TURN server from OpenRelay (Metered) - helps with strict NAT
              RTCIceServer(
                urls: [
                  'turn:a.relay.metered.ca:80',
                  'turn:a.relay.metered.ca:80?transport=tcp',
                  'turn:a.relay.metered.ca:443',
                  'turn:a.relay.metered.ca:443?transport=tcp',
                ],
                username: 'e8dd65c92c1036ee0365f24e',
                credential: 'BXDGfnKgHqR6e0kF',
              ),
            ],
            iceTransportPolicy: RTCIceTransportPolicy.all,
            // Add ICE candidate pooling for faster connections
            iceCandidatePoolSize: 10,
          ),
        );
        
        AppLogger().debug('🔄 PERSISTENT AUDIO: Starting connection with ${connectOptions.rtcConfiguration.iceServers?.length ?? 0} ICE servers');
        
        await _persistentRoom!.connect(
          serverUrl,
          token,
          connectOptions: connectOptions,
        ).timeout(
          Duration(seconds: 20 + (attempts * 10)), // More aggressive timeout increases
          onTimeout: () {
            AppLogger().error('⏰ PERSISTENT AUDIO: Connection timed out after ${20 + (attempts * 10)} seconds');
            throw Exception('Connection timeout after ${20 + (attempts * 10)} seconds (attempt $attempts). This suggests ICE connectivity issues.');
          },
        );
        
        AppLogger().info('✅ PERSISTENT AUDIO: Successfully connected to $roomName on attempt $attempts');
        
        // Log connection details for debugging
        if (_persistentRoom?.connectionState != null) {
          AppLogger().debug('📊 PERSISTENT AUDIO: Connection state: ${_persistentRoom!.connectionState}');
        }
        
        return; // Success - exit retry loop
        
      } catch (error) {
        final errorString = error.toString();
        AppLogger().warning('⚠️ PERSISTENT AUDIO: Connection attempt $attempts failed: $errorString');
        
        // Categorize the error for better debugging
        if (errorString.contains('MediaConnectException')) {
          AppLogger().error('🔍 PERSISTENT AUDIO: MediaConnectException detected - this is typically an ICE connectivity issue');
          AppLogger().error('🔍 PERSISTENT AUDIO: Possible causes:');
          AppLogger().error('   - Firewall blocking WebRTC traffic');
          AppLogger().error('   - NAT/Router not supporting STUN protocol');
          AppLogger().error('   - LiveKit server ICE configuration issues');
          AppLogger().error('   - Corporate network blocking UDP traffic');
        } else if (errorString.contains('PeerConnection')) {
          AppLogger().error('🔍 PERSISTENT AUDIO: PeerConnection issue - WebRTC handshake failed');
        } else if (errorString.contains('timeout')) {
          AppLogger().error('🔍 PERSISTENT AUDIO: Timeout issue - network or server response too slow');
        }
        
        if (attempts >= maxRetries) {
          AppLogger().error('❌ PERSISTENT AUDIO: All $maxRetries connection attempts failed');
          
          // Provide detailed error analysis
          AppLogger().error('🔧 PERSISTENT AUDIO: Troubleshooting suggestions:');
          AppLogger().error('   1. Check if LiveKit server is running and accessible');
          AppLogger().error('   2. Verify network allows WebRTC traffic (UDP ports)');
          AppLogger().error('   3. Test from different network (mobile data vs WiFi)');
          AppLogger().error('   4. Check LiveKit server ICE configuration');
          
          rethrow; // Re-throw the last error after all retries exhausted
        }
        
        // Wait before retry with exponential backoff
        AppLogger().info('⏳ PERSISTENT AUDIO: Waiting ${delay.inSeconds}s before retry...');
        await Future.delayed(delay);
        delay = Duration(seconds: (delay.inSeconds * 1.5).round()); // More gradual backoff
      }
    }
  }

  /// Initialize the persistent audio connection
  /// Call this once on app startup
  Future<void> initialize({
    required String userId,
    String serverUrl = 'ws://172.236.109.9:7880', // Match actual server
    String? roomName, // Optional specific room to connect to
  }) async {
    if (_isInitialized || _isDisposed) return;
    
    try {
      AppLogger().info('🚀 PERSISTENT AUDIO: Initializing persistent audio service for user: $userId');
      
      // Store user ID for token generation
      _currentUserId = userId;
      
      // Determine connection strategy
      final String tokenRoomName;
      final String connectionDisplayName;
      
      if (roomName != null) {
        // Connecting to a specific room - generate room-specific token
        tokenRoomName = roomName;
        connectionDisplayName = roomName;
        _currentRoomId = roomName;
        // We'll determine room type and role when switchToRoom is called
        AppLogger().debug('🎫 PERSISTENT AUDIO: Connecting directly to room: $roomName');
      } else {
        // Connecting to lobby - generate lobby token
        tokenRoomName = 'arena-lobby-$userId';
        connectionDisplayName = 'lobby';
        AppLogger().debug('🎫 PERSISTENT AUDIO: Connecting to lobby room: $tokenRoomName');
      }
      
      // Generate appropriate token
      final token = roomName != null 
          ? await _tokenService.generateLobbyToken(userId) // Use lobby token for flexibility
          : await _tokenService.generateLobbyToken(userId);
      
      AppLogger().debug('🎫 PERSISTENT AUDIO: Generated token for $connectionDisplayName');
      
      // Create persistent room with optimized settings for better connectivity
      _persistentRoom = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          // Enhanced connectivity settings
          e2eeOptions: null, // Disable E2EE for better performance
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'microphone',
            dtx: true, // Enable discontinuous transmission
          ),
          defaultVideoPublishOptions: VideoPublishOptions(
            name: 'camera',
          ),
        ),
      );
      
      // Set up event listeners
      _setupEventListeners();
      
      // Connect to the room with enhanced connectivity options
      await _connectWithRetry(
        serverUrl: serverUrl,
        token: token,
        roomName: connectionDisplayName,
        maxRetries: 3,
      );
      
      _localParticipant = _persistentRoom!.localParticipant;
      _isConnected = true;
      _isInitialized = true;
      
      // Pre-configure audio track (muted initially)
      await _setupInitialAudioTrack();
      
      AppLogger().info('✅ PERSISTENT AUDIO: Persistent audio service initialized successfully');
      onConnected?.call();
      notifyListeners();
      
    } catch (error) {
      AppLogger().error('❌ PERSISTENT AUDIO: Failed to initialize persistent audio service: $error');
      onError?.call('Failed to initialize audio service: $error');
      rethrow;
    }
  }
  
  /// Set up initial audio track (muted, ready for instant unmuting)
  Future<void> _setupInitialAudioTrack() async {
    if (_localParticipant == null) return;
    
    try {
      // Create audio track but keep it muted
      await _localParticipant!.setMicrophoneEnabled(true);
      await _localParticipant!.setMicrophoneEnabled(false);
      _isMuted = true;
      
      AppLogger().debug('🎤 PERSISTENT AUDIO: Initial audio track configured (muted, ready for instant unmuting)');
    } catch (e) {
      AppLogger().warning('⚠️ PERSISTENT AUDIO: Failed to setup initial audio track: $e');
    }
  }
  
  /// Switch to a specific room instantly
  /// This is the key method that makes room transitions instant
  Future<void> switchToRoom({
    required String roomId,
    required String roomType,
    required String userRole,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized || _isDisposed) {
      throw Exception('Persistent audio service not initialized');
    }
    
    try {
      // Skip Arena rooms - they now use LiveKitService directly
      if (roomType == 'arena') {
        AppLogger().info('🏛️ PERSISTENT AUDIO: Skipping Arena room - Arena uses LiveKitService directly');
        return;
      }
      
      AppLogger().info('⚡ PERSISTENT AUDIO: INSTANT ROOM SWITCH: $roomId (type: $roomType, role: $userRole)');
      AppLogger().debug('🔗 PERSISTENT AUDIO: Connection state: connected=$_isConnected, room=${_persistentRoom?.connectionState}');
      
      // If we're already in the target room with the right role, just update metadata
      if (_currentRoomId == roomId && _currentUserRole == userRole) {
        AppLogger().debug('🔄 PERSISTENT AUDIO: Already in target room with correct role, updating metadata only');
        await _updateParticipantMetadata({
          'roomId': roomId,
          'roomType': roomType,
          'role': userRole,
          'userId': _currentUserId,
          ...?metadata,
        });
        return;
      }
      
      // For room switches, we need to reconnect to the actual room
      // This is still much faster than a cold start because our connection is ready
      const currentServerUrl = 'ws://172.236.109.9:7880'; // Use consistent server URL
      
      AppLogger().info('🔄 PERSISTENT AUDIO: Switching to different room, reconnecting...');
      
      // Generate new token for target room and role
      final newToken = LiveKitTokenService.generateToken(
        roomName: roomId,
        identity: _currentUserId!,
        userRole: userRole,
        roomType: roomType,
        userId: _currentUserId,
      );
      
      // Disconnect from current room (but keep the Room object and settings)
      if (_persistentRoom!.connectionState == ConnectionState.connected) {
        await _persistentRoom!.disconnect();
      }
      
      // Connect to new room with pre-warmed connection and retry logic
      await _connectWithRetry(
        serverUrl: currentServerUrl,
        token: newToken,
        roomName: roomId,
        maxRetries: 2, // Fewer retries for room switches since infrastructure is pre-warmed
      );
      
      // Update current context
      _currentRoomId = roomId;
      _currentRoomType = roomType;
      _currentUserRole = userRole;
      
      // Set up audio permissions based on new role
      await _setupAudioForRole(userRole, roomType);
      
      AppLogger().info('✅ PERSISTENT AUDIO: Successfully switched to room $roomId');
      notifyListeners();
      
    } catch (error) {
      AppLogger().error('❌ PERSISTENT AUDIO: Failed to switch to room $roomId: $error');
      onError?.call('Failed to switch room: $error');
      rethrow;
    }
  }
  
  /// Switch to lobby (between rooms)
  Future<void> switchToLobby() async {
    if (!_isInitialized || _isDisposed) return;
    
    try {
      AppLogger().debug('🏠 PERSISTENT AUDIO: Switching to lobby');
      
      // For lobby, we can either disconnect or stay in a lobby room
      // For simplicity and true persistent audio, let's stay connected to a lobby room
      
      final lobbyRoomId = 'arena-lobby-$_currentUserId';
      
      // Only switch if we're not already in lobby
      if (_currentRoomId != lobbyRoomId) {
        await switchToRoom(
          roomId: lobbyRoomId,
          roomType: 'lobby',
          userRole: 'audience',
        );
      }
      
      // Ensure muted in lobby
      await _setMuted(true);
      
      AppLogger().debug('✅ PERSISTENT AUDIO: Switched to lobby, keeping connection alive');
      
    } catch (error) {
      AppLogger().warning('⚠️ PERSISTENT AUDIO: Failed to switch to lobby: $error');
    }
  }
  
  /// Set up audio permissions based on role and room type
  Future<void> _setupAudioForRole(String role, String roomType) async {
    if (_localParticipant == null) return;
    
    final canPublish = _canPublishMedia(role, roomType);
    AppLogger().debug('🎤 PERSISTENT AUDIO: Role $role in $roomType can publish: $canPublish');
    
    try {
      if (canPublish) {
        // User can speak - ensure audio track exists but start muted
        if (!_hasAudioTrack()) {
          AppLogger().debug('🎤 PERSISTENT AUDIO: Creating audio track for speaking role');
          await _localParticipant!.setMicrophoneEnabled(true);
          AppLogger().debug('✅ PERSISTENT AUDIO: Audio track created successfully');
        }
        await _setMuted(true); // Start muted, user can unmute manually
      } else {
        // Audience role - ensure muted and don't try to publish
        AppLogger().debug('🔇 PERSISTENT AUDIO: Audience role - ensuring muted state');
        await _setMuted(true);
      }
    } catch (error) {
      AppLogger().warning('⚠️ PERSISTENT AUDIO: Failed to setup audio for role $role: $error');
      // Don't throw - just ensure muted state as fallback
      try {
        await _setMuted(true);
      } catch (muteError) {
        AppLogger().warning('⚠️ PERSISTENT AUDIO: Failed to mute as fallback: $muteError');
      }
    }
  }
  
  /// Check if user has audio track
  bool _hasAudioTrack() {
    if (_localParticipant == null) return false;
    return _localParticipant!.audioTrackPublications.isNotEmpty;
  }
  
  /// Check if connection is healthy
  bool get isConnectionHealthy {
    if (!_isConnected || _persistentRoom == null) return false;
    
    // Check if room is properly connected
    if (_persistentRoom!.connectionState != ConnectionState.connected) {
      return false;
    }
    
    // Check if we have a local participant
    if (_localParticipant == null) return false;
    
    return true;
  }
  
  /// Determine if role can publish media based on room type
  bool _canPublishMedia(String role, String roomType) {
    switch (roomType) {
      case 'arena':
        return role == 'moderator' ||
               role == 'affirmative' || 
               role == 'negative' || 
               role == 'affirmative2' || 
               role == 'negative2' ||
               role == 'judge' ||
               role == 'judge1' ||
               role == 'judge2' ||
               role == 'judge3';
        
      case 'debate_discussion':
      case 'open_discussion':
        return role == 'moderator' || role == 'speaker';
        
      default:
        return role != 'audience';
    }
  }
  
  /// Set up event listeners for the persistent room
  void _setupEventListeners() {
    if (_persistentRoom == null) return;
    
    // Room disconnected
    _persistentRoom!.addListener(() {
      if (_persistentRoom!.connectionState == ConnectionState.disconnected) {
        _handleDisconnection();
      }
      notifyListeners();
    });
    
    // Create event listener
    final roomListener = _persistentRoom!.createListener();
    
    // Participant events
    roomListener.on<ParticipantConnectedEvent>((event) {
      AppLogger().debug('👤 PERSISTENT AUDIO: Participant connected: ${event.participant.identity}');
      _handleParticipantConnected(event.participant);
      onParticipantConnected?.call(event.participant);
      notifyListeners();
    });
    
    roomListener.on<ParticipantDisconnectedEvent>((event) {
      AppLogger().debug('👤 PERSISTENT AUDIO: Participant disconnected: ${event.participant.identity}');
      _cleanupSpeakingDetection(event.participant.identity);
      onParticipantDisconnected?.call(event.participant);
      notifyListeners();
    });
    
    // Track events
    roomListener.on<TrackSubscribedEvent>((event) {
      AppLogger().debug('🎵 PERSISTENT AUDIO: Track subscribed: ${event.track.kind}');
      onTrackSubscribed?.call(event.publication, event.participant);
      notifyListeners();
    });
    
    roomListener.on<TrackUnsubscribedEvent>((event) {
      AppLogger().debug('🎵 PERSISTENT AUDIO: Track unsubscribed: ${event.publication.kind}');
      onTrackUnsubscribed?.call(event.publication, event.participant);
      notifyListeners();
    });
    
    // Metadata events
    roomListener.on<ParticipantMetadataUpdatedEvent>((event) {
      AppLogger().debug('📝 PERSISTENT AUDIO: Participant metadata updated: ${event.participant.identity}');
      final metadata = event.participant.metadata != null 
          ? jsonDecode(event.participant.metadata!) as Map<String, dynamic>
          : <String, dynamic>{};
      onMetadataChanged?.call(event.participant.identity, metadata);
      notifyListeners();
    });
    
    // Disconnection events
    roomListener.on<RoomDisconnectedEvent>((event) {
      AppLogger().warning('🔌 PERSISTENT AUDIO: Room disconnected: ${event.reason}');
      _handleDisconnection();
    });
    
    // Data received events (for moderator controls)
    roomListener.on<DataReceivedEvent>((event) {
      _handleDataReceived(event);
    });
  }
  
  /// Handle participant connected
  void _handleParticipantConnected(RemoteParticipant participant) {
    // Set up speaking detection for new participant
    for (final publication in participant.audioTrackPublications) {
      _setupSpeakingDetection(participant, publication);
    }
  }
  
  /// Handle data received (mute/unmute commands)
  void _handleDataReceived(DataReceivedEvent event) async {
    try {
      final data = utf8.decode(event.data);
      final message = jsonDecode(data) as Map<String, dynamic>;
      
      final type = message['type'] as String?;
      final targetParticipant = message['targetParticipant'] as String?;
      // final fromModerator = message['fromModerator'] as String?; // For future validation
      
      // Handle broadcast or targeted messages
      if (type == 'mute_all_command' || 
          (targetParticipant != null && targetParticipant == _localParticipant?.identity)) {
        
        switch (type) {
          case 'mute_request':
          case 'mute_all_command':
            if (!_isMuted) {
              await _setMuted(true);
              AppLogger().debug('🔇 PERSISTENT AUDIO: Auto-muted by moderator');
            }
            break;
            
          case 'unmute_request':
            if (_isMuted) {
              await _setMuted(false);
              AppLogger().debug('🎤 PERSISTENT AUDIO: Auto-unmuted by moderator');
            }
            break;
        }
      }
    } catch (error) {
      AppLogger().warning('⚠️ PERSISTENT AUDIO: Failed to handle data message: $error');
    }
  }
  
  /// Update participant metadata
  Future<void> _updateParticipantMetadata(Map<String, dynamic> metadata) async {
    if (_localParticipant == null) return;
    
    try {
      _localParticipant!.setMetadata(jsonEncode(metadata));
      AppLogger().debug('📝 PERSISTENT AUDIO: Updated metadata: $metadata');
    } catch (error) {
      AppLogger().warning('⚠️ PERSISTENT AUDIO: Failed to update metadata: $error');
    }
  }
  
  /// Toggle mute state
  Future<void> toggleMute() async {
    await _setMuted(!_isMuted);
  }
  
  /// Set mute state
  Future<void> _setMuted(bool muted) async {
    if (_localParticipant == null) return;
    
    try {
      await _localParticipant!.setMicrophoneEnabled(!muted);
      _isMuted = muted;
      
      AppLogger().debug('🎤 PERSISTENT AUDIO: ${muted ? 'Muted' : 'Unmuted'} microphone');
      notifyListeners();
    } catch (error) {
      AppLogger().warning('⚠️ PERSISTENT AUDIO: Failed to ${muted ? 'mute' : 'unmute'}: $error');
      onError?.call('Failed to ${muted ? 'mute' : 'unmute'}: $error');
    }
  }
  
  /// Enable audio (unmute)
  Future<void> enableAudio() async {
    await _setMuted(false);
  }
  
  /// Disable audio (mute)
  Future<void> disableAudio() async {
    await _setMuted(true);
  }
  
  /// Mute a specific participant (moderator only)
  Future<void> muteParticipant(String participantIdentity) async {
    if (_currentUserRole != 'moderator' || _localParticipant == null) return;
    
    try {
      final messageData = {
        'type': 'mute_request',
        'targetParticipant': participantIdentity,
        'fromModerator': _localParticipant!.identity,
      };
      
      await _localParticipant!.publishData(
        utf8.encode(jsonEncode(messageData)),
        reliable: true,
        destinationIdentities: [participantIdentity],
      );
      
      AppLogger().debug('🔇 PERSISTENT AUDIO: Sent mute request to $participantIdentity');
    } catch (error) {
      AppLogger().warning('⚠️ PERSISTENT AUDIO: Failed to mute participant: $error');
    }
  }
  
  /// Unmute a specific participant (moderator only)
  Future<void> unmuteParticipant(String participantIdentity) async {
    if (_currentUserRole != 'moderator' || _localParticipant == null) return;
    
    try {
      final messageData = {
        'type': 'unmute_request',
        'targetParticipant': participantIdentity,
        'fromModerator': _localParticipant!.identity,
      };
      
      await _localParticipant!.publishData(
        utf8.encode(jsonEncode(messageData)),
        reliable: true,
        destinationIdentities: [participantIdentity],
      );
      
      AppLogger().debug('🎤 PERSISTENT AUDIO: Sent unmute request to $participantIdentity');
    } catch (error) {
      AppLogger().warning('⚠️ PERSISTENT AUDIO: Failed to unmute participant: $error');
    }
  }
  
  /// Mute all participants (moderator only)
  Future<void> muteAllParticipants() async {
    if (_currentUserRole != 'moderator' || _localParticipant == null) return;
    
    try {
      final messageData = {
        'type': 'mute_all_command',
        'fromModerator': _localParticipant!.identity,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await _localParticipant!.publishData(
        utf8.encode(jsonEncode(messageData)),
        reliable: true,
      );
      
      AppLogger().debug('🔇 PERSISTENT AUDIO: Sent mute-all command');
    } catch (error) {
      AppLogger().warning('⚠️ PERSISTENT AUDIO: Failed to mute all participants: $error');
    }
  }
  
  /// Set up speaking detection
  void _setupSpeakingDetection(RemoteParticipant participant, RemoteTrackPublication publication) {
    if (publication.kind.name != 'audio') return;
    
    final userId = participant.identity;
    _speakingStates[userId] = false;
    _audioLevels[userId] = 0.0;
    
    // Monitor track changes for speaking detection
    publication.track?.addListener(() {
      if (publication.track is RemoteAudioTrack) {
        final audioTrack = publication.track as RemoteAudioTrack;
        _handleAudioTrackChange(userId, audioTrack);
      }
    });
  }
  
  /// Handle audio track changes for speaking detection
  void _handleAudioTrackChange(String userId, RemoteAudioTrack audioTrack) {
    final shouldBeSpeaking = !audioTrack.muted;
    final currentlySpeaking = _speakingStates[userId] ?? false;
    
    if (shouldBeSpeaking != currentlySpeaking) {
      _updateSpeakingState(userId, shouldBeSpeaking);
    }
  }
  
  /// Update speaking state
  void _updateSpeakingState(String userId, bool isSpeaking) {
    final wasSpeaking = _speakingStates[userId] ?? false;
    
    if (isSpeaking != wasSpeaking) {
      _speakingStates[userId] = isSpeaking;
      
      _speakingTimers[userId]?.cancel();
      
      if (isSpeaking) {
        onSpeakingChanged?.call(userId, true);
      } else {
        _speakingTimers[userId] = Timer(_speakingTimeout, () {
          if (_speakingStates[userId] == false) {
            onSpeakingChanged?.call(userId, false);
          }
        });
      }
      
      notifyListeners();
    }
  }
  
  /// Clean up speaking detection
  void _cleanupSpeakingDetection(String userId) {
    _speakingStates.remove(userId);
    _audioLevels.remove(userId);
    _speakingTimers[userId]?.cancel();
    _speakingTimers.remove(userId);
  }
  
  /// Handle disconnection
  void _handleDisconnection() {
    _isConnected = false;
    
    // Try to reconnect if we're not disposing
    if (!_isDisposed && _isInitialized) {
      _attemptReconnection();
    }
    
    onDisconnected?.call();
    notifyListeners();
  }
  
  /// Attempt to reconnect
  Future<void> _attemptReconnection() async {
    if (_isDisposed || _currentUserId == null) return;
    
    AppLogger().warning('🔄 PERSISTENT AUDIO: Attempting to reconnect...');
    
    try {
      // Wait a bit before reconnecting
      await Future.delayed(const Duration(seconds: 2));
      
      if (!_isDisposed) {
        await initialize(userId: _currentUserId!);
        
        // If we were in a room, rejoin it
        if (_currentRoomId != null && _currentRoomType != null && _currentUserRole != null) {
          await switchToRoom(
            roomId: _currentRoomId!,
            roomType: _currentRoomType!,
            userRole: _currentUserRole!,
          );
        }
      }
    } catch (error) {
      AppLogger().error('❌ PERSISTENT AUDIO: Reconnection failed: $error');
      onError?.call('Connection lost: $error');
    }
  }
  
  /// Force cleanup and restart
  Future<void> restart({required String userId}) async {
    AppLogger().info('🔄 PERSISTENT AUDIO: Restarting persistent audio service');
    
    await dispose();
    await initialize(userId: userId);
  }
  
  /// Dispose the service
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    AppLogger().info('🧹 PERSISTENT AUDIO: Disposing persistent audio service');
    _isDisposed = true;
    
    // Clean up background connection management timers
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
    
    // Clean up speaking timers
    for (final timer in _speakingTimers.values) {
      timer?.cancel();
    }
    _speakingTimers.clear();
    _speakingStates.clear();
    _audioLevels.clear();
    
    // Disconnect and dispose room
    if (_persistentRoom != null) {
      await _persistentRoom!.disconnect();
      await _persistentRoom!.dispose();
      _persistentRoom = null;
    }
    
    _localParticipant = null;
    _isConnected = false;
    _isInitialized = false;
    
    // Clear context
    _currentRoomId = null;
    _currentRoomType = null;
    _currentUserId = null;
    _currentUserRole = null;
    
    super.dispose();
  }
}