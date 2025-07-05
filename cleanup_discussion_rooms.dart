import 'package:appwrite/appwrite.dart';
import 'lib/services/appwrite_service.dart';

void main() async {
  // //print('🧹 CLEANING UP UNUSED DISCUSSION ROOMS...');
  
  try {
    final appwrite = AppwriteService();
    
    // Get all active discussion rooms
    final discussionRooms = await appwrite.databases.listDocuments(
      databaseId: 'arena_db',
      collectionId: 'rooms',
      queries: [
        Query.equal('type', 'discussion'),
        Query.equal('status', 'active'),
        Query.limit(100),
      ],
    );
    
    // //print('Found ${discussionRooms.documents.length} active discussion rooms');
    
    // int cleanedCount = 0;  // Unused variable removed
    
    for (final room in discussionRooms.documents) {
      final roomId = room.$id;
      // final roomTitle = room.data['title'] ?? 'Unknown Room';
      final createdAt = DateTime.parse(room.$createdAt);
      final roomAge = DateTime.now().difference(createdAt);
      
      // //print('🔍 Room $roomId: "$roomTitle" (Age: ${roomAge.inHours}h ${roomAge.inMinutes % 60}m)');
      
      // Get participants for this room
      final participants = await appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'room_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('status', 'joined'),
        ],
      );
      
      final participantCount = participants.documents.length;
      //print('   👥 Participants: $participantCount');
      
      // Check cleanup criteria
      bool shouldCleanup = false;
      // String reason = '';  // Unused variable removed
      
      if (roomAge.inHours >= 24) {
        shouldCleanup = true;
        // reason = 'older than 24 hours';
      } else if (roomAge.inHours >= 4 && participantCount == 0) {
        shouldCleanup = true;
        // reason = 'older than 4 hours with no participants';
      } else if (roomAge.inMinutes >= 30 && participantCount == 0) {
        shouldCleanup = true;
        // reason = 'empty for 30+ minutes';
      } else if (roomAge.inHours >= 2 && participantCount <= 1) {
        shouldCleanup = true;
        // reason = 'only 1 or fewer participants for 2+ hours';
      }
      
      if (shouldCleanup) {
        //print('🧹 Cleaning up room: $reason');
        
        // Mark all participants as left
        for (final participant in participants.documents) {
          await appwrite.databases.updateDocument(
            databaseId: 'arena_db',
            collectionId: 'room_participants',
            documentId: participant.$id,
            data: {
              'status': 'left',
              'leftAt': DateTime.now().toIso8601String(),
            },
          );
        }
        
        // Mark room as ended
        await appwrite.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'rooms',
          documentId: roomId,
          data: {
            'status': 'ended',
            'endedAt': DateTime.now().toIso8601String(),
          },
        );
        
        // cleanedCount++;  // Variable was removed
        //print('✅ Room cleaned up successfully');
      } else {
        //print('✅ Room is active, keeping it');
      }
      
      //print(''); // Empty line for readability
    }
    
    //print('🎉 Cleanup completed!');
    //print('📊 Total rooms processed: ${discussionRooms.documents.length}');
    //print('🧹 Rooms cleaned up: $cleanedCount');
    //print('🏃 Active rooms remaining: ${discussionRooms.documents.length - cleanedCount}');
    
  } catch (e) {
    //print('❌ Error: $e');
  }
} 