import 'dart:math';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

/// Tier System Enum
enum RankTier { bronze, silver, gold, platinum, diamond }

/// Gamified Ranking System for Arena
/// Features: Win-based scoring, Monthly resets, Tier system, Live updates
class GamifiedRankingService {
  static final GamifiedRankingService _instance = GamifiedRankingService._internal();
  factory GamifiedRankingService() => _instance;
  GamifiedRankingService._internal();

  final AppwriteService _appwriteService = AppwriteService();

  // Scoring Constants
  static const int WIN_BASE_POINTS = 100;
  static const int LOSS_PARTICIPATION_POINTS = 10;
  static const int DAILY_LOGIN_XP = 5;
  static const int ROOM_CREATION_XP = 15;
  static const int GIFT_MIN_XP = 5;
  static const int GIFT_MAX_XP = 20;

  // Win Streak Multipliers
  static const Map<int, double> WIN_STREAK_MULTIPLIERS = {
    2: 1.0,   // No bonus for 2 wins
    3: 2.0,   // 2x bonus
    5: 3.0,   // 3x bonus
    10: 5.0,  // 5x bonus
    25: 10.0, // 10x bonus (cap)
  };

  // Opponent Tier Bonuses
  static const double HIGHER_TIER_BONUS = 0.5;  // +50%
  static const double SAME_TIER_BONUS = 0.25;   // +25%
  static const double PERFECT_SCORE_BONUS = 0.5; // +50%

  /// Tier System Thresholds
  
  static const Map<RankTier, int> TIER_THRESHOLDS = {
    RankTier.bronze: 0,
    RankTier.silver: 500,
    RankTier.gold: 1500,
    RankTier.platinum: 3500,
    RankTier.diamond: 7500,
  };

  static const Map<RankTier, String> TIER_NAMES = {
    RankTier.bronze: 'Bronze',
    RankTier.silver: 'Silver',
    RankTier.gold: 'Gold',
    RankTier.platinum: 'Platinum',
    RankTier.diamond: 'Diamond',
  };

  static const Map<RankTier, String> TIER_EMOJIS = {
    RankTier.bronze: '🥉',
    RankTier.silver: '🥈',
    RankTier.gold: '🥇',
    RankTier.platinum: '💎',
    RankTier.diamond: '💠',
  };

  /// Calculate win points with bonuses and multipliers
  Future<int> calculateWinPoints({
    required String userId,
    required String opponentId,
    int? judgeScore,
    bool isWin = true,
  }) async {
    try {
      int basePoints = isWin ? WIN_BASE_POINTS : LOSS_PARTICIPATION_POINTS;
      
      if (!isWin) {
        // For losses, just give participation points
        return basePoints;
      }

      // Get user's current stats for streak calculation
      final userStats = await _getCurrentMonthlyStats(userId);
      final winStreak = userStats?['currentWinStreak'] ?? 0;
      
      // Apply win streak multiplier
      double streakMultiplier = _getStreakMultiplier(winStreak + 1); // +1 for current win
      
      // Apply opponent tier bonus
      double opponentBonus = await _getOpponentTierBonus(userId, opponentId);
      
      // Apply perfect score bonus
      double scoreBonus = (judgeScore != null && judgeScore >= 90) ? PERFECT_SCORE_BONUS : 0.0;
      
      // Calculate final points
      double totalMultiplier = streakMultiplier + opponentBonus + scoreBonus;
      int finalPoints = (basePoints * (1.0 + totalMultiplier)).round();
      
      AppLogger().info('🏆 Win points calculated: $userId vs $opponentId = $finalPoints points (base: $basePoints, multiplier: ${totalMultiplier.toStringAsFixed(2)})');
      
      return finalPoints;
      
    } catch (e) {
      AppLogger().error('Failed to calculate win points: $e');
      return isWin ? WIN_BASE_POINTS : LOSS_PARTICIPATION_POINTS;
    }
  }

  /// Award points for a debate result
  Future<bool> awardDebatePoints({
    required String userId,
    required String opponentId,
    required bool isWin,
    int? judgeScore,
  }) async {
    try {
      AppLogger().info('🎯 Awarding debate points: $userId (win: $isWin) vs $opponentId');
      
      // Calculate points
      final points = await calculateWinPoints(
        userId: userId,
        opponentId: opponentId,
        isWin: isWin,
        judgeScore: judgeScore,
      );
      
      // Update user's monthly ranking
      await _updateUserMonthlyRanking(userId, points, isWin);
      
      // Check for achievements
      await _checkAndAwardAchievements(userId, isWin);
      
      // Update global leaderboard position
      await _updateGlobalRankings();
      
      return true;
      
    } catch (e) {
      AppLogger().error('Failed to award debate points: $e');
      return false;
    }
  }

  /// Award activity XP for various actions
  Future<bool> awardActivityXP({
    required String userId,
    required ActivityType activityType,
    int? customAmount,
  }) async {
    try {
      int xpAmount = _getActivityXP(activityType, customAmount);
      
      if (xpAmount <= 0) return true; // No XP to award
      
      await _addUserActivityXP(userId, xpAmount, activityType.name);
      
      AppLogger().info('✨ Activity XP awarded: $userId received $xpAmount XP for ${activityType.name}');
      return true;
      
    } catch (e) {
      AppLogger().error('Failed to award activity XP: $e');
      return false;
    }
  }

  /// Get user's current tier based on monthly points
  Future<RankTier> getUserTier(String userId) async {
    try {
      final stats = await _getCurrentMonthlyStats(userId);
      final points = stats?['monthlyPoints'] ?? 0;
      
      return _getTierFromPoints(points);
      
    } catch (e) {
      AppLogger().error('Failed to get user tier: $e');
      return RankTier.bronze;
    }
  }

  /// Get user's current ranking stats for this month
  Future<Map<String, dynamic>?> getUserCurrentStats(String userId) async {
    try {
      var stats = await _getCurrentMonthlyStats(userId);
      
      // If user doesn't have ranking stats, create initial record
      if (stats == null) {
        await _ensureUserRankingExists(userId);
        stats = await _getCurrentMonthlyStats(userId);
      }
      
      if (stats == null) return null;
      
      // Add tier information
      final points = stats['monthlyPoints'] ?? 0;
      final tier = _getTierFromPoints(points);
      stats['tier'] = tier.name;
      
      return stats;
      
    } catch (e) {
      AppLogger().error('Failed to get user current stats: $e');
      return null;
    }
  }

  /// Get current month's leaderboard
  Future<List<Map<String, dynamic>>> getCurrentLeaderboard({int limit = 100}) async {
    try {
      final currentMonth = _getCurrentMonthKey();
      
      final response = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'monthly_rankings',
        queries: [
          // Query for current month only
        ],
      );
      
      // Filter for current month and sort by points descending
      final currentMonthRankings = response.documents
          .where((doc) => doc.data['monthKey'] == currentMonth)
          .toList();
      
      // Sort by monthly points in descending order (highest first)
      currentMonthRankings.sort((a, b) => 
          (b.data['monthlyPoints'] ?? 0).compareTo(a.data['monthlyPoints'] ?? 0));
      
      // Update global ranks in the database
      for (int i = 0; i < currentMonthRankings.length; i++) {
        final doc = currentMonthRankings[i];
        final newRank = i + 1;
        
        // Update rank in database if it's different
        if (doc.data['globalRank'] != newRank) {
          try {
            await _appwriteService.databases.updateDocument(
              databaseId: 'arena_db',
              collectionId: 'monthly_rankings',
              documentId: doc.$id,
              data: {'globalRank': newRank},
            );
          } catch (e) {
            AppLogger().debug('Failed to update rank for user ${doc.data['userId']}: $e');
          }
        }
      }
      
      // Take only the requested limit
      final limitedRankings = currentMonthRankings.take(limit).toList();
      
      // Format leaderboard data
      final leaderboard = <Map<String, dynamic>>[];
      for (int i = 0; i < limitedRankings.length; i++) {
        final doc = limitedRankings[i];
        final userData = doc.data;
        
        // Get user profile for display name and avatar
        final profile = await _appwriteService.getUserProfile(userData['userId']);
        
        leaderboard.add({
          'rank': i + 1, // This should match the globalRank we just updated
          'userId': userData['userId'],
          'displayName': profile?.displayName ?? 'Unknown User',
          'avatar': profile?.avatar,
          'monthlyPoints': userData['monthlyPoints'] ?? 0,
          'tier': _getTierFromPoints(userData['monthlyPoints'] ?? 0).name,
          'tierEmoji': TIER_EMOJIS[_getTierFromPoints(userData['monthlyPoints'] ?? 0)],
          'wins': userData['monthlyWins'] ?? 0,
          'losses': userData['monthlyLosses'] ?? 0,
          'winStreak': userData['currentWinStreak'] ?? 0,
          'reputationPercentage': profile?.reputationPercentage ?? 100,
        });
      }
      
      return leaderboard;
      
    } catch (e) {
      AppLogger().error('Failed to get current leaderboard: $e');
      return [];
    }
  }

  /// Reset monthly rankings (called at start of each month)
  Future<bool> resetMonthlyRankings() async {
    try {
      AppLogger().info('🔄 Starting monthly rankings reset...');
      
      final previousMonth = _getPreviousMonthKey();
      final currentMonth = _getCurrentMonthKey();
      
      // Award premium to top ranked users from previous month
      await _awardMonthlyPremiumRewards(previousMonth);
      
      // Archive previous month's rankings
      await _archivePreviousMonth(previousMonth);
      
      // Initialize new month rankings for all users
      await _initializeNewMonthRankings(currentMonth);
      
      AppLogger().info('✅ Monthly rankings reset completed');
      return true;
      
    } catch (e) {
      AppLogger().error('Failed to reset monthly rankings: $e');
      return false;
    }
  }

  // Private helper methods

  double _getStreakMultiplier(int streak) {
    for (final entry in WIN_STREAK_MULTIPLIERS.entries.toList().reversed) {
      if (streak >= entry.key) {
        return entry.value;
      }
    }
    return 1.0; // No multiplier for streaks under 2
  }

  Future<double> _getOpponentTierBonus(String userId, String opponentId) async {
    try {
      final userTier = await getUserTier(userId);
      final opponentTier = await getUserTier(opponentId);
      
      final userTierIndex = RankTier.values.indexOf(userTier);
      final opponentTierIndex = RankTier.values.indexOf(opponentTier);
      
      if (opponentTierIndex > userTierIndex) {
        return HIGHER_TIER_BONUS; // Opponent is higher tier
      } else if (opponentTierIndex == userTierIndex) {
        return SAME_TIER_BONUS; // Same tier
      }
      
      return 0.0; // Opponent is lower tier, no bonus
      
    } catch (e) {
      AppLogger().error('Failed to get opponent tier bonus: $e');
      return 0.0;
    }
  }

  RankTier _getTierFromPoints(int points) {
    for (final tier in RankTier.values.reversed) {
      if (points >= TIER_THRESHOLDS[tier]!) {
        return tier;
      }
    }
    return RankTier.bronze;
  }

  int _getActivityXP(ActivityType activityType, int? customAmount) {
    switch (activityType) {
      case ActivityType.dailyLogin:
        return DAILY_LOGIN_XP;
      case ActivityType.roomCreation:
        return ROOM_CREATION_XP;
      case ActivityType.giftSent:
        return customAmount?.clamp(GIFT_MIN_XP, GIFT_MAX_XP) ?? GIFT_MIN_XP;
      case ActivityType.giftReceived:
        return customAmount?.clamp(GIFT_MIN_XP, GIFT_MAX_XP) ?? GIFT_MIN_XP;
    }
  }

  String _getCurrentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String _getPreviousMonthKey() {
    final now = DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1);
    return '${prevMonth.year}-${prevMonth.month.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>?> _getCurrentMonthlyStats(String userId) async {
    try {
      final currentMonth = _getCurrentMonthKey();
      
      final response = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'monthly_rankings',
        queries: [
          // Note: Appwrite queries would be ideal here, but since they're not working,
          // we'll filter manually
        ],
      );
      
      // Filter for specific user and current month
      for (final doc in response.documents) {
        if (doc.data['userId'] == userId && doc.data['monthKey'] == currentMonth) {
          return doc.data;
        }
      }
      
      return null;
      
    } catch (e) {
      AppLogger().error('Failed to get current monthly stats: $e');
      return null;
    }
  }

  Future<void> _updateUserMonthlyRanking(String userId, int points, bool isWin) async {
    try {
      final currentMonth = _getCurrentMonthKey();
      final currentStats = await _getCurrentMonthlyStats(userId);
      
      final newStats = {
        'userId': userId,
        'monthKey': currentMonth,
        'monthlyPoints': (currentStats?['monthlyPoints'] ?? 0) + points,
        'monthlyWins': (currentStats?['monthlyWins'] ?? 0) + (isWin ? 1 : 0),
        'monthlyLosses': (currentStats?['monthlyLosses'] ?? 0) + (isWin ? 0 : 1),
        'currentWinStreak': isWin ? (currentStats?['currentWinStreak'] ?? 0) + 1 : 0,
        'bestWinStreak': max(
          (currentStats?['bestWinStreak'] ?? 0) as int,
          isWin ? ((currentStats?['currentWinStreak'] ?? 0) as int) + 1 : 0,
        ),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      if (currentStats != null) {
        // Update existing record
        await _appwriteService.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'monthly_rankings',
          documentId: currentStats['\$id'],
          data: newStats,
        );
      } else {
        // Create new record
        await _appwriteService.databases.createDocument(
          databaseId: 'arena_db',
          collectionId: 'monthly_rankings',
          documentId: 'unique()',
          data: newStats,
        );
      }
      
    } catch (e) {
      AppLogger().error('Failed to update user monthly ranking: $e');
    }
  }

  Future<void> _addUserActivityXP(String userId, int xpAmount, String activityType) async {
    try {
      final currentStats = await _getCurrentMonthlyStats(userId);
      
      if (currentStats != null) {
        final newXP = (currentStats['activityXP'] ?? 0) + xpAmount;
        
        await _appwriteService.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'monthly_rankings',
          documentId: currentStats['\$id'],
          data: {
            'activityXP': newXP,
            'lastActivity': activityType,
            'lastUpdated': DateTime.now().toIso8601String(),
          },
        );
      }
      
    } catch (e) {
      AppLogger().error('Failed to add user activity XP: $e');
    }
  }

  Future<void> _checkAndAwardAchievements(String userId, bool isWin) async {
    // TODO: Implement achievement checking logic
    // This will be expanded in the achievement system
  }

  Future<void> _updateGlobalRankings() async {
    // TODO: Implement global ranking position updates
    // This could be a background job that runs periodically
  }

  Future<void> _awardMonthlyPremiumRewards(String monthKey) async {
    // TODO: Implement premium reward distribution to top users
  }

  Future<void> _archivePreviousMonth(String monthKey) async {
    // TODO: Implement archiving of previous month's rankings
  }

  Future<void> _initializeNewMonthRankings(String monthKey) async {
    // TODO: Initialize new month rankings for all active users
  }

  /// Ensure user has a ranking record for the current month with accurate data
  Future<void> _ensureUserRankingExists(String userId) async {
    try {
      final currentMonth = _getCurrentMonthKey();
      
      // Check if user already has a record
      final existingStats = await _getCurrentMonthlyStats(userId);
      if (existingStats != null) return;
      
      AppLogger().info('🎯 Creating ranking record with real data for user: $userId');
      
      // Get actual arena participation data
      final arenaParticipants = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
      );
      
      // Calculate real stats from arena participation
      int monthlyWins = 0;
      int monthlyLosses = 0;
      int winStreak = 0;
      
      for (final doc in arenaParticipants.documents) {
        if (doc.data['userId'] == userId) {
          final createdAt = DateTime.parse(doc.$createdAt);
          final docMonth = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
          
          if (docMonth == currentMonth) {
            final status = doc.data['status'] ?? doc.data['result'];
            if (status == 'won' || status == 'win') {
              monthlyWins++;
              winStreak++; // Simple streak calculation for initialization
            } else if (status == 'lost' || status == 'loss') {
              monthlyLosses++;
              winStreak = 0;
            }
          }
        }
      }
      
      // Calculate points using the proper formula
      final winPoints = monthlyWins * WIN_BASE_POINTS;
      final lossPoints = monthlyLosses * LOSS_PARTICIPATION_POINTS;
      final totalPoints = winPoints + lossPoints;
      
      // Determine tier from points
      final tier = _getTierFromPoints(totalPoints);
      
      // Create ranking record with calculated data
      await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'monthly_rankings',
        documentId: 'unique()',
        data: {
          'userId': userId,
          'monthKey': currentMonth,
          'monthlyPoints': totalPoints,
          'monthlyWins': monthlyWins,
          'monthlyLosses': monthlyLosses,
          'currentWinStreak': winStreak,
          'bestWinStreak': winStreak,
          'activityXP': 0,
          'tier': tier.name,
          'globalRank': 0, // Will be updated when leaderboard is calculated
          'lastUpdated': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger().info('✅ Created ranking record: $monthlyWins wins, $totalPoints points, ${tier.name} tier');
      
    } catch (e) {
      AppLogger().error('Failed to ensure user ranking exists: $e');
      rethrow;
    }
  }
}

/// Activity types that award XP
enum ActivityType {
  dailyLogin,
  roomCreation,
  giftSent,
  giftReceived,
}