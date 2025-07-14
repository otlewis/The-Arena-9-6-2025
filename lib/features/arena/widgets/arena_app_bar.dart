import 'package:flutter/material.dart';
import '../../../core/logging/app_logger.dart';
import '../../../screens/arena_modals.dart';
import '../../../widgets/appwrite_timer_widget.dart';
import '../../../models/timer_state.dart';

/// Arena App Bar - DO NOT MODIFY LAYOUT
/// This is the exact app bar from the original arena with timer and moderator controls
class ArenaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isModerator;
  final bool isTimerRunning;
  final String formattedTime;
  final VoidCallback onShowModeratorControls;
  final VoidCallback onShowTimerControls;
  final VoidCallback onExitArena;
  final VoidCallback onEmergencyCloseRoom;
  final String roomId;
  final String userId;

  const ArenaAppBar({
    super.key,
    required this.isModerator,
    required this.isTimerRunning,
    required this.formattedTime,
    required this.onShowModeratorControls,
    required this.onShowTimerControls,
    required this.onExitArena,
    required this.onEmergencyCloseRoom,
    required this.roomId,
    required this.userId,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      toolbarHeight: 56,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          AppLogger().info('🚪 EXIT: Back button clicked in ArenaAppBar');
          onExitArena();
        },
      ),
      title: Row(
        children: [
          // Moderator Controls Icons (only visible to moderators)
          if (isModerator)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: onShowModeratorControls,
                    icon: const Icon(Icons.admin_panel_settings, color: Colors.amber, size: 18),
                    tooltip: 'Moderator Controls',
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: onEmergencyCloseRoom,
                    icon: const Icon(Icons.close, color: Colors.red, size: 18),
                    tooltip: 'Emergency Close Room',
                  ),
                ),
              ],
            ),
          
          // Appwrite Timer (synchronized across devices)
          Expanded(
            child: Center(
              child: AppwriteTimerWidget(
                roomId: roomId,
                roomType: RoomType.arena,
                isModerator: isModerator,
                userId: userId,
                compact: true,
                showControls: isModerator,
                showConnectionStatus: false,
                onTimerExpired: () {
                  // Handle timer expiration for debate phases
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Rules and Guidelines button
        SizedBox(
          width: 40,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const DebateRulesModal(),
              );
            },
            icon: const Icon(Icons.info, color: Colors.white, size: 20),
            tooltip: 'Debate Rules & Guidelines',
          ),
        ),
        // Leave button
        SizedBox(
          width: 40,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              AppLogger().info('🚪 EXIT: Exit button clicked in ArenaAppBar');
              onExitArena();
            },
            icon: const Icon(Icons.exit_to_app, color: Colors.white, size: 20),
            tooltip: 'Leave Arena',
          ),
        ),
      ],
    );
  }
}