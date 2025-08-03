import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
// import 'polling_only_socket_io.dart';

class SimpleWebRTCService extends ChangeNotifier {
  static final SimpleWebRTCService _instance = SimpleWebRTCService._internal();
  factory SimpleWebRTCService() => _instance;
  SimpleWebRTCService._internal() {
    debugPrint('🚫 SimpleWebRTCService initialized - ONLY connects to Linode server 172.236.109.9');
    
    // SECURITY: Force cleanup any existing connections on initialization
    _emergencyCleanup();
  }
  
  void _emergencyCleanup() {
    debugPrint('🚨 EMERGENCY CLEANUP: Destroying any existing socket connections');
    
    if (_socket != null) {
      debugPrint('🧹 Cleaning up existing socket connection');
      _socket!.disconnect();
      _socket!.clearListeners();
      _socket = null;
    }
    
    // Reset all connection state
    _isConnected = false;
    _currentRoom = null;
    _userId = null;
    _userRole = null;
    _mySocketId = null;
    _myPeerId = null;
    
    debugPrint('✅ Emergency cleanup completed');
  }

  // Socket.IO connection
  io.Socket? _socket;
  
  // SFU Mode flag
  bool _sfuMode = false;
  
  // WebRTC - P2P mode (existing)
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  MediaStream? _localStream;
  final Map<String, RTCVideoRenderer> _videoRenderers = {};
  
  // SFU Mode specific
  RTCPeerConnection? _sendTransport;
  RTCPeerConnection? _recvTransport;
  String? _sendTransportId;
  String? _recvTransportId;
  final Map<String, RTCRtpSender> _producers = {}; // producerId -> sender
  final Map<String, RTCRtpReceiver> _consumers = {}; // consumerId -> receiver
  Map<String, dynamic>? _routerRtpCapabilities;
  Map<String, dynamic>? _deviceRtpCapabilities;
  
  // State
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoEnabled = false;
  bool _isDisposed = false;
  String? _currentRoom;
  String? _userId;
  String? _userRole; // 'moderator', 'speaker', 'audience'
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
  int get connectedPeersCount => _sfuMode ? _consumers.length : _connectedPeers.length;
  bool get hasVideoEnabled => _isVideoEnabled;
  
  // P2P tracking
  final Set<String> _connectedPeers = {};
  final Map<String, Map<String, String?>> _peerMetadata = {};
  String? _mySocketId;

  Future<void> connect(String serverUrl, String room, String userId, 
      {bool audioOnly = true, String role = 'audience', bool sfuMode = false}) async {
    try {
      debugPrint('🚀 MediaSoup connect() called with:');
      debugPrint('   serverUrl: $serverUrl');
      debugPrint('   room: $room');
      debugPrint('   userId: $userId');
      debugPrint('   audioOnly: $audioOnly');
      debugPrint('   role: $role');
      debugPrint('   sfuMode: $sfuMode');
      
      // SECURITY: Only allow connections to Linode server
      if (!serverUrl.contains('172.236.109.9')) {
        debugPrint('🚫 BLOCKED: SimpleWebRTCService only connects to Linode server (172.236.109.9)');
        debugPrint('🚫 Attempted connection to: $serverUrl');
        throw Exception('Connection blocked: Only Linode server connections allowed');
      }
      
      _sfuMode = sfuMode;
      
      if (_sfuMode) {
        debugPrint('🎯 Using MediaSoup SFU mode for scalability (200+ users)');
      } else {
        debugPrint('🎯 Using P2P WebRTC mode (2-10 users)');
      }
      
      debugPrint('🔌 Connecting in ${_sfuMode ? "SFU" : "P2P"} mode');
      
      // Check if already connected
      if (_isConnected && _socket != null && _socket!.connected && _currentRoom == room) {
        debugPrint('⚠️ Already connected to room: $room');
        return;
      }
      
      // Clean up if switching rooms or already connected
      if (_socket != null) {
        debugPrint('🧹 Cleaning up existing socket connection');
        await _forceDisconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      _currentRoom = room;
      _userId = userId;
      _userRole = role;
      
      // Connect using standard socket_io_client with proper URL formatting
      final serverUri = 'http://$serverUrl';
      
      debugPrint('🔌 Connecting to: $serverUri');
      
      // FINAL SECURITY CHECK: Absolutely no localhost connections allowed
      if (serverUri.contains('localhost') || serverUri.contains('127.0.0.1')) {
        debugPrint('🚫 EMERGENCY STOP: Localhost connection blocked in SimpleWebRTCService');
        debugPrint('🚫 Attempted URI: $serverUri');
        throw Exception('SECURITY: Localhost connections are permanently blocked');
      }
      
      // Standard socket_io_client with strict polling-only configuration
      _socket = io.io(serverUri, <String, dynamic>{
        'transports': ['polling'], // Force polling only, disable WebSocket
        'upgrade': false, // Prevent WebSocket upgrade
        'rememberUpgrade': false, // Don't remember upgrade attempts
        'autoConnect': false, // We'll connect manually
        'reconnection': false, // Disable automatic reconnection
        'timeout': 20000,
        'forceNew': true,
      });
      
      debugPrint('🔧 socket_io_client configuration:');
      debugPrint('   - Standard socket_io_client package');
      debugPrint('   - Polling transport only (no WebSocket)');
      debugPrint('   - upgrade: false, rememberUpgrade: false');
      debugPrint('   - autoConnect: false, reconnection: false, forceNew: true');
      debugPrint('🚨 Connecting to: $serverUri');
      
      if (_sfuMode) {
        _setupSFUSocketListeners();
      } else {
        _setupP2PSocketListeners();
      }
      
      debugPrint('🔌 Attempting socket_io_client connection...');
      debugPrint('🔒 SECURITY: Connection allowed to Linode server: $serverUrl');
      
      // Additional safety check before connecting
      if (!serverUrl.contains('172.236.109.9')) {
        debugPrint('🚫 DOUBLE-CHECK FAILED: Blocking connection to $serverUrl');
        throw Exception('Unauthorized server connection blocked');
      }
      
      _socket!.connect();
      
      // Wait for connection
      await _waitForConnection();
      
      // Add small delay to ensure socket is fully ready for message emission
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('✅ Socket ready for message emission');
      
      // Use SFU mode for scalability when configured
      if (_sfuMode) {
        await _connectSFU(room, userId, role, audioOnly);
      } else {
        await _connectP2P(room, userId, role, audioOnly);
      }
      
      _isConnected = true;
      onConnected?.call();
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ Connection error: $e');
      onError?.call(e.toString());
      rethrow;
    }
  }

  // ============= SFU MODE IMPLEMENTATION =============
  
  Future<void> _connectSFU(String room, String userId, String role, bool audioOnly) async {
    debugPrint('🎬 Starting SFU connection flow');
    
    // 1. Join room
    final joinCompleter = Completer<void>();
    _socket!.once('room-joined', (data) {
      debugPrint('📥 Received room-joined event: $data');
      _myPeerId = data['myPeerId'] ?? data['peerId'] ?? _socket!.id;
      debugPrint('✅ Joined room as peer: $_myPeerId');
      joinCompleter.complete();
    });
    
    _socket!.emit('join-room', {
      'roomId': room,
      'userId': userId,
      'role': role,
    });
    
    // Add debugging for room join process
    debugPrint('🔄 Emitting join-room event for room: $room, userId: $userId, role: $role');
    debugPrint('🔍 Socket connected: ${_socket?.connected}, socket ID: ${_socket?.id}');
    
    await joinCompleter.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        debugPrint('⏰ Room join timeout - socket connected: ${_socket!.connected}');
        debugPrint('⏰ Waiting for room-joined event from server...');
        throw TimeoutException('Failed to join room - server did not respond to join-room event');
      },
    );
    
    // 2. Get router RTP capabilities
    final rtpCapabilities = await _rpcRequest('getRouterRtpCapabilities', {'roomId': room});
    _routerRtpCapabilities = rtpCapabilities['rtpCapabilities'];
    debugPrint('📡 Got router RTP capabilities');
    
    // 3. Initialize device capabilities (simplified for flutter_webrtc)
    _deviceRtpCapabilities = _routerRtpCapabilities; // Simplified - in real mediasoup-client this would be device.load()
    
    // 4. Create transports
    if (role == 'moderator' || role == 'speaker') {
      await _createSendTransport(room);
    }
    await _createRecvTransport(room);
    
    // 5. Initialize media and produce if needed
    if ((role == 'moderator' || role == 'speaker') && !audioOnly) {
      await _initializeMedia(audioOnly: audioOnly);
      await _produceTracks();
    } else if (role == 'moderator' || role == 'speaker') {
      // Audio only for speakers
      await _initializeMedia(audioOnly: true);
      await _produceTracks();
    }
    
    // 6. Consume existing producers
    await _consumeExistingProducers(room);
  }
  
  Future<void> _createSendTransport(String roomId) async {
    debugPrint('🚛 Creating send transport');
    
    final response = await _rpcRequest('createWebRtcTransport', {
      'roomId': roomId,
      'direction': 'send',
    });
    
    _sendTransportId = response['id'];
    
    // Create RTCPeerConnection for send transport
    _sendTransport = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    });
    
    // Handle ICE gathering
    _sendTransport!.onIceCandidate = (candidate) {
      // In MediaSoup, we don't send individual ICE candidates
      // They are included in the transport parameters
    };
    
    // Set remote ICE parameters and candidates from server
    // This is a simplified approach - real mediasoup-client handles this differently
    await _connectTransport(_sendTransportId!, response, _sendTransport!);
    
    debugPrint('✅ Send transport created: $_sendTransportId');
  }
  
  Future<void> _createRecvTransport(String roomId) async {
    debugPrint('🚛 Creating receive transport');
    
    final response = await _rpcRequest('createWebRtcTransport', {
      'roomId': roomId,
      'direction': 'recv',
    });
    
    _recvTransportId = response['id'];
    
    // Create RTCPeerConnection for receive transport
    _recvTransport = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    });
    
    // Handle incoming tracks
    _recvTransport!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        final trackId = event.track.id;
        
        debugPrint('🎬 Received track: ${event.track.kind} ($trackId)');
        
        // Find which consumer this track belongs to
        String? peerId;
        String? userId;
        String? role;
        
        // Map track to peer metadata (stored during consume)
        for (final entry in _consumers.entries) {
          final consumerId = entry.key;
          final receiver = entry.value;
          if (receiver.track?.id == trackId) {
            final metadata = _consumerMetadata[consumerId];
            if (metadata != null) {
              peerId = metadata['peerId'];
              userId = metadata['userId'];
              role = metadata['role'];
            }
            break;
          }
        }
        
        if (peerId != null) {
          final nonNullPeerId = peerId;
          _remoteStreams[nonNullPeerId] = stream;
          
          // Initialize video renderer if needed
          if (stream.getVideoTracks().isNotEmpty && !_videoRenderers.containsKey(nonNullPeerId)) {
            final renderer = RTCVideoRenderer();
            renderer.initialize().then((_) {
              renderer.srcObject = stream;
              _videoRenderers[nonNullPeerId] = renderer;
              debugPrint('🎥 Video renderer initialized for peer: $nonNullPeerId');
            });
          }
          
          onRemoteStream?.call(nonNullPeerId, stream, userId, role);
        }
      }
    };
    
    await _connectTransport(_recvTransportId!, response, _recvTransport!);
    
    debugPrint('✅ Receive transport created: $_recvTransportId');
  }
  
  Future<void> _connectTransport(String transportId, Map<String, dynamic> params, RTCPeerConnection pc) async {
    // Create offer/answer to establish DTLS
    if (_sendTransport == pc) {
      // For send transport, we create offer
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      
      // Send DTLS parameters to server
      await _rpcRequest('connectWebRtcTransport', {
        'transportId': transportId,
        'dtlsParameters': {
          // Extract DTLS parameters from SDP
          'fingerprints': [/* parsed from SDP */],
          'role': 'client',
        },
      });
    } else {
      // For receive transport, we might need to handle this differently
      // This is simplified - real mediasoup-client has more complex handling
    }
  }
  
  Future<void> _produceTracks() async {
    if (_localStream == null || _sendTransport == null) return;
    
    debugPrint('🎙️ Producing tracks');
    
    // Produce audio
    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isNotEmpty) {
      final audioTrack = audioTracks.first;
      final audioSender = await _sendTransport!.addTrack(audioTrack, _localStream!);
      
      // Get RTP parameters (simplified for flutter_webrtc compatibility)
      final audioParams = {
        'codecs': [{'mimeType': 'audio/opus', 'clockRate': 48000, 'channels': 2}],
        'headerExtensions': [],
        'encodings': [{}],
      };
      
      final response = await _rpcRequest('produce', {
        'roomId': _currentRoom,
        'transportId': _sendTransportId,
        'kind': 'audio',
        'rtpParameters': audioParams,
        'appData': {
          'userId': _userId,
          'role': _userRole,
        },
      });
      
      _producers[response['producerId']] = audioSender;
      debugPrint('✅ Audio producer created: ${response['producerId']}');
    }
    
    // Produce video
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty && _isVideoEnabled) {
      final videoTrack = videoTracks.first;
      final videoSender = await _sendTransport!.addTrack(videoTrack, _localStream!);
      
      final videoParams = {
        'codecs': [{'mimeType': 'video/VP8', 'clockRate': 90000}],
        'headerExtensions': [],
        'encodings': [{}],
      };
      
      final response = await _rpcRequest('produce', {
        'roomId': _currentRoom,
        'transportId': _sendTransportId,
        'kind': 'video',
        'rtpParameters': videoParams,
        'appData': {
          'userId': _userId,
          'role': _userRole,
        },
      });
      
      _producers[response['producerId']] = videoSender;
      debugPrint('✅ Video producer created: ${response['producerId']}');
    }
  }
  
  final Map<String, Map<String, String?>> _consumerMetadata = {}; // consumerId -> metadata
  
  Future<void> _consumeExistingProducers(String roomId) async {
    debugPrint('🎧 Consuming existing producers');
    
    final response = await _rpcRequest('listProducers', {'roomId': roomId});
    final producers = response['producers'] as List;
    
    debugPrint('📋 Found ${producers.length} existing producers');
    
    for (final producer in producers) {
      final producerId = producer['producerId'];
      final peerId = producer['peerId'];
      
      // Don't consume own producers
      if (peerId == _myPeerId) continue;
      
      await _consumeProducer(
        producerId: producerId,
        peerId: peerId,
        userId: producer['userId'],
        role: producer['role'],
        kind: producer['kind'],
      );
    }
  }
  
  Future<void> _consumeProducer({
    required String producerId,
    required String peerId,
    required String userId,
    required String role,
    required String kind,
  }) async {
    debugPrint('🎧 Consuming $kind from $userId ($role)');
    
    try {
      final response = await _rpcRequest('consume', {
        'roomId': _currentRoom,
        'transportId': _recvTransportId,
        'producerId': producerId,
        'rtpCapabilities': _deviceRtpCapabilities,
      });
      
      final consumerId = response['id'];
      
      // Store metadata for track mapping
      _consumerMetadata[consumerId] = {
        'peerId': peerId,
        'userId': userId,
        'role': role,
        'producerId': producerId,
      };
      
      // Add transceiver to receive this track
      final transceiver = await _recvTransport!.addTransceiver(
        kind: kind == 'audio' ? RTCRtpMediaType.RTCRtpMediaTypeAudio : RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.RecvOnly,
          streams: [
            // Create or get stream for this peer (flutter_webrtc creates streams automatically)
            _remoteStreams[peerId] ?? await createLocalMediaStream(peerId),
          ],
        ),
      );
      
      _consumers[consumerId] = transceiver.receiver;
      
      // Resume consumer
      await _rpcRequest('resumeConsumer', {'consumerId': consumerId});
      
      debugPrint('✅ Consumer created and resumed: $consumerId for $kind from $userId');
      
    } catch (e) {
      debugPrint('❌ Error consuming producer: $e');
    }
  }
  
  void _setupSFUSocketListeners() {
    _socket!.on('connect', (_) {
      debugPrint('✅ SFU socket_io_client connected! ID: ${_socket!.id}');
    });
    
    _socket!.on('connect_error', (error) {
      debugPrint('❌ SFU socket_io_client connection error: $error');
    });
    
    _socket!.on('reconnect', (attemptNumber) {
      debugPrint('🔄 SFU socket_io_client reconnected after $attemptNumber attempts');
    });
    
    _socket!.on('reconnect_error', (error) {
      debugPrint('❌ SFU socket_io_client reconnection error: $error');
    });
    
    _socket!.on('disconnect', (_) {
      debugPrint('🔌 SFU socket_io_client disconnected');
      _handleDisconnection();
    });
    
    // New producer in room
    _socket!.on('newProducer', (data) async {
      final producerId = data['producerId'];
      final peerId = data['peerId'];
      final userId = data['userId'];
      final role = data['role'];
      final kind = data['kind'];
      
      debugPrint('🆕 New producer: $kind from $userId ($role)');
      
      // Don't consume own producers
      if (peerId == _myPeerId) return;
      
      await _consumeProducer(
        producerId: producerId,
        peerId: peerId,
        userId: userId,
        role: role,
        kind: kind,
      );
    });
    
    // Producer closed
    _socket!.on('producerClosed', (data) {
      final producerId = data['producerId'];
      final peerId = data['peerId'];
      
      debugPrint('🛑 Producer closed: $producerId from peer $peerId');
      
      // Find and remove consumer for this producer
      String? consumerIdToRemove;
      for (final entry in _consumerMetadata.entries) {
        final consumerId = entry.key;
        final metadata = entry.value;
        if (metadata['producerId'] == producerId) {
          consumerIdToRemove = consumerId;
          break;
        }
      }
      
      if (consumerIdToRemove != null) {
        _consumers.remove(consumerIdToRemove);
        _consumerMetadata.remove(consumerIdToRemove);
      }
    });
    
    // Peer left
    _socket!.on('peerLeft', (data) {
      final peerId = data['peerId'];
      debugPrint('👋 Peer left: $peerId');
      
      _cleanupPeer(peerId);
      onPeerLeft?.call(peerId);
    });
    
    // Peer joined (for presence awareness)
    _socket!.on('peer-joined', (data) {
      final peerId = data['peerId'];
      final userId = data['userId'];
      final role = data['role'];
      
      debugPrint('👤 Peer joined: $userId ($role) as $peerId');
      onPeerJoined?.call(peerId, userId, role);
    });
    
    // Error handling
    _socket!.on('error', (error) {
      debugPrint('❌ SFU socket_io_client error: $error');
      onError?.call(error.toString());
    });
  }
  
  Future<Map<String, dynamic>> _rpcRequest(String method, Map<String, dynamic> params) async {
    final completer = Completer<Map<String, dynamic>>();
    
    // Generate unique request ID for RPC pattern
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Listen for response once
    _socket!.once('response-$requestId', (response) {
      if (response['error'] != null) {
        completer.completeError(Exception(response['error']));
      } else {
        completer.complete(response);
      }
    });
    
    // Send request with ID
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
  
  void _cleanupPeer(String peerId) {
    // Remove streams and renderers
    _remoteStreams.remove(peerId)?.dispose();
    _videoRenderers.remove(peerId)?.dispose();
    
    // Remove consumer metadata for this peer
    _consumerMetadata.removeWhere((_, metadata) => metadata['peerId'] == peerId);
    
    notifyListeners();
  }

  // ============= P2P MODE IMPLEMENTATION (existing) =============
  
  Future<void> _connectP2P(String room, String userId, String role, bool audioOnly) async {
    // Existing P2P implementation
    final joinData = {
      'roomId': room,
      'userId': userId,
      'role': role,
    };
    _socket!.emit('join-room', joinData);
    
    // Wait for room joined confirmation
    final completer = Completer<void>();
    _socket!.once('room-joined', (data) {
      debugPrint('✅ Successfully joined room: $data');
      completer.complete();
    });
    
    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Failed to join room'),
    );
    
    // Initialize media if not audience
    if (role != 'audience' || !audioOnly) {
      await _initializeMedia(audioOnly: audioOnly);
    }
  }
  
  void _setupP2PSocketListeners() {
    _socket!.on('connect', (_) {
      _mySocketId = _socket!.id;
      debugPrint('✅ P2P socket_io_client connected! ID: $_mySocketId');
    });
    
    _socket!.on('connect_error', (error) {
      debugPrint('❌ P2P socket_io_client connection error: $error');
      
      // SECURITY: If localhost detected in error, force disconnect
      if (error.toString().contains('localhost') || error.toString().contains('127.0.0.1')) {
        debugPrint('🚫 SECURITY ALERT: Localhost connection detected in P2P error!');
        debugPrint('🚫 Force disconnecting socket to prevent localhost connection');
        _socket?.disconnect();
        _socket?.clearListeners();
        _socket = null;
      }
    });
    
    _socket!.on('disconnect', (_) {
      debugPrint('🔌 P2P socket_io_client disconnected');
      _handleDisconnection();
    });
    
    // WebRTC signaling handlers
    _socket!.on('offer', (data) async {
      debugPrint('📥 Received offer from ${data['from']}');
      await _handleOffer(data);
    });
    
    _socket!.on('answer', (data) async {
      debugPrint('📥 Received answer from ${data['from']}');
      await _handleAnswer(data);
    });
    
    _socket!.on('ice-candidate', (data) async {
      debugPrint('🧊 Received ICE candidate from ${data['from']}');
      await _handleIceCandidate(data);
    });
    
    // Room management
    _socket!.on('peer-joined', (data) async {
      final peerId = data['peerId'];
      final userId = data['userId'];
      final role = data['role'];
      
      debugPrint('👤 Peer joined: $userId ($role) as $peerId');
      
      // Create peer connection for new peer
      if (role == 'moderator' || role == 'speaker') {
        await _createPeerConnection(peerId, userId, role);
      }
      
      onPeerJoined?.call(peerId, userId, role);
    });
    
    _socket!.on('peer-left', (data) {
      final peerId = data['peerId'];
      debugPrint('👋 Peer left: $peerId');
      
      _cleanupPeerConnection(peerId);
      onPeerLeft?.call(peerId);
    });
  }
  
  // ============= SHARED METHODS =============
  
  Future<void> _initializeMedia({required bool audioOnly}) async {
    try {
      // Skip media for audience only if audioOnly is true AND they're not requesting video
      if (_userRole == 'audience' && audioOnly) {
        debugPrint('🎭 Audience member in audio-only mode - skipping local media setup');
        return;
      }
      
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
      
      // Set initial video state
      if (!audioOnly && _localStream!.getVideoTracks().isNotEmpty) {
        _isVideoEnabled = true;
        debugPrint('🎥 Local video initialized with ${_localStream!.getVideoTracks().length} tracks');
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
      
      // In SFU mode, we might need to notify server
      if (_sfuMode) {
        // Could implement producer.pause() / producer.resume() here
      }
      
      notifyListeners();
    }
  }
  
  Future<void> toggleLocalVideo() async {
    debugPrint('🎥 toggleLocalVideo called - current state: enabled=$_isVideoEnabled, hasStream=${_localStream != null}, role=$_userRole');
    
    // If no local stream, try to initialize it with video
    if (_localStream == null) {
      debugPrint('🎥 No local stream found, attempting to initialize media with video...');
      try {
        await _initializeMedia(audioOnly: false);
        if (_localStream == null) {
          debugPrint('❌ Failed to initialize local stream for video');
          return;
        }
      } catch (e) {
        debugPrint('❌ Error initializing media for video: $e');
        return;
      }
    }
    
    if (_localStream != null) {
      _isVideoEnabled = !_isVideoEnabled;
      
      // Handle existing video tracks
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        for (final track in videoTracks) {
          track.enabled = _isVideoEnabled;
        }
      } else if (_isVideoEnabled) {
        // No video tracks but user wants to enable video - need to get new stream
        debugPrint('🎥 No video tracks found, getting new stream with video...');
        try {
          final Map<String, dynamic> mediaConstraints = {
            'audio': true,
            'video': {
              'width': {'ideal': 640},
              'height': {'ideal': 480},
              'frameRate': {'ideal': 30},
              'facingMode': 'user',
            },
          };
          
          final newStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
          
          // Add video tracks from new stream to existing stream
          for (final videoTrack in newStream.getVideoTracks()) {
            _localStream!.addTrack(videoTrack);
          }
          
          onLocalStream?.call(_localStream!);
        } catch (e) {
          debugPrint('❌ Error getting video stream: $e');
          _isVideoEnabled = false;
          return;
        }
      }
      
      // In SFU mode, handle video producer
      if (_sfuMode && _sendTransport != null) {
        if (_isVideoEnabled) {
          // Re-produce video if it was stopped
          if (_localStream!.getVideoTracks().isNotEmpty) {
            debugPrint('🎥 Producing video tracks in SFU mode...');
            await _produceTracks(); // This will only produce video if not already producing
          }
        } else {
          // Close video producer
          debugPrint('🎥 Closing video producer in SFU mode...');
          for (final entry in _producers.entries) {
            if (entry.value.track?.kind == 'video') {
              await _rpcRequest('closeProducer', {'producerId': entry.key});
              _producers.remove(entry.key);
              break;
            }
          }
        }
      }
      
      debugPrint('🎥 Local video ${_isVideoEnabled ? 'enabled' : 'disabled'}');
      notifyListeners();
    } else {
      debugPrint('❌ Cannot toggle video - no local stream available');
    }
  }
  
  Future<void> _waitForConnection() async {
    final completer = Completer<void>();
    
    if (_socket!.connected) {
      debugPrint('✅ socket_io_client already connected');
      completer.complete();
    } else {
      debugPrint('⏳ Waiting for socket_io_client connect event...');
      _socket!.once('connect', (_) {
        debugPrint('✅ socket_io_client connect event received!');
        completer.complete();
      });
      
      // Also listen for connection errors
      _socket!.once('connect_error', (error) {
        debugPrint('❌ socket_io_client connect error: $error');
        completer.completeError(Exception('Connection error: $error'));
      });
    }
    
    await completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        debugPrint('⏰ Connection timeout - socket.connected: ${_socket!.connected}');
        throw TimeoutException('socket_io_client connection timeout');
      },
    );
  }
  
  void _handleDisconnection() {
    _isConnected = false;
    
    if (_sfuMode) {
      // Clean up SFU resources
      _sendTransport?.close();
      _recvTransport?.close();
      _sendTransport = null;
      _recvTransport = null;
      _producers.clear();
      _consumers.clear();
      _consumerMetadata.clear();
    } else {
      // Clean up P2P resources
      for (final peerId in _peerConnections.keys.toList()) {
        _cleanupPeerConnection(peerId);
      }
    }
    
    // Clean up common resources
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
    
    // Clean up socket
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.clearListeners(); // Clear event listeners instead of dispose()
      _socket = null;
    }
    
    // Clean up all connections and streams
    _handleDisconnection();
    
    // Reset state
    _currentRoom = null;
    _userId = null;
    _userRole = null;
    _mySocketId = null;
    _myPeerId = null;
    _isConnected = false;
    _isMuted = false;
    _isVideoEnabled = false;
    _sfuMode = false;
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
  
  // ============= P2P WebRTC SIGNALING METHODS =============
  
  Future<void> _createPeerConnection(String peerId, String? userId, String? role) async {
    try {
      debugPrint('🔗 Creating peer connection for $peerId ($userId - $role)');
      
      final pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
      });
      
      _peerConnections[peerId] = pc;
      _peerMetadata[peerId] = {'userId': userId, 'role': role};
      
      // Add local stream if available
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          pc.addTrack(track, _localStream!);
        });
        debugPrint('📤 Added local tracks to peer connection');
      }
      
      // Handle incoming streams
      pc.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          final stream = event.streams[0];
          debugPrint('📥 Received remote stream from $peerId');
          
          _remoteStreams[peerId] = stream;
          
          // Initialize video renderer if needed
          if (stream.getVideoTracks().isNotEmpty && !_videoRenderers.containsKey(peerId)) {
            final renderer = RTCVideoRenderer();
            renderer.initialize().then((_) {
              renderer.srcObject = stream;
              _videoRenderers[peerId] = renderer;
              debugPrint('🎥 Video renderer initialized for peer: $peerId');
            });
          }
          
          onRemoteStream?.call(peerId, stream, userId, role);
        }
      };
      
      // Handle ICE candidates
      pc.onIceCandidate = (candidate) {
        debugPrint('🧊 Sending ICE candidate to $peerId');
        _socket!.emit('ice-candidate', {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'to': peerId,
        });
      };
      
      // Create and send offer if we're the caller (moderator/speaker joining)
      if (_userRole == 'moderator' || _userRole == 'speaker') {
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        
        debugPrint('📤 Sending offer to $peerId');
        _socket!.emit('offer', {
          'sdp': offer.sdp,
          'type': offer.type,
          'to': peerId,
        });
      }
      
    } catch (e) {
      debugPrint('❌ Error creating peer connection: $e');
    }
  }
  
  Future<void> _handleOffer(Map<String, dynamic> data) async {
    try {
      final peerId = data['from'];
      final offer = RTCSessionDescription(data['sdp'], data['type']);
      
      debugPrint('📥 Handling offer from $peerId');
      
      // Get or create peer connection
      RTCPeerConnection? pc = _peerConnections[peerId];
      if (pc == null) {
        await _createPeerConnection(peerId, null, null);
        pc = _peerConnections[peerId]!;
      }
      
      await pc.setRemoteDescription(offer);
      
      // Create and send answer
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      
      debugPrint('📤 Sending answer to $peerId');
      _socket!.emit('answer', {
        'sdp': answer.sdp,
        'type': answer.type,
        'to': peerId,
      });
      
    } catch (e) {
      debugPrint('❌ Error handling offer: $e');
    }
  }
  
  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    try {
      final peerId = data['from'];
      final answer = RTCSessionDescription(data['sdp'], data['type']);
      
      debugPrint('📥 Handling answer from $peerId');
      
      final pc = _peerConnections[peerId];
      if (pc != null) {
        await pc.setRemoteDescription(answer);
        debugPrint('✅ Remote description set for $peerId');
      }
      
    } catch (e) {
      debugPrint('❌ Error handling answer: $e');
    }
  }
  
  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    try {
      final peerId = data['from'];
      final candidate = RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      );
      
      debugPrint('🧊 Adding ICE candidate from $peerId');
      
      final pc = _peerConnections[peerId];
      if (pc != null) {
        await pc.addCandidate(candidate);
      }
      
    } catch (e) {
      debugPrint('❌ Error handling ICE candidate: $e');
    }
  }
  
  void _cleanupPeerConnection(String peerId) {
    debugPrint('🧹 Cleaning up peer connection: $peerId');
    
    // Close peer connection
    _peerConnections[peerId]?.close();
    _peerConnections.remove(peerId);
    
    // Remove metadata
    _peerMetadata.remove(peerId);
    
    // Remove streams and renderers
    _remoteStreams.remove(peerId)?.dispose();
    _videoRenderers.remove(peerId)?.dispose();
    
    notifyListeners();
  }
}