import 'dart:io';
import 'package:appwrite/appwrite.dart';

void main() async {
  print('🚀 Creating room_invitations collection...');

  // Initialize Appwrite client
  final client = Client()
      .setEndpoint('https://cloud.appwrite.io/v1')
      .setProject('683a37a8003719978879')
      .setKey(Platform.environment['APPWRITE_API_KEY'] ?? '');

  final databases = Databases(client);

  try {
    // Create collection
    print('📦 Creating collection...');
    await databases.createCollection(
      databaseId: 'arena_db',
      collectionId: 'room_invitations',
      name: 'Room Invitations',
      permissions: [
        Permission.read(Role.any()),
        Permission.create(Role.users()),
        Permission.update(Role.users()),
        Permission.delete(Role.users()),
      ],
    );
    print('✅ Collection created!');

    // Wait a bit for collection to be ready
    await Future.delayed(Duration(seconds: 2));

    // Create attributes
    print('📝 Creating attributes...');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'room_invitations',
      key: 'roomId',
      size: 255,
      required: true,
    );
    print('  ✓ roomId');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'room_invitations',
      key: 'roomName',
      size: 255,
      required: true,
    );
    print('  ✓ roomName');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'room_invitations',
      key: 'roomType',
      size: 50,
      required: true,
    );
    print('  ✓ roomType');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'room_invitations',
      key: 'inviterId',
      size: 255,
      required: true,
    );
    print('  ✓ inviterId');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'room_invitations',
      key: 'inviterName',
      size: 255,
      required: true,
    );
    print('  ✓ inviterName');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'room_invitations',
      key: 'inviteeId',
      size: 255,
      required: true,
    );
    print('  ✓ inviteeId');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'room_invitations',
      key: 'status',
      size: 50,
      required: true,
    );
    print('  ✓ status');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'room_invitations',
      key: 'createdAt',
      size: 100,
      required: true,
    );
    print('  ✓ createdAt');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'room_invitations',
      key: 'expiresAt',
      size: 100,
      required: true,
    );
    print('  ✓ expiresAt');

    // Wait for attributes to be created
    print('⏳ Waiting for attributes to be ready...');
    await Future.delayed(Duration(seconds: 10));

    // Create indexes
    print('🔍 Creating indexes...');

    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'room_invitations',
      key: 'inviteeId_status_idx',
      type: IndexType.key,
      attributes: ['inviteeId', 'status'],
      orders: ['ASC', 'ASC'],
    );
    print('  ✓ inviteeId_status_idx');

    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'room_invitations',
      key: 'roomId_status_idx',
      type: IndexType.key,
      attributes: ['roomId', 'status'],
      orders: ['ASC', 'ASC'],
    );
    print('  ✓ roomId_status_idx');

    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'room_invitations',
      key: 'createdAt_idx',
      type: IndexType.key,
      attributes: ['createdAt'],
      orders: ['DESC'],
    );
    print('  ✓ createdAt_idx');

    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'room_invitations',
      key: 'expiresAt_status_idx',
      type: IndexType.key,
      attributes: ['expiresAt', 'status'],
      orders: ['ASC', 'ASC'],
    );
    print('  ✓ expiresAt_status_idx');

    print('\n✅ room_invitations collection setup complete!');
    print('📍 Database: arena_db');
    print('📍 Collection: room_invitations');

  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
