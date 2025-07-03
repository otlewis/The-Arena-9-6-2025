import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/logging/app_logger.dart';

class FirebaseTestService {
  static final FirebaseTestService _instance = FirebaseTestService._internal();
  
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;

  factory FirebaseTestService() {
    return _instance;
  }

  FirebaseTestService._internal() {
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
  }

  /// Test Firebase connection and Firestore access
  Future<void> testFirebaseConnection() async {
    try {
      AppLogger().info('🧪 Testing Firebase connection...');
      
      // Test 1: Check Firebase Auth
      AppLogger().debug('🧪 Test 1: Firebase Auth');
      if (_auth.currentUser == null) {
        AppLogger().debug('🧪 No user found, signing in anonymously...');
        final userCredential = await _auth.signInAnonymously();
        AppLogger().info('🧪 Anonymous auth successful - UID: ${userCredential.user?.uid}');
      } else {
        AppLogger().info('🧪 User already authenticated - UID: ${_auth.currentUser?.uid}');
      }
      
      // Test 2: Test Firestore Write
      AppLogger().debug('🧪 Test 2: Firestore Write');
      final testDoc = _firestore.collection('test_collection').doc('test_doc');
      await testDoc.set({
        'test': true,
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Firebase connection test',
      });
      AppLogger().info('🧪 Firestore write successful');
      
      // Test 3: Test Firestore Read
      AppLogger().debug('🧪 Test 3: Firestore Read');
      final snapshot = await testDoc.get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        AppLogger().info('🧪 Firestore read successful - data: $data');
      } else {
        AppLogger().warning('🧪 Firestore read failed - document does not exist');
      }
      
      // Test 4: Test Arena Timer Collection
      AppLogger().debug('🧪 Test 4: Arena Timer Collection');
      final timerDoc = _firestore.collection('arena_timers').doc('test_room_123');
      await timerDoc.set({
        'roomId': 'test_room_123',
        'currentPhase': 'preDebate',
        'remainingSeconds': 300,
        'isTimerRunning': false,
        'isPaused': false,
        'lastUpdate': FieldValue.serverTimestamp(),
      });
      AppLogger().info('🧪 Arena timer collection test successful');
      
      // Test 5: Clean up test documents
      AppLogger().debug('🧪 Test 5: Cleanup');
      await testDoc.delete();
      await timerDoc.delete();
      AppLogger().info('🧪 Test cleanup completed');
      
      AppLogger().info('🧪 ✅ All Firebase tests passed successfully!');
      
    } catch (e) {
      AppLogger().error('🧪 ❌ Firebase test failed: $e');
      AppLogger().error('🧪 Error details: ${e.toString()}');
      rethrow;
    }
  }

  /// Quick test just for timer collection
  Future<void> testArenaTimerCollection() async {
    try {
      AppLogger().info('🧪 Testing arena timer collection specifically...');
      
      // Ensure auth
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
      
      final testRoomId = 'test_timer_${DateTime.now().millisecondsSinceEpoch}';
      final timerDoc = _firestore.collection('arena_timers').doc(testRoomId);
      
      // Write test timer
      await timerDoc.set({
        'roomId': testRoomId,
        'currentPhase': 'preDebate',
        'remainingSeconds': 120,
        'isTimerRunning': true,
        'isPaused': false,
        'lastUpdate': FieldValue.serverTimestamp(),
      });
      
      // Read it back
      final snapshot = await timerDoc.get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        AppLogger().info('🧪 ✅ Arena timer test successful - data: $data');
      }
      
      // Clean up
      await timerDoc.delete();
      
    } catch (e) {
      AppLogger().error('🧪 ❌ Arena timer test failed: $e');
      rethrow;
    }
  }
}