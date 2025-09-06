import 'dart:async';
import 'package:flutter/material.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';
import 'coin_service.dart';

/// Mock payment service for beta testing
/// Allows testers to simulate purchases without real payments
class MockPaymentService {
  static final MockPaymentService _instance = MockPaymentService._internal();
  factory MockPaymentService() => _instance;
  MockPaymentService._internal();

  final AppwriteService _appwriteService = AppwriteService();
  final CoinService _coinService = CoinService();
  
  // Test mode flag - can be toggled via settings or environment
  static bool isTestMode = true;
  
  // Mock test cards for different scenarios
  static const Map<String, TestCardResult> testCards = {
    '4242 4242 4242 4242': TestCardResult.success,
    '4000 0000 0000 0002': TestCardResult.declined,
    '4000 0000 0000 9995': TestCardResult.insufficientFunds,
    '4000 0000 0000 0119': TestCardResult.processingError,
    '4000 0000 0000 0127': TestCardResult.invalidCvc,
    '5555 5555 5555 4444': TestCardResult.success, // Mastercard
    '3782 8224 6310 005': TestCardResult.success,  // Amex
  };
  
  // Product prices (in cents for Stripe-like handling)
  static const Map<String, int> productPrices = {
    'arena_pro_monthly': 999,      // $9.99
    'arena_pro_yearly': 9999,      // $99.99
    'arena_coins_1000': 99,        // $0.99
    'arena_coins_5000': 499,       // $4.99
    'arena_coins_10000': 999,      // $9.99
    'arena_coins_25000': 1999,     // $19.99
  };
  
  // Callbacks
  Function(String productId, Map<String, dynamic> receipt)? onPurchaseSuccess;
  Function(String error)? onPurchaseError;
  Function(bool processing)? onProcessingStateChanged;
  
  /// Process a mock payment for beta testing
  Future<PaymentResult> processMockPayment({
    required String productId,
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvc,
    required String cardholderName,
    String? email,
    String? zipCode,
  }) async {
    AppLogger().debug('🧪 Processing MOCK payment for product: $productId');
    
    try {
      // Update processing state
      onProcessingStateChanged?.call(true);
      
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));
      
      // Validate card format
      final cleanCardNumber = cardNumber.replaceAll(' ', '').replaceAll('-', '');
      if (cleanCardNumber.length < 13 || cleanCardNumber.length > 19) {
        throw PaymentException('Invalid card number format');
      }
      
      // Check expiry
      final now = DateTime.now();
      final expMonth = int.tryParse(expiryMonth) ?? 0;
      final expYear = int.tryParse(expiryYear) ?? 0;
      final fullYear = expYear < 100 ? 2000 + expYear : expYear;
      
      if (expMonth < 1 || expMonth > 12) {
        throw PaymentException('Invalid expiry month');
      }
      
      if (fullYear < now.year || (fullYear == now.year && expMonth < now.month)) {
        throw PaymentException('Card has expired');
      }
      
      // Validate CVC
      if (cvc.length < 3 || cvc.length > 4) {
        throw PaymentException('Invalid security code');
      }
      
      // Check test card result
      final formattedCard = _formatCardNumber(cardNumber);
      final testResult = testCards[formattedCard] ?? TestCardResult.success;
      
      // Simulate different outcomes based on test card
      switch (testResult) {
        case TestCardResult.success:
          return await _processSuccessfulPayment(productId, cardholderName, email);
          
        case TestCardResult.declined:
          throw PaymentException('Your card was declined');
          
        case TestCardResult.insufficientFunds:
          throw PaymentException('Insufficient funds');
          
        case TestCardResult.processingError:
          throw PaymentException('Error processing payment. Please try again');
          
        case TestCardResult.invalidCvc:
          throw PaymentException('Invalid security code');
      }
      
    } catch (e) {
      AppLogger().warning('❌ Mock payment failed: $e');
      onPurchaseError?.call(e.toString());
      return PaymentResult(
        success: false,
        error: e.toString(),
      );
    } finally {
      onProcessingStateChanged?.call(false);
    }
  }
  
  /// Process successful mock payment
  Future<PaymentResult> _processSuccessfulPayment(
    String productId,
    String cardholderName,
    String? email,
  ) async {
    AppLogger().debug('✅ Processing successful mock payment for $productId');
    
    // Get current user
    final user = await _appwriteService.getCurrentUser();
    if (user == null) {
      throw PaymentException('User not authenticated');
    }
    
    // Create mock receipt
    final receipt = {
      'transactionId': 'mock_${DateTime.now().millisecondsSinceEpoch}',
      'productId': productId,
      'userId': user.$id,
      'amount': productPrices[productId] ?? 0,
      'currency': 'USD',
      'status': 'completed',
      'testMode': true,
      'cardholderName': cardholderName,
      'email': email ?? user.email,
      'timestamp': DateTime.now().toIso8601String(),
      'environment': 'beta_test',
    };
    
    // Process based on product type
    if (productId.contains('coins')) {
      await _grantCoins(user.$id, productId);
    } else if (productId.contains('monthly') || productId.contains('yearly')) {
      await _grantSubscription(user.$id, productId);
    }
    
    // Store mock transaction (optional - for analytics)
    await _storeMockTransaction(receipt);
    
    // Call success callback
    onPurchaseSuccess?.call(productId, receipt);
    
    AppLogger().debug('🎉 Mock payment completed successfully');
    
    return PaymentResult(
      success: true,
      transactionId: receipt['transactionId'] as String,
      receipt: receipt,
    );
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
  Future<void> _grantSubscription(String userId, String productId) async {
    final duration = productId.contains('yearly') 
        ? const Duration(days: 365) 
        : const Duration(days: 30);
    
    final expiryDate = DateTime.now().add(duration);
    
    try {
      // Update user profile with premium status
      await _appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'isPremium': true,
          'premiumType': productId.contains('yearly') ? 'yearly' : 'monthly',
          'premiumExpiry': expiryDate.toIso8601String(),
          'isTestSubscription': true, // Mark as test subscription
        },
      );
      
      // Also grant welcome bonus coins
      await _coinService.addCoins(userId, 1000);
      
      AppLogger().debug('⭐ Granted ${productId.contains('yearly') ? 'yearly' : 'monthly'} subscription to user $userId');
    } catch (e) {
      AppLogger().warning('Failed to update subscription status: $e');
      // Continue anyway - coins were still granted
    }
  }
  
  /// Store mock transaction for analytics
  Future<void> _storeMockTransaction(Map<String, dynamic> receipt) async {
    try {
      // Store in a mock_transactions collection for tracking
      await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'mock_transactions',
        documentId: receipt['transactionId'] as String,
        data: receipt,
      );
    } catch (e) {
      // Collection might not exist - that's okay for beta
      AppLogger().debug('Could not store mock transaction: $e');
    }
  }
  
  /// Format card number for comparison
  String _formatCardNumber(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();
    
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(cleaned[i]);
    }
    
    return buffer.toString();
  }
  
  /// Validate card number using Luhn algorithm
  bool _validateCardNumber(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleaned.length < 13 || cleaned.length > 19) {
      return false;
    }
    
    int sum = 0;
    bool alternate = false;
    
    for (int i = cleaned.length - 1; i >= 0; i--) {
      int digit = int.parse(cleaned[i]);
      
      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }
      
      sum += digit;
      alternate = !alternate;
    }
    
    return sum % 10 == 0;
  }
  
  /// Get card type from number
  CardType getCardType(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleaned.startsWith('4')) {
      return CardType.visa;
    } else if (cleaned.startsWith('5') || cleaned.startsWith('2')) {
      return CardType.mastercard;
    } else if (cleaned.startsWith('34') || cleaned.startsWith('37')) {
      return CardType.amex;
    } else if (cleaned.startsWith('6')) {
      return CardType.discover;
    }
    
    return CardType.unknown;
  }
  
  /// Check if we're in test mode
  static bool get inTestMode => isTestMode;
  
  /// Toggle test mode
  static void setTestMode(bool enabled) {
    isTestMode = enabled;
    AppLogger().debug('🧪 Test mode ${enabled ? 'enabled' : 'disabled'}');
  }
}

/// Test card results for different scenarios
enum TestCardResult {
  success,
  declined,
  insufficientFunds,
  processingError,
  invalidCvc,
}

/// Card types
enum CardType {
  visa,
  mastercard,
  amex,
  discover,
  unknown,
}

/// Payment result
class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? error;
  final Map<String, dynamic>? receipt;
  
  PaymentResult({
    required this.success,
    this.transactionId,
    this.error,
    this.receipt,
  });
}

/// Payment exception
class PaymentException implements Exception {
  final String message;
  PaymentException(this.message);
  
  @override
  String toString() => message;
}