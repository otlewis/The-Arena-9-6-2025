import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../logging/app_logger.dart';
import 'dart:async';

/// Performance optimizer specifically for Riverpod providers
class RiverpodPerformanceOptimizer {
  static final RiverpodPerformanceOptimizer _instance = RiverpodPerformanceOptimizer._internal();
  factory RiverpodPerformanceOptimizer() => _instance;
  RiverpodPerformanceOptimizer._internal();

  final AppLogger _logger = AppLogger();
  final Map<String, dynamic> _providerCache = {};
  final Map<String, Timer?> _debounceTimers = {};
  final Map<String, int> _rebuildCounts = {};

  /// Enhanced provider with automatic rebuild optimization
  T optimizeProvider<T>(String providerId, T value, {Duration debounceTime = const Duration(milliseconds: 100)}) {
    // Track rebuild counts for monitoring
    _rebuildCounts[providerId] = (_rebuildCounts[providerId] ?? 0) + 1;
    
    if (kDebugMode && _rebuildCounts[providerId]! > 10) {
      _logger.warning('⚠️ Provider $providerId has rebuilt ${_rebuildCounts[providerId]} times');
    }

    // Check if value actually changed
    final cachedValue = _providerCache[providerId];
    if (_deepEquals(cachedValue, value)) {
      return cachedValue;
    }

    // Cache the new value
    _providerCache[providerId] = value;
    return value;
  }

  /// Debounced provider updates to prevent excessive notifications
  void debouncedProviderUpdate<T>(String providerId, void Function() notifyListeners, {Duration delay = const Duration(milliseconds: 50)}) {
    _debounceTimers[providerId]?.cancel();
    _debounceTimers[providerId] = Timer(delay, () {
      notifyListeners();
      _debounceTimers.remove(providerId);
    });
  }

  /// Deep equality check for complex objects
  bool _deepEquals(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a.runtimeType != b.runtimeType) return false;
    
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) {
          return false;
        }
      }
      return true;
    }
    
    return a == b;
  }

  /// Get rebuild statistics for monitoring
  Map<String, int> getRebuildStats() => Map.from(_rebuildCounts);

  /// Clear cache and reset counters
  void clearCache() {
    _providerCache.clear();
    _rebuildCounts.clear();
    for (final timer in _debounceTimers.values) {
      timer?.cancel();
    }
    _debounceTimers.clear();
  }

  /// Log performance statistics
  void logPerformanceStats() {
    if (!kDebugMode) return;
    
    _logger.debug('🚀 Riverpod Performance Stats:');
    _logger.debug('  Cached providers: ${_providerCache.length}');
    _logger.debug('  Active debounce timers: ${_debounceTimers.length}');
    
    final highRebuildProviders = _rebuildCounts.entries
        .where((entry) => entry.value > 5)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    if (highRebuildProviders.isNotEmpty) {
      _logger.debug('  High rebuild providers:');
      for (final entry in highRebuildProviders.take(5)) {
        _logger.debug('    ${entry.key}: ${entry.value} rebuilds');
      }
    }
  }
}

/// Enhanced StateNotifier with automatic performance optimization
abstract class OptimizedStateNotifier<T> extends StateNotifier<T> {
  OptimizedStateNotifier(T state) : super(state);
  
  final RiverpodPerformanceOptimizer _optimizer = RiverpodPerformanceOptimizer();
  String get providerId;

  @override
  set state(T newState) {
    final optimizedState = _optimizer.optimizeProvider(providerId, newState);
    if (!identical(optimizedState, state)) {
      super.state = optimizedState;
    }
  }

  /// Batched state update to prevent excessive rebuilds
  void batchedStateUpdate(T Function(T currentState) updater) {
    final newState = updater(state);
    _optimizer.debouncedProviderUpdate(
      '${providerId}_batched',
      () => state = newState,
    );
  }

  @override
  void dispose() {
    _optimizer.clearCache();
    super.dispose();
  }
}

/// Mixin for optimizing Consumer widgets
mixin ConsumerOptimizationMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final Map<String, dynamic> _lastValues = {};
  
  /// Check if provider value actually changed before rebuilding
  bool shouldRebuildForProvider<K>(String providerKey, K newValue) {
    final lastValue = _lastValues[providerKey];
    if (lastValue == newValue) {
      return false;
    }
    _lastValues[providerKey] = newValue;
    return true;
  }

  @override
  void dispose() {
    _lastValues.clear();
    super.dispose();
  }
}

/// Optimized Consumer widget that reduces unnecessary rebuilds
class OptimizedConsumer<T> extends ConsumerWidget {
  final Widget Function(BuildContext context, WidgetRef ref, T value) builder;
  final ProviderBase<T> provider;
  final String optimizationKey;

  const OptimizedConsumer({
    super.key,
    required this.provider,
    required this.builder,
    required this.optimizationKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(provider);
    final optimizer = RiverpodPerformanceOptimizer();
    
    final optimizedValue = optimizer.optimizeProvider(optimizationKey, value);
    return builder(context, ref, optimizedValue);
  }
}

/// Provider listener that automatically optimizes updates
class OptimizedProviderListener<T> extends ConsumerWidget {
  final ProviderBase<T> provider;
  final void Function(T? previous, T current) listener;
  final Widget child;
  final String optimizationKey;

  const OptimizedProviderListener({
    super.key,
    required this.provider,
    required this.listener,
    required this.child,
    required this.optimizationKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(provider, (previous, current) {
      final optimizer = RiverpodPerformanceOptimizer();
      optimizer.debouncedProviderUpdate(
        '${optimizationKey}_listener',
        () => listener(previous, current),
      );
    });
    
    return child;
  }
}

/// Performance-optimized AsyncValue handler
class OptimizedAsyncBuilder<T> extends ConsumerWidget {
  final ProviderBase<AsyncValue<T>> provider;
  final Widget Function(BuildContext context, T data) dataBuilder;
  final Widget Function(BuildContext context, Object error, StackTrace? stackTrace)? errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final String optimizationKey;

  const OptimizedAsyncBuilder({
    super.key,
    required this.provider,
    required this.dataBuilder,
    required this.optimizationKey,
    this.errorBuilder,
    this.loadingBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(provider);
    final optimizer = RiverpodPerformanceOptimizer();
    
    return asyncValue.when(
      data: (data) {
        final optimizedData = optimizer.optimizeProvider('${optimizationKey}_data', data);
        return dataBuilder(context, optimizedData);
      },
      error: (error, stackTrace) {
        return errorBuilder?.call(context, error, stackTrace) ?? 
               Center(child: Text('Error: $error'));
      },
      loading: () {
        return loadingBuilder?.call(context) ?? 
               const Center(child: CircularProgressIndicator());
      },
    );
  }
}