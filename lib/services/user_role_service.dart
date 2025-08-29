import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import 'package:appwrite/appwrite.dart';

class UserRoleService {
  static final UserRoleService _instance = UserRoleService._internal();
  factory UserRoleService() => _instance;
  UserRoleService._internal();

  final AppwriteService _appwrite = AppwriteService();
  final AppLogger _logger = AppLogger();

  static const String _databaseId = 'arena_db';

  /// Check if current user is a moderator
  Future<bool> isCurrentUserModerator() async {
    try {
      final user = await _appwrite.getCurrentUser();
      if (user == null) return false;

      return await isUserModerator(user.$id);
    } catch (e) {
      _logger.error('Failed to check moderator status: $e');
      return false;
    }
  }

  /// Check if specific user is a moderator
  Future<bool> isUserModerator(String userId) async {
    try {
      final moderators = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: 'moderators',
        queries: [
          Query.equal('userId', userId),
          Query.equal('status', 'active'),
        ],
      );

      return moderators.documents.isNotEmpty;
    } catch (e) {
      _logger.error('Failed to check moderator status for user $userId: $e');
      return false;
    }
  }

  /// Check if current user is a judge
  Future<bool> isCurrentUserJudge() async {
    try {
      final user = await _appwrite.getCurrentUser();
      if (user == null) return false;

      return await isUserJudge(user.$id);
    } catch (e) {
      _logger.error('Failed to check judge status: $e');
      return false;
    }
  }

  /// Check if specific user is a judge
  Future<bool> isUserJudge(String userId) async {
    try {
      final judges = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: 'judges',
        queries: [
          Query.equal('userId', userId),
          Query.equal('status', 'active'),
        ],
      );

      return judges.documents.isNotEmpty;
    } catch (e) {
      _logger.error('Failed to check judge status for user $userId: $e');
      return false;
    }
  }

  /// Check if current user has moderation privileges (moderator or admin)
  Future<bool> hasCurrentUserModerationPrivileges() async {
    try {
      // For now, moderators have full moderation privileges
      // In the future, you could add admin roles or specific permissions
      return await isCurrentUserModerator();
    } catch (e) {
      _logger.error('Failed to check moderation privileges: $e');
      return false;
    }
  }

  /// Get user role information
  Future<Map<String, bool>> getCurrentUserRoles() async {
    try {
      final user = await _appwrite.getCurrentUser();
      if (user == null) {
        return {
          'isModerator': false,
          'isJudge': false,
          'hasModeration': false,
        };
      }

      final isModerator = await isUserModerator(user.$id);
      final isJudge = await isUserJudge(user.$id);

      return {
        'isModerator': isModerator,
        'isJudge': isJudge,
        'hasModeration': isModerator, // Could expand this logic later
      };
    } catch (e) {
      _logger.error('Failed to get user roles: $e');
      return {
        'isModerator': false,
        'isJudge': false,
        'hasModeration': false,
      };
    }
  }
}