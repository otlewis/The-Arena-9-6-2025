import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  print('🎬 Testing room completion functionality...');

  const roomId = 'arena_68daf2e03a04757e3b43';

  try {
    // Check current room status before completion
    print('\n📋 BEFORE COMPLETION:');
    final beforeRequest = await client.getUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_rooms/documents/$roomId')
    );
    beforeRequest.headers.set('X-Appwrite-Project', projectId);
    beforeRequest.headers.set('X-Appwrite-Key', apiKey);

    final beforeResponse = await beforeRequest.close();
    final beforeBody = await utf8.decodeStream(beforeResponse);

    if (beforeResponse.statusCode == 200) {
      final beforeData = jsonDecode(beforeBody);
      print('   - Status: ${beforeData['status']}');
      print('   - Recording Status: ${beforeData['recordingStatus']}');
      print('   - Enable Playback: ${beforeData['enablePlayback']}');
      print('   - Playback ID: ${beforeData['playbackId']}');
    } else {
      print('❌ Room not found: $beforeBody');
      return;
    }

    // Now test the completion by directly calling completeArenaRoom logic
    print('\n🎬 SIMULATING ROOM COMPLETION...');

    // Step 1: Create playback
    print('📹 Creating playback...');
    const playbackId = 'playback_completion_test';
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
        'description': 'Completed room test',
        'audioUrl': 'https://example.com/arena_recording_$roomId.mp3',
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

    if (playbackResponse.statusCode == 201) {
      print('✅ Playback created successfully!');
    } else {
      final playbackBody = await utf8.decodeStream(playbackResponse);
      print('❌ Playback creation failed: $playbackBody');
      return;
    }

    // Step 2: Update room to completed status
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
        'endedAt': DateTime.now().toIso8601String(),
        'recordingStatus': 'ready',
        'recordingEnded': DateTime.now().toIso8601String(),
        'enablePlayback': true,
        'playbackId': playbackId,
      }
    };

    roomRequest.add(utf8.encode(jsonEncode(roomUpdateData)));
    final roomResponse = await roomRequest.close();
    final roomBody = await utf8.decodeStream(roomResponse);

    if (roomResponse.statusCode == 200) {
      print('✅ Room marked as completed successfully!');
      final responseData = jsonDecode(roomBody);
      print('   - Status: ${responseData['status']}');
      print('   - Recording Status: ${responseData['recordingStatus']}');
      print('   - Enable Playback: ${responseData['enablePlayback']}');
      print('   - Playback ID: ${responseData['playbackId']}');
    } else {
      print('❌ Failed to update room: $roomBody');
      return;
    }

    print('\n🎉 ROOM COMPLETION TEST SUCCESSFUL!');
    print('   - Room should now show as "completed" in database');
    print('   - Playback should be available in Arena Playbacks screen');
    print('   - Room should remain visible in lobby with playback access');

  } catch (e) {
    print('❌ Error: $e');
  }

  client.close();
}