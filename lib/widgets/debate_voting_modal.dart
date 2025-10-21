import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/debate_voting_service.dart';
import '../core/logging/app_logger.dart';

/// Modal for audience to vote on debate
class DebateVotingModal extends StatefulWidget {
  final String roomId;
  final String userId;
  final DebateVotingService votingService;
  final VoteSide? currentVote;
  final VoidCallback? onVoteSubmitted;

  const DebateVotingModal({
    super.key,
    required this.roomId,
    required this.userId,
    required this.votingService,
    this.currentVote,
    this.onVoteSubmitted,
  });

  @override
  State<DebateVotingModal> createState() => _DebateVotingModalState();
}

class _DebateVotingModalState extends State<DebateVotingModal> {
  VoteSide? _selectedVote;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedVote = widget.currentVote;
  }

  Future<void> _submitVote() async {
    if (_selectedVote == null) return;

    setState(() => _isSubmitting = true);

    final success = await widget.votingService.submitVote(
      roomId: widget.roomId,
      userId: widget.userId,
      vote: _selectedVote!,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (success) {
        AppLogger().info('✅ Vote submitted successfully');
        widget.onVoteSubmitted?.call();
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vote submitted: ${_selectedVote!.value.toUpperCase()}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit vote. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title with icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.scale,
                color: Colors.amber,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Cast Your Vote',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Which side won the debate?',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 32),

          // Vote buttons
          Row(
            children: [
              Expanded(
                child: _buildVoteButton(
                  side: VoteSide.affirmative,
                  label: 'AFFIRMATIVE',
                  color: Colors.green,
                  icon: LucideIcons.checkCircle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildVoteButton(
                  side: VoteSide.negative,
                  label: 'NEGATIVE',
                  color: Colors.red,
                  icon: LucideIcons.xCircle,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedVote != null && !_isSubmitting
                  ? _submitVote
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                disabledBackgroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : Text(
                      _selectedVote == null
                          ? 'Select a side to vote'
                          : 'SUBMIT VOTE',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'You can change your vote until voting closes',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteButton({
    required VoteSide side,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _selectedVote == side;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedVote = side);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.grey[850],
          border: Border.all(
            color: isSelected ? color : Colors.grey[700]!,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey[600],
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[400],
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'SELECTED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modal to show voting results
class DebateVotingResultsModal extends StatelessWidget {
  final VoteResults results;

  const DebateVotingResultsModal({
    super.key,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    final hasWinner = results.winner != null;
    final isTied = results.winner == null && results.totalVotes > 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasWinner ? LucideIcons.trophy : LucideIcons.scale,
                color: hasWinner ? Colors.amber : Colors.grey,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                hasWinner ? 'Debate Results' : (isTied ? 'It\'s a Tie!' : 'No Votes Yet'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Vote bars
          _buildVoteBar(
            label: 'AFFIRMATIVE',
            votes: results.affirmativeVotes,
            percentage: results.affirmativePercentage,
            color: Colors.green,
            isWinner: results.winner == VoteSide.affirmative,
          ),

          const SizedBox(height: 16),

          _buildVoteBar(
            label: 'NEGATIVE',
            votes: results.negativeVotes,
            percentage: results.negativePercentage,
            color: Colors.red,
            isWinner: results.winner == VoteSide.negative,
          ),

          const SizedBox(height: 24),

          // Total votes
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.users,
                  color: Colors.grey[400],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Total Votes: ${results.totalVotes}',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'CLOSE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteBar({
    required String label,
    required int votes,
    required double percentage,
    required Color color,
    required bool isWinner,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isWinner ? color : Colors.grey[400],
                    fontSize: 16,
                    fontWeight: isWinner ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                if (isWinner) ...[
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.trophy,
                    color: Colors.amber,
                    size: 20,
                  ),
                ],
              ],
            ),
            Text(
              '${votes} votes (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 12,
          ),
        ),
      ],
    );
  }
}
