import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class SimpleTimer extends StatefulWidget {
  const SimpleTimer({super.key});

  @override
  State<SimpleTimer> createState() => _SimpleTimerState();
}

class _SimpleTimerState extends State<SimpleTimer> {
  int _seconds = 0;
  int _totalSeconds = 0;
  Timer? _timer;
  bool _isRunning = false;
  bool _isVisible = false;
  bool _playedWarning = false; // Track if 30-sec warning was played
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(String soundFile) async {
    try {
      await _audioPlayer.setVolume(1.0); // Set volume to maximum
      await _audioPlayer.play(AssetSource('audio/$soundFile'));
    } catch (e) {
      // Handle audio playback errors silently
    }
  }

  void _startTimer() {
    if (_totalSeconds == 0) return;
    
    setState(() {
      _isRunning = true;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_seconds > 0) {
        setState(() {
          _seconds--;
        });

        // Play 30-second warning sound
        if (_seconds == 30 && !_playedWarning) {
          _playedWarning = true;
          _playSound('30sec.mp3');
        }

        // Play zero sound when timer expires
        if (_seconds == 0) {
          _playSound('arenazero.mp3');
          _stopTimer();
        }
      } else {
        _stopTimer();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _seconds = 0;
      _isVisible = false;
      _playedWarning = false; // Reset warning flag
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _seconds = _totalSeconds;
      _playedWarning = false; // Reset warning flag
    });
  }

  void _showTimerSetup() {
    final TextEditingController minutesController = TextEditingController();
    final TextEditingController secondsController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set Timer',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Custom time input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('Custom Time', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: minutesController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            labelText: 'Min',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: secondsController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            labelText: 'Sec',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final minutes = int.tryParse(minutesController.text) ?? 0;
                          final seconds = int.tryParse(secondsController.text) ?? 0;
                          final totalSeconds = (minutes * 60) + seconds;
                          if (totalSeconds > 0) {
                            if (mounted) {
                              setState(() {
                                _totalSeconds = totalSeconds;
                                _seconds = totalSeconds;
                                _isVisible = true;
                                _isRunning = false;
                                _playedWarning = false;
                              });
                            }
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        },
                        child: const Text('Set'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Preset buttons - smaller and more responsive
            const Text('Quick Presets', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              childAspectRatio: 2.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _buildTimeButton('1:00', 60),
                _buildTimeButton('2:00', 120),
                _buildTimeButton('3:00', 180),
                _buildTimeButton('5:00', 300),
                _buildTimeButton('10:00', 600),
                _buildTimeButton('15:00', 900),
                _buildTimeButton('20:00', 1200),
                _buildTimeButton('30:00', 1800),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildTimeButton(String label, int seconds) {
    return ElevatedButton(
      onPressed: () {
        if (mounted) {
          setState(() {
            _totalSeconds = seconds;
            _seconds = seconds;
            _isVisible = true;
            _isRunning = false;
            _playedWarning = false;
          });
        }
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        minimumSize: const Size(0, 32),
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(label),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showTimerControls() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Timer: ${_formatTime(_seconds)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!_isRunning)
                  ElevatedButton.icon(
                    onPressed: _startTimer,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _pauseTimer,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showTimerSetup();
              },
              child: const Text('Change Time'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;

    if (!_isVisible) {
      return GestureDetector(
        onTap: _showTimerSetup,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 6 : 12,
            vertical: isSmallScreen ? 3 : 6,
          ),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer, color: Colors.white, size: isSmallScreen ? 12 : 16),
              SizedBox(width: isSmallScreen ? 2 : 4),
              Text(
                'Timer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 11 : 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _showTimerControls,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 6 : 12,
          vertical: isSmallScreen ? 3 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isRunning ? Colors.green : (_seconds <= 30 ? Colors.red : Colors.white),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isRunning ? Icons.timer : Icons.pause,
              color: _isRunning ? Colors.green : (_seconds <= 30 ? Colors.red : Colors.white),
              size: isSmallScreen ? 12 : 16,
            ),
            SizedBox(width: isSmallScreen ? 2 : 4),
            Text(
              _formatTime(_seconds),
              style: TextStyle(
                color: _isRunning ? Colors.green : (_seconds <= 30 ? Colors.red : Colors.white),
                fontSize: isSmallScreen ? 11 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}