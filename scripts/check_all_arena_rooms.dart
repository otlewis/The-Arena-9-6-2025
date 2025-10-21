// ignore_for_file: avoid_print
import 'package:appwrite/appwrite.dart';

Future<void> main() async {
  print('🔍 Checking all arena rooms...');

  try {
    // Note: This script requires server-side SDK with API key
    // For now, using client SDK. Use Appwrite CLI or server SDK for production.
    final client = Client()
        .setEndpoint('https://cloud.appwrite.io/v1')
        .setProject('arena');

    final databases = Databases(client);

    final result = await databases.listDocuments(
      databaseId: 'arena_db',
      collectionId: 'arena_rooms',
      queries: [
        Query.limit(20),
        Query.orderDesc('\$createdAt'),
      ],
    );

    print('📊 Found ${result.documents.length} arena rooms:');

    for (final doc in result.documents) {
      final id = doc.$id;
      final topic = doc.data['topic'] ?? 'No topic';
      final status = doc.data['status'] ?? 'unknown';
      final createdAt = doc.$createdAt;
      final recordingStatus = doc.data['recordingStatus'] ?? 'none';
      final playbackId = doc.data['playbackId'] ?? 'null';

      print('  🏛️ Room: $id');
      print('    📝 Topic: $topic');
      print('    📊 Status: $status');
      print('    🎬 Recording: $recordingStatus');
      print('    🎥 Playback ID: $playbackId');
      print('    📅 Created: $createdAt');
      print('');
    }

    // Also check participants
    print('👥 Checking participants for rooms...');

    final participantsResult = await databases.listDocuments(
      databaseId: 'arena_db',
      collectionId: 'arena_participants',
      queries: [
        Query.limit(50),
        Query.orderDesc('\$createdAt'),
      ],
    );

    print('📊 Found ${participantsResult.documents.length} arena participants:');

    for (final doc in participantsResult.documents) {
      final roomId = doc.data['roomId'] ?? 'unknown';
      final userId = doc.data['userId'] ?? 'unknown';
      final role = doc.data['role'] ?? 'unknown';
      final isActive = doc.data['isActive'] ?? false;

      print('  👤 $userId in $roomId as $role (active: $isActive)');
    }

  } catch (e) {
    print('❌ Error: $e');
  }
}