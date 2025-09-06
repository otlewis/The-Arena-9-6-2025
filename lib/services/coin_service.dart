import '../services/appwrite_service.dart';
import '../services/reputation_service.dart';
import '../core/logging/app_logger.dart';
import 'package:get_it/get_it.dart';

class CoinService {
  static final CoinService _instance = CoinService._internal();
  factory CoinService() => _instance;
  CoinService._internal();

  final AppwriteService _appwrite = AppwriteService();
  ReputationService get _reputationService => GetIt.instance<ReputationService>();

  /// Get user's current coin balance
  Future<int> getUserCoins(String userId) async {
    try {
      AppLogger().debug('Getting coins for user $userId');
      
      // Get user profile which should contain coin balance
      final userProfile = await _appwrite.getUserProfile(userId);
      AppLogger().debug('User profile found: ${userProfile != null}');
      
      if (userProfile != null) {
        AppLogger().debug('User coinBalance: ${userProfile.coinBalance}');
        // Return the actual coin balance from the profile
        return userProfile.coinBalance;
      }
      
      // Default balance for new users - automatically give them starting coins
      AppLogger().debug('Initializing coins for new user');
      await _initializeUserCoins(userId);
      return 500; // Give new users 500 coins to start with
    } catch (e) {
      AppLogger().error('Error getting user coins: $e');
      // Even on error, give some coins for new users
      return 500;
    }
  }

  /// Initialize coins for new users
  Future<void> _initializeUserCoins(String userId) async {
    try {
      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'coinBalance': 500, // Starting coin balance
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      AppLogger().info('Initialized user $userId with 500 starting coins');
    } catch (e) {
      AppLogger().error('Error initializing user coins: $e');
    }
  }

  /// Add coins to user's balance
  Future<bool> addCoins(String userId, int amount) async {
    try {
      final currentCoins = await getUserCoins(userId);
      final newBalance = currentCoins + amount;
      
      // Update the coin balance in the user profile
      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'coinBalance': newBalance,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger().info('Added $amount coins to user $userId. New balance: $newBalance');
      return true;
    } catch (e) {
      AppLogger().error('Error adding coins: $e');
      return false;
    }
  }

  /// Deduct coins from user's balance
  Future<bool> deductCoins(String userId, int amount) async {
    try {
      final currentCoins = await getUserCoins(userId);
      
      if (currentCoins < amount) {
        AppLogger().warning('Insufficient coins for user $userId. Has: $currentCoins, needs: $amount');
        return false;
      }
      
      final newBalance = currentCoins - amount;
      
      // Update the user's coin balance
      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'coinBalance': newBalance,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger().info('Deducted $amount coins from user $userId. New balance: $newBalance');
      return true;
    } catch (e) {
      AppLogger().error('Error deducting coins: $e');
      return false;
    }
  }

  /// Send gift from one user to another (awards reputation to both users)
  Future<bool> sendGift(String senderId, String receiverId, int giftAmount) async {
    try {
      AppLogger().info('🎁 Processing gift: $senderId → $receiverId ($giftAmount coins)');
      
      // Check if sender has enough coins
      final senderCoins = await getUserCoins(senderId);
      if (senderCoins < giftAmount) {
        AppLogger().warning('Insufficient coins for gift. Sender has: $senderCoins, needs: $giftAmount');
        return false;
      }
      
      // Deduct coins from sender
      final deductSuccess = await deductCoins(senderId, giftAmount);
      if (!deductSuccess) {
        return false;
      }
      
      // Award reputation to sender for being generous
      await _reputationService.awardGiftSent(senderId, giftAmount);
      
      // Award reputation to receiver for receiving community support
      await _reputationService.awardGiftReceived(receiverId, giftAmount);
      
      // Update gift statistics
      await _updateGiftStatistics(senderId, receiverId, giftAmount);
      
      AppLogger().info('✅ Gift sent successfully and reputation awarded');
      return true;
    } catch (e) {
      AppLogger().error('Error sending gift: $e');
      return false;
    }
  }

  /// Update gift statistics for both users
  Future<void> _updateGiftStatistics(String senderId, String receiverId, int amount) async {
    try {
      // Update sender's gifts sent count
      final senderProfile = await _appwrite.getUserProfile(senderId);
      if (senderProfile != null) {
        await _appwrite.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'users',
          documentId: senderId,
          data: {
            'totalGiftsSent': senderProfile.totalGiftsSent + 1,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );
      }
      
      // Update receiver's gifts received count
      final receiverProfile = await _appwrite.getUserProfile(receiverId);
      if (receiverProfile != null) {
        await _appwrite.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'users',
          documentId: receiverId,
          data: {
            'totalGiftsReceived': receiverProfile.totalGiftsReceived + 1,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      AppLogger().error('Error updating gift statistics: $e');
    }
  }

  /// Check if user has enough coins for a purchase
  Future<bool> hasEnoughCoins(String userId, int requiredAmount) async {
    try {
      final currentCoins = await getUserCoins(userId);
      return currentCoins >= requiredAmount;
    } catch (e) {
      AppLogger().error('Error checking coin balance: $e');
      return false;
    }
  }

  /// Award coins for various activities
  Future<void> awardCoinsForActivity(String userId, String activity) async {
    int coinsToAward = 0;
    
    switch (activity) {
      case 'debate_participation':
        coinsToAward = 10;
        break;
      case 'debate_win':
        coinsToAward = 25;
        break;
      case 'room_creation':
        coinsToAward = 5;
        break;
      case 'daily_login':
        coinsToAward = 5;
        break;
      case 'profile_completion':
        coinsToAward = 50;
        break;
      default:
        coinsToAward = 1;
    }
    
    if (coinsToAward > 0) {
      await addCoins(userId, coinsToAward);
      AppLogger().info('Awarded $coinsToAward coins to user $userId for $activity');
    }
  }
}