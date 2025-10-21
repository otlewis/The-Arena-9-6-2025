import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  print('📋 Listing ALL arena rooms in database...');

  try {
    final roomsRequest = await client.getUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_rooms/documents')
    );
    roomsRequest.headers.set('X-Appwrite-Project', projectId);
    roomsRequest.headers.set('X-Appwrite-Key', apiKey);

    final roomsResponse = await roomsRequest.close();
    final roomsBody = await utf8.decodeStream(roomsResponse);

    if (roomsResponse.statusCode == 200) {
      final roomsData = jsonDecode(roomsBody);
      final totalRooms = roomsData['total'];
      print('📊 Total arena rooms: $totalRooms');

      if (totalRooms > 0) {
        final documents = roomsData['documents'] as List;
        print('\n🏟️ All arena rooms:');
        for (var doc in documents) {
          print('   - ${doc['\$id']}: "${doc['topic']}" [${doc['status']}] (${doc['recordingStatus'] ?? 'no recording'})');
          if (doc['enablePlayback'] == true) {
            print('     📹 Playback enabled, PlaybackID: ${doc['playbackId'] ?? 'none'}');
          }
        }
      } else {
        print('   - No arena rooms found in database');
      }
    } else {
      print('❌ Failed to list rooms: $roomsBody');
    }

  } catch (e) {
    print('❌ Error: $e');
  }

  client.close();
}