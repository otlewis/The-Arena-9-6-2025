import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SFUWebRTCService {
  // WebSocket connection to MediaSoup SFU server
  WebSocketChannel? _channel;
  bool _isConnected = false;
  String? _clientId;
  
  // Media streams
  MediaStream? _localStream;
  final Map<String, MediaStream> _remoteStreams = {};
  
  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(String peerId, MediaStream stream, String userId, String role)? onRemoteStream;
  Function(String peerId, String userId, String role)? onPeerJoined;
  Function(String peerId)? onPeerLeft;
  Function(String error)? onError;
  Function()? onConnected;
  Function()? onDisconnected;
  
  bool get isConnected => _isConnected;
  String? get clientId => _clientId;

  Future<void> connect(
    String serverUrl,
    String room,
    String userId, {
    bool audioOnly = false,
    String role = 'audience',
  }) async {
    try {
      debugPrint('🚀 SFU MediaSoup connect() called with:');
      debugPrint('   serverUrl: $serverUrl');
      debugPrint('   room: $room');
      debugPrint('   userId: $userId');
      debugPrint('   audioOnly: $audioOnly');
      debugPrint('   role: $role');
      
      
      // Connect to existing MediaSoup SFU server on port 3005
      final sfuServerUrl = serverUrl.contains(':3006') ? serverUrl.replaceAll(':3006', ':3005') : serverUrl;
      final wsUrl = sfuServerUrl.startsWith('http') 
          ? '${sfuServerUrl.replaceFirst('http', 'ws')}/socket.io/?EIO=4&transport=websocket'
          : 'ws://$sfuServerUrl/socket.io/?EIO=4&transport=websocket';
      
      debugPrint('🔌 Connecting to MediaSoup SFU WebSocket: $wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Listen for Socket.IO messages
      _channel!.stream.listen(
        (data) => _handleSocketIOMessage(data),
        onError: (error) {
          debugPrint('❌ MediaSoup SFU Socket.IO error: $error');
          onError?.call('MediaSoup SFU Socket.IO error: $error');
        },
        onDone: () {
          debugPrint('🔌 MediaSoup SFU Socket.IO connection closed');
          _isConnected = false;
          onDisconnected?.call();
        },
      );
      
      // Send Socket.IO handshake
      _sendSocketIOMessage('40'); // Engine.IO connect + Socket.IO connect
      
      // Wait for connection
      await _waitForConnection();
      
      // Set up local media
      await _setupLocalMedia(audioOnly: audioOnly);
      
      // Join MediaSoup SFU room
      _sendSocketIOMessage('42${jsonEncode([
        'join-room',
        {
          'roomId': room,
          'userId': userId,
          'role': role,
        }
      ])}');
      
      debugPrint('✅ MediaSoup SFU connection established');
      
    } catch (e) {
      debugPrint('❌ MediaSoup SFU connection failed: $e');
      onError?.call('MediaSoup SFU connection failed: $e');
      rethrow;
    }
  }
  
  Future<void> _waitForConnection() async {
    final startTime = DateTime.now();
    const timeout = Duration(seconds: 10);
    
    while (!_isConnected && DateTime.now().difference(startTime) < timeout) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    if (!_isConnected) {
      throw Exception('MediaSoup SFU connection timeout after ${timeout.inSeconds} seconds');
    }
    
    debugPrint('✅ MediaSoup SFU connection confirmed after ${DateTime.now().difference(startTime).inMilliseconds}ms');
  }
  
  Future<void> _setupLocalMedia({bool audioOnly = false}) async {
    try {
      debugPrint('🎥 Setting up local media for MediaSoup SFU (audioOnly: $audioOnly)');
      
      final constraints = {
        'audio': true,
        'video': audioOnly ? false : {
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
          'frameRate': {'ideal': 30},
          'facingMode': 'user',
        },
      };
      
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      
      debugPrint('📹 MediaSoup SFU local stream obtained');
      debugPrint('🎤 SFU Audio tracks: ${_localStream!.getAudioTracks().length}');
      debugPrint('🎥 SFU Video tracks: ${_localStream!.getVideoTracks().length}');
      
      onLocalStream?.call(_localStream!);
      
    } catch (e) {
      debugPrint('❌ Failed to get local media for MediaSoup SFU: $e');
      onError?.call('Failed to get local media for MediaSoup SFU: $e');
      rethrow;
    }
  }
  
  void _handleSocketIOMessage(dynamic data) {
    try {
      final message = data.toString();
      debugPrint('📨 Received MediaSoup SFU message: ${message.substring(0, message.length > 100 ? 100 : message.length)}...');
      
      if (message.startsWith('40')) {
        // Socket.IO connected
        _isConnected = true;
        debugPrint('✅ Socket.IO connected to MediaSoup SFU server');
        onConnected?.call();
        return;
      }
      
      if (message.startsWith('42')) {
        // Socket.IO event message
        final eventData = message.substring(2);
        final parsed = jsonDecode(eventData);
        final eventName = parsed[0];
        final payload = parsed.length > 1 ? parsed[1] : {};
        
        _handleSFUEvent(eventName, payload);
      }
      
    } catch (e) {
      debugPrint('❌ Error parsing MediaSoup SFU Socket.IO message: $e');
    }
  }
  
  void _handleSFUEvent(String event, Map<String, dynamic> data) {
    debugPrint('📨 MediaSoup SFU event: $event');
    
    switch (event) {
      case 'room-joined':
        _handleRoomJoined(data);
        break;
        
      case 'peer-joined':
        _handlePeerJoined(data);
        break;
        
      case 'peer-left':
        _handlePeerLeft(data);
        break;
        
      case 'newProducer':
        _handleNewProducer(data);
        break;
        
      case 'producerClosed':
        _handleProducerClosed(data);
        break;
        
      case 'consumerClosed':
        _handleConsumerClosed(data);
        break;
        
      case 'error':
        debugPrint('❌ MediaSoup SFU server error: ${data['message']}');
        onError?.call('MediaSoup SFU server error: ${data['message']}');
        break;
        
      default:
        debugPrint('❓ Unknown MediaSoup SFU event: $event');
    }
  }
  
  void _handleRoomJoined(Map<String, dynamic> data) {
    debugPrint('✅ Joined MediaSoup SFU room');
    debugPrint('📊 SFU capabilities received: ${data.keys}');
    
    // In a full MediaSoup implementation, we would:
    // 1. Get router RTP capabilities
    // 2. Create send/receive transports
    // 3. Start producing local media
    // 4. Consume existing producers
    
    // For now, just log successful room join
    debugPrint('🎬 MediaSoup SFU room joined successfully');
  }
  
  void _handlePeerJoined(Map<String, dynamic> data) {
    final peerId = data['peerId'];
    final userId = data['userId'];
    final role = data['role'];
    
    debugPrint('👤 MediaSoup SFU peer joined: $userId ($peerId) as $role');
    onPeerJoined?.call(peerId, userId, role);
  }
  
  void _handlePeerLeft(Map<String, dynamic> data) {
    final peerId = data['peerId'];
    
    debugPrint('👋 MediaSoup SFU peer left: $peerId');
    onPeerLeft?.call(peerId);
    
    // Clean up remote stream
    _remoteStreams.remove(peerId);
  }
  
  void _handleNewProducer(Map<String, dynamic> data) {
    debugPrint('🎬 New MediaSoup SFU producer available');
    // In a full implementation, we would create a consumer for this producer
    debugPrint('📊 Producer data: ${data.keys}');
  }
  
  void _handleProducerClosed(Map<String, dynamic> data) {
    final producerId = data['producerId'];
    debugPrint('🛑 MediaSoup SFU producer closed: $producerId');
  }
  
  void _handleConsumerClosed(Map<String, dynamic> data) {
    final consumerId = data['consumerId'];
    debugPrint('🛑 MediaSoup SFU consumer closed: $consumerId');
  }
  
  void _sendSocketIOMessage(String message) {
    if (_channel != null) {
      _channel!.sink.add(message);
      debugPrint('📤 Sent MediaSoup SFU Socket.IO: ${message.substring(0, message.length > 50 ? 50 : message.length)}...');
    } else {
      debugPrint('❌ Cannot send MediaSoup SFU Socket.IO message: WebSocket not connected');
    }
  }
  
  Future<void> disconnect() async {
    debugPrint('🔌 Disconnecting MediaSoup SFU WebRTC service');
    
    // Stop local media
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      await _localStream!.dispose();
      _localStream = null;
    }
    
    // Clear remote streams
    _remoteStreams.clear();
    
    // Close WebSocket
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }
    
    _isConnected = false;
    _clientId = null;
    
    onDisconnected?.call();
    debugPrint('✅ MediaSoup SFU WebRTC service disconnected');
  }
}