import 'dart:async';
import 'package:flutter/material.dart';
import '../models/timer_state.dart';
import '../services/appwrite_timer_service.dart';
import '../services/timer_feedback_service.dart';
import '../config/timer_presets.dart';

/// Pure display widget that shows server-controlled timer state
/// 
/// This widget only displays the current state from Appwrite Database
/// and provides controls that call Appwrite Functions for timer operations.
/// All timer logic is handled server-side for perfect synchronization.
class AppwriteTimerWidget extends StatefulWidget {
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
  final bool showConnectionStatus;

  const AppwriteTimerWidget({
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
    this.showConnectionStatus = true,
  }) : super(key: key);

  @override
  State<AppwriteTimerWidget> createState() => _AppwriteTimerWidgetState();
}

class _AppwriteTimerWidgetState extends State<AppwriteTimerWidget>
    with TickerProviderStateMixin {
  final AppwriteTimerService _timerService = AppwriteTimerService();
  final TimerFeedbackService _feedbackService = TimerFeedbackService();
  
  StreamSubscription<List<TimerState>>? _timersSubscription;
  Timer? _displayUpdateTimer;
  late AnimationController _progressAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  
  List<TimerState> _timers = [];
  TimerState? _activeTimer;
  bool _isCreatingTimer = false;
  bool _showPresets = false;
  bool _isConnected = true;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeServices();
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

  Future<void> _initializeServices() async {
    try {
      await _timerService.initialize();
      await _feedbackService.initialize();
      _setupTimerStream();
    } catch (e) {
      _setConnectionError('Failed to initialize: $e');
    }
  }

  void _setupTimerStream() {
    _timersSubscription = _timerService
        .getRoomTimersStream(widget.roomId)
        .listen(
          _onTimersUpdated,
          onError: _onStreamError,
        );
  }

  void _onTimersUpdated(List<TimerState> timers) {
    if (!mounted) return;
    
    setState(() {
      _timers = timers;
      _isConnected = true;
      
      // Find active timer (running or paused, NOT completed/stopped)
      final activeTimers = timers.where((t) => 
          (t.status == TimerStatus.running || t.status == TimerStatus.paused) &&
          t.remainingSeconds > 0
      ).toList();
      
      if (activeTimers.isNotEmpty) {
        _activeTimer = activeTimers.first;
      } else if (timers.isNotEmpty) {
        _activeTimer = timers.first;
      } else {
        _activeTimer = null;
      }
    });

    // Don't trigger feedback here - let the display timer handle it
    // to avoid duplicate sounds
    
    // Update animations
    _updateAnimations();
    
    // Start/stop display update timer based on active timer state
    _updateDisplayTimer();
    
  }

  void _onStreamError(error) {
    debugPrint('Timer stream error: $error');
    _setConnectionError('Connection lost: $error');
  }

  void _setConnectionError(String error) {
    if (mounted) {
      setState(() {
        _isConnected = false;
      });
    }
  }


  void _updateAnimations() {
    if (_activeTimer == null) return;

    // Update progress animation
    if (_activeTimer!.durationSeconds > 0) {
      final progress = (_activeTimer!.durationSeconds - _activeTimer!.remainingSeconds) / 
                     _activeTimer!.durationSeconds;
      _progressAnimationController.animateTo(progress);
    }

    // Handle pulse animation for warning zone
    if (_activeTimer!.isInWarningZone && _activeTimer!.isActive) {
      if (!_pulseAnimationController.isAnimating) {
        _pulseAnimationController.repeat(reverse: true);
      }
    } else {
      _pulseAnimationController.stop();
      _pulseAnimationController.reset();
    }
  }

  void _updateDisplayTimer() {
    // Cancel existing timer
    _displayUpdateTimer?.cancel();
    _displayUpdateTimer = null;

    // Start timer if we have an active running timer
    if (_activeTimer != null && _activeTimer!.status == TimerStatus.running) {
      // Track the last second we triggered feedback for
      int? lastFeedbackSecond;
      
      _displayUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        // Calculate current remaining time
        final currentRemainingSeconds = _timerService.calculateRemainingTime(_activeTimer!);
        
        // Only trigger feedback if we haven't already for this second
        if (lastFeedbackSecond != currentRemainingSeconds) {
          // Check for 30-second warning
          if (currentRemainingSeconds == 30 && (lastFeedbackSecond ?? 31) > 30) {
            _feedbackService.onTimerWarning(_activeTimer!);
          }
          
          // Check for timer expiration
          if (currentRemainingSeconds == 0 && (lastFeedbackSecond ?? 1) > 0) {
            _feedbackService.onTimerExpired(_activeTimer!);
          }
          
          lastFeedbackSecond = currentRemainingSeconds;
        }
        
        // Update display every second for running timers
        setState(() {
          // This will trigger rebuild with updated time calculation
        });
      });
    }
  }

  // Timer control methods
  Future<void> _createTimer(TimerType timerType, int durationSeconds, [String? customTitle]) async {
    if (_isCreatingTimer) return;
    
    setState(() => _isCreatingTimer = true);
    
    try {
      // First, check if there's an expired/completed timer and delete it
      final expiredTimers = _timers.where((t) => 
        t.status == TimerStatus.completed || 
        (t.status == TimerStatus.stopped && t.remainingSeconds == 0)
      ).toList();
      
      // Delete expired timers to make room for new one
      for (final timer in expiredTimers) {
        try {
          await _timerService.deleteTimer(timer.id, widget.userId);
          debugPrint('Deleted expired timer: ${timer.id}');
        } catch (e) {
          debugPrint('Failed to delete expired timer: $e');
        }
      }
      
      // Create new timer
      await _timerService.createTimer(
        roomId: widget.roomId,
        roomType: widget.roomType,
        timerType: timerType,
        durationSeconds: durationSeconds,
        createdBy: widget.userId,
        currentSpeaker: widget.currentSpeaker,
        title: customTitle ?? '${timerType.displayName} - ${widget.currentSpeaker ?? 'Timer'}',
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
    
    if (_activeTimer!.remainingSeconds <= 0) {
      return Color(int.parse(config?.expiredColor.replaceFirst('#', '0xFF') ?? '0xFFF44336'));
    } else if (_activeTimer!.remainingSeconds <= 10) {
      return Color(int.parse(config?.warningColor.replaceFirst('#', '0xFF') ?? '0xFFFF9800'));
    } else {
      return Color(int.parse(config?.primaryColor.replaceFirst('#', '0xFF') ?? '0xFF2196F3'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showConnectionStatus) _buildConnectionStatus(),
        if (widget.compact) _buildCompactTimer() else _buildFullTimer(),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    if (_isConnected) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: Colors.orange, size: 16),
          const SizedBox(width: 6),
          Text(
            'Reconnecting...',
            style: TextStyle(
              color: Colors.orange[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTimer() {
    if (_activeTimer == null) {
      return _buildCompactPlaceholder();
    }

    return GestureDetector(
      onTap: widget.isModerator && widget.showControls ? _showTimerControls : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getTimerColor(),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimerDisplay(compact: true),
            if (widget.isModerator && widget.showControls) ...[
              const SizedBox(width: 3),
              const Icon(Icons.settings, color: Colors.white, size: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPlaceholder() {
    return GestureDetector(
      onTap: widget.isModerator && widget.showControls ? _showCreateTimerDialog : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF4A4A4A), // Arena purple
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '--:--',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: 'monospace',
              ),
            ),
            if (widget.isModerator && widget.showControls) ...[
              const SizedBox(width: 3),
              const Icon(Icons.add_circle_outline, color: Colors.white, size: 12),
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
              _activeTimer!.description ?? _activeTimer!.timerType.displayName,
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
    // Calculate real-time remaining seconds for running timers
    final seconds = _activeTimer != null 
        ? _timerService.calculateRemainingTime(_activeTimer!)
        : 0;
    final timeText = _formatTime(seconds);
    final color = _getTimerColor();
    
    Widget timeDisplay = Text(
      timeText,
      style: TextStyle(
        fontSize: compact ? 16 : 56,
        fontWeight: FontWeight.bold,
        color: compact ? Colors.white : color,
        fontFamily: 'monospace',
      ),
    );

    if (!compact && _activeTimer != null && _activeTimer!.isInWarningZone && _activeTimer!.isActive) {
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
                  : () => _createTimer(config.type, duration, config.label),
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

  void _showCreateTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateTimerDialog(
        roomType: widget.roomType,
        onCreateTimer: (timerType, duration, title) {
          _createTimer(timerType, duration, title);
        },
      ),
    );
  }


  void _showTimerControls() {
    if (_activeTimer == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 20),
            
            // Timer info
            Text(
              _activeTimer!.description ?? _activeTimer!.timerType.displayName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Timer display
            _buildTimerDisplay(),
            const SizedBox(height: 20),
            
            // Control buttons
            if (_canControlTimer()) ...[
              _buildMainControls(),
              const SizedBox(height: 16),
              _buildSecondaryControls(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              // Add "Create New Timer" button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showCreateTimerDialog();
                  },
                  icon: const Icon(Icons.add_alarm),
                  label: const Text('Create New Timer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else
              Text(
                'Only moderators can control this timer',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                ),
                child: const Text('Close'),
              ),
            ),
            
            // Safe area padding
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timersSubscription?.cancel();
    _displayUpdateTimer?.cancel();
    _progressAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }
}

class _CreateTimerDialog extends StatefulWidget {
  final RoomType roomType;
  final Function(TimerType timerType, int duration, String title) onCreateTimer;

  const _CreateTimerDialog({
    required this.roomType,
    required this.onCreateTimer,
  });

  @override
  State<_CreateTimerDialog> createState() => _CreateTimerDialogState();
}

class _CreateTimerDialogState extends State<_CreateTimerDialog> {
  TimerType _selectedTimerType = TimerType.general;
  int _minutes = 5;
  int _seconds = 0;
  final TextEditingController _titleController = TextEditingController();
  bool _showCustomTime = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = _selectedTimerType.displayName;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Timer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timer Type Selection
            const Text('Timer Type:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<TimerType>(
              value: _selectedTimerType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: TimerType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: (TimerType? value) {
                if (value != null) {
                  setState(() {
                    _selectedTimerType = value;
                    _titleController.text = value.displayName;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Title Input
            const Text('Title:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter timer title',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 16),

            // Duration Selection
            const Text('Duration:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            // Quick presets
            const Text('Quick Presets:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                _buildPresetChip(60, '1m'),
                _buildPresetChip(180, '3m'),
                _buildPresetChip(300, '5m'),
                _buildPresetChip(600, '10m'),
                _buildPresetChip(900, '15m'),
              ],
            ),
            const SizedBox(height: 12),

            // Custom time toggle
            Row(
              children: [
                Checkbox(
                  value: _showCustomTime,
                  onChanged: (bool? value) {
                    setState(() => _showCustomTime = value ?? false);
                  },
                ),
                const Text('Custom time'),
                const Spacer(),
                if (!_showCustomTime)
                  Text(
                    'Current: ${_formatDuration(_getTotalSeconds())}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
              ],
            ),

            // Custom time input
            if (_showCustomTime) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Minutes', style: TextStyle(fontSize: 12)),
                        DropdownButtonFormField<int>(
                          value: _minutes,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          items: List.generate(61, (i) => i).map((min) {
                            return DropdownMenuItem(value: min, child: Text('$min'));
                          }).toList(),
                          onChanged: (int? value) {
                            setState(() => _minutes = value ?? 0);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Seconds', style: TextStyle(fontSize: 12)),
                        DropdownButtonFormField<int>(
                          value: _seconds,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          items: List.generate(60, (i) => i).map((sec) {
                            return DropdownMenuItem(value: sec, child: Text('$sec'));
                          }).toList(),
                          onChanged: (int? value) {
                            setState(() => _seconds = value ?? 0);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Total Duration: ${_formatDuration(_getTotalSeconds())}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _getTotalSeconds() > 0 ? () {
            Navigator.pop(context);
            widget.onCreateTimer(
              _selectedTimerType,
              _getTotalSeconds(),
              _titleController.text.trim().isEmpty 
                  ? _selectedTimerType.displayName 
                  : _titleController.text.trim(),
            );
          } : null,
          child: const Text('Create Timer'),
        ),
      ],
    );
  }

  Widget _buildPresetChip(int seconds, String label) {
    final isSelected = !_showCustomTime && _getTotalSeconds() == seconds;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.blue[100],
      onSelected: (selected) {
        setState(() {
          _showCustomTime = false;
          _minutes = seconds ~/ 60;
          _seconds = seconds % 60;
        });
      },
    );
  }

  int _getTotalSeconds() {
    return (_minutes * 60) + _seconds;
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}