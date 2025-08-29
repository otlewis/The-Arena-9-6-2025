import '../core/logging/app_logger.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../models/timer_state.dart';
import '../services/timer_service.dart';
import '../config/timer_presets.dart';

class SynchronizedTimerWidget extends StatefulWidget {
  final String roomId;
  final RoomType roomType;
  final bool isModerator;
  final String userId;
  final String? currentSpeaker;
  final VoidCallback? onTimerExpired;
  final VoidCallback? onTimerStarted;
  final VoidCallback? onTimerStopped;
  final bool compact;
  final bool showControls;

  const SynchronizedTimerWidget({
    Key? key,
    required this.roomId,
    required this.roomType,
    required this.isModerator,
    required this.userId,
    this.currentSpeaker,
    this.onTimerExpired,
    this.onTimerStarted,
    this.onTimerStopped,
    this.compact = false,
    this.showControls = true,
  }) : super(key: key);

  @override
  State<SynchronizedTimerWidget> createState() => _SynchronizedTimerWidgetState();
}

class _SynchronizedTimerWidgetState extends State<SynchronizedTimerWidget>
    with TickerProviderStateMixin {
  final TimerService _timerService = TimerService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  StreamSubscription<List<TimerState>>? _timersSubscription;
  Timer? _displayUpdateTimer;
  late AnimationController _progressAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  
  TimerState? _activeTimer;
  bool _isCreatingTimer = false;
  bool _showPresets = false;
  
  // Current display values (for smooth updates)
  int _displayRemainingSeconds = 0;
  String _lastExpiredTimerId = '';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAudio();
    _initializeTimer();
  }

  Future<void> _initializeTimer() async {
    try {
      // Initialize the timer service first
      await _timerService.initializeFirebase();
      
      // Then setup streams
      _setupTimerStream();
      _setupDisplayUpdateTimer();
    } catch (e) {
      AppLogger().debug('Timer initialization error: $e');
      _showErrorSnackBar('Timer initialization failed: $e');
    }
  }

  void _initializeAnimations() {
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _setupTimerStream() {
    _timersSubscription = _timerService
        .getRoomTimersStream(widget.roomId)
        .listen(_onTimersUpdated);
  }

  void _setupDisplayUpdateTimer() {
    _displayUpdateTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateDisplayTime(),
    );
  }

  Future<void> _initializeAudio() async {
    try {
      // Load built-in system sounds or custom assets
      // await _audioPlayer.setAsset('assets/sounds/timer_alert.mp3');
    } catch (e) {
      AppLogger().debug('Error initializing audio: $e');
    }
  }

  void _onTimersUpdated(List<TimerState> timers) {
    if (!mounted) return;
    
    setState(() {
      _activeTimer = timers
          .where((t) => t.status == TimerStatus.running || t.status == TimerStatus.paused)
          .isNotEmpty
          ? timers.firstWhere(
              (t) => t.status == TimerStatus.running || t.status == TimerStatus.paused,
              orElse: () => timers.first,
            )
          : timers.isNotEmpty ? timers.first : null;
    });

    // Check for newly expired timers
    _checkForExpiredTimers(timers);
  }

  void _updateDisplayTime() {
    if (!mounted || _activeTimer == null) return;

    final timer = _activeTimer!;
    if (timer.status == TimerStatus.running && timer.startTime != null) {
      final newRemainingSeconds = _timerService.calculateRemainingTime(timer);
      
      if (newRemainingSeconds != _displayRemainingSeconds) {
        setState(() {
          _displayRemainingSeconds = newRemainingSeconds;
        });

        // Update progress animation
        if (timer.durationSeconds > 0) {
          final progress = (timer.durationSeconds - newRemainingSeconds) / timer.durationSeconds;
          _progressAnimationController.animateTo(progress);
        }

        // Start pulse animation for warning zone
        if (newRemainingSeconds <= 10 && newRemainingSeconds > 0) {
          if (!_pulseAnimationController.isAnimating) {
            _pulseAnimationController.repeat(reverse: true);
          }
        } else {
          _pulseAnimationController.stop();
          _pulseAnimationController.reset();
        }
      }
    }
  }

  void _checkForExpiredTimers(List<TimerState> timers) {
    for (final timer in timers) {
      if (timer.hasExpired && timer.id != _lastExpiredTimerId) {
        _lastExpiredTimerId = timer.id;
        _onTimerExpired(timer);
      }
    }
  }

  void _onTimerExpired(TimerState timer) {
    _triggerExpiredFeedback();
    widget.onTimerExpired?.call();
  }

  void _triggerExpiredFeedback() {
    // Haptic feedback
    HapticFeedback.heavyImpact();
    
    // Audio feedback
    _playTimerSound();
    
    // Stop pulse animation
    _pulseAnimationController.stop();
    _pulseAnimationController.reset();
  }

  Future<void> _playTimerSound() async {
    try {
      HapticFeedback.vibrate();
      // If you have audio assets, play them here
      // await _audioPlayer.play();
    } catch (e) {
      AppLogger().debug('Error playing timer sound: $e');
    }
  }

  // Timer control methods
  Future<void> _createTimer(TimerType timerType, int durationSeconds) async {
    if (_isCreatingTimer) return;
    
    setState(() => _isCreatingTimer = true);
    
    try {
      await _timerService.createTimer(
        roomId: widget.roomId,
        roomType: widget.roomType,
        timerType: timerType,
        durationSeconds: durationSeconds,
        createdBy: widget.userId,
        currentSpeaker: widget.currentSpeaker,
        description: timerType.displayName,
      );
      
      setState(() => _showPresets = false);
    } catch (e) {
      _showErrorSnackBar('Failed to create timer: $e');
    } finally {
      setState(() => _isCreatingTimer = false);
    }
  }

  Future<void> _startTimer() async {
    if (_activeTimer == null) return;
    
    try {
      await _timerService.startTimer(_activeTimer!.id, widget.userId);
      widget.onTimerStarted?.call();
    } catch (e) {
      _showErrorSnackBar('Failed to start timer: $e');
    }
  }

  Future<void> _pauseTimer() async {
    if (_activeTimer == null) return;
    
    try {
      await _timerService.pauseTimer(_activeTimer!.id, widget.userId);
    } catch (e) {
      _showErrorSnackBar('Failed to pause timer: $e');
    }
  }

  Future<void> _stopTimer() async {
    if (_activeTimer == null) return;
    
    try {
      await _timerService.stopTimer(_activeTimer!.id, widget.userId);
      widget.onTimerStopped?.call();
    } catch (e) {
      _showErrorSnackBar('Failed to stop timer: $e');
    }
  }

  Future<void> _resetTimer() async {
    if (_activeTimer == null) return;
    
    try {
      await _timerService.resetTimer(_activeTimer!.id, widget.userId);
    } catch (e) {
      _showErrorSnackBar('Failed to reset timer: $e');
    }
  }

  Future<void> _addTime(int seconds) async {
    if (_activeTimer == null) return;
    
    try {
      await _timerService.addTime(_activeTimer!.id, seconds, widget.userId);
    } catch (e) {
      _showErrorSnackBar('Failed to add time: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _canControlTimer() {
    if (_activeTimer == null) return widget.isModerator;
    return _timerService.canControlTimer(_activeTimer!, widget.userId, widget.isModerator);
  }

  Color _getTimerColor() {
    if (_activeTimer == null) return Colors.grey;
    
    final config = TimerPresets.getTimerConfig(
      _activeTimer!.roomType,
      _activeTimer!.timerType,
    );
    
    if (_displayRemainingSeconds <= 0) {
      return Color(int.parse(config?.expiredColor.replaceFirst('#', '0xFF') ?? '0xFFF44336'));
    } else if (_displayRemainingSeconds <= 10) {
      return Color(int.parse(config?.warningColor.replaceFirst('#', '0xFF') ?? '0xFFFF9800'));
    } else {
      return Color(int.parse(config?.primaryColor.replaceFirst('#', '0xFF') ?? '0xFF2196F3'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactTimer();
    }

    return _buildFullTimer();
  }

  Widget _buildCompactTimer() {
    if (_activeTimer == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTimerDisplay(compact: true),
            if (widget.showControls && _canControlTimer())
              _buildCompactControls(),
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
            if (_activeTimer != null) ...[
              _buildTimerHeader(),
              const SizedBox(height: 16),
              _buildTimerDisplay(),
              const SizedBox(height: 16),
              _buildProgressIndicator(),
              const SizedBox(height: 24),
              if (widget.showControls && _canControlTimer()) ...[
                _buildMainControls(),
                const SizedBox(height: 16),
                _buildSecondaryControls(),
              ],
            ] else ...[
              _buildNoTimerState(),
            ],
            if (_showPresets) ...[
              const SizedBox(height: 16),
              _buildTimerPresets(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _activeTimer!.timerType.displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_activeTimer!.currentSpeaker != null)
              Text(
                'Speaker: ${_activeTimer!.currentSpeaker}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        _buildStatusChip(),
      ],
    );
  }

  Widget _buildStatusChip() {
    final color = _getTimerColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        _activeTimer!.statusText,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTimerDisplay({bool compact = false}) {
    final seconds = _activeTimer?.status == TimerStatus.running 
        ? _displayRemainingSeconds 
        : _activeTimer?.remainingSeconds ?? 0;
    
    final timeText = _formatTime(seconds);
    final color = _getTimerColor();
    
    Widget timeDisplay = Text(
      timeText,
      style: TextStyle(
        fontSize: compact ? 24 : 56,
        fontWeight: FontWeight.bold,
        color: color,
        fontFamily: 'monospace',
      ),
    );

    if (!compact && _displayRemainingSeconds <= 10 && _displayRemainingSeconds > 0) {
      timeDisplay = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: timeDisplay,
          );
        },
      );
    }

    return timeDisplay;
  }

  Widget _buildProgressIndicator() {
    if (_activeTimer == null) return const SizedBox.shrink();
    
    final config = TimerPresets.getTimerConfig(
      _activeTimer!.roomType,
      _activeTimer!.timerType,
    );
    
    if (config?.showProgress != true) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _progressAnimationController,
      builder: (context, child) {
        return LinearProgressIndicator(
          value: _progressAnimationController.value,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(_getTimerColor()),
          minHeight: 8,
        );
      },
    );
  }

  Widget _buildMainControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_activeTimer!.isStopped) ...[
          ElevatedButton.icon(
            onPressed: _startTimer,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ] else if (_activeTimer!.isActive) ...[
          if (TimerPresets.canPause(_activeTimer!.roomType, _activeTimer!.timerType))
            ElevatedButton.icon(
              onPressed: _pauseTimer,
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _stopTimer,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ] else if (_activeTimer!.isPaused) ...[
          ElevatedButton.icon(
            onPressed: _startTimer,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _stopTimer,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ],
    );
  }

  Widget _buildSecondaryControls() {
    return Wrap(
      spacing: 8,
      children: [
        if (!_activeTimer!.isActive)
          TextButton.icon(
            onPressed: _resetTimer,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset'),
          ),
        if (TimerPresets.canAddTime(_activeTimer!.roomType, _activeTimer!.timerType)) ...[
          TextButton.icon(
            onPressed: () => _addTime(30),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('+30s'),
          ),
          TextButton.icon(
            onPressed: () => _addTime(60),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('+1m'),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_activeTimer!.isStopped || _activeTimer!.isPaused)
          IconButton(
            onPressed: _startTimer,
            icon: const Icon(Icons.play_arrow),
            color: Colors.green,
          ),
        if (_activeTimer!.isActive)
          IconButton(
            onPressed: _stopTimer,
            icon: const Icon(Icons.stop),
            color: Colors.red,
          ),
      ],
    );
  }

  Widget _buildNoTimerState() {
    return Column(
      children: [
        Icon(
          Icons.timer,
          size: 64,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 16),
        Text(
          'No Timer Active',
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create a timer to get started',
          style: TextStyle(
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 24),
        if (widget.showControls && widget.isModerator)
          ElevatedButton.icon(
            onPressed: () => setState(() => _showPresets = !_showPresets),
            icon: const Icon(Icons.add),
            label: const Text('Create Timer'),
          ),
      ],
    );
  }

  Widget _buildTimerPresets() {
    final presets = TimerPresets.getTimersForRoom(widget.roomType);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text(
          'Timer Presets',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...presets.map((config) => _buildPresetTile(config)),
      ],
    );
  }

  Widget _buildPresetTile(TimerConfiguration config) {
    return ExpansionTile(
      title: Text(config.label),
      subtitle: Text(config.description),
      children: [
        Wrap(
          spacing: 8,
          children: config.presetDurations.map((duration) {
            return ActionChip(
              label: Text(_formatTime(duration)),
              onPressed: _isCreatingTimer 
                  ? null 
                  : () => _createTimer(config.type, duration),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timersSubscription?.cancel();
    _displayUpdateTimer?.cancel();
    _progressAnimationController.dispose();
    _pulseAnimationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}