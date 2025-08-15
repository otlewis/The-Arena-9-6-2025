import 'package:flutter/material.dart';
import '../core/logging/app_logger.dart';
import '../services/sound_service.dart';
import '../features/arena/dialogs/timer_control_modal.dart';

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
