import 'dart:async';
import 'package:flutter/material.dart';

/// Simple, reliable timer widget for debates
/// No server synchronization, no complex state - just works
class SimpleTimerWidget extends StatefulWidget {
  final bool isModerator;
  final VoidCallback? onTimerExpired;
  final bool compact;

  const SimpleTimerWidget({
    Key? key,
    required this.isModerator,
    this.onTimerExpired,
    this.compact = false,
  }) : super(key: key);

  @override
  State<SimpleTimerWidget> createState() => _SimpleTimerWidgetState();
}

class _SimpleTimerWidgetState extends State<SimpleTimerWidget> {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _hasTimer = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_remainingSeconds <= 0) return;
    
    setState(() {
      _isRunning = true;
      _isPaused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
        
        if (_remainingSeconds <= 0) {
          _isRunning = false;
          _timer?.cancel();
          widget.onTimerExpired?.call();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _remainingSeconds = _totalSeconds;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _remainingSeconds = _totalSeconds;
    });
  }

  void _createTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _totalSeconds = seconds;
      _remainingSeconds = seconds;
      _hasTimer = true;
      _isRunning = false;
      _isPaused = false;
    });
    
    // Auto-start the timer
    _startTimer();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color _getTimerColor() {
    if (_remainingSeconds <= 0) return Colors.red;
    if (_remainingSeconds <= 30) return Colors.orange;
    return Colors.green;
  }

  void _showCreateTimerDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
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
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            
            // Title
            const Row(
              children: [
                Icon(Icons.timer, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Speaking Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Preset buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildPresetButton('3:00', 180), // 3 minutes first (default)
                _buildPresetButton('2:00', 120),
                _buildPresetButton('5:00', 300),
                _buildPresetButton('1:00', 60),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, int seconds) {
    return GestureDetector(
      onTap: () {
        _createTimer(seconds);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade700),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showTimerControls() {
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
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            
            // Timer display
            Text(
              _formatTime(_remainingSeconds),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _getTimerColor(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Control buttons
            if (widget.isModerator) ...[
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (!_isRunning && !_isPaused)
                    ElevatedButton.icon(
                      onPressed: _startTimer,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  if (_isRunning)
                    ElevatedButton.icon(
                      onPressed: _pauseTimer,
                      icon: const Icon(Icons.pause),
                      label: const Text('Pause'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    ),
                  if (_isPaused)
                    ElevatedButton.icon(
                      onPressed: _startTimer,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Resume'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ElevatedButton.icon(
                    onPressed: _stopTimer,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                  ElevatedButton.icon(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
                if (widget.isModerator) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showCreateTimerDialog();
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Timer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactTimer();
    }
    
    return _buildFullTimer();
  }

  Widget _buildCompactTimer() {
    if (!_hasTimer) {
      return GestureDetector(
        onTap: widget.isModerator ? _showCreateTimerDialog : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4A4A4A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '--:--',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
              if (widget.isModerator) ...[
                const SizedBox(width: 2),
                const Icon(Icons.add_circle_outline, color: Colors.white, size: 10),
              ],
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.isModerator ? _showTimerControls : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getTimerColor(),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(_remainingSeconds),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),
            if (widget.isModerator) ...[
              const SizedBox(width: 2),
              const Icon(Icons.settings, color: Colors.white, size: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFullTimer() {
    return Card(
      elevation: 8,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasTimer) ...[
              Text(
                _formatTime(_remainingSeconds),
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: _getTimerColor(),
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 24),
              if (widget.isModerator) ...[
                Wrap(
                  spacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if (!_isRunning && !_isPaused)
                      ElevatedButton.icon(
                        onPressed: _startTimer,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    if (_isRunning)
                      ElevatedButton.icon(
                        onPressed: _pauseTimer,
                        icon: const Icon(Icons.pause),
                        label: const Text('Pause'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      ),
                    if (_isPaused)
                      ElevatedButton.icon(
                        onPressed: _startTimer,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Resume'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ElevatedButton.icon(
                      onPressed: _stopTimer,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _resetTimer,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            ] else ...[
              const Icon(Icons.timer, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No Timer Active',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              if (widget.isModerator)
                ElevatedButton.icon(
                  onPressed: _showCreateTimerDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Timer'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}