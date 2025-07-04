import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/debate_phase.dart';
import '../utils/arena_constants.dart';
import '../../../core/logging/app_logger.dart';

/// Timer state model
@immutable
class ArenaTimerState {
  final int remainingSeconds;
  final bool isRunning;
  final bool isPaused;
  final bool hasPlayed30SecWarning;
  final DebatePhase currentPhase;
  final String currentSpeaker;
  final bool speakingEnabled;
  
  const ArenaTimerState({
    required this.remainingSeconds,
    required this.isRunning,
    required this.isPaused,
    required this.hasPlayed30SecWarning,
    required this.currentPhase,
    required this.currentSpeaker,
    required this.speakingEnabled,
  });
  
  ArenaTimerState copyWith({
    int? remainingSeconds,
    bool? isRunning,
    bool? isPaused,
    bool? hasPlayed30SecWarning,
    DebatePhase? currentPhase,
    String? currentSpeaker,
    bool? speakingEnabled,
  }) {
    return ArenaTimerState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      hasPlayed30SecWarning: hasPlayed30SecWarning ?? this.hasPlayed30SecWarning,
      currentPhase: currentPhase ?? this.currentPhase,
      currentSpeaker: currentSpeaker ?? this.currentSpeaker,
      speakingEnabled: speakingEnabled ?? this.speakingEnabled,
    );
  }
  
  /// Formatted time string
  String get formattedTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Timer warning color
  Color get timerColor {
    if (remainingSeconds <= 10) {
      return Colors.red;
    } else if (remainingSeconds <= 30) {
      return Colors.orange;
    } else {
      return Colors.white;
    }
  }
  
  /// Timer icon
  IconData get timerIcon {
    if (isRunning) {
      return Icons.timer;
    } else if (isPaused) {
      return Icons.pause_circle;
    } else {
      return Icons.timer_off;
    }
  }
  
  /// Should show warning colors
  bool get shouldShowWarning => remainingSeconds <= ArenaConstants.timerWarningThreshold;
  
  /// Time is up
  bool get isTimeUp => remainingSeconds <= 0 && isRunning;
}

/// Provider for timer state
final arenaTimerProvider = StateNotifierProvider.autoDispose
    .family<ArenaTimerNotifier, ArenaTimerState, DebatePhase>(
  (ref, initialPhase) => ArenaTimerNotifier(initialPhase),
);

/// Timer state notifier
class ArenaTimerNotifier extends StateNotifier<ArenaTimerState> {
  Timer? _timer;
  VoidCallback? _onTimeout;
  VoidCallback? _on30SecWarning;
  
  ArenaTimerNotifier(DebatePhase initialPhase) : super(
    ArenaTimerState(
      remainingSeconds: initialPhase.defaultDurationSeconds ?? ArenaConstants.defaultTimerDuration,
      isRunning: false,
      isPaused: false,
      hasPlayed30SecWarning: false,
      currentPhase: initialPhase,
      currentSpeaker: initialPhase.speakerRole,
      speakingEnabled: false,
    ),
  );
  
  /// Set timeout callback
  void setTimeoutCallback(VoidCallback callback) {
    _onTimeout = callback;
  }
  
  /// Set 30-second warning callback
  void set30SecWarningCallback(VoidCallback callback) {
    _on30SecWarning = callback;
  }
  
  /// Start the timer
  void startTimer() {
    if (state.isRunning || state.remainingSeconds <= 0) return;
    
    state = state.copyWith(
      isRunning: true,
      isPaused: false,
      currentSpeaker: state.currentPhase.speakerRole,
      speakingEnabled: state.currentPhase.hasSpeaker,
      hasPlayed30SecWarning: false,
    );
    
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
    AppLogger().info('Timer started: ${state.remainingSeconds}s for ${state.currentPhase.displayName}');
  }
  
  /// Pause the timer
  void pauseTimer() {
    if (!state.isRunning) return;
    
    _timer?.cancel();
    state = state.copyWith(
      isRunning: false,
      isPaused: true,
      speakingEnabled: false,
    );
    
    AppLogger().info('Timer paused');
  }
  
  /// Resume the timer
  void resumeTimer() {
    if (!state.isPaused) return;
    
    state = state.copyWith(
      isRunning: true,
      isPaused: false,
      speakingEnabled: true,
    );
    
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
    AppLogger().info('Timer resumed');
  }
  
  /// Stop the timer
  void stopTimer() {
    _timer?.cancel();
    state = state.copyWith(
      isRunning: false,
      isPaused: false,
      speakingEnabled: false,
    );
    
    AppLogger().info('Timer stopped');
  }
  
  /// Reset the timer to phase default
  void resetTimer() {
    _timer?.cancel();
    state = state.copyWith(
      remainingSeconds: state.currentPhase.defaultDurationSeconds ?? ArenaConstants.defaultTimerDuration,
      isRunning: false,
      isPaused: false,
      speakingEnabled: false,
      hasPlayed30SecWarning: false,
    );
    
    AppLogger().info('Timer reset to ${state.remainingSeconds}s');
  }
  
  /// Set custom time
  void setCustomTime(int seconds) {
    _timer?.cancel();
    state = state.copyWith(
      remainingSeconds: seconds,
      isRunning: false,
      isPaused: false,
      hasPlayed30SecWarning: false,
    );
    
    AppLogger().info('Custom time set: ${seconds}s');
  }
  
  /// Extend time
  void extendTime(int additionalSeconds) {
    state = state.copyWith(
      remainingSeconds: state.remainingSeconds + additionalSeconds,
    );
    
    AppLogger().info('Time extended by ${additionalSeconds}s (total: ${state.remainingSeconds}s)');
  }
  
  /// Update phase
  void updatePhase(DebatePhase newPhase) {
    final wasRunning = state.isRunning;
    
    // Stop current timer
    _timer?.cancel();
    
    state = state.copyWith(
      currentPhase: newPhase,
      remainingSeconds: newPhase.defaultDurationSeconds ?? ArenaConstants.defaultTimerDuration,
      currentSpeaker: newPhase.speakerRole,
      isRunning: false,
      isPaused: false,
      speakingEnabled: false,
      hasPlayed30SecWarning: false,
    );
    
    AppLogger().info('Phase updated to: ${newPhase.displayName}');
    
    // Auto-start timer if it was previously running
    if (wasRunning && newPhase.hasSpeaker) {
      startTimer();
    }
  }
  
  /// Force speaker change
  void forceSpeakerChange(String newSpeaker) {
    state = state.copyWith(
      currentSpeaker: newSpeaker,
      speakingEnabled: true,
    );
    
    AppLogger().info('Speaker forced to: $newSpeaker');
  }
  
  /// Toggle speaking enabled
  void toggleSpeaking() {
    state = state.copyWith(speakingEnabled: !state.speakingEnabled);
    AppLogger().info('Speaking ${state.speakingEnabled ? 'enabled' : 'disabled'}');
  }
  
  /// Timer tick handler
  void _onTimerTick(Timer timer) {
    if (state.remainingSeconds <= 0) {
      _handleTimeout();
      return;
    }
    
    final newRemainingSeconds = state.remainingSeconds - 1;
    
    // Play 30-second warning
    if (newRemainingSeconds == 30 && !state.hasPlayed30SecWarning) {
      state = state.copyWith(hasPlayed30SecWarning: true);
      _on30SecWarning?.call();
      AppLogger().debug('30-second warning triggered');
    }
    
    state = state.copyWith(remainingSeconds: newRemainingSeconds);
  }
  
  /// Handle timer timeout
  void _handleTimeout() {
    _timer?.cancel();
    state = state.copyWith(
      remainingSeconds: 0,
      isRunning: false,
      speakingEnabled: false,
      hasPlayed30SecWarning: false,
    );
    
    _onTimeout?.call();
    AppLogger().info('Timer timeout for phase: ${state.currentPhase.displayName}');
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Provider for quick timer actions
final timerActionsProvider = Provider.family<TimerActions, String>((ref, roomId) {
  return TimerActions(ref);
});

/// Timer actions helper
class TimerActions {
  final Ref _ref;
  
  TimerActions(this._ref);
  
  /// Quick extend actions
  void extend30Seconds(DebatePhase phase) {
    _ref.read(arenaTimerProvider(phase).notifier).extendTime(30);
  }
  
  void extend1Minute(DebatePhase phase) {
    _ref.read(arenaTimerProvider(phase).notifier).extendTime(60);
  }
  
  void extend5Minutes(DebatePhase phase) {
    _ref.read(arenaTimerProvider(phase).notifier).extendTime(300);
  }
  
  /// Quick time presets
  void set1Minute(DebatePhase phase) {
    _ref.read(arenaTimerProvider(phase).notifier).setCustomTime(60);
  }
  
  void set3Minutes(DebatePhase phase) {
    _ref.read(arenaTimerProvider(phase).notifier).setCustomTime(180);
  }
  
  void set5Minutes(DebatePhase phase) {
    _ref.read(arenaTimerProvider(phase).notifier).setCustomTime(300);
  }
  
  void set10Minutes(DebatePhase phase) {
    _ref.read(arenaTimerProvider(phase).notifier).setCustomTime(600);
  }
}