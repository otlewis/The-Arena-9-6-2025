import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../core/logging/app_logger.dart';

/// Service for accurate timer synchronization using Firebase server time offset
class FirebaseTimerSyncService {
  static final FirebaseTimerSyncService _instance = FirebaseTimerSyncService._internal();
  
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache server time offset
  int _serverTimeOffset = 0;
  DateTime _lastOffsetUpdate = DateTime.now();
  
  factory FirebaseTimerSyncService() => _instance;
  
  FirebaseTimerSyncService._internal();
  
  /// Get the current server time offset
  Future<int> getServerTimeOffset() async {
    // Update offset every 5 minutes
    if (DateTime.now().difference(_lastOffsetUpdate).inMinutes > 5) {
      await _updateServerTimeOffset();
    }
    return _serverTimeOffset;
  }
  
  /// Update the server time offset from Firebase
  Future<void> _updateServerTimeOffset() async {
    try {
      final offsetRef = _database.ref('.info/serverTimeOffset');
      final snapshot = await offsetRef.once();
      _serverTimeOffset = (snapshot.snapshot.value as num?)?.toInt() ?? 0;
      _lastOffsetUpdate = DateTime.now();
      AppLogger().debug('🔄 Updated server time offset: ${_serverTimeOffset}ms');
    } catch (e) {
      AppLogger().error('Error updating server time offset: $e');
    }
  }
  
  /// Get estimated server time
  Future<int> getServerTimeMillis() async {
    final offset = await getServerTimeOffset();
    return DateTime.now().millisecondsSinceEpoch + offset;
  }
  
  /// Set timer with server-synced end time
  Future<void> setTimerEndTime(String roomId, int durationSeconds) async {
    try {
      final serverTime = await getServerTimeMillis();
      final endTime = serverTime + (durationSeconds * 1000);
      
      await _firestore.collection('arena_timers').doc(roomId).update({
        'endTimeMillis': endTime,
        'startTimeMillis': serverTime,
        'durationSeconds': durationSeconds,
        'isTimerRunning': true,
        'isPaused': false,
        'lastUpdate': FieldValue.serverTimestamp(),
      });
      
      AppLogger().info('⏱️ Timer set - Room: $roomId, Duration: ${durationSeconds}s, End: $endTime');
    } catch (e) {
      AppLogger().error('Error setting timer end time: $e');
      rethrow;
    }
  }
  
  /// Calculate remaining seconds based on server time
  Future<int> getRemainingSeconds(String roomId) async {
    try {
      final doc = await _firestore.collection('arena_timers').doc(roomId).get();
      if (!doc.exists) return 0;
      
      final data = doc.data()!;
      final endTimeMillis = data['endTimeMillis'] as int?;
      final isRunning = data['isTimerRunning'] as bool? ?? false;
      final isPaused = data['isPaused'] as bool? ?? false;
      
      if (!isRunning || isPaused || endTimeMillis == null) {
        return data['remainingSeconds'] as int? ?? 0;
      }
      
      final serverTime = await getServerTimeMillis();
      final remainingMillis = endTimeMillis - serverTime;
      return (remainingMillis / 1000).round().clamp(0, 999999);
    } catch (e) {
      AppLogger().error('Error calculating remaining seconds: $e');
      return 0;
    }
  }
  
  /// Pause timer and store remaining time
  Future<void> pauseTimer(String roomId) async {
    try {
      final remainingSeconds = await getRemainingSeconds(roomId);
      
      await _firestore.collection('arena_timers').doc(roomId).update({
        'isTimerRunning': false,
        'isPaused': true,
        'remainingSeconds': remainingSeconds,
        'pausedAt': FieldValue.serverTimestamp(),
        'lastUpdate': FieldValue.serverTimestamp(),
      });
      
      AppLogger().info('⏸️ Timer paused - Room: $roomId, Remaining: ${remainingSeconds}s');
    } catch (e) {
      AppLogger().error('Error pausing timer: $e');
      rethrow;
    }
  }
  
  /// Resume timer from paused state
  Future<void> resumeTimer(String roomId) async {
    try {
      final doc = await _firestore.collection('arena_timers').doc(roomId).get();
      if (!doc.exists) return;
      
      final remainingSeconds = doc.data()!['remainingSeconds'] as int? ?? 0;
      await setTimerEndTime(roomId, remainingSeconds);
      
      AppLogger().info('▶️ Timer resumed - Room: $roomId, Duration: ${remainingSeconds}s');
    } catch (e) {
      AppLogger().error('Error resuming timer: $e');
      rethrow;
    }
  }
}