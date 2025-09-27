import 'package:appwrite/appwrite.dart';

/// Script to create store configuration collections in Appwrite
/// Run this once to set up the dynamic store system
/// 
/// Collections created:
/// - store_config: Main store configuration and metadata
/// - store_subscriptions: Dynamic subscription plans (teen, adult, etc.)  
/// - store_coins: Arena Coins packages
/// - store_events: Special events and tournaments

class StoreCollectionSetup {
  static Future<void> createCollections() async {
    // Initialize Appwrite client
    final client = Client()
        .setEndpoint('https://cloud.appwrite.io/v1') // Your Appwrite endpoint
        .setProject('683a37a8003719978879'); // Your project ID

    final databases = Databases(client);
    const databaseId = 'arena_db';

    try {
      print('🛒 Setting up store collections...');

      // 1. Store Config Collection
      await _createStoreConfigCollection(databases, databaseId);
      
      // 2. Store Subscriptions Collection  
      await _createStoreSubscriptionsCollection(databases, databaseId);
      
      // 3. Store Coins Collection
      await _createStoreCoinsCollection(databases, databaseId);
      
      // 4. Store Events Collection
      await _createStoreEventsCollection(databases, databaseId);

      print('✅ All store collections created successfully!');
      print('');
      print('Next steps:');
      print('1. Add initial data using the Appwrite console');
      print('2. Update Flutter app to use dynamic store config');
      
    } catch (e) {
      print('❌ Error creating collections: $e');
    }
  }

  static Future<void> _createStoreConfigCollection(
    Databases databases, 
    String databaseId
  ) async {
    try {
      print('📋 Creating store_config collection...');
      
      await databases.createCollection(
        databaseId: databaseId,
        collectionId: 'store_config',
        name: 'Store Configuration',
        permissions: [
          Permission.read(Role.any()),
          Permission.write(Role.users()),
        ],
      );

      // Add attributes
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_config',
        key: 'config_key',
        size: 50,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_config',
        key: 'config_value',
        size: 5000,
        required: true,
      );
      
      await databases.createBooleanAttribute(
        databaseId: databaseId,
        collectionId: 'store_config',
        key: 'is_active',
        required: true,
        xdefault: true,
      );

      // Create indexes
      await databases.createIndex(
        databaseId: databaseId,
        collectionId: 'store_config',
        key: 'config_key_index',
        type: IndexType.key,
        attributes: ['config_key'],
        orders: [OrderType.asc],
      );

      print('✅ store_config collection created');
    } catch (e) {
      print('⚠️ store_config collection might already exist or error: $e');
    }
  }

  static Future<void> _createStoreSubscriptionsCollection(
    Databases databases, 
    String databaseId
  ) async {
    try {
      print('💰 Creating store_subscriptions collection...');
      
      await databases.createCollection(
        databaseId: databaseId,
        collectionId: 'store_subscriptions',
        name: 'Store Subscriptions',
        permissions: [
          Permission.read(Role.any()),
          Permission.write(Role.users()),
        ],
      );

      // Add attributes
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_subscriptions',
        key: 'subscription_id',
        size: 50,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_subscriptions',
        key: 'title',
        size: 100,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_subscriptions',
        key: 'price_display',
        size: 50,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_subscriptions',
        key: 'eligibility',
        size: 50,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_subscriptions',
        key: 'features',
        size: 2000,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_subscriptions',
        key: 'badge',
        size: 100,
        required: false,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_subscriptions',
        key: 'rc_product_id',
        size: 100,
        required: true,
      );
      
      await databases.createIntegerAttribute(
        databaseId: databaseId,
        collectionId: 'store_subscriptions',
        key: 'sort_order',
        required: true,
        xdefault: 0,
      );
      
      await databases.createBooleanAttribute(
        databaseId: databaseId,
        collectionId: 'store_subscriptions',
        key: 'is_active',
        required: true,
        xdefault: true,
      );

      // Create indexes
      await databases.createIndex(
        databaseId: databaseId,
        collectionId: 'store_subscriptions',
        key: 'subscription_id_index',
        type: IndexType.key,
        attributes: ['subscription_id'],
        orders: [OrderType.asc],
      );
      
      await databases.createIndex(
        databaseId: databaseId,
        collectionId: 'store_subscriptions',
        key: 'sort_order_index',
        type: IndexType.key,
        attributes: ['sort_order', 'is_active'],
        orders: [OrderType.asc, OrderType.desc],
      );

      print('✅ store_subscriptions collection created');
    } catch (e) {
      print('⚠️ store_subscriptions collection might already exist or error: $e');
    }
  }

  static Future<void> _createStoreCoinsCollection(
    Databases databases, 
    String databaseId
  ) async {
    try {
      print('🪙 Creating store_coins collection...');
      
      await databases.createCollection(
        databaseId: databaseId,
        collectionId: 'store_coins',
        name: 'Store Coins',
        permissions: [
          Permission.read(Role.any()),
          Permission.write(Role.users()),
        ],
      );

      // Add attributes
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_coins',
        key: 'coin_package_id',
        size: 50,
        required: true,
      );
      
      await databases.createIntegerAttribute(
        databaseId: databaseId,
        collectionId: 'store_coins',
        key: 'amount',
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_coins',
        key: 'price_display',
        size: 50,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_coins',
        key: 'badge',
        size: 100,
        required: false,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_coins',
        key: 'rc_product_id',
        size: 100,
        required: true,
      );
      
      await databases.createIntegerAttribute(
        databaseId: databaseId,
        collectionId: 'store_coins',
        key: 'sort_order',
        required: true,
        xdefault: 0,
      );
      
      await databases.createBooleanAttribute(
        databaseId: databaseId,
        collectionId: 'store_coins',
        key: 'is_active',
        required: true,
        xdefault: true,
      );

      // Create indexes
      await databases.createIndex(
        databaseId: databaseId,
        collectionId: 'store_coins',
        key: 'sort_order_index',
        type: IndexType.key,
        attributes: ['sort_order', 'is_active'],
        orders: [OrderType.asc, OrderType.desc],
      );

      print('✅ store_coins collection created');
    } catch (e) {
      print('⚠️ store_coins collection might already exist or error: $e');
    }
  }

  static Future<void> _createStoreEventsCollection(
    Databases databases, 
    String databaseId
  ) async {
    try {
      print('🎯 Creating store_events collection...');
      
      await databases.createCollection(
        databaseId: databaseId,
        collectionId: 'store_events',
        name: 'Store Events',
        permissions: [
          Permission.read(Role.any()),
          Permission.write(Role.users()),
        ],
      );

      // Add attributes
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_events',
        key: 'event_id',
        size: 50,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_events',
        key: 'title',
        size: 100,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_events',
        key: 'description',
        size: 500,
        required: false,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_events',
        key: 'price_display',
        size: 50,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_events',
        key: 'cta_text',
        size: 50,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'store_events',
        key: 'rc_product_id',
        size: 100,
        required: false,
      );
      
      await databases.createDatetimeAttribute(
        databaseId: databaseId,
        collectionId: 'store_events',
        key: 'start_date',
        required: false,
      );
      
      await databases.createDatetimeAttribute(
        databaseId: databaseId,
        collectionId: 'store_events',
        key: 'end_date',
        required: false,
      );
      
      await databases.createIntegerAttribute(
        databaseId: databaseId,
        collectionId: 'store_events',
        key: 'sort_order',
        required: true,
        xdefault: 0,
      );
      
      await databases.createBooleanAttribute(
        databaseId: databaseId,
        collectionId: 'store_events',
        key: 'is_active',
        required: true,
        xdefault: true,
      );

      // Create indexes
      await databases.createIndex(
        databaseId: databaseId,
        collectionId: 'store_events',
        key: 'active_events_index',
        type: IndexType.key,
        attributes: ['is_active', 'sort_order'],
        orders: [OrderType.desc, OrderType.asc],
      );

      print('✅ store_events collection created');
    } catch (e) {
      print('⚠️ store_events collection might already exist or error: $e');
    }
  }
}

// To run this script:
// dart lib/scripts/setup_store_collections.dart
void main() async {
  await StoreCollectionSetup.createCollections();
}