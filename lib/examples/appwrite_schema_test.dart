import '../core/logging/app_logger.dart';
import 'package:arena/services/appwrite_service.dart';

/// Simple test script to verify Appwrite schema is working
/// Run this after setting up the schema in Appwrite Console
class AppwriteSchemaTest {
  final AppwriteService _appwriteService = AppwriteService();

  Future<void> runTests() async {
    AppLogger().debug('🧪 Starting Appwrite Schema Tests...');
    
    try {
      await _testAuthentication();
      await _testRoomCreation();
      await _testRoomParticipation();
      AppLogger().debug('✅ All Appwrite schema tests passed!');
    } catch (e) {
      AppLogger().debug('❌ Schema test failed: $e');
      rethrow;
    }
  }

  Future<void> _testAuthentication() async {
    AppLogger().debug('Testing authentication...');
    final user = await _appwriteService.getCurrentUser();
    if (user == null) {
      throw Exception('User not authenticated. Please log in first.');
    }
    AppLogger().debug('✅ Authentication working - User: ${user.name}');
  }

  Future<void> _testRoomCreation() async {
    AppLogger().debug('Testing room creation...');
    final user = await _appwriteService.getCurrentUser();
    
    final roomId = await _appwriteService.createRoom(
      title: 'Test Room Schema',
      description: 'Testing if the new schema works',
      createdBy: user!.$id,
      tags: ['test', 'schema'],
      maxParticipants: 10,
    );
    
    AppLogger().debug('✅ Room created successfully: $roomId');
    
    // Test getting the room back
    final room = await _appwriteService.getRoom(roomId);
    if (room == null) {
      throw Exception('Could not retrieve created room');
    }
    
    AppLogger().debug('✅ Room retrieved: ${room['title']}');
    AppLogger().debug('  - Description: ${room['description']}');
    AppLogger().debug('  - Created by: ${room['createdBy']}');
    AppLogger().debug('  - Max participants: ${room['maxParticipants']}');
    AppLogger().debug('  - Tags: ${room['tags']}');
  }

  Future<void> _testRoomParticipation() async {
    AppLogger().debug('Testing room participation...');
    final user = await _appwriteService.getCurrentUser();
    
    // Get all rooms
    final rooms = await _appwriteService.getRooms();
    if (rooms.isEmpty) {
      throw Exception('No rooms found to test participation');
    }
    
    final testRoom = rooms.first;
    AppLogger().debug('Testing with room: ${testRoom['title']}');
    
    // Test getting participation (should exist since we created the room)
    final participation = await _appwriteService.getUserRoomParticipation(
      roomId: testRoom['id'],
      userId: user!.$id,
    );
    
    if (participation == null) {
      throw Exception('Creator should automatically be a participant');
    }
    
    AppLogger().debug('✅ Room participation working');
    AppLogger().debug('  - User role: ${participation['role']}');
    AppLogger().debug('  - User status: ${participation['status']}');
    AppLogger().debug('  - Joined at: ${participation['joinedAt']}');
    
    // Test role update
    await _appwriteService.updateParticipantRole(
      roomId: testRoom['id'],
      userId: user.$id,
      newRole: 'speaker',
    );
    
    AppLogger().debug('✅ Role update successful');
  }
}

/// Call this function from your app to test the schema
Future<void> testAppwriteSchema() async {
  final test = AppwriteSchemaTest();
  await test.runTests();
} 