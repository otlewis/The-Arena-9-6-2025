import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/gift_transaction.dart';
import '../models/gift.dart';
import '../core/logging/app_logger.dart';

class FirebaseGiftService {
  static final FirebaseGiftService _instance = FirebaseGiftService._internal();
  
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;

  factory FirebaseGiftService() {
    return _instance;
  }

  FirebaseGiftService._internal() {
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
    _initializeAuth();
    _configureFirestore();
    _debugFirebaseConnection();
  }

  /// Initialize anonymous authentication
  Future<void> _initializeAuth() async {
    try {
      // Check if user is already signed in
      if (_auth.currentUser == null) {
        AppLogger().debug('🔐 DEBUG: No user signed in, signing in anonymously...');
        final userCredential = await _auth.signInAnonymously();
        AppLogger().debug('🔐 DEBUG: Anonymous sign in successful: ${userCredential.user?.uid}');
      } else {
        AppLogger().debug('🔐 DEBUG: User already signed in: ${_auth.currentUser?.uid}');
      }
    } catch (e) {
      AppLogger().error('DEBUG: Error with anonymous authentication: $e');
    }
  }

  /// Configure Firestore settings
  void _configureFirestore() {
    try {
      // Force enable network and clear cache
      _firestore.enableNetwork();
      _firestore.clearPersistence();
      AppLogger().debug('🔥 DEBUG: Firestore configured and cache cleared');
    } catch (e) {
      AppLogger().debug('🔥 DEBUG: Error configuring Firestore: $e');
    }
  }

  /// Debug Firebase connection details
  void _debugFirebaseConnection() {
    try {
      AppLogger().debug('🔥 DEBUG: Firebase app name: ${Firebase.app().name}');
      AppLogger().debug('🔥 DEBUG: Firebase project ID: ${Firebase.app().options.projectId}');
      AppLogger().debug('🔥 DEBUG: Firestore app: ${_firestore.app.name}');
      AppLogger().debug('🔥 DEBUG: Firestore settings: ${_firestore.settings}');
    } catch (e) {
      AppLogger().debug('🔥 DEBUG: Error getting Firebase info: $e');
    }
  }

  // Collection references
  CollectionReference get _giftTransactions => _firestore.collection('gift_transactions');
  CollectionReference get _userCoins => _firestore.collection('user_coins');

  /// Initialize or get user's coin balance
  Future<int> getUserCoinBalance(String userId) async {
    AppLogger().debug('🎁 DEBUG: Firebase getUserCoinBalance called with userId: $userId');
    
    try {
      AppLogger().debug('🎁 DEBUG: Attempting to get document from _userCoins...');
      final doc = await _userCoins.doc(userId).get();
      AppLogger().debug('🎁 DEBUG: Document retrieved. Exists: ${doc.exists}');
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final balance = data['balance'] ?? 100;
        AppLogger().debug('🎁 DEBUG: Existing user found. Balance: $balance');
        return balance;
      } else {
        AppLogger().debug('🎁 DEBUG: New user detected. Creating initial balance...');
        // Create initial balance for new user
        await _userCoins.doc(userId).set({
          'balance': 100,
          'totalGiftsSent': 0,
          'totalGiftsReceived': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        AppLogger().debug('🎁 DEBUG: Initial balance created successfully. Returning 100');
        return 100;
      }
    } catch (e) {
      AppLogger().error('Firebase Error getting user coin balance: $e');
      AppLogger().error('Firebase Error details: ${e.toString()}');
      return 100; // Return 100 instead of 0 for new users
    }
  }

  /// Update user's coin balance and gift statistics
  Future<bool> updateUserCoinBalance(
    String userId, 
    int newBalance, 
    {int? giftsSentIncrement, int? giftsReceivedIncrement}
  ) async {
    try {
      final updateData = <String, dynamic>{
        'balance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (giftsSentIncrement != null) {
        updateData['totalGiftsSent'] = FieldValue.increment(giftsSentIncrement);
      }

      if (giftsReceivedIncrement != null) {
        updateData['totalGiftsReceived'] = FieldValue.increment(giftsReceivedIncrement);
      }

      await _userCoins.doc(userId).update(updateData);
      return true;
    } catch (e) {
      AppLogger().error('Error updating user coin balance: $e');
      return false;
    }
  }

  /// Send a gift from one user to another
  Future<bool> sendGift({
    required String giftId,
    required String senderId,
    required String recipientId,
    required String roomId,
    required int cost,
    String? message,
  }) async {
    try {
      AppLogger().debug('🎁 Firebase: Starting gift send process...');
      AppLogger().debug('🎁 Firebase: Gift ID: $giftId');
      AppLogger().debug('🎁 Firebase: Sender: $senderId');
      AppLogger().debug('🎁 Firebase: Recipient: $recipientId');
      AppLogger().debug('🎁 Firebase: Cost: $cost');

      // Check sender's coin balance
      final senderBalance = await getUserCoinBalance(senderId);
      if (senderBalance < cost) {
        throw Exception('Insufficient coin balance. Balance: $senderBalance, Cost: $cost');
      }

      AppLogger().debug('🎁 Firebase: Sender has sufficient balance: $senderBalance');

      // Use Firestore transaction to ensure consistency
      await _firestore.runTransaction((transaction) async {
        // Create gift transaction document
        final transactionRef = _giftTransactions.doc();
        transaction.set(transactionRef, {
          'giftId': giftId,
          'senderId': senderId,
          'recipientId': recipientId,
          'roomId': roomId,
          'cost': cost,
          'message': message,
          'sentAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update sender's coin balance
        final senderRef = _userCoins.doc(senderId);
        transaction.set(senderRef, {
          'balance': senderBalance - cost,
          'totalGiftsSent': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update recipient's coin stats and reputation
        final recipientRef = _userCoins.doc(recipientId);
        
        // Calculate reputation bonus based on gift cost
        int reputationBonus = cost >= 50 ? 10 : (cost >= 15 ? 5 : (cost >= 5 ? 3 : 1));
        
        transaction.set(recipientRef, {
          'totalGiftsReceived': FieldValue.increment(1),
          'totalReputationFromGifts': FieldValue.increment(reputationBonus),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      AppLogger().info('Firebase: Gift sent successfully! $giftId from $senderId to $recipientId (cost: $cost coins)');
      return true;
    } catch (e) {
      AppLogger().error('Firebase: Error sending gift: $e');
      rethrow;
    }
  }

  /// Get gift transactions for a room (for live feed)
  Stream<List<GiftTransaction>> getRoomGiftTransactionsStream(String roomId) {
    return _giftTransactions
        .where('roomId', isEqualTo: roomId)
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Convert Timestamp to DateTime if needed
        if (data['sentAt'] is Timestamp) {
          data['sentAt'] = (data['sentAt'] as Timestamp).toDate().toIso8601String();
        }
        
        return GiftTransaction.fromMap(data);
      }).toList();
    });
  }

  /// Get gift transactions for a room (one-time fetch)
  Future<List<GiftTransaction>> getRoomGiftTransactions(String roomId, {int limit = 50}) async {
    try {
      final snapshot = await _giftTransactions
          .where('roomId', isEqualTo: roomId)
          .orderBy('sentAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Convert Timestamp to DateTime if needed
        if (data['sentAt'] is Timestamp) {
          data['sentAt'] = (data['sentAt'] as Timestamp).toDate().toIso8601String();
        }
        
        return GiftTransaction.fromMap(data);
      }).toList();
    } catch (e) {
      AppLogger().error('Firebase: Error getting room gift transactions: $e');
      return [];
    }
  }

  /// Get user's gift sending history
  Future<List<GiftTransaction>> getUserGiftsSent(String userId, {int limit = 20}) async {
    try {
      final snapshot = await _giftTransactions
          .where('senderId', isEqualTo: userId)
          .orderBy('sentAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        if (data['sentAt'] is Timestamp) {
          data['sentAt'] = (data['sentAt'] as Timestamp).toDate().toIso8601String();
        }
        
        return GiftTransaction.fromMap(data);
      }).toList();
    } catch (e) {
      AppLogger().error('Firebase: Error getting user gifts sent: $e');
      return [];
    }
  }

  /// Get user's gift receiving history
  Future<List<GiftTransaction>> getUserGiftsReceived(String userId, {int limit = 20}) async {
    try {
      final snapshot = await _giftTransactions
          .where('recipientId', isEqualTo: userId)
          .orderBy('sentAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        if (data['sentAt'] is Timestamp) {
          data['sentAt'] = (data['sentAt'] as Timestamp).toDate().toIso8601String();
        }
        
        return GiftTransaction.fromMap(data);
      }).toList();
    } catch (e) {
      AppLogger().error('Firebase: Error getting user gifts received: $e');
      return [];
    }
  }

  /// Add coins to user's balance (for admin or reward purposes)
  Future<bool> addCoinsToUser(String userId, int amount, {String? reason}) async {
    try {
      final currentBalance = await getUserCoinBalance(userId);
      
      await _userCoins.doc(userId).update({
        'balance': currentBalance + amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Optionally log the transaction
      if (reason != null) {
        await _firestore.collection('coin_transactions').add({
          'userId': userId,
          'amount': amount,
          'type': 'admin_add',
          'reason': reason,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      AppLogger().info('Firebase: Added $amount coins to user $userId (reason: ${reason ?? 'unspecified'})');
      return true;
    } catch (e) {
      AppLogger().error('Firebase: Error adding coins to user: $e');
      return false;
    }
  }

  /// Get user's coin statistics
  Future<Map<String, dynamic>> getUserCoinStats(String userId) async {
    try {
      final doc = await _userCoins.doc(userId).get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      } else {
        return {
          'balance': 100,
          'totalGiftsSent': 0,
          'totalGiftsReceived': 0,
          'totalReputationFromGifts': 0,
        };
      }
    } catch (e) {
      AppLogger().error('Firebase: Error getting user coin stats: $e');
      return {
        'balance': 0,
        'totalGiftsSent': 0,
        'totalGiftsReceived': 0,
        'totalReputationFromGifts': 0,
      };
    }
  }

  /// Stream of user's coin balance for real-time updates
  Stream<int> getUserCoinBalanceStream(String userId) {
    return _userCoins.doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>)['balance'] ?? 0;
      }
      return 0;
    });
  }
} 