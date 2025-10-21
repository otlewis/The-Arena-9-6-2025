import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  const realRoomId = 'arena_68d9c80e6b5a2f9eaabf';
  const playbackId = 'playback_1759105462051';

  print('🔧 Fixing arena room update...');

  try {
    // Try different HTTP method for updating document
    final updateRequest = await client.putUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_rooms/documents/$realRoomId')
    );

    updateRequest.headers.set('Content-Type', 'application/json');
    updateRequest.headers.set('X-Appwrite-Project', projectId);
    updateRequest.headers.set('X-Appwrite-Key', apiKey);

    final updateData = {
      'playbackId': playbackId,
      'recordingStatus': 'ready',
      'recordingEnded': DateTime.now().toIso8601String(),
    };

    updateRequest.add(utf8.encode(jsonEncode(updateData)));
    final updateResponse = await updateRequest.close();
    final responseBody = await utf8.decodeStream(updateResponse);

    print('Update Status: ${updateResponse.statusCode}');
    if (updateResponse.statusCode == 200) {
      print('✅ Arena room updated successfully with playback link!');
    } else {
      print('❌ Update failed: $responseBody');

      // Let's try just adding the playbackId field
      print('\n🔧 Trying minimal update...');

      final minimalRequest = await client.putUrl(
        Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_rooms/documents/$realRoomId')
      );

      minimalRequest.headers.set('Content-Type', 'application/json');
      minimalRequest.headers.set('X-Appwrite-Project', projectId);
      minimalRequest.headers.set('X-Appwrite-Key', apiKey);

      final minimalData = {
        'playbackId': playbackId,
      };

      minimalRequest.add(utf8.encode(jsonEncode(minimalData)));
      final minimalResponse = await minimalRequest.close();
      final minimalResponseBody = await utf8.decodeStream(minimalResponse);

      print('Minimal Update Status: ${minimalResponse.statusCode}');
      if (minimalResponse.statusCode == 200) {
        print('✅ Arena room updated with minimal data!');
      } else {
        print('❌ Minimal update also failed: $minimalResponseBody');
      }
    }

  } catch (e) {
    print('❌ Error updating arena room: $e');
  }

  // Now let's verify the current state
  print('\n🔍 Checking final state...');

  try {
    final checkRequest = await client.getUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_playbacks/documents')
    );
    checkRequest.headers.set('X-Appwrite-Project', projectId);
    checkRequest.headers.set('X-Appwrite-Key', apiKey);

    final response = await checkRequest.close();
    final responseBody = await utf8.decodeStream(response);
    final data = jsonDecode(responseBody);

    print('📹 Current playback records:');
    if (data['documents'] != null) {
      for (var doc in data['documents']) {
        print('- ID: ${doc['\$id']}');
        print('  Title: ${doc['title']}');
        print('  Original Room: ${doc['originalRoomId']}');
        print('  Status: ${doc['status']}');
      }
    }

  } catch (e) {
    print('❌ Error checking final state: $e');
  }

  client.close();
}