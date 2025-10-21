import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  print('🔧 Fixing arena_playbacks collection permissions...');

  try {
    // Update the collection with proper permissions
    final uri = Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_playbacks');

    final request = await client.putUrl(uri);
    request.headers.set('X-Appwrite-Project', projectId);
    request.headers.set('X-Appwrite-Key', apiKey);
    request.headers.set('Content-Type', 'application/json');

    // Add read permissions for any authenticated user
    final updateData = {
      'name': 'Arena Playbacks',
      'permissions': [
        'read("any")', // Allow any user to read from this collection
      ],
      'documentSecurity': true, // Keep document-level security enabled
      'enabled': true,
    };

    final jsonData = jsonEncode(updateData);
    request.write(jsonData);

    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);

    print('Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      print('✅ Collection permissions updated successfully!');
      print('📋 New collection permissions: ${data['\$permissions']}');
      print('📋 Document security: ${data['documentSecurity']}');
    } else {
      print('❌ Failed to update collection permissions: $responseBody');
    }

  } catch (e) {
    print('❌ Error: $e');
  }

  client.close();
}