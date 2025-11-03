import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/logging/app_logger.dart';

/// Firebase-based Coin Service
/// Stores coin balances in Firestore to keep everything in one database
/// This prevents cross-database race conditions with Appwrite
class FirebaseCoinService {
  static final FirebaseCoinService _instance = FirebaseCoinService._internal();
  factory FirebaseCoinService() => _instance;
  FirebaseCoinService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user's coin balance from Firestore
  Future<int> getUserCoins(String userId) async {
    try {
      AppLogger().debug('💰 Firebase: Getting coins for user $userId');

      final docRef = _firestore.collection('users').doc(userId);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data();
        final coins = data?['coinBalance'] as int? ?? 500; // Default 500 coins
        AppLogger().debug('💰 Firebase: User has $coins coins');
        return coins;
      } else {
        // User doesn't exist in Firestore, create with default balance
        AppLogger().debug('💰 Firebase: User not found, creating with 500 coins');
        await docRef.set({
          'coinBalance': 500,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return 500;
      }
    } catch (e) {
      AppLogger().error('❌ Firebase: Error getting user coins: $e');
      return 500; // Return default on error
    }
  }

  /// Deduct coins using Firestore transaction (atomic operation)
  Future<bool> deductCoins(String userId, int amount) async {
    try {
      AppLogger().info('💰 Firebase: Deducting $amount coins from user $userId');

      final docRef = _firestore.collection('users').doc(userId);

      // Use Firestore transaction for atomicity
      return await _firestore.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          // Create user with default balance
          transaction.set(docRef, {
            'coinBalance': 500,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Check if they can afford it
          if (500 < amount) {
            AppLogger().warning('⚠️ Firebase: Insufficient balance (new user)');
            return false;
          }

          transaction.update(docRef, {
            'coinBalance': 500 - amount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          AppLogger().info('✅ Firebase: Deducted $amount coins from new user');
          return true;
        }

        final currentBalance = snapshot.data()?['coinBalance'] as int? ?? 0;

        if (currentBalance < amount) {
          AppLogger().warning('⚠️ Firebase: Insufficient balance. Has $currentBalance, needs $amount');
          return false;
        }

        final newBalance = currentBalance - amount;
        transaction.update(docRef, {
          'coinBalance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        AppLogger().info('✅ Firebase: Deducted $amount coins. New balance: $newBalance');
        return true;
      });
    } catch (e) {
      AppLogger().error('❌ Firebase: Error deducting coins: $e');
      return false;
    }
  }

  /// Add coins using Firestore transaction (atomic operation)
  Future<bool> addCoins(String userId, int amount) async {
    try {
      AppLogger().info('💰 Firebase: Adding $amount coins to user $userId');

      final docRef = _firestore.collection('users').doc(userId);

      // Use Firestore transaction for atomicity
      return await _firestore.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          transaction.set(docRef, {
            'coinBalance': 500 + amount,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          AppLogger().info('✅ Firebase: Created user with ${500 + amount} coins');
          return true;
        }

        final currentBalance = snapshot.data()?['coinBalance'] as int? ?? 0;
        final newBalance = currentBalance + amount;

        transaction.update(docRef, {
          'coinBalance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        AppLogger().info('✅ Firebase: Added $amount coins. New balance: $newBalance');
        return true;
      });
    } catch (e) {
      AppLogger().error('❌ Firebase: Error adding coins: $e');
      return false;
    }
  }

  /// Listen to real-time coin balance updates
  Stream<int> watchCoinBalance(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            return 500; // Default balance
          }
          final data = snapshot.data();
          return data?['coinBalance'] as int? ?? 500;
        });
  }
}
