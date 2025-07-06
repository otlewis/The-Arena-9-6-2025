import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../../../main.dart' show ArenaApp;
import '../../../services/appwrite_service.dart';
import '../../../core/logging/app_logger.dart';
import '../controllers/arena_state_controller.dart';

/// Arena Navigation Service - DO NOT MODIFY NAVIGATION LOGIC
/// This service handles all arena exit and navigation exactly as the original
class ArenaNavigationService {
  final ArenaStateController _stateController;
  final AppwriteService _appwrite = AppwriteService();
  final String roomId;

  ArenaNavigationService({
    required ArenaStateController stateController,
    required this.roomId,
  }) : _stateController = stateController;

  /// Show exit confirmation dialog
  void showExitDialog(BuildContext context) {
    AppLogger().info('🚪 EXIT: showExitDialog called');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.orange),
            SizedBox(width: 8),
            Text('Leave Arena'),
          ],
        ),
        content: Text(_stateController.isModerator 
            ? 'As the moderator, leaving will close this arena room for all participants. Are you sure?'
            : 'Are you sure you want to leave this arena?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () async {
              AppLogger().info('🚪 EXIT: User confirmed exit');
              Navigator.pop(context); // Close dialog
              
              // Prevent any further state updates
              if (_stateController.isExiting) {
                AppLogger().warning('🚪 EXIT: Already exiting, ignoring duplicate request');
                return;
              }
              _stateController.setIsExiting(true);
              
              AppLogger().info('🚪 EXIT: Starting exit process...');
              AppLogger().info('🚪 EXIT: Is moderator: ${_stateController.isModerator}');
              
              // If moderator is leaving, close the entire room
              if (_stateController.isModerator) {
                AppLogger().info('🚪 EXIT: Handling moderator exit');
                await _handleModeratorExit(context);
              } else {
                AppLogger().info('🚪 EXIT: Handling participant exit');
                await _handleParticipantExit(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  /// Handle moderator exit (closes entire room)
  Future<void> _handleModeratorExit(BuildContext context) async {
    try {
      AppLogger().info('🚪 EXIT: 👑 Moderator leaving - closing entire room');
      
      // 1. Cancel all timers and subscriptions immediately
      AppLogger().info('🚪 EXIT: Step 1 - Cancelling timers and subscriptions');
      _stateController.cancelAllTimersAndSubscriptions();
      AppLogger().info('🚪 EXIT: Step 1 completed');
      
      // 2. Close the room and remove all participants
      AppLogger().info('🚪 EXIT: Step 2 - Closing room and removing participants');
      await _closeRoomDueToModeratorExit();
      AppLogger().info('🚪 EXIT: Step 2 completed');
      
      // 3. Navigate home
      AppLogger().info('🚪 EXIT: Step 3 - Navigating home');
      if (context.mounted) {
        _forceNavigationHomeSync(context);
      }
      AppLogger().info('🚪 EXIT: Step 3 completed');
      
    } catch (e) {
      AppLogger().error('🚪 EXIT: Error in moderator exit: $e');
      AppLogger().info('🚪 EXIT: Attempting fallback navigation');
      if (context.mounted) {
        _forceNavigationHomeSync(context); // Still navigate even if cleanup fails
      }
    }
  }

  /// Handle participant exit (removes only this participant)
  Future<void> _handleParticipantExit(BuildContext context) async {
    try {
      AppLogger().info('🚪 EXIT: 👤 Participant leaving arena');
      
      // 1. Cancel all timers and subscriptions immediately
      AppLogger().info('🚪 EXIT: Step 1 - Cancelling timers and subscriptions');
      _stateController.cancelAllTimersAndSubscriptions();
      AppLogger().info('🚪 EXIT: Step 1 completed');
      
      // 2. Remove only this participant
      AppLogger().info('🚪 EXIT: Step 2 - Removing current user from room');
      await _removeCurrentUserFromRoom();
      AppLogger().info('🚪 EXIT: Step 2 completed');
      
      // 3. Navigate home
      AppLogger().info('🚪 EXIT: Step 3 - Navigating home');
      if (context.mounted) {
        _forceNavigationHomeSync(context);
      }
      AppLogger().info('🚪 EXIT: Step 3 completed');
      
    } catch (e) {
      AppLogger().error('🚪 EXIT: Error in participant exit: $e');
      AppLogger().info('🚪 EXIT: Attempting fallback navigation');
      if (context.mounted) {
        _forceNavigationHomeSync(context); // Still navigate even if cleanup fails
      }
    }
  }

  /// Close room due to moderator exit
  Future<void> _closeRoomDueToModeratorExit() async {
    try {
      AppLogger().info('🚪 EXIT: 🔒 Closing room due to moderator exit...');
      
      // 1. Update room status to abandoned (only using existing schema fields)
      AppLogger().info('🚪 EXIT: Updating room status to abandoned...');
      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'status': 'abandoned',
        },
      );
      AppLogger().info('🚪 EXIT: Room status updated successfully');
      
      // 2. Remove all participants
      AppLogger().info('🚪 EXIT: Getting participants to remove...');
      final participants = await _appwrite.getArenaParticipants(roomId);
      AppLogger().info('🚪 EXIT: Found ${participants.length} participants to remove');
      
      for (final participant in participants) {
        try {
          AppLogger().info('🚪 EXIT: Removing participant ${participant['id']}...');
          await _appwrite.databases.deleteDocument(
            databaseId: 'arena_db',
            collectionId: 'arena_participants',
            documentId: participant['id'],
          );
          AppLogger().info('🚪 EXIT: Participant ${participant['id']} removed successfully');
        } catch (e) {
          AppLogger().warning('🚪 EXIT: Error removing participant ${participant['id']}: $e');
        }
      }
      
      AppLogger().info('🚪 EXIT: Room closed and all participants removed');
      
    } catch (e) {
      AppLogger().error('🚪 EXIT: Error closing room: $e');
      rethrow; // Re-throw to trigger fallback navigation
    }
  }

  /// Remove current user from room
  Future<void> _removeCurrentUserFromRoom() async {
    try {
      if (_stateController.currentUserId == null) {
        AppLogger().warning('🚪 EXIT: Cannot remove user - no current user ID');
        return;
      }

      AppLogger().info('🚪 EXIT: 🚪 Removing current user from room...');
      AppLogger().info('🚪 EXIT: Current user ID: ${_stateController.currentUserId}');
      
      // Get current user's participant record and remove it
      AppLogger().info('🚪 EXIT: Querying for user participant records...');
      final participants = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', _stateController.currentUserId!),
        ],
      );
      
      AppLogger().info('🚪 EXIT: Found ${participants.documents.length} participant records to remove');
      
      for (final participant in participants.documents) {
        AppLogger().info('🚪 EXIT: Removing participant record ${participant.$id}...');
        await _appwrite.databases.deleteDocument(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          documentId: participant.$id,
        );
        AppLogger().info('🚪 EXIT: Participant record ${participant.$id} removed successfully');
      }
      
      AppLogger().info('🚪 EXIT: Current user removed from room');
      
    } catch (e) {
      AppLogger().error('🚪 EXIT: Error removing current user from room: $e');
      rethrow; // Re-throw to trigger fallback navigation
    }
  }

  /// Force navigation to home screen synchronously
  void _forceNavigationHomeSync(BuildContext context) {
    AppLogger().info('🚪 EXIT: _forceNavigationHomeSync called');
    AppLogger().info('🚪 EXIT: hasNavigated=${_stateController.hasNavigated}, context.mounted=${context.mounted}');
    
    if (!_stateController.hasNavigated && context.mounted) {
      _stateController.setHasNavigated(true);
      AppLogger().info('🚪 EXIT: 🏠 Forcing navigation back to home from arena');
      
      try {
        AppLogger().info('🚪 EXIT: Calling Navigator.of(context).pushAndRemoveUntil...');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ArenaApp()),
          (route) => false,
        );
        AppLogger().info('🚪 EXIT: ✅ Successfully navigated to Main App');
      } catch (e) {
        AppLogger().error('🚪 EXIT: ❌ Navigation failed: $e');
      }
    } else {
      if (_stateController.hasNavigated) {
        AppLogger().warning('🚪 EXIT: Navigation already attempted');
      }
      if (!context.mounted) {
        AppLogger().warning('🚪 EXIT: Context is not mounted');
      }
    }
  }

  /// Force navigation with callback (for modal usage)
  void forceNavigationWithCallback(BuildContext context, VoidCallback? onForceNavigation) {
    if (!_stateController.hasNavigated && context.mounted) {
      _stateController.setHasNavigated(true);
      AppLogger().info('Forcing navigation back to arena lobby from closing modal');
      
      // Call the parent's navigation callback if provided
      if (onForceNavigation != null) {
        onForceNavigation();
      } else {
        // Fallback navigation
        try {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ArenaApp()),
            (route) => false,
          );
          AppLogger().info('Successfully navigated from modal to Main App');
        } catch (e) {
          AppLogger().error('Modal navigation failed: $e');
        }
      }
    }
  }
}