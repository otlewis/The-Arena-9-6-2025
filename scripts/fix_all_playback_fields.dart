import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  print('🔧 Adding missing fields to all playback collections...');

  // Fields to add to each collection
  final collectionsToFix = {
    'playback_timeline': [
      {'key': 'isSkippable', 'type': 'boolean', 'default': true},
    ],
    'playback_participants': [
      {'key': 'isActive', 'type': 'boolean', 'default': true},
    ],
    'playback_events': [
      {'key': 'isVisible', 'type': 'boolean', 'default': true},
    ],
  };

  for (final collectionEntry in collectionsToFix.entries) {
    final collectionId = collectionEntry.key;
    final fields = collectionEntry.value;

    print('\n📝 Working on $collectionId collection...');

    for (final field in fields) {
      try {
        print('Adding ${field['key']} field...');

        final request = await client.postUrl(
          Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/$collectionId/attributes/${field['type']}')
        );

        request.headers.set('Content-Type', 'application/json');
        request.headers.set('X-Appwrite-Project', projectId);
        request.headers.set('X-Appwrite-Key', apiKey);

        final data = jsonEncode({
          'key': field['key'],
          'required': false,
          'default': field['default'],
        });

        request.add(utf8.encode(data));
        final response = await request.close();
        final responseBody = await utf8.decodeStream(response);

        if (response.statusCode == 201 || response.statusCode == 202) {
          print('✅ Added ${field['key']} field to $collectionId');
        } else {
          print('❌ Error adding ${field['key']} to $collectionId: ${response.statusCode} - $responseBody');
        }

        // Wait a bit between requests
        await Future.delayed(Duration(milliseconds: 500));

      } catch (e) {
        print('❌ Error adding ${field['key']} to $collectionId: $e');
      }
    }
  }

  client.close();
  print('\n✅ Finished adding missing fields to all collections');
  print('\n🧪 Now let\'s create some test data...');

  // Create test timeline data
  await createTestTimelineData();
  print('✅ Test timeline data created');

  // Create test participant data
  await createTestParticipantData();
  print('✅ Test participant data created');

  // Create test event data
  await createTestEventData();
  print('✅ Test event data created');

  print('\n🎉 All playback collections are now ready with test data!');
}

Future<void> createTestTimelineData() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';

  final client = HttpClient();

  final timelineSegments = [
    {
      'playbackId': 'test_playback_1759101220145',
      'startTime': 0,
      'endTime': 60,
      'speakerId': 'user_123',
      'speakerRole': 'affirmative',
      'segmentType': 'opening',
      'phase': 'opening_affirmative',
      'title': 'Opening Statement - Pro Pineapple',
      'description': 'The affirmative speaker makes their case for pineapple on pizza',
      'isSkippable': false,
      'order': 0,
    },
    {
      'playbackId': 'test_playback_1759101220145',
      'startTime': 60,
      'endTime': 120,
      'speakerId': 'user_456',
      'speakerRole': 'negative',
      'segmentType': 'opening',
      'phase': 'opening_negative',
      'title': 'Opening Statement - Against Pineapple',
      'description': 'The negative speaker argues against pineapple on pizza',
      'isSkippable': false,
      'order': 1,
    },
    {
      'playbackId': 'test_playback_1759101220145',
      'startTime': 120,
      'endTime': 180,
      'speakerId': 'user_789',
      'speakerRole': 'moderator',
      'segmentType': 'closing',
      'phase': 'final_statements',
      'title': 'Moderator Closing',
      'description': 'Final thoughts and wrap-up',
      'isSkippable': true,
      'order': 2,
    },
  ];

  for (final segment in timelineSegments) {
    try {
      final request = await client.postUrl(
        Uri.parse('https://cloud.appwrite.io/v1/databases/arena_db/collections/playback_timeline/documents')
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
}

Future<void> createTestParticipantData() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';

  final client = HttpClient();

  final participants = [
    {
      'playbackId': 'test_playback_1759101220145',
      'userId': 'user_123',
      'joinedAt': DateTime.now().subtract(Duration(minutes: 5)).toIso8601String(),
      'leftAt': null,
      'currentPosition': 45,
      'playbackSpeed': 1.0,
      'isActive': true,
      'watchTime': 45,
    },
  ];

  for (final participant in participants) {
    try {
      final request = await client.postUrl(
        Uri.parse('https://cloud.appwrite.io/v1/databases/arena_db/collections/playback_participants/documents')
      );

      request.headers.set('Content-Type', 'application/json');
      request.headers.set('X-Appwrite-Project', projectId);
      request.headers.set('X-Appwrite-Key', apiKey);

      final data = jsonEncode({
        'documentId': 'participant_${participant['userId']}_${DateTime.now().millisecondsSinceEpoch}',
        'data': participant,
      });

      request.add(utf8.encode(data));
      final response = await request.close();

      if (response.statusCode == 201) {
        print('  ✅ Created participant record');
      }

    } catch (e) {
      print('  ❌ Error creating participant: $e');
    }
  }

  client.close();
}

Future<void> createTestEventData() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';

  final client = HttpClient();

  final events = [
    {
      'playbackId': 'test_playback_1759101220145',
      'timestamp': 30,
      'eventType': 'chat_message',
      'userId': 'audience_1',
      'userName': 'PizzaLover42',
      'userRole': 'audience',
      'content': 'Team pineapple! 🍍',
      'isVisible': true,
      'metadata': '{"emoji": "🍍"}',
    },
    {
      'playbackId': 'test_playback_1759101220145',
      'timestamp': 75,
      'eventType': 'reaction',
      'userId': 'audience_2',
      'userName': 'ItalianChef',
      'userRole': 'audience',
      'content': 'disagree',
      'isVisible': true,
      'metadata': '{"reaction_type": "disagree"}',
    },
    {
      'playbackId': 'test_playback_1759101220145',
      'timestamp': 150,
      'eventType': 'score_update',
      'userId': 'judge_1',
      'userName': 'Judge Smith',
      'userRole': 'judge',
      'content': 'Scored affirmative: 8/10',
      'isVisible': false,
      'metadata': '{"score": 8, "team": "affirmative"}',
    },
  ];

  for (final event in events) {
    try {
      final request = await client.postUrl(
        Uri.parse('https://cloud.appwrite.io/v1/databases/arena_db/collections/playback_events/documents')
      );

      request.headers.set('Content-Type', 'application/json');
      request.headers.set('X-Appwrite-Project', projectId);
      request.headers.set('X-Appwrite-Key', apiKey);

      final data = jsonEncode({
        'documentId': 'event_${event['timestamp']}_${DateTime.now().millisecondsSinceEpoch}',
        'data': event,
      });

      request.add(utf8.encode(data));
      final response = await request.close();

      if (response.statusCode == 201) {
        print('  ✅ Created event: ${event['eventType']} at ${event['timestamp']}s');
      }

    } catch (e) {
      print('  ❌ Error creating event: $e');
    }
  }

  client.close();
}