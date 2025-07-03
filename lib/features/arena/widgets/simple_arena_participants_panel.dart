import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/arena_state.dart';
import '../providers/arena_provider.dart';
import '../../../widgets/user_avatar.dart';

class SimpleArenaParticipantsPanel extends ConsumerWidget {
  const SimpleArenaParticipantsPanel({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arenaState = ref.watch(arenaProvider(roomId));

    if (arenaState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (arenaState.error != null) {
      return _buildErrorState(context, arenaState.error!);
    }
    
    return _buildParticipantsPanel(context, ref, arenaState);
  }

  Widget _buildParticipantsPanel(BuildContext context, WidgetRef ref, ArenaState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Participants',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDebaters(state),
          const SizedBox(height: 16),
          _buildOfficials(state),
          if (state.participants.values.where((p) => p.role == ArenaRole.audience).isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildAudience(state),
          ],
        ],
      ),
    );
  }

  Widget _buildDebaters(ArenaState state) {
    final affirmative = state.participants.values.where((p) => p.role == ArenaRole.affirmative).firstOrNull;
    final negative = state.participants.values.where((p) => p.role == ArenaRole.negative).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Debaters',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildParticipantCard(
                participant: affirmative,
                role: 'Affirmative',
                color: Colors.blue,
                state: state,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildParticipantCard(
                participant: negative,
                role: 'Negative',
                color: Colors.red,
                state: state,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOfficials(ArenaState state) {
    final moderator = state.participants.values.where((p) => p.role == ArenaRole.moderator).firstOrNull;
    final judges = state.participants.values.where((p) => 
      p.role == ArenaRole.judge1 || 
      p.role == ArenaRole.judge2 || 
      p.role == ArenaRole.judge3
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Officials',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        if (moderator != null)
          _buildParticipantCard(
            participant: moderator,
            role: 'Moderator',
            color: Colors.purple,
            state: state,
          ),
        if (judges.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: judges.asMap().entries.map((entry) {
              String roleTitle;
              if (entry.value.role == ArenaRole.judge1) {
                roleTitle = 'Judge 1';
              } else if (entry.value.role == ArenaRole.judge2) {
                roleTitle = 'Judge 2';
              } else {
                roleTitle = 'Judge 3';
              }
              
              return _buildParticipantCard(
                participant: entry.value,
                role: roleTitle,
                color: Colors.orange,
                state: state,
                isCompact: true,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildAudience(ArenaState state) {
    final audience = state.participants.values.where((p) => p.role == ArenaRole.audience).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Audience (${audience.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        // Enhanced audience display with bigger icons and horizontal scroll view
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: audience.length,
            itemBuilder: (context, index) {
              final participant = audience[index];
              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    UserAvatar(
                      initials: _getInitials(participant.name),
                      radius: 24, // Increased from 16 to 24
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60,
                      child: Text(
                        participant.name,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantCard({
    required ArenaParticipant? participant,
    required String role,
    required Color color,
    required ArenaState state,
    bool isCompact = false,
  }) {
    if (participant == null) {
      return Container(
        padding: EdgeInsets.all(isCompact ? 8 : 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              Icons.person_add,
              color: Colors.grey.shade400,
              size: isCompact ? 24 : 32,
            ),
            const SizedBox(height: 4),
            Text(
              role,
              style: TextStyle(
                fontSize: isCompact ? 10 : 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              'Waiting...',
              style: TextStyle(
                fontSize: isCompact ? 8 : 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    final isSpeaking = state.currentSpeaker == participant.userId;
    final isReady = participant.isReady;

    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(
          color: isSpeaking ? Colors.green : color,
          width: isSpeaking ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              UserAvatar(
                initials: _getInitials(participant.name),
                radius: isCompact ? 12 : 16,
              ),
              if (isSpeaking)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            role,
            style: TextStyle(
              fontSize: isCompact ? 10 : 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          Text(
            participant.name,
            style: TextStyle(
              fontSize: isCompact ? 8 : 10,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (!isCompact) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isReady ? Icons.check_circle : Icons.schedule,
                  size: 12,
                  color: isReady ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 2),
                Text(
                  isReady ? 'Ready' : 'Not Ready',
                  style: TextStyle(
                    fontSize: 8,
                    color: isReady ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to load participants',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    
    return name[0].toUpperCase();
  }
}

extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}