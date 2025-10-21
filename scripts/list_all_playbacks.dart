import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  print('📹 Listing ALL arena playbacks in database...');

  try {
    final playbacksRequest = await client.getUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_playbacks/documents')
    );
    playbacksRequest.headers.set('X-Appwrite-Project', projectId);
    playbacksRequest.headers.set('X-Appwrite-Key', apiKey);

    final playbacksResponse = await playbacksRequest.close();
    final playbacksBody = await utf8.decodeStream(playbacksResponse);

    if (playbacksResponse.statusCode == 200) {
      final playbacksData = jsonDecode(playbacksBody);
      final totalPlaybacks = playbacksData['total'];
      print('📊 Total arena playbacks: $totalPlaybacks');

      if (totalPlaybacks > 0) {
        final documents = playbacksData['documents'] as List;
        print('\n🎬 All arena playbacks:');
        for (var doc in documents) {
          print('   - ${doc['\$id']}: "${doc['title']}" (Room: ${doc['originalRoomId']}) - ${doc['status']}');
        }
      } else {
        print('   - No arena playbacks found in database');
      }
    } else {
      print('❌ Failed to list playbacks: $playbacksBody');
    }

  } catch (e) {
    print('❌ Error: $e');
  }

  client.close();
}