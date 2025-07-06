import 'package:flutter/material.dart';
import '../widgets/user_avatar.dart';
import '../models/user_profile.dart';

// Color constants used in participant displays
class ArenaParticipantColors {
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color deepPurple = Color(0xFF6B46C1);
  static const Color lightGray = Color(0xFFF5F5F5);
}

class ArenaParticipantWidgets {
  // Build compact audience display with scrolling
  static Widget buildCompactAudienceDisplay(List<UserProfile> audience) {
    if (audience.isEmpty) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              color: Colors.white54,
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              'No audience yet',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              const Icon(
                Icons.people,
                color: ArenaParticipantColors.accentPurple,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Audience (${audience.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Grid of audience members - fixed height with scrolling
        SizedBox(
          height: 140, // Fixed height like Debates & Discussions
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            physics: const BouncingScrollPhysics(), // Enable scrolling
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // 4 users across
              crossAxisSpacing: 6, // Reduced spacing
              mainAxisSpacing: 6, // Reduced spacing  
              childAspectRatio: 0.85, // Adjusted for compact layout
            ),
            itemCount: audience.length,
            itemBuilder: (context, index) {
              final audienceMember = audience[index];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(
                    avatarUrl: audienceMember.avatar,
                    initials: audienceMember.name.isNotEmpty ? audienceMember.name[0] : '?',
                    radius: 28, // Slightly smaller to fit better with reduced spacing
                  ),
                  const SizedBox(height: 3),
                  Text(
                    audienceMember.name.length > 7 
                        ? '${audienceMember.name.substring(0, 7)}...'
                        : audienceMember.name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // Build debater position with role-specific styling
  static Widget buildDebaterPosition(
    String role, 
    String title, 
    Map<String, UserProfile> participants,
    String? winner,
    {VoidCallback? onTap}
  ) {
    final participant = participants[role];
    final isAffirmative = role == 'affirmative';
    final isWinner = winner == role;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isAffirmative
                ? [Colors.green.withValues(alpha: 0.8), Colors.green.withValues(alpha: 0.6)]
                : [ArenaParticipantColors.scarletRed.withValues(alpha: 0.8), ArenaParticipantColors.scarletRed.withValues(alpha: 0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: isWinner
              ? Border.all(color: Colors.amber, width: 3)
              : null,
          boxShadow: [
            BoxShadow(
              color: (isAffirmative ? Colors.green : ArenaParticipantColors.scarletRed).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Winner crown
            if (isWinner) ...[
              const Icon(
                Icons.emoji_events,
                color: Colors.amber,
                size: 24,
              ),
              const SizedBox(height: 4),
            ],
            
            // Title
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            // Participant content
            if (participant != null)
              buildParticipantTile(participant, isMain: true, isWinner: isWinner)
            else
              buildEmptyPosition('Waiting for ${isAffirmative ? 'affirmative' : 'negative'} debater...'),
          ],
        ),
      ),
    );
  }

  // Build judge position
  static Widget buildJudgePosition(
    String role, 
    String title, 
    Map<String, UserProfile> participants,
    {bool isPurple = false, VoidCallback? onTap}
  ) {
    final participant = participants[role];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPurple
                ? [ArenaParticipantColors.accentPurple.withValues(alpha: 0.8), ArenaParticipantColors.deepPurple.withValues(alpha: 0.8)]
                : [Colors.amber.withValues(alpha: 0.8), Colors.orange.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (isPurple ? ArenaParticipantColors.accentPurple : Colors.amber).withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 6),
            
            // Participant content
            if (participant != null)
              buildParticipantTile(participant, isSmall: true)
            else
              buildEmptyPosition('Waiting...', isSmall: true),
          ],
        ),
      ),
    );
  }

  // Build simple audience display
  static Widget buildSimpleAudienceDisplay(List<UserProfile> audience) {
    if (audience.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, color: Colors.white54, size: 20),
            SizedBox(width: 8),
            Text(
              'No audience members yet',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // Calculate grid height for simple display (max 2 rows)
    final rowCount = (audience.length / 4).ceil();
    final gridHeight = (rowCount * 70.0).clamp(70.0, 140.0); // Max 2 rows

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with audience count
          Row(
            children: [
              const Icon(
                Icons.people,
                color: ArenaParticipantColors.accentPurple,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Audience (${audience.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Grid of audience members with fixed height
          SizedBox(
            height: gridHeight,
            child: GridView.builder(
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: audience.length,
              itemBuilder: (context, index) {
                final audienceMember = audience[index];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    UserAvatar(
                      avatarUrl: audienceMember.avatar,
                      initials: audienceMember.name.isNotEmpty ? audienceMember.name[0] : '?',
                      radius: 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      audienceMember.name.length > 6
                          ? '${audienceMember.name.substring(0, 6)}...'
                          : audienceMember.name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Build individual participant tile
  static Widget buildParticipantTile(
    UserProfile participant, 
    {bool isMain = false, bool isSmall = false, bool isWinner = false}
  ) {
    final avatarRadius = isMain ? 40.0 : (isSmall ? 20.0 : 30.0);
    final nameSize = isMain ? 14.0 : (isSmall ? 10.0 : 12.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Winner glow effect
        if (isWinner && isMain) ...[
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.6),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: UserAvatar(
              avatarUrl: participant.avatar,
              initials: participant.name.isNotEmpty ? participant.name[0] : '?',
              radius: avatarRadius,
            ),
          ),
        ] else ...[
          UserAvatar(
            avatarUrl: participant.avatar,
            initials: participant.name.isNotEmpty ? participant.name[0] : '?',
            radius: avatarRadius,
          ),
        ],
        
        SizedBox(height: isSmall ? 4 : 8),
        
        // Participant name
        Text(
          participant.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: nameSize,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: isSmall ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        // Winner badge
        if (isWinner && !isSmall) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'WINNER',
              style: TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Build empty position placeholder
  static Widget buildEmptyPosition(String text, {bool isSmall = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.person_add_outlined,
          color: Colors.white54,
          size: isSmall ? 20 : 30,
        ),
        SizedBox(height: isSmall ? 4 : 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.white54,
            fontSize: isSmall ? 8 : 10,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
          maxLines: isSmall ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Build participant info for results modal
  static Widget buildParticipantInfo(String role, UserProfile user, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          UserAvatar(
            avatarUrl: user.avatar,
            initials: user.name.isNotEmpty ? user.name[0] : '?',
            radius: 25,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Show participant view modal
  static void showParticipantView(
    BuildContext context,
    UserProfile participant,
    String role,
    {VoidCallback? onInvite, VoidCallback? onRemove}
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${participant.name} - ${role.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              avatarUrl: participant.avatar,
              initials: participant.name.isNotEmpty ? participant.name[0] : '?',
              radius: 50,
            ),
            const SizedBox(height: 16),
            Text(
              participant.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (participant.bio?.isNotEmpty == true) ...[
              Text(
                participant.bio!,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      '${participant.totalWins}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const Text('Wins', style: TextStyle(fontSize: 12)),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${participant.totalDebates}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Text('Debates', style: TextStyle(fontSize: 12)),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${participant.reputation}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ArenaParticipantColors.accentPurple,
                      ),
                    ),
                    const Text('Rep.', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (onInvite != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onInvite();
              },
              child: const Text('Invite'),
            ),
          if (onRemove != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onRemove();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}