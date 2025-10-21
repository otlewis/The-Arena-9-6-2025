import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';

  final client = HttpClient();

  print('🔍 Checking arena_playbacks collection...');
  try {
    final request = await client.getUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/arena_db/collections/arena_playbacks/documents')
    );
    request.headers.set('X-Appwrite-Project', projectId);
    request.headers.set('X-Appwrite-Key', apiKey);

    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);
    final data = jsonDecode(responseBody);

    print('Status: ${response.statusCode}');
    print('Total playbacks: ${data['total'] ?? 0}');

    if (data['documents'] != null && data['documents'].length > 0) {
      print('\n📹 Playback records found:');
      for (var doc in data['documents']) {
        print('- ID: ${doc['\$id']}');
        print('  Title: ${doc['title']}');
        print('  Status: ${doc['status']}');
        print('  Original Room: ${doc['originalRoomId']}');
        print('  Audio URL: ${doc['audioUrl']}');
        print('');
      }
    } else {
      print('❌ No playback records found');
    }

  } catch (e) {
    print('❌ Error checking playbacks: $e');
  }

  print('\n🏛️ Checking arena_rooms collection for completed rooms...');
  try {
    final request = await client.getUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/arena_db/collections/arena_rooms/documents')
    );
    request.headers.set('X-Appwrite-Project', projectId);
    request.headers.set('X-Appwrite-Key', apiKey);

    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);
    final data = jsonDecode(responseBody);

    print('Status: ${response.statusCode}');
    print('Total rooms: ${data['total'] ?? 0}');

    if (data['documents'] != null && data['documents'].length > 0) {
      print('\n🏛️ Arena room statuses:');
      for (var doc in data['documents']) {
        print('- Room ID: ${doc['\$id']}');
        print('  Topic: ${doc['topic']}');
        print('  Status: ${doc['status']}');
        print('  Recording Status: ${doc['recordingStatus'] ?? 'not set'}');
        print('  Playback ID: ${doc['playbackId'] ?? 'none'}');
        print('');
      }
    } else {
      print('❌ No arena rooms found');
    }

  } catch (e) {
    print('❌ Error checking arena rooms: $e');
  }

  client.close();
}