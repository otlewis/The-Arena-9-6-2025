import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A utility class to manage StreamSubscriptions safely and prevent memory leaks.
///
/// Usage:
/// ```dart
/// class MyScreen extends StatefulWidget {
///   @override
///   State<MyScreen> createState() => _MyScreenState();
/// }
///
/// class _MyScreenState extends State<MyScreen> {
///   final _subscriptions = SubscriptionManager();
///
///   @override
///   void initState() {
///     super.initState();
///     _subscriptions.add(
///       someStream.listen((data) {
///         if (mounted) setState(() => /* update state */);
///       }),
///     );
///   }
///
///   @override
///   void dispose() {
///     _subscriptions.dispose();
///     super.dispose();
///   }
/// }
/// ```
class SubscriptionManager {
  final List<StreamSubscription> _subscriptions = [];
  final String? _debugLabel;
  bool _isDisposed = false;

  /// Create a SubscriptionManager with an optional debug label for logging.
  SubscriptionManager([this._debugLabel]);

  /// The number of active subscriptions being managed.
  int get count => _subscriptions.length;

  /// Whether this manager has been disposed.
  bool get isDisposed => _isDisposed;

  /// Add a subscription to be managed.
  ///
  /// Returns the subscription for chaining or later reference.
  /// Throws if the manager has already been disposed.
  StreamSubscription<T> add<T>(StreamSubscription<T> subscription) {
    if (_isDisposed) {
      // Cancel immediately if already disposed to prevent leaks
      subscription.cancel();
      if (kDebugMode) {
        debugPrint(
          'SubscriptionManager${_debugLabel != null ? ' [$_debugLabel]' : ''}: '
          'Attempted to add subscription after dispose. Cancelled immediately.',
        );
      }
      return subscription;
    }

    _subscriptions.add(subscription);

    if (kDebugMode && _subscriptions.length > 20) {
      debugPrint(
        'SubscriptionManager${_debugLabel != null ? ' [$_debugLabel]' : ''}: '
        'Warning - Managing ${_subscriptions.length} subscriptions. '
        'Consider if all are necessary.',
      );
    }

    return subscription;
  }

  /// Add a subscription created from a stream listen call.
  ///
  /// Convenience method that creates and adds a subscription in one call.
  StreamSubscription<T> listen<T>(
    Stream<T> stream,
    void Function(T event) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return add(
      stream.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      ),
    );
  }

  /// Remove and cancel a specific subscription.
  ///
  /// Returns true if the subscription was found and cancelled.
  Future<bool> remove(StreamSubscription subscription) async {
    if (_subscriptions.remove(subscription)) {
      await subscription.cancel();
      return true;
    }
    return false;
  }

  /// Pause all managed subscriptions.
  void pauseAll() {
    for (final subscription in _subscriptions) {
      subscription.pause();
    }
  }

  /// Resume all managed subscriptions.
  void resumeAll() {
    for (final subscription in _subscriptions) {
      subscription.resume();
    }
  }

  /// Cancel all subscriptions and clear the list.
  ///
  /// After calling this, the manager can still be reused to add new subscriptions.
  Future<void> cancelAll() async {
    final futures = <Future>[];
    for (final subscription in _subscriptions) {
      futures.add(subscription.cancel());
    }
    await Future.wait(futures);
    _subscriptions.clear();

    if (kDebugMode) {
      debugPrint(
        'SubscriptionManager${_debugLabel != null ? ' [$_debugLabel]' : ''}: '
        'Cancelled ${futures.length} subscriptions.',
      );
    }
  }

  /// Dispose of all subscriptions.
  ///
  /// After calling this, the manager should not be used again.
  /// This is typically called in a StatefulWidget's dispose method.
  Future<void> dispose() async {
    if (_isDisposed) {
      if (kDebugMode) {
        debugPrint(
          'SubscriptionManager${_debugLabel != null ? ' [$_debugLabel]' : ''}: '
          'Already disposed, ignoring duplicate dispose call.',
        );
      }
      return;
    }

    _isDisposed = true;
    await cancelAll();
  }

  /// Synchronous dispose for use in widget dispose methods.
  ///
  /// Cancels all subscriptions without waiting for completion.
  /// Use this when you need synchronous disposal in a widget's dispose method.
  void disposeSync() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    final count = _subscriptions.length;

    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    if (kDebugMode) {
      debugPrint(
        'SubscriptionManager${_debugLabel != null ? ' [$_debugLabel]' : ''}: '
        'Disposed $count subscriptions synchronously.',
      );
    }
  }
}

/// A mixin that provides subscription management for StatefulWidgets.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with SubscriptionManagerMixin {
///   @override
///   void initState() {
///     super.initState();
///     subscriptions.add(
///       someStream.listen((data) {
///         if (mounted) setState(() => /* update state */);
///       }),
///     );
///   }
///
///   @override
///   void dispose() {
///     disposeSubscriptions();
///     super.dispose();
///   }
/// }
/// ```
mixin SubscriptionManagerMixin<T extends StatefulWidget> on State<T> {
  final SubscriptionManager _subscriptionManager = SubscriptionManager();

  /// Access the subscription manager to add subscriptions.
  SubscriptionManager get subscriptions => _subscriptionManager;

  /// Dispose all subscriptions. Call this in your dispose method.
  void disposeSubscriptions() {
    _subscriptionManager.disposeSync();
  }
}
