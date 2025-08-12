# Complete WebRTC Implementation

## Client: SimpleMediaSoupService (Full Code)

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SimpleMediaSoupService extends ChangeNotifier {
  static final SimpleMediaSoupService _instance = SimpleMediaSoupService._internal();
  factory SimpleMediaSoupService() => _instance;
  SimpleMediaSoupService._internal();

  // Socket.IO connection
  io.Socket? _socket;
  
  // WebRTC - Multiple peer connections for multi-user support
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  MediaStream? _localStream;
  final Map<String, RTCVideoRenderer> _videoRenderers = {};
  
  // State
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoEnabled = false;
  bool _isDisposed = false;
  Map<String, dynamic>? _rtpCapabilities;
  String? _currentRoom;
  String? _userId;
  String? _userRole; // 'moderator', 'speaker', 'audience'
  
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
  int get connectedPeersCount => _connectedPeers.length;
  
  // Track connected peers
  final Set<String> _connectedPeers = {};
  final Map<String, Map<String, String?>> _peerMetadata = {}; // peerId -> {userId, role}
  String? _mySocketId;

  Future<void> connect(String serverUrl, String room, String userId, 
      {bool audioOnly = true, String role = 'audience'}) async {
    try {
      // Check if already connected to the same room
      if (_isConnected && _socket != null && _socket!.connected && _currentRoom == room) {
        debugPrint('⚠️ Already connected to room: $room');
        return;
      }
      
      // Clean up if switching rooms
      if (_socket != null || _currentRoom != room) {
        await _forceDisconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      _currentRoom = room;
      _userId = userId;
      _userRole = role;
      
      // Connect to signaling server
      const serverPort = '3001';
      const protocol = 'http';
      final serverUri = '$protocol://$serverUrl:$serverPort/signaling';
      
      _socket = io.io(serverUri, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': false,
        'timeout': 20000,
        'forceNew': true,
        'upgrade': true,
      });
      
      _setupSocketListeners();
      _socket!.connect();
      
      // Wait for connection
      await _waitForConnection();
      
      // Join room
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
      
      _isConnected = true;
      onConnected?.call();
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ Connection error: $e');
      onError?.call(e.toString());
      rethrow;
    }
  }

  void _setupSocketListeners() {
    _socket!.on('connect', (_) {
      _mySocketId = _socket!.id;
      debugPrint('✅ Socket connected! ID: $_mySocketId');
    });
    
    _socket!.on('disconnect', (_) {
      debugPrint('🔌 Socket disconnected');
      _handleDisconnection();
    });
    
    // Handle existing peers when joining
    _socket!.on('room-joined', (data) async {
      debugPrint('📨 Room joined event: $data');
      
      // Handle any existing peers in the room
      final existingPeers = data['participants'] ?? [];
      for (final peer in existingPeers) {
        final peerId = peer['socketId'];
        final userId = peer['userId'];
        final role = peer['role'];
        
        if (!_connectedPeers.contains(peerId)) {
          _connectedPeers.add(peerId);
          _peerMetadata[peerId] = {'userId': userId, 'role': role};
          
          // Create peer connection
          await _createPeerConnectionForPeer(peerId);
          onPeerJoined?.call(peerId, userId, role);
          
          // Initiate offer to existing peer
          await Future.delayed(const Duration(milliseconds: 500));
          await _createAndSendOffer(peerId);
        }
      }
      notifyListeners();
    });
    
    // Handle new peer joining
    _socket!.on('peer-joined', (data) async {
      final peerId = data['peerId'];
      final userId = data['userId'];
      final role = data['role'];
      
      debugPrint('👤 Peer joined: $peerId (User: $userId, Role: $role)');
      
      if (peerId == _mySocketId) {
        return; // Skip self
      }
      
      if (_connectedPeers.contains(peerId)) {
        return; // Already processed
      }
      
      _connectedPeers.add(peerId);
      _peerMetadata[peerId] = {'userId': userId, 'role': role};
      
      await _createPeerConnectionForPeer(peerId);
      onPeerJoined?.call(peerId, userId, role);
      notifyListeners();
      
      // Always initiate offer to ensure connection
      await Future.delayed(const Duration(milliseconds: 500));
      await _createAndSendOffer(peerId);
    });
    
    // Handle peer leaving
    _socket!.on('peer-left', (data) {
      final peerId = data['peerId'];
      debugPrint('👋 Peer left: $peerId');
      
      _cleanupPeerConnection(peerId);
      onPeerLeft?.call(peerId);
      notifyListeners();
    });
    
    // WebRTC signaling
    _socket!.on('offer', (data) => _handleOffer(data, data['from']));
    _socket!.on('answer', (data) => _handleAnswer(data, data['from']));
    _socket!.on('ice-candidate', (data) => _handleIceCandidate(data, data['from']));
    
    // Error handling
    _socket!.on('error', (error) {
      debugPrint('❌ Socket error: $error');
      onError?.call(error.toString());
    });
  }

  Future<void> _initializeMedia({required bool audioOnly}) async {
    try {
      // Skip media for audience in audio-only mode
      if (_userRole == 'audience' && audioOnly) {
        debugPrint('🎭 Audience member - skipping local media setup');
        return;
      }
      
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

  Future<void> _createPeerConnectionForPeer(String peerId) async {
    try {
      // Check if already exists
      if (_peerConnections.containsKey(peerId)) {
        final existingConnection = _peerConnections[peerId]!;
        final connectionState = await existingConnection.getConnectionState();
        if (connectionState != RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          debugPrint('⚠️ Peer connection already exists for $peerId');
          return;
        }
        _cleanupPeerConnection(peerId);
      }
      
      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
      };
      
      final peerConnection = await createPeerConnection(configuration);
      _peerConnections[peerId] = peerConnection;
      
      // Set up event handlers
      peerConnection.onIceCandidate = (candidate) {
        _socket!.emit('ice-candidate', {
          'to': peerId,
          'from': _mySocketId,
          'candidate': candidate.toMap(),
        });
      };
      
      peerConnection.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          final stream = event.streams[0];
          _remoteStreams[peerId] = stream;
          
          // Initialize video renderer if needed
          if (stream.getVideoTracks().isNotEmpty) {
            final renderer = RTCVideoRenderer();
            renderer.initialize().then((_) {
              renderer.srcObject = stream;
              _videoRenderers[peerId] = renderer;
            });
          }
          
          final metadata = _peerMetadata[peerId];
          onRemoteStream?.call(peerId, stream, metadata?['userId'], metadata?['role']);
        }
      };
      
      peerConnection.onConnectionState = (state) {
        debugPrint('🔗 Connection state for $peerId: $state');
      };
      
      // Add local stream
      await _addLocalStreamToPeer(peerId);
      
      // Process buffered ICE candidates
      await _processBufferedCandidatesForPeer(peerId);
      
    } catch (e) {
      debugPrint('❌ Failed to create peer connection for $peerId: $e');
    }
  }

  Future<void> _addLocalStreamToPeer(String peerId) async {
    try {
      final peerConnection = _peerConnections[peerId];
      if (peerConnection == null) return;
      
      if (_localStream != null) {
        final audioTracks = _localStream!.getAudioTracks();
        final videoTracks = _localStream!.getVideoTracks();
        
        // Debug track states
        debugPrint('🔍 Adding tracks to $peerId:');
        for (final track in audioTracks) {
          await peerConnection.addTrack(track, _localStream!);
          debugPrint('  🎤 Audio: ${track.id}, enabled=${track.enabled}');
        }
        for (final track in videoTracks) {
          await peerConnection.addTrack(track, _localStream!);
          debugPrint('  🎥 Video: ${track.id}, enabled=${track.enabled}');
        }
      } else {
        // Audience receiving only
        if (_userRole == 'audience') {
          debugPrint('🎭 Adding transceivers for audience to receive');
          await peerConnection.addTransceiver(
            kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
            init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
          );
          await peerConnection.addTransceiver(
            kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
            init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error adding local stream to $peerId: $e');
    }
  }

  // ICE candidate buffering
  final Map<String, List<RTCIceCandidate>> _iceCandidateBuffers = {};
  final Map<String, bool> _remoteDescriptionStates = {};

  Future<void> _createAndSendOffer(String targetPeerId) async {
    try {
      final peerConnection = _peerConnections[targetPeerId];
      if (peerConnection == null) return;
      
      final offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      
      _socket!.emit('offer', {
        'sdp': offer.sdp,
        'type': offer.type,
        'to': targetPeerId,
        'from': _mySocketId,
      });
      
      debugPrint('📤 Sent offer to $targetPeerId');
    } catch (e) {
      debugPrint('❌ Error creating offer: $e');
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> data, String fromPeerId) async {
    try {
      var peerConnection = _peerConnections[fromPeerId];
      if (peerConnection == null) {
        await _createPeerConnectionForPeer(fromPeerId);
        peerConnection = _peerConnections[fromPeerId];
      }
      
      if (peerConnection == null) return;
      
      final offer = RTCSessionDescription(data['sdp'], data['type']);
      await peerConnection.setRemoteDescription(offer);
      _remoteDescriptionStates[fromPeerId] = true;
      
      final answer = await peerConnection.createAnswer();
      await peerConnection.setLocalDescription(answer);
      
      _socket!.emit('answer', {
        'sdp': answer.sdp,
        'type': answer.type,
        'to': fromPeerId,
        'from': _mySocketId,
      });
      
      debugPrint('📥 Handled offer from $fromPeerId');
    } catch (e) {
      debugPrint('❌ Error handling offer: $e');
    }
  }

  Future<void> _handleAnswer(Map<String, dynamic> data, String fromPeerId) async {
    try {
      final peerConnection = _peerConnections[fromPeerId];
      if (peerConnection == null) return;
      
      final answer = RTCSessionDescription(data['sdp'], data['type']);
      await peerConnection.setRemoteDescription(answer);
      _remoteDescriptionStates[fromPeerId] = true;
      
      // Process buffered candidates
      await _processBufferedCandidatesForPeer(fromPeerId);
      
      debugPrint('📥 Handled answer from $fromPeerId');
    } catch (e) {
      debugPrint('❌ Error handling answer: $e');
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> data, String fromPeerId) async {
    try {
      final peerConnection = _peerConnections[fromPeerId];
      if (peerConnection == null) return;
      
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );
      
      // Buffer if no remote description yet
      if (_remoteDescriptionStates[fromPeerId] != true) {
        _iceCandidateBuffers[fromPeerId] ??= [];
        _iceCandidateBuffers[fromPeerId]!.add(candidate);
        debugPrint('🧊 Buffered ICE candidate for $fromPeerId');
      } else {
        await peerConnection.addCandidate(candidate);
        debugPrint('🧊 Added ICE candidate from $fromPeerId');
      }
    } catch (e) {
      debugPrint('❌ Error handling ICE candidate: $e');
    }
  }

  Future<void> _processBufferedCandidatesForPeer(String peerId) async {
    final bufferedCandidates = _iceCandidateBuffers[peerId];
    if (bufferedCandidates == null || bufferedCandidates.isEmpty) return;
    
    final peerConnection = _peerConnections[peerId];
    if (peerConnection == null) return;
    
    for (final candidate in bufferedCandidates) {
      try {
        await peerConnection.addCandidate(candidate);
      } catch (e) {
        debugPrint('⚠️ Error adding buffered candidate: $e');
      }
    }
    
    _iceCandidateBuffers[peerId] = [];
    debugPrint('✅ Processed ${bufferedCandidates.length} buffered candidates for $peerId');
  }

  void _cleanupPeerConnection(String peerId) {
    // Close and remove peer connection
    _peerConnections.remove(peerId)?.close();
    
    // Remove streams and renderers
    _remoteStreams.remove(peerId)?.dispose();
    _videoRenderers.remove(peerId)?.dispose();
    
    // Clean up buffers and metadata
    _iceCandidateBuffers.remove(peerId);
    _remoteDescriptionStates.remove(peerId);
    _connectedPeers.remove(peerId);
    _peerMetadata.remove(peerId);
    
    debugPrint('🧹 Cleaned up peer: $peerId');
    notifyListeners();
  }

  Future<void> toggleMute() async {
    if (_localStream != null) {
      _isMuted = !_isMuted;
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !_isMuted;
      });
      notifyListeners();
    }
  }

  Future<void> toggleLocalVideo() async {
    if (_localStream != null) {
      _isVideoEnabled = !_isVideoEnabled;
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled = _isVideoEnabled;
      });
      debugPrint('🎥 Local video ${_isVideoEnabled ? 'enabled' : 'disabled'}');
      notifyListeners();
    }
  }

  Future<void> _waitForConnection() async {
    final completer = Completer<void>();
    
    if (_socket!.connected) {
      completer.complete();
    } else {
      _socket!.once('connect', (_) => completer.complete());
    }
    
    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Socket connection timeout'),
    );
  }

  void _handleDisconnection() {
    _isConnected = false;
    
    // Clean up all peer connections
    for (final peerId in _peerConnections.keys.toList()) {
      _cleanupPeerConnection(peerId);
    }
    
    // Clean up local resources
    _localStream?.dispose();
    _localStream = null;
    
    onDisconnected?.call();
    notifyListeners();
  }

  Future<void> _forceDisconnect() async {
    if (_isDisposed) return;
    
    // Clean up socket
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    
    // Clean up all connections and streams
    _handleDisconnection();
    
    // Reset state
    _currentRoom = null;
    _userId = null;
    _userRole = null;
    _mySocketId = null;
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
```

## Server: unified-webrtc-server.cjs Signaling Handlers

```javascript
// Signaling namespace for basic WebRTC
const signalingNamespace = io.of('/signaling');

signalingNamespace.on('connection', (socket) => {
  console.log(`📡 Signaling client connected: ${socket.id}`);

  socket.on('join-room', async (data) => {
    try {
      const { roomId, userId, role } = data;
      console.log(`📡 Signaling join-room: ${userId} joining room: ${roomId}`);
      
      socket.join(roomId);
      
      // Initialize room if it doesn't exist
      if (!signalingRooms.has(roomId)) {
        signalingRooms.set(roomId, new Map());
      }
      
      const roomParticipants = signalingRooms.get(roomId);
      const participant = { userId, role, socketId: socket.id };
      
      // Send existing participants to the new joiner (FIXED)
      const existingParticipants = Array.from(roomParticipants.values());
      if (existingParticipants.length > 0) {
        console.log(`📡 Sending ${existingParticipants.length} existing participants to ${userId}`);
        for (const existingParticipant of existingParticipants) {
          socket.emit('peer-joined', { 
            peerId: existingParticipant.socketId, 
            userId: existingParticipant.userId, 
            role: existingParticipant.role 
          });
        }
      }
      
      // Add new participant to room
      roomParticipants.set(socket.id, participant);
      
      // Send confirmation to new joiner
      socket.emit('room-joined', { roomId, userId, role, success: true });
      
      // Notify existing participants about new joiner
      socket.to(roomId).emit('peer-joined', { peerId: socket.id, userId, role });

      console.log(`✅ ${userId} joined signaling room ${roomId}`);
      console.log(`🏠 Room ${roomId} now has ${roomParticipants.size} participants`);
    } catch (error) {
      console.error('❌ Signaling join-room error:', error);
      socket.emit('join-room-error', { message: error.message });
    }
  });

  // WebRTC Offer
  socket.on('offer', (data) => {
    const { to, from, sdp, type } = data;
    console.log(`📤 Relaying offer from ${from} to ${to}`);
    socket.to(to).emit('offer', { from, sdp, type });
  });

  // WebRTC Answer
  socket.on('answer', (data) => {
    const { to, from, sdp, type } = data;
    console.log(`📥 Relaying answer from ${from} to ${to}`);
    socket.to(to).emit('answer', { from, sdp, type });
  });

  // ICE Candidates
  socket.on('ice-candidate', (data) => {
    const { to, from, candidate, sdpMid, sdpMLineIndex } = data;
    console.log(`🧊 Relaying ICE candidate from ${from} to ${to}`);
    socket.to(to).emit('ice-candidate', { from, candidate, sdpMid, sdpMLineIndex });
  });

  // Disconnect handling
  socket.on('disconnect', () => {
    console.log(`📡 Signaling client disconnected: ${socket.id}`);
    
    // Notify peers in all signaling rooms
    signalingRooms.forEach((participants, roomId) => {
      if (participants.has(socket.id)) {
        const participant = participants.get(socket.id);
        participants.delete(socket.id);
        
        socket.to(roomId).emit('peer-left', {
          peerId: socket.id,
          userId: participant.userId
        });
        
        console.log(`👋 ${participant.userId} left signaling room ${roomId}`);
      }
    });
  });
});
```

## Key Architecture Points

### Client (SimpleMediaSoupService):
1. **Multi-peer connections** - Maintains separate RTCPeerConnection for each peer
2. **Role-based media** - Moderators/speakers publish video, audience receives only
3. **ICE candidate buffering** - Buffers candidates until remote description is set
4. **Auto-reconnection** - Handles room switching and disconnections gracefully

### Server (Signaling):
1. **Room management** - Tracks participants per room
2. **Peer discovery** - Sends existing peers to new joiners (FIXED)
3. **Message relay** - Relays offers, answers, and ICE candidates
4. **Clean disconnect** - Notifies others when peer leaves

### WebRTC Flow:
1. User joins room → Server sends existing peers
2. Create peer connection for each peer
3. Exchange offers/answers
4. Exchange ICE candidates
5. Media streams flow directly between peers

This is a **mesh network** where each participant connects to every other participant directly. Good for small rooms but doesn't scale well beyond 5-6 participants.