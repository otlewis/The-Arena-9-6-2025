import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import 'package:appwrite/appwrite.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserRoleService {
  static final UserRoleService _instance = UserRoleService._internal();
  factory UserRoleService() => _instance;
  UserRoleService._internal();

  final AppwriteService _appwrite = AppwriteService();
  final AppLogger _logger = AppLogger();

  static const String _databaseId = 'arena_db';
  static const String _webhookBaseUrl = 'https://50.21.187.76/webhook';

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

  // ============================================================================
  // ROLE ASSIGNMENT METHODS
  // ============================================================================

  /// Assign Arena role (judge, debater1, debater2, audience) via webhook
  ///
  /// This is the centralized method for all Arena role assignments.
  /// Returns true if successful, false otherwise.
  Future<bool> assignArenaRole({
    required String roomId,
    required String userId,
    required String role,
  }) async {
    try {
      final webhookUrl = '$_webhookBaseUrl/assign-arena-role';
      _logger.info('🔗 WEBHOOK: Calling n8n to assign Arena role: $userId -> $role');
      _logger.debug('🔗 WEBHOOK: URL=$webhookUrl, roomId=$roomId, userId=$userId, role=$role');

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomId': roomId,
          'userId': userId,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _logger.info('🔗 WEBHOOK: ✅ Successfully assigned role via n8n: $userId -> $role');
        return true;
      } else {
        _logger.error('🔗 WEBHOOK: ❌ n8n returned status ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.error('🔗 WEBHOOK: ❌ Failed to assign Arena role via webhook: $e');
      return false;
    }
  }

  /// Promote user to speaker in Debates & Discussions room via webhook
  ///
  /// This is the centralized method for speaker promotions.
  /// Returns true if successful, false otherwise.
  Future<bool> promoteToSpeaker({
    required String roomId,
    required String userId,
    required String participantDocId,
  }) async {
    try {
      final webhookUrl = '$_webhookBaseUrl/promote-speaker';
      _logger.info('🔗 WEBHOOK: Calling n8n to promote user to speaker: $userId');
      _logger.debug('🔗 WEBHOOK: URL=$webhookUrl, roomId=$roomId, userId=$userId, docId=$participantDocId');

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomId': roomId,
          'userId': userId,
          'participantDocId': participantDocId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _logger.info('🔗 WEBHOOK: ✅ Successfully promoted to speaker via n8n: $userId');
        return true;
      } else {
        _logger.error('🔗 WEBHOOK: ❌ n8n returned status ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.error('🔗 WEBHOOK: ❌ Failed to promote to speaker via webhook: $e');
      return false;
    }
  }

  /// Demote speaker back to audience via webhook
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> demoteToAudience({
    required String roomId,
    required String userId,
    required String participantDocId,
  }) async {
    try {
      final webhookUrl = '$_webhookBaseUrl/demote-speaker';
      _logger.info('🔗 WEBHOOK: Calling n8n to demote speaker to audience: $userId');
      _logger.debug('🔗 WEBHOOK: URL=$webhookUrl, roomId=$roomId, userId=$userId, docId=$participantDocId');

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomId': roomId,
          'userId': userId,
          'participantDocId': participantDocId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _logger.info('🔗 WEBHOOK: ✅ Successfully demoted to audience via n8n: $userId');
        return true;
      } else {
        _logger.error('🔗 WEBHOOK: ❌ n8n returned status ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.error('🔗 WEBHOOK: ❌ Failed to demote to audience via webhook: $e');
      return false;
    }
  }

  /// Update debate/discussion participant role via webhook
  ///
  /// Generic method for updating any participant role in Debates & Discussions.
  /// Returns true if successful, false otherwise.
  Future<bool> updateDebateDiscussionRole({
    required String roomId,
    required String userId,
    required String participantDocId,
    required String newRole,
  }) async {
    try {
      final webhookUrl = '$_webhookBaseUrl/update-participant-role';
      _logger.info('🔗 WEBHOOK: Calling n8n to update participant role: $userId -> $newRole');
      _logger.debug('🔗 WEBHOOK: URL=$webhookUrl, roomId=$roomId, userId=$userId, role=$newRole');

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomId': roomId,
          'userId': userId,
          'participantDocId': participantDocId,
          'role': newRole,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _logger.info('🔗 WEBHOOK: ✅ Successfully updated role via n8n: $userId -> $newRole');
        return true;
      } else {
        _logger.error('🔗 WEBHOOK: ❌ n8n returned status ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.error('🔗 WEBHOOK: ❌ Failed to update role via webhook: $e');
      return false;
    }
  }
}