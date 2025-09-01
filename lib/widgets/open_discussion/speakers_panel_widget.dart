import 'package:flutter/material.dart';
import '../../services/participant_service.dart';
import '../user_avatar.dart';
import '../../core/logging/app_logger.dart';

/// Focused widget for displaying speakers panel
/// Handles moderator + speaker slots with consistent layout
class SpeakersPanelWidget extends StatelessWidget {
  final List<ParticipantData> speakers;
  final ParticipantData? moderator;
  final Function(String)? onPromoteToSpeaker;
  final Function(String)? onDemoteToAudience;
  final Function(String)? onShowParticipantOptions;
  final String? currentUserId;
  final String userRole;

  const SpeakersPanelWidget({
    super.key,
    required this.speakers,
    this.moderator,
    this.onPromoteToSpeaker,
    this.onDemoteToAudience,
    this.onShowParticipantOptions,
    this.currentUserId,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Moderator Section
          _buildModeratorSection(),
          
          const SizedBox(height: 16),
          
          // Speakers Section  
          _buildSpeakersSection(),
        ],
      ),
    );
  }

  Widget _buildModeratorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Moderator',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        
        // Moderator slot - always centered
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                child: moderator != null 
                  ? _buildModeratorSlot(moderator!)
                  : _buildEmptyModeratorSlot(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpeakersSection() {
    // Get non-moderator speakers
    final nonModeratorSpeakers = speakers
        .where((s) => s.role == 'speaker')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Speakers (${nonModeratorSpeakers.length}/6)',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        
        // Speaker slots in 3x2 grid
        _buildSpeakerGrid(nonModeratorSpeakers),
      ],
    );
  }

  Widget _buildSpeakerGrid(List<ParticipantData> speakerList) {
    const int maxSpeakers = 6;
    
    return SizedBox(
      height: 280, // Fixed height for 2 rows
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: maxSpeakers,
        itemBuilder: (context, index) {
          if (index < speakerList.length) {
            return _buildSpeakerSlot(speakerList[index], index + 1);
          } else {
            return _buildEmptySpeakerSlot(index + 1);
          }
        },
      ),
    );
  }

  Widget _buildModeratorSlot(ParticipantData moderator) {
    final isSpeaking = moderator.isSpeaking;
    final isMuted = moderator.isMuted;
    final isLocal = moderator.isLocal;
    
    return GestureDetector(
      onTap: () => _handleParticipantTap(moderator),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: const Color(0xFF6B46C1), // Purple for moderator
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSpeaking ? Colors.green : const Color(0xFF6B46C1),
            width: 3,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar with speaking indicator
            Stack(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: isSpeaking ? Colors.green : Colors.white,
                      width: 3,
                    ),
                  ),
                  child: UserAvatar(
                    avatarUrl: moderator.avatarUrl,
                    initials: moderator.displayName.substring(0, 1).toUpperCase(),
                    radius: 35,
                  ),
                ),
                
                // Mute indicator
                if (isMuted)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_off,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Name with role indicator
            Text(
              isLocal ? 'Me' : moderator.displayName,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            
            const Text(
              'Moderator',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeakerSlot(ParticipantData speaker, int slotNumber) {
    final isSpeaking = speaker.isSpeaking;
    final isMuted = speaker.isMuted;
    final isLocal = speaker.isLocal;
    
    return GestureDetector(
      onTap: () => _handleParticipantTap(speaker),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSpeaking ? Colors.green : Colors.grey[700]!,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar with speaking indicator
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                    border: Border.all(
                      color: isSpeaking ? Colors.green : Colors.grey[500]!,
                      width: 2,
                    ),
                  ),
                  child: UserAvatar(
                    avatarUrl: speaker.avatarUrl,
                    initials: speaker.displayName.substring(0, 1).toUpperCase(),
                    radius: 25,
                  ),
                ),
                
                // Mute indicator
                if (isMuted)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_off,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 6),
            
            // Name
            Text(
              isLocal ? 'Me' : speaker.displayName,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            
            // Slot indicator
            Text(
              '#$slotNumber',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyModeratorSlot() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFF6B46C1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6B46C1),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar placeholder
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Icon(
              Icons.person,
              color: Color(0xFF6B46C1),
              size: 35,
            ),
          ),
          
          const SizedBox(height: 8),
          
          const Text(
            'No Moderator',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const Text(
            'Moderator',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySpeakerSlot(int slotNumber) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[600]!,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[700],
            ),
            child: Icon(
              Icons.person_add,
              color: Colors.grey[500],
              size: 24,
            ),
          ),
          
          const SizedBox(height: 6),
          
          Text(
            'Empty',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
          
          Text(
            '#$slotNumber',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _handleParticipantTap(ParticipantData participant) {
    try {
      // Only moderators can manage participants
      if (userRole != 'moderator') return;
      
      // Don't allow actions on self
      if (participant.id == currentUserId) return;
      
      onShowParticipantOptions?.call(participant.id);
      
      AppLogger().debug('👤 Participant tapped: ${participant.displayName} (${participant.role})');
    } catch (e) {
      AppLogger().error('❌ Error handling participant tap: $e');
    }
  }
}