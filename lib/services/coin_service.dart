import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

class CoinService {
  static final CoinService _instance = CoinService._internal();
  factory CoinService() => _instance;
  CoinService._internal();

  final AppwriteService _appwrite = AppwriteService();

  /// Get user's current coin balance
  Future<int> getUserCoins(String userId) async {
    try {
      print('💰 CoinService DEBUG: Getting coins for user $userId');
      
      // Get user profile which should contain coin balance
      final userProfile = await _appwrite.getUserProfile(userId);
      print('💰 CoinService DEBUG: User profile found: ${userProfile != null}');
      
      if (userProfile != null) {
        print('💰 CoinService DEBUG: User reputation: ${userProfile.reputation}');
        // If coin balance exists in profile and is greater than 0, return it
        if (userProfile.reputation > 0) {
          print('💰 CoinService DEBUG: Returning existing reputation: ${userProfile.reputation}');
          return userProfile.reputation; // Using reputation as coins for now
        }
      }
      
      // Default balance for new users - automatically give them starting coins
      print('💰 CoinService DEBUG: Initializing coins for new user');
      await _initializeUserCoins(userId);
      return 500; // Give new users 500 coins to start with for testing
    } catch (e) {
      AppLogger().error('Error getting user coins: $e');
      print('💰 CoinService ERROR: $e');
      // Even on error, give some coins for testing
      return 500;
    }
  }

  /// Initialize coins for new users
  Future<void> _initializeUserCoins(String userId) async {
    try {
      await _appwrite.updateUserProfile(
        userId: userId,
        reputation: 500, // Starting balance
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
      
      // For now, update the reputation field to store coins
      // In a real app, you'd have a separate coins field
      await _appwrite.updateUserProfile(
        userId: userId,
        reputation: newBalance,
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
      
      // Update the user's balance
      await _appwrite.updateUserProfile(
        userId: userId,
        reputation: newBalance,
      );
      
      AppLogger().info('Deducted $amount coins from user $userId. New balance: $newBalance');
      return true;
    } catch (e) {
      AppLogger().error('Error deducting coins: $e');
      return false;
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