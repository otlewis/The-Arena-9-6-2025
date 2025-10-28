import 'package:flutter/material.dart';
// import 'dart:async'; // Removed - no longer needed
import '../../../core/logging/app_logger.dart';
import '../../../screens/arena_modals.dart';
import '../../../widgets/challenge_bell.dart';
import '../../../widgets/network_quality_indicator.dart';
import '../../../widgets/simple_timer.dart';
// import '../../../services/livekit_service.dart'; // Removed unused import

/// Arena App Bar - DO NOT MODIFY LAYOUT
/// This is the exact app bar from the original arena with timer and moderator controls
class ArenaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isModerator;
  final bool isDebater; // DEBATER MODERATOR: Track if user is a debater
  final VoidCallback onShowModeratorControls;
  final VoidCallback? onShowDebaterControls; // DEBATER MODERATOR: Optional debater controls
  final VoidCallback onExitArena;
  final VoidCallback onEmergencyCloseRoom;
  final String roomId;
  final String userId;
  final int votedCount; // Number of judges who have voted
  final int totalCount; // Total number of judges

  const ArenaAppBar({
    super.key,
    required this.isModerator,
    this.isDebater = false, // DEBATER MODERATOR: Default to false
    required this.onShowModeratorControls,
    this.onShowDebaterControls, // DEBATER MODERATOR: Optional callback
    required this.onExitArena,
    required this.onEmergencyCloseRoom,
    required this.roomId,
    required this.userId,
    this.votedCount = 0,
    this.totalCount = 0,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    
    AppLogger().debug('⚙️ ArenaAppBar building - isModerator: $isModerator, showControls: $isModerator');
    
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
          
          
          return Row(
            children: [
              // Moderator Controls Icons (only visible to moderators) - more compact on small screens
              if (isModerator)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isSmallScreen ? 24 : 28,
                      height: isSmallScreen ? 24 : 28,
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.purple, width: 1.5),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: onShowModeratorControls,
                        icon: Icon(Icons.admin_panel_settings,
                               color: Colors.purple,
                               size: isSmallScreen ? 14 : 16),
                        tooltip: 'Moderator Controls',
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 1 : 2),
                    SizedBox(
                      width: isSmallScreen ? 20 : 24,
                      height: isSmallScreen ? 20 : 24,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: onEmergencyCloseRoom,
                        icon: Icon(Icons.close,
                               color: Colors.red,
                               size: isSmallScreen ? 12 : 14),
                        tooltip: 'Emergency Close Room',
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 2 : 4),
                  ],
                ),

              // DEBATER MODERATOR: Debater Controls Icon (visible to debaters when no moderator)
              if (!isModerator && isDebater && onShowDebaterControls != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isSmallScreen ? 24 : 28,
                      height: isSmallScreen ? 24 : 28,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 1.5),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: onShowDebaterControls,
                        icon: Icon(Icons.person_add,
                               color: Colors.blue,
                               size: isSmallScreen ? 14 : 16),
                        tooltip: 'Select Moderator',
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 2 : 4),
                  ],
                ),
              
              // Simple Timer in header center with vote indicators
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Vote indicator bars (3 bars that turn green when votes come in)
                      // Always show 3 bars for arena debates
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (index) {
                          final hasVoted = index < votedCount;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Container(
                              width: 3,
                              height: 16,
                              decoration: BoxDecoration(
                                color: hasVoted ? Colors.green : Colors.red,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 6),
                      // Timer
                      const SimpleTimer(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        // Network quality indicator - more compact on small screens
        SizedBox(
          width: isSmallScreen ? 24 : 28,
          child: const Center(
            child: CompactNetworkIndicator(),
          ),
        ),
        // Challenge notification bell - more compact on small screens
        SizedBox(
          width: isSmallScreen ? 28 : 32,
          child: Center(
            child: ChallengeBell(
              iconColor: Colors.white,
              iconSize: isSmallScreen ? 16 : 18,
            ),
          ),
        ),
        // Info/Rules button for everyone
        SizedBox(
          width: isSmallScreen ? 28 : 32,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              AppLogger().debug('ℹ️ Opening debate rules');
              showDialog(
                context: context,
                builder: (context) => const DebateRulesModal(),
              );
            },
            icon: Icon(Icons.info, 
                     color: Colors.white, 
                     size: isSmallScreen ? 16 : 18),
            tooltip: 'Debate Rules & Guidelines',
          ),
        ),
        // Leave button - more compact on small screens
        SizedBox(
          width: isSmallScreen ? 28 : 32,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              AppLogger().info('🚪 EXIT: Exit button clicked in ArenaAppBar');
              onExitArena();
            },
            icon: Icon(Icons.exit_to_app, 
                     color: Colors.white, 
                     size: isSmallScreen ? 16 : 18),
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