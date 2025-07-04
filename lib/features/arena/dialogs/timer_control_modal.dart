import 'package:flutter/material.dart';
import '../models/debate_phase.dart';

/// Timer Control Modal - DO NOT MODIFY UI LAYOUT
/// This modal provides timer controls for moderators during debates
class TimerControlModal extends StatefulWidget {
  final DebatePhase currentPhase;
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
  final VoidCallback onAdvancePhase;

  const TimerControlModal({
    super.key,
    required this.currentPhase,
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
    required this.onAdvancePhase,
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
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.timer, color: Colors.purple),
          const SizedBox(width: 8),
          Text('Timer Controls'),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          // Current Phase Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  widget.currentPhase.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.currentPhase.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
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
                  } else if (widget.isPaused) {
                    widget.onResume();
                  } else {
                    widget.onStart();
                  }
                  Navigator.pop(context);
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
          
          const SizedBox(height: 16),
          
          // Advance Phase Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.currentPhase.nextPhase != null ? () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Advance Phase'),
                    content: Text(
                      'Are you sure you want to advance to the next phase?\n\n'
                      'Current: ${widget.currentPhase.displayName}\n'
                      'Next: ${widget.currentPhase.nextPhase?.displayName ?? 'None'}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close confirmation
                          Navigator.pop(context); // Close timer modal
                          widget.onAdvancePhase();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                        child: const Text('Advance', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              } : null,
              icon: const Icon(Icons.skip_next, color: Colors.white),
              label: Text(
                widget.currentPhase.nextPhase != null 
                  ? 'Advance to ${widget.currentPhase.nextPhase!.displayName}'
                  : 'Final Phase',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _setCustomTime,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          child: const Text('Set Time', style: TextStyle(color: Colors.white)),
        ),
      ],
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
}