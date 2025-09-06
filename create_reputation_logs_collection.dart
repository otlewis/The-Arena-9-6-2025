import 'package:appwrite/appwrite.dart';

void main() async {
  // Initialize Appwrite client
  final client = Client()
    ..setEndpoint('https://cloud.appwrite.io/v1')
    ..setProject('683a37a8003719978879')
    ..setKey('standard_a2bb604b91b6e0ad49c4b8b3c0c59c83c9a7ee4ce4b2a784c9f05d9ad84c0fb5f3e8b05e8c4e8f79b3f5e8b05e8c4e8f79b3f5e8b05e8c4e8f79b3f5e8b05e8c4e8');

  final databases = Databases(client);
  
  try {
    print('Creating reputation_logs collection...');
    
    // Create the collection
    final collection = await databases.createCollection(
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
    
    print('✅ Collection created: ${collection.name}');
    
    // Create attributes
    print('Creating attributes...');
    
    // userId attribute
    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'userId',
      size: 255,
      required: true,
    );
    print('✅ Created userId attribute');
    
    // Wait a moment for attribute to be ready
    await Future.delayed(Duration(seconds: 2));
    
    // pointsChange attribute
    await databases.createIntegerAttribute(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'pointsChange',
      required: true,
    );
    print('✅ Created pointsChange attribute');
    
    await Future.delayed(Duration(seconds: 2));
    
    // newTotal attribute
    await databases.createIntegerAttribute(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'newTotal',
      required: true,
    );
    print('✅ Created newTotal attribute');
    
    await Future.delayed(Duration(seconds: 2));
    
    // reason attribute
    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'reason',
      size: 500,
      required: true,
    );
    print('✅ Created reason attribute');
    
    await Future.delayed(Duration(seconds: 2));
    
    // timestamp attribute
    await databases.createDatetimeAttribute(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'timestamp',
      required: true,
    );
    print('✅ Created timestamp attribute');
    
    // Wait for all attributes to be ready before creating indexes
    print('Waiting for attributes to be ready...');
    await Future.delayed(Duration(seconds: 10));
    
    // Create indexes
    print('Creating indexes...');
    
    // Index for userId
    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'userId_index',
      type: 'key',
      attributes: ['userId'],
    );
    print('✅ Created userId index');
    
    await Future.delayed(Duration(seconds: 2));
    
    // Index for timestamp
    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'timestamp_index',
      type: 'key',
      attributes: ['timestamp'],
    );
    print('✅ Created timestamp index');
    
    await Future.delayed(Duration(seconds: 2));
    
    // Compound index for userId + timestamp
    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'reputation_logs',
      key: 'userId_timestamp_index',
      type: 'key',
      attributes: ['userId', 'timestamp'],
    );
    print('✅ Created userId_timestamp compound index');
    
    print('\n🎉 reputation_logs collection created successfully!');
    print('Collection ID: reputation_logs');
    print('Attributes: userId, pointsChange, newTotal, reason, timestamp');
    print('Indexes: userId, timestamp, userId+timestamp');
    
  } catch (e) {
    print('❌ Error creating collection: $e');
  }
}