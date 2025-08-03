// Debug script to test video functionality step by step
// Add this to lib/screens/debug_video_setup.dart

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/simple_mediasoup_service.dart';
import '../services/websocket_webrtc_service.dart';
import '../services/sfu_webrtc_service.dart';
// import '../services/mediasoup_sfu_service.dart'; // Disabled due to API incompatibility

class DebugVideoSetupScreen extends StatefulWidget {
  const DebugVideoSetupScreen({super.key});

  @override
  State<DebugVideoSetupScreen> createState() => _DebugVideoSetupScreenState();
}

class _DebugVideoSetupScreenState extends State<DebugVideoSetupScreen> {
  final _webrtcService = SimpleWebRTCService();
  final _websocketService = WebSocketWebRTCService();
  final _sfuService = SFUWebRTCService();
  // final _mediasoupService = MediaSoupSFUService(); // Disabled due to API incompatibility
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  
  final List<String> _debugLogs = [];
  bool _isConnected = false;
  String _currentMode = 'P2P'; // 'P2P', 'WebSocket', or 'SFU'
  
  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _setupWebRTCCallbacks();
  }
  
  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    _addLog('✅ Local renderer initialized');
  }
  
  void _setupWebRTCCallbacks() {
    // Setup MediaSoup SFU callbacks
    // _setupMediaSoupCallbacks(); // Disabled due to API incompatibility
    
    // Setup WebSocket WebRTC callbacks
    _setupWebSocketCallbacks();
    
    // Setup SFU callbacks
    _setupSFUCallbacks();
    
    _webrtcService.onLocalStream = (stream) {
      _addLog('📹 Local stream received');
      _addLog('🎤 Audio tracks: ${stream.getAudioTracks().length}');
      _addLog('🎥 Video tracks: ${stream.getVideoTracks().length}');
      
      if (stream.getVideoTracks().isNotEmpty) {
        setState(() {
          _localRenderer.srcObject = stream;
        });
        _addLog('✅ Local video renderer set');
        
        // Log video track details
        for (final track in stream.getVideoTracks()) {
          _addLog('🎥 Local video track: ${track.id}, enabled: ${track.enabled}');
        }
      } else {
        _addLog('⚠️ No video tracks in local stream');
      }
    };
    
    _webrtcService.onRemoteStream = (peerId, stream, userId, role) {
      _addLog('📡 Remote stream from $userId ($peerId)');
      _addLog('🎤 Remote audio tracks: ${stream.getAudioTracks().length}');
      _addLog('🎥 Remote video tracks: ${stream.getVideoTracks().length}');
      
      if (stream.getVideoTracks().isNotEmpty) {
        _initializeRemoteRenderer(peerId, stream);
        
        // Log video track details
        for (final track in stream.getVideoTracks()) {
          _addLog('🎥 Remote video track: ${track.id}, enabled: ${track.enabled}');
        }
      } else {
        _addLog('⚠️ No video tracks in remote stream from $userId');
      }
    };
    
    _webrtcService.onPeerJoined = (peerId, userId, role) {
      _addLog('👤 Peer joined: $userId ($peerId) as $role');
    };
    
    _webrtcService.onPeerLeft = (peerId) {
      _addLog('👋 Peer left: $peerId');
      _cleanupRemoteRenderer(peerId);
    };
    
    _webrtcService.onError = (error) {
      _addLog('❌ Error: $error');
    };
    
    _webrtcService.onConnected = () {
      setState(() {
        _isConnected = true;
      });
      _addLog('✅ Connected to WebRTC server');
    };
    
    _webrtcService.onDisconnected = () {
      setState(() {
        _isConnected = false;
      });
      _addLog('🔌 Disconnected from WebRTC server');
    };
  }
  
  // void _setupMediaSoupCallbacks() {
  //   _mediasoupService.onLocalStream = (stream) {
  //     _addLog('📹 SFU Local stream received');
  //     _addLog('🎤 SFU Audio tracks: ${stream.getAudioTracks().length}');
  //     _addLog('🎥 SFU Video tracks: ${stream.getVideoTracks().length}');
  //     
  //     if (stream.getVideoTracks().isNotEmpty) {
  //       setState(() {
  //         _localRenderer.srcObject = stream;
  //       });
  //       _addLog('✅ SFU Local video renderer set');
  //     }
  //   };
  //   
  //   _mediasoupService.onRemoteStream = (peerId, stream, userId, role) {
  //     _addLog('📡 SFU Remote stream from $userId ($peerId)');
  //     _addLog('🎤 SFU Remote audio tracks: ${stream.getAudioTracks().length}');
  //     _addLog('🎥 SFU Remote video tracks: ${stream.getVideoTracks().length}');
  //     
  //     if (stream.getVideoTracks().isNotEmpty) {
  //       _initializeRemoteRenderer(peerId, stream);
  //     }
  //   };
  //   
  //   _mediasoupService.onPeerJoined = (peerId, userId, role) {
  //     _addLog('👤 SFU Peer joined: $userId ($peerId) as $role');
  //   };
  //   
  //   _mediasoupService.onPeerLeft = (peerId) {
  //     _addLog('👋 SFU Peer left: $peerId');
  //     _cleanupRemoteRenderer(peerId);
  //   };
  //   
  //   _mediasoupService.onError = (error) {
  //     _addLog('❌ SFU Error: $error');
  //   };
  //   
  //   _mediasoupService.onConnected = () {
  //     setState(() {
  //       _isConnected = true;
  //     });
  //     _addLog('✅ Connected to MediaSoup SFU server');
  //   };
  //   
  //   _mediasoupService.onDisconnected = () {
  //     setState(() {
  //       _isConnected = false;
  //     });
  //     _addLog('🔌 Disconnected from MediaSoup SFU server');
  //   };
  // }
  
  void _setupWebSocketCallbacks() {
    _websocketService.onLocalStream = (stream) {
      _addLog('📹 WebSocket Local stream received');
      _addLog('🎤 WebSocket Audio tracks: ${stream.getAudioTracks().length}');
      _addLog('🎥 WebSocket Video tracks: ${stream.getVideoTracks().length}');
      
      if (stream.getVideoTracks().isNotEmpty) {
        setState(() {
          _localRenderer.srcObject = stream;
        });
        _addLog('✅ WebSocket Local video renderer set');
        
        // Log video track details
        for (final track in stream.getVideoTracks()) {
          _addLog('🎥 WebSocket Local video track: ${track.id}, enabled: ${track.enabled}');
        }
      } else {
        _addLog('⚠️ No video tracks in WebSocket local stream');
      }
    };
    
    _websocketService.onRemoteStream = (peerId, stream, userId, role) {
      _addLog('📡 WebSocket Remote stream from $userId ($peerId)');
      _addLog('🎤 WebSocket Remote audio tracks: ${stream.getAudioTracks().length}');
      _addLog('🎥 WebSocket Remote video tracks: ${stream.getVideoTracks().length}');
      
      if (stream.getVideoTracks().isNotEmpty) {
        _initializeRemoteRenderer(peerId, stream);
        
        // Log video track details
        for (final track in stream.getVideoTracks()) {
          _addLog('🎥 WebSocket Remote video track: ${track.id}, enabled: ${track.enabled}');
        }
      } else {
        _addLog('⚠️ No video tracks in WebSocket remote stream from $userId');
      }
    };
    
    _websocketService.onPeerJoined = (peerId, userId, role) {
      _addLog('👤 WebSocket Peer joined: $userId ($peerId) as $role');
    };
    
    _websocketService.onPeerLeft = (peerId) {
      _addLog('👋 WebSocket Peer left: $peerId');
      _cleanupRemoteRenderer(peerId);
    };
    
    _websocketService.onError = (error) {
      _addLog('❌ WebSocket Error: $error');
    };
    
    _websocketService.onConnected = () {
      setState(() {
        _isConnected = true;
      });
      _addLog('✅ Connected to WebSocket server');
    };
    
    _websocketService.onDisconnected = () {
      setState(() {
        _isConnected = false;
      });
      _addLog('🔌 Disconnected from WebSocket server');
    };
  }
  
  void _setupSFUCallbacks() {
    _sfuService.onLocalStream = (stream) {
      _addLog('📹 SFU Local stream received');
      _addLog('🎤 SFU Audio tracks: ${stream.getAudioTracks().length}');
      _addLog('🎥 SFU Video tracks: ${stream.getVideoTracks().length}');
      
      if (stream.getVideoTracks().isNotEmpty) {
        setState(() {
          _localRenderer.srcObject = stream;
        });
        _addLog('✅ SFU Local video renderer set');
        
        // Log video track details
        for (final track in stream.getVideoTracks()) {
          _addLog('🎥 SFU Local video track: ${track.id}, enabled: ${track.enabled}');
        }
      } else {
        _addLog('⚠️ No video tracks in SFU local stream');
      }
    };
    
    _sfuService.onRemoteStream = (peerId, stream, userId, role) {
      _addLog('📡 SFU Remote stream from $userId ($peerId)');
      _addLog('🎤 SFU Remote audio tracks: ${stream.getAudioTracks().length}');
      _addLog('🎥 SFU Remote video tracks: ${stream.getVideoTracks().length}');
      
      if (stream.getVideoTracks().isNotEmpty) {
        _initializeRemoteRenderer(peerId, stream);
        
        // Log video track details
        for (final track in stream.getVideoTracks()) {
          _addLog('🎥 SFU Remote video track: ${track.id}, enabled: ${track.enabled}');
        }
      } else {
        _addLog('⚠️ No video tracks in SFU remote stream from $userId');
      }
    };
    
    _sfuService.onPeerJoined = (peerId, userId, role) {
      _addLog('👤 SFU Peer joined: $userId ($peerId) as $role');
    };
    
    _sfuService.onPeerLeft = (peerId) {
      _addLog('👋 SFU Peer left: $peerId');
      _cleanupRemoteRenderer(peerId);
    };
    
    _sfuService.onError = (error) {
      _addLog('❌ SFU Error: $error');
    };
    
    _sfuService.onConnected = () {
      setState(() {
        _isConnected = true;
      });
      _addLog('✅ Connected to MediaSoup SFU server');
    };
    
    _sfuService.onDisconnected = () {
      setState(() {
        _isConnected = false;
      });
      _addLog('🔌 Disconnected from MediaSoup SFU server');
    };
  }
  
  Future<void> _initializeRemoteRenderer(String peerId, MediaStream stream) async {
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = stream;
    
    setState(() {
      _remoteRenderers[peerId] = renderer;
    });
    
    _addLog('✅ Remote video renderer initialized for $peerId');
  }
  
  void _cleanupRemoteRenderer(String peerId) {
    final renderer = _remoteRenderers.remove(peerId);
    if (renderer != null) {
      renderer.dispose();
      _addLog('🧹 Cleaned up renderer for $peerId');
    }
  }
  
  void _addLog(String message) {
    setState(() {
      _debugLogs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
    debugPrint(message); // Also print to console
  }
  
  Future<void> _testAsVideoModerator() async {
    _addLog('🎬 Testing as VIDEO MODERATOR (P2P)...');
    _clearLogs();
    _currentMode = 'P2P';
    
    try {
      await _webrtcService.connect(
        '172.236.109.9:3005',
        'debug-video-test',
        'debug-user-moderator',
        audioOnly: false, // VIDEO MODE
        role: 'moderator',
        sfuMode: false, // P2P WebRTC mode
      );
    } catch (e) {
      _addLog('❌ Connection failed: $e');
    }
  }
  
  Future<void> _testAsVideoModeratorSFU() async {
    _addLog('🎬 Testing as VIDEO MODERATOR (MediaSoup SFU)...');
    _clearLogs();
    _currentMode = 'SFU';
    
    try {
      await _sfuService.connect(
        '172.236.109.9:3005',  // MediaSoup SFU server on port 3005
        'debug-sfu-room-${DateTime.now().millisecondsSinceEpoch}',
        'debug-user-${DateTime.now().millisecondsSinceEpoch}',
        audioOnly: false,
        role: 'moderator',
      );
      _addLog('✅ SFU connection request sent');
    } catch (e) {
      _addLog('❌ Failed to connect to MediaSoup SFU: $e');
    }
  }
  
  Future<void> _testAsVideoModeratorWebSocket() async {
    _addLog('🎬 Testing as VIDEO MODERATOR (WebSocket)...');
    _clearLogs();
    _currentMode = 'WebSocket';
    
    try {
      await _websocketService.connect(
        '172.236.109.9:3006',  // WebSocket server on port 3006
        'debug-video-test',
        'debug-user-moderator',
        audioOnly: false, // VIDEO MODE
        role: 'moderator',
      );
    } catch (e) {
      _addLog('❌ WebSocket connection failed: $e');
    }
  }
  
  Future<void> _testAsAudioOnlyAudience() async {
    _addLog('🎧 Testing as AUDIO-ONLY AUDIENCE...');
    _clearLogs();
    
    try {
      await _webrtcService.connect(
        '172.236.109.9:3005',
        'debug-video-test',
        'debug-user-audience',
        audioOnly: true, // AUDIO ONLY MODE
        role: 'audience',
        sfuMode: false, // P2P WebRTC mode
      );
    } catch (e) {
      _addLog('❌ Connection failed: $e');
    }
  }
  
  Future<void> _testVideoPermissions() async {
    _addLog('📹 Testing video permissions directly...');
    _clearLogs();
    
    try {
      final constraints = {
        'audio': true,
        'video': {
          'width': {'ideal': 640},
          'height': {'ideal': 480},
          'frameRate': {'ideal': 30},
          'facingMode': 'user',
        },
      };
      
      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      _addLog('✅ getUserMedia succeeded');
      _addLog('🎤 Audio tracks: ${stream.getAudioTracks().length}');
      _addLog('🎥 Video tracks: ${stream.getVideoTracks().length}');
      
      if (stream.getVideoTracks().isNotEmpty) {
        setState(() {
          _localRenderer.srcObject = stream;
        });
        _addLog('✅ Video preview set');
      }
      
    } catch (e) {
      _addLog('❌ getUserMedia failed: $e');
    }
  }
  
  void _clearLogs() {
    setState(() {
      _debugLogs.clear();
    });
  }
  
  Future<void> _disconnect() async {
    if (_currentMode == 'SFU') {
      await _sfuService.disconnect();
    } else if (_currentMode == 'WebSocket') {
      await _websocketService.disconnect();
    } else {
      await _webrtcService.disconnect();
    }
    _addLog('🔌 Disconnected');
  }
  
  @override
  void dispose() {
    _localRenderer.dispose();
    for (final renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Video Setup'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Control buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8.0,
              children: [
                ElevatedButton(
                  onPressed: _testVideoPermissions,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Test Camera'),
                ),
                ElevatedButton(
                  onPressed: _testAsVideoModerator,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Video P2P'),
                ),
                ElevatedButton(
                  onPressed: _testAsVideoModeratorWebSocket,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text('Video WebSocket'),
                ),
                ElevatedButton(
                  onPressed: _testAsVideoModeratorSFU,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                  child: const Text('Video SFU'),
                ),
                ElevatedButton(
                  onPressed: _testAsAudioOnlyAudience,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Audio Audience'),
                ),
                ElevatedButton(
                  onPressed: _disconnect,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Disconnect'),
                ),
                ElevatedButton(
                  onPressed: _clearLogs,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('Clear Logs'),
                ),
              ],
            ),
          ),
          
          // Status
          Container(
            padding: const EdgeInsets.all(8.0),
            color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
            child: Text(
              'Status: ${_isConnected ? "Connected" : "Disconnected"}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isConnected ? Colors.green.shade800 : Colors.red.shade800,
              ),
            ),
          ),
          
          // Video previews
          SizedBox(
            height: 200,
            child: Row(
              children: [
                // Local video
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          color: Colors.blue,
                          child: const Text('Local Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: _localRenderer.srcObject != null
                              ? RTCVideoView(_localRenderer, mirror: true)
                              : Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(child: Text('No Local Video')),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Remote videos
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          color: Colors.green,
                          child: Text('Remote Videos (${_remoteRenderers.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: _remoteRenderers.isEmpty
                              ? Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(child: Text('No Remote Videos')),
                                )
                              : ListView(
                                  children: _remoteRenderers.entries.map((entry) {
                                    return Container(
                                      height: 100,
                                      margin: const EdgeInsets.all(2),
                                      child: RTCVideoView(entry.value),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Debug logs
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey.shade200,
                    child: const Text('Debug Logs', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      reverse: true, // Show newest logs at top
                      itemCount: _debugLogs.length,
                      itemBuilder: (context, index) {
                        final reversedIndex = _debugLogs.length - 1 - index;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: Text(
                            _debugLogs[reversedIndex],
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}