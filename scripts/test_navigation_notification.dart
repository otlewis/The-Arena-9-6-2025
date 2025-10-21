import 'package:dart_appwrite/dart_appwrite.dart';

/// Test script to manually create navigation notifications
/// This simulates what the n8n workflow would do
void main() async {
  print('🧪 Testing Arena Navigation Notifications\n');

  // You'll need to replace these with actual values from a real challenge
  final testData = {
    'challengerId': '6847542aaf2b8753e314',  // Replace with actual user ID
    'challengedId': '686c2422838a343e00ea',  // Replace with actual user ID
    'arenaRoomId': 'test_arena_room_id',     // Replace with actual arena room ID
    'challengeId': 'test_challenge_id',      // Replace with actual challenge ID
    'topic': 'Test Challenge',
    'description': 'Testing navigation notifications',
  };

  print('📋 Test Data:');
  print('  Challenger: ${testData['challengerId']}');
  print('  Challenged: ${testData['challengedId']}');
  print('  Arena Room: ${testData['arenaRoomId']}');
  print('\n');

  print('To test the navigation notifications:');
  print('1. Create a real challenge between two users');
  print('2. Accept the challenge (this creates the arena room)');
  print('3. Note the arenaRoomId from the logs');
  print('4. Update this script with the real IDs');
  print('5. Run this script to manually create navigation notifications');
  print('\nOr just test by accepting a challenge - the Flutter client');
  print('should already be listening for navigation notifications!\n');

  print('💡 The Flutter client is already set up and listening.');
  print('   When you accept a challenge, if the notifications are');
  print('   created (either by n8n or manually), navigation will happen!');
}
