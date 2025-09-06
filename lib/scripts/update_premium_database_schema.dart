import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

/// Script to update Appwrite database schema for premium features and gift system
class PremiumDatabaseSchemaUpdater {
  static const String databaseId = 'arena_db';
  
  static Future<void> updateSchema() async {
    AppLogger().info('🔧 Starting premium database schema update...');
    
    final appwrite = AppwriteService();
    final databases = appwrite.databases;
    
    try {
      // Update users collection with premium fields
      await _addPremiumFieldsToUsers(databases);
      
      // Create gift-related collections
      await _createGiftCollections(databases);
      
      AppLogger().info('✅ Premium database schema update completed successfully!');
    } catch (e) {
      AppLogger().error('❌ Schema update failed: $e');
    }
  }
  
  static Future<void> _addPremiumFieldsToUsers(Databases databases) async {
    AppLogger().info('📝 Adding premium fields to users collection...');
    
    try {
      // Add isPremium boolean field
      await databases.createBooleanAttribute(
        databaseId: databaseId,
        collectionId: 'users',
        key: 'isPremium',
        required: false,
        default: false,
      );
      AppLogger().debug('✅ Added isPremium field');
      
      // Add premiumType string field
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'users',
        key: 'premiumType',
        size: 20,
        required: false,
      );
      AppLogger().debug('✅ Added premiumType field');
      
      // Add premiumExpiry datetime field
      await databases.createDatetimeAttribute(
        databaseId: databaseId,
        collectionId: 'users',
        key: 'premiumExpiry',
        required: false,
      );
      AppLogger().debug('✅ Added premiumExpiry field');
      
      // Add isTestSubscription boolean field
      await databases.createBooleanAttribute(
        databaseId: databaseId,
        collectionId: 'users',
        key: 'isTestSubscription',
        required: false,
        default: false,
      );
      AppLogger().debug('✅ Added isTestSubscription field');
      
      AppLogger().info('✅ Successfully added premium fields to users collection');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        AppLogger().info('ℹ️ Premium fields already exist in users collection');
      } else {
        AppLogger().error('❌ Failed to add premium fields: $e');
        rethrow;
      }
    }
  }
  
  static Future<void> _createGiftCollections(Databases databases) async {
    AppLogger().info('🎁 Creating gift collections...');
    
    // Create received_gifts collection
    await _createReceivedGiftsCollection(databases);
  }
  
  static Future<void> _createReceivedGiftsCollection(Databases databases) async {
    AppLogger().info('📦 Creating received_gifts collection...');
    
    try {
      // Create the collection
      await databases.createCollection(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        name: 'Received Gifts',
        permissions: [
          Permission.read(Role.user()),
          Permission.create(Role.user()),
          Permission.update(Role.user()),
          Permission.delete(Role.user()),
        ],
      );
      AppLogger().debug('✅ Created received_gifts collection');
      
      // Add attributes
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        key: 'giftId',
        size: 50,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        key: 'senderId',
        size: 50,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        key: 'senderName',
        size: 100,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        key: 'senderAvatar',
        size: 500,
        required: false,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        key: 'receiverId',
        size: 50,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        key: 'receiverName',
        size: 100,
        required: true,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        key: 'message',
        size: 200,
        required: false,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        key: 'roomId',
        size: 50,
        required: false,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        key: 'roomType',
        size: 30,
        required: false,
      );
      
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        key: 'roomName',
        size: 100,
        required: false,
      );
      
      await databases.createBooleanAttribute(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        key: 'isRead',
        required: true,
        default: false,
      );
      
      await databases.createBooleanAttribute(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        key: 'isNotified',
        required: true,
        default: false,
      );
      
      AppLogger().debug('✅ Added all attributes to received_gifts collection');
      
      // Create indexes for better query performance
      await databases.createIndex(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        key: 'receiverId_index',
        type: 'key',
        attributes: ['receiverId'],
      );
      
      await databases.createIndex(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        key: 'senderId_index',
        type: 'key',
        attributes: ['senderId'],
      );
      
      await databases.createIndex(
        databaseId: databaseId,
        collectionId: 'received_gifts',
        key: 'createdAt_index',
        type: 'key',
        attributes: ['\$createdAt'],
        orders: ['DESC'],
      );
      
      AppLogger().debug('✅ Created indexes for received_gifts collection');
      
      AppLogger().info('✅ Successfully created received_gifts collection');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        AppLogger().info('ℹ️ received_gifts collection already exists');
      } else {
        AppLogger().error('❌ Failed to create received_gifts collection: $e');
        rethrow;
      }
    }
  }
}

/// Main function to run the schema update
void main() async {
  await PremiumDatabaseSchemaUpdater.updateSchema();
}