// ⚠️ DEPRECATED SCRIPT - DO NOT USE ⚠️
// This script uses old Appwrite SDK methods that are no longer available in v18.0.0
// The methods setKey, createCollection, createStringAttribute, etc. have been removed
// Use REST API approach or wait for TablesDB support to be added to the Flutter SDK

/*
import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
// This script uses old Appwrite SDK methods that are no longer available in v18.0.0
// The methods setKey, createCollection, createStringAttribute, etc. have been removed
// Use REST API approach or wait for TablesDB support to be added to the Flutter SDK

// Simple console logger for scripts
void logInfo(String message) {
  if (kDebugMode || !kIsWeb) {
    debugPrint('INFO: $message');
  }
}

void logError(String message) {
  if (kDebugMode || !kIsWeb) {
    debugPrint('ERROR: $message');
  }
}

void logSuccess(String message) {
  if (kDebugMode || !kIsWeb) {
    debugPrint('SUCCESS: $message');
  }
}

void logWarning(String message) {
  if (kDebugMode || !kIsWeb) {
    debugPrint('WARNING: $message');
  }
}

/// Script to create all required Appwrite collections for the payment system
/// Run this once to set up your database for production payments
class SetupPaymentCollections {
  final Client client;
  final Databases databases;
  
  // IMPORTANT: Update these with your Appwrite instance details
  static const String endpoint = 'https://cloud.appwrite.io/v1'; // Your Appwrite endpoint
  static const String projectId = 'YOUR_PROJECT_ID'; // Your project ID
  static const String apiKey = 'YOUR_API_KEY'; // API key with database write permissions
  static const String databaseId = 'arena_db';

  SetupPaymentCollections()
      : client = Client()
          .setEndpoint(endpoint)
          .setProject(projectId)
          .setKey(apiKey),
        databases = Databases(Client()
          .setEndpoint(endpoint)
          .setProject(projectId)
          .setKey(apiKey));

  Future<void> run() async {
    logInfo('Setting up Arena payment collections...\n');
    
    try {
      // 1. Create feature_flags collection
      await createFeatureFlagsCollection();
      
      // 2. Create webhook_events collection
      await createWebhookEventsCollection();
      
      // 3. Create subscription_records collection
      await createSubscriptionRecordsCollection();
      
      // 4. Create user_aliases collection
      await createUserAliasesCollection();
      
      // 5. Update users collection
      await updateUsersCollection();
      
      // 6. Insert initial feature flags
      await insertInitialFeatureFlags();
      
      logSuccess('\nAll collections created successfully!');
      logInfo('Next steps:');
      logInfo('  1. Configure RevenueCat webhook URL to point to your server');
      logInfo('  2. Update RevenueCat API keys in revenue_cat_service.dart');
      logInfo('  3. Test sandbox purchases with TestFlight');
      
    } catch (e) {
      logError('Error setting up collections: $e');
      logError('Please check your Appwrite credentials and try again.');
    }
  }

  Future<void> createFeatureFlagsCollection() async {
    try {
      logInfo('Creating feature_flags collection...');
      
      // Note: Appwrite SDK methods are deprecated but TablesDB is not yet available
      await databases.createCollection(
        databaseId: databaseId,
        collectionId: 'feature_flags',
        name: 'Feature Flags',
        permissions: [
          Permission.read(Role.any()),
          Permission.write(Role.team('admin')),
        ],
      );

      // Create attributes
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'feature_flags',
        key: 'name',
        size: 255,
        required: true,
      );

      await databases.createBooleanAttribute(
        databaseId: databaseId,
        collectionId: 'feature_flags',
        key: 'enabled',
        required: true,
        defaultValue: false,
      );

      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'feature_flags',
        key: 'description',
        size: 500,
        required: false,
      );

      await databases.createDatetimeAttribute(
        databaseId: databaseId,
        collectionId: 'feature_flags',
        key: 'updatedAt',
        required: false,
      );

      // Create unique index on name
      await databases.createIndex(
        databaseId: databaseId,
        collectionId: 'feature_flags',
        key: 'name_unique',
        type: 'unique',
        attributes: ['name'],
      );

      logSuccess('feature_flags collection created');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        logWarning('feature_flags collection already exists');
      } else {
        throw e;
      }
    }
  }

  Future<void> createWebhookEventsCollection() async {
    try {
      logInfo('Creating webhook_events collection...');
      
      // Note: Appwrite SDK methods are deprecated but TablesDB is not yet available
      await databases.createCollection(
        databaseId: databaseId,
        collectionId: 'webhook_events',
        name: 'Webhook Events',
        permissions: [
          Permission.read(Role.team('admin')),
          Permission.write(Role.label('webhook')), // Only webhook service can write
        ],
      );

      // Create attributes
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'webhook_events',
        key: 'eventType',
        size: 100,
        required: true,
      );

      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'webhook_events',
        key: 'userId',
        size: 255,
        required: true,
      );

      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'webhook_events',
        key: 'payload',
        size: 10000, // Large enough for JSON payload
        required: true,
      );

      await databases.createDatetimeAttribute(
        databaseId: databaseId,
        collectionId: 'webhook_events',
        key: 'processedAt',
        required: true,
      );

      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'webhook_events',
        key: 'source',
        size: 50,
        required: true,
        defaultValue: 'revenuecat',
      );

      // Create indexes
      await databases.createIndex(
        databaseId: databaseId,
        collectionId: 'webhook_events',
        key: 'user_event_time',
        type: 'key',
        attributes: ['userId', 'eventType', 'processedAt'],
      );

      logSuccess('webhook_events collection created');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        logWarning('webhook_events collection already exists');
      } else {
        throw e;
      }
    }
  }

  Future<void> createSubscriptionRecordsCollection() async {
    try {
      logInfo('Creating subscription_records collection...');
      
      // Note: Appwrite SDK methods are deprecated but TablesDB is not yet available
      await databases.createCollection(
        databaseId: databaseId,
        collectionId: 'subscription_records',
        name: 'Subscription Records',
        permissions: [
          Permission.read(Role.users()),
          Permission.write(Role.label('webhook')),
        ],
      );

      // Create attributes
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'subscription_records',
        key: 'userId',
        size: 255,
        required: true,
      );

      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'subscription_records',
        key: 'productId',
        size: 255,
        required: false,
      );

      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'subscription_records',
        key: 'status',
        size: 50,
        required: true,
      );

      await databases.createDatetimeAttribute(
        databaseId: databaseId,
        collectionId: 'subscription_records',
        key: 'eventTime',
        required: true,
      );

      await databases.createDatetimeAttribute(
        databaseId: databaseId,
        collectionId: 'subscription_records',
        key: 'expiryDate',
        required: false,
      );

      await databases.createBooleanAttribute(
        databaseId: databaseId,
        collectionId: 'subscription_records',
        key: 'isTestSubscription',
        required: true,
        defaultValue: false,
      );

      await databases.createDatetimeAttribute(
        databaseId: databaseId,
        collectionId: 'subscription_records',
        key: 'createdAt',
        required: true,
      );

      // Create indexes
      await databases.createIndex(
        databaseId: databaseId,
        collectionId: 'subscription_records',
        key: 'user_status',
        type: 'key',
        attributes: ['userId', 'status', 'createdAt'],
      );

      logSuccess('subscription_records collection created');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        logWarning('subscription_records collection already exists');
      } else {
        throw e;
      }
    }
  }

  Future<void> createUserAliasesCollection() async {
    try {
      logInfo('Creating user_aliases collection...');
      
      // Note: Appwrite SDK methods are deprecated but TablesDB is not yet available
      await databases.createCollection(
        databaseId: databaseId,
        collectionId: 'user_aliases',
        name: 'User Aliases',
        permissions: [
          Permission.read(Role.team('admin')),
          Permission.write(Role.label('webhook')),
        ],
      );

      // Create attributes
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'user_aliases',
        key: 'originalUserId',
        size: 255,
        required: true,
      );

      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'user_aliases',
        key: 'newUserId',
        size: 255,
        required: true,
      );

      await databases.createDatetimeAttribute(
        databaseId: databaseId,
        collectionId: 'user_aliases',
        key: 'createdAt',
        required: true,
      );

      // Create indexes
      await databases.createIndex(
        databaseId: databaseId,
        collectionId: 'user_aliases',
        key: 'original_user',
        type: 'unique',
        attributes: ['originalUserId'],
      );

      await databases.createIndex(
        databaseId: databaseId,
        collectionId: 'user_aliases',
        key: 'new_user',
        type: 'key',
        attributes: ['newUserId'],
      );

      logSuccess('user_aliases collection created');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        logWarning('user_aliases collection already exists');
      } else {
        throw e;
      }
    }
  }

  Future<void> updateUsersCollection() async {
    try {
      logInfo('Updating users collection with premium fields...');
      
      // Add premium-related attributes to existing users collection
      // Note: These might already exist, so we'll handle errors gracefully
      
      try {
        await databases.createBooleanAttribute(
          databaseId: databaseId,
          collectionId: 'users',
          key: 'isPremium',
          required: false,
          defaultValue: false,
        );
        logSuccess('Added isPremium field');
      } catch (e) {
        logWarning('isPremium field already exists');
      }

      try {
        await databases.createStringAttribute(
          databaseId: databaseId,
          collectionId: 'users',
          key: 'premiumType',
          size: 50,
          required: false,
        );
        logSuccess('Added premiumType field');
      } catch (e) {
        logWarning('premiumType field already exists');
      }

      try {
        await databases.createDatetimeAttribute(
          databaseId: databaseId,
          collectionId: 'users',
          key: 'premiumExpiry',
          required: false,
        );
        logSuccess('Added premiumExpiry field');
      } catch (e) {
        logWarning('premiumExpiry field already exists');
      }

      try {
        await databases.createBooleanAttribute(
          databaseId: databaseId,
          collectionId: 'users',
          key: 'isTestSubscription',
          required: false,
          defaultValue: false,
        );
        logSuccess('Added isTestSubscription field');
      } catch (e) {
        logWarning('isTestSubscription field already exists');
      }

      try {
        await databases.createDatetimeAttribute(
          databaseId: databaseId,
          collectionId: 'users',
          key: 'lastWebhookUpdate',
          required: false,
        );
        logSuccess('Added lastWebhookUpdate field');
      } catch (e) {
        logWarning('lastWebhookUpdate field already exists');
      }

      // Create index for premium users
      try {
        await databases.createIndex(
          databaseId: databaseId,
          collectionId: 'users',
          key: 'premium_status',
          type: 'key',
          attributes: ['isPremium', 'premiumExpiry'],
        );
        logSuccess('Added premium_status index');
      } catch (e) {
        logWarning('premium_status index already exists');
      }

    } catch (e) {
      logError('Error updating users collection: $e');
    }
  }

  Future<void> insertInitialFeatureFlags() async {
    try {
      logInfo('\nInserting initial feature flags...');
      
      final flags = [
        {
          'name': 'payments_enabled',
          'enabled': false, // Start with payments disabled
          'description': 'Master kill switch for payment system',
          'updatedAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'premium_enabled',
          'enabled': true,
          'description': 'Enable premium features for subscribers',
          'updatedAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'gifts_enabled',
          'enabled': true,
          'description': 'Enable gift system',
          'updatedAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'challenges_enabled',
          'enabled': true,
          'description': 'Enable challenge system',
          'updatedAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'sandbox_enabled',
          'enabled': true,
          'description': 'Allow sandbox/test purchases',
          'updatedAt': DateTime.now().toIso8601String(),
        },
      ];

      for (final flag in flags) {
        try {
          // Note: createDocument is deprecated but TablesDB is not yet available
          await databases.createDocument(
            databaseId: databaseId,
            collectionId: 'feature_flags',
            documentId: ID.unique(),
            data: flag,
          );
          logSuccess('Created flag: ${flag['name']} = ${flag['enabled']}');
        } catch (e) {
          logWarning('Flag ${flag['name']} might already exist');
        }
      }
      
    } catch (e) {
      logError('Error inserting feature flags: $e');
    }
  }
}

// Run the setup
void main() async {
  final setup = SetupPaymentCollections();
  await setup.run();
}
*/

import 'dart:developer' as developer;

void main() {
  developer.log('⚠️ This deprecated script is disabled to prevent compilation errors.', name: 'SetupPaymentCollections');
  developer.log('Use the REST API or wait for TablesDB support in the Flutter SDK.', name: 'SetupPaymentCollections');
}