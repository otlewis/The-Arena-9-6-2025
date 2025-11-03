import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../models/user_profile.dart';
import '../core/logging/app_logger.dart';

/// Admin User Management Service
/// Handles user search, management, and moderation actions
class AdminUserService {
  static final AdminUserService _instance = AdminUserService._internal();
  factory AdminUserService() => _instance;
  AdminUserService._internal();

  final AppwriteService _appwrite = AppwriteService();

  /// Search users by name or ID
  Future<List<UserProfile>> searchUsers(String query, {int limit = 20}) async {
    try {
      AppLogger().info('🔍 Searching users with query: $query');

      if (query.isEmpty) {
        // Return recent users if no query
        return getRecentUsers(limit: limit);
      }

      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [
          Query.search('name', query),
          Query.limit(limit),
        ],
      );

      final users = <UserProfile>[];
      for (var doc in response.documents) {
        try {
          final userData = Map<String, dynamic>.from(doc.data);
          userData['\$id'] = doc.$id;
          users.add(UserProfile.fromMap(userData));
        } catch (e) {
          AppLogger().error('Error parsing user ${doc.$id}: $e');
        }
      }

      AppLogger().info('✅ Found ${users.length} users');
      return users;
    } catch (e) {
      AppLogger().error('❌ Error searching users: $e');
      return [];
    }
  }

  /// Get recent users
  Future<List<UserProfile>> getRecentUsers({int limit = 20}) async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [
          Query.orderDesc('\$createdAt'),
          Query.limit(limit),
        ],
      );

      final users = <UserProfile>[];
      for (var doc in response.documents) {
        try {
          final userData = Map<String, dynamic>.from(doc.data);
          userData['\$id'] = doc.$id;
          users.add(UserProfile.fromMap(userData));
        } catch (e) {
          AppLogger().error('Error parsing user ${doc.$id}: $e');
        }
      }

      return users;
    } catch (e) {
      AppLogger().error('Error getting recent users: $e');
      return [];
    }
  }

  /// Get user details with full stats
  Future<Map<String, dynamic>> getUserDetails(String userId) async {
    try {
      AppLogger().info('📊 Getting details for user: $userId');

      // Get user profile
      final userProfile = await _appwrite.getUserProfile(userId);
      if (userProfile == null) {
        throw Exception('User not found');
      }

      // Get user's debate count
      final debatesResponse = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.equal('userId', userId),
          Query.limit(1),
        ],
      );

      // Get user's challenges
      final challengesSentResponse = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'challenge_messages',
        queries: [
          Query.equal('challengerId', userId),
          Query.equal('messageType', 'challenge'),
          Query.limit(1),
        ],
      );

      final challengesReceivedResponse = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'challenge_messages',
        queries: [
          Query.equal('challengedId', userId),
          Query.equal('messageType', 'challenge'),
          Query.limit(1),
        ],
      );

      return {
        'profile': userProfile,
        'debateCount': debatesResponse.total,
        'challengesSent': challengesSentResponse.total,
        'challengesReceived': challengesReceivedResponse.total,
      };
    } catch (e) {
      AppLogger().error('❌ Error getting user details: $e');
      rethrow;
    }
  }

  /// Update user's coin balance (admin action)
  Future<bool> updateUserCoins(String userId, int newBalance) async {
    try {
      AppLogger().info('💰 Admin updating coins for user $userId to $newBalance');

      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'coinBalance': newBalance,
        },
      );

      AppLogger().info('✅ Coins updated successfully');
      return true;
    } catch (e) {
      AppLogger().error('❌ Error updating user coins: $e');
      return false;
    }
  }

  /// Update user's reputation (admin action)
  Future<bool> updateUserReputation(String userId, int newReputation) async {
    try {
      AppLogger().info('⭐ Admin updating reputation for user $userId to $newReputation');

      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'reputation': newReputation,
        },
      );

      AppLogger().info('✅ Reputation updated successfully');
      return true;
    } catch (e) {
      AppLogger().error('❌ Error updating user reputation: $e');
      return false;
    }
  }

  /// Ban user (admin action)
  Future<bool> banUser(String userId, String reason) async {
    try {
      AppLogger().info('🚫 Admin banning user: $userId, reason: $reason');

      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'isBanned': true,
          'banReason': reason,
          'bannedAt': DateTime.now().toIso8601String(),
        },
      );

      AppLogger().info('✅ User banned successfully');
      return true;
    } catch (e) {
      AppLogger().error('❌ Error banning user: $e');
      return false;
    }
  }

  /// Unban user (admin action)
  Future<bool> unbanUser(String userId) async {
    try {
      AppLogger().info('✅ Admin unbanning user: $userId');

      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'isBanned': false,
          'banReason': '',
          'bannedAt': '',
        },
      );

      AppLogger().info('✅ User unbanned successfully');
      return true;
    } catch (e) {
      AppLogger().error('❌ Error unbanning user: $e');
      return false;
    }
  }

  /// Get banned users list
  Future<List<UserProfile>> getBannedUsers({int limit = 50}) async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [
          Query.equal('isBanned', true),
          Query.orderDesc('bannedAt'),
          Query.limit(limit),
        ],
      );

      final users = <UserProfile>[];
      for (var doc in response.documents) {
        try {
          final userData = Map<String, dynamic>.from(doc.data);
          userData['\$id'] = doc.$id;
          users.add(UserProfile.fromMap(userData));
        } catch (e) {
          AppLogger().error('Error parsing banned user ${doc.$id}: $e');
        }
      }

      return users;
    } catch (e) {
      AppLogger().error('Error getting banned users: $e');
      return [];
    }
  }

  /// Get user activity summary
  Future<Map<String, dynamic>> getUserActivitySummary(String userId) async {
    try {
      // Get last 10 debates
      final debatesResponse = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.equal('userId', userId),
          Query.equal('isActive', true),
          Query.orderDesc('\$createdAt'),
          Query.limit(10),
        ],
      );

      final recentDebates = <Map<String, dynamic>>[];
      for (var doc in debatesResponse.documents) {
        final roomId = doc.data['roomId'];
        final roomData = await _appwrite.getArenaRoom(roomId);
        if (roomData != null) {
          recentDebates.add({
            'roomId': roomId,
            'topic': roomData['topic'],
            'role': doc.data['role'],
            'date': doc.$createdAt,
          });
        }
      }

      return {
        'recentDebates': recentDebates,
        'totalDebates': debatesResponse.total,
      };
    } catch (e) {
      AppLogger().error('Error getting user activity summary: $e');
      return {'recentDebates': [], 'totalDebates': 0};
    }
  }
}
