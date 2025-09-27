import 'dart:async';
import '../core/logging/app_logger.dart';

/// Systematic disposal tracking to prevent memory leaks
/// Tracks all disposable resources and ensures proper cleanup
class DisposalTrackingSystem {
  static final DisposalTrackingSystem _instance = DisposalTrackingSystem._internal();
  factory DisposalTrackingSystem() => _instance;
  DisposalTrackingSystem._internal();

  final AppLogger _logger = AppLogger();

  // Resource tracking maps
  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, StreamController> _controllers = {};
  final Map<String, Timer> _timers = {};
  final Map<String, dynamic> _miscResources = {};

  // Disposal statistics
  int _totalTracked = 0;
  int _totalDisposed = 0;
  int _leaksDetected = 0;

  /// Register a stream subscription for tracking
  void trackSubscription(String id, StreamSubscription subscription) {
    if (_subscriptions.containsKey(id)) {
      _logger.warning('⚠️ Subscription ID already exists: $id - overwriting');
      _subscriptions[id]?.cancel();
    }
    _subscriptions[id] = subscription;
    _totalTracked++;
    _logger.debug('📊 Tracking subscription: $id (Total: ${_subscriptions.length})');
  }

  /// Register a stream controller for tracking
  void trackController(String id, StreamController controller) {
    if (_controllers.containsKey(id)) {
      _logger.warning('⚠️ Controller ID already exists: $id - overwriting');
      _controllers[id]?.close();
    }
    _controllers[id] = controller;
    _totalTracked++;
    _logger.debug('📊 Tracking controller: $id (Total: ${_controllers.length})');
  }

  /// Register a timer for tracking
  void trackTimer(String id, Timer timer) {
    if (_timers.containsKey(id)) {
      _logger.warning('⚠️ Timer ID already exists: $id - overwriting');
      _timers[id]?.cancel();
    }
    _timers[id] = timer;
    _totalTracked++;
    _logger.debug('📊 Tracking timer: $id (Total: ${_timers.length})');
  }

  /// Register miscellaneous disposable resource
  void trackResource(String id, dynamic resource, Function dispose) {
    if (_miscResources.containsKey(id)) {
      _logger.warning('⚠️ Resource ID already exists: $id - overwriting');
      final existing = _miscResources[id];
      if (existing is _TrackedResource) {
        existing.dispose();
      }
    }
    _miscResources[id] = _TrackedResource(resource, dispose);
    _totalTracked++;
    _logger.debug('📊 Tracking resource: $id (Total: ${_miscResources.length})');
  }

  /// Dispose specific subscription
  bool disposeSubscription(String id) {
    final subscription = _subscriptions.remove(id);
    if (subscription != null) {
      subscription.cancel();
      _totalDisposed++;
      _logger.debug('✅ Disposed subscription: $id');
      return true;
    }
    _logger.warning('⚠️ Subscription not found for disposal: $id');
    return false;
  }

  /// Dispose specific controller
  bool disposeController(String id) {
    final controller = _controllers.remove(id);
    if (controller != null) {
      if (!controller.isClosed) {
        controller.close();
      }
      _totalDisposed++;
      _logger.debug('✅ Disposed controller: $id');
      return true;
    }
    _logger.warning('⚠️ Controller not found for disposal: $id');
    return false;
  }

  /// Dispose specific timer
  bool disposeTimer(String id) {
    final timer = _timers.remove(id);
    if (timer != null) {
      if (timer.isActive) {
        timer.cancel();
      }
      _totalDisposed++;
      _logger.debug('✅ Disposed timer: $id');
      return true;
    }
    _logger.warning('⚠️ Timer not found for disposal: $id');
    return false;
  }

  /// Dispose specific resource
  bool disposeResource(String id) {
    final resource = _miscResources.remove(id);
    if (resource != null && resource is _TrackedResource) {
      try {
        resource.dispose();
        _totalDisposed++;
        _logger.debug('✅ Disposed resource: $id');
        return true;
      } catch (e) {
        _logger.error('❌ Failed to dispose resource $id: $e');
        return false;
      }
    }
    _logger.warning('⚠️ Resource not found for disposal: $id');
    return false;
  }

  /// Dispose all resources by category
  void disposeAllSubscriptions() {
    final ids = _subscriptions.keys.toList();
    for (final id in ids) {
      disposeSubscription(id);
    }
    _logger.info('🧹 Disposed all ${ids.length} subscriptions');
  }

  void disposeAllControllers() {
    final ids = _controllers.keys.toList();
    for (final id in ids) {
      disposeController(id);
    }
    _logger.info('🧹 Disposed all ${ids.length} controllers');
  }

  void disposeAllTimers() {
    final ids = _timers.keys.toList();
    for (final id in ids) {
      disposeTimer(id);
    }
    _logger.info('🧹 Disposed all ${ids.length} timers');
  }

  void disposeAllResources() {
    final ids = _miscResources.keys.toList();
    for (final id in ids) {
      disposeResource(id);
    }
    _logger.info('🧹 Disposed all ${ids.length} misc resources');
  }

  /// Dispose all tracked resources
  void disposeAll() {
    final totalBefore = getTotalTracked();

    disposeAllSubscriptions();
    disposeAllControllers();
    disposeAllTimers();
    disposeAllResources();

    _logger.info('🧹 DISPOSAL COMPLETE - Disposed $totalBefore resources');
    logStatistics();
  }

  /// Dispose resources by pattern matching
  void disposeByPattern(String pattern) {
    int disposed = 0;

    // Dispose matching subscriptions
    final subIds = _subscriptions.keys.where((id) => id.contains(pattern)).toList();
    for (final id in subIds) {
      if (disposeSubscription(id)) disposed++;
    }

    // Dispose matching controllers
    final ctrlIds = _controllers.keys.where((id) => id.contains(pattern)).toList();
    for (final id in ctrlIds) {
      if (disposeController(id)) disposed++;
    }

    // Dispose matching timers
    final timerIds = _timers.keys.where((id) => id.contains(pattern)).toList();
    for (final id in timerIds) {
      if (disposeTimer(id)) disposed++;
    }

    // Dispose matching resources
    final resourceIds = _miscResources.keys.where((id) => id.contains(pattern)).toList();
    for (final id in resourceIds) {
      if (disposeResource(id)) disposed++;
    }

    _logger.info('🧹 Disposed $disposed resources matching pattern: $pattern');
  }

  /// Check for potential memory leaks
  List<String> detectLeaks() {
    final leaks = <String>[];

    // Check for old subscriptions (older than 5 minutes with no activity)
    for (final entry in _subscriptions.entries) {
      // This is a simplified leak detection - in practice you'd want more sophisticated tracking
      leaks.add('Subscription: ${entry.key}');
    }

    // Check for controllers that should have been closed
    for (final entry in _controllers.entries) {
      if (!entry.value.isClosed) {
        leaks.add('Open controller: ${entry.key}');
      }
    }

    // Check for active timers
    for (final entry in _timers.entries) {
      if (entry.value.isActive) {
        leaks.add('Active timer: ${entry.key}');
      }
    }

    if (leaks.isNotEmpty) {
      _leaksDetected += leaks.length;
      _logger.warning('🚨 POTENTIAL MEMORY LEAKS DETECTED: ${leaks.length}');
      for (final leak in leaks) {
        _logger.warning('  - $leak');
      }
    }

    return leaks;
  }

  /// Get statistics
  int getTotalTracked() => _subscriptions.length + _controllers.length + _timers.length + _miscResources.length;
  int getTotalSubscriptions() => _subscriptions.length;
  int getTotalControllers() => _controllers.length;
  int getTotalTimers() => _timers.length;
  int getTotalResources() => _miscResources.length;

  /// Log current statistics
  void logStatistics() {
    _logger.info('📊 DISPOSAL TRACKING STATISTICS:');
    _logger.info('  • Active Subscriptions: ${_subscriptions.length}');
    _logger.info('  • Active Controllers: ${_controllers.length}');
    _logger.info('  • Active Timers: ${_timers.length}');
    _logger.info('  • Active Resources: ${_miscResources.length}');
    _logger.info('  • Total Tracked: $_totalTracked');
    _logger.info('  • Total Disposed: $_totalDisposed');
    _logger.info('  • Leaks Detected: $_leaksDetected');
    _logger.info('  • Current Active: ${getTotalTracked()}');
  }

  /// Get detailed status report
  Map<String, dynamic> getStatusReport() {
    return {
      'subscriptions': {
        'count': _subscriptions.length,
        'ids': _subscriptions.keys.toList(),
      },
      'controllers': {
        'count': _controllers.length,
        'ids': _controllers.keys.toList(),
      },
      'timers': {
        'count': _timers.length,
        'ids': _timers.keys.toList(),
      },
      'resources': {
        'count': _miscResources.length,
        'ids': _miscResources.keys.toList(),
      },
      'statistics': {
        'totalTracked': _totalTracked,
        'totalDisposed': _totalDisposed,
        'leaksDetected': _leaksDetected,
        'currentActive': getTotalTracked(),
      },
    };
  }

  /// Reset statistics
  void resetStatistics() {
    _totalTracked = getTotalTracked();
    _totalDisposed = 0;
    _leaksDetected = 0;
    _logger.info('📊 Reset disposal tracking statistics');
  }
}

/// Helper class for tracking miscellaneous resources
class _TrackedResource {
  final dynamic resource;
  final Function _disposeFunction;

  _TrackedResource(this.resource, this._disposeFunction);

  void dispose() {
    _disposeFunction();
  }
}

/// Mixin for easy disposal tracking in stateful widgets
mixin DisposalTrackingMixin {
  late final DisposalTrackingSystem _disposalTracker;
  late final String _widgetId;

  void initDisposalTracking({String? customId}) {
    _disposalTracker = DisposalTrackingSystem();
    _widgetId = customId ?? '${runtimeType}_${DateTime.now().millisecondsSinceEpoch}';
  }

  void trackSubscription(String name, StreamSubscription subscription) {
    _disposalTracker.trackSubscription('${_widgetId}_$name', subscription);
  }

  void trackController(String name, StreamController controller) {
    _disposalTracker.trackController('${_widgetId}_$name', controller);
  }

  void trackTimer(String name, Timer timer) {
    _disposalTracker.trackTimer('${_widgetId}_$name', timer);
  }

  void trackResource(String name, dynamic resource, Function dispose) {
    _disposalTracker.trackResource('${_widgetId}_$name', resource, dispose);
  }

  void disposeTrackedResources() {
    _disposalTracker.disposeByPattern(_widgetId);
  }
}