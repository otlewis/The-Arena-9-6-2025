import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  print('🔍 Checking current status of your room...');

  // The room ID from your logs
  const roomId = 'arena_68daf15f32fb287e4159';

  try {
    // Check arena_rooms collection
    final roomRequest = await client.getUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_rooms/documents/$roomId')
    );
    roomRequest.headers.set('X-Appwrite-Project', projectId);
    roomRequest.headers.set('X-Appwrite-Key', apiKey);

    final roomResponse = await roomRequest.close();
    final roomBody = await utf8.decodeStream(roomResponse);

    if (roomResponse.statusCode == 200) {
      final roomData = jsonDecode(roomBody);
      print('✅ ARENA ROOM FOUND:');
      print('   - Status: ${roomData['status']}');
      print('   - Recording Status: ${roomData['recordingStatus']}');
      print('   - Enable Playback: ${roomData['enablePlayback']}');
      print('   - Playback ID: ${roomData['playbackId']}');
      print('   - Created: ${roomData['\$createdAt']}');
      print('   - Updated: ${roomData['\$updatedAt']}');
    } else {
      print('❌ Room not found in arena_rooms: $roomBody');
    }

    // Check arena_playbacks collection
    print('\n🎬 Checking playbacks collection...');
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
      print('📊 Total playbacks: $totalPlaybacks');

      if (totalPlaybacks > 0) {
        final documents = playbacksData['documents'] as List;
        for (var doc in documents) {
          print('   - ${doc['title']} (Room: ${doc['roomId']}) - ${doc['status']}');
        }
      } else {
        print('   - No playbacks found');
      }
    } else {
      print('❌ Failed to check playbacks: $playbacksBody');
    }

  } catch (e) {
    print('❌ Error: $e');
  }

  client.close();
}