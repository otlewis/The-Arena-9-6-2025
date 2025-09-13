import 'package:appwrite/appwrite.dart';

void main() async {
  // Initialize Appwrite client
  final client = Client()
      .setEndpoint('https://cloud.appwrite.io/v1')
      .setProject('683a37a8003719978879')
      .setKey('7b8d9e3f41c6a27b5e8f1d9a3c6e8b2a4d7f9e1c3b6d8f2a5c7e9b1d4f6a8c2e5');

  final databases = Databases(client);
  const databaseId = 'arena_db';

  try {
    // Create consent_logs collection
    final collection = await databases.createCollection(
      databaseId: databaseId,
      collectionId: 'consent_logs',
      name: 'Consent Logs',
    );

    print('Created consent_logs collection: ${collection.name}');

    // Create attributes for bulletproof consent logs schema
    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: 'consent_logs',
      key: 'userId',
      size: 255,
      required: true,
    );

    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: 'consent_logs',
      key: 'parentEmail',
      size: 255,
      required: false,
    );

    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: 'consent_logs',
      key: 'action',
      size: 50,
      required: true,
    );

    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: 'consent_logs',
      key: 'timestamp',
      size: 50,
      required: true,
    );

    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: 'consent_logs',
      key: 'metadata',
      size: 2000,
      required: true,
    );

    print('Created all attributes for consent_logs');

    // Create indexes for efficient querying
    await databases.createIndex(
      databaseId: databaseId,
      collectionId: 'consent_logs',
      key: 'userId_index',
      type: 'key',
      attributes: ['userId'],
    );

    await databases.createIndex(
      databaseId: databaseId,
      collectionId: 'consent_logs',
      key: 'action_index',
      type: 'key',
      attributes: ['action'],
    );

    await databases.createIndex(
      databaseId: databaseId,
      collectionId: 'consent_logs',
      key: 'timestamp_index',
      type: 'key',
      attributes: ['timestamp'],
    );

    await databases.createIndex(
      databaseId: databaseId,
      collectionId: 'consent_logs',
      key: 'parentEmail_index',
      type: 'key',
      attributes: ['parentEmail'],
    );

    await databases.createIndex(
      databaseId: databaseId,
      collectionId: 'consent_logs',
      key: 'userId_timestamp_compound',
      type: 'key',
      attributes: ['userId', 'timestamp'],
    );

    print('Created indexes for consent_logs');

    // Set permissions
    await databases.updateCollection(
      databaseId: databaseId,
      collectionId: 'consent_logs',
      name: 'Consent Logs',
      permissions: [
        Permission.create(Role.users()),
        Permission.read(Role.users()),
        Permission.update(Role.users()),
        Permission.delete(Role.users()),
      ],
    );

    print('Set permissions for consent_logs collection');
    print('✅ Consent logs collection setup complete!');

  } catch (e) {
    print('❌ Error setting up consent_logs collection: $e');
  }
}