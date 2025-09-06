import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';
import 'coin_service.dart';

/// RevenueCat service for handling in-app purchases and subscriptions
class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  final AppwriteService _appwriteService = AppwriteService();
  final CoinService _coinService = CoinService();
  bool _isInitialized = false;
  
  // RevenueCat API Keys - Production Ready
  static const String _iosApiKey = 'appl_qytdGQiNISdracBQJbEFHYzTkIO';
  static const String _androidApiKey = 'goog_YOUR_ANDROID_API_KEY_HERE'; // TODO: Add your Android key from RevenueCat dashboard
  static const String _webApiKey = 'rc_YOUR_WEB_API_KEY_HERE'; // TODO: Add your Web key for Stripe integration
  
  // Product identifiers - must match your App Store Connect/Google Play Console
  static const Map<String, String> productIds = {
    'arena_pro_monthly': 'arena_pro_monthly',
    'arena_pro_yearly': 'arena_pro_yearly',
    'arena_coins_1000': 'arena_coins_1000',
    'arena_coins_5000': 'arena_coins_5000',
    'arena_coins_10000': 'arena_coins_10000',
    'arena_coins_25000': 'arena_coins_25000',
  };

  // Entitlement identifiers - must match your RevenueCat dashboard
  static const String premiumEntitlement = 'Arena Pro';
  
  // Callbacks
  Function(String productId, CustomerInfo customerInfo)? onPurchaseSuccess;
  Function(String error, bool userCancelled)? onPurchaseError;
  Function(bool processing)? onProcessingStateChanged;

  /// Initialize RevenueCat SDK
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      AppLogger().debug('🏪 Initializing RevenueCat...');
      
      // Configure RevenueCat
      late PurchasesConfiguration configuration;
      
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        configuration = PurchasesConfiguration(_iosApiKey);
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        configuration = PurchasesConfiguration(_androidApiKey);
      } else {
        // Web/other platforms
        configuration = PurchasesConfiguration(_webApiKey);
      }
      
      await Purchases.configure(configuration);
      
      // Set debug logs in development
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }
      
      // Set up listener for customer info updates
      Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);
      
      _isInitialized = true;
      AppLogger().info('✅ RevenueCat initialized successfully');
      
      return true;
    } catch (e) {
      AppLogger().error('❌ Failed to initialize RevenueCat: $e');
      return false;
    }
  }

  /// Set user ID for RevenueCat (call after user authentication)
  Future<void> setUserId(String userId) async {
    try {
      await Purchases.logIn(userId);
      AppLogger().debug('👤 RevenueCat user set: $userId');
    } catch (e) {
      AppLogger().warning('Failed to set RevenueCat user: $e');
    }
  }

  /// Get available products/subscriptions
  Future<List<StoreProduct>> getProducts() async {
    try {
      AppLogger().debug('🛍️ Fetching available products...');
      
      final offerings = await Purchases.getOfferings();
      
      if (offerings.current != null) {
        final products = <StoreProduct>[];
        
        // Get subscription products
        for (final package in offerings.current!.availablePackages) {
          products.add(package.storeProduct);
        }
        
        AppLogger().debug('Found ${products.length} products');
        return products;
      } else {
        AppLogger().warning('No current offering found');
        return [];
      }
    } catch (e) {
      AppLogger().error('Failed to get products: $e');
      return [];
    }
  }

  /// Purchase a subscription
  Future<bool> purchaseSubscription(String productId) async {
    try {
      AppLogger().debug('💳 Starting subscription purchase: $productId');
      onProcessingStateChanged?.call(true);
      
      // Get offerings
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        throw Exception('No offerings available');
      }
      
      // Find the package
      Package? targetPackage;
      for (final package in offerings.current!.availablePackages) {
        if (package.storeProduct.identifier == productId) {
          targetPackage = package;
          break;
        }
      }
      
      if (targetPackage == null) {
        throw Exception('Product not found: $productId');
      }
      
      // Make the purchase
      final purchaseResult = await Purchases.purchasePackage(targetPackage);
      
      // Handle successful purchase
      await _handlePurchaseSuccess(productId, purchaseResult.customerInfo);
      
      AppLogger().info('🎉 Subscription purchase successful: $productId');
      return true;
      
    } catch (e) {
      AppLogger().error('💥 Purchase failed: $e');
      
      // Check if user cancelled
      final userCancelled = e.toString().contains('UserCancelled') || 
                           e.toString().contains('cancelled');
      
      onPurchaseError?.call(e.toString(), userCancelled);
      return false;
    } finally {
      onProcessingStateChanged?.call(false);
    }
  }

  /// Purchase coins (non-consumable for now, can be made consumable)
  Future<bool> purchaseCoins(String productId) async {
    try {
      AppLogger().debug('🪙 Starting coin purchase: $productId');
      onProcessingStateChanged?.call(true);
      
      // For coins, we can use the same subscription flow
      // But mark them as consumable in RevenueCat dashboard
      final success = await purchaseSubscription(productId);
      
      if (success) {
        AppLogger().info('🎉 Coin purchase successful: $productId');
      }
      
      return success;
      
    } catch (e) {
      AppLogger().error('💥 Coin purchase failed: $e');
      onPurchaseError?.call(e.toString(), false);
      return false;
    } finally {
      onProcessingStateChanged?.call(false);
    }
  }

  /// Get current customer info
  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo;
    } catch (e) {
      AppLogger().warning('Failed to get customer info: $e');
      return null;
    }
  }

  /// Check if user has premium subscription
  Future<bool> hasPremiumSubscription() async {
    try {
      final customerInfo = await getCustomerInfo();
      if (customerInfo == null) return false;
      
      // Check if user has active premium entitlement
      final entitlements = customerInfo.entitlements.active;
      final hasPremium = entitlements.containsKey(premiumEntitlement);
      
      AppLogger().debug('Premium check: $hasPremium');
      return hasPremium;
    } catch (e) {
      AppLogger().warning('Failed to check premium status: $e');
      return false;
    }
  }

  /// Get premium subscription type (monthly/yearly)
  Future<String?> getPremiumSubscriptionType() async {
    try {
      final customerInfo = await getCustomerInfo();
      if (customerInfo == null) return null;
      
      final entitlements = customerInfo.entitlements.active;
      final premiumEntitlementInfo = entitlements[premiumEntitlement];
      
      if (premiumEntitlementInfo != null) {
        final productId = premiumEntitlementInfo.productIdentifier;
        
        if (productId.contains('yearly')) {
          return 'yearly';
        } else if (productId.contains('monthly')) {
          return 'monthly';
        }
      }
      
      return null;
    } catch (e) {
      AppLogger().warning('Failed to get subscription type: $e');
      return null;
    }
  }

  /// Handle successful purchase
  Future<void> _handlePurchaseSuccess(String productId, CustomerInfo customerInfo) async {
    try {
      AppLogger().debug('🎯 Processing successful purchase: $productId');
      
      // Get current user
      final user = await _appwriteService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Update Appwrite database based on purchase type
      if (productId.contains('coins')) {
        await _grantCoins(user.$id, productId);
      } else if (productId.contains('monthly') || productId.contains('yearly')) {
        await _grantSubscription(user.$id, productId, customerInfo);
      }
      
      // Call success callback
      onPurchaseSuccess?.call(productId, customerInfo);
      
    } catch (e) {
      AppLogger().error('Failed to process purchase success: $e');
      // Don't rethrow - purchase was successful in RevenueCat
    }
  }

  /// Grant coins for successful purchase
  Future<void> _grantCoins(String userId, String productId) async {
    int coinsToAdd = 0;
    
    switch (productId) {
      case 'arena_coins_1000':
        coinsToAdd = 1000;
        break;
      case 'arena_coins_5000':
        coinsToAdd = 5500; // 5000 + 10% bonus
        break;
      case 'arena_coins_10000':
        coinsToAdd = 11500; // 10000 + 15% bonus
        break;
      case 'arena_coins_25000':
        coinsToAdd = 30000; // 25000 + 20% bonus
        break;
    }
    
    if (coinsToAdd > 0) {
      await _coinService.addCoins(userId, coinsToAdd);
      AppLogger().debug('💰 Granted $coinsToAdd coins to user $userId');
    }
  }

  /// Grant subscription for successful purchase
  Future<void> _grantSubscription(String userId, String productId, CustomerInfo customerInfo) async {
    try {
      // Get expiry date from RevenueCat
      final entitlements = customerInfo.entitlements.active;
      final premiumEntitlementInfo = entitlements[premiumEntitlement];
      
      DateTime? expiryDate;
      if (premiumEntitlementInfo != null && premiumEntitlementInfo.expirationDate != null) {
        expiryDate = DateTime.parse(premiumEntitlementInfo.expirationDate!);
      } else {
        // Fallback calculation
        final duration = productId.contains('yearly') 
            ? const Duration(days: 365) 
            : const Duration(days: 30);
        expiryDate = DateTime.now().add(duration);
      }
      
      // Update user profile with premium status
      await _appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'isPremium': true,
          'premiumType': productId.contains('yearly') ? 'yearly' : 'monthly',
          'premiumExpiry': expiryDate.toIso8601String(),
          'isTestSubscription': false, // Real purchase
        },
      );
      
      // Grant welcome bonus coins
      await _coinService.addCoins(userId, 1000);
      
      AppLogger().debug('⭐ Granted ${productId.contains('yearly') ? 'yearly' : 'monthly'} subscription to user $userId');
    } catch (e) {
      AppLogger().warning('Failed to update subscription status: $e');
      // Don't rethrow - purchase was successful
    }
  }

  /// Handle customer info updates (webhooks/real-time updates)
  void _handleCustomerInfoUpdate(CustomerInfo customerInfo) {
    AppLogger().debug('📱 Customer info updated');
    
    // Sync with Appwrite database
    _syncCustomerInfoWithAppwrite(customerInfo);
  }

  /// Sync RevenueCat customer info with Appwrite
  Future<void> _syncCustomerInfoWithAppwrite(CustomerInfo customerInfo) async {
    try {
      final user = await _appwriteService.getCurrentUser();
      if (user == null) return;
      
      final entitlements = customerInfo.entitlements.active;
      final hasPremium = entitlements.containsKey(premiumEntitlement);
      
      String? premiumType;
      DateTime? expiryDate;
      
      if (hasPremium) {
        final entitlementInfo = entitlements[premiumEntitlement]!;
        final productId = entitlementInfo.productIdentifier;
        
        premiumType = productId.contains('yearly') ? 'yearly' : 'monthly';
        
        if (entitlementInfo.expirationDate != null) {
          expiryDate = DateTime.parse(entitlementInfo.expirationDate!);
        }
      }
      
      // Update Appwrite
      await _appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: user.$id,
        data: {
          'isPremium': hasPremium,
          'premiumType': premiumType,
          'premiumExpiry': expiryDate?.toIso8601String(),
          'isTestSubscription': false,
        },
      );
      
      AppLogger().debug('🔄 Synced customer info with Appwrite');
      
    } catch (e) {
      AppLogger().warning('Failed to sync customer info: $e');
    }
  }

  /// Restore purchases (for users who reinstall the app)
  Future<bool> restorePurchases() async {
    try {
      AppLogger().debug('🔄 Restoring purchases...');
      onProcessingStateChanged?.call(true);
      
      final customerInfo = await Purchases.restorePurchases();
      
      // Sync restored purchases with Appwrite
      await _syncCustomerInfoWithAppwrite(customerInfo);
      
      AppLogger().info('✅ Purchases restored successfully');
      return true;
      
    } catch (e) {
      AppLogger().error('❌ Failed to restore purchases: $e');
      onPurchaseError?.call(e.toString(), false);
      return false;
    } finally {
      onProcessingStateChanged?.call(false);
    }
  }

  /// Log out user (call when user signs out)
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
      AppLogger().debug('👋 RevenueCat user logged out');
    } catch (e) {
      AppLogger().warning('Failed to log out RevenueCat user: $e');
    }
  }

  /// Check if RevenueCat is initialized
  bool get isInitialized => _isInitialized;

  /// Force sync premium status from RevenueCat to Appwrite (for troubleshooting)
  Future<void> forceSyncPremiumStatus() async {
    try {
      AppLogger().debug('🔄 Force syncing premium status...');
      
      // Get customer info with detailed logging
      final customerInfo = await getCustomerInfo();
      if (customerInfo != null) {
        AppLogger().debug('📊 Customer Info Details:');
        AppLogger().debug('  - Customer ID: ${customerInfo.originalAppUserId}');
        AppLogger().debug('  - Active Entitlements: ${customerInfo.entitlements.active.keys.toList()}');
        AppLogger().debug('  - All Entitlements: ${customerInfo.entitlements.all.keys.toList()}');
        
        // Check premium entitlement specifically
        final hasPremium = customerInfo.entitlements.active.containsKey(premiumEntitlement);
        AppLogger().debug('  - Has Premium Entitlement: $hasPremium');
        
        if (hasPremium) {
          final entitlementInfo = customerInfo.entitlements.active[premiumEntitlement]!;
          AppLogger().debug('  - Product ID: ${entitlementInfo.productIdentifier}');
          AppLogger().debug('  - Expiry Date: ${entitlementInfo.expirationDate}');
          AppLogger().debug('  - Is Sandbox: ${entitlementInfo.isSandbox}');
        }
        
        await _syncCustomerInfoWithAppwrite(customerInfo);
        AppLogger().info('✅ Force sync completed');
      } else {
        AppLogger().warning('❌ No customer info available for sync - user might not be logged into RevenueCat');
      }
    } catch (e) {
      AppLogger().error('❌ Force sync failed: $e');
      rethrow; // Re-throw so the UI can show the error
    }
  }

  /// Check RevenueCat connection status and user login
  Future<Map<String, dynamic>> getRevenueCatStatus() async {
    try {
      final customerInfo = await getCustomerInfo();
      final hasPremium = await hasPremiumSubscription();
      
      return {
        'isInitialized': _isInitialized,
        'hasCustomerInfo': customerInfo != null,
        'customerUserId': customerInfo?.originalAppUserId,
        'hasPremium': hasPremium,
        'activeEntitlements': customerInfo?.entitlements.active.keys.toList() ?? [],
        'allEntitlements': customerInfo?.entitlements.all.keys.toList() ?? [],
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'isInitialized': _isInitialized,
        'hasCustomerInfo': false,
      };
    }
  }

  /// Mock purchase for testing (sandbox functionality)
  Future<bool> mockSandboxPurchase(String productId) async {
    try {
      AppLogger().debug('🧪 Creating mock sandbox purchase: $productId');
      onProcessingStateChanged?.call(true);
      
      // Get current user
      final user = await _appwriteService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Set user ID in RevenueCat if not already set
      await setUserId(user.$id);
      
      // Simulate successful purchase by directly updating Appwrite
      // This mimics what a real RevenueCat purchase would do
      await _mockGrantSubscription(user.$id, productId);
      
      // Create mock customer info for callbacks
      final mockCustomerInfo = await getCustomerInfo();
      onPurchaseSuccess?.call(productId, mockCustomerInfo!);
      
      AppLogger().info('✅ Mock sandbox purchase successful: $productId');
      return true;
      
    } catch (e) {
      AppLogger().error('❌ Mock purchase failed: $e');
      onPurchaseError?.call(e.toString(), false);
      return false;
    } finally {
      onProcessingStateChanged?.call(false);
    }
  }

  /// Mock grant subscription (for testing without real RevenueCat purchases)
  Future<void> _mockGrantSubscription(String userId, String productId) async {
    try {
      // Calculate expiry date
      final duration = productId.contains('yearly') 
          ? const Duration(days: 365) 
          : const Duration(days: 30);
      final expiryDate = DateTime.now().add(duration);
      
      // Update user profile with premium status
      await _appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'isPremium': true,
          'premiumType': productId.contains('yearly') ? 'yearly' : 'monthly',
          'premiumExpiry': expiryDate.toIso8601String(),
          'isTestSubscription': true, // Mark as test purchase
        },
      );
      
      // Grant welcome bonus coins
      await _coinService.addCoins(userId, 1000);
      
      AppLogger().debug('🧪 Mock granted ${productId.contains('yearly') ? 'yearly' : 'monthly'} subscription to user $userId');
    } catch (e) {
      AppLogger().warning('Failed to grant mock subscription: $e');
      rethrow;
    }
  }
}