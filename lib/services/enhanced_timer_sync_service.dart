import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/logging/app_logger.dart';

/// Enhanced timer synchronization service
/// 
/// Provides server-side time calculations and drift correction
/// to achieve flawless timer synchronization across all devices.
class EnhancedTimerSyncService {
  static final EnhancedTimerSyncService _instance = EnhancedTimerSyncService._internal();
  factory EnhancedTimerSyncService() => _instance;
  EnhancedTimerSyncService._internal();

  Duration _serverTimeOffset = Duration.zero;
  Timer? _syncTimer;
  final Map<String, DateTime> _timerStartTimes = {};
  
  /// Initialize the sync service
  Future<void> initialize() async {
    await _calculateServerTimeOffset();
    _startPeriodicSync();
  }

  /// Calculate time difference between client and server
  Future<void> _calculateServerTimeOffset() async {
    try {
      AppLogger().debug('🕐 Calculating server time offset...');
      
      // Record request start time
      final clientStartTime = DateTime.now();
      
      // Make server request to get server time
      final serverTime = await _getServerTime();
      
      // Record request end time
      final clientEndTime = DateTime.now();
      
      // Calculate network latency (round trip time)
      final networkLatency = clientEndTime.difference(clientStartTime);
      
      // Estimate server time when request was made (compensate for network latency)
      final estimatedServerTime = serverTime.subtract(Duration(milliseconds: networkLatency.inMilliseconds ~/ 2));
      
      // Calculate time offset
      _serverTimeOffset = estimatedServerTime.difference(clientStartTime);
      
      AppLogger().info('🕐 Server time offset: ${_serverTimeOffset.inMilliseconds}ms, Network latency: ${networkLatency.inMilliseconds}ms');
      
    } catch (e) {
      AppLogger().error('🕐 Failed to calculate server time offset: $e');
      _serverTimeOffset = Duration.zero;
    }
  }

  /// Get current server time
  Future<DateTime> _getServerTime() async {
    try {
      // Use a lightweight time server endpoint
      final response = await http.get(
        Uri.parse('https://worldtimeapi.org/api/timezone/UTC'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DateTime.parse(data['utc_datetime']);
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      AppLogger().warning('🕐 Failed to get server time, using system time: $e');
      return DateTime.now().toUtc();
    }
  }

  /// Start periodic synchronization checks
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    
    // Recalculate offset every 5 minutes to handle clock drift
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _calculateServerTimeOffset();
    });
  }

  /// Get synchronized current time
  DateTime getSynchronizedTime() {
    return DateTime.now().add(_serverTimeOffset);
  }

  /// Calculate precise remaining seconds for a timer
  int calculateRemainingSeconds({
    required String timerId,
    required int originalDurationSeconds,
    required DateTime timerStartTime,
    required bool isPaused,
    DateTime? pausedAt,
    int? pausedDurationSeconds,
  }) {
    final synchronizedNow = getSynchronizedTime();
    
    if (isPaused && pausedAt != null) {
      // Timer is paused - return remaining seconds at pause time
      final elapsedBeforePause = pausedAt.difference(timerStartTime).inSeconds;
      return (originalDurationSeconds - elapsedBeforePause).clamp(0, originalDurationSeconds);
    }
    
    // Calculate total elapsed time
    var totalElapsed = synchronizedNow.difference(timerStartTime).inSeconds;
    
    // Subtract any paused duration
    if (pausedDurationSeconds != null && pausedDurationSeconds > 0) {
      totalElapsed -= pausedDurationSeconds;
    }
    
    // Calculate remaining seconds
    final remainingSeconds = (originalDurationSeconds - totalElapsed).clamp(0, originalDurationSeconds);
    
    AppLogger().debug('🕐 Timer $timerId: ${remainingSeconds}s remaining (synchronized)');
    
    return remainingSeconds;
  }

  /// Check if timer has expired based on synchronized time
  bool isTimerExpired({
    required DateTime timerStartTime,
    required int durationSeconds,
    required bool isPaused,
    DateTime? pausedAt,
    int? pausedDurationSeconds,
  }) {
    final remainingSeconds = calculateRemainingSeconds(
      timerId: 'check',
      originalDurationSeconds: durationSeconds,
      timerStartTime: timerStartTime,
      isPaused: isPaused,
      pausedAt: pausedAt,
      pausedDurationSeconds: pausedDurationSeconds,
    );
    
    return remainingSeconds <= 0;
  }

  /// Get time until next second boundary (for smooth display updates)
  Duration getTimeToNextSecond() {
    final now = getSynchronizedTime();
    final nextSecond = DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second + 1);
    return nextSecond.difference(now);
  }

  /// Record when a timer starts (for local tracking)
  void recordTimerStart(String timerId, DateTime startTime) {
    _timerStartTimes[timerId] = startTime;
    AppLogger().debug('🕐 Recorded timer start: $timerId at $startTime');
  }

  /// Remove timer from local tracking
  void removeTimer(String timerId) {
    _timerStartTimes.remove(timerId);
  }

  /// Get network latency estimate
  Duration get networkLatencyEstimate => Duration(milliseconds: _serverTimeOffset.inMilliseconds.abs());

  /// Check if sync is healthy (offset is reasonable)
  bool get isSyncHealthy => _serverTimeOffset.inMilliseconds.abs() < 5000; // Less than 5 seconds offset

  /// Force resynchronization
  Future<void> forceResync() async {
    AppLogger().info('🕐 Forcing timer resynchronization...');
    await _calculateServerTimeOffset();
  }

  /// Dispose the sync service
  void dispose() {
    _syncTimer?.cancel();
    _timerStartTimes.clear();
  }
}