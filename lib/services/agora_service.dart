// Platform-conditional imports
import 'agora_service_stub.dart'
    if (dart.library.io) 'agora_service_mobile.dart'
    if (dart.library.html) 'agora_service_web.dart' as agora_impl;

class AgoraService {
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  // Delegate to platform-specific implementation
  late final agora_impl.AgoraServiceImplementation _impl = agora_impl.AgoraServiceImplementation();

  // Static constants for ClientRoleType to avoid platform-conditional imports
  static const String clientRoleAudience = 'audience';
  static const String clientRoleBroadcaster = 'broadcaster';

  // Forward all calls to the implementation
  dynamic get engine => _impl.engine;
  bool get isJoined => _impl.isJoined;
  dynamic get userRole => _impl.userRole;
  
  // Helper method to check if user is broadcaster
  bool get isBroadcaster => _impl.isBroadcaster;
  
  // Helper method to check if user is audience  
  bool get isAudience => _impl.isAudience;

  set onUserMuteAudio(Function(int uid, bool muted)? callback) => _impl.onUserMuteAudio = callback;
  set onUserJoined(Function(int uid)? callback) => _impl.onUserJoined = callback;
  set onUserLeft(Function(int uid)? callback) => _impl.onUserLeft = callback;
  set onJoinChannel(Function(bool joined)? callback) => _impl.onJoinChannel = callback;

  Future<void> initialize() => _impl.initialize();
  Future<void> joinChannel() => _impl.joinChannel();
  Future<void> leaveChannel() => _impl.leaveChannel();
  Future<void> switchToSpeaker() => _impl.switchToSpeaker();
  Future<void> switchToAudience() => _impl.switchToAudience();
  Future<void> muteLocalAudio(bool muted) => _impl.muteLocalAudio(muted);
  Future<void> setEnableSpeakerphone(bool enabled) => _impl.setEnableSpeakerphone(enabled);
  
  // Screen sharing functionality
  Future<void> startScreenShare() => _impl.startScreenShare();
  Future<void> stopScreenShare() => _impl.stopScreenShare();
  bool get isScreenSharingSupported => _impl.isScreenSharingSupported;
  
  void dispose() => _impl.dispose();
} 