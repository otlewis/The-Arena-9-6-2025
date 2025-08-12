import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../logging/app_logger.dart';

/// Performance monitoring utilities for the app
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final AppLogger _logger = AppLogger();
  final Map<String, DateTime> _operationTimers = {};
  final List<FrameTimingInfo> _frameTimings = [];
  bool _isMonitoring = false;
  DateTime? _lastSlowFrameLog;

  /// Initialize performance monitoring
  void initialize() {
    if (kDebugMode) {
      _logger.info('Performance monitoring initialized');
      _startFrameMonitoring();
    }
  }

  /// Start timing an operation
  void startTimer(String operationName) {
    _operationTimers[operationName] = DateTime.now();
  }

  /// End timing an operation and log the result
  Duration? endTimer(String operationName) {
    final startTime = _operationTimers.remove(operationName);
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _logger.logPerformance(operationName, duration);
      
      // Warn about slow operations
      if (duration.inMilliseconds > 1000) {
        _logger.warning('Slow operation detected: $operationName took ${duration.inMilliseconds}ms');
      }
      
      return duration;
    }
    return null;
  }

  /// Time an async operation
  Future<T> timeAsync<T>(String operationName, Future<T> Function() operation) async {
    startTimer(operationName);
    try {
      final result = await operation();
      endTimer(operationName);
      return result;
    } catch (e) {
      endTimer(operationName);
      rethrow;
    }
  }

  /// Time a synchronous operation
  T timeSync<T>(String operationName, T Function() operation) {
    startTimer(operationName);
    try {
      final result = operation();
      endTimer(operationName);
      return result;
    } catch (e) {
      endTimer(operationName);
      rethrow;
    }
  }

  /// Start monitoring frame performance
  void _startFrameMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    SchedulerBinding.instance.addTimingsCallback(_onFrameTiming);
  }

  /// Handle frame timing information (optimized to reduce overhead)
  void _onFrameTiming(List<FrameTiming> timings) {
    if (!kDebugMode) return;

    // Process only the latest timing to reduce overhead
    if (timings.isEmpty) return;
    final timing = timings.last;
    
    final buildDuration = timing.buildDuration.inMicroseconds / 1000.0;
    final rasterDuration = timing.rasterDuration.inMicroseconds / 1000.0;
    final totalDuration = buildDuration + rasterDuration;

    final frameInfo = FrameTimingInfo(
      buildTime: buildDuration,
      rasterTime: rasterDuration,
      totalTime: totalDuration,
      timestamp: DateTime.now(),
    );

    _frameTimings.add(frameInfo);

    // Keep only last 50 frames (reduced from 100 for better performance)
    if (_frameTimings.length > 50) {
      _frameTimings.removeAt(0);
    }

    // Log slow frames with throttling to avoid excessive logging
    if (totalDuration > 16.67) { // 60 FPS threshold
      // Throttle logging to max once per 1000ms to prevent log spam
      final now = DateTime.now();
      if (_lastSlowFrameLog == null || 
          now.difference(_lastSlowFrameLog!).inMilliseconds > 1000) {
        _lastSlowFrameLog = now;
        _logger.warning('Slow frame detected: ${totalDuration.toStringAsFixed(2)}ms (build: ${buildDuration.toStringAsFixed(2)}ms, raster: ${rasterDuration.toStringAsFixed(2)}ms)');
      }
    }
  }

  /// Get frame performance statistics
  FrameStats getFrameStats() {
    if (_frameTimings.isEmpty) {
      return FrameStats(
        averageFrameTime: 0,
        maxFrameTime: 0,
        minFrameTime: 0,
        framesAbove16ms: 0,
        totalFrames: 0,
      );
    }

    final frameTimes = _frameTimings.map((f) => f.totalTime).toList();
    final average = frameTimes.reduce((a, b) => a + b) / frameTimes.length;
    final max = frameTimes.reduce((a, b) => a > b ? a : b);
    final min = frameTimes.reduce((a, b) => a < b ? a : b);
    final slowFrames = frameTimes.where((time) => time > 16.67).length;

    return FrameStats(
      averageFrameTime: average,
      maxFrameTime: max,
      minFrameTime: min,
      framesAbove16ms: slowFrames,
      totalFrames: frameTimes.length,
    );
  }

  /// Log memory usage (if available)
  void logMemoryUsage(String context) {
    if (kDebugMode) {
      // Memory monitoring would require platform-specific implementation
      // This is a placeholder for future memory monitoring features
      _logger.debug('Memory usage check: $context');
    }
  }

  /// Log widget rebuild information
  void logRebuild(String widgetName) {
    if (kDebugMode) {
      _logger.debug('Widget rebuild: $widgetName');
    }
  }

  /// Monitor network request performance
  Future<T> monitorNetworkRequest<T>(
    String requestName,
    Future<T> Function() request,
  ) async {
    return timeAsync('network_$requestName', request);
  }

  /// Monitor database operation performance
  Future<T> monitorDatabaseOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    return timeAsync('database_$operationName', operation);
  }

  /// Get performance summary
  Map<String, dynamic> getPerformanceSummary() {
    final frameStats = getFrameStats();
    
    return {
      'frame_stats': {
        'average_frame_time_ms': frameStats.averageFrameTime,
        'max_frame_time_ms': frameStats.maxFrameTime,
        'min_frame_time_ms': frameStats.minFrameTime,
        'slow_frames_count': frameStats.framesAbove16ms,
        'total_frames': frameStats.totalFrames,
        'fps_estimate': frameStats.totalFrames > 0 ? 1000 / frameStats.averageFrameTime : 0,
      },
      'active_timers': _operationTimers.keys.toList(),
      'monitoring_enabled': _isMonitoring,
    };
  }

  /// Stop performance monitoring
  void dispose() {
    if (_isMonitoring) {
      SchedulerBinding.instance.removeTimingsCallback(_onFrameTiming);
      _isMonitoring = false;
    }
    _operationTimers.clear();
    _frameTimings.clear();
  }
}

/// Frame timing information
class FrameTimingInfo {
  final double buildTime;
  final double rasterTime;
  final double totalTime;
  final DateTime timestamp;

  FrameTimingInfo({
    required this.buildTime,
    required this.rasterTime,
    required this.totalTime,
    required this.timestamp,
  });
}

/// Frame performance statistics
class FrameStats {
  final double averageFrameTime;
  final double maxFrameTime;
  final double minFrameTime;
  final int framesAbove16ms;
  final int totalFrames;

  FrameStats({
    required this.averageFrameTime,
    required this.maxFrameTime,
    required this.minFrameTime,
    required this.framesAbove16ms,
    required this.totalFrames,
  });
}

/// Performance monitoring widget wrapper
class PerformanceWidget extends StatefulWidget {
  const PerformanceWidget({
    super.key,
    required this.child,
    required this.name,
    this.logRebuilds = false,
  });

  final Widget child;
  final String name;
  final bool logRebuilds;

  @override
  State<PerformanceWidget> createState() => _PerformanceWidgetState();
}

class _PerformanceWidgetState extends State<PerformanceWidget> {
  final PerformanceMonitor _monitor = PerformanceMonitor();
  int _buildCount = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.logRebuilds) {
      _buildCount++;
      _monitor.logRebuild('${widget.name} (build #$_buildCount)');
    }

    return RepaintBoundary(
      child: widget.child,
    );
  }
}