import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:appwrite/appwrite.dart';

/// RevenueCat Webhook Handler Server
/// Deploy this to your server to handle RevenueCat webhook events
/// 
/// Environment Variables Required:
/// - APPWRITE_ENDPOINT: Your Appwrite endpoint
/// - APPWRITE_PROJECT_ID: Your Appwrite project ID  
/// - APPWRITE_API_KEY: API key with database write permissions
/// - WEBHOOK_SECRET: Secret key for webhook authentication (optional but recommended)
/// - PORT: Server port (default 8080)

class WebhookServer {
  final Client appwriteClient;
  final Databases databases;
  final String? webhookSecret;
  
  static const String databaseId = 'arena_db';

  WebhookServer()
      : appwriteClient = Client()
          ..setEndpoint(Platform.environment['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1')
          ..setProject(Platform.environment['APPWRITE_PROJECT_ID'] ?? '')
          ..setKey(Platform.environment['APPWRITE_API_KEY'] ?? ''),
        databases = Databases(Client()
          ..setEndpoint(Platform.environment['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1')
          ..setProject(Platform.environment['APPWRITE_PROJECT_ID'] ?? '')
          ..setKey(Platform.environment['APPWRITE_API_KEY'] ?? '')),
        webhookSecret = Platform.environment['WEBHOOK_SECRET'];

  Router get router {
    final router = Router();
    
    // Health check endpoint
    router.get('/health', (Request request) {
      return Response.ok(jsonEncode({'status': 'healthy', 'service': 'arena-webhook-handler'}));
    });
    
    // RevenueCat webhook endpoint
    router.post('/webhooks/revenuecat', handleRevenueCatWebhook);
    
    // Test endpoint (remove in production)
    router.get('/test', (Request request) {
      return Response.ok('Webhook handler is running!');
    });
    
    return router;
  }

  /// Handle RevenueCat webhook
  Future<Response> handleRevenueCatWebhook(Request request) async {
    try {
      // Verify webhook secret if configured
      if (webhookSecret != null) {
        final authHeader = request.headers['authorization'];
        if (authHeader != 'Bearer $webhookSecret') {
          print('❌ Webhook authentication failed');
          return Response.unauthorized('Invalid authorization');
        }
      }

      // Parse webhook payload
      final body = await request.readAsString();
      final payload = jsonDecode(body) as Map<String, dynamic>;
      
      print('📨 Received webhook: ${payload['event_type']}');
      
      // Process the webhook
      final success = await processWebhook(payload);
      
      if (success) {
        return Response.ok(jsonEncode({'status': 'success'}));
      } else {
        return Response.internalServerError(
          body: jsonEncode({'status': 'error', 'message': 'Failed to process webhook'}),
        );
      }
      
    } catch (e) {
      print('❌ Webhook handler error: $e');
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
      );
    }
  }

  /// Process the webhook payload
  Future<bool> processWebhook(Map<String, dynamic> payload) async {
    try {
      final eventType = payload['event']['type'] as String?;
      final event = payload['event'] as Map<String, dynamic>;
      
      // Extract user and subscription info
      final appUserId = event['app_user_id'] as String?;
      final productId = event['product_id'] as String?;
      final eventTimeMs = event['event_timestamp_ms'] as int?;
      final environment = event['environment'] as String?; // 'SANDBOX' or 'PRODUCTION'
      
      if (appUserId == null) {
        print('⚠️ Webhook missing app_user_id');
        return false;
      }

      // Store webhook event for audit trail
      await storeWebhookEvent(eventType ?? 'unknown', payload, appUserId);

      // Process different event types
      switch (eventType) {
        case 'INITIAL_PURCHASE':
        case 'RENEWAL':
        case 'PRODUCT_CHANGE':
          return await handleSubscriptionActivation(appUserId, productId, environment, eventTimeMs);
          
        case 'CANCELLATION':
          return await handleSubscriptionCancellation(appUserId, eventTimeMs);
          
        case 'EXPIRATION':
          return await handleSubscriptionExpiration(appUserId, eventTimeMs);
          
        case 'BILLING_ISSUE':
          return await handleBillingIssue(appUserId, eventTimeMs);
          
        case 'SUBSCRIBER_ALIAS':
          return await handleSubscriberAlias(event);
          
        default:
          print('ℹ️ Unhandled webhook event type: $eventType');
          return true; // Don't fail for unknown events
      }
      
    } catch (e) {
      print('❌ Failed to process webhook: $e');
      return false;
    }
  }

  /// Store webhook event for audit trail
  Future<void> storeWebhookEvent(String eventType, Map<String, dynamic> payload, String userId) async {
    try {
      await databases.createDocument(
        databaseId: databaseId,
        collectionId: 'webhook_events',
        documentId: ID.unique(),
        data: {
          'eventType': eventType,
          'userId': userId,
          'payload': jsonEncode(payload),
          'processedAt': DateTime.now().toIso8601String(),
          'source': 'revenuecat',
        },
      );
      print('  ✓ Webhook event stored');
    } catch (e) {
      print('  ⚠️ Failed to store webhook event: $e');
    }
  }

  /// Handle subscription activation
  Future<bool> handleSubscriptionActivation(String userId, String? productId, String? environment, int? eventTimeMs) async {
    try {
      final isTestSubscription = environment == 'SANDBOX';
      final eventTime = eventTimeMs != null 
          ? DateTime.fromMillisecondsSinceEpoch(eventTimeMs) 
          : DateTime.now();
      
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
      await databases.updateDocument(
        databaseId: databaseId,
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
      await databases.createDocument(
        databaseId: databaseId,
        collectionId: 'subscription_records',
        documentId: ID.unique(),
        data: {
          'userId': userId,
          'productId': productId,
          'status': 'active',
          'eventTime': eventTime.toIso8601String(),
          'expiryDate': expiryDate.toIso8601String(),
          'isTestSubscription': isTestSubscription,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      
      print('  ✅ Subscription activated for user $userId');
      return true;
      
    } catch (e) {
      print('  ❌ Failed to handle subscription activation: $e');
      return false;
    }
  }

  /// Handle subscription cancellation
  Future<bool> handleSubscriptionCancellation(String userId, int? eventTimeMs) async {
    try {
      final eventTime = eventTimeMs != null 
          ? DateTime.fromMillisecondsSinceEpoch(eventTimeMs) 
          : DateTime.now();
      
      // Store cancellation record (don't revoke premium immediately)
      await databases.createDocument(
        databaseId: databaseId,
        collectionId: 'subscription_records',
        documentId: ID.unique(),
        data: {
          'userId': userId,
          'status': 'cancelled',
          'eventTime': eventTime.toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      
      print('  📋 Subscription cancelled for user $userId');
      return true;
      
    } catch (e) {
      print('  ❌ Failed to handle cancellation: $e');
      return false;
    }
  }

  /// Handle subscription expiration
  Future<bool> handleSubscriptionExpiration(String userId, int? eventTimeMs) async {
    try {
      // Revoke premium status
      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: 'users',
        documentId: userId,
        data: {
          'isPremium': false,
          'premiumType': null,
          'premiumExpiry': null,
          'lastWebhookUpdate': DateTime.now().toIso8601String(),
        },
      );
      
      print('  ⏰ Subscription expired for user $userId');
      return true;
      
    } catch (e) {
      print('  ❌ Failed to handle expiration: $e');
      return false;
    }
  }

  /// Handle billing issues
  Future<bool> handleBillingIssue(String userId, int? eventTimeMs) async {
    try {
      final eventTime = eventTimeMs != null 
          ? DateTime.fromMillisecondsSinceEpoch(eventTimeMs) 
          : DateTime.now();
      
      // Store billing issue record
      await databases.createDocument(
        databaseId: databaseId,
        collectionId: 'subscription_records',
        documentId: ID.unique(),
        data: {
          'userId': userId,
          'status': 'billing_issue',
          'eventTime': eventTime.toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      
      print('  💳 Billing issue for user $userId');
      return true;
      
    } catch (e) {
      print('  ❌ Failed to handle billing issue: $e');
      return false;
    }
  }

  /// Handle subscriber alias
  Future<bool> handleSubscriberAlias(Map<String, dynamic> event) async {
    try {
      final originalAppUserId = event['original_app_user_id'] as String?;
      final newAppUserId = event['new_app_user_id'] as String?;
      
      if (originalAppUserId == null || newAppUserId == null) {
        return false;
      }

      await databases.createDocument(
        databaseId: databaseId,
        collectionId: 'user_aliases',
        documentId: ID.unique(),
        data: {
          'originalUserId': originalAppUserId,
          'newUserId': newAppUserId,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      
      print('  🔄 Subscriber alias: $originalAppUserId -> $newAppUserId');
      return true;
      
    } catch (e) {
      print('  ❌ Failed to handle alias: $e');
      return false;
    }
  }
}

void main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = WebhookServer();
  
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(server.router);
  
  final httpServer = await shelf_io.serve(handler, '0.0.0.0', port);
  
  print('🚀 Arena Webhook Handler running on port ${httpServer.port}');
  print('📝 Endpoints:');
  print('  - Health Check: http://localhost:${httpServer.port}/health');
  print('  - RevenueCat Webhook: http://localhost:${httpServer.port}/webhooks/revenuecat');
  print('  - Test Endpoint: http://localhost:${httpServer.port}/test');
  print('\n⚙️  Environment:');
  print('  - APPWRITE_ENDPOINT: ${Platform.environment['APPWRITE_ENDPOINT'] ?? 'Not set'}');
  print('  - APPWRITE_PROJECT_ID: ${Platform.environment['APPWRITE_PROJECT_ID'] ?? 'Not set'}');
  print('  - WEBHOOK_SECRET: ${Platform.environment['WEBHOOK_SECRET'] != null ? 'Set' : 'Not set'}');
}