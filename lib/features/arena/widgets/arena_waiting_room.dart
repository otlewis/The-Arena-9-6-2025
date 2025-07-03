import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/arena_state.dart';
import '../providers/arena_provider.dart';
import '../../../widgets/user_avatar.dart';
import '../../../core/providers/app_providers.dart';

/// Waiting room widget for arena debates
/// Shows participants and their ready status before debate starts
class ArenaWaitingRoom extends ConsumerWidget {
  const ArenaWaitingRoom({super.key, required this.roomId});

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
    
    return _buildWaitingRoom(context, ref, arenaState);
  }

  Widget _buildWaitingRoom(BuildContext context, WidgetRef ref, ArenaState state) {
    final readyCount = state.participants.values.where((p) => p.isReady).length;
    final totalCount = state.participants.values.length;
    final allReady = readyCount == totalCount && totalCount >= 2;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Waiting room header
            Row(
              children: [
                const Icon(
                  Icons.hourglass_empty,
                  color: Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Waiting Room',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: allReady ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$readyCount/$totalCount Ready',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: allReady ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Debate topic
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6B46C1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6B46C1).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Debate Topic',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B46C1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.topic ?? 'Loading topic...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Participants grid
            _buildParticipantsGrid(state),
            
            const SizedBox(height: 24),
            
            // Ready button and status
            _buildReadySection(context, ref, state),
            
            if (allReady) ...[
              const SizedBox(height: 16),
              _buildStartDebateButton(context, ref, state),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsGrid(ArenaState state) {
    final debaters = [
      state.participants.values.where((p) => p.role == ArenaRole.affirmative).firstOrNull,
      state.participants.values.where((p) => p.role == ArenaRole.negative).firstOrNull,
    ];
    
    final officials = [
      ...state.participants.values.where((p) => p.role == ArenaRole.moderator),
      ...state.participants.values.where((p) => 
        p.role == ArenaRole.judge1 || 
        p.role == ArenaRole.judge2 || 
        p.role == ArenaRole.judge3
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Debaters section
        const Text(
          'Debaters',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildParticipantSlot(
                participant: debaters[0],
                role: 'Affirmative',
                color: Colors.blue,
                icon: Icons.thumb_up,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildParticipantSlot(
                participant: debaters[1],
                role: 'Negative',
                color: Colors.red,
                icon: Icons.thumb_down,
              ),
            ),
          ],
        ),
        
        if (officials.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Officials',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: officials.map((participant) {
              String roleTitle;
              if (participant.role == ArenaRole.moderator) {
                roleTitle = 'Moderator';
              } else if (participant.role == ArenaRole.judge1) {
                roleTitle = 'Judge 1';
              } else if (participant.role == ArenaRole.judge2) {
                roleTitle = 'Judge 2';
              } else {
                roleTitle = 'Judge 3';
              }
              
              return _buildParticipantSlot(
                participant: participant,
                role: roleTitle,
                color: participant.role == ArenaRole.moderator ? Colors.purple : Colors.orange,
                icon: participant.role == ArenaRole.moderator ? Icons.gavel : Icons.balance,
                isCompact: true,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildParticipantSlot({
    required ArenaParticipant? participant,
    required String role,
    required Color color,
    required IconData icon,
    bool isCompact = false,
  }) {
    final isEmpty = participant == null;
    
    return Container(
      width: isCompact ? 120 : null,
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: isEmpty ? Colors.grey.shade50 : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEmpty ? Colors.grey.shade300 : color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Avatar or placeholder
          if (isEmpty)
            Container(
              width: isCompact ? 40 : 50,
              height: isCompact ? 40 : 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_add,
                color: Colors.grey.shade500,
                size: isCompact ? 20 : 24,
              ),
            )
          else
            Stack(
              children: [
                UserAvatar(
                  initials: _getInitials(participant.name),
                  radius: isCompact ? 20 : 25,
                ),
                if (participant.isReady)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white,
                            blurRadius: 2,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          
          const SizedBox(height: 8),
          
          // Role and name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                role,
                style: TextStyle(
                  fontSize: isCompact ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          Text(
            isEmpty ? 'Waiting...' : participant.name,
            style: TextStyle(
              fontSize: isCompact ? 10 : 12,
              fontWeight: FontWeight.w400,
              color: isEmpty ? Colors.grey.shade600 : Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          if (!isEmpty && !isCompact) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: participant.isReady ? Colors.green.shade100 : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                participant.isReady ? 'Ready' : 'Not Ready',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: participant.isReady ? Colors.green.shade700 : Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadySection(BuildContext context, WidgetRef ref, ArenaState state) {
    final currentUserId = ref.read(currentUserIdProvider);
    final currentParticipant = state.participants[currentUserId];
    final isReady = currentParticipant?.isReady ?? false;

    if (currentParticipant == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.info, color: Colors.grey),
            SizedBox(width: 12),
            Text(
              'You are observing this debate as audience',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _toggleReady(ref),
        icon: Icon(isReady ? Icons.check_circle : Icons.schedule),
        label: Text(isReady ? 'Ready to Debate!' : 'Mark as Ready'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isReady ? Colors.green : const Color(0xFF6B46C1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildStartDebateButton(BuildContext context, WidgetRef ref, ArenaState state) {
    final currentUserId = ref.read(currentUserIdProvider);
    final isModerator = state.participants.values.any(
      (p) => p.userId == currentUserId && p.role == ArenaRole.moderator,
    );

    if (!isModerator) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, color: Colors.green),
            SizedBox(width: 12),
            Text(
              'Waiting for moderator to start the debate...',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _startDebate(ref),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Debate'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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
              'Failed to load waiting room',
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

  void _toggleReady(WidgetRef ref) {
    ref.read(arenaProvider(roomId).notifier).toggleReady();
  }

  void _startDebate(WidgetRef ref) {
    ref.read(arenaProvider(roomId).notifier).startDebate();
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