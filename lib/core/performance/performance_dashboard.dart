import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'performance_monitor.dart';
import '../cache/smart_cache_manager.dart';
import '../../utils/mobile_performance_optimizer.dart';

/// Performance dashboard for monitoring app health in debug mode
class PerformanceDashboard extends StatefulWidget {
  const PerformanceDashboard({super.key});
  
  @override
  State<PerformanceDashboard> createState() => _PerformanceDashboardState();
}

class _PerformanceDashboardState extends State<PerformanceDashboard> {
  late final PerformanceMonitor _monitor;
  late final SmartCacheManager _cache;
  late final MobilePerformanceOptimizer _mobileOptimizer;
  
  @override
  void initState() {
    super.initState();
    _monitor = PerformanceMonitor();
    _cache = SmartCacheManager();
    _mobileOptimizer = MobilePerformanceOptimizer.instance;
  }
  
  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚀 Performance Dashboard'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFramePerformanceCard(),
            const SizedBox(height: 16),
            _buildCacheStatsCard(),
            const SizedBox(height: 16),
            _buildMobileOptimizationCard(),
            const SizedBox(height: 16),
            _buildOperationsCard(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFramePerformanceCard() {
    final stats = _monitor.getFrameStats();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📊 Frame Performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildStatRow('Average Frame Time', '${stats.averageFrameTime.toStringAsFixed(2)}ms'),
            _buildStatRow('Max Frame Time', '${stats.maxFrameTime.toStringAsFixed(2)}ms'),
            _buildStatRow('Slow Frames', '${stats.framesAbove16ms}'),
            _buildStatRow('Total Frames', '${stats.totalFrames}'),
            _buildStatRow('Est. FPS', '${stats.totalFrames > 0 ? (1000 / stats.averageFrameTime).toStringAsFixed(1) : 0}'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCacheStatsCard() {
    final stats = _cache.getCacheStats();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💾 Cache Performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildStatRow('Total Entries', '${stats['total_entries']}'),
            _buildStatRow('Active Entries', '${stats['active_entries']}'),
            _buildStatRow('Expired Entries', '${stats['expired_entries']}'),
            _buildStatRow('Est. Memory Usage', '${(stats['memory_usage_kb'] / 1024).toStringAsFixed(1)} MB'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                _cache.clearAll();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🗑️ Cache cleared')),
                );
              },
              child: const Text('Clear Cache'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMobileOptimizationCard() {
    final metrics = _mobileOptimizer.getMobileMetrics();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📱 Mobile Optimization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildStatRow('Platform', metrics['platform']),
            _buildStatRow('Is Mobile', '${metrics['isMobile']}'),
            _buildStatRow('Low-End Device', '${metrics['isLowEndDevice']}'),
            _buildStatRow('Optimizations Applied', '${metrics['optimizationsApplied']}'),
            _buildStatRow('Animation Duration', '${_mobileOptimizer.getMobileOptimizedAnimationDuration().inMilliseconds}ms'),
            _buildStatRow('Debounce Duration', '${_mobileOptimizer.getMobileOptimizedDebounceDuration().inMilliseconds}ms'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOperationsCard() {
    final summary = _monitor.getPerformanceSummary();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚡ Operations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildStatRow('Active Timers', '${(summary['active_timers'] as List).length}'),
            _buildStatRow('Monitoring Enabled', '${summary['monitoring_enabled']}'),
            const SizedBox(height: 8),
            if ((summary['active_timers'] as List).isNotEmpty) ...[
              const Text('Active Operations:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...(summary['active_timers'] as List).map((timer) => 
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text('• $timer'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Floating performance overlay for quick monitoring
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
  Widget build(BuildContext context) {
    if (!kDebugMode) return widget.child;
    
    return Stack(
      children: [
        widget.child,
        if (_showOverlay)
          Positioned(
            top: 100,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🚀 Performance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  StreamBuilder<FrameStats>(
                    stream: Stream.periodic(const Duration(seconds: 1), (_) => PerformanceMonitor().getFrameStats()),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final stats = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FPS: ${stats.totalFrames > 0 ? (1000 / stats.averageFrameTime).toStringAsFixed(1) : 0}', 
                               style: const TextStyle(color: Colors.green, fontSize: 12)),
                          Text('Slow: ${stats.framesAbove16ms}', 
                               style: const TextStyle(color: Colors.orange, fontSize: 12)),
                        ],
                      );
                    },
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PerformanceDashboard()),
                    ),
                    child: const Text('Open Dashboard', style: TextStyle(color: Colors.blue, fontSize: 10)),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          top: 50,
          right: 16,
          child: FloatingActionButton.small(
            onPressed: () => setState(() => _showOverlay = !_showOverlay),
            backgroundColor: Colors.blue.shade800,
            child: const Icon(Icons.speed, size: 16),
          ),
        ),
      ],
    );
  }
}