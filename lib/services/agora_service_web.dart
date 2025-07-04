import 'package:flutter/foundation.dart';
import '../core/logging/app_logger.dart';

// Web-compatible enums that mirror Agora types
enum ClientRoleType {
  clientRoleAudience,
  clientRoleBroadcaster,
}

class AgoraServiceImplementation {
  static final AgoraServiceImplementation _instance = AgoraServiceImplementation._internal();
  factory AgoraServiceImplementation() => _instance;
  AgoraServiceImplementation._internal();

  // Mock state
  bool _isJoined = false;
  ClientRoleType _userRole = ClientRoleType.clientRoleAudience;
  
  // Callbacks
  Function(int uid, bool muted)? onUserMuteAudio;
  Function(int uid)? onUserJoined;
  Function(int uid)? onUserLeft;
  Function(bool joined)? onJoinChannel;

  dynamic get engine => null; // Web doesn't have engine
  bool get isJoined => _isJoined;
  ClientRoleType get userRole => _userRole;
  
  // Helper getters for role checking
  bool get isBroadcaster => _userRole == ClientRoleType.clientRoleBroadcaster;
  bool get isAudience => _userRole == ClientRoleType.clientRoleAudience;

  Future<void> initialize() async {
    AppLogger().debug('🌐 Agora Web Stub: Initialize (no-op for web)');
    // Web implementation would use WebRTC here
  }

  Future<void> joinChannel() async {
    AppLogger().debug('🌐 Agora Web Stub: Join channel (simulated)');
    _isJoined = true;
    onJoinChannel?.call(true);
  }

  Future<void> leaveChannel() async {
    AppLogger().debug('🌐 Agora Web Stub: Leave channel (simulated)');
    _isJoined = false;
    onJoinChannel?.call(false);
  }

  Future<void> switchToSpeaker() async {
    AppLogger().debug('🌐 Agora Web Stub: Switch to speaker (simulated)');
    _userRole = ClientRoleType.clientRoleBroadcaster;
  }

  Future<void> switchToAudience() async {
    AppLogger().debug('🌐 Agora Web Stub: Switch to audience (simulated)');
    _userRole = ClientRoleType.clientRoleAudience;
  }

  Future<void> muteLocalAudio(bool muted) async {
    AppLogger().debug('Agora Web Stub: ${muted ? 'Mute' : 'Unmute'} local audio (simulated)');
  }

  Future<void> setEnableSpeakerphone(bool enabled) async {
    AppLogger().debug('Agora Web Stub: ${enabled ? 'Enable' : 'Disable'} speakerphone (simulated)');
  }

  // Screen sharing functionality (web implementation)
  Future<void> startScreenShare() async {
    AppLogger().debug('🖥️ Agora Web: Start screen share (simulated - would use getDisplayMedia)');
    // In a real web implementation, you would use:
    // navigator.mediaDevices.getDisplayMedia()
  }

  Future<void> stopScreenShare() async {
    AppLogger().debug('🛑 Agora Web: Stop screen share (simulated)');
  }

  bool get isScreenSharingSupported => kIsWeb; // Supported on web

  void dispose() {
    AppLogger().debug('🌐 Agora Web Stub: Dispose (no-op for web)');
    _isJoined = false;
  }
} 