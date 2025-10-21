// ignore_for_file: avoid_print, unused_local_variable
import 'package:appwrite/appwrite.dart';

/// Setup script for room_reactions collection in Appwrite
/// NOTE: This script requires server-side SDK which is not available in Flutter client SDK
/// Use Appwrite CLI or server SDK (Node.js, Python, etc.) to run this script
/// Run with: dart run setup_reactions_collection.dart
void main() async {
  // Note: flutter_dotenv not available for standalone dart scripts
  // Configure these values manually or use environment variables
  const endpoint = 'https://cloud.appwrite.io/v1';
  const projectId = 'your-project-id';
  const databaseId = 'arena_db';

  final client = Client()
      .setEndpoint(endpoint)
      .setProject(projectId);
      // Note: setKey() is not available in client SDK - use server SDK

  final databases = Databases(client);

  try {
    print('📦 This script needs to be run with Appwrite server SDK');
    print('   The following methods are not available in the client SDK:');
    print('   - createCollection()');
    print('   - createStringAttribute()');
    print('   - createIndex()');
    print('');
    print('   Please use Appwrite CLI or a server-side SDK (Node.js, Python, etc.)');
    print('   to create the room_reactions collection.');

    // Note: The following code requires server SDK methods not available in client SDK
    /*
    // Create collection
    final collection = await databases.createCollection(
      databaseId: databaseId,
      collectionId: 'room_reactions',
      name: 'Room Reactions',
      permissions: [
        Permission.read(Role.any()),
        Permission.create(Role.users()),
        Permission.update(Role.users()),
        Permission.delete(Role.users()),
      ],
    );

    // Create attributes
    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: 'room_reactions',
      key: 'roomId',
      size: 255,
      required: true,
    );

    // Create indexes
    await databases.createIndex(
      databaseId: databaseId,
      collectionId: 'room_reactions',
      key: 'roomId_idx',
      type: 'key',
      attributes: ['roomId'],
    );
    */
  } catch (e) {
    print('❌ Error: $e');
  }
}
