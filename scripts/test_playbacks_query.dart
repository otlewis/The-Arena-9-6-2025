import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const apiKey = 'standard_a2e04fb6446a4f68dd8bec1b65deb704e7dc116d73c4a1a5b8673756127962794f87c4b0baa22706a92b672766e5305273b43603f7dd7ebfb52e072dfa2549483104fe991b477913315bab26040dfe4880700b290759df3281af25e2a92b74728dfcf7486ede15ec03a424232a08c6af65bc140a0d2539a3afdf01335d7d0b77';
  const projectId = '683a37a8003719978879';
  const databaseId = 'arena_db';

  final client = HttpClient();

  print('🔍 Testing getAvailablePlaybacks query (ALL playbacks)...');

  try {
    // Test the exact query used by getAvailablePlaybacks (without userId filter)
    final request = await client.postUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_playbacks/documents')
    );

    request.headers.set('Content-Type', 'application/json');
    request.headers.set('X-Appwrite-Project', projectId);
    request.headers.set('X-Appwrite-Key', apiKey);

    // Simulate the query with status=ready and visibility=public
    final queryData = {
      'queries': [
        'equal("status", "ready")',
        'equal("visibility", "public")',
        'orderDesc("recordedAt")',
        'limit(50)',
      ]
    };

    request.add(utf8.encode(jsonEncode(queryData)));
    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);

    print('Query Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      print('✅ Found ${data['total']} playbacks matching filters');

      if (data['documents'] != null && data['documents'].length > 0) {
        print('\n📹 Available playbacks:');
        for (var doc in data['documents']) {
          print('- ${doc['title']}');
          print('  Status: ${doc['status']}, Visibility: ${doc['visibility']}');
          print('  Debater1: ${doc['debater1Id']}, Debater2: ${doc['debater2Id']}');
          print('  Moderator: ${doc['moderatorId']}');
          print('');
        }
      } else {
        print('❌ No documents returned despite total > 0');
      }
    } else {
      print('❌ Query failed: $responseBody');
    }

  } catch (e) {
    print('❌ Error testing query: $e');
  }

  print('\n🔍 Testing without any filters (raw data)...');

  try {
    // Test without any filters to see all records
    final request = await client.getUrl(
      Uri.parse('https://cloud.appwrite.io/v1/databases/$databaseId/collections/arena_playbacks/documents')
    );

    request.headers.set('X-Appwrite-Project', projectId);
    request.headers.set('X-Appwrite-Key', apiKey);

    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      print('✅ Raw data shows ${data['total']} total playbacks');

      if (data['documents'] != null) {
        for (var doc in data['documents']) {
          print('- ${doc['title']}');
          print('  Status: ${doc['status']}, Visibility: ${doc['visibility']}');
          print('  Ready filter: ${doc['status'] == 'ready'}');
          print('  Public filter: ${doc['visibility'] == 'public'}');
          print('');
        }
      }
    }

  } catch (e) {
    print('❌ Error getting raw data: $e');
  }

  client.close();
}