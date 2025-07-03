import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/arena_state.dart';
import '../providers/arena_provider.dart';

class ArenaTimer extends ConsumerWidget {
  const ArenaTimer({
    super.key,
    required this.roomId,
  });

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arenaState = ref.watch(arenaProvider(roomId));
    final timerAsyncValue = ref.watch(arenaTimerProvider(roomId));
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            _getPhaseTitle(arenaState.currentPhase),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          timerAsyncValue.when(
            data: (time) => _buildTimerDisplay(context, time, arenaState.isTimerRunning),
            loading: () => _buildTimerDisplay(context, arenaState.remainingSeconds, false),
            error: (_, __) => _buildTimerDisplay(context, 0, false),
          ),
          if (arenaState.currentSpeaker != null) ...[
            const SizedBox(height: 8),
            _buildCurrentSpeaker(context, arenaState),
          ],
        ],
      ),
    );
  }

  Widget _buildTimerDisplay(BuildContext context, int timeInSeconds, bool isRunning) {
    final minutes = timeInSeconds ~/ 60;
    final seconds = timeInSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    Color timerColor;
    if (timeInSeconds <= 30) {
      timerColor = Colors.red;
    } else if (timeInSeconds <= 60) {
      timerColor = Colors.orange;
    } else {
      timerColor = Theme.of(context).primaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: timerColor.withValues(alpha: 0.1),
        border: Border.all(color: timerColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRunning)
            Container(
              margin: const EdgeInsets.only(right: 8),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: timerColor,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            timeString,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: timerColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSpeaker(BuildContext context, ArenaState state) {
    final currentSpeaker = state.participants[state.currentSpeaker];
    if (currentSpeaker == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic,
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            '${currentSpeaker.name} is speaking',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getPhaseTitle(DebatePhase phase) {
    switch (phase) {
      case DebatePhase.preDebate:
        return 'Preparation Phase';
      case DebatePhase.openingAffirmative:
        return 'Opening - Affirmative';
      case DebatePhase.openingNegative:
        return 'Opening - Negative';
      case DebatePhase.rebuttalAffirmative:
        return 'Rebuttal - Affirmative';
      case DebatePhase.rebuttalNegative:
        return 'Rebuttal - Negative';
      case DebatePhase.crossExamAffirmative:
        return 'Cross-Exam - Affirmative';
      case DebatePhase.crossExamNegative:
        return 'Cross-Exam - Negative';
      case DebatePhase.finalRebuttalAffirmative:
        return 'Final Rebuttal - Affirmative';
      case DebatePhase.finalRebuttalNegative:
        return 'Final Rebuttal - Negative';
      case DebatePhase.closingAffirmative:
        return 'Closing - Affirmative';
      case DebatePhase.closingNegative:
        return 'Closing - Negative';
      case DebatePhase.judging:
        return 'Judging Phase';
    }
  }
}