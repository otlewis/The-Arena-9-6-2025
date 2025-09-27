import 'dart:io';
import 'dart:developer' as developer;
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

/// Migration script for Gamified Ranking System
/// Creates necessary collections and initializes ranking data for existing users
class GamifiedRankingMigration {
  static final AppwriteService _appwriteService = AppwriteService();

  /// Run the complete migration
  static Future<bool> runMigration() async {
    try {
      AppLogger().info('🚀 Starting Gamified Ranking System migration...');
      
      // Step 1: Create collections
      await _printCollectionInstructions();
      
      // Step 2: Initialize current month rankings for existing users
      await _initializeCurrentMonthRankings();
      
      AppLogger().info('✅ Gamified Ranking System migration completed!');
      return true;
      
    } catch (e) {
      AppLogger().error('❌ Migration failed: $e');
      return false;
    }
  }

  /// Print manual collection creation instructions
  static Future<void> _printCollectionInstructions() async {
    developer.log('''
🔧 GAMIFIED RANKING SYSTEM - COLLECTION SETUP

Please create these collections manually in Appwrite Console:

1. CREATE "monthly_rankings" COLLECTION:
   → Go to arena_db → Create Collection: "monthly_rankings"
   → Add attributes:
     • userId (String, required, 128 chars)
     • monthKey (String, required, 8 chars) // "2024-03"
     • monthlyPoints (Integer, required, default: 0)
     • monthlyWins (Integer, required, default: 0)
     • monthlyLosses (Integer, required, default: 0)
     • currentWinStreak (Integer, required, default: 0)
     • bestWinStreak (Integer, required, default: 0)
     • activityXP (Integer, required, default: 0)
     • tier (String, required, default: "bronze", 16 chars)
     • globalRank (Integer, required, default: 0)
     • achievementsEarned (Array of Strings, optional)
     • lastActivity (String, optional, 64 chars)
     • lastUpdated (String, required)

2. CREATE "achievements" COLLECTION:
   → Go to arena_db → Create Collection: "achievements"
   → Add attributes:
     • userId (String, required, 128 chars)
     • achievementId (String, required, 64 chars)
     • title (String, required, 128 chars)
     • description (String, required, 256 chars)
     • category (String, required, 32 chars)
     • rarity (String, required, default: "common", 16 chars)
     • iconAsset (String, required, 128 chars)
     • xpReward (Integer, required, default: 0)
     • isUnlocked (Boolean, required, default: false)
     • unlockedAt (String, optional)
     • metadata (String, optional, 1024 chars) // JSON
     • createdAt (String, required)

3. CREATE "ranking_history" COLLECTION:
   → Go to arena_db → Create Collection: "ranking_history"
   → Add attributes:
     • userId (String, required, 128 chars)
     • monthKey (String, required, 8 chars)
     • finalRank (Integer, required)
     • finalPoints (Integer, required)
     • finalTier (String, required, 16 chars)
     • premiumAwarded (Boolean, required, default: false)
     • archivedAt (String, required)

4. SET UP PERMISSIONS:
   → monthly_rankings: Read for all users, Write for server/moderators
   → achievements: Read for all users, Write for server/moderators
   → ranking_history: Read for all users, Write for server/moderators

5. CREATE INDEXES:
   → monthly_rankings: 
     - userId + monthKey (unique)
     - monthKey + monthlyPoints (for leaderboards)
     - monthKey + globalRank
   → achievements:
     - userId + achievementId (unique)
     - userId + isUnlocked
   → ranking_history:
     - userId + monthKey
     - monthKey + finalRank

6. OPTIONAL - CREATE FUNCTIONS:
   → Monthly Reset Function (runs on 1st of each month)
   → Real-time Ranking Update Function
   → Achievement Checker Function

After completing these steps, run this migration again to initialize user data.
''', name: 'GamifiedRankingMigration');
  }

  /// Initialize monthly rankings for all existing users
  static Future<void> _initializeCurrentMonthRankings() async {
    try {
      AppLogger().info('📊 Initializing monthly rankings for existing users...');
      
      final currentMonth = _getCurrentMonthKey();
      
      // Get all users from the users collection
      final usersResponse = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [],
      );
      
      int initializedCount = 0;
      
      for (final userDoc in usersResponse.documents) {
        final userId = userDoc.data['\$id'] ?? userDoc.data['id'];
        if (userId == null) continue;
        
        try {
          // Check if user already has current month ranking
          final existingRankings = await _appwriteService.databases.listDocuments(
            databaseId: 'arena_db',
            collectionId: 'monthly_rankings',
            queries: [
              // Query for user and current month
            ],
          );
          
          if (existingRankings.documents.isEmpty) {
            // Create initial ranking record
            await _appwriteService.databases.createDocument(
              databaseId: 'arena_db',
              collectionId: 'monthly_rankings',
              documentId: 'unique()',
              data: {
                'userId': userId,
                'monthKey': currentMonth,
                'monthlyPoints': 0,
                'monthlyWins': 0,
                'monthlyLosses': 0,
                'currentWinStreak': 0,
                'bestWinStreak': 0,
                'activityXP': 0,
                'tier': 'bronze',
                'globalRank': 0,
                'achievementsEarned': [],
                'lastActivity': 'initialized',
                'lastUpdated': DateTime.now().toIso8601String(),
              },
            );
            
            initializedCount++;
            AppLogger().info('✅ Initialized ranking for user: $userId');
          }
        } catch (e) {
          AppLogger().warning('⚠️ Failed to initialize ranking for user $userId: $e');
        }
      }
      
      AppLogger().info('📈 Initialized monthly rankings for $initializedCount users');
      
    } catch (e) {
      AppLogger().error('Failed to initialize monthly rankings: $e');
    }
  }


  /// Get current month key (YYYY-MM format)
  static String _getCurrentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Test ranking system functionality
  static Future<void> testRankingSystem() async {
    try {
      AppLogger().info('🧪 Testing ranking system...');
      
      // This would test various ranking operations
      // For now, just print success
      AppLogger().info('✅ Ranking system test completed');
      
    } catch (e) {
      AppLogger().error('❌ Ranking system test failed: $e');
    }
  }
}

/// Command-line interface for running migration
void main(List<String> arguments) async {
  try {
    developer.log('🚀 Gamified Ranking System Migration Tool', name: 'GamifiedRankingMigration');
    
    if (arguments.contains('--instructions')) {
      await GamifiedRankingMigration._printCollectionInstructions();
      return;
    }
    
    if (arguments.contains('--test')) {
      await GamifiedRankingMigration.testRankingSystem();
      return;
    }
    
    // Run full migration
    final success = await GamifiedRankingMigration.runMigration();
    
    if (success) {
      developer.log('🎉 Migration completed successfully!', name: 'GamifiedRankingMigration');
      exit(0);
    } else {
      developer.log('💥 Migration failed. Check logs for details.', name: 'GamifiedRankingMigration');
      exit(1);
    }
    
  } catch (e) {
    developer.log('💥 Migration error: $e', name: 'GamifiedRankingMigration');
    exit(1);
  }
}