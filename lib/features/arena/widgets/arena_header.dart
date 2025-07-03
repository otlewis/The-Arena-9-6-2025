import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/arena_state.dart';
import '../providers/arena_provider.dart';

class ArenaHeader extends ConsumerWidget {
  const ArenaHeader({
    super.key,
    required this.roomId,
  });

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arenaState = ref.watch(arenaProvider(roomId));
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withValues(alpha: 0.8),
            theme.primaryColor.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    'Arena Debate',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                _buildStatusChip(arenaState.status, theme),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              arenaState.topic,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (arenaState.description?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                arenaState.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            _buildPhaseIndicator(arenaState, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ArenaStatus status, ThemeData theme) {
    Color chipColor;
    String text;
    
    switch (status) {
      case ArenaStatus.waiting:
        chipColor = Colors.orange;
        text = 'Waiting';
        break;
      case ArenaStatus.starting:
        chipColor = Colors.blue;
        text = 'Starting';
        break;
      case ArenaStatus.speaking:
        chipColor = Colors.green;
        text = 'Live';
        break;
      case ArenaStatus.voting:
        chipColor = Colors.purple;
        text = 'Voting';
        break;
      case ArenaStatus.completed:
        chipColor = Colors.grey;
        text = 'Completed';
        break;
      default:
        chipColor = Colors.grey;
        text = status.name;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPhaseIndicator(ArenaState state, ThemeData theme) {
    final phases = [
      DebatePhase.preDebate,
      DebatePhase.openingAffirmative,
      DebatePhase.rebuttalAffirmative,
      DebatePhase.closingAffirmative,
      DebatePhase.judging,
    ];

    return Row(
      children: phases.map((phase) {
        final isActive = phase == state.currentPhase;
        final isCompleted = phases.indexOf(phase) < phases.indexOf(state.currentPhase);
        
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 4,
            decoration: BoxDecoration(
              color: isActive 
                ? Colors.white
                : isCompleted 
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }).toList(),
    );
  }
}