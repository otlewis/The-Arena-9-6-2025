// ignore_for_file: avoid_print, deprecated_member_use
import 'package:appwrite/appwrite.dart';

// Test the exact same query used by the app
void main() async {
  print('🔍 Testing exact app query using Appwrite SDK...');

  // Note: This script requires server-side SDK with API key
  // For now, using client SDK. Use Appwrite CLI or server SDK for production.
  final client = Client()
      .setEndpoint('https://cloud.appwrite.io/v1')
      .setProject('683a37a8003719978879');

  final databases = Databases(client);

  try {
    print('📱 Testing main query with filters...');

    List<String> queries = [
      Query.equal('status', 'ready'),
      Query.equal('visibility', 'public'),
      Query.orderDesc('\$createdAt'),
      Query.limit(50),
      Query.offset(0),
    ];

    print('🔍 Executing query with ${queries.length} filters');

    final response = await databases.listDocuments(
      databaseId: 'arena_db',
      collectionId: 'arena_playbacks',
      queries: queries,
    );

    print('✅ Found ${response.documents.length} playback documents');

    for (final doc in response.documents) {
      print('📹 Document: ${doc.data['title']} - status: ${doc.data['status']}, visibility: ${doc.data['visibility']}');
    }

    if (response.documents.isEmpty) {
      print('\n🔧 Trying debug query without filters...');
      final debugResponse = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_playbacks',
        queries: [Query.limit(10)],
      );
      print('📊 Debug query found ${debugResponse.documents.length} total documents');

      for (final doc in debugResponse.documents) {
        print('📋 All docs: ${doc.data['title']} - status: ${doc.data['status']}, visibility: ${doc.data['visibility']}');
      }
    }

  } catch (e) {
    print('❌ Error: $e');
  }

  print('🎉 Query test complete!');
}