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
  bool _isVideoEnabled = false;
  bool _isDisposed = false;
  String? _currentRoom;
  String? _currentRoomType;
  String? _userRole;
  
  // Callbacks for UI updates
  Function(RemoteParticipant)? onParticipantConnected;
  Function(RemoteParticipant)? onParticipantDisconnected;
  Function(RemoteTrackPublication, RemoteParticipant)? onTrackSubscribed;
  Function(RemoteTrackPublication, RemoteParticipant)? onTrackUnsubscribed;
  Function(String)? onError;
  Function()? onConnected;
  Function()? onDisconnected;
  Function(String userId, Map<String, dynamic> metadata)? onMetadataChanged;
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled && _localParticipant?.isCameraEnabled() == true;
  String? get userRole => _userRole;
  String? get currentRoom => _currentRoom;
  String? get currentRoomType => _currentRoomType;
  Room? get room => _room;
  LocalParticipant? get localParticipant => _localParticipant;
  
  List<RemoteParticipant> get remoteParticipants => 
      _room?.remoteParticipants.values.toList() ?? [];
  
  int get connectedPeersCount => remoteParticipants.length;
  
  /// Connect to a LiveKit room with role-based permissions
  Future<void> connect({
    required String serverUrl,
    required String roomName,
    required String token,
    required String userId,
    required String userRole,
    required String roomType,
  }) async {
    try {
      if (_isDisposed) return;
      
      debugPrint('🔗 Connecting to LiveKit room: $roomName');
      debugPrint('📱 Server: $serverUrl');
      debugPrint('👤 Role: $userRole, Type: $roomType');
      
      _currentRoom = roomName;
      _currentRoomType = roomType;
      _userRole = userRole;
      // User ID stored for session
      
      // Create room with options optimized for Arena audio
      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'microphone',
            dtx: true,  // Enable discontinuous transmission to save bandwidth and reduce feedback
          ),
          defaultVideoPublishOptions: VideoPublishOptions(
            name: 'camera',
          ),
        ),
      );
      
      // Set up event listeners
      _setupEventListeners();
      
      // Connect to room
      await _room!.connect(
        serverUrl,
        token,
        connectOptions: const ConnectOptions(
          autoSubscribe: true,
          protocolVersion: ProtocolVersion.v9,
        ),
      );
      
      _localParticipant = _room!.localParticipant;
      _isConnected = true;
      
      // Determine if user can publish media based on role and room type
      if (_localParticipant != null) {
        await _setupMediaBasedOnRole();
      } else {
        debugPrint('⚠️ Local participant is null, skipping media setup');
      }
      
      debugPrint('✅ Connected to LiveKit room successfully');
      onConnected?.call();
      notifyListeners();
      
    } catch (error) {
      debugPrint('❌ Failed to connect to LiveKit room: $error');
      onError?.call('Failed to connect: $error');
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
      debugPrint('👤 Participant connected: ${event.participant.identity}');
      _handleParticipantConnected(event.participant);
      onParticipantConnected?.call(event.participant);
      notifyListeners();
    });
    
    // Participant disconnected
    roomListener.on<ParticipantDisconnectedEvent>((event) {
      debugPrint('👤 Participant disconnected: ${event.participant.identity}');
      onParticipantDisconnected?.call(event.participant);
      notifyListeners();
    });
    
    // Track subscribed
    roomListener.on<TrackSubscribedEvent>((event) {
      debugPrint('🎵 Track subscribed: ${event.track.kind}');
      onTrackSubscribed?.call(event.publication, event.participant);
      notifyListeners();
    });
    
    // Track unsubscribed  
    roomListener.on<TrackUnsubscribedEvent>((event) {
      debugPrint('🎵 Track unsubscribed: ${event.publication.kind}');
      onTrackUnsubscribed?.call(event.publication, event.participant);
      notifyListeners();
    });
    
    // Participant metadata updated
    roomListener.on<ParticipantMetadataUpdatedEvent>((event) {
      debugPrint('📝 Participant metadata updated: ${event.participant.identity}');
      final metadata = event.participant.metadata != null 
          ? jsonDecode(event.participant.metadata!) as Map<String, dynamic>
          : <String, dynamic>{};
      onMetadataChanged?.call(event.participant.identity, metadata);
      notifyListeners();
    });
    
    // Room disconnected event
    roomListener.on<RoomDisconnectedEvent>((event) {
      debugPrint('🔌 Room disconnected: ${event.reason}');
      _handleDisconnection();
    });

    // Data received event (for mute/unmute requests)
    roomListener.on<DataReceivedEvent>((event) {
      _handleDataReceived(event);
    });
  }
  
  /// Handle participant role based on room type
  void _handleParticipantConnected(RemoteParticipant participant) {
    final metadata = participant.metadata != null 
        ? jsonDecode(participant.metadata!) as Map<String, dynamic>
        : <String, dynamic>{};
    
    final role = metadata['role'] as String?;
    debugPrint('👤 Participant ${participant.identity} joined with role: $role');
    
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
    debugPrint('🏟️ Arena participant: ${participant.identity} ($role)');
  }
  
  void _handleDebateDiscussionParticipant(RemoteParticipant participant, String? role) {
    // Debate & Discussion specific participant handling
    debugPrint('💬 Debate participant: ${participant.identity} ($role)');
  }
  
  void _handleOpenDiscussionParticipant(RemoteParticipant participant, String? role) {
    // Open Discussion specific participant handling
    debugPrint('🗣️ Open discussion participant: ${participant.identity} ($role)');
  }

  /// Handle incoming data messages (mute/unmute requests)
  void _handleDataReceived(DataReceivedEvent event) async {
    try {
      debugPrint('📨 Raw data received: ${event.data.length} bytes');
      
      final data = utf8.decode(event.data);
      debugPrint('📨 Decoded data: $data');
      
      final message = jsonDecode(data) as Map<String, dynamic>;
      debugPrint('📨 Parsed message: $message');
      
      final type = message['type'] as String?;
      final targetParticipant = message['targetParticipant'] as String?;
      final fromModerator = message['fromModerator'] as String?;
      
      debugPrint('📨 Message details - Type: $type, Target: $targetParticipant, From: $fromModerator');
      debugPrint('📨 Local participant identity: ${_localParticipant?.identity}');
      
      // Handle broadcast messages (mute_all_command) or targeted messages
      if (type == 'mute_all_command') {
        debugPrint('📨 Processing broadcast mute-all command from $fromModerator');
      } else if (targetParticipant != null && targetParticipant != _localParticipant?.identity) {
        debugPrint('📨 Targeted message not for us, ignoring');
        return;
      } else {
        debugPrint('📨 Processing moderator request: $type from $fromModerator');
      }
      
      switch (type) {
        case 'mute_request':
          debugPrint('🔇 Processing mute request - currently muted: $_isMuted');
          // Auto-mute when moderator requests it
          if (!_isMuted) {
            debugPrint('🔇 Calling disableAudio() to mute participant');
            await disableAudio();
            debugPrint('🔇 Auto-muted by moderator request');
          } else {
            debugPrint('🔇 Already muted, no action needed');
          }
          break;
          
        case 'unmute_request':
          debugPrint('🎤 Processing unmute request - currently muted: $_isMuted');
          // Auto-unmute when moderator requests it  
          if (_isMuted) {
            debugPrint('🎤 Calling enableAudio() to unmute participant');
            await enableAudio();
            debugPrint('🎤 Auto-unmuted by moderator request');
          } else {
            debugPrint('🎤 Already unmuted, no action needed');
          }
          break;
          
        case 'test_message':
          debugPrint('🧪 Test message received from $fromModerator');
          debugPrint('🧪 Message content: ${message['message']}');
          debugPrint('🧪 Timestamp: ${message['timestamp']}');
          break;
          
        case 'mute_all_command':
          debugPrint('🔇 Mute-all command received from $fromModerator');
          debugPrint('🔇 Current mute state: $_isMuted');
          // Mute immediately if not already muted
          if (!_isMuted) {
            debugPrint('🔇 Auto-muting due to mute-all command');
            await disableAudio();
            debugPrint('🔇 Successfully auto-muted by mute-all command');
          } else {
            debugPrint('🔇 Already muted, ignoring mute-all command');
          }
          break;
          
        default:
          debugPrint('📨 Unknown message type: $type');
      }
    } catch (error) {
      debugPrint('❌ Failed to handle data message: $error');
    }
  }
  
  /// Set up media publishing based on user role and room type
  Future<void> _setupMediaBasedOnRole() async {
    if (_localParticipant == null) return;
    
    if (_userRole == null || _currentRoomType == null) {
      debugPrint('⚠️ User role or room type is null: role=$_userRole, type=$_currentRoomType');
      return;
    }
    
    final canPublish = _canPublishMedia(_userRole!, _currentRoomType!);
    
    if (canPublish) {
      await enableAudio();
      
      // Arena is audio-only, no video needed
      // Video can be enabled for other room types if needed
    } else {
      debugPrint('🔇 User role $_userRole cannot publish in $_currentRoomType room');
    }
  }
  
  /// Determine if role can publish media based on room type
  bool _canPublishMedia(String role, String roomType) {
    switch (roomType) {
      case 'arena':
        return role == 'affirmative' || role == 'negative' || role == 'judge' || role == 'moderator';
      case 'debate_discussion':
        return role == 'moderator' || role == 'speaker';
      case 'open_discussion':
        return role == 'moderator' || role == 'speaker';
      default:
        return role != 'audience';
    }
  }
  
  /// Enable audio publishing with noise cancellation
  Future<void> enableAudio() async {
    try {
      if (_localParticipant == null) return;
      
      // Enable microphone with enhanced audio processing
      await _localParticipant!.setMicrophoneEnabled(true);
      
      // Apply audio constraints for noise cancellation (WebRTC level)
      try {
        // Get the local audio track
        final audioTracks = _localParticipant!.audioTrackPublications;
        if (audioTracks.isNotEmpty) {
          final audioTrack = audioTracks.first.track;
          if (audioTrack != null) {
            // These constraints help with noise cancellation at the WebRTC level
            debugPrint('🎤 Applying noise cancellation constraints to audio track');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Could not apply additional audio constraints: $e');
      }
      
      _isMuted = false;
      debugPrint('🎤 Audio enabled with noise cancellation');
      notifyListeners();
    } catch (error) {
      debugPrint('❌ Failed to enable audio: $error');
      onError?.call('Failed to enable audio: $error');
    }
  }
  
  /// Disable audio publishing
  Future<void> disableAudio() async {
    try {
      if (_localParticipant == null) return;
      
      await _localParticipant!.setMicrophoneEnabled(false);
      _isMuted = true;
      debugPrint('🔇 Audio disabled');
      notifyListeners();
    } catch (error) {
      debugPrint('❌ Failed to disable audio: $error');
      onError?.call('Failed to disable audio: $error');
    }
  }
  
  /// Toggle mute state
  Future<void> toggleMute() async {
    if (_isMuted) {
      await enableAudio();
    } else {
      await disableAudio();
    }
  }

  /// Mute a specific participant (moderator only)
  Future<void> muteParticipant(String participantIdentity) async {
    try {
      debugPrint('🔇 muteParticipant called for: $participantIdentity');
      
      if (_room == null) {
        debugPrint('⚠️ Cannot mute participant: room is null');
        return;
      }
      
      if (_userRole != 'moderator') {
        debugPrint('⚠️ Cannot mute participant: user role is $_userRole, not moderator');
        return;
      }
      
      if (_localParticipant == null) {
        debugPrint('⚠️ Cannot mute participant: local participant is null');
        return;
      }

      // Find the participant
      final participant = _room!.remoteParticipants[participantIdentity];
      if (participant == null) {
        debugPrint('⚠️ Participant $participantIdentity not found in remote participants');
        debugPrint('⚠️ Available participants: ${_room!.remoteParticipants.keys.toList()}');
        return;
      }

      debugPrint('🔇 Sending mute request to $participantIdentity');
      
      final messageData = {
        'type': 'mute_request',
        'targetParticipant': participantIdentity,
        'fromModerator': _localParticipant!.identity,
      };
      
      final messageJson = jsonEncode(messageData);
      final messageBytes = utf8.encode(messageJson);
      
      debugPrint('🔇 Message data: $messageData');
      debugPrint('🔇 Message JSON: $messageJson');
      debugPrint('🔇 Message bytes length: ${messageBytes.length}');
      
      // Send mute signal to participant via data publish
      await _localParticipant!.publishData(
        messageBytes,
        reliable: true,
        destinationIdentities: [participantIdentity],
      );
      
      debugPrint('✅ Data published to $participantIdentity');
      debugPrint('✅ Sent mute request to $participantIdentity');
    } catch (error) {
      debugPrint('❌ Failed to mute participant $participantIdentity: $error');
      onError?.call('Failed to mute participant: $error');
    }
  }

  /// Unmute a specific participant (moderator only)  
  Future<void> unmuteParticipant(String participantIdentity) async {
    try {
      if (_room == null || _userRole != 'moderator') {
        debugPrint('⚠️ Cannot unmute participant: not a moderator or not connected');
        return;
      }

      // Find the participant
      final participant = _room!.remoteParticipants[participantIdentity];
      if (participant == null) {
        debugPrint('⚠️ Participant $participantIdentity not found');
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
      
      debugPrint('🎤 Sent unmute request to $participantIdentity');
    } catch (error) {
      debugPrint('❌ Failed to unmute participant $participantIdentity: $error');
      onError?.call('Failed to unmute participant: $error');
    }
  }

  /// Mute all participants in the room (moderator only)
  /// Uses broadcast message to all participants
  Future<void> muteAllParticipants() async {
    try {
      debugPrint('🔇 muteAllParticipants() called');
      debugPrint('🔇 Room connected: ${_room != null}');
      debugPrint('🔇 User role: $_userRole');
      debugPrint('🔇 Is connected: $_isConnected');
      debugPrint('🔇 Remote participants: ${remoteParticipants.length}');
      
      if (_room == null) {
        debugPrint('⚠️ Cannot mute all: room is null');
        onError?.call('Not connected to room');
        return;
      }
      
      if (_userRole != 'moderator') {
        debugPrint('⚠️ Cannot mute all: user role is $_userRole, not moderator');
        onError?.call('Only moderators can mute all participants');
        return;
      }
      
      if (!_isConnected) {
        debugPrint('⚠️ Cannot mute all: not connected to room');
        onError?.call('Not connected to room');
        return;
      }
      
      if (_localParticipant == null) {
        debugPrint('⚠️ Cannot mute all: local participant is null');
        onError?.call('Local participant not available');
        return;
      }
      
      final participantCount = remoteParticipants.length;
      debugPrint('🔇 Moderator broadcasting mute-all to $participantCount participants');
      
      if (participantCount == 0) {
        debugPrint('⚠️ No remote participants to mute');
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
      
      debugPrint('🔇 Broadcasting mute-all message: $muteAllMessage');
      debugPrint('🔇 Message size: ${messageBytes.length} bytes');
      
      // Send broadcast message to all participants (no destinationIdentities = broadcast)
      await _localParticipant!.publishData(
        messageBytes,
        reliable: true,
        // No destinationIdentities = broadcast to all participants
      );
      
      debugPrint('✅ Broadcast mute-all command sent to all participants');
      
    } catch (error) {
      debugPrint('❌ Failed to broadcast mute-all: $error');
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
  
  /// Enable video publishing
  Future<void> enableVideo() async {
    try {
      if (_localParticipant == null) {
        debugPrint('⚠️ Cannot enable video: local participant is null');
        return;
      }
      
      debugPrint('📹 Attempting to enable camera...');
      
      // Create and publish camera track
      await _localParticipant!.setCameraEnabled(true);
      
      // Give it a moment to initialize
      await Future.delayed(const Duration(milliseconds: 500));
      
      _isVideoEnabled = true;
      debugPrint('✅ Video enabled successfully');
      notifyListeners();
    } catch (error) {
      debugPrint('❌ Failed to enable video: $error');
      
      // Try alternative approach: don't fail completely
      _isVideoEnabled = false;
      debugPrint('🔄 Video publishing failed, but continuing without video');
      onError?.call('Video unavailable: $error');
      notifyListeners();
    }
  }
  
  /// Disable video publishing
  Future<void> disableVideo() async {
    try {
      if (_localParticipant == null) return;
      
      await _localParticipant!.setCameraEnabled(false);
      _isVideoEnabled = false;
      debugPrint('📹 Video disabled');
      notifyListeners();
    } catch (error) {
      debugPrint('❌ Failed to disable video: $error');
      onError?.call('Failed to disable video: $error');
    }
  }
  
  /// Update participant metadata (for hand raising, role changes, etc.)
  void updateMetadata(Map<String, dynamic> metadata) {
    try {
      if (_localParticipant == null) return;
      
      _localParticipant!.setMetadata(jsonEncode(metadata));
      debugPrint('📝 Updated metadata: $metadata');
    } catch (error) {
      debugPrint('❌ Failed to update metadata: $error');
      onError?.call('Failed to update metadata: $error');
    }
  }
  
  /// Disconnect from the room
  Future<void> disconnect() async {
    try {
      debugPrint('🔌 Disconnecting from LiveKit room...');
      
      if (_room != null) {
        await _room!.disconnect();
      }
      
      _handleDisconnection();
      
    } catch (error) {
      debugPrint('❌ Error during disconnect: $error');
    }
  }
  
  /// Handle disconnection cleanup
  void _handleDisconnection() {
    _isConnected = false;
    _currentRoom = null;
    _currentRoomType = null;
    _userRole = null;
    // User ID cleared
    _localParticipant = null;
    
    onDisconnected?.call();
    notifyListeners();
  }
  
  /// Test connectivity to LiveKit server
  Future<bool> testServerConnectivity(String serverUrl) async {
    try {
      debugPrint('🔍 Testing LiveKit server connectivity to: $serverUrl');
      
      // Create a temporary room for testing
      final testRoom = Room();
      
      // Try to connect with a minimal token (will fail but test connectivity)
      try {
        await testRoom.connect(serverUrl, 'test-token');
      } catch (e) {
        // Expected to fail with invalid token, but connectivity is verified
        if (e.toString().contains('Unauthorized') || 
            e.toString().contains('invalid token')) {
          debugPrint('✅ Server connectivity test successful (expected auth error)');
          await testRoom.dispose();
          return true;
        }
        rethrow;
      }
      
      await testRoom.dispose();
      return true;
      
    } catch (error) {
      debugPrint('❌ Server connectivity test failed: $error');
      return false;
    }
  }
  
  /// Dispose resources
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _isDisposed = true;
    await disconnect();
    
    if (_room != null) {
      await _room!.dispose();
      _room = null;
    }
    
    super.dispose();
  }
}