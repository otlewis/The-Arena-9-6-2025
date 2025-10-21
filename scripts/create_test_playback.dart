import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  print('🎬 Creating test playback entry...');

  try {
    // Create a unique playback ID
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final playbackId = 'test_playback_$timestamp';

    final playbackRequest = await client.postUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_playbacks/documents')
    );
    playbackRequest.headers.set('Content-Type', 'application/json');
    playbackRequest.headers.set('X-Appwrite-Project', projectId);
    playbackRequest.headers.set('X-Appwrite-Key', apiKey);

    final playbackData = {
      'documentId': playbackId,
      'data': {
        'originalRoomId': 'arena_68db117ccc283abda482', // First completed room
        'title': "can't believe",
        'topic': "can't believe",
        'description': 'Test playback',
        'audioUrl': 'http://50.21.187.76/arena-recordings/test.mp3',
        'audioFormat': 'mp3',
        'duration': 300,
        'fileSize': 1024000,
        'status': 'ready',
        'visibility': 'public',
        'debater1Id': '6843c3781d2c1c7154a0',
        'debater2Id': '6843c3781d2c1c7154a0',
        'moderatorId': '6843c3781d2c1c7154a0',
        'totalJudges': 0,
        'affirmativeVotes': 0,
        'negativeVotes': 0,
        'viewCount': 0,
        'likeCount': 0,
        'recordedAt': DateTime.now().toIso8601String(),
        'processingCompleted': DateTime.now().toIso8601String(),
      }
    };

    playbackRequest.add(utf8.encode(jsonEncode(playbackData)));
    final playbackResponse = await playbackRequest.close();
    final playbackBody = await utf8.decodeStream(playbackResponse);

    if (playbackResponse.statusCode == 201) {
      print('✅ Playback created successfully!');
      final data = jsonDecode(playbackBody);
      print('   ID: ${data['\$id']}');
      print('   Title: ${data['title']}');
      print('   URL: ${data['audioUrl']}');
    } else {
      print('❌ Failed to create playback: $playbackBody');
    }

  } catch (e) {
    print('❌ Error: $e');
  }

  client.close();
}