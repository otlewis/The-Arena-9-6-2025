import 'dart:io';
import 'dart:convert';

/// Fix permissions for all existing user profiles using HTTP
Future<void> main() async {
  print('🔧 Starting user profile permissions fix...');

  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  try {
    // Get all user profiles
    print('📊 Fetching all user profiles...');
    final listRequest = await client.getUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/users/documents'),
    );
    listRequest.headers.set('X-Appwrite-Project', projectId);
    listRequest.headers.set('X-Appwrite-Key', apiKey);

    final listResponse = await listRequest.close();
    final listBody = await utf8.decodeStream(listResponse);

    print('Response status: ${listResponse.statusCode}');
    print('Response body: ${listBody.substring(0, listBody.length > 200 ? 200 : listBody.length)}...');

    final listData = jsonDecode(listBody);

    if (listData['documents'] == null) {
      print('❌ Error: No documents found in response');
      print('Full response: $listBody');
      return;
    }

    final documents = listData['documents'] as List;
    print('✅ Found ${documents.length} user profiles');

    int fixed = 0;
    int failed = 0;

    for (final doc in documents) {
      final userId = doc['\$id'];
      final userName = doc['name'] ?? 'Unknown';

      try {
        print('🔄 Fixing permissions for: $userName ($userId)');

        // Update the document with proper permissions
        final updateRequest = await client.patchUrl(
          Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/users/documents/$userId'),
        );
        updateRequest.headers.set('X-Appwrite-Project', projectId);
        updateRequest.headers.set('X-Appwrite-Key', apiKey);
        updateRequest.headers.set('Content-Type', 'application/json');

        final updateBody = jsonEncode({
          'data': doc,
          'permissions': [
            'read("user:$userId")',
            'update("user:$userId")',
            'delete("user:$userId")',
            'read("users")',
          ],
        });

        updateRequest.write(updateBody);
        final updateResponse = await updateRequest.close();
        final responseBody = await utf8.decodeStream(updateResponse);

        if (updateResponse.statusCode == 200) {
          fixed++;
          print('✅ Fixed: $userName');
        } else {
          failed++;
          print('❌ Failed to fix $userName: $responseBody');
        }
      } catch (e) {
        failed++;
        print('❌ Failed to fix $userName: $e');
      }
    }

    print('');
    print('🎉 COMPLETE!');
    print('✅ Fixed: $fixed profiles');
    print('❌ Failed: $failed profiles');
  } catch (e) {
    print('❌ Error: $e');
  } finally {
    client.close();
  }
}
