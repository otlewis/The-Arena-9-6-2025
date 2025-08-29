import 'package:flutter/material.dart';
import '../logging/app_logger.dart';

/// Enhanced virtualized list with intelligent caching and memory management
class VirtualizedListOptimizer {
  static final VirtualizedListOptimizer _instance = VirtualizedListOptimizer._internal();
  factory VirtualizedListOptimizer() => _instance;
  VirtualizedListOptimizer._internal();

  final AppLogger _logger = AppLogger();
  final Map<String, List<Widget>> _widgetCache = {};
  final Map<String, ScrollController> _scrollControllers = {};

  /// Create an optimized list view with intelligent virtualization
  Widget createOptimizedListView<T>({
    required String listId,
    required List<T> items,
    required Widget Function(BuildContext context, T item, int index) itemBuilder,
    ScrollController? scrollController,
    EdgeInsetsGeometry? padding,
    bool shrinkWrap = false,
    ScrollPhysics? physics,
    double? itemExtent,
    int viewportBufferSize = 5, // Items to keep outside viewport
    bool enablePreloading = true,
  }) {
    final controller = scrollController ?? _getOrCreateScrollController(listId);
    
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (enablePreloading && notification is ScrollUpdateNotification) {
          _handleScrollUpdate(listId, items, notification, viewportBufferSize);
        }
        return false;
      },
      child: ListView.builder(
        controller: controller,
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: physics,
        itemExtent: itemExtent,
        itemCount: items.length,
        cacheExtent: _calculateOptimalCacheExtent(items.length),
        itemBuilder: (context, index) {
          return _buildOptimizedItem(
            listId,
            items[index],
            index,
            itemBuilder,
            context,
          );
        },
      ),
    );
  }

  /// Create optimized grid view with intelligent viewport management
  Widget createOptimizedGridView<T>({
    required String gridId,
    required List<T> items,
    required Widget Function(BuildContext context, T item, int index) itemBuilder,
    required SliverGridDelegate gridDelegate,
    ScrollController? scrollController,
    EdgeInsetsGeometry? padding,
    bool shrinkWrap = false,
    ScrollPhysics? physics,
    int viewportBufferSize = 10,
  }) {
    final controller = scrollController ?? _getOrCreateScrollController(gridId);
    
    return GridView.builder(
      controller: controller,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: gridDelegate,
      itemCount: items.length,
      cacheExtent: _calculateOptimalCacheExtent(items.length),
      itemBuilder: (context, index) {
        return _buildOptimizedItem(
          gridId,
          items[index],
          index,
          itemBuilder,
          context,
        );
      },
    );
  }

  Widget _buildOptimizedItem<T>(
    String listId,
    T item,
    int index,
    Widget Function(BuildContext context, T item, int index) itemBuilder,
    BuildContext context,
  ) {
    // Use RepaintBoundary to isolate widget rebuilds
    return RepaintBoundary(
      key: ValueKey('${listId}_$index'),
      child: Builder(
        builder: (context) => itemBuilder(context, item, index),
      ),
    );
  }

  ScrollController _getOrCreateScrollController(String listId) {
    return _scrollControllers.putIfAbsent(
      listId,
      () => ScrollController(),
    );
  }

  double _calculateOptimalCacheExtent(int itemCount) {
    // Dynamic cache extent based on list size
    if (itemCount < 20) return 250.0;
    if (itemCount < 100) return 500.0;
    if (itemCount < 500) return 1000.0;
    return 2000.0; // For very large lists
  }

  void _handleScrollUpdate<T>(
    String listId,
    List<T> items,
    ScrollUpdateNotification notification,
    int bufferSize,
  ) {
    final scrollController = _scrollControllers[listId];
    if (scrollController == null) return;

    final scrollOffset = scrollController.offset;
    final viewportDimension = scrollController.position.viewportDimension;
    
    // Log performance metrics periodically
    
    // Log performance metrics if debug mode
    if (scrollOffset % 1000 < 50) { // Log every ~1000 pixels scrolled
      _logger.debug('📜 List $listId scroll performance:');
      _logger.debug('  Offset: ${scrollOffset.toInt()}px');
      _logger.debug('  Viewport: ${viewportDimension.toInt()}px');
      _logger.debug('  Items: ${items.length}');
    }
  }

  /// Preload images for better scroll performance
  void preloadImages(BuildContext context, List<String> imageUrls, {int maxPreload = 20}) {
    final urlsToPreload = imageUrls.take(maxPreload);
    
    for (final url in urlsToPreload) {
      if (url.isNotEmpty) {
        precacheImage(
          NetworkImage(url),
          context,
          onError: (exception, stackTrace) {
            _logger.warning('Failed to preload image: $url');
          },
        );
      }
    }
  }

  /// Dispose resources for a specific list
  void disposeList(String listId) {
    _scrollControllers[listId]?.dispose();
    _scrollControllers.remove(listId);
    _widgetCache.remove(listId);
  }

  /// Clear all cached resources
  void clearAll() {
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    _scrollControllers.clear();
    _widgetCache.clear();
  }
}

/// Optimized sliver list for complex layouts
class OptimizedSliverList extends StatelessWidget {
  final String sliverId;
  final List<dynamic> items;
  final Widget Function(BuildContext context, dynamic item, int index) itemBuilder;
  final int bufferSize;

  const OptimizedSliverList({
    super.key,
    required this.sliverId,
    required this.items,
    required this.itemBuilder,
    this.bufferSize = 5,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return RepaintBoundary(
            key: ValueKey('${sliverId}_sliver_$index'),
            child: itemBuilder(context, items[index], index),
          );
        },
        childCount: items.length,
        semanticIndexCallback: (widget, localIndex) => localIndex,
      ),
    );
  }
}

/// Performance monitoring for list scrolling
class ListPerformanceMonitor {
  static final Map<String, DateTime> _scrollStartTimes = {};
  static final Map<String, int> _scrollEvents = {};

  static void startScrollMonitoring(String listId) {
    _scrollStartTimes[listId] = DateTime.now();
    _scrollEvents[listId] = 0;
  }

  static void recordScrollEvent(String listId) {
    _scrollEvents[listId] = (_scrollEvents[listId] ?? 0) + 1;
  }

  static void endScrollMonitoring(String listId) {
    final startTime = _scrollStartTimes[listId];
    final eventCount = _scrollEvents[listId] ?? 0;
    
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      final eventsPerSecond = eventCount / duration.inSeconds;
      
      AppLogger().debug('📊 List $listId scroll performance:');
      AppLogger().debug('  Duration: ${duration.inMilliseconds}ms');
      AppLogger().debug('  Events: $eventCount');
      AppLogger().debug('  Events/sec: ${eventsPerSecond.toStringAsFixed(1)}');
      
      _scrollStartTimes.remove(listId);
      _scrollEvents.remove(listId);
    }
  }
}

/// Mixin for widgets that use optimized lists
mixin ListOptimizationMixin<T extends StatefulWidget> on State<T> {
  final VirtualizedListOptimizer _listOptimizer = VirtualizedListOptimizer();
  final Set<String> _activeListIds = {};

  @protected
  Widget buildOptimizedList<K>({
    required String listId,
    required List<K> items,
    required Widget Function(BuildContext context, K item, int index) itemBuilder,
    ScrollController? scrollController,
    EdgeInsetsGeometry? padding,
    bool shrinkWrap = false,
    ScrollPhysics? physics,
  }) {
    _activeListIds.add(listId);
    
    return _listOptimizer.createOptimizedListView(
      listId: listId,
      items: items,
      itemBuilder: itemBuilder,
      scrollController: scrollController,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
    );
  }

  @protected
  Widget buildOptimizedGrid<K>({
    required String gridId,
    required List<K> items,
    required Widget Function(BuildContext context, K item, int index) itemBuilder,
    required SliverGridDelegate gridDelegate,
    ScrollController? scrollController,
    EdgeInsetsGeometry? padding,
    bool shrinkWrap = false,
    ScrollPhysics? physics,
  }) {
    _activeListIds.add(gridId);
    
    return _listOptimizer.createOptimizedGridView(
      gridId: gridId,
      items: items,
      itemBuilder: itemBuilder,
      gridDelegate: gridDelegate,
      scrollController: scrollController,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
    );
  }

  @override
  void dispose() {
    for (final listId in _activeListIds) {
      _listOptimizer.disposeList(listId);
    }
    super.dispose();
  }
}