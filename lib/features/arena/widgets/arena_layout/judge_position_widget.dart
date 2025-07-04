import 'package:flutter/material.dart';
import '../../../../models/user_profile.dart';
import '../../../../widgets/user_avatar.dart';
import '../../constants/arena_colors.dart';

/// Judge Position Widget - DO NOT MODIFY LAYOUT
/// This widget displays judges and moderator positions
class JudgePositionWidget extends StatelessWidget {
  final String role;
  final String title;
  final UserProfile? participant;
  final bool isPurple;

  const JudgePositionWidget({
    super.key,
    required this.role,
    required this.title,
    this.participant,
    this.isPurple = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isPurple ? ArenaColors.accentPurple.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
        border: Border.all(color: isPurple ? ArenaColors.accentPurple : Colors.amber, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isPurple ? ArenaColors.accentPurple : Colors.amber,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: participant != null
                ? _buildParticipantTile(participant!, isSmall: true)
                : _buildEmptyPosition('Waiting...', isSmall: true),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(UserProfile participant, {bool isMain = false, bool isSmall = false, bool isWinner = false}) {
    final avatarSize = isMain ? 32.0 : isSmall ? 16.0 : 24.0;
    final nameSize = isMain ? 12.0 : isSmall ? 9.0 : 10.0;
    
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Crown for winner
          if (isWinner && isMain) ...[
            const Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 18,
            ),
            const SizedBox(height: 1),
          ],
          
          // Avatar with special border for winner
          Container(
            decoration: isWinner ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.amber,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ) : null,
            child: UserAvatar(
              avatarUrl: participant.avatar,
              initials: participant.name.isNotEmpty ? participant.name[0] : '?',
              radius: avatarSize,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            participant.name,
            style: TextStyle(
              color: isWinner ? Colors.amber : Colors.white,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.w600,
              fontSize: nameSize,
              shadows: isWinner ? [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 2,
                ),
              ] : null,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPosition(String text, {bool isSmall = false}) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white54,
            fontSize: isSmall ? 9 : 10,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}