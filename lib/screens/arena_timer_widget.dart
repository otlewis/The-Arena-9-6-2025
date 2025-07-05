import 'package:flutter/material.dart';
import '../core/logging/app_logger.dart';
import '../services/sound_service.dart';

// Debate Phase Enum
enum DebatePhase {
  preDebate('Pre-Debate', 'Preparation and setup time', 300), // 5 minutes
  openingAffirmative('Opening - Affirmative', 'Affirmative opening statement', 300), // 5 minutes
  openingNegative('Opening - Negative', 'Negative opening statement', 300), // 5 minutes
  rebuttalAffirmative('Rebuttal - Affirmative', 'Affirmative rebuttal', 180), // 3 minutes
  rebuttalNegative('Rebuttal - Negative', 'Negative rebuttal', 180), // 3 minutes
  crossExamAffirmative('Cross-Exam - Affirmative', 'Affirmative cross-examination', 120), // 2 minutes
  crossExamNegative('Cross-Exam - Negative', 'Negative cross-examination', 120), // 2 minutes
  finalRebuttalAffirmative('Final Rebuttal - Affirmative', 'Affirmative final rebuttal', 180), // 3 minutes
  finalRebuttalNegative('Final Rebuttal - Negative', 'Negative final rebuttal', 180), // 3 minutes
  closingAffirmative('Closing - Affirmative', 'Affirmative closing statement', 240), // 4 minutes
  closingNegative('Closing - Negative', 'Negative closing statement', 240), // 4 minutes
  judging('Judging Phase', 'Judges deliberate and score', null);

  const DebatePhase(this.displayName, this.description, this.defaultDurationSeconds);
  
  final String displayName;
  final String description;
  final int? defaultDurationSeconds;
  
  String get speakerRole {
    switch (this) {
      case DebatePhase.openingAffirmative:
      case DebatePhase.rebuttalAffirmative:
      case DebatePhase.crossExamAffirmative:
      case DebatePhase.finalRebuttalAffirmative:
      case DebatePhase.closingAffirmative:
        return 'affirmative';
      case DebatePhase.openingNegative:
      case DebatePhase.rebuttalNegative:
      case DebatePhase.crossExamNegative:
      case DebatePhase.finalRebuttalNegative:
      case DebatePhase.closingNegative:
        return 'negative';
      default:
        return '';
    }
  }
  
  DebatePhase? get nextPhase {
    const phases = DebatePhase.values;
    final currentIndex = phases.indexOf(this);
    if (currentIndex < phases.length - 1) {
      return phases[currentIndex + 1];
    }
    return null;
  }
}

// Color Constants
class ArenaColors {
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);
  static const Color lightGray = Color(0xFFF5F5F5);
}

class ArenaTimerWidget extends StatefulWidget {
  final DebatePhase currentPhase;
  final SoundService soundService;
  final Function(String) onSpeakerChange;
  final Function(bool) onSpeakingEnabledChange;
  final VoidCallback? onAdvancePhase;
  final Function(DebatePhase)? onPhaseTimeout;

  const ArenaTimerWidget({
    super.key,
    required this.currentPhase,
    required this.soundService,
    required this.onSpeakerChange,
    required this.onSpeakingEnabledChange,
    this.onAdvancePhase,
    this.onPhaseTimeout,
  });

  @override
  State<ArenaTimerWidget> createState() => _ArenaTimerWidgetState();
}

class _ArenaTimerWidgetState extends State<ArenaTimerWidget> with TickerProviderStateMixin {
  // Timer state variables
  late AnimationController _timerController;
  int _remainingSeconds = 0;
  bool _isTimerRunning = false;
  bool _isPaused = false;
  bool _hasPlayed30SecWarning = false;
  String _currentSpeaker = '';
  bool _speakingEnabled = false;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      duration: const Duration(minutes: 10), // Max duration
      vsync: this,
    );
    _remainingSeconds = widget.currentPhase.defaultDurationSeconds ?? 0;
    _currentSpeaker = widget.currentPhase.speakerRole;
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ArenaTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPhase != widget.currentPhase) {
      _resetTimer();
    }
  }

  // Timer Control Methods
  void _startPhaseTimer() {
    final durationToUse = _remainingSeconds > 0 ? _remainingSeconds : (widget.currentPhase.defaultDurationSeconds ?? 0);
    
    if (durationToUse <= 0) {
      AppLogger().error('Cannot start timer: no valid duration');
      return;
    }
    
    setState(() {
      _remainingSeconds = durationToUse;
      _isTimerRunning = true;
      _isPaused = false;
      _currentSpeaker = widget.currentPhase.speakerRole;
      _speakingEnabled = _currentSpeaker.isNotEmpty;
      _hasPlayed30SecWarning = false;
    });
    
    widget.onSpeakerChange(_currentSpeaker);
    widget.onSpeakingEnabledChange(_speakingEnabled);
    
    _timerController.duration = Duration(seconds: durationToUse);
    _timerController.reset();
    _timerController.forward();
    
    AppLogger().info('Started timer with duration: ${durationToUse}s (phase: ${widget.currentPhase.displayName})');
    
    _timerController.addListener(() {
      if (mounted) {
        setState(() {
          final totalDuration = _timerController.duration?.inSeconds ?? durationToUse;
          _remainingSeconds = (totalDuration * (1 - _timerController.value)).round();
        });
        
        // Play 30-second warning sound (only once per phase)
        if (_remainingSeconds == 30 && !_hasPlayed30SecWarning && _isTimerRunning) {
          _hasPlayed30SecWarning = true;
          widget.soundService.play30SecWarningSound();
          AppLogger().debug('🔊 Playing 30-second warning sound');
        }
        
        if (_remainingSeconds <= 0) {
          widget.soundService.playArenaZeroSound();
          _hasPlayed30SecWarning = false;
          _handlePhaseTimeout();
        }
      }
    });
  }

  void _pauseTimer() {
    setState(() {
      _isPaused = true;
      _isTimerRunning = false;
    });
    _timerController.stop();
    widget.onSpeakingEnabledChange(false);
  }

  void _resumeTimer() {
    setState(() {
      _isPaused = false;
      _isTimerRunning = true;
    });
    _timerController.forward();
    widget.onSpeakingEnabledChange(true);
  }

  void _stopTimer() {
    setState(() {
      _isTimerRunning = false;
      _isPaused = false;
      _speakingEnabled = false;
    });
    _timerController.stop();
    widget.onSpeakingEnabledChange(false);
  }

  void _resetTimer() {
    _timerController.reset();
    setState(() {
      _remainingSeconds = widget.currentPhase.defaultDurationSeconds ?? 0;
      _isTimerRunning = false;
      _isPaused = false;
      _speakingEnabled = false;
      _hasPlayed30SecWarning = false;
    });
    widget.onSpeakingEnabledChange(false);
  }

  void _extendTime(int additionalSeconds) {
    setState(() {
      _remainingSeconds += additionalSeconds;
    });
    
    final totalDuration = (widget.currentPhase.defaultDurationSeconds ?? 0) + additionalSeconds;
    final elapsedRatio = ((widget.currentPhase.defaultDurationSeconds ?? 0) - _remainingSeconds) / totalDuration;
    
    _timerController.duration = Duration(seconds: totalDuration);
    _timerController.value = elapsedRatio;
    
    if (_isTimerRunning) {
      _timerController.forward();
    }
  }

  void _setCustomTime(int seconds) {
    setState(() {
      _remainingSeconds = seconds;
      if (_isTimerRunning) {
        AppLogger().debug('🛑 Stopping timer to set custom time');
        _stopTimer();
      }
    });
    
    _timerController.duration = Duration(seconds: seconds);
    _timerController.reset();
    
    AppLogger().debug('⏱️ Set custom time: ${seconds}s (timer ready to start)');
  }

  void _handlePhaseTimeout() {
    _stopTimer();
    widget.onPhaseTimeout?.call(widget.currentPhase);
    _showPhaseTimeoutDialog();
  }

  void _showPhaseTimeoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⏰ Time\'s Up!'),
        content: Text('${widget.currentPhase.displayName} phase has ended.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _extendTime(60); // Add 1 minute
            },
            child: const Text('Extend +1 min'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onAdvancePhase?.call();
            },
            child: const Text('Next Phase'),
          ),
        ],
      ),
    );
  }

  // Timer Display Methods
  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildTimerDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ArenaColors.deepPurple.withValues(alpha: 0.9),
            ArenaColors.accentPurple.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Debate Phase Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.currentPhase.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Current Speaker Indicator
          if (_currentSpeaker.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _speakingEnabled ? Icons.mic : Icons.mic_off,
                  color: _speakingEnabled ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Speaker: ${_currentSpeaker.toUpperCase()}',
                  style: TextStyle(
                    color: _speakingEnabled ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          
          // Timer Display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isTimerRunning ? Icons.timer : (_isPaused ? Icons.pause_circle : Icons.timer_off),
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                _formattedTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          
          // Phase Description
          if (widget.currentPhase.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.currentPhase.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  void _showTimerControlModal() {
    showDialog(
      context: context,
      builder: (context) => TimerControlModal(
        currentPhase: widget.currentPhase,
        remainingSeconds: _remainingSeconds,
        isTimerRunning: _isTimerRunning,
        isPaused: _isPaused,
        onStart: _startPhaseTimer,
        onPause: _pauseTimer,
        onResume: _resumeTimer,
        onStop: _stopTimer,
        onReset: _resetTimer,
        onExtendTime: _extendTime,
        onSetCustomTime: _setCustomTime,
        onAdvancePhase: widget.onAdvancePhase,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showTimerControlModal,
      child: _buildTimerDisplay(),
    );
  }
}

// Timer Control Modal
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
  final VoidCallback? onAdvancePhase;

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
    this.onAdvancePhase,
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
          Icon(Icons.timer, color: ArenaColors.accentPurple),
          const SizedBox(width: 8),
          const Text('Timer Controls'),
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
                  color: ArenaColors.accentPurple.withValues(alpha: 0.1),
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
              if (widget.onAdvancePhase != null)
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
                                widget.onAdvancePhase!();
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: ArenaColors.accentPurple),
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
                      backgroundColor: ArenaColors.accentPurple,
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
          style: ElevatedButton.styleFrom(backgroundColor: ArenaColors.accentPurple),
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