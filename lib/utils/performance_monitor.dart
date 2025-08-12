import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import '../core/logging/app_logger.dart';

/// Real-time performance monitoring for Arena app
class PerformanceMonitor {
  static PerformanceMonitor? _instance;
  static PerformanceMonitor get instance => _instance ??= PerformanceMonitor._();
  
  PerformanceMonitor._();
  
  bool _isMonitoring = false;
  int _frameCount = 0;
  int _slowFrameCount = 0;
  Duration _totalFrameTime = Duration.zero;
  DateTime _lastReportTime = DateTime.now();
  
  // Performance thresholds
  static const Duration _slowFrameThreshold = Duration(milliseconds: 16); // 60fps = 16.67ms per frame
  static const Duration _verySlowFrameThreshold = Duration(milliseconds: 33); // 30fps = 33ms per frame
  
  /// Start monitoring performance
  void startMonitoring() {
    if (_isMonitoring || !kDebugMode) return;
    
    _isMonitoring = true;
    _frameCount = 0;
    _slowFrameCount = 0;
    _totalFrameTime = Duration.zero;
    _lastReportTime = DateTime.now();
    
    AppLogger().info('🔍 Performance monitoring started');
    
    // Monitor frame rendering time
    SchedulerBinding.instance.addTimingsCallback(_onFrameCallback);
    
    // Report performance stats every 5 seconds
    _schedulePerformanceReport();
  }
  
  /// Stop monitoring performance
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    SchedulerBinding.instance.removeTimingsCallback(_onFrameCallback);
    
    AppLogger().info('🛑 Performance monitoring stopped');
  }
  
  /// Frame callback to measure rendering performance
  void _onFrameCallback(List<FrameTiming> timings) {
    if (!_isMonitoring) return;
    
    for (final timing in timings) {
      _frameCount++;
      
      final frameDuration = Duration(
        microseconds: (timing.totalSpan.inMicroseconds),
      );
      
      _totalFrameTime += frameDuration;
      
      // Check for slow frames
      if (frameDuration > _verySlowFrameThreshold) {
        _slowFrameCount++;
        AppLogger().debug('🐌 Very slow frame detected: ${frameDuration.inMilliseconds}ms');
      } else if (frameDuration > _slowFrameThreshold) {
        _slowFrameCount++;
        AppLogger().debug('⚠️ Slow frame detected: ${frameDuration.inMilliseconds}ms');
      }
      
      // Log extremely slow frames immediately
      if (frameDuration.inMilliseconds > 100) {
        AppLogger().error('🚨 EXTREMELY SLOW FRAME: ${frameDuration.inMilliseconds}ms');
        _logFrameDetails(timing);
      }
    }
  }
  
  /// Log detailed frame information for debugging
  void _logFrameDetails(FrameTiming timing) {
    AppLogger().debug('Frame details:');
    AppLogger().debug('  Build: ${timing.buildDuration.inMilliseconds}ms');
    AppLogger().debug('  Raster: ${timing.rasterDuration.inMilliseconds}ms');
    AppLogger().debug('  Total: ${timing.totalSpan.inMilliseconds}ms');
  }
  
  /// Schedule periodic performance reports
  void _schedulePerformanceReport() {
    if (!_isMonitoring) return;
    
    Future.delayed(const Duration(seconds: 5), () {
      _reportPerformanceStats();
      _schedulePerformanceReport();
    });
  }
  
  /// Report performance statistics
  void _reportPerformanceStats() {
    if (!_isMonitoring || _frameCount == 0) return;
    
    final now = DateTime.now();
    final duration = now.difference(_lastReportTime);
    final avgFrameTime = _totalFrameTime.inMicroseconds / _frameCount;
    final fps = _frameCount / duration.inSeconds;
    final slowFramePercent = (_slowFrameCount / _frameCount) * 100;
    
    AppLogger().info('📊 Performance Report:');
    AppLogger().info('  📈 Average FPS: ${fps.toStringAsFixed(1)}');
    AppLogger().info('  ⏱️ Average frame time: ${(avgFrameTime / 1000).toStringAsFixed(1)}ms');
    AppLogger().info('  🐌 Slow frames: $_slowFrameCount/$_frameCount (${slowFramePercent.toStringAsFixed(1)}%)');
    
    // Performance recommendations
    if (slowFramePercent > 10) {
      AppLogger().warning('🚨 High slow frame rate detected! Consider optimizing UI updates.');
    } else if (slowFramePercent > 5) {
      AppLogger().warning('⚠️ Moderate slow frame rate. Monitor for performance issues.');
    } else {
      AppLogger().info('✅ Good performance - smooth 60fps rendering');
    }
    
    // Reset counters for next report
    _frameCount = 0;
    _slowFrameCount = 0;
    _totalFrameTime = Duration.zero;
    _lastReportTime = now;
  }
  
  /// Get current performance metrics
  Map<String, dynamic> getCurrentMetrics() {
    if (!_isMonitoring || _frameCount == 0) {
      return {
        'isMonitoring': _isMonitoring,
        'fps': 0.0,
        'avgFrameTime': 0.0,
        'slowFramePercent': 0.0,
      };
    }
    
    final duration = DateTime.now().difference(_lastReportTime);
    final avgFrameTime = _totalFrameTime.inMicroseconds / _frameCount;
    final fps = _frameCount / duration.inSeconds;
    final slowFramePercent = (_slowFrameCount / _frameCount) * 100;
    
    return {
      'isMonitoring': _isMonitoring,
      'fps': fps,
      'avgFrameTime': avgFrameTime / 1000, // Convert to milliseconds
      'slowFramePercent': slowFramePercent,
      'frameCount': _frameCount,
      'slowFrameCount': _slowFrameCount,
    };
  }
  
  /// Log memory usage
  void logMemoryUsage() {
    if (!kDebugMode) return;
    
    // Note: Detailed memory info requires platform-specific implementation
    AppLogger().info('💾 Memory monitoring available in Flutter DevTools');
  }
  
  /// Monitor specific widget rebuild performance
  static Widget wrapWithPerformanceMonitor(Widget child, String widgetName) {
    if (!kDebugMode) return child;
    
    return _PerformanceWrapper(
      widgetName: widgetName,
      child: child,
    );
  }
}

/// Widget wrapper for monitoring specific widget performance
class _PerformanceWrapper extends StatefulWidget {
  final String widgetName;
  final Widget child;
  
  const _PerformanceWrapper({
    required this.widgetName,
    required this.child,
  });
  
  @override
  State<_PerformanceWrapper> createState() => _PerformanceWrapperState();
}

class _PerformanceWrapperState extends State<_PerformanceWrapper> {
  int _buildCount = 0;
  DateTime? _lastBuild;
  
  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      _buildCount++;
      final now = DateTime.now();
      
      if (_lastBuild != null) {
        final timeSinceLastBuild = now.difference(_lastBuild!);
        if (timeSinceLastBuild.inMilliseconds < 16) {
          AppLogger().debug('⚡ Rapid rebuild detected in ${widget.widgetName}: ${timeSinceLastBuild.inMilliseconds}ms');
        }
      }
      
      _lastBuild = now;
      
      // Log excessive rebuilds
      if (_buildCount % 10 == 0) {
        AppLogger().debug('🔄 ${widget.widgetName} rebuilt $_buildCount times');
      }
    }
    
    return widget.child;
  }
}

/// Performance monitoring overlay widget
class PerformanceOverlay extends StatefulWidget {
  final Widget child;
  
  const PerformanceOverlay({
    super.key,
    required this.child,
  });
  
  @override
  State<PerformanceOverlay> createState() => _PerformanceOverlayState();
}

class _PerformanceOverlayState extends State<PerformanceOverlay> {
  bool _showOverlay = false;
  
  @override
  void initState() {
    super.initState();
    // Only show in debug mode
    _showOverlay = kDebugMode;
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_showOverlay) return widget.child;
    
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 100,
          right: 10,
          child: _buildPerformanceInfo(),
        ),
      ],
    );
  }
  
  Widget _buildPerformanceInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: StreamBuilder(
        stream: Stream.periodic(const Duration(seconds: 1)),
        builder: (context, snapshot) {
          final metrics = PerformanceMonitor.instance.getCurrentMetrics();
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Performance Monitor',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'FPS: ${metrics['fps'].toStringAsFixed(1)}',
                style: TextStyle(
                  color: metrics['fps'] > 55 ? Colors.green : Colors.red,
                  fontSize: 10,
                ),
              ),
              Text(
                'Frame Time: ${metrics['avgFrameTime'].toStringAsFixed(1)}ms',
                style: TextStyle(
                  color: metrics['avgFrameTime'] < 16 ? Colors.green : Colors.red,
                  fontSize: 10,
                ),
              ),
              Text(
                'Slow Frames: ${metrics['slowFramePercent'].toStringAsFixed(1)}%',
                style: TextStyle(
                  color: metrics['slowFramePercent'] < 5 ? Colors.green : Colors.red,
                  fontSize: 10,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}