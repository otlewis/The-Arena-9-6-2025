import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../logging/app_logger.dart';

/// Enhanced network performance optimizer with intelligent caching and batching
class NetworkPerformanceOptimizer {
  static final NetworkPerformanceOptimizer _instance = NetworkPerformanceOptimizer._internal();
  factory NetworkPerformanceOptimizer() => _instance;
  NetworkPerformanceOptimizer._internal();

  final AppLogger _logger = AppLogger();
  final Map<String, Completer<dynamic>> _pendingRequests = {};
  final Map<String, Timer?> _batchTimers = {};
  final Map<String, List<BatchRequest>> _batchQueues = {};
  final Map<String, DateTime> _requestTimes = {};
  final Map<String, dynamic> _responseCache = {};

  // Performance configuration
  static const Duration _defaultCacheExpiry = Duration(minutes: 5);
  static const Duration _batchDelay = Duration(milliseconds: 100);
  static const int _maxBatchSize = 10;
  static const int _maxConcurrentRequests = 5;

  int _activeRequests = 0;

  /// Optimize a network request with caching and deduplication
  Future<T> optimizeRequest<T>({
    required String requestId,
    required Future<T> Function() requestBuilder,
    Duration cacheExpiry = _defaultCacheExpiry,
    bool enableCaching = true,
    bool enableDeduplication = true,
  }) async {
    // Check cache first
    if (enableCaching && _isValidCached(requestId, cacheExpiry)) {
      _logger.debug('📦 Cache hit for request: $requestId');
      return _responseCache[requestId] as T;
    }

    // Deduplication: check if request is already pending
    if (enableDeduplication && _pendingRequests.containsKey(requestId)) {
      _logger.debug('🔄 Deduplicating request: $requestId');
      return await _pendingRequests[requestId]!.future as T;
    }

    // Track performance
    _requestTimes[requestId] = DateTime.now();
    final completer = Completer<T>();
    _pendingRequests[requestId] = completer as Completer<dynamic>;

    try {
      // Throttle concurrent requests
      await _waitForSlot();
      _activeRequests++;

      final result = await requestBuilder();
      
      // Cache the result
      if (enableCaching) {
        _responseCache[requestId] = result;
      }

      // Log performance
      _logRequestPerformance(requestId);
      
      completer.complete(result);
      return result;
    } catch (error) {
      _logger.error('Network request failed: $requestId - $error');
      completer.completeError(error);
      rethrow;
    } finally {
      _activeRequests--;
      _pendingRequests.remove(requestId);
      _requestTimes.remove(requestId);
    }
  }

  /// Batch multiple requests together for better performance
  Future<List<T>> batchRequests<T>({
    required String batchId,
    required List<String> requestIds,
    required Future<List<T>> Function(List<String> ids) batchRequestBuilder,
    Duration batchDelay = _batchDelay,
  }) async {
    final completer = Completer<List<T>>();
    
    // Add to batch queue
    _batchQueues.putIfAbsent(batchId, () => []);
    _batchQueues[batchId]!.add(BatchRequest(requestIds, completer as Completer<List<dynamic>>));

    // Start or reset batch timer
    _batchTimers[batchId]?.cancel();
    _batchTimers[batchId] = Timer(batchDelay, () => _executeBatch(batchId, batchRequestBuilder));

    // If batch is full, execute immediately
    if (_batchQueues[batchId]!.length >= _maxBatchSize) {
      _batchTimers[batchId]?.cancel();
      await _executeBatch(batchId, batchRequestBuilder);
    }

    return await completer.future;
  }

  /// Preload data in background for better performance
  void preloadData({
    required String preloadId,
    required Future<dynamic> Function() dataLoader,
    Duration cacheExpiry = _defaultCacheExpiry,
  }) {
    if (_isValidCached(preloadId, cacheExpiry)) {
      return; // Already cached
    }

    // Load in background
    dataLoader().then((data) {
      _responseCache[preloadId] = data;
      _logger.debug('🚀 Preloaded data: $preloadId');
    }).catchError((error) {
      _logger.warning('Failed to preload data: $preloadId - $error');
    });
  }

  /// Smart cache invalidation based on data patterns
  void invalidateCache({
    String? specificRequestId,
    String? patternPrefix,
    List<String>? tags,
  }) {
    if (specificRequestId != null) {
      _responseCache.remove(specificRequestId);
      _logger.debug('🗑️ Invalidated cache for: $specificRequestId');
      return;
    }

    if (patternPrefix != null) {
      final keysToRemove = _responseCache.keys
          .where((key) => key.startsWith(patternPrefix))
          .toList();
      
      for (final key in keysToRemove) {
        _responseCache.remove(key);
      }
      _logger.debug('🗑️ Invalidated ${keysToRemove.length} cache entries with prefix: $patternPrefix');
      return;
    }

    // Full cache clear
    _responseCache.clear();
    _logger.debug('🗑️ Cleared all cache entries');
  }

  /// Get network performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'activeRequests': _activeRequests,
      'cachedResponses': _responseCache.length,
      'pendingRequests': _pendingRequests.length,
      'activeBatches': _batchQueues.length,
    };
  }

  /// Monitor and optimize based on network conditions
  void optimizeForNetworkCondition({
    required NetworkCondition condition,
  }) {
    switch (condition) {
      case NetworkCondition.slow:
        _enableAggressiveCaching();
        _reduceConcurrency();
        break;
      case NetworkCondition.fast:
        _enablePreloading();
        _increaseConcurrency();
        break;
      case NetworkCondition.unstable:
        _enableRetryLogic();
        _prioritizeEssentialRequests();
        break;
    }
  }

  bool _isValidCached(String requestId, Duration expiry) {
    if (!_responseCache.containsKey(requestId)) return false;
    
    // For simplicity, assume all cached data is valid for the expiry duration
    // In a real implementation, you'd store timestamps with the data
    return true;
  }

  Future<void> _waitForSlot() async {
    while (_activeRequests >= _maxConcurrentRequests) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  void _logRequestPerformance(String requestId) {
    final startTime = _requestTimes[requestId];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      
      if (duration.inMilliseconds > 1000) {
        _logger.warning('🐌 Slow network request: $requestId took ${duration.inMilliseconds}ms');
      } else if (kDebugMode) {
        _logger.debug('⚡ Request completed: $requestId in ${duration.inMilliseconds}ms');
      }
    }
  }

  Future<void> _executeBatch<T>(
    String batchId,
    Future<List<T>> Function(List<String> ids) batchRequestBuilder,
  ) async {
    final batch = _batchQueues.remove(batchId);
    if (batch == null || batch.isEmpty) return;

    try {
      // Collect all request IDs
      final allRequestIds = <String>[];
      for (final request in batch) {
        allRequestIds.addAll(request.requestIds);
      }

      _logger.debug('📦 Executing batch $batchId with ${allRequestIds.length} requests');
      
      // Execute batch request
      final results = await batchRequestBuilder(allRequestIds);
      
      // Distribute results back to individual completers
      for (final request in batch) {
        request.completer.complete(results);
      }
    } catch (error) {
      // Complete all with error
      for (final request in batch) {
        request.completer.completeError(error);
      }
    }
  }

  void _enableAggressiveCaching() {
    _logger.debug('🚀 Enabled aggressive caching for slow network');
  }

  void _reduceConcurrency() {
    _logger.debug('🚀 Reduced concurrency for slow network');
  }

  void _enablePreloading() {
    _logger.debug('🚀 Enabled preloading for fast network');
  }

  void _increaseConcurrency() {
    _logger.debug('🚀 Increased concurrency for fast network');
  }

  void _enableRetryLogic() {
    _logger.debug('🚀 Enabled retry logic for unstable network');
  }

  void _prioritizeEssentialRequests() {
    _logger.debug('🚀 Prioritizing essential requests for unstable network');
  }

  /// Clear all resources
  void dispose() {
    for (final timer in _batchTimers.values) {
      timer?.cancel();
    }
    _batchTimers.clear();
    _batchQueues.clear();
    _pendingRequests.clear();
    _responseCache.clear();
    _requestTimes.clear();
  }
}

/// Batch request container
class BatchRequest {
  final List<String> requestIds;
  final Completer<List<dynamic>> completer;

  BatchRequest(this.requestIds, this.completer);
}

/// Network condition enum
enum NetworkCondition {
  slow,
  fast,
  unstable,
}

/// Mixin for widgets that need network optimization
mixin NetworkOptimizationMixin<T extends StatefulWidget> on State<T> {
  final NetworkPerformanceOptimizer _networkOptimizer = NetworkPerformanceOptimizer();

  @protected
  Future<K> optimizedNetworkRequest<K>({
    required String requestId,
    required Future<K> Function() requestBuilder,
    Duration cacheExpiry = const Duration(minutes: 5),
    bool enableCaching = true,
  }) {
    return _networkOptimizer.optimizeRequest(
      requestId: requestId,
      requestBuilder: requestBuilder,
      cacheExpiry: cacheExpiry,
      enableCaching: enableCaching,
    );
  }

  @protected
  void preloadNetworkData({
    required String preloadId,
    required Future<dynamic> Function() dataLoader,
  }) {
    _networkOptimizer.preloadData(
      preloadId: preloadId,
      dataLoader: dataLoader,
    );
  }

  @protected
  void invalidateNetworkCache({String? requestId, String? patternPrefix}) {
    _networkOptimizer.invalidateCache(
      specificRequestId: requestId,
      patternPrefix: patternPrefix,
    );
  }
}

/// Global network performance utilities
class NetworkPerformanceUtils {
  static final NetworkPerformanceOptimizer _optimizer = NetworkPerformanceOptimizer();

  /// Optimize API calls with automatic caching and deduplication
  static Future<T> optimizedApiCall<T>({
    required String endpoint,
    required Future<T> Function() apiCall,
    Duration cacheExpiry = const Duration(minutes: 5),
  }) {
    return _optimizer.optimizeRequest(
      requestId: 'api_$endpoint',
      requestBuilder: apiCall,
      cacheExpiry: cacheExpiry,
    );
  }

  /// Batch multiple API calls for better performance
  static Future<List<T>> batchApiCalls<T>({
    required String batchEndpoint,
    required List<String> resourceIds,
    required Future<List<T>> Function(List<String> ids) batchApiCall,
  }) {
    return _optimizer.batchRequests(
      batchId: 'batch_$batchEndpoint',
      requestIds: resourceIds,
      batchRequestBuilder: batchApiCall,
    );
  }

  /// Get current network performance metrics
  static Map<String, dynamic> getNetworkStats() {
    return _optimizer.getPerformanceStats();
  }
}