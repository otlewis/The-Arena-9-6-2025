import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'agora_token_service.dart';
import '../core/logging/app_logger.dart';

class AgoraServiceImplementation {
  static final AgoraServiceImplementation _instance = AgoraServiceImplementation._internal();
  factory AgoraServiceImplementation() => _instance;
  AgoraServiceImplementation._internal();

  // Agora credentials
  static const String appId = "3ccc264b24df4b5f91fa35741ea6e0b8";
  static const String channelName = "arena";
  
  // Token service for dynamic token generation
  final AgoraTokenService _tokenService = AgoraTokenService();

  RtcEngine? _engine;
  bool _isJoined = false;
  ClientRoleType _userRole = ClientRoleType.clientRoleAudience;
  
  // Callbacks
  Function(int uid, bool muted)? onUserMuteAudio;
  Function(int uid)? onUserJoined;
  Function(int uid)? onUserLeft;
  Function(bool joined)? onJoinChannel;

  RtcEngine? get engine => _engine;
  bool get isJoined => _isJoined;
  ClientRoleType get userRole => _userRole;
  
  // Better role checking methods
  bool get isBroadcaster => _userRole == ClientRoleType.clientRoleBroadcaster;
  bool get isAudience => _userRole == ClientRoleType.clientRoleAudience;

  Future<void> initialize() async {
    try {
      // Request microphone permission
      await _requestPermissions();

      // Create RTC engine - equivalent to AgoraRTC.createClient()
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(appId: appId));

      // Set channel profile for live streaming (mode: "live")
      await _engine!.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);

      // Start as audience role
      await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
      
      // Enable audio
      await _engine!.enableAudio();

      // Set up event listeners - equivalent to client.on()
      _setupEventListeners();
      
      AppLogger().debug('🎙️ Agora engine initialized successfully');

    } catch (e) {
      AppLogger().error('Error initializing Agora: $e');
      rethrow;
    }
  }

  void _setupEventListeners() {
    AppLogger().debug('🎙️ Setting up Agora event listeners...');
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        AppLogger().info('Successfully joined channel: ${connection.channelId} with UID: ${connection.localUid}');
        _isJoined = true;
        onJoinChannel?.call(true);
        
        // Enable speakerphone after joining
        _enableSpeakerphone();
      },
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        AppLogger().debug('👋 Left channel: ${connection.channelId}');
        _isJoined = false;
        onJoinChannel?.call(false);
      },
      // Equivalent to client.on("user-published")
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        AppLogger().debug('🎙️ User joined voice channel: $remoteUid in ${connection.channelId}');
        onUserJoined?.call(remoteUid);
        
        // Auto-subscribe to remote user's audio - this is KEY for hearing sound!
        _subscribeToRemoteUser(remoteUid);
      },
      // Equivalent to client.on("user-unpublished")
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        AppLogger().debug('🎙️ User left voice channel: $remoteUid (Reason: $reason)');
        onUserLeft?.call(remoteUid);
      },
      onRemoteAudioStateChanged: (RtcConnection connection, int remoteUid, RemoteAudioState state, RemoteAudioStateReason reason, int elapsed) {
        bool muted = state == RemoteAudioState.remoteAudioStateStopped;
        AppLogger().debug('User $remoteUid audio state: ${muted ? 'muted' : 'unmuted'}');
        onUserMuteAudio?.call(remoteUid, muted);
      },
      onClientRoleChanged: (RtcConnection connection, ClientRoleType oldRole, ClientRoleType newRole, ClientRoleOptions? newRoleOptions) {
        AppLogger().debug('Role changed from $oldRole to $newRole');
        _userRole = newRole;
      },
      onError: (ErrorCodeType err, String msg) {
        AppLogger().error('Agora Error: $err - $msg');
      },
      onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
        AppLogger().debug('🔗 Connection state changed: $state (reason: $reason)');
      },
    ));
  }

  // Subscribe to remote user - equivalent to client.subscribe(user, "audio")
  Future<void> _subscribeToRemoteUser(int remoteUid) async {
    try {
      // This ensures we can hear the remote user's audio
      await _engine!.muteRemoteAudioStream(uid: remoteUid, mute: false);
      AppLogger().debug('Subscribed to remote user $remoteUid audio');
    } catch (e) {
      AppLogger().debug('Error subscribing to remote user $remoteUid: $e');
    }
  }

  Future<void> _enableSpeakerphone() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1000));
      await _engine!.setEnableSpeakerphone(true);
      AppLogger().debug('Speakerphone enabled');
    } catch (e) {
      AppLogger().debug('Error enabling speakerphone: $e');
    }
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.camera].request();
  }

  // Join channel - equivalent to client.join()
  Future<void> joinChannel() async {
    if (_engine == null) {
      throw Exception('Agora engine not initialized');
    }

    try {
      AppLogger().debug('🎙️ Attempting to join channel: $channelName');
      
      // Generate fresh token
      final token = await _tokenService.generateToken(
        channel: channelName,
        uid: 0,
        role: _userRole == ClientRoleType.clientRoleBroadcaster ? 'publisher' : 'subscriber',
      );
      
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: 0, // Let Agora assign UID
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          autoSubscribeAudio: true, // Auto-subscribe to remote audio
        ),
      );
      
      // Ensure audience members join with audio disabled
      if (_userRole == ClientRoleType.clientRoleAudience) {
        await _engine!.enableLocalAudio(false);
        AppLogger().debug('🔇 Audience member joined with audio disabled');
      }
      
      AppLogger().debug('🎙️ Join channel request sent successfully');
      
    } catch (e) {
      AppLogger().error('Error joining channel: $e');
      rethrow;
    }
  }

  Future<void> leaveChannel() async {
    if (_engine == null) return;

    try {
      await _engine!.leaveChannel();
      _isJoined = false;
    } catch (e) {
      AppLogger().debug('Error leaving channel: $e');
    }
  }

  // Switch to host role - equivalent to setClientRole("host") + publish
  Future<void> switchToSpeaker() async {
    if (_engine == null) return;

    try {
      AppLogger().debug('🎤 Switching to broadcaster (speaker) role...');
      
      // Check if we need a new token for publisher role
      if (_tokenService.isTokenExpiringSoon()) {
        AppLogger().debug('🔄 Token expiring soon, generating new publisher token...');
        final newToken = await _tokenService.generateToken(
          channel: channelName,
          uid: 0,
          role: 'publisher',
        );
        
        // Renew token
        await _engine!.renewToken(newToken);
        AppLogger().info('Token renewed for publisher role');
      }
      
      // Set role to broadcaster (host)
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      _userRole = ClientRoleType.clientRoleBroadcaster;
      
      // Enable microphone publishing - speakers can broadcast audio
      await _engine!.enableLocalAudio(true);
      
      AppLogger().info('Switched to broadcaster (speaker) - audio enabled, can now publish');
      
    } catch (e) {
      AppLogger().error('Error switching to broadcaster: $e');
    }
  }

  // Switch to audience role - equivalent to setClientRole("audience")
  Future<void> switchToAudience() async {
    if (_engine == null) return;

    try {
      AppLogger().debug('🎧 Switching to audience role...');
      
      // Disable microphone publishing first - audience cannot broadcast
      await _engine!.enableLocalAudio(false);
      
      // Set role to audience
      await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
      _userRole = ClientRoleType.clientRoleAudience;
      
      AppLogger().info('Switched to audience - audio disabled, can only listen');
      
    } catch (e) {
      AppLogger().error('Error switching to audience: $e');
    }
  }

  /// Manually refresh token if needed (useful for long sessions)
  Future<void> refreshTokenIfNeeded() async {
    if (_engine == null || !_isJoined) return;
    
    try {
      if (_tokenService.isTokenExpiringSoon()) {
        AppLogger().debug('🔄 Refreshing Agora token...');
        final newToken = await _tokenService.generateToken(
          channel: channelName,
          uid: 0,
          role: _userRole == ClientRoleType.clientRoleBroadcaster ? 'publisher' : 'subscriber',
        );
        
        await _engine!.renewToken(newToken);
        AppLogger().info('Agora token refreshed successfully');
      }
    } catch (e) {
      AppLogger().error('Error refreshing token: $e');
    }
  }

  Future<void> muteLocalAudio(bool muted) async {
    if (_engine == null) return;

    try {
      // Only allow muting/unmuting for broadcasters
      if (_userRole != ClientRoleType.clientRoleBroadcaster) {
        AppLogger().warning('Cannot mute/unmute: User is not a broadcaster (current role: $_userRole)');
        return;
      }
      
      // For broadcasters: muted=true should DISABLE audio, muted=false should ENABLE audio
      await _engine!.enableLocalAudio(!muted);
      AppLogger().debug('🎤 Broadcaster audio ${muted ? 'muted (disabled)' : 'unmuted (enabled)'}');
    } catch (e) {
      AppLogger().error('❌ Error ${muted ? 'muting' : 'unmuting'} local audio: $e');
    }
  }

  Future<void> setEnableSpeakerphone(bool enabled) async {
    if (_engine == null) return;

    try {
      await _engine!.setEnableSpeakerphone(enabled);
      AppLogger().debug('Speakerphone ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      AppLogger().error('Error ${enabled ? 'enabling' : 'disabling'} speakerphone: $e');
    }
  }

  // Screen sharing functionality
  Future<void> startScreenShare() async {
    if (_engine == null) return;

    try {
      AppLogger().debug('🖥️ Starting screen share...');
      
      // Enable video module for screen sharing
      await _engine!.enableVideo();
      
      // Start screen capture with proper parameters for mobile
      await _engine!.startScreenCapture(
        const ScreenCaptureParameters2(
          captureAudio: false, // Don't capture system audio to avoid conflicts
          captureVideo: true,  // Capture video for screen sharing
        ),
      );
      
      AppLogger().info('✅ Screen share started successfully');
    } catch (e) {
      AppLogger().error('❌ Error starting screen share: $e');
      rethrow;
    }
  }

  Future<void> stopScreenShare() async {
    if (_engine == null) return;

    try {
      AppLogger().debug('🛑 Stopping screen share...');
      
      // Stop screen capture
      await _engine!.stopScreenCapture();
      
      // Disable video module
      await _engine!.disableVideo();
      
      AppLogger().info('✅ Screen share stopped successfully');
    } catch (e) {
      AppLogger().error('❌ Error stopping screen share: $e');
      rethrow;
    }
  }

  // Check if screen sharing is supported
  bool get isScreenSharingSupported {
    // Screen sharing is supported on mobile platforms
    return true;
  }

  void dispose() {
    leaveChannel();
    _tokenService.clearCache(); // Clear token cache
    _engine?.release();
    _engine = null;
  }
} 