import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  // Initialize Appwrite client
  final client = Client()
    ..setEndpoint('https://cloud.appwrite.io/v1')
    ..setProject('683a37a8003719978879')
    ..setKey('standard_8f66fb71aaa2f50e3d5e3a2b67a3b8db42daee8f32e1e7dc03a4bafa4784d62b0d7fb1c7b37f8913af48db58b0e1a6d6f4acdb84bc2cd08b7fb7b93d1d35eae30e8a1ff7d35e1dc4e1e3fad48c0a2cb95a78d0a4de0df53acaf62b0c08bd2f3c');

  final databases = Databases(client);

  try {
    print('🎯 Creating arena_navigation_notifications collection...\n');

    // Create the collection
    try {
      await databases.createCollection(
        databaseId: 'arena_db',
        collectionId: 'arena_navigation_notifications',
        name: 'Arena Navigation Notifications',
        permissions: [
          Permission.read(Role.users()),
          Permission.create(Role.users()),
          Permission.update(Role.users()),
          Permission.delete(Role.users()),
        ],
      );
      print('✅ Collection created\n');
    } catch (e) {
      print('⚠️ Collection might already exist: $e\n');
    }

    // Add attributes
    print('📋 Adding attributes...\n');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'arena_navigation_notifications',
      key: 'userId',
      size: 255,
      required: true,
    );
    print('  ✅ Added userId attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'arena_navigation_notifications',
      key: 'type',
      size: 50,
      required: true,
    );
    print('  ✅ Added type attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'arena_navigation_notifications',
      key: 'arenaRoomId',
      size: 255,
      required: true,
    );
    print('  ✅ Added arenaRoomId attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'arena_navigation_notifications',
      key: 'challengeId',
      size: 255,
      required: false,
    );
    print('  ✅ Added challengeId attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'arena_navigation_notifications',
      key: 'status',
      size: 50,
      required: true,
      xdefault: 'pending',
    );
    print('  ✅ Added status attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'arena_navigation_notifications',
      key: 'topic',
      size: 500,
      required: false,
    );
    print('  ✅ Added topic attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'arena_navigation_notifications',
      key: 'description',
      size: 2000,
      required: false,
    );
    print('  ✅ Added description attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'arena_navigation_notifications',
      key: 'processedAt',
      size: 255,
      required: false,
    );
    print('  ✅ Added processedAt attribute');

    // Wait for attributes to be ready
    print('\n⏳ Waiting for attributes to be ready...');
    await Future.delayed(Duration(seconds: 3));

    // Create indexes
    print('\n📇 Creating indexes...\n');

    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'arena_navigation_notifications',
      key: 'userId_status_index',
      type: IndexType.key,
      attributes: ['userId', 'status'],
    );
    print('  ✅ Added userId+status index');

    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'arena_navigation_notifications',
      key: 'userId_index',
      type: IndexType.key,
      attributes: ['userId'],
    );
    print('  ✅ Added userId index');

    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'arena_navigation_notifications',
      key: 'createdAt_index',
      type: IndexType.key,
      attributes: ['\$createdAt'],
    );
    print('  ✅ Added createdAt index');

    print('\n🎉 Arena navigation notifications collection setup complete!\n');
    print('Collection details:');
    print('  - ID: arena_navigation_notifications');
    print('  - Database: arena_db');
    print('  - Purpose: Backend-driven navigation for arena challenges');
    print('\nAttributes:');
    print('  - userId: Who should navigate');
    print('  - type: Notification type (arena_ready, etc.)');
    print('  - arenaRoomId: Target arena room');
    print('  - challengeId: Related challenge (optional)');
    print('  - status: pending/processed/expired');
    print('  - topic: Challenge topic (optional)');
    print('  - description: Challenge description (optional)');
    print('  - processedAt: When notification was processed (optional)');

  } catch (e) {
    print('❌ Error: $e');
  }
}
