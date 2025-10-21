import 'dart:async';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

/// Service to manage user timeouts issued by moderators
class UserTimeoutService {
  static final UserTimeoutService _instance = UserTimeoutService._internal();
  factory UserTimeoutService() => _instance;
  UserTimeoutService._internal();

  final AppwriteService _appwrite = AppwriteService();
  final AppLogger _logger = AppLogger();

  static const String _databaseId = 'arena_db';
  static const String _collectionId = 'user_timeouts';

  // Periodic timer to auto-expire timeouts
  Timer? _cleanupTimer;
  bool _isCleanupRunning = false;

  /// Check if a user is currently timed out in a room
  Future<bool> isUserTimedOut(String userId, String roomId) async {
    try {
      final now = DateTime.now().toIso8601String();

      final response = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [
          Query.equal('userId', userId),
          Query.equal('roomId', roomId),
          Query.equal('isActive', true),
          Query.greaterThan('expiresAt', now),
          Query.limit(1),
        ],
      );

      return response.documents.isNotEmpty;
    } catch (e) {
      _logger.error('Failed to check timeout status: $e');
      return false;
    }
  }

  /// Get active timeout for a user in a room
  Future<Map<String, dynamic>?> getActiveTimeout(String userId, String roomId) async {
    try {
      final now = DateTime.now().toIso8601String();

      final response = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [
          Query.equal('userId', userId),
          Query.equal('roomId', roomId),
          Query.equal('isActive', true),
          Query.greaterThan('expiresAt', now),
          Query.limit(1),
        ],
      );

      if (response.documents.isEmpty) return null;

      return response.documents.first.data;
    } catch (e) {
      _logger.error('Failed to get active timeout: $e');
      return null;
    }
  }

  /// Issue a timeout to a user
  ///
  /// This method calls a server-side Appwrite Function that:
  /// 1. Validates the caller's session (gets real userId from auth)
  /// 2. Checks permissions from database (not client cache)
  /// 3. Checks if target is a super moderator (IMMUNE)
  /// 4. Creates the timeout record with proper audit logging
  /// 5. Returns success/failure
  ///
  /// The server-side validation prevents authorization bypass attacks.
  Future<bool> timeoutUser({
    required String userId,
    required String roomId,
    required String moderatorId,
    required String moderatorName,
    required int durationMinutes,
    String? reason,
  }) async {
    try {
      _logger.info('⏰ Calling timeout-user function - targetUserId: $userId, roomId: $roomId, duration: $durationMinutes, reason: $reason');

      // Call server-side function with 10 second timeout
      final result = await _appwrite.functions.createExecution(
        functionId: 'timeout-user',
        body: jsonEncode({
          'targetUserId': userId,
          'roomId': roomId,
          'durationMinutes': durationMinutes,
          'reason': reason,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logger.error('⏰ Function execution timed out after 10 seconds');
          throw TimeoutException('Timeout user function timed out - function may not be deployed');
        },
      );

      _logger.info('⏰ Function execution completed - status: ${result.status}, responseCode: ${result.responseStatusCode}, responseBody: ${result.responseBody}');

      final response = jsonDecode(result.responseBody) as Map<String, dynamic>;

      if (response['success'] == true) {
        _logger.info('⏰ User $userId timed out in room $roomId (timeoutId: ${response['timeoutId']})');
        return true;
      } else {
        final error = response['error'] ?? 'Unknown error';
        _logger.error('Timeout failed: $error');
        throw Exception(error);
      }
    } catch (e) {
      _logger.error('Failed to timeout user: $e');
      rethrow; // Rethrow to let caller handle it
    }
  }

  /// Remove/cancel a timeout early
  Future<bool> removeTimeout(String userId, String roomId) async {
    try {
      final now = DateTime.now().toIso8601String();

      final response = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [
          Query.equal('userId', userId),
          Query.equal('roomId', roomId),
          Query.equal('isActive', true),
          Query.greaterThan('expiresAt', now),
        ],
      );

      for (final doc in response.documents) {
        await _appwrite.databases.updateDocument(
          databaseId: _databaseId,
          collectionId: _collectionId,
          documentId: doc.$id,
          data: {'isActive': false},
        );
      }

      _logger.info('⏰ Timeout removed for user $userId in room $roomId');
      return true;
    } catch (e) {
      _logger.error('Failed to remove timeout: $e');
      return false;
    }
  }

  /// Get remaining timeout duration in minutes (rounded up)
  Future<int?> getRemainingTimeoutMinutes(String userId, String roomId) async {
    try {
      final timeout = await getActiveTimeout(userId, roomId);
      if (timeout == null) return null;

      final expiresAt = DateTime.parse(timeout['expiresAt']);
      final now = DateTime.now();
      final remainingSeconds = expiresAt.difference(now).inSeconds;

      // Round up to nearest minute (so 1:01 shows as 2 minutes remaining)
      final remaining = (remainingSeconds / 60).ceil();

      return remaining > 0 ? remaining : null;
    } catch (e) {
      _logger.error('Failed to get remaining timeout: $e');
      return null;
    }
  }

  /// Start periodic cleanup of expired timeouts (runs every 30 seconds)
  void startPeriodicCleanup() {
    if (_cleanupTimer != null) {
      _logger.info('⏰ Periodic timeout cleanup already running');
      return;
    }

    _logger.info('⏰ Starting periodic timeout cleanup (every 30 seconds)');

    // Run cleanup immediately on start
    cleanupExpiredTimeouts();

    // Then run every 30 seconds
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      cleanupExpiredTimeouts();
    });
  }

  /// Stop periodic cleanup
  void stopPeriodicCleanup() {
    if (_cleanupTimer != null) {
      _logger.info('⏰ Stopping periodic timeout cleanup');
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
    }
  }

  /// Clean up expired timeouts
  Future<void> cleanupExpiredTimeouts() async {
    // Prevent concurrent cleanup runs
    if (_isCleanupRunning) return;

    _isCleanupRunning = true;
    try {
      final now = DateTime.now().toIso8601String();

      final response = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [
          Query.equal('isActive', true),
          Query.lessThan('expiresAt', now),
        ],
      );

      for (final doc in response.documents) {
        await _appwrite.databases.updateDocument(
          databaseId: _databaseId,
          collectionId: _collectionId,
          documentId: doc.$id,
          data: {'isActive': false},
        );
      }

      if (response.documents.isNotEmpty) {
        _logger.info('🧹 Cleaned up ${response.documents.length} expired timeouts');
      }
    } catch (e) {
      _logger.error('Failed to cleanup expired timeouts: $e');
    } finally {
      _isCleanupRunning = false;
    }
  }

  /// Dispose and cleanup resources
  void dispose() {
    stopPeriodicCleanup();
  }
}
