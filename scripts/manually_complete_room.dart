import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  print('🎬 Manually completing arena room with playback...');

  // The current room that exists
  const roomId = 'arena_68daf2e03a04757e3b43';
  const playbackId = 'playback_test_12345';

  try {
    // Step 1: Create a dummy playback entry
    print('📹 Creating playback entry...');
    final playbackRequest = await client.postUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_playbacks/documents')
    );
    playbackRequest.headers.set('Content-Type', 'application/json');
    playbackRequest.headers.set('X-Appwrite-Project', projectId);
    playbackRequest.headers.set('X-Appwrite-Key', apiKey);

    final playbackData = {
      'documentId': playbackId,
      'data': {
        'originalRoomId': roomId,
        'title': 'The first time',
        'topic': 'The first time',
        'description': 'Test playback creation',
        'audioUrl': 'https://example.com/test.mp3',
        'audioFormat': 'mp3',
        'duration': 300,
        'fileSize': 1024000,
        'status': 'ready',
        'visibility': 'public',
        'debater1Id': '6843c3781d2c1c7154a0', // Required field - using moderatorId as fallback
        'debater2Id': '6843c3781d2c1c7154a0', // Required field - using moderatorId as fallback
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
    } else {
      print('❌ Failed to create playback: $playbackBody');
      return;
    }

    // Step 2: Update the room to completed with playback info
    print('🏟️ Updating room to completed...');
    final roomRequest = await client.patchUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_rooms/documents/$roomId')
    );
    roomRequest.headers.set('Content-Type', 'application/json');
    roomRequest.headers.set('X-Appwrite-Project', projectId);
    roomRequest.headers.set('X-Appwrite-Key', apiKey);

    final roomUpdateData = {
      'data': {
        'status': 'completed',
        'recordingStatus': 'ready',
        'recordingEnded': DateTime.now().toIso8601String(),
        'playbackId': playbackId,
        'enablePlayback': true, // Use boolean instead of string
        'endedAt': DateTime.now().toIso8601String(),
      }
    };

    roomRequest.add(utf8.encode(jsonEncode(roomUpdateData)));
    final roomResponse = await roomRequest.close();
    final roomBody = await utf8.decodeStream(roomResponse);

    if (roomResponse.statusCode == 200) {
      print('✅ Room marked as completed successfully!');
      final responseData = jsonDecode(roomBody);
      print('   - Status: ${responseData['status']}');
      print('   - Enable Playback: ${responseData['enablePlayback']}');
      print('   - Playback ID: ${responseData['playbackId']}');
      print('\n🎉 Check your Arena Playbacks screen - "The first time" should now appear!');
    } else {
      print('❌ Failed to update room: $roomBody');
    }

  } catch (e) {
    print('❌ Error: $e');
  }

  client.close();
}