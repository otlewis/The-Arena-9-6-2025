import '../core/logging/app_logger.dart';
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
      AppLogger().debug('🕐 Timer widget initializing for room: ${widget.roomId}, isModerator: ${widget.isModerator}, userId: ${widget.userId}');
      await _timerService.initialize();
      await _feedbackService.initialize();
      _setupTimerStream();
      AppLogger().debug('🕐 Timer widget setup complete for room: ${widget.roomId}');
    } catch (e) {
      AppLogger().error('🕐 Timer widget initialization failed: $e');
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
    
    AppLogger().debug('🕐 Timer update received for room ${widget.roomId}: ${timers.length} timers, isModerator: ${widget.isModerator}');
    for (final timer in timers) {
      AppLogger().debug('🕐   Timer ${timer.id}: ${timer.status.name}, ${timer.remainingSeconds}s remaining');
    }
    
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
        AppLogger().debug('🕐 Active timer found: ${_activeTimer!.id} with ${_activeTimer!.remainingSeconds}s remaining');
      } else if (timers.isNotEmpty) {
        _activeTimer = timers.first;
        AppLogger().debug('🕐 Using first timer: ${_activeTimer!.id} (status: ${_activeTimer!.status.name})');
      } else {
        _activeTimer = null;
        AppLogger().debug('🕐 No active timer found');
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
    AppLogger().debug('Timer stream error: $error');
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

    // Create local countdown timer for immediate functionality
    if (_activeTimer != null && _activeTimer!.status == TimerStatus.running) {
      // Track feedback triggers
      int? lastFeedbackSecond;
      
      _displayUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        // Local countdown - decrement remaining seconds
        if (_activeTimer != null && _activeTimer!.remainingSeconds > 0) {
          setState(() {
            _activeTimer = _activeTimer!.copyWith(
              remainingSeconds: _activeTimer!.remainingSeconds - 1
            );
          });
          
          final currentRemainingSeconds = _activeTimer!.remainingSeconds;
          
          // Trigger feedback
          if (lastFeedbackSecond != currentRemainingSeconds) {
            // Check for 30-second warning
            if (currentRemainingSeconds == 30 && (lastFeedbackSecond ?? 31) > 30) {
              _feedbackService.onTimerWarning(_activeTimer!);
            }
            
            // Check for timer expiration
            if (currentRemainingSeconds == 0 && (lastFeedbackSecond ?? 1) > 0) {
              _feedbackService.onTimerExpired(_activeTimer!);
              timer.cancel(); // Stop the timer
              widget.onTimerExpired?.call();
            }
            
            lastFeedbackSecond = currentRemainingSeconds;
          }
        } else {
          timer.cancel();
        }
      });
    }
  }

  /// Calculate the current display time for the timer
  int _calculateCurrentDisplayTime() {
    if (_activeTimer == null) return 0;
    
    // Always use server's remainingSeconds - it's the source of truth
    return _activeTimer!.remainingSeconds;
  }

  // Timer control methods
  Future<void> _createTimer(TimerType timerType, int durationSeconds, [String? customTitle]) async {
    if (_isCreatingTimer) return;
    
    setState(() => _isCreatingTimer = true);
    
    try {
      // Create a local timer in STOPPED state (not auto-starting)
      final localTimer = TimerState(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        roomId: widget.roomId,
        roomType: widget.roomType,
        timerType: timerType,
        status: TimerStatus.stopped,
        durationSeconds: durationSeconds,
        remainingSeconds: durationSeconds,
        startTime: null,
        createdAt: DateTime.now(),
        createdBy: widget.userId,
        currentSpeaker: widget.currentSpeaker,
        description: customTitle ?? '${timerType.displayName} - ${widget.currentSpeaker ?? 'Timer'}',
      );
      
      setState(() {
        _activeTimer = localTimer;
        _showPresets = false;
      });
      
      // Do NOT auto-start the timer
      
      // Try to create server timer in background (non-blocking)
      _createServerTimer(timerType, durationSeconds, customTitle);
      
    } catch (e) {
      _showErrorSnackBar('Failed to create timer: $e');
    } finally {
      setState(() => _isCreatingTimer = false);
    }
  }
  
  // Background server timer creation (non-blocking)
  Future<void> _createServerTimer(TimerType timerType, int durationSeconds, String? customTitle) async {
    try {
      // Delete expired timers
      final expiredTimers = _timers.where((t) => 
        t.status == TimerStatus.completed || 
        (t.status == TimerStatus.stopped && t.remainingSeconds == 0)
      ).toList();
      
      for (final timer in expiredTimers) {
        try {
          await _timerService.deleteTimer(timer.id, widget.userId);
        } catch (e) {
          AppLogger().debug('Failed to delete expired timer: $e');
        }
      }
      
      // Create server timer (but don't auto-start it)
      await _timerService.createTimer(
        roomId: widget.roomId,
        roomType: widget.roomType,
        timerType: timerType,
        durationSeconds: durationSeconds,
        createdBy: widget.userId,
        currentSpeaker: widget.currentSpeaker,
        title: customTitle ?? '${timerType.displayName} - ${widget.currentSpeaker ?? 'Timer'}',
      );
      
      // Do NOT auto-start server timer - wait for moderator to start it
      
    } catch (e) {
      AppLogger().debug('Background server timer creation failed: $e');
      // Local timer continues working regardless
    }
  }

  Future<void> _startTimer() async {
    if (_activeTimer == null) return;
    
    try {
      // Start timer (or restart from full duration if paused)
      setState(() {
        if (_activeTimer!.isPaused) {
          // Restart from full duration
          _activeTimer = _activeTimer!.copyWith(
            status: TimerStatus.running,
            remainingSeconds: _activeTimer!.durationSeconds,
          );
        } else {
          // Normal start
          _activeTimer = _activeTimer!.copyWith(status: TimerStatus.running);
        }
      });
      _updateDisplayTimer();
      widget.onTimerStarted?.call();
      
      // Try to start server timer (non-blocking)
      if (!_activeTimer!.id.startsWith('local_')) {
        if (_activeTimer!.isPaused) {
          // Reset and start on server
          _timerService.resetTimer(_activeTimer!.id, widget.userId).then((_) {
            _timerService.startTimer(_activeTimer!.id, widget.userId);
          }).catchError((e) {
            AppLogger().debug('Server restart failed: $e');
          });
        } else {
          _timerService.startTimer(_activeTimer!.id, widget.userId).catchError((e) {
            AppLogger().debug('Server start failed: $e');
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to start timer: $e');
    }
  }

  Future<void> _pauseTimer() async {
    if (_activeTimer == null) return;
    
    try {
      // Pause local timer immediately
      _displayUpdateTimer?.cancel();
      setState(() {
        _activeTimer = _activeTimer!.copyWith(status: TimerStatus.paused);
      });
      
      // Try to pause server timer (non-blocking)
      if (!_activeTimer!.id.startsWith('local_')) {
        _timerService.pauseTimer(_activeTimer!.id, widget.userId).catchError((e) {
          AppLogger().debug('Server pause failed: $e');
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pause timer: $e');
    }
  }

  Future<void> _resumeTimer() async {
    if (_activeTimer == null) return;
    
    try {
      // Resume local timer immediately from current remaining time
      setState(() {
        _activeTimer = _activeTimer!.copyWith(status: TimerStatus.running);
      });
      _updateDisplayTimer();
      widget.onTimerStarted?.call();
      
      // Try to resume server timer (non-blocking)
      if (!_activeTimer!.id.startsWith('local_')) {
        _timerService.startTimer(_activeTimer!.id, widget.userId).catchError((e) {
          AppLogger().debug('Server resume failed: $e');
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to resume timer: $e');
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
    if (_activeTimer == null) {
      // Allow timer creation based on showControls and room type
      if (widget.showControls) {
        // For debates & discussions and open discussions, allow all users to create timers
        if (widget.roomType == RoomType.debatesDiscussions || 
            widget.roomType == RoomType.openDiscussion) {
          return true;
        }
        // For arena, only moderators can create timers
        return widget.isModerator;
      }
      return false;
    }
    // For timer control (start/pause/stop), only moderators can control
    return widget.isModerator;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 380;
        
        return GestureDetector(
          onTap: widget.isModerator && widget.showControls ? _showTimerControls : null,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 6 : 8, 
              vertical: isSmallScreen ? 3 : 4,
            ),
            constraints: BoxConstraints(
              maxWidth: isSmallScreen ? 95 : 120, // Further increased to prevent cutoff
              minWidth: isSmallScreen ? 75 : 90,  // Increased minimum width
            ),
            decoration: BoxDecoration(
              color: _getTimerColor(),
              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: _buildTimerDisplay(compact: true),
                ),
                // Remove settings icon on small screens to give timer maximum space
                if (widget.isModerator && widget.showControls && !isSmallScreen) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.settings, color: Colors.white, size: 10),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactPlaceholder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 380;
        
        return GestureDetector(
          onTap: widget.isModerator && widget.showControls ? _showCreateTimerDialog : null,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 6 : 8, 
              vertical: isSmallScreen ? 3 : 4,
            ),
            constraints: BoxConstraints(
              maxWidth: isSmallScreen ? 95 : 120, // Match active timer size
              minWidth: isSmallScreen ? 75 : 90,  // Match active timer size
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF4A4A4A), // Arena purple
              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '--:--',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 16 : 18, // Increased to match active timer
                      fontFamily: 'monospace',
                      letterSpacing: -0.5, // Tighter spacing
                    ),
                    overflow: TextOverflow.clip,
                  ),
                ),
                // Remove add icon on small screens to give timer maximum space
                if (widget.isModerator && widget.showControls && !isSmallScreen) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.add_circle_outline, color: Colors.white, size: 10),
                ],
              ],
            ),
          ),
        );
      },
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
              const SizedBox(height: 10),
              _buildTimerDisplay(),
              const SizedBox(height: 10),
              _buildProgressIndicator(),
              const SizedBox(height: 24),
              if (widget.showControls && _canControlTimer()) ...[
                _buildMainControls(),
                const SizedBox(height: 10),
                _buildSecondaryControls(),
              ],
            ] else ...[
              _buildNoTimerState(),
            ],
            if (_showPresets) ...[
              const SizedBox(height: 10),
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
    // Calculate current display time
    final seconds = _activeTimer != null 
        ? _calculateCurrentDisplayTime()
        : 0;
    final timeText = _formatTime(seconds);
    final color = _getTimerColor();
    
    // For compact mode, make timer as large as possible while preventing overflow
    double fontSize = compact ? 18 : 56; // Increased base size from 14 to 18
    if (compact) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isSmallScreen = screenWidth < 380;
      // Larger but still safe sizes
      fontSize = isSmallScreen ? 16 : 18; // Increased from 12/14 to 16/18
    }
    
    Widget timeDisplay = Text(
      timeText,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: compact ? Colors.white : color,
        fontFamily: 'monospace',
        letterSpacing: compact ? -0.5 : 0, // Tighter letter spacing for compact mode
      ),
      overflow: compact ? TextOverflow.clip : null, // Use clip instead of ellipsis
      maxLines: 1,
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
            onPressed: _resumeTimer,
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
        ] else if (_activeTimer!.remainingSeconds == 0) ...[
          ElevatedButton.icon(
            onPressed: _startTimer,
            icon: const Icon(Icons.refresh),
            label: const Text('Restart'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
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

  Widget _buildBottomSheetSecondaryControls() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isSmallScreen = screenWidth < 360;
        
        return Wrap(
          spacing: isSmallScreen ? 4 : 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            // Always show reset button in bottom sheet for easier access
            _buildCompactButton(
              onPressed: _resetTimer,
              icon: Icons.refresh,
              label: 'Reset',
              isSmallScreen: isSmallScreen,
            ),
            if (TimerPresets.canAddTime(_activeTimer!.roomType, _activeTimer!.timerType)) ...[
              _buildCompactButton(
                onPressed: () => _addTime(30),
                icon: Icons.add,
                label: '+30s',
                isSmallScreen: isSmallScreen,
              ),
              _buildCompactButton(
                onPressed: () => _addTime(60),
                icon: Icons.add,
                label: '+1m',
                isSmallScreen: isSmallScreen,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCompactButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    Color? color,
    bool isSmallScreen = false,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isSmallScreen ? 14 : 16),
      label: Text(
        label,
        style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
      ),
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 6 : 8,
          vertical: isSmallScreen ? 4 : 8,
        ),
        minimumSize: Size(isSmallScreen ? 60 : 80, isSmallScreen ? 32 : 36),
      ),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SingleChildScrollView(
            child: _CreateTimerDialog(
              roomType: widget.roomType,
              onCreateTimer: (timerType, duration, title) {
                _createTimer(timerType, duration, title);
              },
            ),
          ),
        ),
      ),
    );
  }


  void _showTimerControls() {
    if (_activeTimer == null) return;
    
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
            
            // Timer info with status
            Column(
              children: [
                Text(
                  _activeTimer!.description ?? _activeTimer!.timerType.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status: ${_activeTimer!.statusText}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _getTimerColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Control buttons
            if (_canControlTimer()) ...[
              _buildMainControls(),
              const SizedBox(height: 8),
              _buildBottomSheetSecondaryControls(),
            ] else
              Text(
                'Only moderators can control this timer',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Action buttons row
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
                if (_canControlTimer()) ...[
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
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ],
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
  final int _minutes = 3;
  final int _seconds = 0;
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _secondsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _minutesController.text = _minutes.toString();
    _secondsController.text = _seconds.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        const SizedBox(height: 10),
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
          
          const SizedBox(height: 12),
          
          // Custom Time Input
          const Text(
            'Set Custom Time',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          
          // Live preview of entered time
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Preview: ${_minutesController.text.isEmpty ? '0' : _minutesController.text}:${(_secondsController.text.isEmpty ? '0' : _secondsController.text).padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          
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
                  onChanged: (_) => setState(() {}), // Trigger rebuild for preview
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
                  onChanged: (_) => setState(() {}), // Trigger rebuild for preview
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Action buttons
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
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          
        ],
      ),
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
            widget.onCreateTimer(TimerType.general, seconds, 'Speaking Time - $label');
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

  void _setCustomTime() {
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    final totalSeconds = (minutes * 60) + seconds;
    
    if (totalSeconds > 0) {
      widget.onCreateTimer(TimerType.general, totalSeconds, 'Speaking Time - ${_formatTime(totalSeconds)}');
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

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }
}