import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/arena_state.dart';
import '../providers/arena_provider.dart';

class SimpleArenaDebateControls extends ConsumerWidget {
  const SimpleArenaDebateControls({super.key, required this.roomId});

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
    
    return _buildControls(context, ref, arenaState);
  }

  Widget _buildControls(BuildContext context, WidgetRef ref, ArenaState state) {
    // Show waiting message if debate hasn't started
    if (state.status == ArenaStatus.waiting) {
      return Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.hourglass_empty,
                    color: Colors.orange,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Waiting for Debate to Start',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Topic: ${state.topic}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          _buildBottomNavigationBar(context, ref, state),
        ],
      );
    }

    // Show debate controls during active debate
    return Column(
      children: [
        // Main controls card
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhaseInfo(state),
                const SizedBox(height: 16),
                _buildSpeakingInfo(state),
              ],
            ),
          ),
        ),
        
        // Bottom navigation bar with controls
        _buildBottomNavigationBar(context, ref, state),
      ],
    );
  }

  Widget _buildPhaseInfo(ArenaState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Phase',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _getPhaseDisplayName(state.currentPhase),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Timer: ${_formatTime(state.remainingSeconds)}',
          style: TextStyle(
            fontSize: 16,
            color: state.isTimerRunning ? Colors.green : Colors.orange,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSpeakingInfo(ArenaState state) {
    if (state.currentSpeaker != null) {
      final speaker = state.participants[state.currentSpeaker];
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              'Speaking: ${speaker?.name ?? "Unknown"}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.mic_off, color: Colors.grey),
          SizedBox(width: 8),
          Text(
            'No active speaker',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, WidgetRef ref, ArenaState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Gift button (simplified - no actual functionality)
            _buildControlButton(
              icon: Icons.card_giftcard,
              label: 'Gift',
              color: Colors.amber,
              onTap: () => _showComingSoonDialog(context, 'Gifting'),
            ),
            
            // Info button
            _buildControlButton(
              icon: Icons.info_outline,
              label: 'Info',
              color: Colors.blue,
              onTap: () => _showDebateInfo(context, state),
            ),
            
            // Leave arena
            _buildControlButton(
              icon: Icons.exit_to_app,
              label: 'Leave',
              color: Colors.red.shade400,
              onTap: () => _confirmLeaveArena(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
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
              'Failed to load debate controls',
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

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$feature Coming Soon!'),
        content: Text('$feature functionality will be available in a future update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDebateInfo(BuildContext context, ArenaState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debate Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Topic: ${state.topic}'),
            const SizedBox(height: 8),
            Text('Phase: ${_getPhaseDisplayName(state.currentPhase)}'),
            const SizedBox(height: 8),
            Text('Participants: ${state.participants.length}'),
            const SizedBox(height: 8),
            Text('Status: ${state.status.name}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeaveArena(BuildContext context) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Arena'),
        content: const Text('Are you sure you want to leave this debate arena?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (shouldLeave == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  String _getPhaseDisplayName(DebatePhase phase) {
    switch (phase) {
      case DebatePhase.preDebate:
        return 'Pre-Debate Setup';
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

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}