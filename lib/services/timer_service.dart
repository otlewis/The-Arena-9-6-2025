import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/timer_state.dart';
import '../config/timer_presets.dart';
import '../core/logging/app_logger.dart';
import 'firebase_arena_timer_service.dart';

class TimerService {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal() {
    initializeFirebase();
  }

  late final FirebaseFirestore _firestore;
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  final Map<String, Timer> _localTimers = {};

  static const String _timersCollection = 'room_timers';
  static const String _eventsCollection = 'timer_events';

  Future<void> initializeFirebase() async {
    try {
      // Initialize Firebase using the existing pattern
      _firestore = FirebaseFirestore.instance;
      
      // Ensure Firebase Auth is initialized by using existing service
      FirebaseArenaTimerService();
      // The arena service will handle auth initialization in its constructor
      
      AppLogger().info('🕐 TimerService: Firebase initialized successfully');
    } catch (e) {
      AppLogger().error('🕐 TimerService: Firebase initialization failed: $e');
      rethrow;
    }
  }

  // Create a new timer
  Future<String> createTimer({
    required String roomId,
    required RoomType roomType,
    required TimerType timerType,
    required int durationSeconds,
    required String createdBy,
    String? currentSpeaker,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Check if room can have multiple concurrent timers
      final activeTimers = await getActiveTimersForRoom(roomId);
      final maxConcurrent = TimerPresets.getMaxConcurrentTimers(roomType);
      
      if (activeTimers.length >= maxConcurrent) {
        throw Exception('Maximum concurrent timers ($maxConcurrent) reached for room');
      }

      final timerRef = _firestore.collection(_timersCollection).doc();
      final timerId = timerRef.id;

      final timerState = TimerState.initial(
        roomId: roomId,
        roomType: roomType,
        timerType: timerType,
        durationSeconds: durationSeconds,
        createdBy: createdBy,
        description: description,
        currentSpeaker: currentSpeaker,
      ).copyWith(
        id: timerId,
        createdAt: DateTime.now(),
        metadata: metadata,
      );

      await timerRef.set(timerState.toJson());
      
      // Log creation event
      await _logTimerEvent(
        timerId: timerId,
        action: 'created',
        userId: createdBy,
        details: 'Timer created for ${timerType.displayName}',
      );

      return timerId;
    } catch (e) {
      debugPrint('Error creating timer: $e');
      rethrow;
    }
  }

  // Start a timer
  Future<void> startTimer(String timerId, String userId) async {
    try {
      final timerRef = _firestore.collection(_timersCollection).doc(timerId);
      final timerDoc = await timerRef.get();
      
      if (!timerDoc.exists) {
        throw Exception('Timer not found');
      }

      final currentState = TimerState.fromJson(timerDoc.data()!);
      
      if (currentState.status == TimerStatus.running) {
        throw Exception('Timer is already running');
      }

      // Calculate remaining time if resuming from pause
      int remainingSeconds = currentState.remainingSeconds;
      if (currentState.status == TimerStatus.paused && currentState.pausedAt != null) {
        // Keep the remaining time from when it was paused
        remainingSeconds = currentState.remainingSeconds;
      }

      await timerRef.update({
        'status': TimerStatus.running.name,
        'startTime': FieldValue.serverTimestamp(),
        'remainingSeconds': remainingSeconds,
        'pausedAt': null,
        'hasExpired': false,
      });

      await _logTimerEvent(
        timerId: timerId,
        action: 'started',
        userId: userId,
        details: 'Timer started with ${remainingSeconds}s remaining',
      );

      // Start local timer for expiry detection
      _startLocalExpiryTimer(timerId, remainingSeconds);

    } catch (e) {
      debugPrint('Error starting timer: $e');
      rethrow;
    }
  }

  // Pause a timer
  Future<void> pauseTimer(String timerId, String userId) async {
    try {
      final timerRef = _firestore.collection(_timersCollection).doc(timerId);
      final timerDoc = await timerRef.get();
      
      if (!timerDoc.exists) {
        throw Exception('Timer not found');
      }

      final currentState = TimerState.fromJson(timerDoc.data()!);
      
      if (currentState.status != TimerStatus.running) {
        throw Exception('Timer is not running');
      }

      // Check if pausing is allowed for this timer type
      if (!TimerPresets.canPause(currentState.roomType, currentState.timerType)) {
        throw Exception('Pausing is not allowed for ${currentState.timerType.displayName}');
      }

      // Calculate remaining time
      final elapsed = DateTime.now().difference(currentState.startTime!).inSeconds;
      final remainingSeconds = max(0, currentState.remainingSeconds - elapsed);

      await timerRef.update({
        'status': TimerStatus.paused.name,
        'pausedAt': FieldValue.serverTimestamp(),
        'remainingSeconds': remainingSeconds,
      });

      await _logTimerEvent(
        timerId: timerId,
        action: 'paused',
        userId: userId,
        details: 'Timer paused with ${remainingSeconds}s remaining',
      );

      // Cancel local timer
      _cancelLocalTimer(timerId);

    } catch (e) {
      debugPrint('Error pausing timer: $e');
      rethrow;
    }
  }

  // Stop a timer
  Future<void> stopTimer(String timerId, String userId) async {
    try {
      final timerRef = _firestore.collection(_timersCollection).doc(timerId);
      
      await timerRef.update({
        'status': TimerStatus.stopped.name,
        'pausedAt': null,
      });

      await _logTimerEvent(
        timerId: timerId,
        action: 'stopped',
        userId: userId,
        details: 'Timer stopped by user',
      );

      _cancelLocalTimer(timerId);

    } catch (e) {
      debugPrint('Error stopping timer: $e');
      rethrow;
    }
  }

  // Reset a timer
  Future<void> resetTimer(String timerId, String userId) async {
    try {
      final timerRef = _firestore.collection(_timersCollection).doc(timerId);
      final timerDoc = await timerRef.get();
      
      if (!timerDoc.exists) {
        throw Exception('Timer not found');
      }

      final currentState = TimerState.fromJson(timerDoc.data()!);

      await timerRef.update({
        'status': TimerStatus.stopped.name,
        'remainingSeconds': currentState.durationSeconds,
        'startTime': null,
        'pausedAt': null,
        'hasExpired': false,
      });

      await _logTimerEvent(
        timerId: timerId,
        action: 'reset',
        userId: userId,
        details: 'Timer reset to ${currentState.durationSeconds}s',
      );

      _cancelLocalTimer(timerId);

    } catch (e) {
      debugPrint('Error resetting timer: $e');
      rethrow;
    }
  }

  // Add time to a timer
  Future<void> addTime(String timerId, int additionalSeconds, String userId) async {
    try {
      final timerRef = _firestore.collection(_timersCollection).doc(timerId);
      final timerDoc = await timerRef.get();
      
      if (!timerDoc.exists) {
        throw Exception('Timer not found');
      }

      final currentState = TimerState.fromJson(timerDoc.data()!);

      // Check if adding time is allowed for this timer type
      if (!TimerPresets.canAddTime(currentState.roomType, currentState.timerType)) {
        throw Exception('Adding time is not allowed for ${currentState.timerType.displayName}');
      }

      int newRemainingSeconds;
      
      if (currentState.status == TimerStatus.running && currentState.startTime != null) {
        // Calculate current remaining time and add to it
        final elapsed = DateTime.now().difference(currentState.startTime!).inSeconds;
        final currentRemaining = max(0, currentState.remainingSeconds - elapsed);
        newRemainingSeconds = currentRemaining + additionalSeconds;
      } else {
        // Timer is stopped or paused, just add to remaining time
        newRemainingSeconds = currentState.remainingSeconds + additionalSeconds;
      }

      await timerRef.update({
        'remainingSeconds': newRemainingSeconds,
        'durationSeconds': currentState.durationSeconds + additionalSeconds,
        'hasExpired': false,
      });

      await _logTimerEvent(
        timerId: timerId,
        action: 'time_added',
        userId: userId,
        details: 'Added ${additionalSeconds}s (new total: ${newRemainingSeconds}s)',
      );

      // Restart local timer with new duration if running
      if (currentState.status == TimerStatus.running) {
        _startLocalExpiryTimer(timerId, newRemainingSeconds);
      }

    } catch (e) {
      debugPrint('Error adding time: $e');
      rethrow;
    }
  }

  // Complete a timer (when it expires)
  Future<void> _completeTimer(String timerId) async {
    try {
      await _firestore.collection(_timersCollection).doc(timerId).update({
        'status': TimerStatus.completed.name,
        'remainingSeconds': 0,
        'hasExpired': true,
      });

      await _logTimerEvent(
        timerId: timerId,
        action: 'completed',
        userId: 'system',
        details: 'Timer expired and completed',
      );

    } catch (e) {
      debugPrint('Error completing timer: $e');
    }
  }

  // Get a timer stream
  Stream<TimerState?> getTimerStream(String timerId) {
    return _firestore
        .collection(_timersCollection)
        .doc(timerId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return TimerState.fromJson(snapshot.data()!);
        });
  }

  // Get all timers for a room
  Stream<List<TimerState>> getRoomTimersStream(String roomId) {
    return _firestore
        .collection(_timersCollection)
        .where('roomId', isEqualTo: roomId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TimerState.fromJson(doc.data()))
              .toList();
        });
  }

  // Get active timers for a room
  Future<List<TimerState>> getActiveTimersForRoom(String roomId) async {
    final snapshot = await _firestore
        .collection(_timersCollection)
        .where('roomId', isEqualTo: roomId)
        .where('status', whereIn: [TimerStatus.running.name, TimerStatus.paused.name])
        .get();

    return snapshot.docs
        .map((doc) => TimerState.fromJson(doc.data()))
        .toList();
  }

  // Delete a timer
  Future<void> deleteTimer(String timerId, String userId) async {
    try {
      await _firestore.collection(_timersCollection).doc(timerId).delete();
      
      await _logTimerEvent(
        timerId: timerId,
        action: 'deleted',
        userId: userId,
        details: 'Timer deleted',
      );

      _cancelLocalTimer(timerId);
      _cancelSubscription(timerId);

    } catch (e) {
      debugPrint('Error deleting timer: $e');
      rethrow;
    }
  }

  // Get timer events/history
  Stream<List<TimerEvent>> getTimerEventsStream(String timerId) {
    return _firestore
        .collection(_eventsCollection)
        .where('timerId', isEqualTo: timerId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TimerEvent.fromJson(doc.data()))
              .toList();
        });
  }

  // Local timer management for expiry detection
  void _startLocalExpiryTimer(String timerId, int durationSeconds) {
    _cancelLocalTimer(timerId);
    
    _localTimers[timerId] = Timer(Duration(seconds: durationSeconds), () {
      _completeTimer(timerId);
    });
  }

  void _cancelLocalTimer(String timerId) {
    _localTimers[timerId]?.cancel();
    _localTimers.remove(timerId);
  }

  void _cancelSubscription(String timerId) {
    _activeSubscriptions[timerId]?.cancel();
    _activeSubscriptions.remove(timerId);
  }

  // Log timer events
  Future<void> _logTimerEvent({
    required String timerId,
    required String action,
    required String userId,
    String? details,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final event = TimerEvent(
        timerId: timerId,
        action: action,
        timestamp: DateTime.now(),
        userId: userId,
        details: details,
        metadata: metadata,
      );

      await _firestore.collection(_eventsCollection).add(event.toJson());
    } catch (e) {
      debugPrint('Error logging timer event: $e');
    }
  }

  // Calculate precise remaining time for a running timer
  int calculateRemainingTime(TimerState timer) {
    if (timer.status != TimerStatus.running || timer.startTime == null) {
      return timer.remainingSeconds;
    }

    final elapsed = DateTime.now().difference(timer.startTime!).inSeconds;
    return max(0, timer.remainingSeconds - elapsed);
  }

  // Check if user can control timers (moderator check)
  bool canControlTimer(TimerState timer, String userId, bool isModerator) {
    // Creator can always control their timer
    if (timer.createdBy == userId) return true;
    
    // Check room-specific moderator requirements
    final roomPreset = TimerPresets.getPresetForRoom(timer.roomType);
    if (roomPreset.moderatorOnly) {
      return isModerator;
    }

    return true;
  }

  // Cleanup method
  void dispose() {
    for (final subscription in _activeSubscriptions.values) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();

    for (final timer in _localTimers.values) {
      timer.cancel();
    }
    _localTimers.clear();
  }
}