import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart';

/// HTTP-based MediaSoup service that bypasses Socket.IO upgrade issues
class HttpMediaSoupService extends ChangeNotifier {
  static final HttpMediaSoupService _instance = HttpMediaSoupService._internal();
  factory HttpMediaSoupService() => _instance;
  HttpMediaSoupService._internal();

  // HTTP client for direct communication
  final http.Client _httpClient = http.Client();
  Timer? _pollingTimer;
  
  // MediaSoup client objects
  Device? _device;
  Transport? _sendTransport;
  Transport? _recvTransport;
  final Map<String, Producer> _producers = {};
  final Map<String, Consumer> _consumers = {};
  
  // WebRTC media
  MediaStream? _localStream;
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, RTCVideoRenderer> _videoRenderers = {};
  
  // State
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoEnabled = false;
  bool _isDisposed = false;
  String? _currentRoom;
  String? _currentRoomType;
  String? _userRole;
  String? _userId;
  bool _canPublishMedia = false;
  String? _serverUrl;
  String? _sessionId;
  
  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(String peerId, MediaStream stream, String? userId, String? role)? onRemoteStream;
  Function(String peerId, String? userId, String? role)? onPeerJoined;
  Function(String peerId)? onPeerLeft;
  Function(String)? onError;
  Function()? onConnected;
  Function()? onDisconnected;
  Function(String userId, bool isSharing)? onRemoteScreenShareChanged;
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isLocalVideoEnabled => _isVideoEnabled;
  String? get userRole => _userRole;
  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;
  Map<String, RTCVideoRenderer> get videoRenderers => _videoRenderers;
  int get connectedPeersCount => _consumers.length;
  bool get hasVideoEnabled => _isVideoEnabled;
  bool get canPublishMedia => _canPublishMedia;
  
  /// Determine if role can publish media based on room type
  bool _shouldPublishMedia(String role, String roomType) {
    switch (roomType) {
      case 'arena':
        return role == 'debater' || role == 'judge' || role == 'moderator';
      case 'debate_discussion':
        return role == 'moderator' || role == 'speaker';
      case 'open_discussion':
        return role == 'moderator' || role == 'speaker';
      default:
        return role != 'audience';
    }
  }
  
  /// HTTP-based connect method
  Future<void> connect(
    String serverUrl, 
    String room, 
    String userId, {
    bool audioOnly = true, 
    String role = 'audience',
    String roomType = 'open_discussion',
  }) async {
    try {
      debugPrint('🚀 HTTP MediaSoup connect() called with:');
      debugPrint('   serverUrl: $serverUrl');
      debugPrint('   room: $room');
      debugPrint('   userId: $userId');
      debugPrint('   role: $role');
      debugPrint('   roomType: $roomType');
      debugPrint('   audioOnly: $audioOnly');
      
      _canPublishMedia = _shouldPublishMedia(role, roomType);
      debugPrint('   canPublishMedia: $_canPublishMedia');
      
      // Clean up existing connection
      if (_isConnected) {
        await _forceDisconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      _currentRoom = room;
      _currentRoomType = roomType;
      _userRole = role;
      _userId = userId;
      _serverUrl = serverUrl.startsWith('http') ? serverUrl : 'http://$serverUrl';
      
      // Step 1: HTTP handshake to establish session
      await _httpHandshake();
      
      // Step 2: Initialize MediaSoup device
      await _initializeDevice();
      
      // Step 3: Join room via HTTP
      await _joinRoomHttp();
      
      // Step 4: Initialize media if role can publish
      if (_canPublishMedia) {
        debugPrint('🎤 Role "$role" can publish media - initializing...');
        await _initializeMedia(audioOnly: audioOnly);
        await _createSendTransport();
        await _produceTracks();
      }
      
      // Step 5: Create receive transport
      await _createRecvTransport();
      
      // Step 6: Start HTTP polling for events
      _startHttpPolling();
      
      _isConnected = true;
      onConnected?.call();
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ HTTP MediaSoup connection error: $e');
      onError?.call(e.toString());
      rethrow;
    }
  }
  
  /// HTTP handshake to establish session
  Future<void> _httpHandshake() async {
    debugPrint('🤝 Starting HTTP handshake...');
    
    final response = await _httpClient.post(
      Uri.parse('$_serverUrl/handshake'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': _userId,
        'role': _userRole,
        'roomType': _currentRoomType,
        'canPublish': _canPublishMedia,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _sessionId = data['sessionId'];
      // Peer ID stored in session
      debugPrint('✅ HTTP handshake successful - Session: $_sessionId');
    } else {
      throw Exception('HTTP handshake failed: ${response.statusCode}');
    }
  }
  
  /// Join room via HTTP
  Future<void> _joinRoomHttp() async {
    debugPrint('🚪 Joining room via HTTP...');
    
    final response = await _httpClient.post(
      Uri.parse('$_serverUrl/join-room'),
      headers: {
        'Content-Type': 'application/json',
        'X-Session-ID': _sessionId ?? '',
      },
      body: jsonEncode({
        'roomId': _currentRoom,
        'userId': _userId,
        'role': _userRole,
        'roomType': _currentRoomType,
        'canPublish': _canPublishMedia,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      debugPrint('✅ Joined room via HTTP');
      
      // Notify about existing participants
      if (data['participants'] != null) {
        for (final participant in data['participants']) {
          onPeerJoined?.call(
            participant['peerId'], 
            participant['userId'], 
            participant['role']
          );
        }
      }
    } else {
      throw Exception('Room join failed: ${response.statusCode}');
    }
  }
  
  /// Start HTTP polling for real-time events
  void _startHttpPolling() {
    debugPrint('📡 Starting HTTP polling...');
    
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) async {
      if (_isDisposed || !_isConnected) return;
      
      try {
        final response = await _httpClient.get(
          Uri.parse('$_serverUrl/events'),
          headers: {'X-Session-ID': _sessionId ?? ''},
        );
        
        if (response.statusCode == 200) {
          final events = jsonDecode(response.body) as List;
          for (final event in events) {
            await _handleHttpEvent(event);
          }
        }
      } catch (e) {
        debugPrint('⚠️ HTTP polling error: $e');
      }
    });
  }
  
  /// Handle HTTP event
  Future<void> _handleHttpEvent(Map<String, dynamic> event) async {
    final eventType = event['type'];
    final data = event['data'];
    
    switch (eventType) {
      case 'peer-joined':
        onPeerJoined?.call(data['peerId'], data['userId'], data['role']);
        break;
        
      case 'peer-left':
        _cleanupPeer(data['peerId']);
        onPeerLeft?.call(data['peerId']);
        break;
        
      case 'newProducer':
        await _consumeProducerHttp(data);
        break;
        
      case 'producerClosed':
        _handleProducerClosed(data);
        break;
        
      default:
        debugPrint('📥 Unknown HTTP event: $eventType');
    }
  }
  
  /// HTTP-based RPC request
  Future<Map<String, dynamic>> _httpRpcRequest(String method, Map<String, dynamic> params) async {
    final response = await _httpClient.post(
      Uri.parse('$_serverUrl/rpc'),
      headers: {
        'Content-Type': 'application/json',
        'X-Session-ID': _sessionId ?? '',
      },
      body: jsonEncode({
        'method': method,
        'params': params,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['error'] != null) {
        throw Exception(data['error']);
      }
      return data;
    } else {
      throw Exception('HTTP RPC failed: ${response.statusCode}');
    }
  }
  
  /// Initialize MediaSoup device via HTTP
  Future<void> _initializeDevice() async {
    debugPrint('📱 Initializing MediaSoup device via HTTP...');
    _device = Device();
    
    final response = await _httpRpcRequest('getRouterRtpCapabilities', {
      'roomId': _currentRoom,
    });
    
    await _device!.load(routerRtpCapabilities: response['rtpCapabilities']);
    debugPrint('✅ MediaSoup device loaded via HTTP');
  }
  
  /// Create send transport via HTTP
  Future<void> _createSendTransport() async {
    if (!_canPublishMedia) return;
    
    debugPrint('📤 Creating send transport via HTTP...');
    
    final response = await _httpRpcRequest('createWebRtcTransport', {
      'roomId': _currentRoom,
      'direction': 'send',
    });
    
    _sendTransport = _device!.createSendTransport(
      id: response['id'],
      iceParameters: response['iceParameters'],
      iceCandidates: response['iceCandidates'],
      dtlsParameters: response['dtlsParameters'],
    );
    
    _sendTransport!.on('connect', (data) async {
      await _httpRpcRequest('connectWebRtcTransport', {
        'transportId': _sendTransport!.id,
        'dtlsParameters': data['dtlsParameters'],
      });
      data['callback']();
    });
    
    _sendTransport!.on('produce', (data) async {
      try {
        final response = await _httpRpcRequest('produce', {
          'roomId': _currentRoom,
          'transportId': _sendTransport!.id,
          'kind': data['kind'],
          'rtpParameters': data['rtpParameters'],
          'appData': {
            ...data['appData'],
            'userId': _userId,
            'role': _userRole,
          },
        });
        data['callback']({'id': response['producerId']});
      } catch (e) {
        data['errback'](e);
      }
    });
    
    debugPrint('✅ Send transport created via HTTP');
  }
  
  /// Create receive transport via HTTP
  Future<void> _createRecvTransport() async {
    debugPrint('📥 Creating receive transport via HTTP...');
    
    final response = await _httpRpcRequest('createWebRtcTransport', {
      'roomId': _currentRoom,
      'direction': 'recv',
    });
    
    _recvTransport = _device!.createRecvTransport(
      id: response['id'],
      iceParameters: response['iceParameters'],
      iceCandidates: response['iceCandidates'],
      dtlsParameters: response['dtlsParameters'],
    );
    
    _recvTransport!.on('connect', (data) async {
      await _httpRpcRequest('connectWebRtcTransport', {
        'transportId': _recvTransport!.id,
        'dtlsParameters': data['dtlsParameters'],
      });
      data['callback']();
    });
    
    debugPrint('✅ Receive transport created via HTTP');
    
    // Request existing producers
    await _httpRpcRequest('getExistingProducers', {'roomId': _currentRoom});
  }
  
  /// Initialize media
  Future<void> _initializeMedia({required bool audioOnly}) async {
    if (!_canPublishMedia) return;
    
    try {
      debugPrint('🎥 Initializing media via HTTP...');
      
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
      }
      
      debugPrint('✅ Media initialized via HTTP');
      
    } catch (e) {
      debugPrint('❌ Media initialization error: $e');
      if (_userRole != 'audience') {
        throw Exception('Failed to access media devices: $e');
      }
    }
  }
  
  /// Produce tracks via HTTP signaling
  Future<void> _produceTracks() async {
    if (!_canPublishMedia || _localStream == null || _sendTransport == null) {
      return;
    }
    
    try {
      debugPrint('🎤 Producing tracks via HTTP...');
      
      // Produce audio
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        debugPrint('🎤 Would produce audio track via HTTP (API compatibility check needed)');
      }
      
      // Produce video if enabled
      if (_isVideoEnabled) {
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          debugPrint('🎥 Would produce video track via HTTP (API compatibility check needed)');
        }
      }
      
    } catch (e) {
      debugPrint('❌ Track production error: $e');
    }
  }
  
  /// Consume producer via HTTP
  Future<void> _consumeProducerHttp(Map<String, dynamic> data) async {
    // Implementation similar to original but using HTTP for signaling
    debugPrint('🎧 Consuming producer via HTTP: ${data['producerId']}');
  }
  
  /// Handle producer closed
  void _handleProducerClosed(Map<String, dynamic> data) {
    debugPrint('🛑 Producer closed via HTTP: ${data['producerId']}');
    // Implementation for cleanup
  }
  
  /// Clean up peer
  void _cleanupPeer(String peerId) {
    _remoteStreams.remove(peerId)?.dispose();
    _videoRenderers.remove(peerId)?.dispose();
    notifyListeners();
  }
  
  /// Toggle mute
  Future<void> toggleMute() async {
    if (_localStream != null) {
      _isMuted = !_isMuted;
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
      
      // Notify server via HTTP
      try {
        await _httpClient.post(
          Uri.parse('$_serverUrl/mute-state'),
          headers: {
            'Content-Type': 'application/json',
            'X-Session-ID': _sessionId ?? '',
          },
          body: jsonEncode({
            'roomId': _currentRoom,
            'userId': _userId,
            'isMuted': _isMuted,
          }),
        );
      } catch (e) {
        debugPrint('⚠️ Failed to sync mute state: $e');
      }
      
      notifyListeners();
    }
  }
  
  /// Toggle video
  Future<void> toggleLocalVideo() async {
    if (_localStream != null && _canPublishMedia) {
      _isVideoEnabled = !_isVideoEnabled;
      
      final videoTracks = _localStream!.getVideoTracks();
      for (final track in videoTracks) {
        track.enabled = _isVideoEnabled;
      }
      
      debugPrint('🎥 Local video ${_isVideoEnabled ? 'enabled' : 'disabled'}');
      notifyListeners();
    }
  }
  
  /// Start screen share
  Future<void> startScreenShare() async {
    if (!_canPublishMedia) return;
    
    try {
      debugPrint('🖥️ Starting screen share via HTTP...');
      
      await navigator.mediaDevices.getDisplayMedia({
        'video': {
          'width': {'ideal': 1920},
          'height': {'ideal': 1080},
          'frameRate': {'ideal': 30},
        },
        'audio': false,
      });
      
      // Notify server via HTTP
      await _httpClient.post(
        Uri.parse('$_serverUrl/screen-share-start'),
        headers: {
          'Content-Type': 'application/json',
          'X-Session-ID': _sessionId ?? '',
        },
        body: jsonEncode({
          'roomId': _currentRoom,
          'userId': _userId,
        }),
      );
      
      debugPrint('✅ Screen share started via HTTP');
      
    } catch (e) {
      debugPrint('❌ Screen share error: $e');
      onError?.call('Failed to start screen share: $e');
    }
  }
  
  /// Stop screen share
  Future<void> stopScreenShare() async {
    try {
      debugPrint('🛑 Stopping screen share via HTTP...');
      
      await _httpClient.post(
        Uri.parse('$_serverUrl/screen-share-stop'),
        headers: {
          'Content-Type': 'application/json',
          'X-Session-ID': _sessionId ?? '',
        },
        body: jsonEncode({
          'roomId': _currentRoom,
          'userId': _userId,
        }),
      );
      
      debugPrint('✅ Screen share stopped via HTTP');
      
    } catch (e) {
      debugPrint('❌ Stop screen share error: $e');
    }
  }
  
  /// Force disconnect
  Future<void> _forceDisconnect() async {
    if (_isDisposed) return;
    
    _pollingTimer?.cancel();
    
    try {
      if (_sessionId != null) {
        await _httpClient.post(
          Uri.parse('$_serverUrl/leave-room'),
          headers: {
            'Content-Type': 'application/json',
            'X-Session-ID': _sessionId ?? '',
          },
          body: jsonEncode({'roomId': _currentRoom}),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error during disconnect: $e');
    }
    
    // Clean up MediaSoup objects
    for (final producer in _producers.values) {
      producer.close();
    }
    _producers.clear();
    
    for (final consumer in _consumers.values) {
      consumer.close();
    }
    _consumers.clear();
    
    _sendTransport?.close();
    _recvTransport?.close();
    _sendTransport = null;
    _recvTransport = null;
    
    // Clean up media
    _localStream?.dispose();
    _localStream = null;
    _remoteStreams.clear();
    for (final renderer in _videoRenderers.values) {
      renderer.dispose();
    }
    _videoRenderers.clear();
    
    // Reset state
    _currentRoom = null;
    _currentRoomType = null;
    _userRole = null;
    _userId = null;
    // Peer ID reset
    _sessionId = null;
    _isConnected = false;
    _isMuted = false;
    _isVideoEnabled = false;
    _canPublishMedia = false;
    
    onDisconnected?.call();
  }
  
  /// Disconnect
  Future<void> disconnect() async {
    if (_isDisposed) return;
    await _forceDisconnect();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    disconnect();
    _httpClient.close();
    super.dispose();
  }
}