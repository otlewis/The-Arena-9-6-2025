import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

/// Admin Analytics Service
/// Provides comprehensive analytics and metrics for the admin dashboard
class AdminAnalyticsService {
  static final AdminAnalyticsService _instance = AdminAnalyticsService._internal();
  factory AdminAnalyticsService() => _instance;
  AdminAnalyticsService._internal();

  final AppwriteService _appwrite = AppwriteService();

  /// Get total number of users
  Future<int> getTotalUsers() async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [Query.limit(1)],
      );
      return response.total;
    } catch (e) {
      AppLogger().error('Error getting total users: $e');
      return 0;
    }
  }

  /// Get active users in the last N days
  Future<int> getActiveUsers({int days = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days)).toIso8601String();

      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [
          Query.greaterThan('lastActiveAt', cutoffDate),
          Query.limit(1),
        ],
      );
      return response.total;
    } catch (e) {
      AppLogger().error('Error getting active users: $e');
      return 0;
    }
  }

  /// Get total number of arena debates
  Future<int> getTotalDebates() async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        queries: [Query.limit(1)],
      );
      return response.total;
    } catch (e) {
      AppLogger().error('Error getting total debates: $e');
      return 0;
    }
  }

  /// Get debates in the last N days
  Future<int> getRecentDebates({int days = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days)).toIso8601String();

      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        queries: [
          Query.greaterThan('\$createdAt', cutoffDate),
          Query.limit(1),
        ],
      );
      return response.total;
    } catch (e) {
      AppLogger().error('Error getting recent debates: $e');
      return 0;
    }
  }

  /// Get total coins distributed across all users
  Future<int> getTotalCoinsInCirculation() async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [Query.limit(500)], // Get in batches
      );

      int total = 0;
      for (var doc in response.documents) {
        total += (doc.data['coinBalance'] as int? ?? 0);
      }

      return total;
    } catch (e) {
      AppLogger().error('Error getting total coins: $e');
      return 0;
    }
  }

  /// Get total challenges sent
  Future<int> getTotalChallenges() async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'challenge_messages',
        queries: [
          Query.equal('messageType', 'challenge'),
          Query.limit(1),
        ],
      );
      return response.total;
    } catch (e) {
      AppLogger().error('Error getting total challenges: $e');
      return 0;
    }
  }

  /// Get challenge acceptance rate
  Future<double> getChallengeAcceptanceRate() async {
    try {
      final totalResponse = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'challenge_messages',
        queries: [
          Query.equal('messageType', 'challenge'),
          Query.limit(1),
        ],
      );

      final acceptedResponse = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'challenge_messages',
        queries: [
          Query.equal('messageType', 'challenge'),
          Query.equal('status', 'accepted'),
          Query.limit(1),
        ],
      );

      if (totalResponse.total == 0) return 0.0;
      return (acceptedResponse.total / totalResponse.total) * 100;
    } catch (e) {
      AppLogger().error('Error getting challenge acceptance rate: $e');
      return 0.0;
    }
  }

  /// Get new users in the last N days
  Future<int> getNewUsers({int days = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days)).toIso8601String();

      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [
          Query.greaterThan('\$createdAt', cutoffDate),
          Query.limit(1),
        ],
      );
      return response.total;
    } catch (e) {
      AppLogger().error('Error getting new users: $e');
      return 0;
    }
  }

  /// Get top debaters by win count
  Future<List<Map<String, dynamic>>> getTopDebaters({int limit = 10}) async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [
          Query.orderDesc('totalWins'),
          Query.limit(limit),
        ],
      );

      return response.documents.map((doc) {
        return {
          'userId': doc.$id,
          'name': doc.data['name'] ?? 'Unknown',
          'avatar': doc.data['avatar'] ?? '',
          'totalWins': doc.data['totalWins'] ?? 0,
          'totalLosses': doc.data['totalLosses'] ?? 0,
          'reputation': doc.data['reputation'] ?? 0,
          'coinBalance': doc.data['coinBalance'] ?? 0,
        };
      }).toList();
    } catch (e) {
      AppLogger().error('Error getting top debaters: $e');
      return [];
    }
  }

  /// Get debate participation metrics
  Future<Map<String, dynamic>> getDebateParticipationMetrics() async {
    try {
      final totalUsers = await getTotalUsers();

      // Count users who have participated in at least one debate
      final participantsResponse = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.limit(500),
        ],
      );

      final uniqueParticipants = <String>{};
      for (var doc in participantsResponse.documents) {
        uniqueParticipants.add(doc.data['userId']);
      }

      final participationRate = totalUsers > 0
          ? (uniqueParticipants.length / totalUsers) * 100
          : 0.0;

      return {
        'totalParticipants': uniqueParticipants.length,
        'participationRate': participationRate,
      };
    } catch (e) {
      AppLogger().error('Error getting debate participation metrics: $e');
      return {'totalParticipants': 0, 'participationRate': 0.0};
    }
  }

  /// Get user growth data for the last N days
  Future<List<Map<String, dynamic>>> getUserGrowthData({int days = 30}) async {
    try {
      final growthData = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (int i = days - 1; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

        final response = await _appwrite.databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'users',
          queries: [
            Query.greaterThan('\$createdAt', startOfDay),
            Query.lessThan('\$createdAt', endOfDay),
            Query.limit(1),
          ],
        );

        growthData.add({
          'date': date,
          'count': response.total,
        });
      }

      return growthData;
    } catch (e) {
      AppLogger().error('Error getting user growth data: $e');
      return [];
    }
  }

  /// Get debate activity data for the last N days
  Future<List<Map<String, dynamic>>> getDebateActivityData({int days = 30}) async {
    try {
      final activityData = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (int i = days - 1; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

        final response = await _appwrite.databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'arena_rooms',
          queries: [
            Query.greaterThan('\$createdAt', startOfDay),
            Query.lessThan('\$createdAt', endOfDay),
            Query.limit(1),
          ],
        );

        activityData.add({
          'date': date,
          'count': response.total,
        });
      }

      return activityData;
    } catch (e) {
      AppLogger().error('Error getting debate activity data: $e');
      return [];
    }
  }

  /// Get comprehensive dashboard metrics
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    try {
      AppLogger().info('📊 Loading admin dashboard metrics...');

      final results = await Future.wait([
        getTotalUsers(),
        getActiveUsers(days: 7),
        getActiveUsers(days: 1),
        getTotalDebates(),
        getRecentDebates(days: 7),
        getTotalCoinsInCirculation(),
        getTotalChallenges(),
        getChallengeAcceptanceRate(),
        getNewUsers(days: 7),
        getDebateParticipationMetrics(),
      ]);

      final metrics = {
        'totalUsers': results[0],
        'activeUsersWeek': results[1],
        'activeUsersToday': results[2],
        'totalDebates': results[3],
        'debatesThisWeek': results[4],
        'totalCoins': results[5],
        'totalChallenges': results[6],
        'challengeAcceptanceRate': results[7],
        'newUsersThisWeek': results[8],
        'debateParticipation': results[9],
      };

      AppLogger().info('✅ Dashboard metrics loaded successfully');
      return metrics;
    } catch (e) {
      AppLogger().error('❌ Error loading dashboard metrics: $e');
      return {};
    }
  }
}
