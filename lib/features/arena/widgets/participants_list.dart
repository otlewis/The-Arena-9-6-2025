import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/arena_state.dart';
import '../providers/arena_provider.dart';

class ParticipantsList extends ConsumerWidget {
  const ParticipantsList({
    super.key,
    required this.roomId,
  });

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arenaState = ref.watch(arenaProvider(roomId));
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Participants',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDebaters(context, arenaState),
          const SizedBox(height: 16),
          _buildModerators(context, arenaState),
          const SizedBox(height: 16),
          _buildJudges(context, arenaState),
          const SizedBox(height: 16),
          _buildAudience(context, arenaState),
        ],
      ),
    );
  }

  Widget _buildDebaters(BuildContext context, ArenaState state) {
    final affirmative = state.getParticipantsByRole(ArenaRole.affirmative);
    final negative = state.getParticipantsByRole(ArenaRole.negative);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.gavel, size: 20, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              'Debaters',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTeamSection(
                context,
                'Affirmative',
                affirmative,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTeamSection(
                context,
                'Negative',
                negative,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamSection(
    BuildContext context,
    String teamName,
    List<ArenaParticipant> participants,
    Color teamColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: teamColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
        color: teamColor.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teamName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: teamColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          if (participants.isEmpty)
            Text(
              'Waiting for debater...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...participants.map((participant) => _buildParticipantTile(
              context,
              participant,
              teamColor,
            )),
        ],
      ),
    );
  }

  Widget _buildModerators(BuildContext context, ArenaState state) {
    final moderators = state.getParticipantsByRole(ArenaRole.moderator);
    
    return _buildRoleSection(
      context,
      'Moderators',
      moderators,
      Icons.person_pin_circle,
      Colors.purple,
    );
  }

  Widget _buildJudges(BuildContext context, ArenaState state) {
    // Get all judges (judge1, judge2, judge3)
    final judges = <ArenaParticipant>[];
    judges.addAll(state.getParticipantsByRole(ArenaRole.judge1));
    judges.addAll(state.getParticipantsByRole(ArenaRole.judge2));
    judges.addAll(state.getParticipantsByRole(ArenaRole.judge3));
    
    return _buildRoleSection(
      context,
      'Judges',
      judges,
      Icons.balance,
      Colors.orange,
    );
  }

  Widget _buildAudience(BuildContext context, ArenaState state) {
    final audience = state.getParticipantsByRole(ArenaRole.audience);
    
    return _buildRoleSection(
      context,
      'Audience',
      audience,
      Icons.people,
      Colors.grey[600]!,
      showAll: false,
    );
  }

  Widget _buildRoleSection(
    BuildContext context,
    String roleName,
    List<ArenaParticipant> participants,
    IconData icon,
    Color color, {
    bool showAll = true,
  }) {
    final displayParticipants = showAll ? participants : participants.take(3).toList();
    final hiddenCount = participants.length - displayParticipants.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              '$roleName (${participants.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (participants.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              'No $roleName yet',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else ...[
          ...displayParticipants.map((participant) => 
            _buildParticipantTile(context, participant, color)),
          if (hiddenCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                '+$hiddenCount more',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildParticipantTile(
    BuildContext context,
    ArenaParticipant participant,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color.withValues(alpha: 0.2),
            backgroundImage: participant.avatar != null 
              ? NetworkImage(participant.avatar!)
              : null,
            child: participant.avatar == null
              ? Text(
                  participant.name.isNotEmpty 
                    ? participant.name[0].toUpperCase()
                    : '?',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                )
              : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              participant.name,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (participant.isReady)
            const Icon(
              Icons.check_circle,
              size: 16,
              color: Colors.green,
            )
          else
            const Icon(
              Icons.schedule,
              size: 16,
              color: Colors.orange,
            ),
        ],
      ),
    );
  }
}