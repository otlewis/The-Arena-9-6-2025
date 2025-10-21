import 'package:appwrite/appwrite.dart';
import 'dart:io';

void main() async {
  // Initialize Appwrite client
  final client = Client()
      .setEndpoint('https://cloud.appwrite.io/v1')
      .setProject('arena')
      .setKey('standard_00d440e0d9e7f53faaccdfac1ecfe49e4c0b30f2c4770b75a5cbaba5ea6375ea2d6e68483697726bfe1b8d67d8c8bb447ff97fce0f13893b38c5fe46c315aeff46cb38d109055f59689663b6214b480b346fddf7009dc776f183abdd3b07e4ceb78477b769d5f0631b696f0f342d5541d224b4305b9b4c40e7f3809c958e8bdd');

  final databases = Databases(client);

  try {
    print('🔍 Checking arena rooms for showResults field...\n');

    // Get all arena rooms
    final response = await databases.listDocuments(
      databaseId: 'arena_db',
      collectionId: 'arena_rooms',
      queries: [
        Query.limit(10),
        Query.orderDesc('\$createdAt'),
      ],
    );

    print('Found ${response.documents.length} recent arena rooms:\n');

    for (final doc in response.documents) {
      final data = doc.data;
      print('Room ID: ${doc.$id}');
      print('  Topic: ${data['topic'] ?? 'N/A'}');
      print('  Status: ${data['status'] ?? 'N/A'}');
      print('  Winner: ${data['winner'] ?? 'NOT SET'}');
      print('  ShowResults: ${data['showResults'] ?? 'NOT SET'}');
      print('  JudgingComplete: ${data['judgingComplete'] ?? 'NOT SET'}');
      print('  Created: ${doc.$createdAt}');
      print('');
    }

    print('\n✅ Debug complete!');
    print('\nIf showResults shows "NOT SET", the n8n workflow is not setting it.');
    print('Check your n8n workflow "Force Broadcast Winner Update" node.');
  } catch (e) {
    print('❌ Error: $e');
  }
}
