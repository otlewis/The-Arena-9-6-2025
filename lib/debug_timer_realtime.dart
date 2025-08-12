import 'package:flutter/material.dart';
import 'services/appwrite_service.dart';
import 'models/timer_state.dart';
import 'services/appwrite_timer_service.dart';

/// Debug screen to test realtime timer connections
class DebugTimerRealtime extends StatefulWidget {
  const DebugTimerRealtime({super.key});

  @override
  State<DebugTimerRealtime> createState() => _DebugTimerRealtimeState();
}

class _DebugTimerRealtimeState extends State<DebugTimerRealtime> {
  final AppwriteTimerService _timerService = AppwriteTimerService();
  final AppwriteService _appwriteService = AppwriteService();
  // ignore: prefer_final_fields
  List<String> _logs = [];
  List<TimerState> _timers = [];
  
  @override
  void initState() {
    super.initState();
    _startDebugTest();
  }
  
  void _addLog(String message) {
    if (mounted) {
      setState(() {
        _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
        if (_logs.length > 20) _logs.removeAt(0);
      });
    }
    // debugPrint('🔍 DEBUG: $message'); // Disabled for production
  }
  
  Future<void> _startDebugTest() async {
    _addLog('Starting debug test...');
    
    try {
      // Test 1: Initialize service
      await _timerService.initialize();
      _addLog('✅ Timer service initialized');
      
      // Test 2: Test direct database access
      final response = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'timers',
      );
      _addLog('✅ Database access works: ${response.documents.length} timers found');
      
      // Test 3: Subscribe to realtime updates
      _addLog('🔔 Setting up realtime subscription...');
      _timerService.getRoomTimersStream('test-room-123').listen(
        (timers) {
          _addLog('📡 Realtime update received: ${timers.length} timers');
          setState(() {
            _timers = timers;
          });
        },
        onError: (error) {
          _addLog('❌ Realtime error: $error');
        },
      );
      
      // Test 4: Test realtime with manual subscription
      const channel = 'databases.arena_db.collections.timers.documents';
      _addLog('🔔 Manual realtime test channel: $channel');
      
      final subscription = _appwriteService.realtime.subscribe([channel]);
      subscription.stream.listen(
        (response) {
          _addLog('📡 Manual realtime: ${response.events} - ${response.payload}');
        },
        onError: (error) {
          _addLog('❌ Manual realtime error: $error');
        },
      );
      
    } catch (e) {
      _addLog('❌ Error in debug test: $e');
    }
  }
  
  Future<void> _createTestTimer() async {
    try {
      _addLog('🔨 Creating test timer...');
      final timerId = await _timerService.createTimer(
        roomId: 'test-room-123',
        roomType: RoomType.openDiscussion,
        timerType: TimerType.general,
        durationSeconds: 60,
        createdBy: 'debug-user',
      );
      _addLog('✅ Timer created: $timerId');
    } catch (e) {
      _addLog('❌ Create timer error: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Timer Realtime'),
        actions: [
          IconButton(
            onPressed: _createTestTimer,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          // Current timers
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Timers: ${_timers.length}', 
                     style: const TextStyle(fontWeight: FontWeight.bold)),
                ...(_timers.map((timer) => Text(
                  'Timer: ${timer.id} - ${timer.status.name} - ${timer.remainingSeconds}s'
                ))),
              ],
            ),
          ),
          
          // Debug logs
          Expanded(
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return ListTile(
                  title: Text(
                    log,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: log.contains('❌') ? Colors.red :
                             log.contains('✅') ? Colors.green :
                             log.contains('📡') ? Colors.blue :
                             Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}