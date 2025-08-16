import 'package:flutter/material.dart';
// import 'dart:async'; // Removed - no longer needed
import '../../../core/logging/app_logger.dart';
import '../../../screens/arena_modals.dart';
import '../../../widgets/appwrite_timer_widget.dart';
import '../../../widgets/challenge_bell.dart';
import '../../../widgets/instant_message_bell.dart';
import '../../../widgets/network_quality_indicator.dart';
import '../../../models/timer_state.dart';
// import '../../../services/livekit_service.dart'; // Removed unused import

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
      title: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate available space for timer
          final moderatorControlsWidth = isModerator ? 58 : 0; // 28 + 2 + 24 + 4 = more accurate calculation
          final availableWidth = constraints.maxWidth - moderatorControlsWidth;
          
          return Row(
            children: [
              // Moderator Controls Icons (only visible to moderators) - more compact
              if (isModerator)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,  // Further reduced from 32
                      height: 28, // Further reduced from 32
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.purple, width: 1.5), // Thinner border
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: onShowModeratorControls,
                        icon: const Icon(Icons.admin_panel_settings, color: Colors.purple, size: 16), // Further reduced
                        tooltip: 'Moderator Controls',
                      ),
                    ),
                    const SizedBox(width: 2), // Minimal spacing
                    SizedBox(
                      width: 24,  // Further reduced from 28
                      height: 24, // Further reduced from 28
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: onEmergencyCloseRoom,
                        icon: const Icon(Icons.close, color: Colors.red, size: 14), // Further reduced
                        tooltip: 'Emergency Close Room',
                      ),
                    ),
                    const SizedBox(width: 4), // Minimal space after controls
                  ],
                ),
              
              // Appwrite Timer (synchronized across devices) - constrained to available space
              Expanded(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: availableWidth * 0.9, // Allow more space for larger timer
                  ),
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
              ),
            ],
          );
        },
      ),
      actions: [
        // Network quality indicator - more compact
        const SizedBox(
          width: 28, // Reduced from 32
          child: Center(
            child: CompactNetworkIndicator(),
          ),
        ),
        // Challenge notification bell - more compact
        const SizedBox(
          width: 32, // Reduced from 40
          child: Center(
            child: ChallengeBell(
              iconColor: Colors.white,
              iconSize: 18, // Reduced from 20
            ),
          ),
        ),
        // Message notification bell - more compact
        const SizedBox(
          width: 32, // Reduced from 40
          child: Center(
            child: InstantMessageBell(
              iconColor: Colors.white,
              iconSize: 18, // Reduced from 20
            ),
          ),
        ),
        // Rules and Guidelines button - more compact
        SizedBox(
          width: 32, // Reduced from 40
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const DebateRulesModal(),
              );
            },
            icon: const Icon(Icons.info, color: Colors.white, size: 18), // Reduced from 20
            tooltip: 'Debate Rules & Guidelines',
          ),
        ),
        // Leave button - more compact
        SizedBox(
          width: 32, // Reduced from 40
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              AppLogger().info('🚪 EXIT: Exit button clicked in ArenaAppBar');
              onExitArena();
            },
            icon: const Icon(Icons.exit_to_app, color: Colors.white, size: 18), // Reduced from 20
            tooltip: 'Leave Arena',
          ),
        ),
      ],
    );
  }
}

// Audio Quality Indicator Widget removed - keeping original layout

// Audio Quality Indicator State removed
// All Audio Quality Indicator code removed - keeping original layout