import 'package:flutter/material.dart';
import '../../../../models/user_profile.dart';
import '../../../../widgets/user_avatar.dart';

/// Debater Position Widget - DO NOT MODIFY LAYOUT
/// This widget displays the affirmative or negative debater with winner effects
class DebaterPositionWidget extends StatelessWidget {
  final String role;
  final String title;
  final UserProfile? participant;
  final bool judgingComplete;
  final String? winner;

  const DebaterPositionWidget({
    super.key,
    required this.role,
    required this.title,
    this.participant,
    required this.judgingComplete,
    this.winner,
  });

  @override
  Widget build(BuildContext context) {
    final isAffirmative = role == 'affirmative';
    final isWinner = judgingComplete && winner == role;
    
    return Container(
      decoration: BoxDecoration(
        color: isAffirmative ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        border: Border.all(
          color: isWinner 
              ? Colors.amber 
              : (isAffirmative ? Colors.green : Colors.red),
          width: isWinner ? 4 : 2,
        ),
        borderRadius: BorderRadius.circular(12),
        // Add golden glow effect for winner
        boxShadow: isWinner ? [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.5),
            blurRadius: 12,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ] : null,
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isWinner 
                  ? Colors.amber
                  : (isAffirmative ? Colors.green : Colors.red),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isWinner) ...[
                  const Icon(Icons.emoji_events, color: Colors.black, size: 16),
                  const SizedBox(width: 4),
                ],
                Text(
                  isWinner ? 'WINNER' : title,
                  style: TextStyle(
                    color: isWinner ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isWinner) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.emoji_events, color: Colors.black, size: 16),
                ],
              ],
            ),
          ),
          Expanded(
            child: participant != null
                ? _buildParticipantTile(participant!, isMain: true, isWinner: isWinner)
                : _buildEmptyPosition('Waiting for $title...'),
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