import 'dart:async';
import 'dart:core';
import '../core/logging/app_logger.dart';
import 'disposal_tracking_system.dart';

/// Manages weak references for event listeners to prevent memory leaks
/// Automatically cleans up listeners when target objects are garbage collected
class WeakReferenceManager {
  static final WeakReferenceManager _instance = WeakReferenceManager._internal();
  factory WeakReferenceManager() => _instance;
  WeakReferenceManager._internal();

  final AppLogger _logger = AppLogger();
  final DisposalTrackingSystem _disposalTracker = DisposalTrackingSystem();

  // Track weak references and their associated cleanup functions
  final Map<String, WeakReference<Object>> _weakReferences = {};
  final Map<String, List<Function()>> _cleanupFunctions = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  // Periodic cleanup timer
  Timer? _cleanupTimer;
  bool _isInitialized = false;

  /// Initialize the weak reference manager with periodic cleanup
  void initialize() {
    if (_isInitialized) return;

    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) => _performCleanup());
    // Track cleanup timer for memory leak prevention
    _disposalTracker.trackTimer('weak_ref_cleanup_timer', _cleanupTimer!);
    _isInitialized = true;
    _logger.info('🔗 Weak reference manager initialized with 30s cleanup cycle');
  }

  /// Register a weak reference with cleanup functions
  void registerWeakReference<T extends Object>(
    String id,
    T target,
    List<Function()> cleanupFunctions,
  ) {
    // Clean up existing reference if it exists
    _cleanupReference(id);

    // Register new weak reference
    _weakReferences[id] = WeakReference(target);
    _cleanupFunctions[id] = cleanupFunctions;

    _logger.debug('🔗 Registered weak reference: $id');
  }

  /// Register a stream subscription with weak reference to target
  void registerWeakSubscription<T extends Object>(
    String id,
    T target,
    StreamSubscription subscription,
  ) {
    registerWeakReference(id, target, [
      () {
        subscription.cancel();
        _subscriptions.remove(id);
      }
    ]);

    _subscriptions[id] = subscription;
    // Track subscription in disposal tracking system
    _disposalTracker.trackSubscription('weak_ref_' + id, subscription);
    _logger.debug('🔗 Registered weak subscription: $id');
  }

  /// Register an event listener with weak reference
  void registerWeakListener<T extends Object>(
    String id,
    T target,
    Function removeListener,
  ) {
    registerWeakReference(id, target, [
      () => removeListener(),
    ]);
  }

  /// Check if a reference is still alive
  bool isAlive(String id) {
    final weakRef = _weakReferences[id];
    return weakRef?.target != null;
  }

  /// Get the target object if still alive
  T? getTarget<T extends Object>(String id) {
    final weakRef = _weakReferences[id];
    return weakRef?.target as T?;
  }

  /// Manually trigger cleanup for a specific reference
  void cleanupReference(String id) {
    _cleanupReference(id);
  }

  /// Internal cleanup for a specific reference
  void _cleanupReference(String id) {
    final cleanupFunctions = _cleanupFunctions.remove(id);
    if (cleanupFunctions != null) {
      for (final cleanup in cleanupFunctions) {
        try {
          cleanup();
        } catch (e) {
          _logger.error('Error during cleanup for $id: $e');
        }
      }
    }

    _weakReferences.remove(id);
    _subscriptions.remove(id);
    // Remove from disposal tracking system
    _disposalTracker.disposeSubscription('weak_ref_' + id);
    _logger.debug('🧹 Cleaned up weak reference: $id');
  }

  /// Perform periodic cleanup of dead references
  void _performCleanup() {
    final deadReferences = <String>[];

    for (final entry in _weakReferences.entries) {
      if (entry.value.target == null) {
        deadReferences.add(entry.key);
      }
    }

    if (deadReferences.isNotEmpty) {
      _logger.info('🧹 Cleaning up ${deadReferences.length} dead weak references');
      for (final id in deadReferences) {
        _cleanupReference(id);
      }
    }
  }

  /// Get statistics about managed references
  Map<String, dynamic> getStatistics() {
    int aliveCount = 0;
    int deadCount = 0;

    for (final weakRef in _weakReferences.values) {
      if (weakRef.target != null) {
        aliveCount++;
      } else {
        deadCount++;
      }
    }

    return {
      'totalReferences': _weakReferences.length,
      'aliveReferences': aliveCount,
      'deadReferences': deadCount,
      'subscriptions': _subscriptions.length,
      'cleanupFunctions': _cleanupFunctions.length,
    };
  }

  /// Log current statistics
  void logStatistics() {
    final stats = getStatistics();
    _logger.info('🔗 WEAK REFERENCE STATISTICS:');
    _logger.info('  • Total References: ${stats['totalReferences']}');
    _logger.info('  • Alive References: ${stats['aliveReferences']}');
    _logger.info('  • Dead References: ${stats['deadReferences']}');
    _logger.info('  • Active Subscriptions: ${stats['subscriptions']}');
  }

  /// Dispose the manager and clean up all references
  void dispose() {
    // Use disposal tracking system to clean up timer
    _disposalTracker.disposeTimer('weak_ref_cleanup_timer');
    _cleanupTimer = null;

    final allIds = _weakReferences.keys.toList();
    for (final id in allIds) {
      _cleanupReference(id);
    }

    // Clean up any remaining subscriptions in disposal tracker
    _disposalTracker.disposeByPattern('weak_ref_');

    _isInitialized = false;
    _logger.info('🧹 Weak reference manager disposed');
  }
}

/// Mixin for easy weak reference management in classes
mixin WeakReferenceMixin {
  late final WeakReferenceManager _weakRefManager;
  late final String _instanceId;

  void initWeakReferences({String? customId}) {
    _weakRefManager = WeakReferenceManager();
    _instanceId = customId ?? '${runtimeType}_${DateTime.now().millisecondsSinceEpoch}';

    if (!_weakRefManager._isInitialized) {
      _weakRefManager.initialize();
    }
  }

  /// Register a weak subscription that will be auto-cleaned when this object is GC'd
  void registerWeakSubscription(String name, StreamSubscription subscription) {
    _weakRefManager.registerWeakSubscription('${_instanceId}_$name', this, subscription);
  }

  /// Register a weak listener that will be auto-cleaned when this object is GC'd
  void registerWeakListener(String name, Function removeListener) {
    _weakRefManager.registerWeakListener('${_instanceId}_$name', this, removeListener);
  }

  /// Register a custom weak reference with cleanup functions
  void registerWeakReference(String name, List<Function()> cleanupFunctions) {
    _weakRefManager.registerWeakReference('${_instanceId}_$name', this, cleanupFunctions);
  }

  /// Check if a specific weak reference is still alive
  bool isWeakReferenceAlive(String name) {
    return _weakRefManager.isAlive('${_instanceId}_$name');
  }

  /// Manually clean up weak references for this instance
  void cleanupWeakReferences() {
    // Find all references for this instance and clean them up
    final allIds = _weakRefManager._weakReferences.keys
        .where((id) => id.startsWith(_instanceId))
        .toList();

    for (final id in allIds) {
      _weakRefManager._cleanupReference(id);
    }
  }
}

/// Helper class for creating weak event listeners
class WeakEventListener<T extends Object> {
  final WeakReference<T> _targetRef;
  final String _listenerId;
  final WeakReferenceManager _manager;

  WeakEventListener._(this._targetRef, this._listenerId, this._manager);

  /// Create a weak event listener
  static WeakEventListener<T> create<T extends Object>(
    T target,
    String listenerId,
    Function removeListener,
  ) {
    final manager = WeakReferenceManager();
    final listener = WeakEventListener._(WeakReference(target), listenerId, manager);

    manager.registerWeakListener(listenerId, target, removeListener);

    return listener;
  }

  /// Get the target if still alive
  T? get target => _targetRef.target;

  /// Check if target is still alive
  bool get isAlive => _targetRef.target != null;

  /// Manually remove this listener
  void remove() {
    _manager.cleanupReference(_listenerId);
  }
}

/// Helper class for weak stream subscriptions
class WeakStreamSubscription<T extends Object> {
  final WeakReference<T> _targetRef;
  final StreamSubscription _subscription;
  final String _subscriptionId;
  final WeakReferenceManager _manager;

  WeakStreamSubscription._(
    this._targetRef,
    this._subscription,
    this._subscriptionId,
    this._manager,
  );

  /// Create a weak stream subscription
  static WeakStreamSubscription<T> create<T extends Object>(
    T target,
    Stream stream,
    void Function(dynamic) onData, {
    String? subscriptionId,
    Function? onError,
    void Function()? onDone,
  }) {
    final manager = WeakReferenceManager();
    final id = subscriptionId ?? 'sub_${DateTime.now().millisecondsSinceEpoch}';

    late final StreamSubscription subscription;
    subscription = stream.listen(
      (data) {
        // Check if weak reference target is still alive before calling handler
        final weakRef = WeakReference(target);
        if (weakRef.target != null) {
          onData(data);
        } else {
          // Target was garbage collected, cancel subscription
          subscription.cancel();
          manager.cleanupReference(id);
        }
      },
      onError: onError,
      onDone: onDone,
    );

    final weakSub = WeakStreamSubscription._(
      WeakReference(target),
      subscription,
      id,
      manager,
    );

    manager.registerWeakSubscription(id, target, subscription);

    return weakSub;
  }

  /// Get the target if still alive
  T? get target => _targetRef.target;

  /// Check if target is still alive
  bool get isAlive => _targetRef.target != null;

  /// Cancel the subscription
  void cancel() {
    _subscription.cancel();
    _manager.cleanupReference(_subscriptionId);
  }

  /// Pause the subscription
  void pause() {
    _subscription.pause();
  }

  /// Resume the subscription
  void resume() {
    _subscription.resume();
  }
}