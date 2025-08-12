import 'dart:async';
import 'package:flutter/material.dart';
import '../core/logging/app_logger.dart';

/// Utility class for debouncing rapid operations to improve performance
class PerformanceDebouncer {
  Timer? _timer;
  final Duration _delay;
  final String? _debugLabel;
  
  PerformanceDebouncer({
    Duration delay = const Duration(milliseconds: 300),
    String? debugLabel,
  }) : _delay = delay, _debugLabel = debugLabel;
  
  /// Debounce a callback - only executes after delay period with no new calls
  void call(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(_delay, () {
      if (_debugLabel != null) {
        AppLogger().debug('🎯 Executing debounced operation: $_debugLabel');
      }
      callback();
    });
  }
  
  /// Cancel any pending operations
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
  
  /// Check if operation is pending
  bool get isPending => _timer?.isActive ?? false;
  
  /// Dispose resources
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Throttle utility - executes at most once per interval
class PerformanceThrottler {
  Timer? _timer;
  DateTime? _lastExecution;
  final Duration _interval;
  final String? _debugLabel;
  
  PerformanceThrottler({
    Duration interval = const Duration(milliseconds: 100),
    String? debugLabel,
  }) : _interval = interval, _debugLabel = debugLabel;
  
  /// Throttle a callback - executes at most once per interval
  void call(VoidCallback callback) {
    final now = DateTime.now();
    
    if (_lastExecution == null || 
        now.difference(_lastExecution!) >= _interval) {
      _lastExecution = now;
      if (_debugLabel != null) {
        AppLogger().debug('⚡ Executing throttled operation: $_debugLabel');
      }
      callback();
    }
  }
  
  /// Force execution (ignoring throttle)
  void executeNow(VoidCallback callback) {
    _lastExecution = DateTime.now();
    if (_debugLabel != null) {
      AppLogger().debug('🚀 Force executing throttled operation: $_debugLabel');
    }
    callback();
  }
  
  /// Dispose resources
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _lastExecution = null;
  }
}