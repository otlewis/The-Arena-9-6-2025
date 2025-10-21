import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  // This would be the session token from an authenticated user
  // For now, let's test collection-level permissions
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';

  final client = HttpClient();

  print('🔍 Testing collection permissions and access...');

  try {
    // First, let's check the collection attributes to see permissions
    final collectionUri = Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_playbacks');

    final collectionRequest = await client.getUrl(collectionUri);
    collectionRequest.headers.set('X-Appwrite-Project', projectId);
    collectionRequest.headers.set('X-Appwrite-Key', apiKey);

    final collectionResponse = await collectionRequest.close();
    final collectionBody = await utf8.decodeStream(collectionResponse);

    print('Collection status: ${collectionResponse.statusCode}');

    if (collectionResponse.statusCode == 200) {
      final collectionData = jsonDecode(collectionBody);
      print('✅ Collection found!');
      print('📋 Collection permissions: ${collectionData['\$permissions']}');
      print('📋 Document security enabled: ${collectionData['documentSecurity']}');

      // Now test document query with API key
      print('\\n🔍 Testing document query with API key...');
      final docsUri = Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_playbacks/documents');

      final docsRequest = await client.getUrl(docsUri);
      docsRequest.headers.set('X-Appwrite-Project', projectId);
      docsRequest.headers.set('X-Appwrite-Key', apiKey);

      final docsResponse = await docsRequest.close();
      final docsBody = await utf8.decodeStream(docsResponse);

      print('Documents query status: ${docsResponse.statusCode}');

      if (docsResponse.statusCode == 200) {
        final docsData = jsonDecode(docsBody);
        print('✅ Documents query successful!');
        print('📊 Total documents: ${docsData['total']}');

        if (docsData['documents'] != null && docsData['documents'].length > 0) {
          for (var doc in docsData['documents']) {
            print('📋 Document: ${doc['title']} - permissions: ${doc['\$permissions']}');
          }
        }
      } else {
        print('❌ Documents query failed: $docsBody');
      }

    } else {
      print('❌ Collection query failed: $collectionBody');
    }

  } catch (e) {
    print('❌ Error: $e');
  }

  client.close();
}