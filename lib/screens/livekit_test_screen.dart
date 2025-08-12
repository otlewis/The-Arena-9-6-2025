import 'package:flutter/material.dart';
import '../services/livekit_service.dart';
import '../services/livekit_token_service.dart';

/// Test screen to verify LiveKit connection and basic functionality
/// This screen helps validate the LiveKit infrastructure before migration
class LiveKitTestScreen extends StatefulWidget {
  const LiveKitTestScreen({super.key});

  @override
  State<LiveKitTestScreen> createState() => _LiveKitTestScreenState();
}

class _LiveKitTestScreenState extends State<LiveKitTestScreen> {
  final LiveKitService _liveKitService = LiveKitService();
  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _identityController = TextEditingController();
  
  String _selectedRole = 'moderator';
  String _selectedRoomType = 'open_discussion';
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _errorMessage;
  String? _successMessage;
  final List<String> _connectionLogs = [];
  
  final List<String> _roles = [
    'moderator',
    'speaker',
    'audience',
    'affirmative',
    'negative',
    'judge'
  ];
  
  final List<String> _roomTypes = [
    'open_discussion',
    'debate_discussion',
    'arena'
  ];

  @override
  void initState() {
    super.initState();
    
    // Default test values  
    _serverController.text = 'ws://172.236.109.9:7880';
    _roomController.text = 'test-room-${DateTime.now().millisecondsSinceEpoch}';
    _identityController.text = 'test-user-${DateTime.now().millisecondsSinceEpoch % 10000}';
    
    _setupLiveKitCallbacks();
    _addLog('LiveKit test screen initialized');
  }

  @override
  void dispose() {
    _liveKitService.disconnect();
    _serverController.dispose();
    _roomController.dispose();
    _identityController.dispose();
    super.dispose();
  }

  void _setupLiveKitCallbacks() {
    _liveKitService.onConnected = () {
      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _successMessage = 'Successfully connected to LiveKit!';
        _errorMessage = null;
      });
      _addLog('✅ Connected to LiveKit room');
    };

    _liveKitService.onDisconnected = () {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _successMessage = null;
      });
      _addLog('🔌 Disconnected from LiveKit room');
    };

    _liveKitService.onError = (error) {
      setState(() {
        _errorMessage = error;
        _isConnecting = false;
      });
      _addLog('❌ Error: $error');
    };

    _liveKitService.onParticipantConnected = (participant) {
      _addLog('👤 Participant joined: ${participant.identity}');
    };

    _liveKitService.onParticipantDisconnected = (participant) {
      _addLog('👤 Participant left: ${participant.identity}');
    };

    _liveKitService.onTrackSubscribed = (publication, participant) {
      _addLog('🎵 Track subscribed: ${publication.kind} from ${participant.identity}');
    };
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().split(' ')[1].substring(0, 8);
    setState(() {
      _connectionLogs.insert(0, '[$timestamp] $message');
      if (_connectionLogs.length > 20) {
        _connectionLogs.removeLast();
      }
    });
    debugPrint(message);
  }

  Future<void> _testServerConnectivity() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      _addLog('🔍 Testing server connectivity...');
      
      final isReachable = await _liveKitService.testServerConnectivity(_serverController.text);
      
      if (isReachable) {
        setState(() {
          _successMessage = 'Server is reachable!';
          _errorMessage = null;
        });
        _addLog('✅ Server connectivity test passed');
      } else {
        setState(() {
          _errorMessage = 'Server is not reachable';
        });
        _addLog('❌ Server connectivity test failed');
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Connectivity test failed: $error';
      });
      _addLog('❌ Connectivity test error: $error');
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _connectToRoom() async {
    if (_isConnected) {
      await _disconnect();
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      _addLog('🔗 Generating token...');
      
      // Generate token for the test
      final token = LiveKitTokenService.generateToken(
        roomName: _roomController.text,
        identity: _identityController.text,
        userRole: _selectedRole,
        roomType: _selectedRoomType,
        userId: 'test-user-id',
        ttl: const Duration(hours: 1),
      );

      _addLog('🔑 Token generated successfully');
      _addLog('🚀 Connecting to room...');

      // Connect to the room
      await _liveKitService.connect(
        serverUrl: _serverController.text,
        roomName: _roomController.text,
        token: token,
        userId: 'test-user-id',
        userRole: _selectedRole,
        roomType: _selectedRoomType,
      );

    } catch (error) {
      setState(() {
        _errorMessage = 'Connection failed: $error';
        _isConnecting = false;
      });
      _addLog('❌ Connection failed: $error');
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _isConnecting = true;
    });
    
    _addLog('🔌 Disconnecting...');
    await _liveKitService.disconnect();
    
    setState(() {
      _isConnected = false;
      _isConnecting = false;
      _successMessage = null;
    });
    
    _addLog('✅ Disconnected successfully');
  }

  Future<void> _toggleMute() async {
    if (!_isConnected) return;
    
    await _liveKitService.toggleMute();
    _addLog('🔇 Toggled mute: ${_liveKitService.isMuted ? 'Muted' : 'Unmuted'}');
  }

  void _clearLogs() {
    setState(() {
      _connectionLogs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LiveKit Test'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status
            Card(
              color: _isConnected ? Colors.green[50] : Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _isConnected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _isConnected ? Colors.green : Colors.grey,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isConnected ? Colors.green : Colors.grey,
                      ),
                    ),
                    if (_isConnected) ...[
                      const SizedBox(height: 8),
                      Text('Room: ${_liveKitService.currentRoom}'),
                      Text('Role: ${_liveKitService.userRole}'),
                      Text('Participants: ${_liveKitService.connectedPeersCount + 1}'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Connection Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connection Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _serverController,
                      decoration: const InputDecoration(
                        labelText: 'LiveKit Server URL',
                        hintText: 'wss://your-server.com',
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextField(
                      controller: _roomController,
                      decoration: const InputDecoration(
                        labelText: 'Room Name',
                        prefixIcon: Icon(Icons.meeting_room),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextField(
                      controller: _identityController,
                      decoration: const InputDecoration(
                        labelText: 'User Identity',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              prefixIcon: Icon(Icons.badge),
                            ),
                            items: _roles.map((role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            )).toList(),
                            onChanged: (value) => setState(() => _selectedRole = value!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedRoomType,
                            decoration: const InputDecoration(
                              labelText: 'Room Type',
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: _roomTypes.map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.replaceAll('_', ' ')),
                            )).toList(),
                            onChanged: (value) => setState(() => _selectedRoomType = value!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnecting ? null : _testServerConnectivity,
                    icon: const Icon(Icons.wifi_find),
                    label: const Text('Test Connectivity'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnecting ? null : _connectToRoom,
                    icon: Icon(_isConnected ? Icons.stop : Icons.play_arrow),
                    label: Text(_isConnected ? 'Disconnect' : 'Connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            if (_isConnected) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleMute,
                      icon: Icon(_liveKitService.isMuted ? Icons.mic_off : Icons.mic),
                      label: Text(_liveKitService.isMuted ? 'Unmute' : 'Mute'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _liveKitService.isMuted ? Colors.orange : Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (_isConnecting) ...[
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],

            // Status Messages
            if (_errorMessage != null || _successMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _errorMessage != null ? Colors.red[50] : Colors.green[50],
                  border: Border.all(
                    color: _errorMessage != null ? Colors.red : Colors.green,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage ?? _successMessage ?? '',
                  style: TextStyle(
                    color: _errorMessage != null ? Colors.red[800] : Colors.green[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Connection Logs
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connection Logs',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _connectionLogs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              _connectionLogs[index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
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
      ),
    );
  }
}