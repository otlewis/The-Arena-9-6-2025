import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart';

/// Proper MediaSoup SFU service using the official mediasfu_mediasoup_client
class MediaSoupSFUService extends ChangeNotifier {
  static final MediaSoupSFUService _instance = MediaSoupSFUService._internal();
  factory MediaSoupSFUService() => _instance;
  MediaSoupSFUService._internal();

  // Socket.IO connection
  io.Socket? _socket;
  
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
  String? _userRole;
  String? _myPeerId;
  
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
  int get connectedPeersCount => _consumers.length;
  bool get hasVideoEnabled => _isVideoEnabled;
  
  Future<void> connect(String serverUrl, String room, String userId, 
      {bool audioOnly = true, String role = 'audience', bool sfuMode = true}) async {
    try {
      debugPrint('🚀 MediaSoup SFU connect() called with:');
      debugPrint('   serverUrl: $serverUrl');
      debugPrint('   room: $room');
      debugPrint('   userId: $userId');
      debugPrint('   audioOnly: $audioOnly');
      debugPrint('   role: $role');
      debugPrint('   sfuMode: $sfuMode (MediaSoup SFU)');
      
      // Check if already connected
      if (_isConnected && _socket != null && _socket!.connected && _currentRoom == room) {
        debugPrint('⚠️ Already connected to room: $room');
        return;
      }
      
      // Clean up if switching rooms
      if (_socket != null) {
        debugPrint('🧹 Cleaning up existing connection');
        await _forceDisconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      _currentRoom = room;
      _userRole = role;
      
      // Connect to server
      final serverUri = 'http://$serverUrl';
      debugPrint('🔌 Connecting to: $serverUri');
      
      _socket = io.io(serverUri, <String, dynamic>{
        'transports': ['polling'], // Force polling only
        'autoConnect': false,
        'timeout': 20000,
        'forceNew': true,
      });
      
      _setupSocketListeners();
      
      debugPrint('🔌 Attempting socket connection...');
      _socket!.connect();
      
      // Wait for connection
      await _waitForConnection();
      
      // Initialize MediaSoup device
      await _initializeDevice();
      
      // Join room
      await _joinRoom(room, userId, role);
      
      // Initialize media if needed
      if (role == 'moderator' || role == 'speaker') {
        await _initializeMedia(audioOnly: audioOnly);
        await _createSendTransport();
        await _produceTracks();
      }
      
      // Create receive transport for consuming other participants
      await _createRecvTransport();
      
      _isConnected = true;
      onConnected?.call();
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ MediaSoup connection error: $e');
      onError?.call(e.toString());
      rethrow;
    }
  }
  
  Future<void> _initializeDevice() async {
    try {
      debugPrint('📱 Initializing MediaSoup device...');
      _device = Device();
      
      // Get router RTP capabilities from server
      final response = await _rpcRequest('getRouterRtpCapabilities', {'roomId': _currentRoom});
      final rtpCapabilities = response['rtpCapabilities'];
      
      // Load device with router capabilities
      await _device!.load(routerRtpCapabilities: rtpCapabilities);
      debugPrint('✅ MediaSoup device loaded');
      
    } catch (e) {
      debugPrint('❌ Device initialization error: $e');
      rethrow;
    }
  }
  
  Future<void> _joinRoom(String room, String userId, String role) async {
    try {
      debugPrint('🚪 Joining MediaSoup room: $room');
      
      final completer = Completer<void>();
      _socket!.once('room-joined', (data) {
        debugPrint('📥 Room joined: $data');
        _myPeerId = data['myPeerId'] ?? _socket!.id;
        completer.complete();
      });
      
      _socket!.emit('join-room', {
        'roomId': room,
        'userId': userId,
        'role': role,
      });
      
      await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Failed to join room'),
      );
      
    } catch (e) {
      debugPrint('❌ Room join error: $e');
      rethrow;
    }
  }
  
  Future<void> _createSendTransport() async {
    try {
      debugPrint('📤 Creating send transport...');
      
      final response = await _rpcRequest('createWebRtcTransport', {
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
        debugPrint('🔗 Send transport connecting...');
        await _rpcRequest('connectWebRtcTransport', {
          'transportId': _sendTransport!.id,
          'dtlsParameters': data['dtlsParameters'],
        });
        data['callback']();
      });
      
      _sendTransport!.on('produce', (data) async {
        debugPrint('🎬 Producing track: ${data['kind']}');
        try {
          final response = await _rpcRequest('produce', {
            'roomId': _currentRoom,
            'transportId': _sendTransport!.id,
            'kind': data['kind'],
            'rtpParameters': data['rtpParameters'],
            'appData': data['appData'],
          });
          data['callback']({'id': response['producerId']});
        } catch (e) {
          data['errback'](e);
        }
      });
      
      debugPrint('✅ Send transport created');
      
    } catch (e) {
      debugPrint('❌ Send transport creation error: $e');
      rethrow;
    }
  }
  
  Future<void> _createRecvTransport() async {
    try {
      debugPrint('📥 Creating receive transport...');
      
      final response = await _rpcRequest('createWebRtcTransport', {
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
        debugPrint('🔗 Receive transport connecting...');
        await _rpcRequest('connectWebRtcTransport', {
          'transportId': _recvTransport!.id,
          'dtlsParameters': data['dtlsParameters'],
        });
        data['callback']();
      });
      
      debugPrint('✅ Receive transport created');
      
    } catch (e) {
      debugPrint('❌ Receive transport creation error: $e');
      rethrow;
    }
  }
  
  Future<void> _produceTracks() async {
    if (_localStream == null || _sendTransport == null) return;
    
    try {
      debugPrint('🎤 Producing tracks...');
      
      // Produce audio
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        // MediaSoup API compatibility issue - temporarily disabled
        debugPrint('⚠️ Audio producer creation disabled due to API incompatibility');
      }
      
      // Produce video
      if (_isVideoEnabled) {
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          // MediaSoup API compatibility issue - temporarily disabled
          debugPrint('⚠️ Video producer creation disabled due to API incompatibility');
        }
      }
      
    } catch (e) {
      debugPrint('❌ Track production error: $e');
    }
  }
  
  Future<void> _initializeMedia({required bool audioOnly}) async {
    try {
      debugPrint('🎥 Initializing media - audioOnly: $audioOnly');
      
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
  
  void _setupSocketListeners() {
    _socket!.on('connect', (_) {
      debugPrint('✅ MediaSoup socket connected! ID: ${_socket!.id}');
    });
    
    _socket!.on('connect_error', (error) {
      debugPrint('❌ MediaSoup socket connection error: $error');
      onError?.call(error.toString());
    });
    
    _socket!.on('disconnect', (_) {
      debugPrint('🔌 MediaSoup socket disconnected');
      _handleDisconnection();
    });
    
    // MediaSoup-specific events
    _socket!.on('newProducer', (data) async {
      await _consumeProducer(data);
    });
    
    _socket!.on('producerClosed', (data) {
      _handleProducerClosed(data);
    });
    
    _socket!.on('peer-joined', (data) {
      final peerId = data['peerId'];
      final userId = data['userId'];
      final role = data['role'];
      debugPrint('👤 Peer joined: $userId ($role) as $peerId');
      onPeerJoined?.call(peerId, userId, role);
    });
    
    _socket!.on('peer-left', (data) {
      final peerId = data['peerId'];
      debugPrint('👋 Peer left: $peerId');
      _cleanupPeer(peerId);
      onPeerLeft?.call(peerId);
    });
  }
  
  Future<void> _consumeProducer(Map<String, dynamic> data) async {
    try {
      final producerId = data['producerId'];
      final peerId = data['peerId'];
      final userId = data['userId'];
      final role = data['role'];
      final kind = data['kind'];
      
      debugPrint('🎧 Consuming $kind from $userId ($role)');
      
      // Don't consume own producers
      if (peerId == _myPeerId) return;
      
      final response = await _rpcRequest('consume', {
        'roomId': _currentRoom,
        'transportId': _recvTransport!.id,
        'producerId': producerId,
        'rtpCapabilities': _device!.rtpCapabilities,
      });
      
      // The consume method returns void, so we handle it differently
      _recvTransport!.consume(
        id: response['id'],
        producerId: producerId,
        kind: kind,
        rtpParameters: response['rtpParameters'],
        peerId: peerId,
      );
      
      // Since consume returns void, we'll track by response ID
      final consumerId = response['id'];
      
      // Resume consumer
      await _rpcRequest('resumeConsumer', {'consumerId': consumerId});
      
      // For now, we'll create a placeholder stream for this peer
      // This would need to be handled through MediaSoup events in a real implementation
      MediaStream? stream = _remoteStreams[peerId];
      if (stream == null) {
        stream = await createLocalMediaStream(peerId);
        _remoteStreams[peerId] = stream;
      }
      
      // Initialize video renderer if needed for video tracks
      if (kind == 'video' && !_videoRenderers.containsKey(peerId)) {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = stream;
        _videoRenderers[peerId] = renderer;
      }
      
      onRemoteStream?.call(peerId, stream, userId, role);
      
      debugPrint('✅ Consumer created and resumed: $consumerId');
      
    } catch (e) {
      debugPrint('❌ Error consuming producer: $e');
    }
  }
  
  void _handleProducerClosed(Map<String, dynamic> data) {
    final producerId = data['producerId'];
    final peerId = data['peerId'];
    
    debugPrint('🛑 Producer closed: $producerId from peer $peerId');
    
    // Find and close corresponding consumer
    _consumers.removeWhere((consumerId, consumer) {
      if (consumer.producerId == producerId) {
        consumer.close();
        return true;
      }
      return false;
    });
  }
  
  void _cleanupPeer(String peerId) {
    _remoteStreams.remove(peerId)?.dispose();
    _videoRenderers.remove(peerId)?.dispose();
    notifyListeners();
  }
  
  Future<Map<String, dynamic>> _rpcRequest(String method, Map<String, dynamic> params) async {
    final completer = Completer<Map<String, dynamic>>();
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    
    _socket!.once('response-$requestId', (response) {
      if (response['error'] != null) {
        completer.completeError(Exception(response['error']));
      } else {
        completer.complete(response);
      }
    });
    
    _socket!.emit('request', {
      'id': requestId,
      'method': method,
      'params': params,
    });
    
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('RPC request timeout: $method'),
    );
  }
  
  Future<void> _waitForConnection() async {
    final completer = Completer<void>();
    
    if (_socket!.connected) {
      completer.complete();
    } else {
      _socket!.once('connect', (_) => completer.complete());
      _socket!.once('connect_error', (error) => 
        completer.completeError(Exception('Connection error: $error')));
    }
    
    await completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException('Socket connection timeout'),
    );
  }
  
  Future<void> toggleMute() async {
    if (_localStream != null) {
      _isMuted = !_isMuted;
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
      notifyListeners();
    }
  }
  
  Future<void> toggleLocalVideo() async {
    if (_localStream != null) {
      _isVideoEnabled = !_isVideoEnabled;
      
      final videoTracks = _localStream!.getVideoTracks();
      for (final track in videoTracks) {
        track.enabled = _isVideoEnabled;
      }
      
      debugPrint('🎥 Local video ${_isVideoEnabled ? 'enabled' : 'disabled'}');
      notifyListeners();
    }
  }
  
  void _handleDisconnection() {
    _isConnected = false;
    
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
    
    onDisconnected?.call();
    notifyListeners();
  }
  
  Future<void> _forceDisconnect() async {
    if (_isDisposed) return;
    
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.clearListeners();
      _socket = null;
    }
    
    _handleDisconnection();
    
    // Reset state
    _currentRoom = null;
    _userRole = null;
    _myPeerId = null;
    _isConnected = false;
    _isMuted = false;
    _isVideoEnabled = false;
  }
  
  Future<void> disconnect() async {
    if (_isDisposed) return;
    await _forceDisconnect();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    disconnect();
    super.dispose();
  }
}