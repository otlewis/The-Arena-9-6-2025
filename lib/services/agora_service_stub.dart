import '../core/logging/app_logger.dart';

// Fallback stub implementation
enum ClientRoleType {
  clientRoleAudience,
  clientRoleBroadcaster,
}

class AgoraServiceImplementation {
  static final AgoraServiceImplementation _instance = AgoraServiceImplementation._internal();
  factory AgoraServiceImplementation() => _instance;
  AgoraServiceImplementation._internal();

  bool _isJoined = false;
  ClientRoleType _userRole = ClientRoleType.clientRoleAudience;
  
  Function(int uid, bool muted)? onUserMuteAudio;
  Function(int uid)? onUserJoined;
  Function(int uid)? onUserLeft;
  Function(bool joined)? onJoinChannel;

  dynamic get engine => null;
  bool get isJoined => _isJoined;
  ClientRoleType get userRole => _userRole;
  
  // Helper getters for role checking
  bool get isBroadcaster => _userRole == ClientRoleType.clientRoleBroadcaster;
  bool get isAudience => _userRole == ClientRoleType.clientRoleAudience;

  Future<void> initialize() async {
    AppLogger().debug('📱 Agora Stub: Initialize (no-op)');
  }

  Future<void> joinChannel() async {
    AppLogger().debug('📱 Agora Stub: Join channel (simulated)');
    _isJoined = true;
    onJoinChannel?.call(true);
  }

  Future<void> leaveChannel() async {
    AppLogger().debug('📱 Agora Stub: Leave channel (simulated)');
    _isJoined = false;
    onJoinChannel?.call(false);
  }

  Future<void> switchToSpeaker() async {
    AppLogger().debug('📱 Agora Stub: Switch to speaker (simulated)');
    _userRole = ClientRoleType.clientRoleBroadcaster;
  }

  Future<void> switchToAudience() async {
    AppLogger().debug('📱 Agora Stub: Switch to audience (simulated)');
    _userRole = ClientRoleType.clientRoleAudience;
  }

  Future<void> muteLocalAudio(bool muted) async {
    AppLogger().debug('Agora Stub: ${muted ? 'Mute' : 'Unmute'} local audio (simulated)');
  }

  Future<void> setEnableSpeakerphone(bool enabled) async {
    AppLogger().debug('Agora Stub: ${enabled ? 'Enable' : 'Disable'} speakerphone (simulated)');
  }

  // Screen sharing functionality (stub implementation)
  Future<void> startScreenShare() async {
    AppLogger().debug('🖥️ Agora Stub: Start screen share (simulated)');
  }

  Future<void> stopScreenShare() async {
    AppLogger().debug('🛑 Agora Stub: Stop screen share (simulated)');
  }

  bool get isScreenSharingSupported => false; // Not supported in stub

  void dispose() {
    AppLogger().debug('📱 Agora Stub: Dispose (no-op)');
    _isJoined = false;
  }
} 