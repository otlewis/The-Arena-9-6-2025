import 'dart:io';
import 'dart:convert';

/// Test script to simulate creating a playback document with proper permissions
Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  print('🧪 Testing playback creation with permissions...');

  try {
    final playbackId = 'test_playback_${DateTime.now().millisecondsSinceEpoch}';

    // Create a test playback document with permissions
    final uri = Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_playbacks/documents');

    final request = await client.postUrl(uri);
    request.headers.set('X-Appwrite-Project', projectId);
    request.headers.set('X-Appwrite-Key', apiKey);
    request.headers.set('Content-Type', 'application/json');

    final playbackData = {
      'documentId': playbackId,
      'data': {
        'originalRoomId': 'test_room_123',
        'title': 'Test Room Created by User',
        'topic': 'Test Topic',
        'description': 'Test description for user-created room',
        'audioUrl': 'https://demo-audio-url-user-room.mp3',
        'duration': 300,
        'fileSize': 2048000,
        'debater1Id': 'user1',
        'debater2Id': 'user2',
        'moderatorId': 'moderator1',
        'winnerSide': null,
        'totalJudges': 0,
        'affirmativeVotes': 0,
        'negativeVotes': 0,
        'recordedAt': DateTime.now().toUtc().toIso8601String(),
        'processingStarted': null,
        'processingCompleted': DateTime.now().toUtc().toIso8601String(),
        'tags': null,
        'metadata': null,
        'viewCount': 0,
        'likeCount': 0,
        'audioFormat': 'mp3',
        'status': 'ready',
        'visibility': 'public',
      },
      'permissions': [
        'read("any")', // Allow anyone to read this playback
      ]
    };

    final jsonData = jsonEncode(playbackData);
    request.write(jsonData);

    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);

    print('Status: ${response.statusCode}');

    if (response.statusCode == 201) {
      final data = jsonDecode(responseBody);
      print('✅ Test playback created successfully!');
      print('📋 Playback ID: ${data['\$id']}');
      print('📋 Title: ${data['title']}');
      print('📋 Permissions: ${data['\$permissions']}');
      print('🎉 This playback should now be visible to authenticated users!');
    } else {
      print('❌ Failed to create test playback: $responseBody');
    }

  } catch (e) {
    print('❌ Error: $e');
  }

  client.close();
}