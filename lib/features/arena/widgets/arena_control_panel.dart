import 'package:flutter/material.dart';
import '../constants/arena_colors.dart';

/// Arena Control Panel - DO NOT MODIFY LAYOUT
/// This is the bottom control panel with all arena actions
class ArenaControlPanel extends StatelessWidget {
  final bool judgingComplete;
  final String? winner;
  final bool isJudge;
  final bool isModerator;
  final bool hasCurrentUserSubmittedVote;
  final bool judgingEnabled;
  final VoidCallback? onShowResults;
  final VoidCallback? onShowJudging;
  final VoidCallback onShowGift;
  final VoidCallback onShowChat;
  final VoidCallback onShowRoleManager;

  const ArenaControlPanel({
    super.key,
    required this.judgingComplete,
    this.winner,
    required this.isJudge,
    required this.isModerator,
    required this.hasCurrentUserSubmittedVote,
    required this.judgingEnabled,
    this.onShowResults,
    this.onShowJudging,
    required this.onShowGift,
    required this.onShowChat,
    required this.onShowRoleManager,
  });

  @override
  Widget build(BuildContext context) {
    // Always show control panel - at minimum for gifting
    // Specific controls will be filtered based on role

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // View Results button (when judging is complete)
              if (judgingComplete && winner != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildControlButton(
                    icon: Icons.emoji_events,
                    label: 'View Results',
                    onPressed: onShowResults,
                    color: Colors.amber,
                  ),
                ),
              
              // Judge Panel (only for moderators and judges)
              if ((isJudge || isModerator) && !judgingComplete)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildControlButton(
                    icon: hasCurrentUserSubmittedVote 
                        ? Icons.check_circle 
                        : (judgingEnabled ? Icons.gavel : Icons.gavel_outlined),
                    label: hasCurrentUserSubmittedVote 
                        ? 'Vote Submitted' 
                        : (judgingEnabled ? 'Judge' : 'Vote Closed'),
                    onPressed: hasCurrentUserSubmittedVote 
                        ? null 
                        : (judgingEnabled ? onShowJudging : null),
                    color: hasCurrentUserSubmittedVote 
                        ? Colors.green 
                        : (judgingEnabled ? Colors.amber : Colors.grey),
                    isEnabled: !hasCurrentUserSubmittedVote && judgingEnabled,
                  ),
                ),
              
              // Gift button (always visible)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildControlButton(
                  icon: Icons.card_giftcard,
                  label: 'Gift',
                  onPressed: onShowGift,
                  color: Colors.amber,
                ),
              ),

              // Chat button (always visible)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildControlButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  onPressed: onShowChat,
                  color: Colors.blue,
                ),
              ),

              // Role Manager (always available for testing)
              if (!judgingComplete)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildControlButton(
                    icon: Icons.people,
                    label: 'Roles',
                    onPressed: onShowRoleManager,
                    color: ArenaColors.accentPurple,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
    bool isEnabled = true,
  }) {
    final actuallyEnabled = isEnabled && onPressed != null;
    
    return GestureDetector(
      onTap: actuallyEnabled ? onPressed : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10), // Reduced from 12
            decoration: BoxDecoration(
              color: actuallyEnabled ? color : Colors.grey[600],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20, // Reduced from 24
            ),
          ),
          const SizedBox(height: 3), // Reduced from 4
          Text(
            label,
            style: TextStyle(
              color: actuallyEnabled ? Colors.white : Colors.grey[400],
              fontSize: 10, // Reduced from 12
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}