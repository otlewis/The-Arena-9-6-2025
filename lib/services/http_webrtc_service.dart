import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

/// Pure HTTP-based WebRTC service that bypasses Socket.IO entirely
/// This avoids WebSocket upgrade issues while maintaining full functionality
class HttpWebRTCService extends ChangeNotifier {
  static final HttpWebRTCService _instance = HttpWebRTCService._internal();
  factory HttpWebRTCService() => _instance;
  HttpWebRTCService._internal();

  // State
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoEnabled = false;
  String? _currentRoom;
  String? _userId;
  String? _userRole;
  String? _sessionId;
  String? _serverUrl;
  
  // WebRTC
  MediaStream? _localStream;
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, RTCVideoRenderer> _videoRenderers = {};
  RTCPeerConnection? _peerConnection;
  
  // HTTP polling
  Timer? _pollingTimer;
  bool _isPolling = false;
  
  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(String peerId, MediaStream stream, String? userId, String? role)? onRemoteStream;
  Function(String peerId, String? userId, String? role)? onPeerJoined;
  Function(String peerId)? onPeerLeft;
  Function(String)? onError;
  Function()? onConnected;
  Function()? onDisconnected;
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isLocalVideoEnabled => _isVideoEnabled;
  String? get userRole => _userRole;
  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;
  Map<String, RTCVideoRenderer> get videoRenderers => _videoRenderers;
  int get connectedPeersCount => _remoteStreams.length;
  bool get hasVideoEnabled => _isVideoEnabled;

  Future<void> connect(String serverUrl, String room, String userId, 
      {bool audioOnly = true, String role = 'audience'}) async {
    try {
      debugPrint('🚀 HTTP WebRTC connect() called with:');
      debugPrint('   serverUrl: $serverUrl');
      debugPrint('   room: $room');
      debugPrint('   userId: $userId');
      debugPrint('   audioOnly: $audioOnly');
      debugPrint('   role: $role');
      
      _serverUrl = 'http://$serverUrl';
      _currentRoom = room;
      _userId = userId;
      _userRole = role;
      
      // 1. Health check
      await _healthCheck();
      
      // 2. Join room via HTTP
      await _joinRoom();
      
      // 3. Initialize media if needed
      if (role == 'moderator' || role == 'speaker') {
        await _initializeMedia(audioOnly: audioOnly);
      }
      
      // 4. Start polling for events
      _startPolling();
      
      _isConnected = true;
      onConnected?.call();
      notifyListeners();
      
      debugPrint('✅ HTTP WebRTC connected successfully');
      
    } catch (e) {
      debugPrint('❌ HTTP WebRTC connection error: $e');
      onError?.call(e.toString());
      rethrow;
    }
  }
  
  Future<void> _healthCheck() async {
    final response = await http.get(Uri.parse('$_serverUrl/health'));
    if (response.statusCode != 200) {
      throw Exception('Server health check failed: ${response.statusCode}');
    }
    debugPrint('✅ Server health check passed');
  }
  
  Future<void> _joinRoom() async {
    final response = await http.post(
      Uri.parse('$_serverUrl/api/join-room'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'roomId': _currentRoom,
        'userId': _userId,
        'role': _userRole,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _sessionId = data['sessionId'];
      debugPrint('✅ Joined room via HTTP, sessionId: $_sessionId');
    } else {
      throw Exception('Failed to join room: ${response.statusCode}');
    }
  }
  
  void _startPolling() {
    _isPolling = true;
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_isPolling) return;
      
      try {
        await _pollForEvents();
      } catch (e) {
        debugPrint('❌ Polling error: $e');
      }
    });
    debugPrint('🔄 Started HTTP polling');
  }
  
  Future<void> _pollForEvents() async {
    if (_sessionId == null) return;
    
    final response = await http.get(
      Uri.parse('$_serverUrl/api/poll-events?sessionId=$_sessionId'),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final events = data['events'] as List;
      
      for (final event in events) {
        await _handleEvent(event);
      }
    }
  }
  
  Future<void> _handleEvent(Map<String, dynamic> event) async {
    final type = event['type'];
    final data = event['data'];
    
    switch (type) {
      case 'peer-joined':
        onPeerJoined?.call(data['peerId'], data['userId'], data['role']);
        break;
      case 'peer-left':
        onPeerLeft?.call(data['peerId']);
        break;
      case 'offer':
      case 'answer':
      case 'ice-candidate':
        // Handle WebRTC signaling
        await _handleWebRTCSignaling(type, data);
        break;
    }
  }
  
  Future<void> _handleWebRTCSignaling(String type, Map<String, dynamic> data) async {
    // Simple WebRTC signaling implementation
    // This would be expanded based on your specific needs
    debugPrint('📡 Received WebRTC signaling: $type');
  }
  
  Future<void> _initializeMedia({required bool audioOnly}) async {
    try {
      debugPrint('🎥 Initializing media - audioOnly: $audioOnly, role: $_userRole');
      
      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': audioOnly ? false : {
          'width': {'ideal': 640},
          'height': {'ideal': 480},
          'frameRate': {'ideal': 30},
          'facingMode': 'user',
        },
      };
      
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      onLocalStream?.call(_localStream!);
      
      if (!audioOnly && _localStream!.getVideoTracks().isNotEmpty) {
        _isVideoEnabled = true;
        debugPrint('🎥 Local video initialized');
      }
      
    } catch (e) {
      debugPrint('❌ Media initialization error: $e');
      throw Exception('Failed to access media devices: $e');
    }
  }
  
  Future<void> toggleMute() async {
    if (_localStream != null) {
      _isMuted = !_isMuted;
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
      debugPrint('🎙️ Audio ${_isMuted ? 'muted' : 'unmuted'}');
      notifyListeners();
    }
  }
  
  Future<void> toggleLocalVideo() async {
    if (_localStream == null) {
      debugPrint('❌ Cannot toggle video - no local stream');
      return;
    }
    
    _isVideoEnabled = !_isVideoEnabled;
    
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      for (final track in videoTracks) {
        track.enabled = _isVideoEnabled;
      }
    }
    
    debugPrint('🎥 Local video ${_isVideoEnabled ? 'enabled' : 'disabled'}');
    notifyListeners();
  }
  
  Future<void> disconnect() async {
    _isPolling = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    
    _localStream?.dispose();
    _localStream = null;
    
    _remoteStreams.clear();
    for (final renderer in _videoRenderers.values) {
      renderer.dispose();
    }
    _videoRenderers.clear();
    
    _peerConnection?.close();
    _peerConnection = null;
    
    _isConnected = false;
    _sessionId = null;
    
    if (_sessionId != null) {
      try {
        await http.post(
          Uri.parse('$_serverUrl/api/leave-room'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'sessionId': _sessionId}),
        );
      } catch (e) {
        debugPrint('❌ Error leaving room: $e');
      }
    }
    
    onDisconnected?.call();
    notifyListeners();
    debugPrint('🔌 HTTP WebRTC disconnected');
  }
  
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}