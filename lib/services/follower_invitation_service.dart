import 'package:appwrite/appwrite.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

/// Service for inviting followers to rooms
class FollowerInvitationService {
  final AppwriteService _appwrite = AppwriteService();

  // Rate limiting: track last invitation time per user per room
  final Map<String, DateTime> _lastInvitationTimes = {};

  static const Duration _invitationCooldown = Duration(minutes: 5);

  /// Send room invitation to selected followers
  Future<Map<String, dynamic>> inviteFollowersToRoom({
    required String roomId,
    required String roomName,
    required String roomType,
    required String inviterUserId,
    required String inviterName,
    required List<String> followerIds,
  }) async {
    try {
      int successCount = 0;
      int failedCount = 0;
      List<String> rateLimitedFollowers = [];

      for (final followerId in followerIds) {
        // Check rate limiting
        final cooldownKey = '$inviterUserId-$followerId-$roomId';
        if (_isRateLimited(cooldownKey)) {
          rateLimitedFollowers.add(followerId);
          failedCount++;
          continue;
        }

        try {
          // Create invitation notification
          await _appwrite.databases.createDocument(
            databaseId: 'arena_db',
            collectionId: 'room_invitations',
            documentId: ID.unique(),
            data: {
              'roomId': roomId,
              'roomName': roomName,
              'roomType': roomType,
              'inviterId': inviterUserId,
              'inviterName': inviterName,
              'inviteeId': followerId,
              'status': 'pending', // pending, accepted, declined, expired
              'createdAt': DateTime.now().toIso8601String(),
              'expiresAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
            },
          );

          // Update rate limiting
          _lastInvitationTimes[cooldownKey] = DateTime.now();
          successCount++;

          AppLogger().info('📨 Sent room invitation to follower $followerId');
        } catch (e) {
          AppLogger().error('Failed to invite follower $followerId: $e');
          failedCount++;
        }
      }

      return {
        'success': successCount > 0,
        'successCount': successCount,
        'failedCount': failedCount,
        'rateLimitedCount': rateLimitedFollowers.length,
        'rateLimitedFollowers': rateLimitedFollowers,
      };
    } catch (e) {
      AppLogger().error('Error inviting followers: $e');
      return {
        'success': false,
        'successCount': 0,
        'failedCount': followerIds.length,
        'error': e.toString(),
      };
    }
  }

  /// Broadcast invitation to all followers
  Future<Map<String, dynamic>> broadcastToAllFollowers({
    required String roomId,
    required String roomName,
    required String roomType,
    required String inviterUserId,
    required String inviterName,
  }) async {
    try {
      // Get all followers
      final followers = await _appwrite.getUserFollowers(inviterUserId);
      final followerIds = followers.map((f) => f.id).toList();

      if (followerIds.isEmpty) {
        return {
          'success': false,
          'message': 'No followers to invite',
          'successCount': 0,
        };
      }

      // Send invitations
      return await inviteFollowersToRoom(
        roomId: roomId,
        roomName: roomName,
        roomType: roomType,
        inviterUserId: inviterUserId,
        inviterName: inviterName,
        followerIds: followerIds,
      );
    } catch (e) {
      AppLogger().error('Error broadcasting to followers: $e');
      return {
        'success': false,
        'error': e.toString(),
        'successCount': 0,
      };
    }
  }

  /// Check if invitation is rate limited
  bool _isRateLimited(String cooldownKey) {
    final lastTime = _lastInvitationTimes[cooldownKey];
    if (lastTime == null) return false;

    final timeSinceLastInvite = DateTime.now().difference(lastTime);
    return timeSinceLastInvite < _invitationCooldown;
  }

  /// Get remaining cooldown time for a specific invitation
  Duration? getRemainingCooldown(String inviterUserId, String followerId, String roomId) {
    final cooldownKey = '$inviterUserId-$followerId-$roomId';
    final lastTime = _lastInvitationTimes[cooldownKey];

    if (lastTime == null) return null;

    final timeSinceLastInvite = DateTime.now().difference(lastTime);
    if (timeSinceLastInvite >= _invitationCooldown) return null;

    return _invitationCooldown - timeSinceLastInvite;
  }

  /// Mark invitation as accepted
  Future<void> acceptInvitation(String invitationId) async {
    try {
      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'room_invitations',
        documentId: invitationId,
        data: {'status': 'accepted'},
      );
      AppLogger().info('✅ Invitation $invitationId accepted');
    } catch (e) {
      AppLogger().error('Failed to accept invitation: $e');
    }
  }

  /// Mark invitation as declined
  Future<void> declineInvitation(String invitationId) async {
    try {
      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'room_invitations',
        documentId: invitationId,
        data: {'status': 'declined'},
      );
      AppLogger().info('❌ Invitation $invitationId declined');
    } catch (e) {
      AppLogger().error('Failed to decline invitation: $e');
    }
  }

  /// Get pending invitations for a user
  Future<List<Map<String, dynamic>>> getPendingInvitations(String userId) async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'room_invitations',
        queries: [
          Query.equal('inviteeId', userId),
          Query.equal('status', 'pending'),
          Query.greaterThan('expiresAt', DateTime.now().toIso8601String()),
          Query.orderDesc('createdAt'),
          Query.limit(50),
        ],
      );

      return response.documents.map((doc) => doc.data).toList();
    } catch (e) {
      AppLogger().error('Failed to get pending invitations: $e');
      return [];
    }
  }

  /// Clean up expired invitations
  Future<void> cleanupExpiredInvitations() async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'room_invitations',
        queries: [
          Query.equal('status', 'pending'),
          Query.lessThan('expiresAt', DateTime.now().toIso8601String()),
        ],
      );

      for (final doc in response.documents) {
        await _appwrite.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'room_invitations',
          documentId: doc.$id,
          data: {'status': 'expired'},
        );
      }

      AppLogger().info('🧹 Cleaned up ${response.documents.length} expired invitations');
    } catch (e) {
      AppLogger().error('Failed to cleanup expired invitations: $e');
    }
  }
}
