import '../core/logging/app_logger.dart';
import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

class InAppPurchaseService {
  static final InAppPurchaseService _instance = InAppPurchaseService._internal();
  factory InAppPurchaseService() => _instance;
  InAppPurchaseService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // Product IDs - these must match what you configure in App Store Connect and Google Play Console
  static const String monthlySubscriptionId = 'arena_pro_monthly';
  static const String yearlySubscriptionId = 'arena_pro_yearly1';
  
  // Coin packages
  static const String coins1000Id = 'arena_coins_1000';
  static const String coins5000Id = 'arena_coins_5000';
  static const String coins10000Id = 'arena_coins_10000';
  static const String coins25000Id = 'arena_coins_25000';
  
  static const Set<String> _productIds = {
    monthlySubscriptionId,
    yearlySubscriptionId,
    coins1000Id,
    coins5000Id,
    coins10000Id,
    coins25000Id,
  };

  // Available products
  List<ProductDetails> _products = [];
  
  // Callbacks
  Function(String productId)? onPurchaseSuccess;
  Function(String error)? onPurchaseError;
  Function(List<ProductDetails> products)? onProductsLoaded;

  Future<bool> get isAvailable => _inAppPurchase.isAvailable();

  List<ProductDetails> get products => _products;

  Future<void> initialize() async {
    AppLogger().debug('🛒 Initializing In-App Purchase Service...');
    
    try {
      // Check if in-app purchase is available on this device with timeout
      AppLogger().debug('🔍 Checking in-app purchase availability...');
      final bool available = await _inAppPurchase.isAvailable()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              AppLogger().warning('⏱️ Availability check timed out - assuming unavailable');
              return false;
            },
          );
      
      if (!available) {
        AppLogger().warning('❌ In-app purchase not available on this device');
        // Call the callback to stop loading on the UI
        onProductsLoaded?.call([]);
        return;
      }
      
      AppLogger().debug('✅ In-app purchase is available');

      // Enable pending purchases (required for subscriptions)
      if (Platform.isIOS) {
        try {
          AppLogger().debug('📱 Setting up iOS payment queue delegate...');
          final InAppPurchaseStoreKitPlatformAddition iosAddition =
              _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
          await iosAddition.setDelegate(ExamplePaymentQueueDelegate())
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () {
                  AppLogger().warning('⏱️ iOS delegate setup timed out');
                },
              );
          AppLogger().debug('✅ iOS payment queue delegate set up successfully');
        } catch (e) {
          AppLogger().warning('❌ Failed to set iOS delegate: $e');
          // Continue anyway - the delegate is optional
        }
      }
      
      // Android doesn't need special setup for pending purchases,
      // but we should ensure the stream is ready
      if (Platform.isAndroid) {
        AppLogger().debug('📱 Initializing Android in-app purchase...');
        // Android automatically handles pending purchases
      }

      // Listen to purchase updates
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdated,
        onDone: () => _subscription.cancel(),
        onError: (error) {
          AppLogger().warning('❌ Purchase stream error: $error');
          // Don't show error dialog on app startup - just log the error
        },
      );

      // Load products
      await loadProducts();
      
      AppLogger().debug('✅ In-App Purchase Service initialized successfully');
    } catch (e) {
      AppLogger().warning('❌ Failed to initialize in-app purchase service: $e');
      // Make sure to call the callback to stop loading
      onProductsLoaded?.call([]);
    }
  }

  Future<void> loadProducts() async {
    AppLogger().debug('📦 Loading products...');
    
    try {
      // Add a timeout to prevent hanging on Android
      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails(_productIds)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              AppLogger().warning('⏱️ Product loading timed out after 10 seconds');
              // Return empty response on timeout
              return ProductDetailsResponse(
                productDetails: [],
                notFoundIDs: _productIds.toList(),
              );
            },
          );
      
      if (response.error != null) {
        AppLogger().warning('❌ Error loading products: ${response.error}');
        // Still call callback with empty products list to stop loading
        _products = [];
        onProductsLoaded?.call(_products);
        return;
      }

      if (response.notFoundIDs.isNotEmpty) {
        AppLogger().debug('⚠️ Products not found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      AppLogger().debug('✅ Loaded ${_products.length} products');
      
      for (var product in _products) {
        AppLogger().debug('📱 Product: ${product.id} - ${product.title} - ${product.price}');
      }
      
      onProductsLoaded?.call(_products);
      
    } catch (e) {
      AppLogger().warning('❌ Exception loading products: $e');
      // Still call callback with empty products list to stop loading
      _products = [];
      onProductsLoaded?.call(_products);
    }
  }

  Future<void> purchaseProduct(ProductDetails product) async {
    AppLogger().debug('💳 Purchasing product: ${product.id}');
    
    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      
      if (product.id == monthlySubscriptionId || product.id == yearlySubscriptionId) {
        // This is a subscription
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else if (product.id.contains('coins')) {
        // This is a coin purchase (consumable)
        await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      } else {
        // This is a one-time purchase (for other items)
        await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      }
      
    } catch (e) {
      AppLogger().debug('❌ Purchase failed: $e');
      onPurchaseError?.call('Purchase failed: $e');
    }
  }

  Future<void> restorePurchases() async {
    AppLogger().debug('🔄 Restoring purchases...');
    
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      AppLogger().debug('❌ Restore failed: $e');
      onPurchaseError?.call('Restore failed: $e');
    }
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      AppLogger().debug('🔄 Purchase status: ${purchaseDetails.status} for ${purchaseDetails.productID}');
      
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          AppLogger().debug('⏳ Purchase pending for ${purchaseDetails.productID}');
          break;
          
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          AppLogger().debug('✅ Purchase successful for ${purchaseDetails.productID}');
          _handleSuccessfulPurchase(purchaseDetails);
          break;
          
        case PurchaseStatus.error:
          AppLogger().debug('❌ Purchase error for ${purchaseDetails.productID}: ${purchaseDetails.error}');
          onPurchaseError?.call('Purchase failed: ${purchaseDetails.error?.message ?? 'Unknown error'}');
          break;
          
        case PurchaseStatus.canceled:
          AppLogger().debug('🚫 Purchase canceled for ${purchaseDetails.productID}');
          onPurchaseError?.call('Purchase was canceled');
          break;
      }

      // Complete the purchase
      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) {
    // Here you would typically:
    // 1. Verify the receipt with your server
    // 2. Grant premium access to the user
    // 3. Update user's subscription status in your database
    
    AppLogger().debug('🎉 Handling successful purchase: ${purchaseDetails.productID}');
    
    // For now, just call the success callback
    onPurchaseSuccess?.call(purchaseDetails.productID);
    
    // TODO: Add server-side receipt verification
    // TODO: Update user's premium status in Appwrite
  }

  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((product) => product.id == productId);
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}

// iOS-specific payment queue delegate for handling transactions
class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
      SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}