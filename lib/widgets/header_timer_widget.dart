import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/logging/app_logger.dart';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';

/// Compact timer widget for debates header with hybrid sync
///
/// Shows: "Speaker Name - MM:SS"
/// Uses n8n for authority sync + local interpolation
class HeaderTimerWidget extends StatefulWidget {
  final String roomId;
  final String roomType;
  final bool isModerator;
  final String userId;

  const HeaderTimerWidget({
    Key? key,
    required this.roomId,
    required this.roomType,
    required this.isModerator,
    required this.userId,
  }) : super(key: key);

  @override
  State<HeaderTimerWidget> createState() => _HeaderTimerWidgetState();
}

class _HeaderTimerWidgetState extends State<HeaderTimerWidget> {
  final AppwriteService _appwrite = AppwriteService();
  static const String _n8nUrl = 'https://50.21.187.76/webhook/timer-get/timer';

  // Server state
  double _serverRemaining = 0;
  DateTime _lastSyncTime = DateTime.now();
  String _timerState = 'stopped';

  // Local display state
  double _displayRemaining = 0;

  // Timers
  Timer? _authoritySync;
  Timer? _displayUpdate;
  RealtimeSubscription? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _initializeHybridTimer();
  }

  Future<void> _initializeHybridTimer() async {
    try {
      final documentId = widget.roomId;

      // Subscribe to Appwrite Realtime for instant state changes
      final channel = 'databases.arena_db.collections.timers.documents.$documentId';
      _realtimeSubscription = _appwrite.realtime.subscribe([channel]);

      _realtimeSubscription!.stream.listen(
        (response) {
          if (mounted) {
            // Immediately sync on state change
            _syncWithN8n();
          }
        },
        onError: (error) {
          AppLogger().error('🕐 Timer subscription error: $error');
        },
      );

      // Initial sync
      await _syncWithN8n();

      // Authority sync every 2 seconds
      _authoritySync = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _syncWithN8n(),
      );

      // Display update every 100ms
      _displayUpdate = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _updateDisplay(),
      );
    } catch (e) {
      AppLogger().error('🕐 Failed to initialize timer: $e');
    }
  }

  Future<void> _syncWithN8n() async {
    try {
      final url = '$_n8nUrl/${widget.roomId}';
      AppLogger().debug('🕐 Syncing with n8n: $url');

      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 3));

      AppLogger().debug('🕐 n8n response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger().info('🕐 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        AppLogger().info('🕐 n8n FULL RESPONSE: $data');
        AppLogger().info('🕐   state: ${data['state']}');
        AppLogger().info('🕐   elapsed: ${data['elapsed']}');
        AppLogger().info('🕐   remaining: ${data['remaining']}');
        AppLogger().info('🕐   duration: ${data['duration']}');
        AppLogger().info('🕐   started_at: ${data['started_at']}');
        AppLogger().info('🕐   server_timestamp: ${data['server_timestamp']}');
        AppLogger().info('🕐 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        if (mounted) {
          setState(() {
            _serverRemaining = (data['remaining'] as num).toDouble();
            _displayRemaining = _serverRemaining;
            _lastSyncTime = DateTime.now();
            _timerState = data['state'] ?? 'stopped';
          });
          AppLogger().info('🕐 Timer synced: ${_formatTime(_displayRemaining)} ($_timerState)');
        }
      } else {
        AppLogger().warning('🕐 n8n returned status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      AppLogger().warning('🕐 n8n sync failed (using last known state): $e');
    }
  }

  void _updateDisplay() {
    if (!mounted || _timerState != 'running') return;

    final elapsed = DateTime.now().difference(_lastSyncTime).inMilliseconds / 1000;
    final interpolated = _serverRemaining - elapsed;

    setState(() {
      _displayRemaining = interpolated > 0 ? interpolated : 0;
    });
  }

  String _formatTime(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color _getTimerColor() {
    if (_displayRemaining <= 10 && _timerState == 'running') {
      return Colors.red;
    } else if (_displayRemaining <= 30 && _timerState == 'running') {
      return Colors.orange;
    } else if (_timerState == 'running') {
      return Colors.green;
    } else if (_timerState == 'paused') {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  Future<void> _createTimer(int durationSeconds) async {
    try {
      // Create valid Appwrite document ID (max 36 chars, alphanumeric + . - _)
      final documentId = widget.roomId;

      AppLogger().info('🕐 Creating timer document: $documentId');

      try {
        // Delete existing timer if it exists
        try {
          AppLogger().info('🕐 Attempting to delete timer: $documentId');
          await _appwrite.databases.deleteDocument(
            databaseId: 'arena_db',
            collectionId: 'timers',
            documentId: documentId,
          );
          AppLogger().info('🕐 ✅ Successfully deleted old timer');

          // Wait a moment for deletion to propagate
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          // Document doesn't exist, that's fine
          AppLogger().info('🕐 No existing timer to delete (error: $e)');
        }

        // Create fresh timer document
        AppLogger().info('🕐 Creating new timer with duration: $durationSeconds seconds');
        final newDoc = await _appwrite.databases.createDocument(
          databaseId: 'arena_db',
          collectionId: 'timers',
          documentId: documentId,
          data: {
            'roomId': widget.roomId,
            'roomType': widget.roomType,
            'timerType': 'general',
            'status': 'stopped',
            'durationSeconds': durationSeconds,
            'remainingSeconds': durationSeconds,
            'createdBy': widget.userId,
          },
        );
        AppLogger().info('🕐 ✅ Timer created successfully: ${newDoc.data}');
      } catch (e) {
        AppLogger().error('🕐 ❌ Failed to create timer document: $e');
        rethrow;
      }

      // Sync immediately to show the timer
      await _syncWithN8n();
    } catch (e) {
      AppLogger().error('🕐 Failed to create timer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create timer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startTimer() async {
    try {
      final documentId = widget.roomId;
      final startTime = DateTime.now().toIso8601String();

      AppLogger().info('🕐 Setting timer to running with startTime: $startTime');

      final updatedDoc = await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'timers',
        documentId: documentId,
        data: {
          'status': 'running',
          'startTime': startTime,
        },
      );

      AppLogger().info('🕐 Timer started - Appwrite response: ${updatedDoc.data}');

      // Force immediate sync to see what n8n calculates
      await Future.delayed(const Duration(milliseconds: 100));
      await _syncWithN8n();

    } catch (e) {
      AppLogger().error('🕐 Failed to start timer: $e');
    }
  }

  Future<void> _pauseTimer() async {
    try {
      final documentId = widget.roomId;

      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'timers',
        documentId: documentId,
        data: {
          'status': 'paused',
        },
      );

      AppLogger().info('🕐 Timer paused');
    } catch (e) {
      AppLogger().error('🕐 Failed to pause timer: $e');
    }
  }

  void _showCreateTimerDialog() {
    if (!widget.isModerator) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.timer, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Create Speaking Timer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildPresetButton('3:00', 180),
                _buildPresetButton('2:00', 120),
                _buildPresetButton('5:00', 300),
                _buildPresetButton('1:00', 60),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, int seconds) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _createTimer(seconds);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade700),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showTimerControls() {
    if (!widget.isModerator) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Timer: ${_formatTime(_displayRemaining)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (_timerState == 'stopped')
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _startTimer();
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                if (_timerState == 'running')
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _pauseTimer();
                    },
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                if (_timerState == 'paused')
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _startTimer();
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showCreateTimerDialog();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('New Timer'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show placeholder if no timer synced yet
    if (_displayRemaining == 0 && _timerState == 'stopped') {
      return GestureDetector(
        onTap: widget.isModerator ? _showCreateTimerDialog : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF4A4A4A).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.grey.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.timer,
                color: Colors.grey,
                size: 12,
              ),
              const SizedBox(width: 3),
              Text(
                '--:--',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (widget.isModerator) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.add_circle_outline,
                  color: Colors.grey[600],
                  size: 10,
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Show actual timer
    return GestureDetector(
      onTap: widget.isModerator ? _showTimerControls : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _getTimerColor().withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _getTimerColor().withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _timerState == 'running' ? Icons.timer : Icons.timer_off,
              color: _getTimerColor(),
              size: 12,
            ),
            const SizedBox(width: 3),
            Text(
              _formatTime(_displayRemaining),
              style: TextStyle(
                color: _getTimerColor(),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _authoritySync?.cancel();
    _displayUpdate?.cancel();
    _realtimeSubscription?.close();
    super.dispose();
  }
}
