import 'package:flutter/material.dart';
import '../core/logging/app_logger.dart';
import '../screens/debates_discussions_screen.dart';
import '../screens/arena_screen.dart';
import 'appwrite_service.dart';
import 'follower_invitation_service.dart';
import 'user_presence_service.dart';

/// Service for handling room invitation acceptance flow
/// Manages the entire process of joining a room from an invitation
class RoomInvitationAcceptanceService {
  static final RoomInvitationAcceptanceService _instance =
      RoomInvitationAcceptanceService._internal();
  factory RoomInvitationAcceptanceService() => _instance;
  RoomInvitationAcceptanceService._internal();

  final AppwriteService _appwrite = AppwriteService();
  final FollowerInvitationService _invitationService = FollowerInvitationService();
  final UserPresenceService _presenceService = UserPresenceService();

  /// Accept a room invitation and prepare data
  ///
  /// [invitation] - The invitation document data
  ///
  /// Returns map with room data if successful, null otherwise
  Future<Map<String, dynamic>?> acceptInvitation({
    required Map<String, dynamic> invitation,
  }) async {
    try {
      final invitationId = invitation['\$id'];
      final roomId = invitation['roomId'];
      final roomName = invitation['roomName'];
      final inviterName = invitation['inviterName'];
      final roomType = invitation['roomType'] ?? 'Discussion'; // Default to Discussion

      AppLogger().info('🚪 Accepting invitation to $roomType: $roomName');

      // Mark invitation as accepted
      await _invitationService.acceptInvitation(invitationId);

      // Update user's online status before joining
      final currentUser = await _appwrite.account.get();
      await _presenceService.updateNow();

      return {
        'roomId': roomId,
        'roomName': roomName,
        'roomType': roomType,
        'inviterName': inviterName,
        'userId': currentUser.$id,
      };
    } catch (e) {
      AppLogger().error('Failed to accept invitation: $e');
      return null;
    }
  }

  /// Join room after invitation is accepted
  ///
  /// [context] - BuildContext for navigation
  /// [roomData] - Room data from acceptInvitation
  ///
  /// Returns true if successful, false otherwise
  Future<bool> joinRoom({
    required BuildContext context,
    required Map<String, dynamic> roomData,
  }) async {
    try {
      final roomId = roomData['roomId'];
      final roomName = roomData['roomName'];
      final roomType = roomData['roomType'];
      final inviterName = roomData['inviterName'];
      final userId = roomData['userId'];

      if (!context.mounted) return false;

      // Navigate to appropriate room based on type
      if (roomType.toLowerCase() == 'arena') {
        return await _joinArenaRoom(
          context: context,
          roomId: roomId,
          roomName: roomName,
          userId: userId,
        );
      } else {
        return await _joinDebatesDiscussionsRoom(
          context: context,
          roomId: roomId,
          roomName: roomName,
          inviterName: inviterName,
        );
      }
    } catch (e) {
      AppLogger().error('Failed to join room: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Join an Arena room
  Future<bool> _joinArenaRoom({
    required BuildContext context,
    required String roomId,
    required String roomName,
    required String userId,
  }) async {
    try {
      AppLogger().info('🏛️ Joining Arena room: $roomName');

      // Fetch arena room details
      final arenaRoom = await _appwrite.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
      );

      // Add user as audience member if not already a participant
      try {
        await _appwrite.assignArenaRole(
          roomId: roomId,
          userId: userId,
          role: 'audience',
        );
        AppLogger().info('✅ Added user to arena as audience');
      } catch (e) {
        AppLogger().warning('⚠️ Could not assign audience role (user may already be participant): $e');
      }

      if (!context.mounted) return false;

      // Navigate to Arena screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArenaScreen(
            roomId: roomId,
            challengeId: arenaRoom.data['challengeId'] ?? roomId,
            topic: arenaRoom.data['topic'] ?? roomName,
            description: arenaRoom.data['description'],
          ),
        ),
      );

      return true;
    } catch (e) {
      AppLogger().error('❌ Failed to join arena: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join arena: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Join a Debates & Discussions room
  Future<bool> _joinDebatesDiscussionsRoom({
    required BuildContext context,
    required String roomId,
    required String roomName,
    required String inviterName,
  }) async {
    try {
      AppLogger().info('💬 Joining Debates & Discussions room: $roomName');

      if (!context.mounted) return false;

      // Navigate to Debates & Discussions screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DebatesDiscussionsScreen(
            roomId: roomId,
            roomName: roomName,
            moderatorName: inviterName,
          ),
        ),
      );

      return true;
    } catch (e) {
      AppLogger().error('❌ Failed to join discussion room: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Decline a room invitation
  ///
  /// [invitationId] - The invitation document ID
  ///
  /// Returns true if successful, false otherwise
  Future<bool> declineInvitation(String invitationId) async {
    try {
      AppLogger().info('❌ Declining invitation: $invitationId');
      await _invitationService.declineInvitation(invitationId);
      return true;
    } catch (e) {
      AppLogger().error('Failed to decline invitation: $e');
      return false;
    }
  }
}
