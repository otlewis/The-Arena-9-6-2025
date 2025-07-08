import 'package:flutter/material.dart';

class DiscussionRoomCard extends StatelessWidget {
  final Map<String, dynamic> roomData;
  final VoidCallback? onTap;

  const DiscussionRoomCard({
    super.key,
    required this.roomData,
    this.onTap,
  });

  // Purple theme colors
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);
  static const Color lightPurple = Color(0xFFF3F4F6);
  static const Color accentPurple = Color(0xFF9333EA);

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'religion':
        return Colors.amber;
      case 'sports':
        return Colors.green;
      case 'science':
        return Colors.blue;
      case 'technology':
        return Colors.cyan;
      case 'music':
        return Colors.pink;
      case 'business':
        return Colors.orange;
      case 'art':
        return Colors.purple;
      case 'education':
        return Colors.indigo;
      case 'social':
        return Colors.teal;
      case 'gaming':
        return Colors.red;
      default:
        return primaryPurple;
    }
  }

  IconData _getDebateStyleIcon(String style) {
    switch (style.toLowerCase()) {
      case 'debate':
        return Icons.gavel;
      case 'discussion':
        return Icons.forum;
      case 'take':
        return Icons.flash_on;
      default:
        return Icons.chat;
    }
  }

  Color _getDebateStyleColor(String style) {
    switch (style.toLowerCase()) {
      case 'debate':
        return Colors.red;
      case 'discussion':
        return primaryPurple;
      case 'take':
        return Colors.orange;
      default:
        return primaryPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomName = roomData['name'] ?? 'Untitled Room';
    final moderatorName = roomData['moderator'] ?? 'Unknown Moderator';
    final category = roomData['category'] ?? 'General';
    final debateStyle = roomData['debateStyle'] ?? 'Discussion';
    final description = roomData['description'] ?? '';
    final participantCount = roomData['participantCount'] ?? 0;
    final isLive = roomData['isLive'] ?? false;
    final isPrivate = roomData['isPrivate'] ?? false;
    final moderatorAvatar = roomData['moderatorAvatar'];
    
    // Debug print to check data
    debugPrint('Room Card - Moderator: $moderatorName, Avatar: $moderatorAvatar');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with live indicator and privacy icon
                Row(
                  children: [
                    if (isLive) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 8),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(category).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getCategoryColor(category),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: _getCategoryColor(category),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    if (isPrivate)
                      Icon(
                        Icons.lock,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Room title
                Text(
                  roomName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Bottom section with moderator info and debate style
                Row(
                  children: [
                    // Moderator info
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: primaryPurple,
                              shape: BoxShape.circle,
                            ),
                            child: moderatorAvatar != null && moderatorAvatar.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      moderatorAvatar,
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Text(
                                            moderatorName.isNotEmpty ? moderatorName[0].toUpperCase() : 'M',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      moderatorName.isNotEmpty ? moderatorName[0].toUpperCase() : 'M',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  moderatorName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'Moderator',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Debate style and participant count
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getDebateStyleColor(debateStyle).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getDebateStyleIcon(debateStyle),
                                size: 14,
                                color: _getDebateStyleColor(debateStyle),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                debateStyle,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getDebateStyleColor(debateStyle),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$participantCount',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}