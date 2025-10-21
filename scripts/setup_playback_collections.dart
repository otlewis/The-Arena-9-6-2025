// ignore_for_file: avoid_print
// This is a utility script for database schema setup, not production code.
// Print statements are appropriate for console output.

import 'dart:io';
import 'dart:convert';

/// Setup script for Arena Playback system database collections
/// Creates the necessary collections and attributes for recording and replaying debates

void main() async {
  print('🎬 Setting up Arena Playback System database schema...');

  const endpoint = 'https://cloud.appwrite.io/v1';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  // Get API key from environment
  String? apiKey = Platform.environment['APPWRITE_API_KEY'];
  if (apiKey == null || apiKey.isEmpty || apiKey == 'mock-api-key') {
    print('⚠️ Please set APPWRITE_API_KEY environment variable with your actual API key');
    print('You can get it from: https://cloud.appwrite.io/console/project-$projectId/settings/keys');
    exit(1);
  }

  final client = HttpClient();

  try {
    // 1. Update arena_rooms collection to support playback
    print('\n📝 Updating arena_rooms collection for playback support...');
    await updateArenaRoomsForPlayback(client, endpoint, projectId, apiKey, databaseId);

    // 2. Create arena_playbacks collection
    print('\n📝 Creating arena_playbacks collection...');
    await createArenaPlaybacksCollection(client, endpoint, projectId, apiKey, databaseId);

    // 3. Create playback_participants collection
    print('\n📝 Creating playback_participants collection...');
    await createPlaybackParticipantsCollection(client, endpoint, projectId, apiKey, databaseId);

    // 4. Create playback_timeline collection
    print('\n📝 Creating playback_timeline collection...');
    await createPlaybackTimelineCollection(client, endpoint, projectId, apiKey, databaseId);

    // 5. Create playback_events collection
    print('\n📝 Creating playback_events collection...');
    await createPlaybackEventsCollection(client, endpoint, projectId, apiKey, databaseId);

    print('\n🎉 Arena Playback System database schema setup completed successfully!');
    print('\n📊 Collections Summary:');
    print('├── arena_rooms (updated with playback fields)');
    print('├── arena_playbacks (main playback metadata)');
    print('├── playback_participants (who joins playback rooms)');
    print('├── playback_timeline (speaker segments and timing)');
    print('└── playback_events (chat messages, reactions, score events)');

  } catch (e) {
    print('❌ Error setting up playback schema: $e');
    exit(1);
  } finally {
    client.close();
  }
}

/// Update arena_rooms collection to support playback recording
Future<void> updateArenaRoomsForPlayback(
  HttpClient client,
  String endpoint,
  String projectId,
  String apiKey,
  String databaseId,
) async {
  final collectionId = 'arena_rooms';

  // Add playback-related fields to arena_rooms
  final attributes = [
    {
      'key': 'enablePlayback',
      'type': 'boolean',
      'required': true,
      'default': false,
    },
    {
      'key': 'recordingStatus',
      'type': 'string',
      'size': 50,
      'required': false,
      'default': null, // null, recording, processing, ready, failed
    },
    {
      'key': 'recordingStarted',
      'type': 'datetime',
      'required': false,
    },
    {
      'key': 'recordingEnded',
      'type': 'datetime',
      'required': false,
    },
    {
      'key': 'playbackId',
      'type': 'string',
      'size': 50,
      'required': false,
    },
  ];

  for (final attr in attributes) {
    try {
      await createAttribute(client, endpoint, projectId, apiKey, databaseId, collectionId, attr);
      print('✅ Added ${attr['key']} field to arena_rooms');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        print('ℹ️ Field ${attr['key']} already exists in arena_rooms');
      } else {
        print('❌ Error adding ${attr['key']}: $e');
      }
    }
  }

  // Add indexes
  final indexes = [
    {
      'key': 'playback_enabled_index',
      'type': 'key',
      'attributes': ['enablePlayback']
    },
    {
      'key': 'recording_status_index',
      'type': 'key',
      'attributes': ['recordingStatus']
    },
    {
      'key': 'playback_id_index',
      'type': 'key',
      'attributes': ['playbackId']
    },
  ];

  for (final index in indexes) {
    try {
      await createIndex(client, endpoint, projectId, apiKey, databaseId, collectionId, index);
      print('✅ Created ${index['key']} index');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        print('ℹ️ Index ${index['key']} already exists');
      } else {
        print('❌ Error creating ${index['key']}: $e');
      }
    }
  }
}

/// Create arena_playbacks collection for storing playback metadata
Future<void> createArenaPlaybacksCollection(
  HttpClient client,
  String endpoint,
  String projectId,
  String apiKey,
  String databaseId,
) async {
  final collectionId = 'arena_playbacks';

  // Create collection first
  try {
    await createCollection(client, endpoint, projectId, apiKey, databaseId, {
      'collectionId': collectionId,
      'name': 'Arena Playbacks',
      'documentSecurity': true,
      'enabled': true,
    });
    print('✅ Created arena_playbacks collection');
  } catch (e) {
    if (e.toString().contains('already exists')) {
      print('ℹ️ Collection arena_playbacks already exists');
    } else {
      throw e;
    }
  }

  // Add attributes
  final attributes = [
    {'key': 'originalRoomId', 'type': 'string', 'size': 50, 'required': true},
    {'key': 'title', 'type': 'string', 'size': 200, 'required': true},
    {'key': 'topic', 'type': 'string', 'size': 500, 'required': true},
    {'key': 'description', 'type': 'string', 'size': 1000, 'required': false},
    {'key': 'audioUrl', 'type': 'string', 'size': 500, 'required': true},
    {'key': 'audioFormat', 'type': 'string', 'size': 10, 'required': true, 'default': 'mp3'},
    {'key': 'duration', 'type': 'integer', 'required': true}, // seconds
    {'key': 'fileSize', 'type': 'integer', 'required': true}, // bytes
    {'key': 'status', 'type': 'string', 'size': 20, 'required': true, 'default': 'processing'},
    {'key': 'visibility', 'type': 'string', 'size': 20, 'required': true, 'default': 'public'},
    {'key': 'debater1Id', 'type': 'string', 'size': 50, 'required': true},
    {'key': 'debater2Id', 'type': 'string', 'size': 50, 'required': true},
    {'key': 'moderatorId', 'type': 'string', 'size': 50, 'required': false},
    {'key': 'winnerSide', 'type': 'string', 'size': 20, 'required': false},
    {'key': 'totalJudges', 'type': 'integer', 'required': false, 'default': 0},
    {'key': 'affirmativeVotes', 'type': 'integer', 'required': false, 'default': 0},
    {'key': 'negativeVotes', 'type': 'integer', 'required': false, 'default': 0},
    {'key': 'viewCount', 'type': 'integer', 'required': true, 'default': 0},
    {'key': 'likeCount', 'type': 'integer', 'required': true, 'default': 0},
    {'key': 'recordedAt', 'type': 'datetime', 'required': true},
    {'key': 'processingStarted', 'type': 'datetime', 'required': false},
    {'key': 'processingCompleted', 'type': 'datetime', 'required': false},
    {'key': 'tags', 'type': 'string', 'size': 500, 'required': false}, // JSON array of tags
    {'key': 'metadata', 'type': 'string', 'size': 2000, 'required': false}, // JSON metadata
  ];

  for (final attr in attributes) {
    try {
      await createAttribute(client, endpoint, projectId, apiKey, databaseId, collectionId, attr);
      print('✅ Added ${attr['key']} field');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        print('ℹ️ Field ${attr['key']} already exists');
      } else {
        print('❌ Error adding ${attr['key']}: $e');
      }
    }
  }

  // Add indexes
  final indexes = [
    {'key': 'original_room_index', 'type': 'key', 'attributes': ['originalRoomId']},
    {'key': 'status_index', 'type': 'key', 'attributes': ['status']},
    {'key': 'visibility_index', 'type': 'key', 'attributes': ['visibility']},
    {'key': 'recorded_at_index', 'type': 'key', 'attributes': ['recordedAt'], 'orders': ['DESC']},
    {'key': 'debater1_index', 'type': 'key', 'attributes': ['debater1Id']},
    {'key': 'debater2_index', 'type': 'key', 'attributes': ['debater2Id']},
    {'key': 'view_count_index', 'type': 'key', 'attributes': ['viewCount'], 'orders': ['DESC']},
    {'key': 'winner_index', 'type': 'key', 'attributes': ['winnerSide']},
  ];

  for (final index in indexes) {
    try {
      await createIndex(client, endpoint, projectId, apiKey, databaseId, collectionId, index);
      print('✅ Created ${index['key']} index');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        print('ℹ️ Index ${index['key']} already exists');
      } else {
        print('❌ Error creating ${index['key']}: $e');
      }
    }
  }
}

/// Create playback_participants collection for tracking who joins playback rooms
Future<void> createPlaybackParticipantsCollection(
  HttpClient client,
  String endpoint,
  String projectId,
  String apiKey,
  String databaseId,
) async {
  final collectionId = 'playback_participants';

  try {
    await createCollection(client, endpoint, projectId, apiKey, databaseId, {
      'collectionId': collectionId,
      'name': 'Playback Participants',
      'documentSecurity': true,
      'enabled': true,
    });
    print('✅ Created playback_participants collection');
  } catch (e) {
    if (e.toString().contains('already exists')) {
      print('ℹ️ Collection playback_participants already exists');
    } else {
      throw e;
    }
  }

  final attributes = [
    {'key': 'playbackId', 'type': 'string', 'size': 50, 'required': true},
    {'key': 'userId', 'type': 'string', 'size': 50, 'required': true},
    {'key': 'joinedAt', 'type': 'datetime', 'required': true},
    {'key': 'leftAt', 'type': 'datetime', 'required': false},
    {'key': 'currentPosition', 'type': 'integer', 'required': false, 'default': 0}, // seconds
    {'key': 'playbackSpeed', 'type': 'string', 'size': 10, 'required': false, 'default': '1x'},
    {'key': 'isActive', 'type': 'boolean', 'required': true, 'default': true},
    {'key': 'watchTime', 'type': 'integer', 'required': false, 'default': 0}, // total seconds watched
  ];

  for (final attr in attributes) {
    try {
      await createAttribute(client, endpoint, projectId, apiKey, databaseId, collectionId, attr);
      print('✅ Added ${attr['key']} field');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        print('ℹ️ Field ${attr['key']} already exists');
      } else {
        print('❌ Error adding ${attr['key']}: $e');
      }
    }
  }

  final indexes = [
    {'key': 'playback_user_index', 'type': 'key', 'attributes': ['playbackId', 'userId']},
    {'key': 'user_index', 'type': 'key', 'attributes': ['userId']},
    {'key': 'active_index', 'type': 'key', 'attributes': ['isActive']},
    {'key': 'joined_at_index', 'type': 'key', 'attributes': ['joinedAt'], 'orders': ['DESC']},
  ];

  for (final index in indexes) {
    try {
      await createIndex(client, endpoint, projectId, apiKey, databaseId, collectionId, index);
      print('✅ Created ${index['key']} index');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        print('ℹ️ Index ${index['key']} already exists');
      } else {
        print('❌ Error creating ${index['key']}: $e');
      }
    }
  }
}

/// Create playback_timeline collection for speaker segments and timing
Future<void> createPlaybackTimelineCollection(
  HttpClient client,
  String endpoint,
  String projectId,
  String apiKey,
  String databaseId,
) async {
  final collectionId = 'playback_timeline';

  try {
    await createCollection(client, endpoint, projectId, apiKey, databaseId, {
      'collectionId': collectionId,
      'name': 'Playback Timeline',
      'documentSecurity': true,
      'enabled': true,
    });
    print('✅ Created playback_timeline collection');
  } catch (e) {
    if (e.toString().contains('already exists')) {
      print('ℹ️ Collection playback_timeline already exists');
    } else {
      throw e;
    }
  }

  final attributes = [
    {'key': 'playbackId', 'type': 'string', 'size': 50, 'required': true},
    {'key': 'startTime', 'type': 'integer', 'required': true}, // seconds from start
    {'key': 'endTime', 'type': 'integer', 'required': true}, // seconds from start
    {'key': 'speakerId', 'type': 'string', 'size': 50, 'required': false}, // null for system events
    {'key': 'speakerRole', 'type': 'string', 'size': 30, 'required': false}, // debater1, debater2, moderator, judge
    {'key': 'segmentType', 'type': 'string', 'size': 30, 'required': true}, // speech, timer, system, break
    {'key': 'phase', 'type': 'string', 'size': 30, 'required': false}, // opening, rebuttal1, rebuttal2, closing, judging
    {'key': 'title', 'type': 'string', 'size': 100, 'required': false}, // "Opening Statement - Debater 1"
    {'key': 'description', 'type': 'string', 'size': 500, 'required': false},
    {'key': 'isSkippable', 'type': 'boolean', 'required': true, 'default': true},
    {'key': 'order', 'type': 'integer', 'required': true}, // order within the debate
  ];

  for (final attr in attributes) {
    try {
      await createAttribute(client, endpoint, projectId, apiKey, databaseId, collectionId, attr);
      print('✅ Added ${attr['key']} field');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        print('ℹ️ Field ${attr['key']} already exists');
      } else {
        print('❌ Error adding ${attr['key']}: $e');
      }
    }
  }

  final indexes = [
    {'key': 'playback_index', 'type': 'key', 'attributes': ['playbackId']},
    {'key': 'timeline_index', 'type': 'key', 'attributes': ['playbackId', 'order']},
    {'key': 'time_range_index', 'type': 'key', 'attributes': ['playbackId', 'startTime']},
    {'key': 'speaker_index', 'type': 'key', 'attributes': ['speakerId']},
    {'key': 'phase_index', 'type': 'key', 'attributes': ['phase']},
    {'key': 'segment_type_index', 'type': 'key', 'attributes': ['segmentType']},
  ];

  for (final index in indexes) {
    try {
      await createIndex(client, endpoint, projectId, apiKey, databaseId, collectionId, index);
      print('✅ Created ${index['key']} index');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        print('ℹ️ Index ${index['key']} already exists');
      } else {
        print('❌ Error creating ${index['key']}: $e');
      }
    }
  }
}

/// Create playback_events collection for chat messages, reactions, and score events
Future<void> createPlaybackEventsCollection(
  HttpClient client,
  String endpoint,
  String projectId,
  String apiKey,
  String databaseId,
) async {
  final collectionId = 'playback_events';

  try {
    await createCollection(client, endpoint, projectId, apiKey, databaseId, {
      'collectionId': collectionId,
      'name': 'Playback Events',
      'documentSecurity': true,
      'enabled': true,
    });
    print('✅ Created playback_events collection');
  } catch (e) {
    if (e.toString().contains('already exists')) {
      print('ℹ️ Collection playback_events already exists');
    } else {
      throw e;
    }
  }

  final attributes = [
    {'key': 'playbackId', 'type': 'string', 'size': 50, 'required': true},
    {'key': 'timestamp', 'type': 'integer', 'required': true}, // seconds from start
    {'key': 'eventType', 'type': 'string', 'size': 30, 'required': true}, // chat, reaction, score, system
    {'key': 'userId', 'type': 'string', 'size': 50, 'required': false}, // null for system events
    {'key': 'userName', 'type': 'string', 'size': 100, 'required': false},
    {'key': 'userRole', 'type': 'string', 'size': 30, 'required': false},
    {'key': 'content', 'type': 'string', 'size': 1000, 'required': false}, // message content or reaction emoji
    {'key': 'metadata', 'type': 'string', 'size': 500, 'required': false}, // JSON for additional data
    {'key': 'isVisible', 'type': 'boolean', 'required': true, 'default': true},
  ];

  for (final attr in attributes) {
    try {
      await createAttribute(client, endpoint, projectId, apiKey, databaseId, collectionId, attr);
      print('✅ Added ${attr['key']} field');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        print('ℹ️ Field ${attr['key']} already exists');
      } else {
        print('❌ Error adding ${attr['key']}: $e');
      }
    }
  }

  final indexes = [
    {'key': 'playback_index', 'type': 'key', 'attributes': ['playbackId']},
    {'key': 'timeline_index', 'type': 'key', 'attributes': ['playbackId', 'timestamp']},
    {'key': 'event_type_index', 'type': 'key', 'attributes': ['eventType']},
    {'key': 'user_index', 'type': 'key', 'attributes': ['userId']},
    {'key': 'visible_index', 'type': 'key', 'attributes': ['isVisible']},
  ];

  for (final index in indexes) {
    try {
      await createIndex(client, endpoint, projectId, apiKey, databaseId, collectionId, index);
      print('✅ Created ${index['key']} index');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        print('ℹ️ Index ${index['key']} already exists');
      } else {
        print('❌ Error creating ${index['key']}: $e');
      }
    }
  }
}

// Helper functions for HTTP operations
Future<void> createCollection(
  HttpClient client,
  String endpoint,
  String projectId,
  String apiKey,
  String databaseId,
  Map<String, dynamic> collectionData,
) async {
  final url = '$endpoint/databases/$databaseId/collections';

  final request = await client.postUrl(Uri.parse(url));
  request.headers.set('X-Appwrite-Response-Format', '1.6.0');
  request.headers.set('X-Appwrite-Project', projectId);
  request.headers.set('X-Appwrite-Key', apiKey);
  request.headers.set('Content-Type', 'application/json');

  request.write(jsonEncode(collectionData));

  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();

  if (response.statusCode >= 400) {
    throw Exception('HTTP ${response.statusCode}: $responseBody');
  }
}

Future<void> createAttribute(
  HttpClient client,
  String endpoint,
  String projectId,
  String apiKey,
  String databaseId,
  String collectionId,
  Map<String, dynamic> attributeData,
) async {
  final url = '$endpoint/databases/$databaseId/collections/$collectionId/attributes/${attributeData['type']}';

  final request = await client.postUrl(Uri.parse(url));
  request.headers.set('X-Appwrite-Response-Format', '1.6.0');
  request.headers.set('X-Appwrite-Project', projectId);
  request.headers.set('X-Appwrite-Key', apiKey);
  request.headers.set('Content-Type', 'application/json');

  request.write(jsonEncode(attributeData));

  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();

  if (response.statusCode >= 400) {
    if (responseBody.contains('already exists')) {
      // Attribute already exists, that's OK
      return;
    }
    throw Exception('HTTP ${response.statusCode}: $responseBody');
  }
}

Future<void> createIndex(
  HttpClient client,
  String endpoint,
  String projectId,
  String apiKey,
  String databaseId,
  String collectionId,
  Map<String, dynamic> indexData,
) async {
  final url = '$endpoint/databases/$databaseId/collections/$collectionId/indexes';

  final request = await client.postUrl(Uri.parse(url));
  request.headers.set('X-Appwrite-Response-Format', '1.6.0');
  request.headers.set('X-Appwrite-Project', projectId);
  request.headers.set('X-Appwrite-Key', apiKey);
  request.headers.set('Content-Type', 'application/json');

  request.write(jsonEncode(indexData));

  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();

  if (response.statusCode >= 400) {
    if (responseBody.contains('already exists')) {
      // Index already exists, that's OK
      return;
    }
    throw Exception('HTTP ${response.statusCode}: $responseBody');
  }
}