import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import 'package:appwrite/appwrite.dart';

/// Resets all user reputation values to 0
class ReputationReset {
  static final AppwriteService _appwrite = AppwriteService();

  static Future<void> resetAllReputation() async {
    try {
      AppLogger().info('🔄 Starting reputation reset for all users...');
      
      int offset = 0;
      const limit = 25;
      int totalUpdated = 0;
      
      while (true) {
        // Get batch of users
        final response = await _appwrite.databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'users',
          queries: [
            Query.limit(limit),
            Query.offset(offset),
          ],
        );
        
        if (response.documents.isEmpty) {
          break; // No more users to process
        }
        
        // Update each user's reputation to 0
        for (final doc in response.documents) {
          try {
            await _appwrite.databases.updateDocument(
              databaseId: 'arena_db',
              collectionId: 'users',
              documentId: doc.$id,
              data: {
                'reputation': 0,
                'updatedAt': DateTime.now().toIso8601String(),
              },
            );
            
            totalUpdated++;
            AppLogger().info('✅ Reset reputation for user: ${doc.$id}');
            
          } catch (e) {
            AppLogger().error('❌ Failed to reset reputation for user ${doc.$id}: $e');
          }
          
          // Small delay to avoid rate limiting
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        offset += limit;
        AppLogger().info('📊 Processed batch: $offset users, $totalUpdated updated so far');
      }
      
      AppLogger().info('🎉 Reputation reset completed! Total users updated: $totalUpdated');
      
    } catch (e) {
      AppLogger().error('❌ Failed to reset reputation: $e');
      rethrow;
    }
  }
  
  /// Reset reputation for a specific user
  static Future<void> resetUserReputation(String userId) async {
    try {
      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'reputation': 0,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger().info('✅ Reset reputation for user: $userId');
      
    } catch (e) {
      AppLogger().error('❌ Failed to reset reputation for user $userId: $e');
      rethrow;
    }
  }
}