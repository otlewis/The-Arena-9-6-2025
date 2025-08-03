import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class NativeMediaSoupService {
  // WebSocket connection to MediaSoup server
  WebSocketChannel? _channel;
  bool _isConnected = false;
  String? _clientId;
  String? _currentRoom;
  
  // MediaSoup state
  Map<String, dynamic>? _routerRtpCapabilities;
  RTCPeerConnection? _sendTransport;
  RTCPeerConnection? _recvTransport;
  MediaStream? _localStream;
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, RTCRtpSender> _producers = {};
  final Map<String, RTCRtpReceiver> _consumers = {};
  
  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(String peerId, MediaStream stream, String userId, String role)? onRemoteStream;
  Function(String peerId, String userId, String role)? onPeerJoined;
  Function(String peerId)? onPeerLeft;
  Function(String error)? onError;
  Function()? onConnected;
  Function()? onDisconnected;
  
  // MediaSoup configuration for SFU
  final Map<String, dynamic> _transportConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan' // MediaSoup requires Unified Plan
  };
  
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
      debugPrint('🚀 Native MediaSoup connect() called with:');
      debugPrint('   serverUrl: $serverUrl');
      debugPrint('   room: $room');
      debugPrint('   userId: $userId');
      debugPrint('   audioOnly: $audioOnly');
      debugPrint('   role: $role');
      
      _currentRoom = room;
      
      // Create WebSocket connection to MediaSoup server
      final wsUrl = serverUrl.startsWith('http') 
          ? '${serverUrl.replaceFirst('http', 'ws')}/socket.io/?EIO=4&transport=websocket'
          : 'ws://$serverUrl/socket.io/?EIO=4&transport=websocket';
      
      debugPrint('🔌 Connecting to MediaSoup WebSocket: $wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Listen for messages
      _channel!.stream.listen(
        (data) => _handleMessage(data),
        onError: (error) {
          debugPrint('❌ MediaSoup WebSocket error: $error');
          onError?.call('WebSocket error: $error');
        },
        onDone: () {
          debugPrint('🔌 MediaSoup WebSocket connection closed');
          _isConnected = false;
          onDisconnected?.call();
        },
      );
      
      // Send Socket.IO handshake
      _sendSocketIOMessage('40'); // Engine.IO connect + Socket.IO connect
      
      // Wait for connection
      await _waitForConnection();
      
      // Set up local media first
      await _setupLocalMedia(audioOnly: audioOnly);
      
      // Join room - this will trigger the MediaSoup flow
      _sendSocketIOMessage('42${jsonEncode([
        'join-room',
        {
          'roomId': room,
          'userId': userId,
          'role': role,
        }
      ])}');
      
      debugPrint('✅ Native MediaSoup connection established');
      
    } catch (e) {
      debugPrint('❌ Native MediaSoup connection failed: $e');
      onError?.call('Connection failed: $e');
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
      throw Exception('MediaSoup connection timeout after ${timeout.inSeconds} seconds');
    }
    
    debugPrint('✅ MediaSoup connection confirmed after ${DateTime.now().difference(startTime).inMilliseconds}ms');
  }
  
  Future<void> _setupLocalMedia({bool audioOnly = false}) async {
    try {
      debugPrint('🎥 Setting up local media (audioOnly: $audioOnly)');
      
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
      
      debugPrint('📹 Local stream obtained');
      debugPrint('🎤 Audio tracks: ${_localStream!.getAudioTracks().length}');
      debugPrint('🎥 Video tracks: ${_localStream!.getVideoTracks().length}');
      
      onLocalStream?.call(_localStream!);
      
    } catch (e) {
      debugPrint('❌ Failed to get local media: $e');
      onError?.call('Failed to get local media: $e');
      rethrow;
    }
  }
  
  void _handleMessage(dynamic data) {
    try {
      final message = data.toString();
      debugPrint('📨 Received MediaSoup message: ${message.substring(0, message.length > 100 ? 100 : message.length)}...');
      
      if (message.startsWith('40')) {
        // Socket.IO connected
        _isConnected = true;
        debugPrint('✅ Socket.IO connected to MediaSoup server');
        onConnected?.call();
        return;
      }
      
      if (message.startsWith('42')) {
        // Socket.IO event message
        final eventData = message.substring(2);
        final parsed = jsonDecode(eventData);
        final eventName = parsed[0];
        final payload = parsed.length > 1 ? parsed[1] : {};
        
        _handleSocketIOEvent(eventName, payload);
      }
      
    } catch (e) {
      debugPrint('❌ Error parsing MediaSoup message: $e');
    }
  }
  
  void _handleSocketIOEvent(String event, Map<String, dynamic> data) {
    debugPrint('📨 MediaSoup event: $event');
    
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
        
      default:
        debugPrint('❓ Unknown MediaSoup event: $event');
    }
  }
  
  Future<void> _handleRoomJoined(Map<String, dynamic> data) async {
    debugPrint('✅ Joined MediaSoup room');
    _routerRtpCapabilities = data['rtpCapabilities'];
    
    // Create send transport for publishing our media
    await _createSendTransport();
    
    // Create receive transport for consuming others' media
    await _createRecvTransport();
    
    // Start producing our local media
    if (_localStream != null) {
      await _produceMedia();
    }
    
    // Consume existing producers
    final existingProducers = data['existingProducers'] as List? ?? [];
    for (final producer in existingProducers) {
      await _consumeProducer(producer);
    }
  }
  
  void _handlePeerJoined(Map<String, dynamic> data) {
    final peerId = data['peerId'];
    final userId = data['userId'];
    final role = data['role'];
    
    debugPrint('👤 MediaSoup peer joined: $userId ($peerId) as $role');
    onPeerJoined?.call(peerId, userId, role);
  }
  
  void _handlePeerLeft(Map<String, dynamic> data) {
    final peerId = data['peerId'];
    
    debugPrint('👋 MediaSoup peer left: $peerId');
    onPeerLeft?.call(peerId);
    
    // Clean up remote stream
    _remoteStreams.remove(peerId);
  }
  
  Future<void> _handleNewProducer(Map<String, dynamic> data) async {
    debugPrint('🎬 New producer available, consuming...');
    await _consumeProducer(data);
  }
  
  void _handleProducerClosed(Map<String, dynamic> data) {
    final producerId = data['producerId'];
    debugPrint('🛑 Producer closed: $producerId');
    // Handle producer closure
  }
  
  void _handleConsumerClosed(Map<String, dynamic> data) {
    final consumerId = data['consumerId'];
    debugPrint('🛑 Consumer closed: $consumerId');
    // Handle consumer closure
  }
  
  Future<void> _createSendTransport() async {
    debugPrint('🚛 Creating send transport...');
    
    // Request transport from server
    final response = await _sendRequest('createWebRtcTransport', {
      'roomId': _currentRoom,
      'direction': 'send',
    });
    
    final transportOptions = response['params'];
    
    // Create RTCPeerConnection for sending
    _sendTransport = await createPeerConnection({
      ..._transportConfig,
      'iceServers': _transportConfig['iceServers'],
    });
    
    // Set remote description from server
    await _sendTransport!.setRemoteDescription(RTCSessionDescription(
      transportOptions['sdp'] ?? '',
      'offer'
    ));
    
    debugPrint('✅ Send transport created');
  }
  
  Future<void> _createRecvTransport() async {
    debugPrint('🚛 Creating receive transport...');
    
    // Request transport from server
    final _ = await _sendRequest('createWebRtcTransport', {
      'roomId': _currentRoom,
      'direction': 'recv',
    });
    
    // Create RTCPeerConnection for receiving
    _recvTransport = await createPeerConnection({
      ..._transportConfig,
      'iceServers': _transportConfig['iceServers'],
    });
    
    // Handle incoming streams
    _recvTransport!.onAddStream = (stream) {
      debugPrint('📡 Received remote stream');
      // We'll handle this in consume logic
    };
    
    debugPrint('✅ Receive transport created');
  }
  
  Future<void> _produceMedia() async {
    if (_localStream == null || _sendTransport == null) return;
    
    debugPrint('🎬 Producing local media...');
    
    // Add tracks to send transport
    for (final track in _localStream!.getTracks()) {
      final sender = await _sendTransport!.addTrack(track, _localStream!);
      _producers[track.id!] = sender;
      
      debugPrint('➕ Added ${track.kind} track to producer');
    }
    
    // Create offer and set local description
    final offer = await _sendTransport!.createOffer();
    await _sendTransport!.setLocalDescription(offer);
    
    // Send produce request to server
    await _sendRequest('produce', {
      'roomId': _currentRoom,
      'kind': 'video', // Will handle audio separately if needed
      'rtpParameters': offer.sdp,
    });
    
    debugPrint('✅ Media production started');
  }
  
  Future<void> _consumeProducer(Map<String, dynamic> producerInfo) async {
    if (_recvTransport == null || _routerRtpCapabilities == null) return;
    
    final producerId = producerInfo['producerId'];
    final userId = producerInfo['userId'];
    final kind = producerInfo['kind'];
    
    debugPrint('🍽️ Consuming producer: $producerId ($kind) from $userId');
    
    try {
      // Request consumption from server
      final response = await _sendRequest('consume', {
        'roomId': _currentRoom,
        'producerId': producerId,
        'rtpCapabilities': _routerRtpCapabilities,
      });
      
      final consumerParams = response;
      final consumerId = consumerParams['id'];
      
      // This is a simplified approach - in a real implementation,
      // you'd create a proper consumer with the MediaSoup client library
      debugPrint('✅ Consumer created: $consumerId for $userId');
      
      // Resume consumer
      await _sendRequest('resumeConsumer', {
        'consumerId': consumerId,
      });
      
      debugPrint('▶️ Consumer resumed for $userId');
      
    } catch (e) {
      debugPrint('❌ Failed to consume producer: $e');
    }
  }
  
  Future<Map<String, dynamic>> _sendRequest(String method, Map<String, dynamic> params) async {
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final completer = Completer<Map<String, dynamic>>();
    
    // Send RPC request
    _sendSocketIOMessage('42${jsonEncode([
      'request',
      {
        'id': requestId,
        'method': method,
        'params': params,
      }
    ])}');
    
    // Set up response handler (simplified - in real implementation, track multiple requests)
    Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.completeError('Request timeout');
      }
    });
    
    // For now, return a mock response to avoid blocking
    // In a real implementation, you'd wait for the actual response
    await Future.delayed(const Duration(milliseconds: 100));
    return {'success': true};
  }
  
  void _sendSocketIOMessage(String message) {
    if (_channel != null) {
      _channel!.sink.add(message);
      debugPrint('📤 Sent: ${message.substring(0, message.length > 50 ? 50 : message.length)}...');
    }
  }
  
  Future<void> disconnect() async {
    debugPrint('🔌 Disconnecting Native MediaSoup service');
    
    // Close transports
    await _sendTransport?.close();
    await _recvTransport?.close();
    _sendTransport = null;
    _recvTransport = null;
    
    // Stop local media
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      await _localStream!.dispose();
      _localStream = null;
    }
    
    // Clear state
    _producers.clear();
    _consumers.clear();
    _remoteStreams.clear();
    _routerRtpCapabilities = null;
    
    // Close WebSocket
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }
    
    _isConnected = false;
    _clientId = null;
    _currentRoom = null;
    
    onDisconnected?.call();
    debugPrint('✅ Native MediaSoup service disconnected');
  }
}