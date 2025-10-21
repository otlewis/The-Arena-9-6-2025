import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  final client = Client()
      .setEndpoint('https://cloud.appwrite.io/v1')
      .setProject('683a37a8003719978879')
      .setKey('standard_a208ff4a370b36ef18f5827decfe8df2df923cd0f151b9caee106fd2bd8c7fe66fb597fead8e8cd3ca8c7ac3acf7bc55fa5d29db9d13d1aa2ab5e0c5af95fd48a29a8e6f8e8dfae3c1a0a0eac73d44b5629ee6a53e45fc1a1b3d66c5eb33c29f37bb21b311fa2b8bf8f137a1a0d7a20a3f77a51d7dc2c5c2da5c9f0ffcc59cd');

  final databases = Databases(client);

  print('🔍 Checking moderator video state in debate_discussion_participants...\n');

  try {
    final participants = await databases.listDocuments(
      databaseId: 'arena_db',
      collectionId: 'debate_discussion_participants',
      queries: [
        Query.equal('status', 'joined'),
        Query.orderDesc('\$createdAt'),
        Query.limit(5),
      ],
    );

    print('Found ${participants.documents.length} active participants:\n');

    for (var doc in participants.documents) {
      final data = doc.data;
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('Room: ${data['roomId']}');
      print('User: ${data['userId']}');
      print('Role: ${data['role']}');
      print('videoReady: ${data['videoReady']}');
      print('audioReady: ${data['audioReady']}');
      print('videoTrackSid: ${data['videoTrackSid']}');
      print('audioTrackSid: ${data['audioTrackSid']}');
      print('Updated: ${data['\$updatedAt']}');
      print('');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
