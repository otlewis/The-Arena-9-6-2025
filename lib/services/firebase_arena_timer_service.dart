import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/logging/app_logger.dart';

class FirebaseArenaTimerService {
  static final FirebaseArenaTimerService _instance = FirebaseArenaTimerService._internal();
  
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;

  factory FirebaseArenaTimerService() {
    return _instance;
  }

  FirebaseArenaTimerService._internal() {
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
    _initializeAuth();
  }

  /// Initialize anonymous authentication if needed
  Future<void> _initializeAuth() async {
    try {
      AppLogger().debug('🔐 Firebase Arena Timer: Checking auth status...');
      if (_auth.currentUser == null) {
        AppLogger().debug('🔐 Firebase Arena Timer: No user found, signing in anonymously...');
        final userCredential = await _auth.signInAnonymously();
        AppLogger().info('🔐 Firebase Arena Timer: Anonymous sign in successful - UID: ${userCredential.user?.uid}');
      } else {
        AppLogger().debug('🔐 Firebase Arena Timer: User already authenticated - UID: ${_auth.currentUser?.uid}');
      }
    } catch (e) {
      AppLogger().error('Firebase Arena Timer Auth Error: $e');
      rethrow;
    }
  }

  // Collection reference for arena timers
  CollectionReference get _arenaTimers => _firestore.collection('arena_timers');

  /// Initialize timer for a new arena room
  Future<void> initializeArenaTimer(String roomId) async {
    try {
      // Ensure auth is complete before accessing Firestore
      await _initializeAuth();
      
      AppLogger().debug('🔥 Firebase: Initializing timer for room: $roomId');
      
      final timerData = {
        'roomId': roomId,
        'currentPhase': 'preDebate',
        'remainingSeconds': 0,
        'isTimerRunning': false,
        'isPaused': false,
        'phaseStartedAt': FieldValue.serverTimestamp(),
        'lastUpdate': FieldValue.serverTimestamp(),
        'currentSpeaker': null,
      };
      
      await _arenaTimers.doc(roomId).set(timerData);
      AppLogger().info('🔥 Firebase timer initialized successfully for room: $roomId');
    } catch (e) {
      AppLogger().error('Error initializing Firebase timer for room $roomId: $e');
      AppLogger().error('Firebase error details: ${e.toString()}');
      rethrow;
    }
  }

  /// Get real-time timer stream for an arena
  Stream<Map<String, dynamic>> getArenaTimerStream(String roomId) {
    AppLogger().debug('🔥 Firebase: Setting up timer stream for room: $roomId');
    
    return _arenaTimers.doc(roomId).snapshots().asyncMap((snapshot) async {
      AppLogger().debug('🔥 Firebase: Timer snapshot received for $roomId - exists: ${snapshot.exists}');
      
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.data() as Map<String, dynamic>);
        final isRunning = data['isTimerRunning'] ?? false;
        final isPaused = data['isPaused'] ?? false;
        final phase = data['currentPhase'] ?? 'preDebate';
        
        // If timer is running and we have an end time, calculate remaining seconds
        if (isRunning && !isPaused && data['endTimeMillis'] != null) {
          // Get current server time
          final serverTimeDoc = await _firestore.doc('server_time/current').get();
          final serverTime = serverTimeDoc.exists 
              ? (serverTimeDoc.data()?['timestamp'] as Timestamp?)?.millisecondsSinceEpoch 
              : DateTime.now().millisecondsSinceEpoch;
          
          final endTimeMillis = data['endTimeMillis'] as int;
          final remainingMillis = endTimeMillis - (serverTime ?? DateTime.now().millisecondsSinceEpoch);
          final remainingSeconds = (remainingMillis / 1000).round().clamp(0, 999999);
          
          data['remainingSeconds'] = remainingSeconds;
          AppLogger().debug('🔥 Timer sync - End: $endTimeMillis, Now: $serverTime, Remaining: ${remainingSeconds}s');
        } else {
          // Use stored remaining seconds for paused timers
          final remainingSeconds = data['remainingSeconds'] ?? 0;
          data['remainingSeconds'] = remainingSeconds;
        }
        
        AppLogger().debug('🔥 Firebase timer update - Room: $roomId, Time: ${data['remainingSeconds']}s, Running: $isRunning, Paused: $isPaused, Phase: $phase');
        return data;
      } else {
        AppLogger().warning('🔥 Firebase: Timer document does not exist for room: $roomId, returning defaults');
        // Return default timer state if document doesn't exist
        final defaultData = {
          'roomId': roomId,
          'currentPhase': 'preDebate',
          'remainingSeconds': 0,
          'isTimerRunning': false,
          'isPaused': false,
          'currentSpeaker': null,
        };
        return defaultData;
      }
    }).handleError((error) {
      AppLogger().error('🔥 Firebase timer stream error for room $roomId: $error');
      // Return default data on error
      return {
        'roomId': roomId,
        'currentPhase': 'preDebate',
        'remainingSeconds': 0,
        'isTimerRunning': false,
        'isPaused': false,
        'currentSpeaker': null,
      };
    });
  }

  /// Update timer state
  Future<void> updateTimer({
    required String roomId,
    int? remainingSeconds,
    bool? isTimerRunning,
    bool? isPaused,
    String? currentPhase,
    String? currentSpeaker,
  }) async {
    try {
      final updates = <String, dynamic>{
        'lastUpdate': FieldValue.serverTimestamp(),
      };

      if (remainingSeconds != null) updates['remainingSeconds'] = remainingSeconds;
      if (isTimerRunning != null) updates['isTimerRunning'] = isTimerRunning;
      if (isPaused != null) updates['isPaused'] = isPaused;
      if (currentPhase != null) updates['currentPhase'] = currentPhase;
      if (currentSpeaker != null) updates['currentSpeaker'] = currentSpeaker;

      await _arenaTimers.doc(roomId).update(updates);
      
      AppLogger().debug('🔥 Timer updated - Room: $roomId, Updates: $updates');
    } catch (e) {
      AppLogger().error('Error updating Firebase timer: $e');
      rethrow;
    }
  }

  /// Start or resume timer
  Future<void> startTimer(String roomId, {int? initialSeconds}) async {
    try {
      // Get current document to calculate proper end time
      final doc = await _arenaTimers.doc(roomId).get();
      final currentData = doc.exists ? doc.data() as Map<String, dynamic> : {};
      
      final updates = <String, dynamic>{
        'isTimerRunning': true,
        'isPaused': false,
        'startedAt': FieldValue.serverTimestamp(),
        'lastUpdate': FieldValue.serverTimestamp(),
      };
      
      if (initialSeconds != null) {
        updates['remainingSeconds'] = initialSeconds;
        // Calculate end time based on server timestamp
        // We'll store a server timestamp and duration to calculate end time
        updates['durationSeconds'] = initialSeconds;
        updates['startTimeMillis'] = FieldValue.serverTimestamp();
      }

      await _arenaTimers.doc(roomId).update(updates);
      
      // Immediately after starting, set the proper end time
      if (initialSeconds != null) {
        final updatedDoc = await _arenaTimers.doc(roomId).get();
        final data = updatedDoc.data() as Map<String, dynamic>?;
        final startTime = (data?['startTimeMillis'] as Timestamp?)?.millisecondsSinceEpoch;
        if (startTime != null) {
          await _arenaTimers.doc(roomId).update({
            'endTimeMillis': startTime + (initialSeconds * 1000),
          });
        }
      }
      
      AppLogger().info('🔥 Timer started for room: $roomId with ${initialSeconds}s');
    } catch (e) {
      AppLogger().error('Error starting timer: $e');
      rethrow;
    }
  }

  /// Pause timer
  Future<void> pauseTimer(String roomId) async {
    try {
      await _arenaTimers.doc(roomId).update({
        'isTimerRunning': false,
        'isPaused': true,
        'lastUpdate': FieldValue.serverTimestamp(),
      });
      AppLogger().info('🔥 Timer paused for room: $roomId');
    } catch (e) {
      AppLogger().error('Error pausing timer: $e');
      rethrow;
    }
  }

  /// Stop timer completely
  Future<void> stopTimer(String roomId) async {
    try {
      await _arenaTimers.doc(roomId).update({
        'isTimerRunning': false,
        'isPaused': false,
        'remainingSeconds': 0,
        'lastUpdate': FieldValue.serverTimestamp(),
      });
      AppLogger().info('🔥 Timer stopped for room: $roomId');
    } catch (e) {
      AppLogger().error('Error stopping timer: $e');
      rethrow;
    }
  }

  /// Add or subtract time
  Future<void> adjustTime(String roomId, int secondsToAdd) async {
    try {
      final doc = await _arenaTimers.doc(roomId).get();
      if (doc.exists) {
        final currentTime = (doc.data() as Map<String, dynamic>)['remainingSeconds'] ?? 0;
        final newTime = (currentTime + secondsToAdd).clamp(0, 3600); // Max 1 hour
        
        await _arenaTimers.doc(roomId).update({
          'remainingSeconds': newTime,
          'lastUpdate': FieldValue.serverTimestamp(),
        });
        
        AppLogger().info('🔥 Time adjusted by ${secondsToAdd}s for room: $roomId (new time: ${newTime}s)');
      }
    } catch (e) {
      AppLogger().error('Error adjusting time: $e');
      rethrow;
    }
  }

  /// Set timer to specific value
  Future<void> setTimer(String roomId, int seconds) async {
    try {
      await _arenaTimers.doc(roomId).update({
        'remainingSeconds': seconds,
        'isTimerRunning': false,
        'isPaused': false,
        'lastUpdate': FieldValue.serverTimestamp(),
      });
      AppLogger().info('🔥 Timer set to ${seconds}s for room: $roomId');
    } catch (e) {
      AppLogger().error('Error setting timer: $e');
      rethrow;
    }
  }

  /// Move to next phase
  Future<void> nextPhase(String roomId, String newPhase, int phaseDurationSeconds) async {
    try {
      await _arenaTimers.doc(roomId).update({
        'currentPhase': newPhase,
        'remainingSeconds': phaseDurationSeconds,
        'isTimerRunning': true,
        'isPaused': false,
        'phaseStartedAt': FieldValue.serverTimestamp(),
        'lastUpdate': FieldValue.serverTimestamp(),
      });
      AppLogger().info('🔥 Phase changed to $newPhase for room: $roomId');
    } catch (e) {
      AppLogger().error('Error changing phase: $e');
      rethrow;
    }
  }

  /// Clean up timer when arena ends
  Future<void> cleanupTimer(String roomId) async {
    try {
      await _arenaTimers.doc(roomId).delete();
      AppLogger().info('🔥 Timer cleaned up for room: $roomId');
    } catch (e) {
      AppLogger().error('Error cleaning up timer: $e');
      // Don't rethrow - cleanup errors shouldn't break flow
    }
  }

  /// Check if timer exists (useful for avoiding duplicates)
  Future<bool> timerExists(String roomId) async {
    try {
      final doc = await _arenaTimers.doc(roomId).get();
      return doc.exists;
    } catch (e) {
      AppLogger().error('Error checking timer existence: $e');
      return false;
    }
  }
}