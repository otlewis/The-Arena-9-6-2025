import 'package:appwrite/appwrite.dart';
import 'dart:io';

/// Test script to manually set showResults=true on an arena room
/// This helps debug if the UI responds to the showResults field
void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart scripts/test_show_results_broadcast.dart <room_id>');
    print('Example: dart scripts/test_show_results_broadcast.dart 67a1b2c3d4e5f6g7h8i9');
    exit(1);
  }

  final roomId = args[0];

  // Initialize Appwrite client
  final client = Client()
      .setEndpoint('https://cloud.appwrite.io/v1')
      .setProject('arena')
      .setKey('standard_00d440e0d9e7f53faaccdfac1ecfe49e4c0b30f2c4770b75a5cbaba5ea6375ea2d6e68483697726bfe1b8d67d8c8bb447ff97fce0f13893b38c5fe46c315aeff46cb38d109055f59689663b6214b480b346fddf7009dc776f183abdd3b07e4ceb78477b769d5f0631b696f0f342d5541d224b4305b9b4c40e7f3809c958e8bdd');

  final databases = Databases(client);

  try {
    print('🔍 Fetching current room state for: $roomId\n');

    // Get current room data
    final room = await databases.getDocument(
      databaseId: 'arena_db',
      collectionId: 'arena_rooms',
      documentId: roomId,
    );

    print('Current room state:');
    print('  Topic: ${room.data['topic']}');
    print('  Status: ${room.data['status']}');
    print('  Winner: ${room.data['winner'] ?? 'NOT SET'}');
    print('  ShowResults: ${room.data['showResults'] ?? 'NOT SET'}');
    print('  JudgingComplete: ${room.data['judgingComplete'] ?? 'NOT SET'}');
    print('');

    // Ask for winner if not set
    String winner = room.data['winner'] ?? '';
    if (winner.isEmpty) {
      print('Enter winner (affirmative/negative): ');
      winner = stdin.readLineSync() ?? 'affirmative';
    }

    print('\n🚀 Broadcasting results...');
    print('  Setting showResults = true');
    print('  Setting winner = $winner');
    print('  Setting judgingComplete = true');
    print('');

    // Update room with showResults flag
    await databases.updateDocument(
      databaseId: 'arena_db',
      collectionId: 'arena_rooms',
      documentId: roomId,
      data: {
        'showResults': true,
        'winner': winner,
        'judgingComplete': true,
      },
    );

    print('✅ Results broadcast sent!');
    print('');
    print('Check your app - the trophy icon should now appear in the bottom nav bar.');
    print('If it doesn\'t appear, check the app logs for:');
    print('  - "🏆 RESULTS STATE CHANGE DETECTED!"');
    print('  - "🏆 TROPHY ICON APPEARING!"');
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
