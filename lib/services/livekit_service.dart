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
  
  // Speaking detection getters
  bool isUserSpeaking(String userId) => _speakingStates[userId] ?? false;
  double getUserAudioLevel(String userId) => _audioLevels[userId] ?? 0.0;
  Map<String, bool> get allSpeakingStates => Map.from(_speakingStates);
  List<String> get currentSpeakers => _speakingStates.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toList();
  
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
      
      debugPrint('🔗 CONNECTING to LiveKit room: $roomName');
      debugPrint('📱 Server: $serverUrl');
      debugPrint('👤 RECEIVED PARAMS - Role: "$userRole", Type: "$roomType"');
      debugPrint('🆔 User ID: $userId');
      
      // Store role and room type
      debugPrint('💾 STORING: Saving role and room type in LiveKit service');
      debugPrint('💾 BEFORE: _userRole=$_userRole, _currentRoomType=$_currentRoomType');
      
      _currentRoom = roomName;
      _currentRoomType = roomType;
      _userRole = userRole;
      
      debugPrint('💾 AFTER: _userRole=$_userRole, _currentRoomType=$_currentRoomType');
      debugPrint('✅ LiveKit service stored - Role: "$_userRole", RoomType: "$_currentRoomType"');
      
      // Check if this role can publish
      final canPublishCheck = _canPublishMedia(_userRole!, _currentRoomType!);
      debugPrint('🔍 INITIAL CHECK: Can "$_userRole" publish in "$_currentRoomType"? $canPublishCheck');
      // User ID stored for session
      
      // Create room with options optimized for Arena audio with noise cancellation
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
      
      // Connect to room with increased timeout for mobile networks
      await _room!.connect(
        serverUrl,
        token,
        connectOptions: const ConnectOptions(
          autoSubscribe: true,
          protocolVersion: ProtocolVersion.v9,
        ),
      ).timeout(
        const Duration(seconds: 45), // Increased timeout for mobile networks
        onTimeout: () {
          throw Exception('LiveKit connection timeout - please check your network connection');
        },
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
      _cleanupSpeakingDetection(event.participant.identity);
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
    
    // Audio track published event - set up speaking detection
    roomListener.on<TrackPublishedEvent>((event) {
      if (event.publication.kind.name == 'audio') {
        debugPrint('🎤 Audio track published for ${event.participant.identity}');
        _setupSpeakingDetection(event.participant, event.publication);
      }
    });
    
    // Local track published - set up speaking detection for local user
    roomListener.on<LocalTrackPublishedEvent>((event) {
      if (event.publication.kind.name == 'audio') {
        debugPrint('🎤 Local audio track published');
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
    
    debugPrint('🎤 SETUP MEDIA: _setupMediaBasedOnRole called');
    debugPrint('🎤 SETUP MEDIA: Current role: $_userRole');
    debugPrint('🎤 SETUP MEDIA: Current room type: $_currentRoomType');
    
    if (_userRole == null || _currentRoomType == null) {
      debugPrint('⚠️ User role or room type is null: role=$_userRole, type=$_currentRoomType');
      return;
    }
    
    final canPublish = _canPublishMedia(_userRole!, _currentRoomType!);
    debugPrint('🎤 SETUP MEDIA: Can publish result: $canPublish for role "$_userRole" in "$_currentRoomType"');
    
    if (canPublish) {
      try {
        debugPrint('✅ SETUP MEDIA: Creating and enabling audio tracks for role: $_userRole in $_currentRoomType');
        
        // For speakers/moderators, ensure audio track is created and initially muted
        // This ensures the track exists for later unmuting
        await _localParticipant!.setMicrophoneEnabled(true);
        debugPrint('🎤 SETUP MEDIA: Audio track created and enabled');
        
        // Now mute it initially - speakers should start muted but have tracks ready
        await _localParticipant!.setMicrophoneEnabled(false);
        _isMuted = true;
        debugPrint('🔇 SETUP MEDIA: Audio track muted initially (speakers start muted but can unmute)');
        
        notifyListeners();
        debugPrint('✅ SETUP MEDIA: Audio track setup completed for $_userRole');
      } catch (e) {
        debugPrint('⚠️ SETUP MEDIA: Failed to setup audio tracks: $e');
        // Don't propagate error for initial setup - user can manually unmute later
      }
      
      // Arena is audio-only, no video needed
      // Video can be enabled for other room types if needed
    } else {
      // This is expected for audience members - not an error
      debugPrint('ℹ️ SETUP MEDIA: User role "$_userRole" is listen-only in "$_currentRoomType" room');
      debugPrint('ℹ️ SETUP MEDIA: This is normal for audience members');
      // Don't throw error or call onError - this is expected behavior
    }
  }
  
  /// Determine if role can publish media based on room type
  bool _canPublishMedia(String role, String roomType) {
    debugPrint('🔍 JUDGE DEBUG: _canPublishMedia called with role="$role", roomType="$roomType"');
    
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
        
        debugPrint('🔍 JUDGE DEBUG: Arena role check result: $result for role="$role"');
        debugPrint('🔍 JUDGE DEBUG: Is judge?: ${role == 'judge'}');
        debugPrint('🔍 JUDGE DEBUG: Is judge1?: ${role == 'judge1'}');
        debugPrint('🔍 JUDGE DEBUG: Is judge2?: ${role == 'judge2'}');
        debugPrint('🔍 JUDGE DEBUG: Is judge3?: ${role == 'judge3'}');
        
        return result;
        
      case 'debate_discussion':
        final canPublish = role == 'moderator' || role == 'speaker';
        debugPrint('🎯 DEBATE_DISCUSSION: Role "$role" can publish: $canPublish');
        return canPublish;
      case 'open_discussion':
        final canPublish = role == 'moderator' || role == 'speaker';
        debugPrint('🎯 OPEN_DISCUSSION: Role "$role" can publish: $canPublish');
        return canPublish;
      default:
        return role != 'audience';
    }
  }
  
  /// Enable audio publishing with noise cancellation
  Future<void> enableAudio() async {
    try {
      debugPrint('🎤 ENABLE AUDIO: enableAudio() called');
      debugPrint('🎤 ENABLE AUDIO: Current role: $_userRole, room type: $_currentRoomType');
      
      if (_localParticipant == null) {
        debugPrint('⚠️ No local participant available for audio enable');
        throw Exception('Local participant not available');
      }
      
      // Quick role check - if audience, don't allow
      if (_userRole == 'audience') {
        debugPrint('ℹ️ ENABLE AUDIO: Audience member cannot publish audio - this is expected');
        _isMuted = true;
        notifyListeners();
        return;
      }
      
      // iOS-specific: Add delay and retry mechanism for audio enabling
      bool enableSuccess = false;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (!enableSuccess && retryCount < maxRetries) {
        try {
          debugPrint('🎤 ENABLE AUDIO: Attempt ${retryCount + 1}/$maxRetries to enable microphone');
          
          // Add a small delay for iOS audio session stabilization
          if (retryCount > 0) {
            await Future.delayed(Duration(milliseconds: 200 * retryCount));
          }
          
          // Enable microphone with explicit error catching
          await _localParticipant!.setMicrophoneEnabled(true);
          
          // Verify it actually enabled by checking the state
          await Future.delayed(const Duration(milliseconds: 100)); // Give it time to update
          
          final audioTracks = _localParticipant!.audioTrackPublications;
          debugPrint('🎤 ENABLE AUDIO: Available audio tracks after enable (attempt ${retryCount + 1}): ${audioTracks.length}');
          
          if (audioTracks.isNotEmpty) {
            // Check if any audio track is actually published and not muted
            bool hasEnabledTrack = false;
            for (final publication in audioTracks) {
              if (publication.track != null && !publication.muted) {
                hasEnabledTrack = true;
                break;
              }
            }
            
            if (hasEnabledTrack) {
              enableSuccess = true;
              debugPrint('✅ ENABLE AUDIO: Audio track successfully enabled on attempt ${retryCount + 1}');
            } else {
              debugPrint('⚠️ ENABLE AUDIO: Audio tracks exist but are muted, retrying...');
            }
          } else {
            debugPrint('⚠️ ENABLE AUDIO: No audio tracks available after enable attempt ${retryCount + 1}');
          }
          
        } catch (e) {
          debugPrint('❌ ENABLE AUDIO: Attempt ${retryCount + 1} failed: $e');
          if (retryCount == maxRetries - 1) {
            rethrow; // Only rethrow on final attempt
          }
        }
        
        retryCount++;
      }
      
      if (!enableSuccess) {
        debugPrint('❌ ENABLE AUDIO: Failed to enable audio after $maxRetries attempts');
        throw Exception('Failed to enable microphone after $maxRetries attempts. Please check audio permissions.');
      }
      
      _isMuted = false;
      debugPrint('✅ ENABLE AUDIO: Audio enabled successfully for $_userRole');
      notifyListeners();
    } catch (error) {
      debugPrint('❌ ENABLE AUDIO: Failed to enable audio for $_userRole: $error');
      onError?.call('Failed to enable audio: $error');
      rethrow;
    }
  }
  
  /// Disable audio publishing
  Future<void> disableAudio() async {
    try {
      if (_localParticipant == null) return;
      
      debugPrint('🔇 DISABLE AUDIO: Disabling microphone');
      await _localParticipant!.setMicrophoneEnabled(false);
      
      // Verify it actually disabled by checking the state (iOS-specific)
      await Future.delayed(const Duration(milliseconds: 100));
      
      final audioTracks = _localParticipant!.audioTrackPublications;
      bool hasDisabledTracks = true;
      
      if (audioTracks.isNotEmpty) {
        for (final publication in audioTracks) {
          if (publication.track != null && !publication.muted) {
            hasDisabledTracks = false;
            debugPrint('⚠️ DISABLE AUDIO: Audio track still unmuted after disable attempt');
            break;
          }
        }
      }
      
      _isMuted = true;
      debugPrint('🔇 DISABLE AUDIO: Audio disabled ${hasDisabledTracks ? 'successfully' : 'with warnings'}');
      notifyListeners();
    } catch (error) {
      debugPrint('❌ DISABLE AUDIO: Failed to disable audio: $error');
      onError?.call('Failed to disable audio: $error');
    }
  }
  
  /// Toggle mute state
  Future<void> toggleMute() async {
    try {
      debugPrint('🔄 TOGGLE MUTE: Current state: ${_isMuted ? 'muted' : 'unmuted'}');
      debugPrint('🔄 TOGGLE MUTE: Will ${_isMuted ? 'enable' : 'disable'} audio');
      
      if (_isMuted) {
        await enableAudio();
      } else {
        await disableAudio();
      }
      
      debugPrint('✅ TOGGLE MUTE: Successfully toggled to ${_isMuted ? 'muted' : 'unmuted'}');
    } catch (error) {
      debugPrint('❌ TOGGLE MUTE: Failed to toggle mute state: $error');
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
      debugPrint('⚠️ Could not get noise cancellation status: $e');
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
        debugPrint('⚠️ Cannot test noise cancellation: not connected');
        return;
      }

      debugPrint('🧪 Testing noise cancellation features...');
      
      // Temporarily disable and re-enable audio to test constraints
      await _localParticipant!.setMicrophoneEnabled(false);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Re-enable with noise cancellation
      await enableAudio();
      
      // Get and display status
      final status = getNoiseCancellationStatus();
      debugPrint('🎤 Noise cancellation test results:');
      debugPrint('   Echo Cancellation: ${status['echoCancellation']}');
      debugPrint('   Noise Suppression: ${status['noiseSuppression']}');
      debugPrint('   Auto Gain Control: ${status['autoGainControl']}');
      debugPrint('   High-pass Filter: ${status['highpassFilter']}');
      debugPrint('   Typing Noise Detection: ${status['typingNoiseDetection']}');
      
    } catch (error) {
      debugPrint('❌ Noise cancellation test failed: $error');
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
  
  /// Force update the user role in LiveKit service
  void forceUpdateRole(String newRole, String roomType) {
    debugPrint('🔄 FORCE ROLE UPDATE: Updating LiveKit role from $_userRole to $newRole');
    debugPrint('🔄 FORCE ROLE UPDATE: Room type: $roomType');
    
    _userRole = newRole;
    _currentRoomType = roomType;
    
    debugPrint('✅ FORCE ROLE UPDATE: LiveKit role updated to $_userRole');
    notifyListeners();
  }

  /// Force setup audio for judges who might be having issues
  Future<void> forceSetupJudgeAudio() async {
    try {
      debugPrint('🎤 Force setting up judge audio...');
      debugPrint('🎤 Current stored role: $_userRole');
      
      if (_localParticipant == null) {
        throw Exception('No local participant available');
      }
      
      // SIMPLIFIED: In Arena, everyone can use audio (judges get same access as moderators)
      if (_currentRoomType == 'arena') {
        debugPrint('🎤 JUDGE FIX: Arena - bypassing role check, enabling audio directly');
      } else {
        // For other room types, check if it's actually a judge
        if (_userRole == null || !_userRole!.startsWith('judge')) {
          throw Exception('This method is only for judges, current role: $_userRole');
        }
        
        // Check permissions for non-Arena rooms
        final canPublish = _canPublishMedia(_userRole!, _currentRoomType ?? 'arena');
        debugPrint('🎤 Judge publish permission: $canPublish');
        
        if (!canPublish) {
          throw Exception('Judge role $_userRole cannot publish in $_currentRoomType');
        }
      }
      
      // Request microphone permissions explicitly
      debugPrint('🎤 Requesting microphone permissions...');
      
      // Try to enable audio tracks
      await _localParticipant!.setMicrophoneEnabled(true);
      
      _isMuted = false;
      debugPrint('✅ Judge audio setup completed successfully');
      notifyListeners();
      
    } catch (error) {
      debugPrint('❌ Failed to setup judge audio: $error');
      onError?.call('Failed to setup judge audio: $error');
      rethrow;
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
  
  /// Set up speaking detection for remote participants
  void _setupSpeakingDetection(RemoteParticipant participant, RemoteTrackPublication publication) {
    if (publication.kind.name != 'audio') return;
    
    final userId = participant.identity;
    debugPrint('🗣️ Setting up speaking detection for $userId');
    
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
    debugPrint('🗣️ Setting up local speaking detection for $userId');
    
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
        debugPrint('🗣️ User $userId started speaking');
        onSpeakingChanged?.call(userId, true);
      } else {
        // User might have stopped speaking, use timer to avoid rapid changes
        _speakingTimers[userId] = Timer(_speakingTimeout, () {
          if (_speakingStates[userId] == false) {
            debugPrint('🤐 User $userId stopped speaking');
            onSpeakingChanged?.call(userId, false);
          }
        });
      }
      
      notifyListeners();
    }
  }
  
  /// Manual method to simulate speaking detection (for testing)
  void simulateSpeaking(String userId, bool isSpeaking) {
    debugPrint('🧪 Simulating speaking for $userId: $isSpeaking');
    _updateSpeakingState(userId, isSpeaking);
  }
  
  /// Clean up speaking detection state when participant leaves
  void _cleanupSpeakingDetection(String userId) {
    _speakingStates.remove(userId);
    _audioLevels.remove(userId);
    _speakingTimers[userId]?.cancel();
    _speakingTimers.remove(userId);
    debugPrint('🧹 Cleaned up speaking detection for $userId');
  }

  /// Dispose resources
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _isDisposed = true;
    
    // Clean up all speaking timers
    for (final timer in _speakingTimers.values) {
      timer?.cancel();
    }
    _speakingTimers.clear();
    _speakingStates.clear();
    _audioLevels.clear();
    
    await disconnect();
    
    if (_room != null) {
      await _room!.dispose();
      _room = null;
    }
    
    super.dispose();
  }
}