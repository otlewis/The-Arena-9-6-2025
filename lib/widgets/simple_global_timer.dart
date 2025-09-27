import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../constants/appwrite.dart';
import '../core/logging/app_logger.dart';

class SimpleGlobalTimer extends StatefulWidget {
  final String roomId;
  final String userId;
  final bool isModerator;
  final Widget child;
  
  const SimpleGlobalTimer({
    super.key,
    required this.roomId,
    required this.userId,
    required this.isModerator,
    required this.child,
  });

  @override
  State<SimpleGlobalTimer> createState() => _SimpleGlobalTimerState();
}

class _SimpleGlobalTimerState extends State<SimpleGlobalTimer> {
  int _displaySeconds = 0;
  bool _isVisible = false;
  String _status = 'stopped';
  String? _currentTimerId;
  Timer? _pollingTimer;
  
  final Client _client = Client()
    ..setEndpoint(AppwriteConstants.endpoint)
    ..setProject(AppwriteConstants.projectId);
  
  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Check for timer updates every 1 second
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _checkForTimer();
    });
  }

  Future<void> _checkForTimer() async {
    try {
      final databases = Databases(_client);
      
      final result = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'timers',
        queries: [
          Query.equal('roomId', widget.roomId),
          Query.equal('isActive', true),
        ],
      );

      if (result.documents.isEmpty) {
        if (_isVisible) {
          setState(() {
            _isVisible = false;
            _displaySeconds = 0;
            _status = 'stopped';
            _currentTimerId = null;
          });
        }
        return;
      }

      final timer = result.documents.first;
      final newSeconds = timer.data['remainingSeconds'] ?? 0;
      final newStatus = timer.data['status'] ?? 'stopped';
      final newTimerId = timer.$id;
      
      setState(() {
        _displaySeconds = newSeconds;
        _status = newStatus;
        _currentTimerId = newTimerId;
        _isVisible = newSeconds > 0 || newStatus != 'stopped';
      });
    } catch (e) {
      AppLogger().error('Failed to check timer: $e');
    }
  }

  Future<void> _callTimerController(String action, Map<String, dynamic> data) async {
    try {
      final functions = Functions(_client);
      
      final response = await functions.createExecution(
        functionId: 'timer-controller',
        body: jsonEncode({
          'action': action,
          'data': data,
        }),
        xasync: false,
      );

      final result = jsonDecode(response.responseBody);
      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Timer operation failed');
      }
    } catch (e) {
      AppLogger().error('Timer controller error: $e');
    }
  }

  void _showTimerControls() {
    if (!widget.isModerator) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TimerControlsSheet(
        onSetTimer: (minutes, seconds) async {
          final totalSeconds = (minutes * 60) + seconds;
          await _callTimerController('create', {
            'roomId': widget.roomId,
            'roomType': 'arena',
            'timerType': 'general',
            'durationSeconds': totalSeconds,
            'createdBy': widget.userId,
            'title': 'Arena Timer',
          });
        },
        onStartTimer: () async {
          if (_currentTimerId != null) {
            await _callTimerController('start', {
              'timerId': _currentTimerId!,
              'userId': widget.userId,
            });
          }
        },
        onStopTimer: () async {
          if (_currentTimerId != null) {
            await _callTimerController('stop', {
              'timerId': _currentTimerId!,
              'userId': widget.userId,
            });
          }
        },
        currentSeconds: _displaySeconds,
        status: _status,
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Color _getTimerColor() {
    switch (_status) {
      case 'running':
        return _displaySeconds <= 30 ? Colors.red : Colors.green;
      case 'paused':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Timer display - visible on ALL screens when active
        if (_isVisible)
          Positioned(
            top: 50,
            left: 20,
            child: GestureDetector(
              onTap: widget.isModerator ? _showTimerControls : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getTimerColor(),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _status == 'running' ? Icons.timer : Icons.pause,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(_displaySeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // Moderator timer button - only visible when no active timer
        if (widget.isModerator && !_isVisible)
          Positioned(
            top: 50,
            left: 20,
            child: FloatingActionButton.small(
              heroTag: "simple_timer_fab_${widget.roomId}",
              onPressed: _showTimerControls,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.timer, color: Colors.white, size: 18),
            ),
          ),
      ],
    );
  }
}

class _TimerControlsSheet extends StatefulWidget {
  final Function(int minutes, int seconds) onSetTimer;
  final VoidCallback onStartTimer;
  final VoidCallback onStopTimer;
  final int currentSeconds;
  final String status;

  const _TimerControlsSheet({
    required this.onSetTimer,
    required this.onStartTimer,
    required this.onStopTimer,
    required this.currentSeconds,
    required this.status,
  });

  @override
  State<_TimerControlsSheet> createState() => _TimerControlsSheetState();
}

class _TimerControlsSheetState extends State<_TimerControlsSheet> {
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _secondsController = TextEditingController();

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          Text(
            'Timer Controls',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          
          // Current timer display
          if (widget.currentSeconds > 0) ...[
            Text(
              'Current: ${_formatTime(widget.currentSeconds)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (widget.status != 'running')
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.onStartTimer();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onStopTimer();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
          ],
          
          // Set new timer
          const Text('Set New Timer', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Min',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _secondsController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Sec',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          
          ElevatedButton(
            onPressed: () async {
              // Capture Navigator before async operations to avoid BuildContext async gap
              final navigator = Navigator.of(context);
              
              final minutes = int.tryParse(_minutesController.text) ?? 0;
              final seconds = int.tryParse(_secondsController.text) ?? 0;
              if (minutes > 0 || seconds > 0) {
                await widget.onSetTimer(minutes, seconds);
                if (mounted) {
                  navigator.pop();
                }
              }
            },
            child: const Text('Set Timer'),
          ),
        ],
      ),
    );
  }
}