import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

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
          ..setEndpoint(endpoint)
          ..setProject(projectId)
          ..setKey(apiKey),
        databases = Databases(Client()
          ..setEndpoint(endpoint)
          ..setProject(projectId)
          ..setKey(apiKey));

  Future<void> run() async {
    print('🚀 Setting up Arena payment collections...\n');
    
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
      
      print('\n✅ All collections created successfully!');
      print('📝 Next steps:');
      print('  1. Configure RevenueCat webhook URL to point to your server');
      print('  2. Update RevenueCat API keys in revenue_cat_service.dart');
      print('  3. Test sandbox purchases with TestFlight');
      
    } catch (e) {
      print('❌ Error setting up collections: $e');
      print('Please check your Appwrite credentials and try again.');
    }
  }

  Future<void> createFeatureFlagsCollection() async {
    try {
      print('📌 Creating feature_flags collection...');
      
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

      print('  ✓ feature_flags collection created');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        print('  ⚠️  feature_flags collection already exists');
      } else {
        throw e;
      }
    }
  }

  Future<void> createWebhookEventsCollection() async {
    try {
      print('📌 Creating webhook_events collection...');
      
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

      print('  ✓ webhook_events collection created');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        print('  ⚠️  webhook_events collection already exists');
      } else {
        throw e;
      }
    }
  }

  Future<void> createSubscriptionRecordsCollection() async {
    try {
      print('📌 Creating subscription_records collection...');
      
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

      print('  ✓ subscription_records collection created');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        print('  ⚠️  subscription_records collection already exists');
      } else {
        throw e;
      }
    }
  }

  Future<void> createUserAliasesCollection() async {
    try {
      print('📌 Creating user_aliases collection...');
      
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

      print('  ✓ user_aliases collection created');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        print('  ⚠️  user_aliases collection already exists');
      } else {
        throw e;
      }
    }
  }

  Future<void> updateUsersCollection() async {
    try {
      print('📌 Updating users collection with premium fields...');
      
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
        print('  ✓ Added isPremium field');
      } catch (e) {
        print('  ⚠️  isPremium field already exists');
      }

      try {
        await databases.createStringAttribute(
          databaseId: databaseId,
          collectionId: 'users',
          key: 'premiumType',
          size: 50,
          required: false,
        );
        print('  ✓ Added premiumType field');
      } catch (e) {
        print('  ⚠️  premiumType field already exists');
      }

      try {
        await databases.createDatetimeAttribute(
          databaseId: databaseId,
          collectionId: 'users',
          key: 'premiumExpiry',
          required: false,
        );
        print('  ✓ Added premiumExpiry field');
      } catch (e) {
        print('  ⚠️  premiumExpiry field already exists');
      }

      try {
        await databases.createBooleanAttribute(
          databaseId: databaseId,
          collectionId: 'users',
          key: 'isTestSubscription',
          required: false,
          defaultValue: false,
        );
        print('  ✓ Added isTestSubscription field');
      } catch (e) {
        print('  ⚠️  isTestSubscription field already exists');
      }

      try {
        await databases.createDatetimeAttribute(
          databaseId: databaseId,
          collectionId: 'users',
          key: 'lastWebhookUpdate',
          required: false,
        );
        print('  ✓ Added lastWebhookUpdate field');
      } catch (e) {
        print('  ⚠️  lastWebhookUpdate field already exists');
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
        print('  ✓ Added premium_status index');
      } catch (e) {
        print('  ⚠️  premium_status index already exists');
      }

    } catch (e) {
      print('  ❌ Error updating users collection: $e');
    }
  }

  Future<void> insertInitialFeatureFlags() async {
    try {
      print('\n📌 Inserting initial feature flags...');
      
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
          await databases.createDocument(
            databaseId: databaseId,
            collectionId: 'feature_flags',
            documentId: ID.unique(),
            data: flag,
          );
          print('  ✓ Created flag: ${flag['name']} = ${flag['enabled']}');
        } catch (e) {
          print('  ⚠️  Flag ${flag['name']} might already exist');
        }
      }
      
    } catch (e) {
      print('  ❌ Error inserting feature flags: $e');
    }
  }
}

// Run the setup
void main() async {
  final setup = SetupPaymentCollections();
  await setup.run();
}