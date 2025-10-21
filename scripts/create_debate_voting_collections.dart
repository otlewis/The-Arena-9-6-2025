import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  // Initialize Appwrite client
  final client = Client()
    ..setEndpoint('https://cloud.appwrite.io/v1')
    ..setProject('683a37a8003719978879')
    ..setKey('standard_8f66fb71aaa2f50e3d5e3a2b67a3b8db42daee8f32e1e7dc03a4bafa4784d62b0d7fb1c7b37f8913af48db58b0e1a6d6f4acdb84bc2cd08b7fb7b93d1d35eae30e8a1ff7d35e1dc4e1e3fad48c0a2cb95a78d0a4de0df53acaf62b0c08bd2f3c');

  final databases = Databases(client);

  try {
    print('🗳️ Creating debate voting collections...');

    // 1. Create debate_voting_sessions collection
    print('\n📋 Creating debate_voting_sessions collection...');
    try {
      await databases.createCollection(
        databaseId: 'arena_db',
        collectionId: 'debate_voting_sessions',
        name: 'Debate Voting Sessions',
        permissions: [
          Permission.read(Role.users()),
          Permission.create(Role.users()),
          Permission.update(Role.users()),
          Permission.delete(Role.users()),
        ],
      );
      print('✅ Collection created');

      // Add attributes
      await databases.createStringAttribute(
        databaseId: 'arena_db',
        collectionId: 'debate_voting_sessions',
        key: 'roomId',
        size: 255,
        required: true,
      );
      print('  ✅ Added roomId attribute');

      await databases.createStringAttribute(
        databaseId: 'arena_db',
        collectionId: 'debate_voting_sessions',
        key: 'status',
        size: 50,
        required: true,
        xdefault: 'open',
      );
      print('  ✅ Added status attribute');

      await databases.createStringAttribute(
        databaseId: 'arena_db',
        collectionId: 'debate_voting_sessions',
        key: 'openedBy',
        size: 255,
        required: true,
      );
      print('  ✅ Added openedBy attribute');

      await databases.createStringAttribute(
        databaseId: 'arena_db',
        collectionId: 'debate_voting_sessions',
        key: 'openedAt',
        size: 255,
        required: true,
      );
      print('  ✅ Added openedAt attribute');

      await databases.createStringAttribute(
        databaseId: 'arena_db',
        collectionId: 'debate_voting_sessions',
        key: 'closedAt',
        size: 255,
        required: false,
      );
      print('  ✅ Added closedAt attribute');

      // Create indexes
      await Future.delayed(Duration(seconds: 2)); // Wait for attributes to be ready

      await databases.createIndex(
        databaseId: 'arena_db',
        collectionId: 'debate_voting_sessions',
        key: 'roomId_index',
        type: IndexType.key,
        attributes: ['roomId'],
      );
      print('  ✅ Added roomId index');

      await databases.createIndex(
        databaseId: 'arena_db',
        collectionId: 'debate_voting_sessions',
        key: 'status_index',
        type: IndexType.key,
        attributes: ['status'],
      );
      print('  ✅ Added status index');

    } catch (e) {
      print('⚠️ debate_voting_sessions collection might already exist: $e');
    }

    // 2. Create debate_votes collection
    print('\n📋 Creating debate_votes collection...');
    try {
      await databases.createCollection(
        databaseId: 'arena_db',
        collectionId: 'debate_votes',
        name: 'Debate Votes',
        permissions: [
          Permission.read(Role.users()),
          Permission.create(Role.users()),
          Permission.update(Role.users()),
          Permission.delete(Role.users()),
        ],
      );
      print('✅ Collection created');

      // Add attributes
      await databases.createStringAttribute(
        databaseId: 'arena_db',
        collectionId: 'debate_votes',
        key: 'sessionId',
        size: 255,
        required: true,
      );
      print('  ✅ Added sessionId attribute');

      await databases.createStringAttribute(
        databaseId: 'arena_db',
        collectionId: 'debate_votes',
        key: 'roomId',
        size: 255,
        required: true,
      );
      print('  ✅ Added roomId attribute');

      await databases.createStringAttribute(
        databaseId: 'arena_db',
        collectionId: 'debate_votes',
        key: 'userId',
        size: 255,
        required: true,
      );
      print('  ✅ Added userId attribute');

      await databases.createStringAttribute(
        databaseId: 'arena_db',
        collectionId: 'debate_votes',
        key: 'vote',
        size: 50,
        required: true,
      );
      print('  ✅ Added vote attribute');

      await databases.createStringAttribute(
        databaseId: 'arena_db',
        collectionId: 'debate_votes',
        key: 'votedAt',
        size: 255,
        required: true,
      );
      print('  ✅ Added votedAt attribute');

      await databases.createStringAttribute(
        databaseId: 'arena_db',
        collectionId: 'debate_votes',
        key: 'updatedAt',
        size: 255,
        required: true,
      );
      print('  ✅ Added updatedAt attribute');

      // Create indexes
      await Future.delayed(Duration(seconds: 2)); // Wait for attributes to be ready

      await databases.createIndex(
        databaseId: 'arena_db',
        collectionId: 'debate_votes',
        key: 'sessionId_index',
        type: IndexType.key,
        attributes: ['sessionId'],
      );
      print('  ✅ Added sessionId index');

      await databases.createIndex(
        databaseId: 'arena_db',
        collectionId: 'debate_votes',
        key: 'userId_sessionId_unique',
        type: IndexType.unique,
        attributes: ['userId', 'sessionId'],
      );
      print('  ✅ Added userId+sessionId unique index');

    } catch (e) {
      print('⚠️ debate_votes collection might already exist: $e');
    }

    print('\n🎉 Debate voting collections setup complete!');
    print('\nCollections created:');
    print('  - debate_voting_sessions');
    print('  - debate_votes');

  } catch (e) {
    print('❌ Error: $e');
  }
}
