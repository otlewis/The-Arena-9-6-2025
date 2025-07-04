import 'package:flutter/material.dart';
import '../models/debate_phase.dart';
import '../../../models/user_profile.dart';

/// Moderator Control Modal - DO NOT MODIFY UI LAYOUT
/// This modal provides all moderator controls during a debate
class ModeratorControlModal extends StatelessWidget {
  final DebatePhase currentPhase;
  final VoidCallback onAdvancePhase;
  final VoidCallback onEmergencyReset;
  final VoidCallback onEndDebate;
  final VoidCallback onCloseRoom;
  final Function(String) onSpeakerChange;
  final VoidCallback onToggleSpeaking;
  final VoidCallback onToggleJudging;
  final String currentSpeaker;
  final bool speakingEnabled;
  final bool judgingEnabled;
  final UserProfile? affirmativeParticipant;
  final UserProfile? negativeParticipant;
  final String? debateCategory;

  const ModeratorControlModal({
    super.key,
    required this.currentPhase,
    required this.onAdvancePhase,
    required this.onEmergencyReset,
    required this.onEndDebate,
    required this.onCloseRoom,
    required this.onSpeakerChange,
    required this.onToggleSpeaking,
    required this.onToggleJudging,
    required this.currentSpeaker,
    required this.speakingEnabled,
    required this.judgingEnabled,
    this.affirmativeParticipant,
    this.negativeParticipant,
    this.debateCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber, Colors.orange],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.black, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'MODERATOR CONTROLS',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.black),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                // Current Phase Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.purple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentPhase.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              currentPhase.description,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Phase Management
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      children: [
                        Expanded(
                          child: _buildControlButton(
                            icon: Icons.skip_next,
                            label: 'Next Phase',
                            onPressed: currentPhase.nextPhase != null 
                                ? () {
                                    Navigator.pop(context);
                                    onAdvancePhase();
                                  }
                                : null,
                            color: Colors.purple,
                          ),
                        ),
                        SizedBox(width: constraints.maxWidth < 300 ? 6 : 12),
                        Expanded(
                          child: _buildControlButton(
                            icon: Icons.emergency,
                            label: 'Emergency',
                            onPressed: () => _showEmergencyDialog(context),
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Speaking Controls
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      children: [
                        Expanded(
                          child: _buildControlButton(
                            icon: speakingEnabled ? Icons.mic_off : Icons.mic,
                            label: speakingEnabled ? 'Mute All' : 'Unmute',
                            onPressed: () {
                              onToggleSpeaking();
                              Navigator.pop(context);
                            },
                            color: speakingEnabled ? Colors.red : Colors.green,
                          ),
                        ),
                        SizedBox(width: constraints.maxWidth < 300 ? 6 : 12),
                        Expanded(
                          child: _buildControlButton(
                            icon: judgingEnabled ? Icons.gavel_outlined : Icons.gavel,
                            label: judgingEnabled ? 'Close Voting' : 'Open Voting',
                            onPressed: () {
                              onToggleJudging();
                              Navigator.pop(context);
                            },
                            color: judgingEnabled ? Colors.orange : Colors.teal,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Note: Judges are automatically selected from audience
                
                // Speaker Assignment
                if (affirmativeParticipant != null || negativeParticipant != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Assign Speaker',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (affirmativeParticipant != null)
                        Expanded(
                          child: _buildSpeakerButton(
                            'Affirmative',
                            'affirmative',
                            currentSpeaker == 'affirmative',
                            () {
                              onSpeakerChange(currentSpeaker == 'affirmative' ? '' : 'affirmative');
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      if (affirmativeParticipant != null && negativeParticipant != null)
                        const SizedBox(width: 12),
                      if (negativeParticipant != null)
                        Expanded(
                          child: _buildSpeakerButton(
                            'Negative',
                            'negative',
                            currentSpeaker == 'negative',
                            () {
                              onSpeakerChange(currentSpeaker == 'negative' ? '' : 'negative');
                              Navigator.pop(context);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    final isEnabled = onPressed != null;
    
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isEnabled ? color : Colors.grey[600],
          borderRadius: BorderRadius.circular(8),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 100) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 14),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              );
            } else {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildSpeakerButton(String label, String role, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.green : Colors.grey[700],
          borderRadius: BorderRadius.circular(6),
          border: isActive ? Border.all(color: Colors.greenAccent, width: 2) : null,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.emergency, color: Colors.orange),
            const SizedBox(width: 8),
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Text(
                    constraints.maxWidth < 150 ? 'Emergency' : 'Emergency Controls',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
          ],
        ),
        content: const Text('Choose an emergency action:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close modal
              onEmergencyReset();
            },
            child: const Text('Reset Debate'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close modal
              onEndDebate();
            },
            child: const Text('End Debate'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close modal
              onCloseRoom();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Close Room'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}