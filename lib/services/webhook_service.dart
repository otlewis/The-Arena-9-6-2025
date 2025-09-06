import 'dart:async';
import 'dart:convert';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

/// Service for handling RevenueCat webhooks
class WebhookService {
  static final WebhookService _instance = WebhookService._internal();
  factory WebhookService() => _instance;
  WebhookService._internal();

  final AppwriteService _appwriteService = AppwriteService();

  /// Process RevenueCat webhook payload
  Future<bool> processRevenueCatWebhook(Map<String, dynamic> payload) async {
    try {
      AppLogger().debug('🪝 Processing RevenueCat webhook: ${payload['event_type']}');
      
      final eventType = payload['event_type'] as String;
      final event = payload['event'] as Map<String, dynamic>;
      
      // Extract user and subscription info
      final appUserId = event['app_user_id'] as String?;
      final productId = event['product_id'] as String?;
      final eventTimeMs = event['event_timestamp_ms'] as int?;
      final environment = event['environment'] as String?; // 'SANDBOX' or 'PRODUCTION'
      
      if (appUserId == null) {
        AppLogger().warning('Webhook missing app_user_id');
        return false;
      }

      // Store webhook event for audit trail
      await _storeWebhookEvent(eventType, payload, appUserId);

      // Process different event types
      switch (eventType) {
        case 'INITIAL_PURCHASE':
        case 'RENEWAL':
        case 'PRODUCT_CHANGE':
          return await _handleSubscriptionActivation(appUserId, productId, environment, eventTimeMs);
          
        case 'CANCELLATION':
          return await _handleSubscriptionCancellation(appUserId, eventTimeMs);
          
        case 'EXPIRATION':
          return await _handleSubscriptionExpiration(appUserId, eventTimeMs);
          
        case 'BILLING_ISSUE':
          return await _handleBillingIssue(appUserId, eventTimeMs);
          
        case 'SUBSCRIBER_ALIAS':
          return await _handleSubscriberAlias(event);
          
        default:
          AppLogger().info('Unhandled webhook event type: $eventType');
          return true; // Don't fail for unknown events
      }
      
    } catch (e) {
      AppLogger().error('Failed to process RevenueCat webhook: $e');
      return false;
    }
  }

  /// Store webhook event for audit trail
  Future<void> _storeWebhookEvent(String eventType, Map<String, dynamic> payload, String userId) async {
    try {
      await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'webhook_events',
        documentId: 'unique()',
        data: {
          'eventType': eventType,
          'userId': userId,
          'payload': jsonEncode(payload),
          'processedAt': DateTime.now().toIso8601String(),
          'source': 'revenuecat',
        },
      );
    } catch (e) {
      AppLogger().warning('Failed to store webhook event: $e');
      // Don't fail the main process if audit logging fails
    }
  }

  /// Handle subscription activation (purchase, renewal, upgrade)
  Future<bool> _handleSubscriptionActivation(String userId, String? productId, String? environment, int? eventTimeMs) async {
    try {
      final isTestSubscription = environment == 'SANDBOX';
      final eventTime = eventTimeMs != null ? DateTime.fromMillisecondsSinceEpoch(eventTimeMs) : DateTime.now();
      
      // Calculate expiry based on product type
      Duration subscriptionDuration;
      String premiumType;
      
      if (productId?.contains('yearly') == true) {
        subscriptionDuration = const Duration(days: 365);
        premiumType = 'yearly';
      } else {
        subscriptionDuration = const Duration(days: 30);
        premiumType = 'monthly';
      }
      
      final expiryDate = eventTime.add(subscriptionDuration);
      
      // Update user profile
      await _appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'isPremium': true,
          'premiumType': premiumType,
          'premiumExpiry': expiryDate.toIso8601String(),
          'isTestSubscription': isTestSubscription,
          'lastWebhookUpdate': DateTime.now().toIso8601String(),
        },
      );

      // Store subscription record
      await _storeSubscriptionRecord(userId, productId, 'active', eventTime, expiryDate, isTestSubscription);
      
      AppLogger().info('✅ Subscription activated for user $userId: $premiumType ($productId)');
      return true;
      
    } catch (e) {
      AppLogger().error('Failed to handle subscription activation: $e');
      return false;
    }
  }

  /// Handle subscription cancellation
  Future<bool> _handleSubscriptionCancellation(String userId, int? eventTimeMs) async {
    try {
      final eventTime = eventTimeMs != null ? DateTime.fromMillisecondsSinceEpoch(eventTimeMs) : DateTime.now();
      
      // Don't immediately revoke premium - let it expire naturally
      // Just update the subscription status
      await _storeSubscriptionRecord(userId, null, 'cancelled', eventTime, null, false);
      
      AppLogger().info('📋 Subscription cancelled for user $userId (will expire at natural end date)');
      return true;
      
    } catch (e) {
      AppLogger().error('Failed to handle subscription cancellation: $e');
      return false;
    }
  }

  /// Handle subscription expiration
  Future<bool> _handleSubscriptionExpiration(String userId, int? eventTimeMs) async {
    try {
      final eventTime = eventTimeMs != null ? DateTime.fromMillisecondsSinceEpoch(eventTimeMs) : DateTime.now();
      
      // Revoke premium status
      await _appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'isPremium': false,
          'premiumType': null,
          'premiumExpiry': null,
          'lastWebhookUpdate': DateTime.now().toIso8601String(),
        },
      );

      // Store expiration record
      await _storeSubscriptionRecord(userId, null, 'expired', eventTime, null, false);
      
      AppLogger().info('⏰ Subscription expired for user $userId');
      return true;
      
    } catch (e) {
      AppLogger().error('Failed to handle subscription expiration: $e');
      return false;
    }
  }

  /// Handle billing issues
  Future<bool> _handleBillingIssue(String userId, int? eventTimeMs) async {
    try {
      final eventTime = eventTimeMs != null ? DateTime.fromMillisecondsSinceEpoch(eventTimeMs) : DateTime.now();
      
      // Store billing issue record (don't revoke premium immediately - give grace period)
      await _storeSubscriptionRecord(userId, null, 'billing_issue', eventTime, null, false);
      
      AppLogger().warning('💳 Billing issue for user $userId');
      return true;
      
    } catch (e) {
      AppLogger().error('Failed to handle billing issue: $e');
      return false;
    }
  }

  /// Handle subscriber alias (user ID changes)
  Future<bool> _handleSubscriberAlias(Map<String, dynamic> event) async {
    try {
      final originalAppUserId = event['original_app_user_id'] as String?;
      final newAppUserId = event['new_app_user_id'] as String?;
      
      if (originalAppUserId == null || newAppUserId == null) {
        AppLogger().warning('Webhook missing user IDs for alias');
        return false;
      }

      // Store alias record for tracking
      await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'user_aliases',
        documentId: 'unique()',
        data: {
          'originalUserId': originalAppUserId,
          'newUserId': newAppUserId,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger().info('🔄 Subscriber alias: $originalAppUserId -> $newAppUserId');
      return true;
      
    } catch (e) {
      AppLogger().error('Failed to handle subscriber alias: $e');
      return false;
    }
  }

  /// Store subscription record for history/audit
  Future<void> _storeSubscriptionRecord(
    String userId,
    String? productId,
    String status,
    DateTime eventTime,
    DateTime? expiryDate,
    bool isTest,
  ) async {
    try {
      await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'subscription_records',
        documentId: 'unique()',
        data: {
          'userId': userId,
          'productId': productId,
          'status': status, // active, cancelled, expired, billing_issue
          'eventTime': eventTime.toIso8601String(),
          'expiryDate': expiryDate?.toIso8601String(),
          'isTestSubscription': isTest,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      AppLogger().warning('Failed to store subscription record: $e');
      // Don't fail the main process
    }
  }

  /// Clean up expired test subscriptions (for maintenance)
  Future<void> cleanupExpiredTestSubscriptions() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      
      // This would typically be done via a scheduled function
      // For now, just log that it should be done
      AppLogger().info('🧹 Cleanup needed for test subscriptions older than ${cutoffDate.toIso8601String()}');
      
    } catch (e) {
      AppLogger().error('Failed to cleanup test subscriptions: $e');
    }
  }
}