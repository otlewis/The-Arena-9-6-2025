// ignore_for_file: avoid_print
import 'lib/services/appwrite_service.dart';
Future<void> main() async {
  print('🔍 Testing real AppwriteService.getAvailablePlaybacks()...');

  try {
    final appwriteService = AppwriteService();

    print('📡 Calling getAvailablePlaybacks with no filters...');
    final allPlaybacks = await appwriteService.getAvailablePlaybacks(limit: 50);

    print('✅ Found ${allPlaybacks.length} playbacks');

    if (allPlaybacks.isNotEmpty) {
      print('\n📹 Playbacks returned:');
      for (var playback in allPlaybacks) {
        print('- ${playback['title']}');
        print('  Status: ${playback['status']}');
        print('  Visibility: ${playback['visibility']}');
        print('  Original Room: ${playback['originalRoomId']}');
        print('');
      }
    } else {
      print('❌ No playbacks returned - something is filtering them out');
    }

    // Test with a fake user ID to see if that's the issue
    print('🔍 Testing with fake userId filter...');
    final userPlaybacks = await appwriteService.getAvailablePlaybacks(
      userId: 'fake_user_123',
      limit: 50,
    );

    print('With userId filter: ${userPlaybacks.length} playbacks');

  } catch (e) {
    print('❌ Error testing AppwriteService: $e');
    print('Stack trace: ${StackTrace.current}');
  }
}