import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/sound_service.dart';
import '../../../core/logging/app_logger.dart';
import '../models/debate_phase.dart';
import 'arena_state_controller.dart';

/// Arena Timer Controller - DO NOT MODIFY TIMER LOGIC
/// This controller manages the arena timer exactly as the original
class ArenaTimerController extends ChangeNotifier {
  final ArenaStateController _stateController;
  final SoundService _soundService;
  late AnimationController _animationController;
  Timer? _countdownTimer;

  ArenaTimerController({
    required ArenaStateController stateController,
    required SoundService soundService,
    required TickerProvider vsync,
  }) : _stateController = stateController,
       _soundService = soundService {
    _animationController = AnimationController(
      duration: const Duration(minutes: 10), // Max duration
      vsync: vsync,
    );
  }

  AnimationController get animationController => _animationController;

  /// Start the timer
  void startTimer() {
    AppLogger().debug('⏱️ Starting timer for ${_stateController.remainingSeconds}s');
    
    _stateController.startTimer();
    _soundService.playCustomSound('start.mp3');
    
    // Start countdown
    _startCountdown();
    
    AppLogger().debug('⏱️ Timer started successfully');
  }

  /// Pause the timer
  void pauseTimer() {
    AppLogger().debug('⏸️ Pausing timer');
    
    _stateController.pauseTimer();
    _countdownTimer?.cancel();
    _animationController.stop();
    
    AppLogger().debug('⏸️ Timer paused');
  }

  /// Resume the timer
  void resumeTimer() {
    AppLogger().debug('▶️ Resuming timer');
    
    _stateController.resumeTimer();
    _startCountdown();
    
    AppLogger().debug('▶️ Timer resumed');
  }

  /// Stop the timer
  void stopTimer() {
    AppLogger().debug('⏹️ Stopping timer');
    
    _stateController.stopTimer();
    _countdownTimer?.cancel();
    _animationController.stop();
    
    AppLogger().debug('⏹️ Timer stopped');
  }

  /// Reset the timer to phase default
  void resetTimer() {
    AppLogger().debug('🔄 Resetting timer');
    
    stopTimer();
    _stateController.resetTimer();
    _animationController.reset();
    
    AppLogger().debug('🔄 Timer reset to ${_stateController.remainingSeconds}s');
  }

  /// Set custom time
  void setCustomTime(int seconds) {
    AppLogger().debug('🕐 Setting custom time: ${seconds}s');
    
    stopTimer();
    _stateController.setCustomTime(seconds);
    _animationController.reset();
    
    AppLogger().debug('🕐 Custom time set: ${seconds}s (timer ready to start)');
  }

  /// Extend current time
  void extendTime(int seconds) {
    AppLogger().debug('➕ Extending time by ${seconds}s');
    
    _stateController.extendTime(seconds);
    
    AppLogger().debug('➕ Time extended. New total: ${_stateController.remainingSeconds}s');
  }

  /// Advance to next phase
  void advanceToNextPhase() {
    final currentPhase = _stateController.currentPhase;
    final nextPhase = currentPhase.nextPhase;
    
    if (nextPhase != null) {
      AppLogger().info('⏭️ Advancing from ${currentPhase.displayName} to ${nextPhase.displayName}');
      
      stopTimer();
      _stateController.advancePhase();
      _animationController.reset();
      
      AppLogger().info('⏭️ Phase advanced successfully. New duration: ${_stateController.remainingSeconds}s');
    } else {
      AppLogger().warning('⏭️ Cannot advance - already at final phase');
    }
  }

  /// Start the countdown timer
  void _startCountdown() {
    _countdownTimer?.cancel();
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_stateController.remainingSeconds > 0) {
        _stateController.setRemainingSeconds(_stateController.remainingSeconds - 1);
        
        // Play 30-second warning
        if (_stateController.remainingSeconds == 30 && !_stateController.hasPlayed30SecWarning) {
          _stateController.setHasPlayed30SecWarning(true);
          _soundService.play30SecWarningSound();
          AppLogger().debug('🔔 30-second warning played');
        }
        
        notifyListeners();
      } else {
        // Time's up!
        timer.cancel();
        _stateController.setTimerRunning(false);
        _stateController.setHasPlayed30SecWarning(false);
        _soundService.playArenaZeroSound();
        
        AppLogger().info('⏰ Timer completed for phase: ${_stateController.currentPhase.displayName}');
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }
}