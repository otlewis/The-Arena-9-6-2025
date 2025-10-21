import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Persistent bottom sheet showing judge voting progress for moderators
class JudgeVotingProgressSheet extends StatelessWidget {
  final int votedCount;
  final int totalCount;
  final VoidCallback? onViewResults;
  final VoidCallback onDismiss;

  const JudgeVotingProgressSheet({
    super.key,
    required this.votedCount,
    required this.totalCount,
    this.onViewResults,
    required this.onDismiss,
  });

  bool get isComplete => votedCount == totalCount && totalCount > 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isComplete ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isComplete ? Colors.green.shade400 : Colors.blue.shade400,
            width: 3,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isComplete
                          ? Colors.green.shade600
                          : Colors.blue.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isComplete ? Icons.check_circle : Icons.how_to_vote,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Progress text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isComplete
                              ? 'All Votes Are In!'
                              : 'Judges Voting',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isComplete
                                ? Colors.green.shade900
                                : Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$votedCount/$totalCount judges have voted',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Vote indicators
                  Row(
                    children: List.generate(totalCount, (index) {
                      final hasVoted = index < votedCount;
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: hasVoted
                                ? (isComplete ? Colors.green : Colors.blue)
                                : Colors.grey.shade300,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: hasVoted
                                  ? (isComplete
                                      ? Colors.green.shade700
                                      : Colors.blue.shade700)
                                  : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            hasVoted ? Icons.check : Icons.person,
                            color: hasVoted ? Colors.white : Colors.grey.shade600,
                            size: 16,
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(width: 8),

                  // Action button
                  if (isComplete)
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onViewResults?.call();
                      },
                      icon: const Icon(Icons.visibility),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      tooltip: 'View Results',
                    )
                  else
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onDismiss();
                      },
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.grey.shade700,
                      ),
                      tooltip: 'Dismiss',
                    ),
                ],
              ),

              // Completion message
              if (isComplete) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.shade400,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.celebration,
                        color: Colors.green.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can now proceed to announce results',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
