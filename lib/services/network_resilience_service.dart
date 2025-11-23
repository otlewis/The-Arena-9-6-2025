import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/logging/app_logger.dart';
import 'device_capabilities_service.dart';

/// Service for handling poor network conditions and connection reliability
class NetworkResilienceService {
  static final NetworkResilienceService _instance = NetworkResilienceService._internal();
  factory NetworkResilienceService() => _instance;
  NetworkResilienceService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  // Network state
  bool _isOnline = true;
  NetworkQuality _networkQuality = NetworkQuality.good;
  NetworkType _networkType = NetworkType.unknown;
  int _consecutiveFailures = 0;
  
  // Circuit breaker state
  final Map<String, CircuitBreakerState> _circuitBreakers = {};

  // Timer for periodic quality monitoring
  Timer? _qualityMonitoringTimer;

  // Streams
  final StreamController<bool> _connectionController = StreamController.broadcast();
  final StreamController<NetworkQuality> _qualityController = StreamController.broadcast();
  
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<NetworkQuality> get networkQualityStream => _qualityController.stream;
  
  bool get isOnline => _isOnline;
  NetworkQuality get networkQuality => _networkQuality;
  NetworkType get networkType => _networkType;
  
  /// Initialize network monitoring
  Future<void> initialize() async {
    AppLogger().info('🌐 Initializing Network Resilience Service');
    
    // Monitor connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
      onError: (error) => AppLogger().error('Connectivity monitoring error: $error'),
    );
    
    // Initial connection check
    await _checkInitialConnection();
    
    // Start periodic network quality checks
    _startNetworkQualityMonitoring();
  }
  
  /// Handle connectivity changes
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasConnection = results.any((result) => 
      result != ConnectivityResult.none);
    
    // Update network type
    _updateNetworkType(results);
    
    if (hasConnection != _isOnline) {
      _isOnline = hasConnection;
      _connectionController.add(_isOnline);
      
      if (_isOnline) {
        AppLogger().info('🌐 Connection restored - Type: ${_networkType.name}');
        _resetCircuitBreakers();
        _checkNetworkQuality();
      } else {
        AppLogger().warning('🌐 Connection lost');
        _networkQuality = NetworkQuality.offline;
        _qualityController.add(_networkQuality);
      }
    }
  }
  
  /// Update network type based on connectivity results
  void _updateNetworkType(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.ethernet)) {
      _networkType = NetworkType.ethernet;
    } else if (results.contains(ConnectivityResult.wifi)) {
      _networkType = NetworkType.wifi;
    } else if (results.contains(ConnectivityResult.mobile)) {
      // Try to determine cellular generation
      _networkType = _determineCellularType();
    } else {
      _networkType = NetworkType.unknown;
    }
  }
  
  /// Determine cellular type (2G/3G/4G/5G) with better detection
  NetworkType _determineCellularType() {
    // Enhanced detection using latency and connection quality
    try {
      // Use latency-based detection for more accuracy
      final latency = _lastMeasuredLatency;
      
      if (latency > 800 || _networkQuality == NetworkQuality.offline) {
        return NetworkType.cellular2G; // EDGE/GPRS - very high latency
      } else if (latency > 400 || _networkQuality == NetworkQuality.poor) {
        return NetworkType.cellular3G; // 3G/HSPA - high latency
      } else if (latency > 100 || _networkQuality == NetworkQuality.moderate) {
        return NetworkType.cellular4G; // 4G/LTE - moderate latency
      } else if (latency <= 100 && _networkQuality == NetworkQuality.good) {
        return NetworkType.cellular5G; // 5G - low latency
      } else {
        return NetworkType.cellular4G; // Default to 4G
      }
    } catch (e) {
      return NetworkType.cellular4G; // Default to 4G
    }
  }
  
  int _lastMeasuredLatency = 100; // Store last measured latency
  
  /// Check initial connection status
  Future<void> _checkInitialConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
    } catch (e) {
      AppLogger().error('Failed to check initial connection: $e');
      _isOnline = false;
    }
  }
  
  /// Start periodic network quality monitoring
  void _startNetworkQualityMonitoring() {
    _qualityMonitoringTimer?.cancel();
    _qualityMonitoringTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isOnline) _checkNetworkQuality();
    });
  }
  
  /// Check network quality with ping test
  Future<void> _checkNetworkQuality() async {
    if (!_isOnline) return;
    
    try {
      final stopwatch = Stopwatch()..start();
      
      // Ping test to assess connection quality
      await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      
      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;
      _lastMeasuredLatency = latency; // Store for network type detection
      
      _updateNetworkQuality(latency);
      _consecutiveFailures = 0;
      
    } catch (e) {
      _consecutiveFailures++;
      AppLogger().warning('Network quality check failed: $e');
      
      if (_consecutiveFailures >= 3) {
        _networkQuality = NetworkQuality.poor;
        _qualityController.add(_networkQuality);
      }
    }
  }
  
  /// Update network quality based on latency
  void _updateNetworkQuality(int latencyMs) {
    NetworkQuality newQuality;
    
    if (latencyMs < 100) {
      newQuality = NetworkQuality.good;
    } else if (latencyMs < 500) {
      newQuality = NetworkQuality.moderate;
    } else {
      newQuality = NetworkQuality.poor;
    }
    
    if (newQuality != _networkQuality) {
      _networkQuality = newQuality;
      _qualityController.add(_networkQuality);
      AppLogger().info('🌐 Network quality: ${_networkQuality.name} (${latencyMs}ms)');
    }
  }
  
  /// Circuit breaker pattern for API calls
  Future<T> executeWithCircuitBreaker<T>(
    String operationId,
    Future<T> Function() operation, {
    int failureThreshold = 5,
    Duration cooldownPeriod = const Duration(minutes: 1),
  }) async {
    final circuitBreaker = _circuitBreakers[operationId] ??= CircuitBreakerState();
    
    // Check if circuit is open
    if (circuitBreaker.isOpen) {
      if (DateTime.now().difference(circuitBreaker.lastFailureTime!) < cooldownPeriod) {
        throw CircuitBreakerOpenException('Circuit breaker open for $operationId');
      } else {
        // Try to close circuit (half-open state)
        circuitBreaker.state = CircuitState.halfOpen;
      }
    }
    
    try {
      final result = await operation();
      
      // Success - close circuit
      if (circuitBreaker.state == CircuitState.halfOpen) {
        circuitBreaker.reset();
        AppLogger().info('🔄 Circuit breaker closed for $operationId');
      }
      
      return result;
    } catch (e) {
      circuitBreaker.failures++;
      circuitBreaker.lastFailureTime = DateTime.now();
      
      if (circuitBreaker.failures >= failureThreshold) {
        circuitBreaker.state = CircuitState.open;
        AppLogger().warning('⚡ Circuit breaker opened for $operationId');
      }
      
      rethrow;
    }
  }
  
  /// Reset all circuit breakers (when connection is restored)
  void _resetCircuitBreakers() {
    for (final breaker in _circuitBreakers.values) {
      breaker.reset();
    }
    AppLogger().info('🔄 All circuit breakers reset');
  }

  /// Manually reset a specific circuit breaker (for development/debugging)
  void resetCircuitBreaker(String operationId) {
    final breaker = _circuitBreakers[operationId];
    if (breaker != null) {
      breaker.reset();
      AppLogger().info('🔄 Circuit breaker reset for $operationId');
    }
  }

  /// Manually reset all circuit breakers (for development/debugging)
  void resetAllCircuitBreakers() {
    _resetCircuitBreakers();
  }
  
  /// Get adaptive timeout based on network quality
  Duration getAdaptiveTimeout({Duration baseTimeout = const Duration(seconds: 10)}) {
    switch (_networkQuality) {
      case NetworkQuality.good:
        return baseTimeout;
      case NetworkQuality.moderate:
        return Duration(milliseconds: (baseTimeout.inMilliseconds * 1.5).round());
      case NetworkQuality.poor:
        return Duration(milliseconds: (baseTimeout.inMilliseconds * 3).round());
      case NetworkQuality.offline:
        return const Duration(seconds: 60);
    }
  }
  
  /// Get retry delay with exponential backoff
  Duration getRetryDelay(int attemptNumber) {
    final baseDelay = Duration(seconds: attemptNumber * attemptNumber);
    
    // Adjust based on network quality
    switch (_networkQuality) {
      case NetworkQuality.good:
        return baseDelay;
      case NetworkQuality.moderate:
        return Duration(milliseconds: (baseDelay.inMilliseconds * 1.5).round());
      case NetworkQuality.poor:
        return Duration(milliseconds: (baseDelay.inMilliseconds * 2).round());
      case NetworkQuality.offline:
        return const Duration(minutes: 1);
    }
  }
  
  /// Check if should reduce data quality
  bool shouldReduceDataQuality() {
    return _networkQuality == NetworkQuality.poor || _consecutiveFailures > 2;
  }
  
  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _qualityMonitoringTimer?.cancel();
    _connectionController.close();
    _qualityController.close();
  }
}

enum NetworkQuality {
  good,
  moderate, 
  poor,
  offline
}

enum CircuitState {
  closed,
  open,
  halfOpen
}

class CircuitBreakerState {
  CircuitState state = CircuitState.closed;
  int failures = 0;
  DateTime? lastFailureTime;
  
  bool get isOpen => state == CircuitState.open;
  
  void reset() {
    state = CircuitState.closed;
    failures = 0;
    lastFailureTime = null;
  }
}

class CircuitBreakerOpenException implements Exception {
  final String message;
  CircuitBreakerOpenException(this.message);
  
  @override
  String toString() => 'CircuitBreakerOpenException: $message';
}