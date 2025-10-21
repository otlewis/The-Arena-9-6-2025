import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  print('✅ Verifying permissions fix is working...');

  try {
    // Test the exact query that Flutter app uses
    final uri = Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_playbacks/documents');

    final request = await client.getUrl(uri);
    request.headers.set('X-Appwrite-Project', projectId);
    request.headers.set('X-Appwrite-Key', apiKey);

    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);

    print('Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      print('✅ Query successful!');
      print('📊 Total documents: ${data['total']}');

      if (data['documents'] != null && data['documents'].length > 0) {
        print('\\n📹 Playback documents found:');
        for (var doc in data['documents']) {
          print('- Title: ${doc['title']}');
          print('  Status: ${doc['status']}');
          print('  Visibility: ${doc['visibility']}');
          print('  Document Permissions: ${doc['\$permissions']}');
          print('  ✅ Should be visible to authenticated users!');
        }

        // Test with filters that the app uses
        print('\\n🔍 Testing with app filters (status=ready, visibility=public)...');
        final filteredUri = Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_playbacks/documents');

        final filteredRequest = await client.postUrl(filteredUri);
        filteredRequest.headers.set('X-Appwrite-Project', projectId);
        filteredRequest.headers.set('X-Appwrite-Key', apiKey);
        filteredRequest.headers.set('Content-Type', 'application/json');

        final queryData = {
          'queries': [
            'equal("status", "ready")',
            'equal("visibility", "public")',
            'orderDesc("\$createdAt")',
            'limit(50)',
          ]
        };

        filteredRequest.write(jsonEncode(queryData));

        final filteredResponse = await filteredRequest.close();
        final filteredBody = await utf8.decodeStream(filteredResponse);

        if (filteredResponse.statusCode == 200) {
          final filteredData = jsonDecode(filteredBody);
          print('✅ Filtered query successful!');
          print('📊 Filtered results: ${filteredData['total']} documents');

          if (filteredData['total'] > 0) {
            print('🎉 SUCCESS: Authenticated users should now see playback data!');
          } else {
            print('⚠️ Warning: Filtered query returned 0 results. Check document values.');
          }
        } else {
          print('❌ Filtered query failed: ${filteredResponse.statusCode}');
          print('Response: $filteredBody');
        }

      } else {
        print('❌ No documents found');
      }
    } else {
      print('❌ Query failed: $responseBody');
    }

  } catch (e) {
    print('❌ Error: $e');
  }

  client.close();
}