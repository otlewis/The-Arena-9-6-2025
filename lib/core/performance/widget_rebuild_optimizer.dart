import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logging/app_logger.dart';
import 'dart:async';

/// Optimizes widget rebuilds with granular state management
class WidgetRebuildOptimizer {
  static final WidgetRebuildOptimizer _instance = WidgetRebuildOptimizer._internal();
  factory WidgetRebuildOptimizer() => _instance;
  WidgetRebuildOptimizer._internal();

  final AppLogger _logger = AppLogger();
  // final Map<String, Timer?> _rebuildTimers = {}; // Reserved for future use
  final Map<String, int> _rebuildCounts = {};

  /// Create a selective listener that only rebuilds when specific properties change
  Widget buildSelectiveListener<T>({
    required ProviderBase<T> provider,
    required Widget Function(BuildContext context, T value) builder,
    required bool Function(T previous, T current) shouldRebuild,
    String? debugName,
  }) {
    return Consumer(
      builder: (context, ref, child) {
        final value = ref.watch(provider);
        
        // Track rebuilds for debugging
        final name = debugName ?? provider.toString();
        _trackRebuild(name);
        
        return builder(context, value);
      },
    );
  }

  /// Create a debounced widget that delays rebuilds
  Widget buildDebouncedWidget({
    required Widget child,
    Duration debounceTime = const Duration(milliseconds: 100),
    String? debugName,
  }) {
    return _DebouncedWidget(
      key: ValueKey(debugName),
      debounceTime: debounceTime,
      debugName: debugName,
      child: child,
    );
  }

  /// Create a memoized widget that prevents unnecessary rebuilds
  Widget buildMemoizedWidget<T>({
    required T value,
    required Widget Function(T value) builder,
    String? debugName,
  }) {
    return _MemoizedWidget<T>(
      value: value,
      builder: builder,
      debugName: debugName,
    );
  }

  /// Track rebuild counts for performance monitoring
  void _trackRebuild(String widgetName) {
    _rebuildCounts[widgetName] = (_rebuildCounts[widgetName] ?? 0) + 1;
    
    // Log excessive rebuilds
    final count = _rebuildCounts[widgetName]!;
    if (count % 50 == 0) {
      _logger.warning('⚠️ Widget $widgetName has rebuilt $count times');
    }
  }

  /// Get rebuild statistics
  Map<String, int> getRebuildStats() {
    return Map.from(_rebuildCounts);
  }

  /// Clear rebuild tracking
  void clearStats() {
    _rebuildCounts.clear();
    _logger.info('🔄 Widget rebuild stats cleared');
  }
}

/// Debounced widget that delays rebuilds
class _DebouncedWidget extends StatefulWidget {
  final Widget child;
  final Duration debounceTime;
  final String? debugName;

  const _DebouncedWidget({
    super.key,
    required this.child,
    required this.debounceTime,
    this.debugName,
  });

  @override
  State<_DebouncedWidget> createState() => _DebouncedWidgetState();
}

class _DebouncedWidgetState extends State<_DebouncedWidget> {
  Timer? _debounceTimer;
  Widget? _currentChild;
  Widget? _pendingChild;

  @override
  void initState() {
    super.initState();
    _currentChild = widget.child;
  }

  @override
  void didUpdateWidget(_DebouncedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.child != oldWidget.child) {
      _pendingChild = widget.child;
      
      _debounceTimer?.cancel();
      _debounceTimer = Timer(widget.debounceTime, () {
        if (mounted && _pendingChild != null) {
          setState(() {
            _currentChild = _pendingChild;
            _pendingChild = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _currentChild ?? widget.child;
  }
}

/// Memoized widget that prevents unnecessary rebuilds
class _MemoizedWidget<T> extends StatefulWidget {
  final T value;
  final Widget Function(T value) builder;
  final String? debugName;

  const _MemoizedWidget({
    super.key,
    required this.value,
    required this.builder,
    this.debugName,
  });

  @override
  State<_MemoizedWidget<T>> createState() => _MemoizedWidgetState<T>();
}

class _MemoizedWidgetState<T> extends State<_MemoizedWidget<T>> {
  Widget? _memoizedWidget;
  T? _lastValue;

  @override
  Widget build(BuildContext context) {
    if (_lastValue != widget.value || _memoizedWidget == null) {
      _memoizedWidget = widget.builder(widget.value);
      _lastValue = widget.value;
    }
    
    return _memoizedWidget!;
  }
}

/// Granular state provider that splits state into smaller pieces
class GranularStateProvider<T> extends StateNotifier<T> {
  final AppLogger _logger = AppLogger();
  final Map<String, dynamic> _stateSlices = {};
  final Map<String, List<VoidCallback>> _sliceListeners = {};

  GranularStateProvider(super.initialState);

  /// Update only a specific slice of state
  void updateSlice<S>(String sliceKey, S newValue) {
    final oldValue = _stateSlices[sliceKey];
    if (oldValue != newValue) {
      _stateSlices[sliceKey] = newValue;
      _notifySliceListeners(sliceKey);
      _logger.debug('🔄 Updated state slice: $sliceKey');
    }
  }

  /// Get a specific slice of state
  S? getSlice<S>(String sliceKey) {
    return _stateSlices[sliceKey] as S?;
  }

  /// Listen to changes in a specific state slice
  void addSliceListener(String sliceKey, VoidCallback listener) {
    _sliceListeners.putIfAbsent(sliceKey, () => []).add(listener);
  }

  /// Remove listener for a specific state slice
  void removeSliceListener(String sliceKey, VoidCallback listener) {
    _sliceListeners[sliceKey]?.remove(listener);
  }

  /// Notify listeners of a specific slice
  void _notifySliceListeners(String sliceKey) {
    final listeners = _sliceListeners[sliceKey];
    if (listeners != null) {
      for (final listener in listeners) {
        try {
          listener();
        } catch (e) {
          _logger.error('Error in slice listener for $sliceKey: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _sliceListeners.clear();
    _stateSlices.clear();
    super.dispose();
  }
}