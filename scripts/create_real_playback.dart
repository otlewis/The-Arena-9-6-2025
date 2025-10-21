import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  print('🎬 Creating playback record for real arena room...');

  // The real arena room ID from the database check
  const realRoomId = 'arena_68d9c80e6b5a2f9eaabf';
  final playbackId = 'playback_${DateTime.now().millisecondsSinceEpoch}';

  try {
    // Create playback record for the real arena room
    final request = await client.postUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_playbacks/documents')
    );

    request.headers.set('Content-Type', 'application/json');
    request.headers.set('X-Appwrite-Project', projectId);
    request.headers.set('X-Appwrite-Key', apiKey);

    final playbackData = {
      'documentId': playbackId,
      'data': {
        'originalRoomId': realRoomId,
        'title': 'The only way - Arena Debate',
        'topic': 'The only way',
        'description': 'Arena debate recording',
        'audioUrl': 'https://demo-audio-url-real-room.mp3',
        'audioFormat': 'mp3',
        'duration': 180,
        'fileSize': 1024000,
        'status': 'ready',
        'visibility': 'public',
        'debater1Id': 'debater1',
        'debater2Id': 'debater2',
        'moderatorId': 'moderator',
        'winnerSide': null,
        'totalJudges': 0,
        'affirmativeVotes': 0,
        'negativeVotes': 0,
        'viewCount': 0,
        'likeCount': 0,
        'recordedAt': DateTime.now().toIso8601String(),
        'processingCompleted': DateTime.now().toIso8601String(),
      },
    };

    request.add(utf8.encode(jsonEncode(playbackData)));
    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);

    if (response.statusCode == 201) {
      print('✅ Created playback record: $playbackId');

      // Update the arena room to link to this playback
      print('🔗 Linking arena room to playback...');

      final updateRequest = await client.patchUrl(
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

      if (updateResponse.statusCode == 200) {
        print('✅ Arena room updated with playback link');
      } else {
        print('❌ Failed to update arena room: ${updateResponse.statusCode}');
      }

    } else {
      print('❌ Failed to create playback: ${response.statusCode} - $responseBody');
    }

  } catch (e) {
    print('❌ Error creating playback: $e');
  }

  // Now create timeline data for this playback
  print('\n📝 Creating timeline data for real playback...');

  final timelineSegments = [
    {
      'playbackId': playbackId,
      'startTime': 0,
      'endTime': 60,
      'speakerId': 'debater1',
      'speakerRole': 'affirmative',
      'segmentType': 'opening',
      'phase': 'opening_affirmative',
      'title': 'Opening Statement - The Only Way Affirmative',
      'description': 'The affirmative speaker presents their argument',
      'isSkippable': false,
      'order': 0,
    },
    {
      'playbackId': playbackId,
      'startTime': 60,
      'endTime': 120,
      'speakerId': 'debater2',
      'speakerRole': 'negative',
      'segmentType': 'opening',
      'phase': 'opening_negative',
      'title': 'Opening Statement - The Only Way Negative',
      'description': 'The negative speaker presents their counter-argument',
      'isSkippable': false,
      'order': 1,
    },
    {
      'playbackId': playbackId,
      'startTime': 120,
      'endTime': 180,
      'speakerId': 'moderator',
      'speakerRole': 'moderator',
      'segmentType': 'closing',
      'phase': 'final_statements',
      'title': 'Debate Conclusion',
      'description': 'Final statements and wrap-up',
      'isSkippable': true,
      'order': 2,
    },
  ];

  for (final segment in timelineSegments) {
    try {
      final request = await client.postUrl(
        Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/playback_timeline/documents')
      );

      request.headers.set('Content-Type', 'application/json');
      request.headers.set('X-Appwrite-Project', projectId);
      request.headers.set('X-Appwrite-Key', apiKey);

      final data = jsonEncode({
        'documentId': 'timeline_${segment['order']}_${DateTime.now().millisecondsSinceEpoch}',
        'data': segment,
      });

      request.add(utf8.encode(data));
      final response = await request.close();

      if (response.statusCode == 201) {
        print('  ✅ Created timeline segment: ${segment['title']}');
      }

    } catch (e) {
      print('  ❌ Error creating timeline segment: $e');
    }
  }

  client.close();
  print('\n🎉 Real arena room now has a complete playback with timeline!');
}