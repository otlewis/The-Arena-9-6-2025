import 'dart:math';
import '../services/appwrite_service.dart';
import '../services/gamified_ranking_service.dart';
import '../core/logging/app_logger.dart';

/// Quick script to initialize rankings for existing users
/// This will create sample rankings so you can see how the system looks
void main() async {
  try {
    print('🚀 Initializing rankings for existing users...\n');
    
    final appwriteService = AppwriteService();
    final rankingService = GamifiedRankingService();
    
    // Get current month key
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    print('📅 Current month: $monthKey\n');
    
    // Get all users from the database
    print('📊 Fetching existing users...');
    final usersResponse = await appwriteService.databases.listDocuments(
      databaseId: 'arena_db',
      collectionId: 'users',
      queries: [],
    );
    
    final users = usersResponse.documents;
    print('✅ Found ${users.length} users\n');
    
    if (users.isEmpty) {
      print('⚠️  No users found in database. Create some user accounts first!');
      return;
    }
    
    print('🎯 Creating initial rankings with sample data...\n');
    
    final random = Random();
    int successCount = 0;
    
    for (int i = 0; i < users.length; i++) {
      final user = users[i];
      final userId = user.$id;
      final userName = user.data['name'] ?? 'User $i';
      
      try {
        // Generate random but realistic-looking stats
        // Higher ranked users get better stats
        final rankPosition = i + 1;
        final isTopTier = rankPosition <= 3;
        final isMidTier = rankPosition <= 10;
        
        // Calculate points based on rank (top users get more points)
        int monthlyPoints = 0;
        int monthlyWins = 0;
        int monthlyLosses = 0;
        int winStreak = 0;
        String tier = 'bronze';
        
        if (isTopTier) {
          // Top 3 users - Diamond/Platinum tier
          monthlyPoints = 7500 + random.nextInt(5000); // 7500-12500 points
          monthlyWins = 25 + random.nextInt(15); // 25-40 wins
          monthlyLosses = random.nextInt(5); // 0-5 losses
          winStreak = 5 + random.nextInt(10); // 5-15 streak
          tier = monthlyPoints > 10000 ? 'diamond' : 'platinum';
        } else if (isMidTier) {
          // Top 4-10 users - Gold/Silver tier  
          monthlyPoints = 1500 + random.nextInt(4000); // 1500-5500 points
          monthlyWins = 10 + random.nextInt(15); // 10-25 wins
          monthlyLosses = 3 + random.nextInt(7); // 3-10 losses
          winStreak = random.nextInt(5); // 0-5 streak
          tier = monthlyPoints > 3500 ? 'gold' : 'silver';
        } else {
          // Rest of users - Silver/Bronze tier
          monthlyPoints = random.nextInt(1500); // 0-1500 points
          monthlyWins = random.nextInt(10); // 0-10 wins
          monthlyLosses = random.nextInt(10); // 0-10 losses
          winStreak = 0;
          tier = monthlyPoints > 500 ? 'silver' : 'bronze';
        }
        
        // Add some activity XP
        final activityXP = 50 + random.nextInt(200); // 50-250 XP
        
        // Check if ranking already exists
        final existingRankings = await appwriteService.databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'monthly_rankings',
          queries: [
            // Query would go here if Appwrite SDK supported it
          ],
        );
        
        // Look for existing record for this user and month
        final existingRecord = existingRankings.documents.firstWhere(
          (doc) => doc.data['userId'] == userId && doc.data['monthKey'] == monthKey,
          orElse: () => null as dynamic,
        );
        
        if (existingRecord != null) {
          // Update existing record
          await appwriteService.databases.updateDocument(
            databaseId: 'arena_db',
            collectionId: 'monthly_rankings',
            documentId: existingRecord.$id,
            data: {
              'monthlyPoints': monthlyPoints,
              'monthlyWins': monthlyWins,
              'monthlyLosses': monthlyLosses,
              'currentWinStreak': winStreak,
              'bestWinStreak': winStreak,
              'activityXP': activityXP,
              'tier': tier,
              'globalRank': rankPosition,
              'lastUpdated': DateTime.now().toIso8601String(),
            },
          );
          print('📝 Updated: #$rankPosition - $userName ($tier tier, $monthlyPoints pts)');
        } else {
          // Create new ranking record
          await appwriteService.databases.createDocument(
            databaseId: 'arena_db',
            collectionId: 'monthly_rankings',
            documentId: 'unique()',
            data: {
              'userId': userId,
              'monthKey': monthKey,
              'monthlyPoints': monthlyPoints,
              'monthlyWins': monthlyWins,
              'monthlyLosses': monthlyLosses,
              'currentWinStreak': winStreak,
              'bestWinStreak': winStreak,
              'activityXP': activityXP,
              'tier': tier,
              'globalRank': rankPosition,
              'lastUpdated': DateTime.now().toIso8601String(),
            },
          );
          print('✨ Created: #$rankPosition - $userName ($tier tier, $monthlyPoints pts)');
        }
        
        successCount++;
        
      } catch (e) {
        print('❌ Error initializing ranking for $userName: $e');
      }
    }
    
    print('\n' + '═' * 50);
    print('🎉 Rankings initialized successfully!');
    print('📊 Created/Updated rankings for $successCount/${users.length} users');
    print('\n💡 Tier Distribution:');
    print('   💠 Diamond: Top performers (7500+ points)');
    print('   💎 Platinum: Elite players (3500+ points)');
    print('   🥇 Gold: Strong competitors (1500+ points)');
    print('   🥈 Silver: Active players (500+ points)');
    print('   🥉 Bronze: New players (0+ points)');
    print('\n🎮 Open the Arena app and tap "Rankings" to see the leaderboard!');
    
  } catch (e) {
    print('💥 Error initializing rankings: $e');
  }
}