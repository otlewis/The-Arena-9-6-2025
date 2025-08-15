import 'package:flutter/material.dart';

/// Simplified Timer Control Modal
/// Universal timer controls for all room types with 3-minute default
class TimerControlModal extends StatefulWidget {
  final int remainingSeconds;
  final bool isTimerRunning;
  final bool isPaused;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onReset;
  final Function(int) onExtendTime;
  final Function(int) onSetCustomTime;

  const TimerControlModal({
    super.key,
    required this.remainingSeconds,
    required this.isTimerRunning,
    required this.isPaused,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onReset,
    required this.onExtendTime,
    required this.onSetCustomTime,
  });

  @override
  State<TimerControlModal> createState() => _TimerControlModalState();
}

class _TimerControlModalState extends State<TimerControlModal> {
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _secondsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final minutes = widget.remainingSeconds ~/ 60;
    final seconds = widget.remainingSeconds % 60;
    _minutesController.text = minutes.toString();
    _secondsController.text = seconds.toString();
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 16),
          
          // Title with timer display if running
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.timer, color: Colors.purple),
                  SizedBox(width: 8),
                  Text(
                    'Speaking Time',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Show live countdown if timer is running
              if (widget.isTimerRunning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.remainingSeconds <= 30 ? Colors.red : Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatTime(widget.remainingSeconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Only show preset and custom time input when timer is NOT running
          if (!widget.isTimerRunning) ...[
            // Speaking Time Preset
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildPresetButton('3:00', 180), // 3 minutes default
                  _buildPresetButton('2:00', 120), // 2 minutes
                  _buildPresetButton('5:00', 300), // 5 minutes
                  _buildPresetButton('1:00', 60),  // 1 minute
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Custom Time Input
            const Text(
              'Set Custom Time',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minutesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(':', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _secondsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Seconds',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
          ],
          
          // Timer Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimerButton(
                icon: widget.isTimerRunning ? Icons.pause : (widget.isPaused ? Icons.play_arrow : Icons.play_arrow),
                label: widget.isTimerRunning ? 'Pause' : (widget.isPaused ? 'Resume' : 'Start'),
                onPressed: () {
                  if (widget.isTimerRunning) {
                    widget.onPause();
                    // Don't close when pausing - keep bottom sheet open
                  } else if (widget.isPaused) {
                    widget.onResume();
                    // Don't close when resuming - keep bottom sheet open
                  } else {
                    widget.onStart();
                    // Don't close when starting - keep bottom sheet open to show countdown
                  }
                },
                color: widget.isTimerRunning ? Colors.orange : Colors.green,
              ),
              _buildTimerButton(
                icon: Icons.stop,
                label: 'Stop',
                onPressed: () {
                  widget.onStop();
                  Navigator.pop(context);
                },
                color: Colors.red,
              ),
              _buildTimerButton(
                icon: Icons.refresh,
                label: 'Reset',
                onPressed: () {
                  widget.onReset();
                  Navigator.pop(context);
                },
                color: Colors.blue,
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Quick Extend Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildExtendButton('+30s', 30),
              _buildExtendButton('+1m', 60),
              _buildExtendButton('+5m', 300),
            ],
          ),
          
          
          const SizedBox(height: 20),
          
          // Action buttons - conditional based on timer state
          if (widget.isTimerRunning)
            // When timer is running, just show close button
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            // When timer is not running, show normal controls
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _setCustomTime,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Set Time',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          
          // Add bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          
          ],
        ),
      ),
    );
  }

  Widget _buildTimerButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildPresetButton(String label, int seconds) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive sizing based on screen width
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360;
        
        return GestureDetector(
          onTap: () {
            widget.onSetCustomTime(seconds);
            Navigator.pop(context);
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: 8,
            ),
            constraints: BoxConstraints(
              minWidth: isSmallScreen ? 60 : 70,
              maxWidth: isSmallScreen ? 70 : 80,
            ),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade700),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 12 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExtendButton(String label, int seconds) {
    return GestureDetector(
      onTap: () {
        widget.onExtendTime(seconds);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.indigo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _setCustomTime() {
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    final totalSeconds = (minutes * 60) + seconds;
    
    if (totalSeconds > 0) {
      widget.onSetCustomTime(totalSeconds);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid time')),
      );
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}