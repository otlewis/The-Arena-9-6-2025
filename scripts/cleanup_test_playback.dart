import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  print('🧹 Cleaning up test playback...');

  try {
    final deleteRequest = await client.deleteUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_playbacks/documents/playback_test_12345')
    );
    deleteRequest.headers.set('X-Appwrite-Project', projectId);
    deleteRequest.headers.set('X-Appwrite-Key', apiKey);

    final deleteResponse = await deleteRequest.close();
    if (deleteResponse.statusCode == 204) {
      print('✅ Test playback deleted successfully');
    } else {
      final body = await utf8.decodeStream(deleteResponse);
      print('❌ Failed to delete: $body');
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  client.close();
}