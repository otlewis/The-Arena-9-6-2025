import 'package:flutter/material.dart';
import '../../services/participant_service.dart';
import '../user_avatar.dart';
import '../../core/logging/app_logger.dart';

/// Focused widget for displaying audience participants in a grid
/// Handles responsive layout and hand-raise indicators
class AudienceGridWidget extends StatelessWidget {
  final List<ParticipantData> audience;
  final Function(String)? onPromoteToSpeaker;
  final Function(String)? onDenyHandRaise;
  final Function(String)? onShowParticipantOptions;
  final String? currentUserId;
  final String userRole;

  const AudienceGridWidget({
    Key? key,
    required this.audience,
    this.onPromoteToSpeaker,
    this.onDenyHandRaise,
    this.onShowParticipantOptions,
    this.currentUserId,
    required this.userRole,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (audience.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildAudienceGrid(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final handRaisedCount = audience.where((p) => p.isHandRaised).length;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Audience (${audience.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        
        if (handRaisedCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pan_tool, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$handRaisedCount raised',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAudienceGrid(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    // Responsive columns based on screen size
    int crossAxisCount;
    double childAspectRatio;
    
    if (isSmallScreen) {
      crossAxisCount = 3;
      childAspectRatio = 0.9;
    } else if (screenWidth < 600) {
      crossAxisCount = 4;
      childAspectRatio = 0.85;
    } else {
      crossAxisCount = 5;
      childAspectRatio = 0.8;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: audience.length,
      itemBuilder: (context, index) {
        return _buildAudienceParticipant(audience[index]);
      },
    );
  }

  Widget _buildAudienceParticipant(ParticipantData participant) {
    final isHandRaised = participant.isHandRaised;
    final isPending = participant.role == 'pending';
    final isLocal = participant.isLocal;
    
    return GestureDetector(
      onTap: () => _handleParticipantTap(participant),
      child: Container(
        decoration: BoxDecoration(
          color: _getParticipantBackgroundColor(participant),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getParticipantBorderColor(participant),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar with indicators
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                  ),
                  child: UserAvatar(
                    avatarUrl: participant.avatarUrl,
                    initials: participant.displayName.substring(0, 1).toUpperCase(),
                    radius: 20,
                  ),
                ),
                
                // Hand raise indicator
                if (isHandRaised)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.pan_tool,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
                  
                // Pending indicator
                if (isPending)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hourglass_empty,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 6),
            
            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                isLocal ? 'Me' : participant.displayName,
                style: TextStyle(
                  fontSize: 11,
                  color: _getTextColor(participant),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            
            // Status indicator
            if (isHandRaised || isPending)
              Text(
                isPending ? 'Pending' : 'Hand up',
                style: TextStyle(
                  fontSize: 9,
                  color: isPending ? Colors.blue[300] : Colors.orange[300],
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No audience members yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Participants will appear here as they join',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getParticipantBackgroundColor(ParticipantData participant) {
    if (participant.role == 'pending') {
      return Colors.blue[900]!;
    } else if (participant.isHandRaised) {
      return Colors.orange[900]!;
    } else {
      return const Color(0xFF1E293B);
    }
  }

  Color _getParticipantBorderColor(ParticipantData participant) {
    if (participant.role == 'pending') {
      return Colors.blue;
    } else if (participant.isHandRaised) {
      return Colors.orange;
    } else {
      return Colors.grey[700]!;
    }
  }

  Color _getTextColor(ParticipantData participant) {
    if (participant.role == 'pending') {
      return Colors.blue[200]!;
    } else if (participant.isHandRaised) {
      return Colors.orange[200]!;
    } else {
      return Colors.white;
    }
  }

  void _handleParticipantTap(ParticipantData participant) {
    try {
      // Handle different tap actions based on user role and participant status
      if (userRole == 'moderator') {
        if (participant.isHandRaised || participant.role == 'pending') {
          // Show promote/deny options for hand-raised participants
          _showHandRaiseActions(participant);
        } else {
          // Show general participant options
          onShowParticipantOptions?.call(participant.id);
        }
      } else {
        // Non-moderators can only view participant info
        onShowParticipantOptions?.call(participant.id);
      }
      
      AppLogger().debug('👤 Audience participant tapped: ${participant.displayName} (${participant.role})');
    } catch (e) {
      AppLogger().error('❌ Error handling audience participant tap: $e');
    }
  }

  void _showHandRaiseActions(ParticipantData participant) {
    // This would typically show a modal or context menu
    // For now, we'll just call the appropriate action
    if (participant.isHandRaised || participant.role == 'pending') {
      onPromoteToSpeaker?.call(participant.id);
    }
  }
}