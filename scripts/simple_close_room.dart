import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  print('🔧 Closing arena room using PATCH method...');

  const roomId = 'arena_68d9d5116dd958497a67'; // "play" room

  try {
    final updateRequest = await client.patchUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_rooms/documents/$roomId')
    );

    updateRequest.headers.set('Content-Type', 'application/json');
    updateRequest.headers.set('X-Appwrite-Project', projectId);
    updateRequest.headers.set('X-Appwrite-Key', apiKey);

    // Use the exact format Appwrite expects
    final requestBody = {
      'status': 'completed',
      'endedAt': DateTime.now().toIso8601String(),
    };

    updateRequest.add(utf8.encode(jsonEncode(requestBody)));
    final updateResponse = await updateRequest.close();
    final responseBody = await utf8.decodeStream(updateResponse);

    print('Update Status: ${updateResponse.statusCode}');
    if (updateResponse.statusCode == 200) {
      print('✅ Room closed successfully!');
      final responseData = jsonDecode(responseBody);
      print('✅ New status: ${responseData['status']}');
    } else {
      print('❌ Failed to close room: $responseBody');
    }

  } catch (e) {
    print('❌ Error: $e');
  }

  client.close();
  print('\n🎉 Check your Arena lobby - the "play" room should be gone!');
}