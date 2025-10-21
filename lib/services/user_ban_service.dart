import 'dart:async';
import 'dart:convert';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

/// Service to manage user bans issued by moderators
class UserBanService {
  static final UserBanService _instance = UserBanService._internal();
  factory UserBanService() => _instance;
  UserBanService._internal();

  final AppwriteService _appwrite = AppwriteService();
  final AppLogger _logger = AppLogger();

  /// Ban a user from a room
  ///
  /// This method calls a server-side Appwrite Function that:
  /// 1. Validates the caller's session (gets real userId from auth)
  /// 2. Checks permissions from database (room moderator or super moderator)
  /// 3. Checks if target is a super moderator (IMMUNE)
  /// 4. Creates the ban record with proper audit logging
  /// 5. Returns success/failure
  ///
  /// The server-side validation prevents authorization bypass attacks.
  Future<bool> banUser({
    required String userId,
    required String roomId,
    required String roomType,
    required String moderatorId,
    required String moderatorName,
    String? reason,
    int? durationMinutes,
  }) async {
    try {
      _logger.info('🔨 Calling ban-user function - targetUserId: $userId, roomId: $roomId, roomType: $roomType, duration: $durationMinutes, reason: $reason');

      // Call server-side function with 10 second timeout
      final result = await _appwrite.functions.createExecution(
        functionId: 'ban-user',
        body: jsonEncode({
          'targetUserId': userId,
          'roomId': roomId,
          'roomType': roomType,
          'durationMinutes': durationMinutes,
          'reason': reason,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logger.error('🔨 Function execution timed out after 10 seconds');
          throw TimeoutException('Ban user function timed out - function may not be deployed');
        },
      );

      _logger.info('🔨 Function execution completed - status: ${result.status}, responseCode: ${result.responseStatusCode}, responseBody: ${result.responseBody}');

      final response = jsonDecode(result.responseBody) as Map<String, dynamic>;

      if (response['success'] == true) {
        _logger.info('🔨 User $userId banned from room $roomId (banId: ${response['banId']})')  ;
        return true;
      } else {
        final error = response['error'] ?? 'Unknown error';
        _logger.error('Ban failed: $error');
        throw Exception(error);
      }
    } catch (e) {
      _logger.error('Failed to ban user: $e');
      rethrow; // Rethrow to let caller handle it
    }
  }
}
