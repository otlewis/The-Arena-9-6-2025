// ignore_for_file: avoid_print, deprecated_member_use, expected_identifier_but_got_keyword

import 'package:appwrite/appwrite.dart';

/// Script to update participant collections with role authority fields
/// This ensures consistent schema across all participant collections
void main() async {
  // Initialize Appwrite
  final client = Client()
      .setEndpoint('https://cloud.appwrite.io/v1')
      .setProject('683a37a8003719978879'); // Your project ID
      // .setKey(''); // Set your API key here - deprecated method

  final databases = Databases(client);
  const databaseId = 'arena_db';

  print('🔄 Updating participant collections schema for role authority...');

  try {
    // NOTE: This script is disabled due to deprecated Appwrite API methods
    // The methods used here are not yet replaced in Flutter SDK v18.0.0
    // Enable this script once TablesDB API is available

    print('📝 This script is currently disabled due to deprecated API methods');
    print('📝 Wait for TablesDB API to be available in Flutter SDK');

    /*
    // Update debate_discussion_participants collection
    await updateDebateDiscussionParticipants(databases, databaseId);

    // Update arena_participants collection
    await updateArenaParticipants(databases, databaseId);

    // Update room_participants collection (for open discussions)
    await updateRoomParticipants(databases, databaseId);
    */

    print('✅ Script completed (no operations performed)');
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Update debate_discussion_participants collection
Future<void> updateDebateDiscussionParticipants(Databases databases, String databaseId) async {
  // Function disabled due to deprecated API methods
  print('Function disabled - deprecated API methods');
  return;
  /*
  const collectionId = 'debate_discussion_participants';

  print('📝 Updating $collectionId collection...');

  try {
    // Add role field (authoritative source)
    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'role',
      size: 50,
      required: true,
      default: 'audience',
    );
    print('  ✅ Added role field');

    // Add eventId for idempotency
    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'eventId',
      size: 100,
      required: false,
    );
    print('  ✅ Added eventId field');

    // Add roleUpdatedAt timestamp
    await databases.createDatetimeAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'roleUpdatedAt',
      required: false,
    );
    print('  ✅ Added roleUpdatedAt field');

    // Add lastHeartbeat for presence tracking
    await databases.createDatetimeAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'lastHeartbeat',
      required: false,
      default: DateTime.now().toIso8601String(),
    );
    print('  ✅ Added lastHeartbeat field');

    // Add isConnected status
    await databases.createBooleanAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'isConnected',
      required: true,
      default: true,
    );
    print('  ✅ Added isConnected field');

    // Create indexes for efficient queries
    await databases.createIndex(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'role_index',
      type: 'key',
      attributes: ['role'],
    );
    print('  ✅ Added role index');

    await databases.createIndex(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'room_role_index',
      type: 'key',
      attributes: ['roomId', 'role'],
    );
    print('  ✅ Added room_role compound index');

    await databases.createIndex(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'eventId_index',
      type: 'key',
      attributes: ['eventId'],
    );
    print('  ✅ Added eventId index');

    await databases.createIndex(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'heartbeat_index',
      type: 'key',
      attributes: ['lastHeartbeat'],
      orders: ['DESC'],
    );
    print('  ✅ Added heartbeat index');

  } catch (e) {
    if (e.toString().contains('already exists')) {
      print('  ⚠️  Some fields already exist, continuing...');
    } else {
      print('  ❌ Error: $e');
      rethrow;
    }
  }
}

/// Update arena_participants collection
Future<void> updateArenaParticipants(Databases databases, String databaseId) async {
  const collectionId = 'arena_participants';

  print('📝 Updating $collectionId collection...');

  try {
    // Add role field (judges, debater1, debater2, audience)
    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'role',
      size: 50,
      required: true,
      default: 'audience',
    );
    print('  ✅ Added role field');

    // Add eventId for idempotency
    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'eventId',
      size: 100,
      required: false,
    );
    print('  ✅ Added eventId field');

    // Add roleUpdatedAt timestamp
    await databases.createDatetimeAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'roleUpdatedAt',
      required: false,
    );
    print('  ✅ Added roleUpdatedAt field');

    // Add lastHeartbeat for presence tracking
    await databases.createDatetimeAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'lastHeartbeat',
      required: false,
      default: DateTime.now().toIso8601String(),
    );
    print('  ✅ Added lastHeartbeat field');

    // Add isConnected status
    await databases.createBooleanAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'isConnected',
      required: true,
      default: true,
    );
    print('  ✅ Added isConnected field');

    // Create indexes
    await databases.createIndex(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'role_index',
      type: 'key',
      attributes: ['role'],
    );
    print('  ✅ Added role index');

    await databases.createIndex(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'room_role_index',
      type: 'key',
      attributes: ['roomId', 'role'],
    );
    print('  ✅ Added room_role compound index');

  } catch (e) {
    if (e.toString().contains('already exists')) {
      print('  ⚠️  Some fields already exist, continuing...');
    } else {
      print('  ❌ Error: $e');
      rethrow;
    }
  }
}

/// Update room_participants collection (open discussions)
Future<void> updateRoomParticipants(Databases databases, String databaseId) async {
  const collectionId = 'room_participants';

  print('📝 Updating $collectionId collection...');

  try {
    // Add role field (moderator, speaker, audience)
    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'role',
      size: 50,
      required: true,
      default: 'audience',
    );
    print('  ✅ Added role field');

    // Add eventId for idempotency
    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'eventId',
      size: 100,
      required: false,
    );
    print('  ✅ Added eventId field');

    // Add roleUpdatedAt timestamp
    await databases.createDatetimeAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'roleUpdatedAt',
      required: false,
    );
    print('  ✅ Added roleUpdatedAt field');

    // Add lastHeartbeat for presence tracking
    await databases.createDatetimeAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'lastHeartbeat',
      required: false,
      default: DateTime.now().toIso8601String(),
    );
    print('  ✅ Added lastHeartbeat field');

    // Add isConnected status
    await databases.createBooleanAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'isConnected',
      required: true,
      default: true,
    );
    print('  ✅ Added isConnected field');

    // Create indexes
    await databases.createIndex(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'role_index',
      type: 'key',
      attributes: ['role'],
    );
    print('  ✅ Added role index');

    await databases.createIndex(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'room_role_index',
      type: 'key',
      attributes: ['roomId', 'role'],
    );
    print('  ✅ Added room_role compound index');

  } catch (e) {
    if (e.toString().contains('already exists')) {
      print('  ⚠️  Some fields already exist, continuing...');
    } else {
      print('  ❌ Error: $e');
      rethrow;
    }
  }
}

/// Create role change events collection for audit trail
Future<void> createRoleChangeEventsCollection(Databases databases, String databaseId) async {
  const collectionId = 'role_change_events';

  print('📝 Creating $collectionId collection...');

  try {
    // Create the collection
    await databases.createCollection(
      databaseId: databaseId,
      collectionId: collectionId,
      name: 'Role Change Events',
      permissions: [
        Permission.read(Role.any()),
        Permission.create(Role.users()),
        Permission.update(Role.users()),
      ],
    );
    print('  ✅ Created collection');

    // Add fields
    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'roomId',
      size: 100,
      required: true,
    );

    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'userId',
      size: 100,
      required: true,
    );

    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'oldRole',
      size: 50,
      required: true,
    );

    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'newRole',
      size: 50,
      required: true,
    );

    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'eventId',
      size: 100,
      required: true,
    );

    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'triggeredBy',
      size: 100,
      required: true,
    );

    await databases.createDatetimeAttribute(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'timestamp',
      required: true,
      default: DateTime.now().toIso8601String(),
    );

    // Create indexes
    await databases.createIndex(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'room_index',
      type: 'key',
      attributes: ['roomId'],
    );

    await databases.createIndex(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'user_index',
      type: 'key',
      attributes: ['userId'],
    );

    await databases.createIndex(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'eventId_index',
      type: 'key',
      attributes: ['eventId'],
    );

    await databases.createIndex(
      databaseId: databaseId,
      collectionId: collectionId,
      key: 'timestamp_index',
      type: 'key',
      attributes: ['timestamp'],
      orders: ['DESC'],
    );

    print('  ✅ Added all fields and indexes');

  } catch (e) {
    if (e.toString().contains('already exists')) {
      print('  ⚠️  Collection already exists, skipping...');
    } else {
      print('  ❌ Error: $e');
      rethrow;
    }
  }
}