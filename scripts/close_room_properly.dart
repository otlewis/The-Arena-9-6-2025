import 'package:appwrite/appwrite.dart';

// ignore_for_file: avoid_print, deprecated_member_use

// Simple script to properly close an arena room using the Appwrite service
void main() async {
  print('🔧 Properly closing arena room using updateDocument...');

  // Note: This script requires server-side SDK with API key
  // For now, using client SDK. Use Appwrite CLI or server SDK for production.
  final client = Client()
      .setEndpoint('https://cloud.appwrite.io/v1')
      .setProject('683a37a8003719978879');

  final databases = Databases(client);

  const roomId = 'arena_68d9d5116dd958497a67'; // "play" room

  try {
    print('📝 Updating room status to completed...');

    await databases.updateDocument(
      databaseId: 'arena_db',
      collectionId: 'arena_rooms',
      documentId: roomId,
      data: {
        'status': 'completed',
        'endedAt': DateTime.now().toIso8601String(),
        'reason': 'Manual close - testing',
      },
    );

    print('✅ Room closed successfully!');

    // Verify the update
    print('🔍 Verifying room status...');
    final doc = await databases.getDocument(
      databaseId: 'arena_db',
      collectionId: 'arena_rooms',
      documentId: roomId,
    );

    print('📋 Room status: ${doc.data['status']}');
    print('📋 Ended at: ${doc.data['endedAt']}');

  } catch (e) {
    print('❌ Error: $e');
  }

  print('\n🎉 Arena lobby should now be clean!');
}