import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketWebRTCService {
  // WebSocket connection (bypasses Socket.IO)
  WebSocketChannel? _channel;
  bool _isConnected = false;
  String? _clientId;
  String? _currentRoom;
  // WebRTC
  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _remotePeerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  
  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(String peerId, MediaStream stream, String userId, String role)? onRemoteStream;
  Function(String peerId, String userId, String role)? onPeerJoined;
  Function(String peerId)? onPeerLeft;
  Function(String error)? onError;
  Function()? onConnected;
  Function()? onDisconnected;
  
  // STUN servers for NAT traversal with Unified Plan SdpSemantics
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
      // Additional reliable STUN servers
      {'urls': 'stun:stun.stunprotocol.org:3478'},
      {'urls': 'stun:stun.voiparound.com'},
      {'urls': 'stun:stun.voipbuster.com'},
    ],
    'sdpSemantics': 'unified-plan', // Use Unified Plan (modern standard)
    'iceCandidatePoolSize': 10, // Increase ICE candidate pool for better connectivity
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
      debugPrint('🚀 WebSocket WebRTC connect() called with:');
      debugPrint('   serverUrl: $serverUrl');
      debugPrint('   room: $room');
      debugPrint('   userId: $userId');
      debugPrint('   audioOnly: $audioOnly');
      debugPrint('   role: $role');
      
      _currentRoom = room;
      
      // Create WebSocket connection (bypassing Socket.IO)
      final wsUrl = serverUrl.startsWith('http') 
          ? '${serverUrl.replaceFirst('http', 'ws')}/signaling'
          : 'ws://$serverUrl/signaling';
      
      debugPrint('🔌 Connecting to WebSocket: $wsUrl');
      
      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['echo-protocol'], // Optional protocol
      );
      
      // Listen for WebSocket messages (single listener)
      _channel!.stream.listen(
        (data) => _handleWebSocketMessage(data),
        onError: (error) {
          debugPrint('❌ WebSocket error: $error');
          onError?.call('WebSocket error: $error');
        },
        onDone: () {
          debugPrint('🔌 WebSocket connection closed');
          _isConnected = false;
          onDisconnected?.call();
        },
      );
      
      // Wait for connection confirmation with timeout
      await _waitForConnectionSimple();
      
      // Set up local media - audience doesn't need microphone access
      final shouldSetupAudio = role != 'audience';
      await _setupLocalMedia(audioOnly: audioOnly, enableAudio: shouldSetupAudio, role: role);
      
      // Join room
      _sendMessage({
        'type': 'join-room',
        'data': {
          'roomId': room,
          'userId': userId,
          'role': role,
        }
      });
      
      debugPrint('✅ WebSocket WebRTC connection established');
      
    } catch (e) {
      debugPrint('❌ WebSocket connection failed: $e');
      onError?.call('Connection failed: $e');
      rethrow;
    }
  }
  
  Future<void> _waitForConnectionSimple() async {
    // Simple timeout-based wait for connection
    final startTime = DateTime.now();
    const timeout = Duration(seconds: 10);
    
    while (!_isConnected && DateTime.now().difference(startTime) < timeout) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    if (!_isConnected) {
      throw Exception('WebSocket connection timeout after ${timeout.inSeconds} seconds');
    }
    
    debugPrint('✅ WebSocket connection confirmed after ${DateTime.now().difference(startTime).inMilliseconds}ms');
  }
  
  
  Future<void> _setupLocalMedia({bool audioOnly = false, bool enableAudio = true, String role = 'audience'}) async {
    try {
      debugPrint('🎥 Setting up local media (audioOnly: $audioOnly, enableAudio: $enableAudio, role: $role)');
      
      if (!enableAudio && role == 'audience') {
        debugPrint('👂 Audience member - skipping microphone access (receive-only mode)');
        // Audience members don't need local media - they only receive audio
        _localStream = null;
        // Don't call onLocalStream for audience members
        return;
      }
      
      final constraints = {
        'audio': enableAudio,
        'video': audioOnly ? false : {
          'width': {'ideal': 640},
          'height': {'ideal': 480},
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
      // For audience members, continue without media rather than failing
      if (role == 'audience') {
        debugPrint('👂 Audience member - continuing without local media');
        _localStream = null;
        return;
      }
      onError?.call('Failed to get local media: $e');
      rethrow;
    }
  }
  
  void _handleWebSocketMessage(dynamic data) {
    try {
      final message = jsonDecode(data);
      final type = message['type'];
      final messageData = message['data'];
      
      debugPrint('📨 Received WebSocket message: $type');
      
      switch (type) {
        case 'connected':
          _clientId = message['clientId'];
          _isConnected = true;
          debugPrint('✅ WebSocket connected with clientId: $_clientId');
          onConnected?.call();
          break;
          
        case 'room-joined':
          _handleRoomJoined(messageData);
          break;
          
        case 'peer-joined':
          _handlePeerJoined(messageData);
          break;
          
        case 'peer-left':
          _handlePeerLeft(messageData);
          break;
          
        case 'offer':
          _handleOffer(messageData);
          break;
          
        case 'answer':
          _handleAnswer(messageData);
          break;
          
        case 'ice-candidate':
          _handleIceCandidate(messageData);
          break;
          
        case 'error':
          debugPrint('❌ Server error: ${message['message']}');
          onError?.call('Server error: ${message['message']}');
          break;
          
        default:
          debugPrint('❓ Unknown message type: $type');
      }
      
    } catch (e) {
      debugPrint('❌ Error parsing WebSocket message: $e');
    }
  }
  
  void _handleRoomJoined(Map<String, dynamic> data) {
    final roomId = data['roomId'];
    final clientId = data['clientId'];
    final existingClients = data['existingClients'] as List;
    
    debugPrint('✅ Joined room: $roomId as client: $clientId');
    debugPrint('👥 Existing clients: ${existingClients.length}');
    
    // Create peer connections for existing clients
    for (final client in existingClients) {
      final peerId = client['clientId'];
      final userId = client['userId'];
      final role = client['role'];
      
      debugPrint('🔗 Creating peer connection for: $userId ($peerId)');
      
      // Use client ID comparison to determine who initiates
      final myClientId = _clientId ?? '';
      final shouldInitiate = myClientId.compareTo(peerId) > 0;
      
      debugPrint('🎯 Client comparison: mine=$myClientId, theirs=$peerId, shouldInitiate=$shouldInitiate');
      _createPeerConnection(peerId, userId, role, isInitiator: shouldInitiate);
    }
  }
  
  void _handlePeerJoined(Map<String, dynamic> data) {
    final peerId = data['clientId'];
    final userId = data['userId'];
    final role = data['role'];
    
    debugPrint('👤 Peer joined: $userId ($peerId) as $role');
    onPeerJoined?.call(peerId, userId, role);
    
    // Use client ID comparison to determine who initiates (same logic as room-joined)
    final myClientId = _clientId ?? '';
    final shouldInitiate = myClientId.compareTo(peerId) > 0;
    
    debugPrint('🎯 New peer comparison: mine=$myClientId, theirs=$peerId, shouldInitiate=$shouldInitiate');
    _createPeerConnection(peerId, userId, role, isInitiator: shouldInitiate);
  }
  
  void _handlePeerLeft(Map<String, dynamic> data) {
    final peerId = data['clientId'];
    final userId = data['userId'];
    
    debugPrint('👋 Peer left: $userId ($peerId)');
    onPeerLeft?.call(peerId);
    
    // Clean up peer connection
    _remotePeerConnections[peerId]?.close();
    _remotePeerConnections.remove(peerId);
    _remoteStreams.remove(peerId);
  }
  
  Future<void> _createPeerConnection(String peerId, String userId, String role, {required bool isInitiator}) async {
    try {
      debugPrint('🔨 Creating peer connection for $peerId ($userId) - isInitiator: $isInitiator');
      final peerConnection = await createPeerConnection(_iceServers);
      
      // Give the peer connection a moment to fully initialize
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Verify the peer connection was created properly
      final initialState = peerConnection.signalingState;
      debugPrint('🔍 Initial signaling state for $peerId: $initialState');
      
      _remotePeerConnections[peerId] = peerConnection;
      
      // Add local stream using Unified Plan API
      if (_localStream != null) {
        try {
          // Use addTrack for Unified Plan (modern WebRTC)
          for (final track in _localStream!.getTracks()) {
            await peerConnection.addTrack(track, _localStream!);
          }
          debugPrint('➕ Added local tracks to peer connection for $peerId');
        } catch (e) {
          debugPrint('❌ Failed to add tracks to peer connection for $peerId: $e');
          rethrow; // Don't continue if we can't add tracks
        }
      }
      
      // Handle remote tracks (Unified Plan - modern API)
      peerConnection.onTrack = (event) {
        debugPrint('📡 Received remote track from $peerId ($userId)');
        debugPrint('🎵 Track kind: ${event.track.kind}');
        debugPrint('🎵 Track enabled: ${event.track.enabled}');
        
        if (event.streams.isNotEmpty) {
          final stream = event.streams.first;
          _remoteStreams[peerId] = stream;
          
          debugPrint('🎊 REMOTE STREAM RECEIVED from $userId!');
          debugPrint('🎤 Audio tracks in stream: ${stream.getAudioTracks().length}');
          debugPrint('🎥 Video tracks in stream: ${stream.getVideoTracks().length}');
          
          onRemoteStream?.call(peerId, stream, userId, role);
        }
      };
      
      // Handle ICE candidates
      peerConnection.onIceCandidate = (candidate) {
        if (candidate.candidate != null && _isConnected) {
          // Only send ICE candidates if WebSocket is connected
          // Reduce logging noise - only log first few candidates
          if (_remotePeerConnections.length <= 2) {
            debugPrint('🧊 Sending ICE candidate to $peerId');
          }
          _sendMessage({
            'type': 'ice-candidate',
            'data': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
              'to': peerId,
            }
          });
        } else if (candidate.candidate != null && !_isConnected) {
          // Silently skip if not connected (reduce log spam)
          debugPrint('🧊 Skipping ICE candidate - WebSocket disconnected');
        }
      };
      
      // Handle connection state changes
      peerConnection.onConnectionState = (state) {
        debugPrint('🔗 Peer connection state with $peerId: $state');
        
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          debugPrint('🎉 PEER CONNECTED! Audio should now flow with $peerId ($userId)');
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          debugPrint('❌ Peer connection failed with $peerId ($userId)');
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          debugPrint('🔌 Peer disconnected: $peerId ($userId)');
        }
      };
      
      // If we're the initiator, create and send offer
      if (isInitiator) {
        debugPrint('🎯 Creating offer for $peerId (skipping signaling state wait)');
        
        // Small delay to ensure peer connection is ready
        await Future.delayed(const Duration(milliseconds: 100));
        
        try {
          final offer = await peerConnection.createOffer();
          await peerConnection.setLocalDescription(offer);
          
          debugPrint('📤 Sending offer to $peerId');
          _sendMessage({
            'type': 'offer',
            'data': {
              'sdp': offer.sdp,
              'type': offer.type,
              'to': peerId,
            }
          });
          
          debugPrint('✅ Offer created and sent successfully for $peerId');
        } catch (e) {
          debugPrint('❌ Failed to create offer for $peerId: $e');
        }
      }
      
    } catch (e) {
      debugPrint('❌ Failed to create peer connection for $peerId: $e');
      onError?.call('Failed to create peer connection: $e');
    }
  }
  
  void _handleOffer(Map<String, dynamic> data) async {
    final from = data['from'];
    final fromUserId = data['fromUserId'];
    final sdp = data['sdp'];
    final type = data['type'];
    
    debugPrint('📥 Received offer from $from ($fromUserId)');
    
    // If no peer connection exists, create one (race condition fix)
    var peerConnection = _remotePeerConnections[from];
    if (peerConnection == null) {
      debugPrint('🔧 No peer connection found for $from, creating one...');
      // When receiving an offer, we are not the initiator
      await _createPeerConnection(from, fromUserId, 'audience', isInitiator: false);
      peerConnection = _remotePeerConnections[from];
      
      if (peerConnection == null) {
        debugPrint('❌ Failed to create peer connection for $from');
        return;
      }
    }
    
    try {
      // Check signaling state to avoid wrong state errors
      final currentState = peerConnection.signalingState;
      debugPrint('🔍 Current signaling state for offer from $from: $currentState');
      
      // Skip signaling state checks - directly process offer
      debugPrint('🎯 Processing offer directly without signaling state wait');
      
      try {
        // Set remote description
        await peerConnection.setRemoteDescription(
          RTCSessionDescription(sdp, type)
        );
        
        debugPrint('✅ Set remote description for offer from $from');
        
        // Create and set local answer
        final answer = await peerConnection.createAnswer();
        await peerConnection.setLocalDescription(answer);
        
        debugPrint('📤 Sending answer to $from');
        _sendMessage({
          'type': 'answer',
          'data': {
            'sdp': answer.sdp,
            'type': answer.type,
            'to': from,
          }
        });
        
        debugPrint('✅ Answer sent successfully to $from');
        
      } catch (e) {
        debugPrint('❌ Error processing offer from $from: $e');
        // Continue anyway - don't fail completely
      }
      
    } catch (e) {
      debugPrint('❌ Failed to handle offer from $from: $e');
      onError?.call('Failed to handle offer: $e');
    }
  }
  
  void _handleAnswer(Map<String, dynamic> data) async {
    final from = data['from'];
    final fromUserId = data['fromUserId'];
    final sdp = data['sdp'];
    final type = data['type'];
    
    debugPrint('📥 Received answer from $from ($fromUserId)');
    
    final peerConnection = _remotePeerConnections[from];
    if (peerConnection == null) {
      debugPrint('❌ No peer connection found for $from');
      return;
    }
    
    try {
      // Check current state before setting remote description
      final currentState = peerConnection.signalingState;
      debugPrint('🔍 Current signaling state before setting answer: $currentState');
      
      // Only set remote description if we're in the correct state
      if (currentState == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        await peerConnection.setRemoteDescription(
          RTCSessionDescription(sdp, type)
        );
        debugPrint('✅ Set remote description for answer from $from');
      } else if (currentState == RTCSignalingState.RTCSignalingStateStable) {
        debugPrint('⚠️ Connection already stable, ignoring duplicate answer from $from');
        return;
      } else {
        debugPrint('⚠️ Unexpected state $currentState for answer from $from, skipping');
        return;
      }
      
    } catch (e) {
      debugPrint('❌ Failed to handle answer from $from: $e');
      onError?.call('Failed to handle answer: $e');
    }
  }
  
  void _handleIceCandidate(Map<String, dynamic> data) async {
    final from = data['from'];
    final fromUserId = data['fromUserId'];
    final candidate = data['candidate'];
    final sdpMid = data['sdpMid'];
    final sdpMLineIndex = data['sdpMLineIndex'];
    
    // Reduce logging noise - only log first few candidates per peer
    if (_remotePeerConnections.length <= 2) {
      debugPrint('🧊 Received ICE candidate from $from ($fromUserId)');
    }
    
    final peerConnection = _remotePeerConnections[from];
    if (peerConnection == null) {
      debugPrint('❌ No peer connection found for $from');
      return;
    }
    
    try {
      await peerConnection.addCandidate(
        RTCIceCandidate(candidate, sdpMid, sdpMLineIndex)
      );
      if (_remotePeerConnections.length <= 2) {
        debugPrint('✅ Added ICE candidate from $from');
      }
      
    } catch (e) {
      debugPrint('❌ Failed to add ICE candidate from $from: $e');
      // Don't propagate ICE candidate errors as they're not critical
      // onError?.call('Failed to add ICE candidate: $e');
    }
  }
  
  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(message));
    } else {
      debugPrint('❌ Cannot send message: WebSocket not connected');
    }
  }
  
  Future<void> disconnect() async {
    debugPrint('🔌 Disconnecting WebSocket WebRTC service');
    
    // Close all peer connections
    for (final peerConnection in _remotePeerConnections.values) {
      await peerConnection.close();
    }
    _remotePeerConnections.clear();
    _remoteStreams.clear();
    
    // Stop local media
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      await _localStream!.dispose();
      _localStream = null;
    }
    
    // Close WebSocket
    if (_channel != null) {
      _sendMessage({
        'type': 'leave-room',
        'data': {'roomId': _currentRoom}
      });
      await _channel!.sink.close();
      _channel = null;
    }
    
    _isConnected = false;
    _clientId = null;
    _currentRoom = null;
    
    onDisconnected?.call();
    debugPrint('✅ WebSocket WebRTC service disconnected');
  }
}