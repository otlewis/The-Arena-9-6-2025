import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../models/timer_state.dart';
import '../config/timer_presets.dart';

class TimerFeedbackService {
  static final TimerFeedbackService _instance = TimerFeedbackService._internal();
  factory TimerFeedbackService() => _instance;
  TimerFeedbackService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // Audio asset paths
  static const String _timerWarningSound = 'assets/audio/30sec.mp3';
  static const String _timerExpiredSound = 'assets/audio/arenazero.mp3';
  static const String _timerStartSound = 'assets/audio/ding.mp3';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Pre-load timer sounds if available
      await _preloadSounds();
      _isInitialized = true;
    } catch (e) {
      debugPrint('TimerFeedbackService initialization error: $e');
      // Continue without audio if assets are missing
      _isInitialized = true;
    }
  }

  Future<void> _preloadSounds() async {
    try {
      // Pre-load sounds for instant playback
      await _audioPlayer.setAsset(_timerWarningSound);
      await _audioPlayer.setAsset(_timerExpiredSound);
      await _audioPlayer.setAsset(_timerStartSound);
    } catch (e) {
      debugPrint('Sound preloading failed: $e');
    }
  }

  // Enable/disable feedback types
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
  }

  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  // Timer lifecycle feedback
  Future<void> onTimerStarted(TimerState timer) async {
    await _triggerFeedback(
      hapticType: HapticType.light,
      soundAsset: _timerStartSound,
      description: 'Timer started: ${timer.timerType.displayName}',
    );
  }

  Future<void> onTimerPaused(TimerState timer) async {
    await _triggerFeedback(
      hapticType: HapticType.medium,
      description: 'Timer paused: ${timer.timerType.displayName}',
    );
  }

  Future<void> onTimerResumed(TimerState timer) async {
    await _triggerFeedback(
      hapticType: HapticType.light,
      description: 'Timer resumed: ${timer.timerType.displayName}',
    );
  }

  Future<void> onTimerStopped(TimerState timer) async {
    await _triggerFeedback(
      hapticType: HapticType.medium,
      description: 'Timer stopped: ${timer.timerType.displayName}',
    );
  }

  Future<void> onTimerReset(TimerState timer) async {
    await _triggerFeedback(
      hapticType: HapticType.light,
      description: 'Timer reset: ${timer.timerType.displayName}',
    );
  }

  // Warning feedback (30 seconds remaining)
  Future<void> onTimerWarning(TimerState timer) async {
    await _triggerFeedback(
      hapticType: HapticType.heavy,
      soundAsset: _timerWarningSound,
      description: '30-second warning: ${timer.remainingSeconds}s remaining',
      vibrationPattern: [100, 50, 100], // Custom pattern for warnings
    );
  }

  // Expiry feedback
  Future<void> onTimerExpired(TimerState timer) async {
    await _triggerFeedback(
      hapticType: HapticType.heavy,
      soundAsset: _timerExpiredSound,
      description: 'Timer expired: ${timer.timerType.displayName}',
      vibrationPattern: [200, 100, 200, 100, 200], // Longer pattern for expiry
      repeat: 3, // Repeat the feedback 3 times
    );
  }

  // Time added feedback
  Future<void> onTimeAdded(TimerState timer, int addedSeconds) async {
    await _triggerFeedback(
      hapticType: HapticType.light,
      description: 'Added ${addedSeconds}s to timer',
    );
  }

  // Interval feedback (every minute milestone)
  Future<void> onMinuteMilestone(TimerState timer, int remainingMinutes) async {
    if (remainingMinutes <= 5 && remainingMinutes > 0) {
      await _triggerFeedback(
        hapticType: HapticType.light,
        description: '$remainingMinutes minute${remainingMinutes == 1 ? '' : 's'} remaining',
      );
    }
  }

  // Critical countdown feedback (last 10 seconds)
  Future<void> onCriticalCountdown(TimerState timer, int remainingSeconds) async {
    if (remainingSeconds <= 10 && remainingSeconds > 0) {
      final intensity = remainingSeconds <= 3 ? HapticType.heavy : HapticType.medium;
      
      await _triggerFeedback(
        hapticType: intensity,
        description: '${remainingSeconds}s remaining',
        skipSound: remainingSeconds > 3, // Only sound for last 3 seconds
      );
    }
  }

  // Core feedback triggering method
  Future<void> _triggerFeedback({
    HapticType? hapticType,
    String? soundAsset,
    List<int>? vibrationPattern,
    String? description,
    int repeat = 1,
    bool skipSound = false,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Debug logging
    if (description != null) {
      debugPrint('TimerFeedback: $description');
    }

    for (int i = 0; i < repeat; i++) {
      // Haptic feedback
      if (_vibrationEnabled && hapticType != null) {
        await _triggerHaptic(hapticType);
      }

      // Custom vibration pattern
      if (_vibrationEnabled && vibrationPattern != null) {
        await _triggerVibrationPattern(vibrationPattern);
      }

      // Audio feedback
      if (_soundEnabled && !skipSound && soundAsset != null) {
        await _playSound(soundAsset);
      }

      // Add delay between repetitions
      if (i < repeat - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> _triggerHaptic(HapticType type) async {
    try {
      switch (type) {
        case HapticType.light:
          await HapticFeedback.lightImpact();
          break;
        case HapticType.medium:
          await HapticFeedback.mediumImpact();
          break;
        case HapticType.heavy:
          await HapticFeedback.heavyImpact();
          break;
        case HapticType.selection:
          await HapticFeedback.selectionClick();
          break;
        case HapticType.vibrate:
          await HapticFeedback.vibrate();
          break;
      }
    } catch (e) {
      debugPrint('Haptic feedback error: $e');
    }
  }

  Future<void> _triggerVibrationPattern(List<int> pattern) async {
    try {
      // For more complex vibration patterns, you might need a platform-specific implementation
      // This is a simple fallback using the standard vibrate method
      for (int i = 0; i < pattern.length; i += 2) {
        if (i < pattern.length) {
          await HapticFeedback.vibrate();
          if (i + 1 < pattern.length) {
            await Future.delayed(Duration(milliseconds: pattern[i + 1]));
          }
        }
      }
    } catch (e) {
      debugPrint('Vibration pattern error: $e');
    }
  }

  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Sound playback error: $e');
      // Fallback to system sound if asset fails
      await SystemSound.play(SystemSoundType.click);
    }
  }

  // Timer state change detection helper
  void handleTimerStateChange(TimerState? previousState, TimerState currentState) {
    if (previousState == null) return;

    // Detect status changes
    if (previousState.status != currentState.status) {
      switch (currentState.status) {
        case TimerStatus.running:
          if (previousState.status == TimerStatus.paused) {
            onTimerResumed(currentState);
          } else {
            onTimerStarted(currentState);
          }
          break;
        case TimerStatus.paused:
          onTimerPaused(currentState);
          break;
        case TimerStatus.stopped:
          onTimerStopped(currentState);
          break;
        case TimerStatus.completed:
          onTimerExpired(currentState);
          break;
      }
    }

    // Detect 30-second warning (specific trigger for 30sec.mp3)
    if (currentState.remainingSeconds == 30 && 
        previousState.remainingSeconds > 30 && 
        currentState.status == TimerStatus.running) {
      onTimerWarning(currentState);
    }

    // Detect timer reaching exactly 0 seconds (specific trigger for arenazero.mp3)
    if (currentState.remainingSeconds == 0 && 
        previousState.remainingSeconds > 0 && 
        currentState.status == TimerStatus.running) {
      onTimerExpired(currentState);
    }

    // Detect minute milestones
    final prevMinutes = previousState.remainingSeconds ~/ 60;
    final currMinutes = currentState.remainingSeconds ~/ 60;
    if (prevMinutes != currMinutes && currMinutes <= 5) {
      onMinuteMilestone(currentState, currMinutes);
    }

    // Detect critical countdown
    if (currentState.remainingSeconds <= 10 && 
        currentState.remainingSeconds > 0 &&
        previousState.remainingSeconds != currentState.remainingSeconds) {
      onCriticalCountdown(currentState, currentState.remainingSeconds);
    }

    // Detect time added
    if (currentState.durationSeconds > previousState.durationSeconds) {
      final addedTime = currentState.durationSeconds - previousState.durationSeconds;
      onTimeAdded(currentState, addedTime);
    }

    // Detect reset
    if (currentState.remainingSeconds == currentState.durationSeconds &&
        previousState.remainingSeconds != currentState.remainingSeconds &&
        currentState.status == TimerStatus.stopped) {
      onTimerReset(currentState);
    }
  }

  // Test feedback methods (useful for settings/preferences)
  Future<void> testHapticFeedback(HapticType type) async {
    await _triggerHaptic(type);
  }

  Future<void> testSoundFeedback() async {
    await _playSound(_timerStartSound);
  }

  Future<void> testWarningFeedback() async {
    await _triggerFeedback(
      hapticType: HapticType.heavy,
      soundAsset: _timerWarningSound,
      description: 'Testing warning feedback',
    );
  }

  Future<void> testExpiredFeedback() async {
    await _triggerFeedback(
      hapticType: HapticType.heavy,
      soundAsset: _timerExpiredSound,
      description: 'Testing expired feedback',
      vibrationPattern: [200, 100, 200, 100, 200],
    );
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}

enum HapticType {
  light,
  medium,
  heavy,
  selection,
  vibrate,
}

// Extension to add feedback settings to TimerState
extension TimerStateWithFeedback on TimerState {
  bool get shouldTriggerWarning => isInWarningZone && soundEnabled;
  bool get shouldTriggerVibration => vibrationEnabled;
}