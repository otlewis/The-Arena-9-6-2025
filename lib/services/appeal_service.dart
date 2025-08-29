import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import 'package:appwrite/appwrite.dart';

class AppealService {
  static final AppealService _instance = AppealService._internal();
  factory AppealService() => _instance;
  AppealService._internal();

  final AppwriteService _appwrite = AppwriteService();
  final AppLogger _logger = AppLogger();

  static const String _databaseId = 'arena_db';

  /// Submit an appeal for a moderation action
  Future<bool> submitAppeal({
    required String userId,
    required String moderationActionId,
    required String reason,
    required String appealType,
  }) async {
    try {
      await _appwrite.databases.createDocument(
        databaseId: _databaseId,
        collectionId: 'appeals',
        documentId: ID.unique(),
        data: {
          'userId': userId,
          'moderationActionId': moderationActionId,
          'appealType': appealType, // 'ban_appeal', 'mute_appeal', etc.
          'reason': reason,
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );

      _logger.info('Appeal submitted successfully for user: $userId');
      return true;
    } catch (e) {
      _logger.error('Failed to submit appeal: $e');
      return false;
    }
  }

  /// Get appeals for the current user
  Future<List<Map<String, dynamic>>> getUserAppeals(String userId) async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: 'appeals',
        queries: [
          Query.equal('userId', userId),
          Query.orderDesc('createdAt'),
        ],
      );

      return response.documents.map((doc) => {
        ...doc.data,
        'id': doc.$id,
      }).toList();
    } catch (e) {
      _logger.error('Failed to get user appeals: $e');
      return [];
    }
  }

  /// Get all appeals for moderation review
  Future<List<Map<String, dynamic>>> getAllAppeals() async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: 'appeals',
        queries: [
          Query.orderDesc('createdAt'),
          Query.limit(100),
        ],
      );

      return response.documents.map((doc) => {
        ...doc.data,
        'id': doc.$id,
      }).toList();
    } catch (e) {
      _logger.error('Failed to get all appeals: $e');
      return [];
    }
  }

  /// Get pending appeals for moderation review
  Future<List<Map<String, dynamic>>> getPendingAppeals() async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: 'appeals',
        queries: [
          Query.equal('status', 'pending'),
          Query.orderDesc('createdAt'),
          Query.limit(50),
        ],
      );

      return response.documents.map((doc) => {
        ...doc.data,
        'id': doc.$id,
      }).toList();
    } catch (e) {
      _logger.error('Failed to get pending appeals: $e');
      return [];
    }
  }

  /// Process an appeal (approve/deny)
  Future<bool> processAppeal({
    required String appealId,
    required String moderatorId,
    required String decision, // 'approved', 'denied'
    required String moderatorNotes,
  }) async {
    try {
      await _appwrite.databases.updateDocument(
        databaseId: _databaseId,
        collectionId: 'appeals',
        documentId: appealId,
        data: {
          'status': decision,
          'moderatorId': moderatorId,
          'moderatorNotes': moderatorNotes,
          'reviewedAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );

      _logger.info('Appeal $appealId processed with decision: $decision');
      return true;
    } catch (e) {
      _logger.error('Failed to process appeal: $e');
      return false;
    }
  }

  /// Get moderation action details by ID
  Future<Map<String, dynamic>?> getModerationAction(String actionId) async {
    try {
      final response = await _appwrite.databases.getDocument(
        databaseId: _databaseId,
        collectionId: 'moderation_actions',
        documentId: actionId,
      );

      return {
        ...response.data,
        'id': response.$id,
      };
    } catch (e) {
      _logger.error('Failed to get moderation action: $e');
      return null;
    }
  }

  /// Check if user can submit an appeal for a specific action
  Future<bool> canUserAppeal({
    required String userId,
    required String moderationActionId,
  }) async {
    try {
      // Check if user already has a pending appeal for this action
      final existingAppeals = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: 'appeals',
        queries: [
          Query.equal('userId', userId),
          Query.equal('moderationActionId', moderationActionId),
          Query.equal('status', 'pending'),
        ],
      );

      // Users can only have one pending appeal per moderation action
      return existingAppeals.documents.isEmpty;
    } catch (e) {
      _logger.error('Failed to check appeal eligibility: $e');
      return false;
    }
  }

  /// Get user's active moderation actions (bans, mutes, etc.)
  Future<List<Map<String, dynamic>>> getUserModerationActions(String userId) async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: 'moderation_actions',
        queries: [
          Query.equal('targetUserId', userId),
          Query.equal('status', 'active'),
          Query.orderDesc('createdAt'),
        ],
      );

      return response.documents.map((doc) => {
        ...doc.data,
        'id': doc.$id,
      }).toList();
    } catch (e) {
      _logger.error('Failed to get user moderation actions: $e');
      return [];
    }
  }
}