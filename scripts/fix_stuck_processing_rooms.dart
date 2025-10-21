import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Script to find and fix all arena rooms stuck in "processing" status
/// Run with: dart run fix_stuck_processing_rooms.dart
void main() async {
  // Load .env file manually
  final envFile = File('.env');
  final envVars = <String, String>{};

  if (await envFile.exists()) {
    final lines = await envFile.readAsLines();
    for (var line in lines) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;
      final parts = line.split('=');
      if (parts.length == 2) {
        envVars[parts[0].trim()] = parts[1].trim();
      }
    }
  }

  final endpoint = envVars['APPWRITE_ENDPOINT'] ?? '';
  final projectId = envVars['APPWRITE_PROJECT_ID'] ?? '';
  final apiKey = envVars['APPWRITE_API_KEY'] ?? '';
  final databaseId = envVars['APPWRITE_DATABASE_ID'] ?? 'arena_db';

  if (endpoint.isEmpty || projectId.isEmpty || apiKey.isEmpty) {
    print('❌ Missing Appwrite credentials in .env file');
    return;
  }

  try {
    print('🔍 Searching for rooms stuck in processing status...\n');

    // Get all arena rooms
    final response = await http.get(
      Uri.parse('$endpoint/databases/$databaseId/collections/arena_rooms/documents?limit=500'),
      headers: {
        'X-Appwrite-Project': projectId,
        'X-Appwrite-Key': apiKey,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      print('❌ Failed to fetch rooms: ${response.statusCode}');
      print(response.body);
      return;
    }

    final data = json.decode(response.body);
    final documents = data['documents'] as List;

    print('📊 Found ${documents.length} total arena rooms\n');

    // Find rooms stuck in processing
    List<Map<String, dynamic>> stuckRooms = [];

    for (var room in documents) {
      final status = room['status'];
      final enablePlayback = room['enablePlayback'] ?? false;
      final createdAt = DateTime.parse(room['\$createdAt']);
      final hoursSinceCreation = DateTime.now().difference(createdAt).inHours;

      // Check if room is stuck in processing (more than 24 hours)
      if (status == 'processing' && hoursSinceCreation > 24) {
        stuckRooms.add({
          'id': room['\$id'],
          'topic': room['topic'] ?? 'Unknown',
          'status': status,
          'enablePlayback': enablePlayback,
          'createdAt': room['\$createdAt'],
          'hoursSinceCreation': hoursSinceCreation,
        });
      }
    }

    if (stuckRooms.isEmpty) {
      print('✅ No rooms stuck in processing status!');
      return;
    }

    print('⚠️  Found ${stuckRooms.length} rooms stuck in processing:\n');

    for (var i = 0; i < stuckRooms.length; i++) {
      final room = stuckRooms[i];
      print('${i + 1}. ${room['topic']}');
      print('   ID: ${room['id']}');
      print('   Created: ${room['createdAt']}');
      print('   Hours stuck: ${room['hoursSinceCreation']}');
      print('   Playback enabled: ${room['enablePlayback']}');
      print('');
    }

    print('🔧 Fixing stuck rooms...\n');

    int fixedCount = 0;
    int errorCount = 0;

    for (var room in stuckRooms) {
      try {
        final updateResponse = await http.patch(
          Uri.parse('$endpoint/databases/$databaseId/collections/arena_rooms/documents/${room['id']}'),
          headers: {
            'X-Appwrite-Project': projectId,
            'X-Appwrite-Key': apiKey,
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'status': 'completed',
            'playbackStatus': 'failed',
          }),
        );

        if (updateResponse.statusCode == 200) {
          print('✅ Fixed: ${room['topic']} (${room['id']})');
          fixedCount++;
        } else {
          print('❌ Error fixing ${room['topic']}: ${updateResponse.statusCode}');
          print('   ${updateResponse.body}');
          errorCount++;
        }
      } catch (e) {
        print('❌ Error fixing ${room['topic']}: $e');
        errorCount++;
      }
    }

    print('\n📈 Summary:');
    print('   Total stuck rooms: ${stuckRooms.length}');
    print('   Successfully fixed: $fixedCount');
    print('   Errors: $errorCount');
    print('\n✨ Done!');

  } catch (e) {
    print('❌ Error: $e');
  }
}
