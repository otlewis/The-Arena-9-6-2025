import '../core/logging/app_logger.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/timer_state.dart';
import '../services/appwrite_timer_service.dart';
import '../services/timer_feedback_service.dart';
import '../services/enhanced_timer_sync_service.dart';
import 'timer_control_bottom_sheet.dart';

/// Enhanced timer widget with flawless synchronization
/// 
/// Features:
/// - Server time offset compensation
/// - Network latency adjustment  
/// - Automatic drift correction
/// - Fallback mechanisms for connection issues
/// - Sub-second precision display updates
class EnhancedAppwriteTimerWidget extends StatefulWidget {
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

  const EnhancedAppwriteTimerWidget({
    super.key,
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
  });

  @override
  State<EnhancedAppwriteTimerWidget> createState() => _EnhancedAppwriteTimerWidgetState();
}

class _EnhancedAppwriteTimerWidgetState extends State<EnhancedAppwriteTimerWidget>
    with TickerProviderStateMixin {
  final AppwriteTimerService _timerService = AppwriteTimerService();
  final TimerFeedbackService _feedbackService = TimerFeedbackService();
  final EnhancedTimerSyncService _syncService = EnhancedTimerSyncService();
  
  StreamSubscription<List<TimerState>>? _timersSubscription;
  Timer? _displayUpdateTimer;
  Timer? _syncCheckTimer;
  late AnimationController _progressAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  
  TimerState? _activeTimer;
  bool _isConnected = true;
  int _displayRemainingSeconds = 0;
  bool _isPreciseMode = true;
  int _consecutiveFailures = 0;
  static const int _maxFailures = 3;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeServices();
    _startSyncMonitoring();
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
      AppLogger().debug('🕐 Enhanced timer widget initializing for room: ${widget.roomId}');
      await _timerService.initialize();
      await _feedbackService.initialize();
      await _syncService.initialize();
      _setupTimerStream();
      AppLogger().debug('🕐 Enhanced timer widget setup complete for room: ${widget.roomId}');
    } catch (e) {
      AppLogger().error('🕐 Enhanced timer widget initialization failed: $e');
      _setConnectionError('Failed to initialize: $e');
    }
  }


  /// Start monitoring synchronization accuracy
  void _startSyncMonitoring() {
    _syncCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_activeTimer?.status == TimerStatus.running) {
        _recheckSynchronization();
      }
    });
  }

  /// Periodically recheck synchronization to prevent drift
  Future<void> _recheckSynchronization() async {
    if (_activeTimer == null) return;
    
    try {
      // Get fresh timer state from server
      final freshTimers = await _timerService.getRoomTimers(widget.roomId);
      final freshActiveTimer = freshTimers.firstWhere(
        (t) => t.id == _activeTimer!.id,
        orElse: () => _activeTimer!,
      );
      
      // Calculate expected remaining seconds using sync service
      final serverRemainingSeconds = _syncService.calculateRemainingSeconds(
        timerId: freshActiveTimer.id,
        originalDurationSeconds: freshActiveTimer.durationSeconds,
        timerStartTime: freshActiveTimer.startTime ?? DateTime.now(),
        isPaused: freshActiveTimer.status == TimerStatus.paused,
        pausedAt: freshActiveTimer.pausedAt,
      );
      
      // Check if we're drifting from server time
      final drift = (_displayRemainingSeconds - serverRemainingSeconds).abs();
      
      if (drift > 2) { // More than 2 seconds drift
        AppLogger().warning('🕐 Timer drift detected: ${drift}s, correcting...');
        _displayRemainingSeconds = serverRemainingSeconds;
        await _syncService.forceResync();
        
        if (mounted) {
          setState(() {}); // Update display
        }
      }
      
      _consecutiveFailures = 0; // Reset failure count on success
      
    } catch (e) {
      _consecutiveFailures++;
      AppLogger().error('🕐 Sync check failed ($_consecutiveFailures/$_maxFailures): $e');
      
      if (_consecutiveFailures >= _maxFailures) {
        _handleConnectionLoss();
      }
    }
  }


  void _handleConnectionLoss() {
    AppLogger().warning('🕐 Connection lost, entering fallback mode');
    setState(() {
      _isConnected = false;
      _isPreciseMode = false;
    });
    
    // Start aggressive reconnection attempts
    _attemptReconnection();
  }

  void _attemptReconnection() {
    Timer(const Duration(seconds: 5), () async {
      try {
        await _syncService.forceResync();
        _setupTimerStream();
        setState(() {
          _isConnected = true;
          _isPreciseMode = true;
        });
        _consecutiveFailures = 0;
        AppLogger().info('🕐 Connection restored, resuming precise mode');
      } catch (e) {
        AppLogger().error('🕐 Reconnection failed: $e');
        if (_consecutiveFailures < 10) { // Max 10 reconnection attempts
          _attemptReconnection();
        }
      }
    });
  }

  void _setupTimerStream() {
    _timersSubscription?.cancel();
    
    _timersSubscription = _timerService
        .getRoomTimersStream(widget.roomId)
        .listen(
          _onTimersUpdated,
          onError: _onStreamError,
        );
  }

  void _onTimersUpdated(List<TimerState> timers) {
    if (!mounted) return;
    
    AppLogger().debug('🕐 Enhanced timer update received for room ${widget.roomId}: ${timers.length} timers');
    
    setState(() {
      _isConnected = true;
      _consecutiveFailures = 0;
      
      // Find active timer
      final activeTimers = timers.where((t) => 
          (t.status == TimerStatus.running || t.status == TimerStatus.paused) &&
          t.remainingSeconds > 0
      ).toList();
      
      if (activeTimers.isNotEmpty) {
        _activeTimer = activeTimers.first;
        
        // Update display with server-compensated time using sync service
        _displayRemainingSeconds = _syncService.calculateRemainingSeconds(
          timerId: _activeTimer!.id,
          originalDurationSeconds: _activeTimer!.durationSeconds,
          timerStartTime: _activeTimer!.startTime ?? DateTime.now(),
          isPaused: _activeTimer!.status == TimerStatus.paused,
          pausedAt: _activeTimer!.pausedAt,
        );
        
        AppLogger().debug('🕐 Active timer found: ${_activeTimer!.id} with ${_displayRemainingSeconds}s remaining (server-compensated)');
      } else if (timers.isNotEmpty) {
        _activeTimer = timers.first;
        _displayRemainingSeconds = _activeTimer!.remainingSeconds;
      } else {
        _activeTimer = null;
        _displayRemainingSeconds = 0;
      }
    });

    _updateAnimations();
    _updateDisplayTimer();
  }

  void _onStreamError(dynamic error) {
    AppLogger().error('🕐 Enhanced timer stream error: $error');
    _consecutiveFailures++;
    
    if (_consecutiveFailures >= _maxFailures) {
      _handleConnectionLoss();
    } else {
      // Attempt to restart stream after a brief delay
      Timer(Duration(seconds: _consecutiveFailures * 2), () {
        if (mounted && _isConnected) {
          _setupTimerStream();
        }
      });
    }
  }

  void _updateDisplayTimer() {
    _displayUpdateTimer?.cancel();
    
    if (_activeTimer?.status == TimerStatus.running) {
      // Use high-frequency updates for precise display
      _displayUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted || _activeTimer?.status != TimerStatus.running) {
          timer.cancel();
          return;
        }
        
        setState(() {
          if (_displayRemainingSeconds > 0 && _activeTimer != null) {
            // Use sync service to get precise remaining time
            _displayRemainingSeconds = _syncService.calculateRemainingSeconds(
              timerId: _activeTimer!.id,
              originalDurationSeconds: _activeTimer!.durationSeconds,
              timerStartTime: _activeTimer!.startTime ?? DateTime.now(),
              isPaused: _activeTimer!.status == TimerStatus.paused,
              pausedAt: _activeTimer!.pausedAt,
            );
          }
          
          if (_displayRemainingSeconds <= 0) {
            timer.cancel();
            widget.onTimerExpired?.call();
            if (_activeTimer != null) {
              _feedbackService.onTimerExpired(_activeTimer!);
            }
          }
        });
      });
    }
  }

  void _updateAnimations() {
    if (_activeTimer?.status == TimerStatus.running) {
      _pulseAnimationController.repeat(reverse: true);
      
      final progress = _activeTimer!.durationSeconds > 0 
          ? (_activeTimer!.durationSeconds - _displayRemainingSeconds) / _activeTimer!.durationSeconds
          : 0.0;
      
      _progressAnimationController.animateTo(progress.clamp(0.0, 1.0));
    } else {
      _pulseAnimationController.stop();
    }
  }

  void _setConnectionError(String error) {
    setState(() {
      _isConnected = false;
    });
  }
  
  /// Show timer controls bottom sheet for moderators
  void _showTimerControls(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimerControlBottomSheet(
        roomId: widget.roomId,
        roomType: widget.roomType,
        userId: widget.userId,
        activeTimer: _activeTimer,
        timerService: _timerService,
      ),
    );
  }

  @override
  void dispose() {
    _timersSubscription?.cancel();
    _displayUpdateTimer?.cancel();
    _syncCheckTimer?.cancel();
    _progressAnimationController.dispose();
    _pulseAnimationController.dispose();
    _syncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_activeTimer == null) {
      return _buildNoTimerDisplay(theme);
    }
    
    return _buildTimerDisplay(theme);
  }

  Widget _buildNoTimerDisplay(ThemeData theme) {
    if (widget.compact) {
      return Text(
        '--:--',
        style: theme.textTheme.titleMedium?.copyWith(
          color: Colors.white70,
          fontFamily: 'monospace',
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'No Timer',
        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
      ),
    );
  }

  Widget _buildTimerDisplay(ThemeData theme) {
    final minutes = _displayRemainingSeconds ~/ 60;
    final seconds = _displayRemainingSeconds % 60;
    final timeText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    final isWarning = _displayRemainingSeconds <= 30 && _displayRemainingSeconds > 0;
    final isExpired = _displayRemainingSeconds <= 0;
    
    Color textColor = Colors.white;
    if (isExpired) {
      textColor = Colors.red;
    } else if (isWarning) {
      textColor = Colors.orange;
    }
    
    if (widget.compact) {
      final timerWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isConnected || !_isPreciseMode)
            const Icon(
              Icons.signal_wifi_off,
              size: 14,
              color: Colors.red,
            ),
          if (!_isConnected || !_isPreciseMode)
            const SizedBox(width: 4),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _activeTimer?.status == TimerStatus.running ? _pulseAnimation.value : 1.0,
                child: Text(
                  timeText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          // Add gear icon for moderator controls
          if (widget.isModerator && widget.showControls) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.settings,
              size: 14,
              color: Colors.white70,
            ),
          ],
        ],
      );
      
      // Make timer tappable for moderators to show controls
      if (widget.isModerator && widget.showControls) {
        return GestureDetector(
          onTap: () => _showTimerControls(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24),
            ),
            child: timerWidget,
          ),
        );
      }
      
      return timerWidget;
    }
    
    final timerContainer = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isExpired ? Colors.red : (isWarning ? Colors.orange : Colors.white24),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isConnected || !_isPreciseMode) ...[
                Icon(
                  _isConnected ? Icons.sync_problem : Icons.signal_wifi_off,
                  size: 16,
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'FALLBACK' : 'OFFLINE',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _activeTimer?.status == TimerStatus.running ? _pulseAnimation.value : 1.0,
                    child: Text(
                      timeText,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: textColor,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
              // Add gear icon for moderator controls
              if (widget.isModerator && widget.showControls) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.settings,
                  size: 18,
                  color: Colors.white70,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _activeTimer?.description ?? 'Timer',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          if (widget.showConnectionStatus) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isConnected && _isPreciseMode && _syncService.isSyncHealthy ? Icons.sync : Icons.sync_disabled,
                  size: 12,
                  color: _isConnected && _isPreciseMode && _syncService.isSyncHealthy ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  _isConnected && _isPreciseMode && _syncService.isSyncHealthy ? 'SYNCED' : 
                  (_isConnected ? 'SYNC DRIFT' : 'OFFLINE'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _isConnected && _isPreciseMode && _syncService.isSyncHealthy ? Colors.green : 
                    (_isConnected ? Colors.orange : Colors.red),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    
    // Make timer tappable for moderators
    if (widget.isModerator && widget.showControls) {
      return GestureDetector(
        onTap: () => _showTimerControls(context),
        child: timerContainer,
      );
    }
    
    return timerContainer;
  }
}