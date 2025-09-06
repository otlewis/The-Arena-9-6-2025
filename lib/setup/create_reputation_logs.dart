import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import 'package:appwrite/appwrite.dart';

/// Creates the reputation_logs collection using the existing AppwriteService
class ReputationLogsCollectionSetup {
  static final AppwriteService _appwrite = AppwriteService();

  static Future<void> createCollection() async {
    try {
      AppLogger().info('🏗️ Creating reputation_logs collection...');
      
      // Create the collection
      await _appwrite.databases.createCollection(
        databaseId: 'arena_db',
        collectionId: 'reputation_logs',
        name: 'Reputation Logs',
        permissions: [
          Permission.read(Role.any()),
          Permission.create(Role.users()),
          Permission.update(Role.users()),
          Permission.delete(Role.users()),
        ],
        documentSecurity: true,
      );
      
      AppLogger().info('✅ Collection created successfully');
      
      // Wait a moment for collection to be ready
      await Future.delayed(const Duration(seconds: 3));
      
      // Create attributes
      await _createAttributes();
      
      // Wait for attributes to be ready
      AppLogger().info('⏳ Waiting for attributes to be ready...');
      await Future.delayed(const Duration(seconds: 15));
      
      // Create indexes
      await _createIndexes();
      
      AppLogger().info('🎉 reputation_logs collection setup completed!');
      
    } catch (e) {
      AppLogger().error('❌ Failed to create reputation_logs collection: $e');
      rethrow;
    }
  }
  
  static Future<void> _createAttributes() async {
    final attributes = [
      {'key': 'userId', 'type': 'string', 'size': 255},
      {'key': 'pointsChange', 'type': 'integer'},
      {'key': 'newTotal', 'type': 'integer'},
      {'key': 'reason', 'type': 'string', 'size': 500},
      {'key': 'timestamp', 'type': 'datetime'},
    ];
    
    for (var attr in attributes) {
      try {
        AppLogger().info('Creating ${attr['key']} attribute...');
        
        if (attr['type'] == 'string') {
          await _appwrite.databases.createStringAttribute(
            databaseId: 'arena_db',
            collectionId: 'reputation_logs',
            key: attr['key'],
            size: attr['size'],
            required: true,
          );
        } else if (attr['type'] == 'integer') {
          await _appwrite.databases.createIntegerAttribute(
            databaseId: 'arena_db',
            collectionId: 'reputation_logs',
            key: attr['key'],
            required: true,
          );
        } else if (attr['type'] == 'datetime') {
          await _appwrite.databases.createDatetimeAttribute(
            databaseId: 'arena_db',
            collectionId: 'reputation_logs',
            key: attr['key'],
            required: true,
          );
        }
        
        AppLogger().info('✅ Created ${attr['key']} attribute');
        await Future.delayed(const Duration(seconds: 2));
        
      } catch (e) {
        AppLogger().error('❌ Failed to create ${attr['key']} attribute: $e');
      }
    }
  }
  
  static Future<void> _createIndexes() async {
    final indexes = [
      {'key': 'userId_index', 'attributes': ['userId']},
      {'key': 'timestamp_index', 'attributes': ['timestamp']},
      {'key': 'userId_timestamp_index', 'attributes': ['userId', 'timestamp']},
    ];
    
    for (var index in indexes) {
      try {
        AppLogger().info('Creating ${index['key']} index...');
        
        await _appwrite.databases.createIndex(
          databaseId: 'arena_db',
          collectionId: 'reputation_logs',
          key: index['key'],
          type: 'key',
          attributes: index['attributes'],
        );
        
        AppLogger().info('✅ Created ${index['key']} index');
        await Future.delayed(const Duration(seconds: 2));
        
      } catch (e) {
        AppLogger().error('❌ Failed to create ${index['key']} index: $e');
      }
    }
  }
}