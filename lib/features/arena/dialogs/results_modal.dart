import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../../widgets/user_avatar.dart';
import '../constants/arena_colors.dart';

/// Results Modal - DO NOT MODIFY UI LAYOUT
/// This modal displays debate results with winner announcement and vote breakdown
class ResultsModal extends StatelessWidget {
  final String winner;
  final UserProfile? affirmativeDebater;
  final UserProfile? negativeDebater;
  final List<dynamic> judgments;
  final String topic;

  const ResultsModal({
    super.key,
    required this.winner,
    this.affirmativeDebater,
    this.negativeDebater,
    required this.judgments,
    required this.topic,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate vote counts
    int affirmativeVotes = 0;
    int negativeVotes = 0;
    
    for (var judgment in judgments) {
      final judgeWinner = judgment.data['winner'];
      if (judgeWinner == 'affirmative') {
        affirmativeVotes++;
      } else if (judgeWinner == 'negative') {
        negativeVotes++;
      }
    }

    final isAffirmativeWinner = winner == 'affirmative';
    final winnerDebater = isAffirmativeWinner ? affirmativeDebater : negativeDebater;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: MediaQuery.of(context).size.height * 0.85, // Limit height to 85% of screen
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.grey[50]!,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                child: _buildContent(affirmativeVotes, negativeVotes),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ArenaColors.accentPurple, ArenaColors.deepPurple],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events,
            color: Colors.white,
            size: 40, // Reduced from 48
          ),
          const SizedBox(height: 8), // Reduced from 12
          const Text(
            'DEBATE RESULTS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20, // Reduced from 24
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6), // Reduced from 8
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced padding
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              topic,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12, // Reduced from 14
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(int affirmativeVotes, int negativeVotes) {
    final isAffirmativeWinner = winner == 'affirmative';
    final winnerDebater = isAffirmativeWinner ? affirmativeDebater : negativeDebater;

    return Padding(
      padding: const EdgeInsets.all(20), // Reduced from 24
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Winner Announcement
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16), // Reduced from 20
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withValues(alpha: 0.1),
                  Colors.orange.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 24), // Reduced from 32
                    const SizedBox(width: 6), // Reduced from 8
                    Text(
                      'WINNER',
                      style: TextStyle(
                        color: Colors.amber[800],
                        fontSize: 16, // Reduced from 20
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 6), // Reduced from 8
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 24), // Reduced from 32
                  ],
                ),
                const SizedBox(height: 12), // Reduced from 16
                if (winnerDebater != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 2), // Reduced from 3
                        ),
                        child: UserAvatar(
                          avatarUrl: winnerDebater.avatar,
                          initials: winnerDebater.name.isNotEmpty ? winnerDebater.name[0] : '?',
                          radius: 24, // Reduced from 32
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              winnerDebater.name,
                              style: const TextStyle(
                                fontSize: 16, // Reduced from 20
                                fontWeight: FontWeight.bold,
                                color: ArenaColors.deepPurple,
                              ),
                            ),
                            Text(
                              '${winner.toUpperCase()} SIDE',
                              style: TextStyle(
                                fontSize: 12, // Reduced from 14
                                fontWeight: FontWeight.w600,
                                color: isAffirmativeWinner ? Colors.green : ArenaColors.scarletRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16), // Reduced from 24

          // Vote Breakdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12), // Reduced from 16
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Judge Votes',
                  style: TextStyle(
                    fontSize: 16, // Reduced from 18
                    fontWeight: FontWeight.bold,
                    color: ArenaColors.deepPurple,
                  ),
                ),
                const SizedBox(height: 12), // Reduced from 16
                _buildVoteRow('Affirmative', affirmativeVotes, isAffirmativeWinner, Colors.green),
                const SizedBox(height: 6), // Reduced from 8
                _buildVoteRow('Negative', negativeVotes, !isAffirmativeWinner, ArenaColors.scarletRed),
              ],
            ),
          ),

          const SizedBox(height: 12), // Reduced from 16

          // Individual Judge Scores (if we have detailed scores)
          if (judgments.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12), // Reduced from 16
              decoration: BoxDecoration(
                color: ArenaColors.accentPurple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ArenaColors.accentPurple.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Judge Details',
                    style: TextStyle(
                      fontSize: 14, // Reduced from 16
                      fontWeight: FontWeight.bold,
                      color: ArenaColors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 6), // Reduced from 8
                  ...judgments.map((judgment) {
                    final index = judgments.indexOf(judgment);
                    final judgeWinner = judgment.data['winner'];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3), // Reduced from 4
                      child: Row(
                        children: [
                          Icon(
                            Icons.gavel,
                            size: 14, // Reduced from 16
                            color: ArenaColors.accentPurple,
                          ),
                          const SizedBox(width: 6), // Reduced from 8
                          Text(
                            'Judge ${index + 1}:',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: ArenaColors.deepPurple,
                              fontSize: 12, // Added smaller font
                            ),
                          ),
                          const SizedBox(width: 6), // Reduced from 8
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), // Reduced padding
                            decoration: BoxDecoration(
                              color: judgeWinner == 'affirmative' ? Colors.green : ArenaColors.scarletRed,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              judgeWinner?.toUpperCase() ?? 'UNKNOWN',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10, // Reduced from 12
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoteRow(String side, int votes, bool isWinner, Color color) {
    return Row(
      children: [
        Container(
          width: 20, // Reduced from 24
          height: 20, // Reduced from 24
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              votes.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12, // Reduced from 14
              ),
            ),
          ),
        ),
        const SizedBox(width: 10), // Reduced from 12
        Text(
          side,
          style: TextStyle(
            fontSize: 14, // Reduced from 16
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        if (isWinner) ...[
          const SizedBox(width: 6), // Reduced from 8
          const Icon(
            Icons.check_circle,
            color: Colors.amber,
            size: 16, // Reduced from 20
          ),
        ],
        const Spacer(),
        Text(
          '$votes vote${votes != 1 ? 's' : ''}',
          style: TextStyle(
            fontSize: 12, // Reduced from 14
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16), // Reduced from 24
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ArenaColors.accentPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12), // Reduced from 16
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Close Results',
                style: TextStyle(
                  fontSize: 14, // Reduced from 16
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6), // Reduced from 8
          Text(
            'Great debate! 🎉',
            style: TextStyle(
              fontSize: 12, // Reduced from 14
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}