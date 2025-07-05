import 'package:flutter/material.dart';
import '../../../../models/user_profile.dart';
import '../../../../widgets/user_avatar.dart';
import '../../constants/arena_colors.dart';

/// Audience Display Widget - DO NOT MODIFY LAYOUT
/// This widget displays the scrollable audience grid exactly as in the original
class AudienceDisplayWidget extends StatelessWidget {
  final List<UserProfile> audience;

  const AudienceDisplayWidget({
    super.key,
    required this.audience,
  });

  @override
  Widget build(BuildContext context) {
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
                color: ArenaColors.accentPurple,
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
}