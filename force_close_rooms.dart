import 'package:appwrite/appwrite.dart';
import 'lib/services/appwrite_service.dart';

void main() async {
  print('🚨 FORCE CLOSING ALL STUCK ARENA ROOMS...');
  
  try {
    final appwrite = AppwriteService();
    
    // Get all active arena rooms
    final activeRooms = await appwrite.getActiveArenaRooms();
    
    print('Found ${activeRooms.length} active arena rooms');
    
    for (final room in activeRooms) {
      final roomId = room['id'];
      final status = room['status'];
      final topic = room['topic'] ?? 'Unknown Topic';
      
      print('🔍 Room $roomId: "$topic" (Status: $status)');
      
      // Force close any room that's not already completed
      if (status != 'completed' && status != 'force_closed') {
        print('🚨 Force closing room $roomId...');
        await appwrite.forceCloseArenaRoom(roomId);
        print('✅ Room $roomId force closed successfully');
      } else {
        print('⚠️ Room $roomId already closed');
      }
    }
    
    print('🎉 All rooms processed successfully!');
    print('📱 Mobile devices should now be redirected to home screen within 1-2 seconds');
    
  } catch (e) {
    print('❌ Error: $e');
  }
} 