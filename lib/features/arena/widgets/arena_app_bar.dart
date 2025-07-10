import 'package:flutter/material.dart';
import '../constants/arena_colors.dart';
import '../../../core/logging/app_logger.dart';
import '../../../screens/arena_modals.dart';

/// Arena App Bar - DO NOT MODIFY LAYOUT
/// This is the exact app bar from the original arena with timer and moderator controls
class ArenaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isModerator;
  final bool isTimerRunning;
  final String formattedTime;
  final VoidCallback onShowModeratorControls;
  final VoidCallback onShowTimerControls;
  final VoidCallback onExitArena;

  const ArenaAppBar({
    super.key,
    required this.isModerator,
    required this.isTimerRunning,
    required this.formattedTime,
    required this.onShowModeratorControls,
    required this.onShowTimerControls,
    required this.onExitArena,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Moderator Controls Icon (only visible to moderators)
          if (isModerator)
            IconButton(
              onPressed: onShowModeratorControls,
              icon: const Icon(Icons.admin_panel_settings, color: Colors.amber),
              tooltip: 'Moderator Controls',
            )
          else
            const SizedBox(width: 48), // Maintain spacing
          
          // Timer in center (clickable for moderators)
          GestureDetector(
            onTap: isModerator ? onShowTimerControls : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isTimerRunning ? ArenaColors.scarletRed : ArenaColors.accentPurple,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formattedTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (isModerator) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.settings, color: Colors.white, size: 14),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 48), // Maintain spacing for balance
        ],
      ),
      actions: [
        // Rules and Guidelines button
        IconButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const DebateRulesModal(),
            );
          },
          icon: const Icon(Icons.info, color: Colors.white, size: 24),
          tooltip: 'Debate Rules & Guidelines',
        ),
        // Leave button
        IconButton(
          onPressed: () {
            AppLogger().info('🚪 EXIT: Exit button clicked in ArenaAppBar');
            onExitArena();
          },
          icon: const Icon(Icons.exit_to_app, color: Colors.white),
          tooltip: 'Leave Arena',
        ),
      ],
    );
  }
}