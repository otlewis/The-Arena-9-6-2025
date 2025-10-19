import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal that shows when all judges have submitted their votes
class AllVotesInModal extends StatefulWidget {
  final int totalJudges;
  final VoidCallback onDismiss;
  final VoidCallback? onViewResults;

  const AllVotesInModal({
    super.key,
    required this.totalJudges,
    required this.onDismiss,
    this.onViewResults,
  });

  @override
  State<AllVotesInModal> createState() => _AllVotesInModalState();
}

class _AllVotesInModalState extends State<AllVotesInModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _checkmarkAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _animationController.forward();

    // Play success haptic feedback
    HapticFeedback.mediumImpact();

    // Delayed second haptic for emphasis
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        HapticFeedback.lightImpact();
      }
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    _checkmarkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 0.8, curve: Curves.elasticOut),
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(0, 10),
                    blurRadius: 30,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with gradient
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.shade600,
                          Colors.green.shade500,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Animated checkmark circle
                        ScaleTransition(
                          scale: _checkmarkAnimation,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              size: 60,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'All Votes Are In!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.totalJudges} judge${widget.totalJudges == 1 ? '' : 's'} submitted',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Success message
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.shade200,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.gavel,
                                color: Colors.green.shade700,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Judging Complete',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'All judges have cast their votes. You can now proceed to announce the results.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Vote breakdown
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildVoteIndicator(),
                            const SizedBox(width: 8),
                            _buildVoteIndicator(),
                            const SizedBox(width: 8),
                            _buildVoteIndicator(),
                          ].take(widget.totalJudges).toList(),
                        ),

                        const SizedBox(height: 24),

                        // Action buttons
                        Row(
                          children: [
                            // Dismiss button
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                  widget.onDismiss();
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(
                                    color: Colors.grey.shade400,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Dismiss',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // View Results button
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                  widget.onViewResults?.call();
                                  widget.onDismiss();
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.visibility, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'View Results',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoteIndicator() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.green.shade400,
          width: 3,
        ),
      ),
      child: Icon(
        Icons.how_to_vote,
        color: Colors.green.shade700,
        size: 24,
      ),
    );
  }
}
