import 'package:flutter/material.dart';
import '../utils/mobile_performance_optimizer.dart';
import '../utils/performance_optimizations.dart';
import '../core/logging/app_logger.dart';

/// Mobile-optimized audience grid with performance enhancements
class MobileOptimizedAudienceGrid extends StatefulWidget {
  final List<Map<String, dynamic>> participants;
  final Function(String userId)? onParticipantTap;
  final String debugLabel;
  
  const MobileOptimizedAudienceGrid({
    super.key,
    required this.participants,
    this.onParticipantTap,
    this.debugLabel = 'AudienceGrid',
  });

  @override
  State<MobileOptimizedAudienceGrid> createState() => _MobileOptimizedAudienceGridState();
}

class _MobileOptimizedAudienceGridState extends State<MobileOptimizedAudienceGrid> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _lastParticipants = [];
  
  @override
  void initState() {
    super.initState();
    _lastParticipants = List.from(widget.participants);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Use performance optimization to prevent unnecessary rebuilds
    if (!PerformanceOptimizations.participantsChanged(_lastParticipants, widget.participants)) {
      AppLogger().debug('${widget.debugLabel}: Participants unchanged, skipping rebuild');
      return _buildGrid(context);
    }
    
    _lastParticipants = List.from(widget.participants);
    
    return MobilePerformanceOptimizer.instance.wrapWithMobileOptimization(
      _buildGrid(context),
      debugLabel: widget.debugLabel,
    );
  }
  
  Widget _buildGrid(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final mobileOptimizer = MobilePerformanceOptimizer.instance;
    
    if (widget.participants.isEmpty) {
      return Center(
        child: Text(
          'No participants yet',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
      );
    }
    
    return GridView.builder(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(), // Better for mobile
      padding: const EdgeInsets.all(8),
      gridDelegate: mobileOptimizer.getMobileOptimizedGridDelegate(screenWidth),
      itemCount: widget.participants.length,
      cacheExtent: 200, // Optimize for mobile memory usage
      itemBuilder: (context, index) {
        return _buildParticipantCard(widget.participants[index], mobileOptimizer);
      },
    );
  }
  
  Widget _buildParticipantCard(Map<String, dynamic> participant, MobilePerformanceOptimizer optimizer) {
    final userId = participant['userId'] ?? '';
    final name = participant['name'] ?? participant['userName'] ?? 'Unknown';
    final avatarUrl = participant['avatarUrl'] ?? participant['avatar'] ?? '';
    final role = participant['role'] ?? 'audience';
    
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onParticipantTap != null 
          ? () => widget.onParticipantTap!(userId)
          : null,
        child: AnimatedContainer(
          duration: optimizer.getMobileOptimizedAnimationDuration(),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: _getRoleColor(role),
            borderRadius: BorderRadius.circular(12),
            border: role == 'speaker' 
              ? Border.all(color: Colors.blue, width: 2)
              : null,
            boxShadow: optimizer.shouldUseReducedAnimations() 
              ? null 
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAvatar(avatarUrl, optimizer),
              const SizedBox(height: 4),
              _buildNameText(name),
              if (role != 'audience') _buildRoleBadge(role),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAvatar(String avatarUrl, MobilePerformanceOptimizer optimizer) {
    const double size = 40;
    
    if (avatarUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[400],
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.person,
          color: Colors.white,
          size: 24,
        ),
      );
    }
    
    return ClipOval(
      child: optimizer.getMobileOptimizedImage(
        imageUrl: avatarUrl,
        width: size,
        height: size,
      ),
    );
  }
  
  Widget _buildNameText(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        name.length > 12 ? '${name.substring(0, 12)}...' : name,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
  
  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    IconData icon;
    
    switch (role) {
      case 'moderator':
        badgeColor = Colors.red;
        icon = Icons.gavel;
        break;
      case 'speaker':
        badgeColor = Colors.blue;
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
  
  Color _getRoleColor(String role) {
    switch (role) {
      case 'moderator':
        return Colors.red.withValues(alpha: 0.1);
      case 'speaker':
        return Colors.blue.withValues(alpha: 0.1);
      case 'pending':
        return Colors.orange.withValues(alpha: 0.1);
      default:
        return Colors.white;
    }
  }
}

/// Mobile-optimized floating speakers panel
class MobileOptimizedSpeakersPanel extends StatelessWidget {
  final List<Map<String, dynamic>> speakers;
  final Map<String, dynamic>? moderator;
  final Function(String userId)? onSpeakerTap;
  
  const MobileOptimizedSpeakersPanel({
    super.key,
    required this.speakers,
    this.moderator,
    this.onSpeakerTap,
  });

  @override
  Widget build(BuildContext context) {
    final optimizer = MobilePerformanceOptimizer.instance;
    final allSpeakers = <Map<String, dynamic>>[];
    
    if (moderator != null) {
      allSpeakers.add({
        ...moderator!,
        'role': 'moderator',
      });
    }
    
    allSpeakers.addAll(speakers);
    
    // Fill remaining slots with empty placeholders
    while (allSpeakers.length < 7) {
      allSpeakers.add({'isEmpty': true});
    }
    
    return optimizer.wrapWithMobileOptimization(
      Container(
        height: 80,
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: allSpeakers.map((speaker) => Expanded(
            child: _buildSpeakerSlot(speaker, optimizer),
          )).toList(),
        ),
      ),
      debugLabel: 'SpeakersPanel',
    );
  }
  
  Widget _buildSpeakerSlot(Map<String, dynamic> speaker, MobilePerformanceOptimizer optimizer) {
    if (speaker['isEmpty'] == true) {
      return Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(
            Icons.person_outline,
            color: Colors.white54,
            size: 24,
          ),
        ),
      );
    }
    
    final userId = speaker['userId'] ?? '';
    final name = speaker['name'] ?? speaker['userName'] ?? 'Unknown';
    final avatarUrl = speaker['avatarUrl'] ?? speaker['avatar'] ?? '';
    final role = speaker['role'] ?? 'speaker';
    
    return GestureDetector(
      onTap: onSpeakerTap != null ? () => onSpeakerTap!(userId) : null,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: role == 'moderator' 
            ? Colors.red.withValues(alpha: 0.2)
            : Colors.blue.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: role == 'moderator' ? Colors.red : Colors.blue,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: optimizer.getMobileOptimizedImage(
                imageUrl: avatarUrl,
                width: 32,
                height: 32,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name.length > 8 ? '${name.substring(0, 8)}...' : name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}