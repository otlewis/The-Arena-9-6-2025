// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import '../core/logging/app_logger.dart';

/// High-performance audience grid optimized for Arena's needs
class PerformanceOptimizedAudienceGrid extends StatefulWidget {
  final List<Map<String, dynamic>> participants;
  final Function(String userId)? onParticipantTap;
  final String debugLabel;
  
  const PerformanceOptimizedAudienceGrid({
    super.key,
    required this.participants,
    this.onParticipantTap,
    this.debugLabel = 'AudienceGrid',
  });

  @override
  State<PerformanceOptimizedAudienceGrid> createState() => _PerformanceOptimizedAudienceGridState();
}

class _PerformanceOptimizedAudienceGridState extends State<PerformanceOptimizedAudienceGrid> {
  List<Map<String, dynamic>> _cachedParticipants = [];
  List<Widget> _cachedWidgets = [];
  
  @override
  void initState() {
    super.initState();
    _buildCachedWidgets();
  }
  
  @override
  void didUpdateWidget(PerformanceOptimizedAudienceGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only rebuild if participants actually changed (with deep comparison)
    if (_participantsEqual(_cachedParticipants, widget.participants)) {
      return;
    }
    
    AppLogger().debug('🔄 Rebuilding audience grid: ${widget.debugLabel}');
    _buildCachedWidgets();
  }
  
  /// Efficient deep comparison of participant lists
  bool _participantsEqual(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    
    for (int i = 0; i < a.length; i++) {
      if (a[i]['userId'] != b[i]['userId'] || 
          a[i]['name'] != b[i]['name'] ||
          a[i]['role'] != b[i]['role']) {
        return false;
      }
    }
    return true;
  }
  
  void _buildCachedWidgets() {
    _cachedParticipants = List.from(widget.participants);
    _cachedWidgets = widget.participants.map((participant) => 
      _AudienceCard(
        key: ValueKey(participant['userId'] ?? participant['id'] ?? DateTime.now().millisecondsSinceEpoch),
        participant: participant,
        onTap: widget.onParticipantTap,
      )
    ).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.participants.isEmpty) {
      return const Center(
        child: Text(
          'No participants yet',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 5 : 4;
    
    // Use RepaintBoundary for better performance
    return RepaintBoundary(
      child: GridView.custom(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(8),
        cacheExtent: 500, // Optimize for scrolling
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.8, // Adjusted for better proportions with name underneath
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        childrenDelegate: SliverChildBuilderDelegate(
          (context, index) => RepaintBoundary(child: _cachedWidgets[index]),
          childCount: _cachedWidgets.length,
        ),
      ),
    );
  }
}

/// Helper function to create stacked name display
Widget _buildStackedNameDisplay(String name) {
  if (name.isEmpty || name == 'Unknown') {
    return Text(
      'Unknown',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
  
  final parts = name.split(' ');
  
  // Single name - just show it
  if (parts.length == 1) {
    return Text(
      parts[0].length > 10 ? '${parts[0].substring(0, 10)}...' : parts[0],
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
  
  // Multiple names - stack first and last name
  if (parts.length >= 2) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          parts[0].length > 10 ? '${parts[0].substring(0, 10)}...' : parts[0],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          parts.last.length > 10 ? '${parts.last.substring(0, 10)}...' : parts.last,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
  
  // Fallback
  return Text(
    name.length > 10 ? '${name.substring(0, 10)}...' : name,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    textAlign: TextAlign.center,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

/// Helper function to create stacked name display for video tiles
Widget _buildStackedNameDisplayForVideoTile(String name) {
  if (name.isEmpty || name == 'Unknown') {
    return Text(
      'Unknown',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(
            offset: Offset(0, 1),
            blurRadius: 2,
            color: Colors.black54,
          ),
        ],
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
  
  final parts = name.split(' ');
  
  // Single name - just show it
  if (parts.length == 1) {
    return Text(
      parts[0].length > 10 ? '${parts[0].substring(0, 10)}...' : parts[0],
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(
            offset: Offset(0, 1),
            blurRadius: 2,
            color: Colors.black54,
          ),
        ],
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
  
  // Multiple names - stack first and last name
  if (parts.length >= 2) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          parts[0].length > 8 ? '${parts[0].substring(0, 8)}...' : parts[0],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.1,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 2,
                color: Colors.black54,
              ),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          parts.last.length > 8 ? '${parts.last.substring(0, 8)}...' : parts.last,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.1,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 2,
                color: Colors.black54,
              ),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
  
  // Fallback
  return Text(
    name.length > 10 ? '${name.substring(0, 10)}...' : name,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      shadows: [
        Shadow(
          offset: Offset(0, 1),
          blurRadius: 2,
          color: Colors.black54,
        ),
      ],
    ),
    textAlign: TextAlign.center,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

/// Helper function to create avatar text content from Map data - just first letter
Widget _buildAvatarTextFromMap(Map<String, dynamic> data, double fontSize) {
  final name = data['name'] ?? data['userName'] ?? '';
  String letter;
  
  if (name.isEmpty) {
    letter = 'U';
  } else {
    letter = name.substring(0, 1).toUpperCase();
  }
  
  return Center(
    child: Text(
      letter,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    ),
  );
}

/// Clean audience card matching the design in the image
class _AudienceCard extends StatelessWidget {
  final Map<String, dynamic> participant;
  final Function(String userId)? onTap;
  
  const _AudienceCard({
    super.key,
    required this.participant,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final userId = participant['userId'] ?? participant['id'] ?? '';
    final name = participant['name'] ?? participant['userName'] ?? 'Unknown';
    final avatarUrl = participant['avatarUrl'] ?? participant['avatar'] ?? '';
    
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap != null ? () => onTap!(userId) : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Round profile picture
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withValues(alpha: 0.3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: Color(0xFF8B5CF6),
                            shape: BoxShape.circle,
                          ),
                          child: _buildAvatarTextFromMap(participant, 20),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Color(0xFF8B5CF6),
                          shape: BoxShape.circle,
                        ),
                        child: _buildAvatarTextFromMap(participant, 20),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            // Name underneath
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildStackedNameDisplay(name),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optimized participant card with minimal rebuilds (legacy)
// ignore: unused_element
class _ParticipantCard extends StatelessWidget {
  final Map<String, dynamic> participant;
  final Function(String userId)? onTap;
  
  const _ParticipantCard({
    super.key, // ignore: unused_element_parameter
    required this.participant,
    this.onTap, // ignore: unused_element_parameter
  });
  
  @override
  Widget build(BuildContext context) {
    final userId = participant['userId'] ?? '';
    final name = participant['name'] ?? participant['userName'] ?? 'Unknown';
    final avatarUrl = participant['avatarUrl'] ?? participant['avatar'] ?? '';
    final role = participant['role'] ?? 'audience';
    
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap != null ? () => onTap!(userId) : null,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: _getRoleColor(role),
            borderRadius: BorderRadius.circular(12),
            border: role == 'speaker' 
              ? Border.all(color: Colors.purple, width: 2)
              : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _OptimizedAvatar(avatarUrl: avatarUrl),
              const SizedBox(height: 4),
              _OptimizedNameText(name: name),
              if (role != 'audience') _RoleBadge(role: role),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getRoleColor(String role) {
    switch (role) {
      case 'moderator':
        return Colors.red.withValues(alpha: 0.1);
      case 'speaker':
        return Colors.purple.withValues(alpha: 0.1);
      case 'pending':
        return Colors.orange.withValues(alpha: 0.1);
      default:
        return Colors.white;
    }
  }
}

/// Optimized avatar with caching
class _OptimizedAvatar extends StatelessWidget {
  final String avatarUrl;
  final double size;
  
  const _OptimizedAvatar({required this.avatarUrl, this.size = 50}); // ignore: unused_element_parameter
  
  @override
  Widget build(BuildContext context) {
    
    if (avatarUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.person,
          color: Colors.white,
          size: 28,
        ),
      );
    }
    
    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: 80, // Reduce memory usage
        cacheHeight: 80,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            color: Colors.grey[300],
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 24),
          );
        },
      ),
    );
  }
}

/// Optimized name text with truncation
class _OptimizedNameText extends StatelessWidget {
  final String name;
  final double fontSize;
  
  const _OptimizedNameText({required this.name, this.fontSize = 10}); // ignore: unused_element_parameter
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        name,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Optimized role badge
class _RoleBadge extends StatelessWidget {
  final String role;
  
  const _RoleBadge({required this.role});
  
  @override
  Widget build(BuildContext context) {
    late final Color badgeColor;
    late final IconData icon;
    
    switch (role) {
      case 'moderator':
        badgeColor = Colors.red;
        icon = Icons.gavel;
        break;
      case 'speaker':
        badgeColor = Colors.purple;
        icon = Icons.mic;
        break;
      case 'pending':
        badgeColor = Colors.orange;
        icon = Icons.access_time;
        break;
      default:
        badgeColor = Colors.grey;
        icon = Icons.person;
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 8, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            role.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 6,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// High-performance floating speakers panel
class PerformanceOptimizedSpeakersPanel extends StatefulWidget {
  final List<Map<String, dynamic>> speakers;
  final Map<String, dynamic>? moderator;
  final List<Map<String, dynamic>>? audience; // New parameter for audience
  final List<Map<String, dynamic>>? speakerRequests; // New parameter for speaker requests
  final Function(String userId)? onSpeakerTap;
  final Function(String userId)? onAudienceTap; // New parameter for audience tap
  final Function(String userId)? onSpeakerRequestApprove; // New parameter for approving speaker requests
  final String? debateStyle; // New parameter for debate style
  final bool isCurrentUserModerator; // New parameter to know if current user is moderator
  
  const PerformanceOptimizedSpeakersPanel({
    super.key,
    required this.speakers,
    this.moderator,
    this.audience,
    this.speakerRequests,
    this.onSpeakerTap,
    this.onAudienceTap,
    this.onSpeakerRequestApprove,
    this.debateStyle,
    this.isCurrentUserModerator = false,
  });

  @override
  State<PerformanceOptimizedSpeakersPanel> createState() => _PerformanceOptimizedSpeakersPanelState();
}

class _PerformanceOptimizedSpeakersPanelState extends State<PerformanceOptimizedSpeakersPanel> {
  List<Widget> _cachedSpeakerWidgets = [];
  
  @override
  void initState() {
    super.initState();
    _buildCachedSpeakers();
  }
  
  @override
  void didUpdateWidget(PerformanceOptimizedSpeakersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _buildCachedSpeakers();
  }
  
  void _buildCachedSpeakers() {
    // Check layout type: Debate (2 slots), Take (3 slots), or regular (8 slots)
    final isDebateLayout = widget.debateStyle == 'Debate';
    final isTakeLayout = widget.debateStyle == 'Take';
    final totalSlots = isDebateLayout ? 2 : (isTakeLayout ? 3 : 8);
    
    final speakersWithPlaceholders = <Map<String, dynamic>>[];
    
    if (isDebateLayout) {
      // For debate layout, arrange speakers in specific positions
      Map<String, dynamic>? affirmativeSpeaker;
      Map<String, dynamic>? negativeSpeaker;
      
      // Find affirmative and negative speakers
      for (final speaker in widget.speakers) {
        final role = speaker['role'] ?? 'speaker';
        if (role == 'affirmative') {
          affirmativeSpeaker = speaker;
        } else if (role == 'negative') {
          negativeSpeaker = speaker;
        }
      }
      
      // First slot: Affirmative
      if (affirmativeSpeaker != null) {
        speakersWithPlaceholders.add(affirmativeSpeaker);
      } else {
        speakersWithPlaceholders.add({
          'isEmpty': true, 
          'slotNumber': 1,
          'debatePosition': 'Affirmative'
        });
      }
      
      // Second slot: Negative
      if (negativeSpeaker != null) {
        speakersWithPlaceholders.add(negativeSpeaker);
      } else {
        speakersWithPlaceholders.add({
          'isEmpty': true, 
          'slotNumber': 2,
          'debatePosition': 'Negative'
        });
      }
    } else if (isTakeLayout) {
      // For Take layout, arrange 3 speakers
      Map<String, dynamic>? speaker1;
      Map<String, dynamic>? speaker2;
      Map<String, dynamic>? speaker3;
      
      // Assign speakers to the 3 slots
      int speakerIndex = 0;
      for (final speaker in widget.speakers) {
        if (speakerIndex == 0) {
          speaker1 = speaker;
        } else if (speakerIndex == 1) {
          speaker2 = speaker;
        } else if (speakerIndex == 2) {
          speaker3 = speaker;
        }
        speakerIndex++;
        if (speakerIndex >= 3) break;
      }
      
      // First slot
      if (speaker1 != null) {
        speakersWithPlaceholders.add(speaker1);
      } else {
        speakersWithPlaceholders.add({
          'isEmpty': true, 
          'slotNumber': 1,
          'takePosition': 'Speaker 1'
        });
      }
      
      // Second slot
      if (speaker2 != null) {
        speakersWithPlaceholders.add(speaker2);
      } else {
        speakersWithPlaceholders.add({
          'isEmpty': true, 
          'slotNumber': 2,
          'takePosition': 'Speaker 2'
        });
      }
      
      // Third slot
      if (speaker3 != null) {
        speakersWithPlaceholders.add(speaker3);
      } else {
        speakersWithPlaceholders.add({
          'isEmpty': true, 
          'slotNumber': 3,
          'takePosition': 'Speaker 3'
        });
      }
    } else {
      // Regular layout - add all speakers and fill with placeholders
      speakersWithPlaceholders.addAll(widget.speakers);
      
      // Fill remaining slots with empty placeholders
      while (speakersWithPlaceholders.length < totalSlots) {
        final slotNumber = speakersWithPlaceholders.length + 1;
        speakersWithPlaceholders.add({'isEmpty': true, 'slotNumber': slotNumber});
      }
    }
    
    _cachedSpeakerWidgets = speakersWithPlaceholders.map((speaker) => 
      _VideoTile(
        key: ValueKey(speaker['userId'] ?? speaker['isEmpty'] ?? DateTime.now().millisecondsSinceEpoch),
        speaker: speaker,
        onTap: widget.onSpeakerTap,
        isModerator: false,
        isDebateLayout: isDebateLayout,
      )
    ).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    final isDebateLayout = widget.debateStyle == 'Debate';
    final isTakeLayout = widget.debateStyle == 'Take';
    
    // Calculate dimensions based on screen width and layout type
    final screenWidth = MediaQuery.of(context).size.width;
    const containerMargin = 8.0;
    final containerWidth = screenWidth - (containerMargin * 2);
    const tileSpacing = 4.0;
    
    late final double tileWidth;
    late final double tileHeight;
    
    if (isDebateLayout) {
      // For debate layout: 2 large slots side by side
      final availableWidth = containerWidth - tileSpacing; // Space for 1 gap between 2 tiles
      tileWidth = (availableWidth / 2).floor().toDouble();
      tileHeight = tileWidth * 1.2; // Larger tiles for debate
    } else if (isTakeLayout) {
      // For Take layout: 3 medium slots side by side
      final availableWidth = containerWidth - (tileSpacing * 2); // Space for 2 gaps between 3 tiles
      tileWidth = (availableWidth / 3).floor().toDouble();
      tileHeight = tileWidth * 1.15; // Medium-sized tiles for Take
    } else {
      // Regular layout: 4 tiles per row
      final availableWidth = containerWidth - (tileSpacing * 3); // Space for 3 gaps between 4 tiles
      tileWidth = (availableWidth / 4).floor().toDouble();
      tileHeight = tileWidth * 1.15;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: containerMargin),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDebateLayout)
            // Debate layout: 2 large slots for Affirmative and Negative with tabs
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tabs row
                SizedBox(
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < 2; i++) ...[
                        if (i > 0) const SizedBox(width: tileSpacing),
                        Container(
                          width: tileWidth,
                          height: 30,
                          decoration: BoxDecoration(
                            color: i == 0 
                                ? const Color(0xFF4CAF50).withValues(alpha: 0.15)  // Green for Affirmative
                                : const Color(0xFFF44336).withValues(alpha: 0.15), // Red for Negative  
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                            border: Border(
                              top: BorderSide(
                                color: i == 0 ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                                width: 2,
                              ),
                              left: BorderSide(
                                color: i == 0 ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                                width: 2,
                              ),
                              right: BorderSide(
                                color: i == 0 ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                                width: 2,
                              ),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              i == 0 ? 'AFFIRMATIVE' : 'NEGATIVE',
                              style: TextStyle(
                                color: i == 0 ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Speaker slots row
                SizedBox(
                  height: tileHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < 2; i++) ...[
                        if (i > 0) const SizedBox(width: tileSpacing),
                        SizedBox(
                          width: tileWidth,
                          height: tileHeight,
                          child: _cachedSpeakerWidgets[i],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            )
          else if (isTakeLayout)
            // Take layout: 3 medium slots for speakers
            SizedBox(
              height: tileHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: tileSpacing),
                    SizedBox(
                      width: tileWidth,
                      height: tileHeight,
                      child: _cachedSpeakerWidgets[i],
                    ),
                  ],
                ],
              ),
            )
          else
            // Regular layout: 4x2 grid of 8 speaker slots
            ...[
              // First row (slots 1-4)
              SizedBox(
                height: tileHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: tileSpacing),
                      SizedBox(
                        width: tileWidth,
                        height: tileHeight,
                        child: _cachedSpeakerWidgets[i],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Second row (slots 5-8)
              const SizedBox(height: tileSpacing),
              SizedBox(
                height: tileHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 4; i < 8; i++) ...[
                      if (i > 4) const SizedBox(width: tileSpacing),
                      SizedBox(
                        width: tileWidth,
                        height: tileHeight,
                        child: _cachedSpeakerWidgets[i],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          
          // Space between speakers and moderator
          const SizedBox(height: tileSpacing),
          
          // Moderator at the bottom (always shown)
          if (widget.moderator != null)
            SizedBox(
              width: isDebateLayout || isTakeLayout ? tileWidth * 0.8 : tileWidth, // Slightly smaller for debate/take layout
              height: isDebateLayout || isTakeLayout ? tileHeight * 0.8 : tileHeight,
              child: _VideoTile(
                speaker: {
                  ...widget.moderator!,
                  'role': 'moderator',
                },
                onTap: widget.onSpeakerTap,
                isModerator: true,
                isDebateLayout: isDebateLayout || isTakeLayout,
              ),
            ),
          
          // Speaker requests section (only for moderator)
          if (widget.isCurrentUserModerator && widget.speakerRequests != null && widget.speakerRequests!.isNotEmpty) ...[
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Speaker Requests:',
                    style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ...(widget.speakerRequests!.map((request) => 
                    Row(
                      children: [
                        Text(
                          request['name'] ?? 'Unknown',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => widget.onSpeakerRequestApprove?.call(request['userId'] ?? ''),
                          child: const Text('Approve', style: TextStyle(color: Colors.green, fontSize: 10)),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
          
          // Audience section below moderator
          if (widget.audience != null && widget.audience!.isNotEmpty) ...[
            const SizedBox(height: 16),
            
            // Audience header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.group,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Audience (${widget.audience!.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Audience grid
            SizedBox(
              height: 120, // Fixed height for audience section
              child: PerformanceOptimizedAudienceGrid(
                participants: widget.audience!,
                onParticipantTap: widget.onAudienceTap,
                debugLabel: 'SpeakerPanelAudience',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Beautiful video tile matching the original design
class _VideoTile extends StatelessWidget {
  final Map<String, dynamic> speaker;
  final Function(String userId)? onTap;
  final bool isModerator;
  final bool isDebateLayout;
  
  const _VideoTile({
    super.key,
    required this.speaker,
    this.onTap,
    this.isModerator = false,
    this.isDebateLayout = false,
  });
  
  @override
  Widget build(BuildContext context) {
    if (speaker['isEmpty'] == true) {
      // Different display for debate layout vs Take layout vs regular layout
      final displayText = isDebateLayout && speaker['debatePosition'] != null 
          ? speaker['debatePosition']
          : speaker['takePosition'] ?? '${speaker['slotNumber'] ?? ''}';
      
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF8B5CF6),
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.gavel,
                color: Color(0xFF8B5CF6),
                size: 32,
              ),
              const SizedBox(height: 4),
              Text(
                displayText,
                style: TextStyle(
                  color: Colors.grey.withValues(alpha: 0.6),
                  fontSize: isDebateLayout ? 14 : 12, // Slightly larger text for debate positions
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    final userId = speaker['userId'] ?? '';
    final name = speaker['name'] ?? speaker['userName'] ?? 'Unknown';
    final avatarUrl = speaker['avatarUrl'] ?? speaker['avatar'] ?? '';
    
    // Beautiful gradient and styling for different roles
    final isModeratorRole = isModerator || speaker['role'] == 'moderator';
    
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap != null ? () => onTap!(userId) : null,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isModeratorRole
                  ? [
                      const Color(0xFF7C2D12), // Dark red-orange
                      const Color(0xFF991B1B), // Deep red
                    ]
                  : [
                      const Color(0xFF5B21B6), // Dark purple
                      const Color(0xFF8B5CF6), // Bright purple
                    ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isModeratorRole
                  ? const Color(0xFFDC2626)  // Red border for moderator
                  : const Color(0xFF8B5CF6), // Purple border for speaker
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isModeratorRole 
                    ? const Color(0xFFDC2626) 
                    : const Color(0xFF8B5CF6)).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Avatar - larger round profile pics with gavel fallback
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: avatarUrl.isNotEmpty
                            ? Image.network(
                                avatarUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  width: 60,
                                  height: 60,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF8B5CF6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: _buildAvatarTextFromMap(speaker, 20),
                                ),
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF8B5CF6),
                                  shape: BoxShape.circle,
                                ),
                                child: _buildAvatarTextFromMap(speaker, 20),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Name - stacked for first/last
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildStackedNameDisplayForVideoTile(name),
                    ),
                  ],
                ),
              ),
              
              // Role indicator
              if (isModeratorRole)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Text(
                      'MOD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}