// ignore_for_file: avoid_print
// This is a utility script for database schema updates, not production code.
// Print statements are appropriate for console output.

import 'dart:io';
import 'dart:convert';

/// Standalone script to update Appwrite participant collections schema
/// This script uses direct HTTP calls to Appwrite API instead of Flutter SDK

void main() async {
  print('🔄 Starting Role Authority System database schema update...');

  const endpoint = 'https://cloud.appwrite.io/v1';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  // Get API key from environment or prompt
  String? apiKey = Platform.environment['APPWRITE_API_KEY'];
  if (apiKey == null || apiKey.isEmpty || apiKey == 'mock-api-key') {
    print('⚠️ Please set APPWRITE_API_KEY environment variable with your actual API key');
    print('You can get it from: https://cloud.appwrite.io/console/project-$projectId/settings/keys');
    exit(1);
  }

  final client = HttpClient();

  // Collections to update
  final collections = [
    'arena_participants',
    'room_participants',
    'debate_discussion_participants',
  ];

  for (final collectionId in collections) {
    print('\n📝 Updating collection: $collectionId');

    try {
      // Add role field
      await createAttribute(client, endpoint, projectId, apiKey, databaseId, collectionId, {
        'key': 'role',
        'type': 'string',
        'size': 50,
        'required': true,
        'default': 'audience'
      });
      print('✅ Added role field');

      // Add eventId field
      await createAttribute(client, endpoint, projectId, apiKey, databaseId, collectionId, {
        'key': 'eventId',
        'type': 'string',
        'size': 100,
        'required': false
      });
      print('✅ Added eventId field');

      // Add roleUpdatedAt field
      await createAttribute(client, endpoint, projectId, apiKey, databaseId, collectionId, {
        'key': 'roleUpdatedAt',
        'type': 'datetime',
        'required': false
      });
      print('✅ Added roleUpdatedAt field');

      // Add lastHeartbeat field
      await createAttribute(client, endpoint, projectId, apiKey, databaseId, collectionId, {
        'key': 'lastHeartbeat',
        'type': 'datetime',
        'required': false
      });
      print('✅ Added lastHeartbeat field');

      // Add isConnected field
      await createAttribute(client, endpoint, projectId, apiKey, databaseId, collectionId, {
        'key': 'isConnected',
        'type': 'boolean',
        'required': true,
        'default': true
      });
      print('✅ Added isConnected field');

      // Create indexes
      await createIndex(client, endpoint, projectId, apiKey, databaseId, collectionId, {
        'key': 'role_index',
        'type': 'key',
        'attributes': ['role']
      });
      print('✅ Created role index');

      await createIndex(client, endpoint, projectId, apiKey, databaseId, collectionId, {
        'key': 'room_role_index',
        'type': 'key',
        'attributes': ['roomId', 'role']
      });
      print('✅ Created room_role composite index');

      await createIndex(client, endpoint, projectId, apiKey, databaseId, collectionId, {
        'key': 'eventId_index',
        'type': 'key',
        'attributes': ['eventId']
      });
      print('✅ Created eventId index');

      await createIndex(client, endpoint, projectId, apiKey, databaseId, collectionId, {
        'key': 'heartbeat_index',
        'type': 'key',
        'attributes': ['lastHeartbeat'],
        'orders': ['DESC']
      });
      print('✅ Created heartbeat index');

      print('🎉 Successfully updated $collectionId');

    } catch (e) {
      print('❌ Error updating $collectionId: $e');
    }

    // Wait between collections to avoid rate limits
    await Future.delayed(Duration(seconds: 2));
  }

  client.close();
  print('\n🚀 Role Authority System schema update completed!');
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