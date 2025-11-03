import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';
import '../models/money_tip.dart';
import '../models/user_profile.dart';

/// Service for handling Stripe payments for real money tips
class StripePaymentService {
  static final StripePaymentService _instance = StripePaymentService._internal();
  factory StripePaymentService() => _instance;
  StripePaymentService._internal();

  final AppwriteService _appwriteService = AppwriteService();
  bool _isInitialized = false;

  /// Initialize Stripe with publishable key
  /// Call this in main.dart before runApp()
  Future<void> initialize({required String publishableKey}) async {
    if (_isInitialized) return;

    try {
      Stripe.publishableKey = publishableKey;
      Stripe.merchantIdentifier = 'merchant.com.thearenadtd.app';
      await Stripe.instance.applySettings();
      _isInitialized = true;
      AppLogger().info('✅ Stripe initialized successfully');
    } catch (e) {
      AppLogger().error('❌ Failed to initialize Stripe: $e');
      rethrow;
    }
  }

  /// Send a money tip to a user
  /// Returns true if successful, false otherwise
  Future<bool> sendMoneyTip({
    required UserProfile recipient,
    required double amount,
    String? message,
    String? roomId,
    RoomType? roomType,
  }) async {
    try {
      AppLogger().info('💵 Starting money tip: \$$amount to ${recipient.displayName}');

      // Validate amount (minimum $1, maximum $10,000)
      if (amount < 1.0 || amount > 10000.0) {
        AppLogger().error('❌ Invalid amount: \$$amount (must be between \$1 and \$10,000)');
        throw Exception('Amount must be between \$1 and \$10,000');
      }

      // Get current user
      final currentUser = await _appwriteService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if recipient has Stripe Connect account
      final recipientHasPaymentAccount = await _checkRecipientPaymentAccount(recipient.id);
      if (!recipientHasPaymentAccount) {
        throw Exception('${recipient.displayName} has not set up their payment account yet');
      }

      // STEP 1: Create payment intent via Appwrite Function
      final paymentIntent = await _createPaymentIntent(
        recipientId: recipient.id,
        amount: amount,
        currency: 'usd',
        message: message,
        roomId: roomId,
        roomType: roomType,
      );

      if (paymentIntent == null) {
        throw Exception('Failed to create payment intent');
      }

      // STEP 2: Present payment sheet to user
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'The Arena DTD',
          paymentIntentClientSecret: paymentIntent['clientSecret'],
          customerEphemeralKeySecret: paymentIntent['ephemeralKey'],
          customerId: paymentIntent['customerId'],
          style: ThemeMode.dark,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: const Color(0xFF6366F1),
              background: const Color(0xFF1F2937),
              componentBackground: const Color(0xFF374151),
              componentText: const Color(0xFFFFFFFF),
              primaryText: const Color(0xFFFFFFFF),
              secondaryText: const Color(0xFF9CA3AF),
            ),
            shapes: PaymentSheetShape(
              borderRadius: 12,
              borderWidth: 0,
            ),
            primaryButton: PaymentSheetPrimaryButtonAppearance(
              colors: PaymentSheetPrimaryButtonTheme(
                dark: PaymentSheetPrimaryButtonThemeColors(
                  background: const Color(0xFF6366F1),
                  text: const Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        ),
      );

      // STEP 3: Display payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Payment successful!
      AppLogger().info('✅ Payment successful: \$$amount to ${recipient.displayName}');

      // STEP 4: Confirm payment with backend
      await _confirmPayment(paymentIntent['paymentIntentId']);

      return true;
    } on StripeException catch (e) {
      AppLogger().error('❌ Stripe error: ${e.error.localizedMessage}');
      if (e.error.code == FailureCode.Canceled) {
        AppLogger().info('User canceled payment');
        return false;
      }
      throw Exception(e.error.localizedMessage ?? 'Payment failed');
    } catch (e) {
      AppLogger().error('❌ Money tip error: $e');
      rethrow;
    }
  }

  /// Create a payment intent via Appwrite Function
  /// This calls your backend to create a Stripe Payment Intent
  Future<Map<String, dynamic>?> _createPaymentIntent({
    required String recipientId,
    required double amount,
    required String currency,
    String? message,
    String? roomId,
    RoomType? roomType,
  }) async {
    try {
      // Call Appwrite Function to create payment intent
      // The function will handle Stripe API calls securely
      final result = await _appwriteService.callFunction(
        functionId: 'create-payment-intent',
        body: {
          'recipientId': recipientId,
          'amount': (amount * 100).toInt(), // Convert to cents
          'currency': currency,
          'message': message,
          'roomId': roomId,
          'roomType': roomType?.name,
        },
      );

      if (result['success'] == true) {
        return result['data'];
      } else {
        throw Exception(result['error'] ?? 'Failed to create payment intent');
      }
    } catch (e) {
      AppLogger().error('Failed to create payment intent: $e');
      return null;
    }
  }

  /// Check if recipient has set up their Stripe Connect account
  Future<bool> _checkRecipientPaymentAccount(String userId) async {
    try {
      final result = await _appwriteService.callFunction(
        functionId: 'check-payment-account',
        body: {'userId': userId},
      );
      return result['hasAccount'] == true;
    } catch (e) {
      AppLogger().error('Failed to check payment account: $e');
      return false;
    }
  }

  /// Confirm payment with backend after Stripe confirms
  Future<void> _confirmPayment(String paymentIntentId) async {
    try {
      await _appwriteService.callFunction(
        functionId: 'confirm-payment',
        body: {'paymentIntentId': paymentIntentId},
      );
    } catch (e) {
      AppLogger().error('Failed to confirm payment: $e');
    }
  }

  /// Get user's Stripe Connect onboarding link
  /// Returns URL to complete Stripe Connect account setup
  Future<String?> getStripeConnectOnboardingLink() async {
    try {
      final result = await _appwriteService.callFunction(
        functionId: 'create-connect-account',
        body: {},
      );

      if (result['success'] == true) {
        return result['onboardingUrl'];
      }
      return null;
    } catch (e) {
      AppLogger().error('Failed to get onboarding link: $e');
      return null;
    }
  }

  /// Check if current user has completed Stripe Connect onboarding
  Future<bool> hasCompletedStripeOnboarding() async {
    try {
      final user = await _appwriteService.getCurrentUser();
      if (user == null) return false;

      final result = await _appwriteService.callFunction(
        functionId: 'check-payment-account',
        body: {'userId': user.$id},
      );

      return result['hasAccount'] == true && result['isOnboarded'] == true;
    } catch (e) {
      AppLogger().error('Failed to check onboarding status: $e');
      return false;
    }
  }
}
