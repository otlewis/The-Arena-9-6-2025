/// WebRTC Configuration for Arena App
class WebRTCConfig {
  // Server endpoints (using secure WebSocket - after SSL setup)
  static const String signalingUrl = 'ws://172.236.109.9:3006/signaling';
  static const String mediasoupUrl = 'ws://172.236.109.9:3005/mediasoup';
  
  // Current endpoints (without SSL - temporary)
  static const String signalingUrlInsecure = 'ws://172.236.109.9:3006/signaling';
  static const String mediasoupUrlInsecure = 'ws://172.236.109.9:3005/mediasoup';
  
  // ICE Servers
  static const List<Map<String, dynamic>> iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    {'urls': 'stun:stun3.l.google.com:19302'},
  ];
  
  // MediaSoup settings
  static const Map<String, dynamic> mediasoupSettings = {
    'audio': {
      'enabled': true,
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    },
    'video': {
      'enabled': true,
      'width': 640,
      'height': 480,
      'frameRate': 30,
    },
  };
  
  // Connection settings
  static const int connectionTimeout = 10000; // 10 seconds
  static const int reconnectInterval = 5000; // 5 seconds
  static const int maxReconnectAttempts = 3;
}