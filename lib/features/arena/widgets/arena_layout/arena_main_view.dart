import 'package:flutter/material.dart';
import '../../../../models/user_profile.dart';
import '../../constants/arena_colors.dart';
import 'debater_position_widget.dart';
import 'judge_position_widget.dart';
import 'audience_display_widget.dart';

/// Arena Main View - DO NOT MODIFY LAYOUT
/// This is the core arena layout with exact positioning and spacing
class ArenaMainView extends StatelessWidget {
  final String topic;
  final Map<String, UserProfile?> participants;
  final List<UserProfile> audience;
  final bool judgingComplete;
  final String? winner;

  const ArenaMainView({
    super.key,
    required this.topic,
    required this.participants,
    required this.audience,
    required this.judgingComplete,
    this.winner,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            padding: const EdgeInsets.all(8),
            // Add bottom padding to allow scrolling underneath bottom navigation (approximately 100px for the control panel)
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  // Debate Title (more compact)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: ArenaColors.deepPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ArenaColors.deepPurple.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      topic,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                        fontSize: 12,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // Main arena content - fixed heights instead of flexible
                  Column(
                    children: [
                      // Top Row - Debaters (fixed height)
                      SizedBox(
                        height: 200, // Fixed height instead of flex 40
                        child: Row(
                          children: [
                            Expanded(
                              child: DebaterPositionWidget(
                                role: 'affirmative',
                                title: 'Affirmative',
                                participant: participants['affirmative'],
                                judgingComplete: judgingComplete,
                                winner: winner,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DebaterPositionWidget(
                                role: 'negative',
                                title: 'Negative',
                                participant: participants['negative'],
                                judgingComplete: judgingComplete,
                                winner: winner,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // Middle Row - Moderator (fixed height)
                      SizedBox(
                        height: 120, // Fixed height instead of flex 25
                        child: Row(
                          children: [
                            const Expanded(child: SizedBox.shrink()),
                            Expanded(
                              flex: 2,
                              child: JudgePositionWidget(
                                role: 'moderator',
                                title: 'Moderator',
                                participant: participants['moderator'],
                                isPurple: true,
                              ),
                            ),
                            const Expanded(child: SizedBox.shrink()),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // Bottom Row - Judges (fixed height)
                      SizedBox(
                        height: 150, // Fixed height instead of flex 30
                        child: Row(
                          children: [
                            Expanded(
                              child: JudgePositionWidget(
                                role: 'judge1',
                                title: 'Judge 1',
                                participant: participants['judge1'],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: JudgePositionWidget(
                                role: 'judge2',
                                title: 'Judge 2',
                                participant: participants['judge2'],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: JudgePositionWidget(
                                role: 'judge3',
                                title: 'Judge 3',
                                participant: participants['judge3'],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Audience Display (scrollable)
                      AudienceDisplayWidget(audience: audience),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}