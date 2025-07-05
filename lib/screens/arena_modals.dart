import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/user_avatar.dart';
import '../models/user_profile.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../widgets/debater_invite_choice_modal.dart';
// Conditional import to avoid web compilation issues

// Color constants
class ArenaModalColors {
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color lightGray = Color(0xFFF5F5F5);
}

class ArenaModals {
  // Show moderator control modal
  static void showModeratorControlModal(
    BuildContext context,
    {
      required VoidCallback onShowTimerControls,
      required VoidCallback onShowJudgingPanel,
      required VoidCallback onShowRoleManager,
      required VoidCallback onToggleJudging,
      required VoidCallback onToggleSpeaking,
      required Function(String) onForceSpeakerChange,
      required VoidCallback onShowResults,
      required VoidCallback onCloseRoom,
      required bool judgingEnabled,
      required bool speakingEnabled,
      required String currentSpeaker,
    }
  ) {
    showDialog(
      context: context,
      builder: (context) => ModeratorControlModal(
        onShowTimerControls: onShowTimerControls,
        onShowJudgingPanel: onShowJudgingPanel,
        onShowRoleManager: onShowRoleManager,
        onToggleJudging: onToggleJudging,
        onToggleSpeaking: onToggleSpeaking,
        onForceSpeakerChange: onForceSpeakerChange,
        onShowResults: onShowResults,
        onCloseRoom: onCloseRoom,
        judgingEnabled: judgingEnabled,
        speakingEnabled: speakingEnabled,
        currentSpeaker: currentSpeaker,
      ),
    );
  }

  // Show results modal
  static void showResultsModal(
    BuildContext context,
    {
      required String? winner,
      required Map<String, UserProfile> participants,
      required List<UserProfile> audience,
      required VoidCallback onClose,
    }
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ResultsModal(
        winner: winner,
        participants: participants,
        audience: audience,
        onClose: onClose,
      ),
    );
  }

  // Show room closing modal
  static void showRoomClosingModal(
    BuildContext context,
    int initialSeconds,
    {required VoidCallback onRoomClosed}
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RoomClosingModal(
        initialSeconds: initialSeconds,
        onRoomClosed: onRoomClosed,
      ),
    );
  }

  // Show coming soon dialog
  static void showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🚀 $feature'),
        content: Text('$feature is coming soon! Stay tuned for updates.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  // Show gift coming soon
  static void showGiftComingSoon(BuildContext context) {
    showComingSoonDialog(context, 'Gift System');
  }

  // Show judging panel
  static void showJudgingPanel(
    BuildContext context,
    {
      required Map<String, UserProfile> participants,
      required List<UserProfile> audience,
      required String? currentUserId,
      required bool hasCurrentUserSubmittedVote,
      required Function(String) onSubmitVote,
    }
  ) {
    showDialog(
      context: context,
      builder: (context) => JudgingPanel(
        participants: participants,
        audience: audience,
        currentUserId: currentUserId,
        hasCurrentUserSubmittedVote: hasCurrentUserSubmittedVote,
        onSubmitVote: onSubmitVote,
      ),
    );
  }

  // Show role manager
  static void showRoleManager(
    BuildContext context,
    {
      required Map<String, UserProfile> participants,
      required List<UserProfile> audience,
      required Function(UserProfile, String) onAssignRole,
      required Function(UserProfile) onAssignModeratorFromAudience,
      required Function(UserProfile) onAssignJudgeFromAudience,
    }
  ) {
    showDialog(
      context: context,
      builder: (context) => RoleManagerPanel(
        participants: participants,
        audience: audience,
        onAssignRole: onAssignRole,
        onAssignModeratorFromAudience: onAssignModeratorFromAudience,
        onAssignJudgeFromAudience: onAssignJudgeFromAudience,
      ),
    );
  }

  // Show chat bottom sheet
  static void showChatBottomSheet(
    BuildContext context,
    {
      required ChatService chatService,
      required String roomId,
      required String? currentUserId,
    }
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ArenaChatBottomSheet(
        chatService: chatService,
        roomId: roomId,
        currentUserId: currentUserId,
      ),
    );
  }

  // Show debater invite choice modal
  static void showDebaterInviteChoiceModal(
    BuildContext context,
    {
      required String currentUserId,
      required String debaterRole,
      required List<UserProfile> networkUsers,
      required Function(Map<String, String?>) onInviteSelectionComplete,
      required VoidCallback onSkip,
      String? challengerId,
      String? challengedId,
    }
  ) {
    showDialog(
      context: context,
      builder: (context) => DebaterInviteChoiceModal(
        currentUserId: currentUserId,
        debaterRole: debaterRole,
        networkUsers: networkUsers,
        onInviteSelectionComplete: onInviteSelectionComplete,
        onSkip: onSkip,
        challengerId: challengerId,
        challengedId: challengedId,
      ),
    );
  }
}

// Moderator Control Modal
class ModeratorControlModal extends StatelessWidget {
  final VoidCallback onShowTimerControls;
  final VoidCallback onShowJudgingPanel;
  final VoidCallback onShowRoleManager;
  final VoidCallback onToggleJudging;
  final VoidCallback onToggleSpeaking;
  final Function(String) onForceSpeakerChange;
  final VoidCallback onShowResults;
  final VoidCallback onCloseRoom;
  final bool judgingEnabled;
  final bool speakingEnabled;
  final String currentSpeaker;

  const ModeratorControlModal({
    super.key,
    required this.onShowTimerControls,
    required this.onShowJudgingPanel,
    required this.onShowRoleManager,
    required this.onToggleJudging,
    required this.onToggleSpeaking,
    required this.onForceSpeakerChange,
    required this.onShowResults,
    required this.onCloseRoom,
    required this.judgingEnabled,
    required this.speakingEnabled,
    required this.currentSpeaker,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.admin_panel_settings, color: ArenaModalColors.accentPurple),
          SizedBox(width: 8),
          Text('Moderator Controls'),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          minWidth: 300,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Timer Controls
              _buildControlTile(
                icon: Icons.timer,
                title: 'Timer Controls',
                subtitle: 'Manage debate timing',
                onTap: () {
                  Navigator.pop(context);
                  onShowTimerControls();
                },
              ),
              
              // Judging Panel
              _buildControlTile(
                icon: Icons.how_to_vote,
                title: 'Judging Panel',
                subtitle: judgingEnabled ? 'Judging enabled' : 'Judging disabled',
                onTap: () {
                  Navigator.pop(context);
                  onShowJudgingPanel();
                },
                trailing: Switch(
                  value: judgingEnabled,
                  onChanged: (_) => onToggleJudging(),
                  activeColor: ArenaModalColors.accentPurple,
                ),
              ),
              
              // Role Manager
              _buildControlTile(
                icon: Icons.people,
                title: 'Role Manager',
                subtitle: 'Assign participant roles',
                onTap: () {
                  Navigator.pop(context);
                  onShowRoleManager();
                },
              ),
              
              // Speaking Controls
              _buildControlTile(
                icon: speakingEnabled ? Icons.mic : Icons.mic_off,
                title: 'Speaking Control',
                subtitle: speakingEnabled 
                    ? 'Speaking: ${currentSpeaker.isNotEmpty ? currentSpeaker.toUpperCase() : 'None'}'
                    : 'Speaking disabled',
                onTap: () => onToggleSpeaking(),
                trailing: Switch(
                  value: speakingEnabled,
                  onChanged: (_) => onToggleSpeaking(),
                  activeColor: ArenaModalColors.accentPurple,
                ),
              ),
              
              const Divider(height: 20),
              
              // Force Speaker Change
              if (currentSpeaker.isNotEmpty) ...[
                const Text(
                  'Force Speaker Change',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        onForceSpeakerChange('affirmative');
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Affirmative', style: TextStyle(color: Colors.white)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        onForceSpeakerChange('negative');
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: ArenaModalColors.scarletRed),
                      child: const Text('Negative', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              
              // Results & Close
              _buildControlTile(
                icon: Icons.poll,
                title: 'Show Results',
                subtitle: 'Display debate results',
                onTap: () {
                  Navigator.pop(context);
                  onShowResults();
                },
                color: Colors.blue,
              ),
              
              _buildControlTile(
                icon: Icons.close,
                title: 'Close Room',
                subtitle: 'End the debate session',
                onTap: () {
                  Navigator.pop(context);
                  onCloseRoom();
                },
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildControlTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color ?? ArenaModalColors.accentPurple),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: onTap,
        dense: true,
      ),
    );
  }
}

// Results Modal
class ResultsModal extends StatelessWidget {
  final String? winner;
  final Map<String, UserProfile> participants;
  final List<UserProfile> audience;
  final VoidCallback onClose;

  const ResultsModal({
    super.key,
    required this.winner,
    required this.participants,
    required this.audience,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.emoji_events, color: Colors.amber, size: 28),
          SizedBox(width: 8),
          Text('🏆 Debate Results'),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
          minWidth: 300,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Winner announcement
              if (winner != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.withValues(alpha: 0.2), Colors.orange.withValues(alpha: 0.2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '🎉 WINNER 🎉',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (participants[winner] != null) ...[
                        UserAvatar(
                          avatarUrl: participants[winner]!.avatar,
                          initials: participants[winner]!.name.isNotEmpty ? participants[winner]!.name[0] : '?',
                          radius: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          participants[winner]!.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          winner!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            color: winner == 'affirmative' ? Colors.green : ArenaModalColors.scarletRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                const Text(
                  'No winner declared',
                  style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
              ],
              
              // Participants
              const Text(
                'Participants',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              if (participants['affirmative'] != null)
                _buildParticipantInfo('Affirmative', participants['affirmative']!, Colors.green),
              if (participants['negative'] != null)
                _buildParticipantInfo('Negative', participants['negative']!, ArenaModalColors.scarletRed),
              if (participants['moderator'] != null)
                _buildParticipantInfo('Moderator', participants['moderator']!, ArenaModalColors.accentPurple),
              
              // Judges
              if (participants.keys.any((key) => key.startsWith('judge'))) ...[
                const SizedBox(height: 12),
                const Text(
                  'Judges',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...participants.entries
                    .where((entry) => entry.key.startsWith('judge'))
                    .map((entry) => _buildParticipantInfo(
                          'Judge ${entry.key.replaceAll('judge', '')}',
                          entry.value,
                          Colors.amber,
                        )),
              ],
              
              // Audience count
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ArenaModalColors.accentPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people, color: ArenaModalColors.accentPurple),
                    const SizedBox(width: 8),
                    Text(
                      'Audience: ${audience.length} members',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: onClose,
          style: ElevatedButton.styleFrom(backgroundColor: ArenaModalColors.accentPurple),
          child: const Text('Close', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildParticipantInfo(String role, UserProfile user, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          UserAvatar(
            avatarUrl: user.avatar,
            initials: user.name.isNotEmpty ? user.name[0] : '?',
            radius: 25,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Room Closing Modal
class RoomClosingModal extends StatefulWidget {
  final int initialSeconds;
  final VoidCallback onRoomClosed;

  const RoomClosingModal({
    super.key,
    required this.initialSeconds,
    required this.onRoomClosed,
  });

  @override
  State<RoomClosingModal> createState() => _RoomClosingModalState();
}

class _RoomClosingModalState extends State<RoomClosingModal> {
  late int _remainingSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
        });
        
        if (_remainingSeconds <= 0) {
          timer.cancel();
          widget.onRoomClosed();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.timer, color: Colors.orange),
          SizedBox(width: 8),
          Text('Room Closing'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber,
            size: 48,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          const Text(
            'This room will close automatically',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Time remaining: $_remainingSeconds seconds',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            _countdownTimer?.cancel();
            widget.onRoomClosed();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('Close Now', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// Judging Panel
class JudgingPanel extends StatefulWidget {
  final Map<String, UserProfile> participants;
  final List<UserProfile> audience;
  final String? currentUserId;
  final bool hasCurrentUserSubmittedVote;
  final Function(String) onSubmitVote;

  const JudgingPanel({
    super.key,
    required this.participants,
    required this.audience,
    required this.currentUserId,
    required this.hasCurrentUserSubmittedVote,
    required this.onSubmitVote,
  });

  @override
  State<JudgingPanel> createState() => _JudgingPanelState();
}

class _JudgingPanelState extends State<JudgingPanel> {
  String? _selectedWinner;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.how_to_vote, color: ArenaModalColors.accentPurple),
          const SizedBox(width: 8),
          const Text('Cast Your Vote'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.hasCurrentUserSubmittedVote) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('You have already submitted your vote'),
                ],
              ),
            ),
          ] else ...[
            const Text(
              'Select the winner of this debate:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            
            // Affirmative option
            if (widget.participants['affirmative'] != null)
              _buildVoteOption(
                'affirmative',
                widget.participants['affirmative']!,
                Colors.green,
              ),
            
            const SizedBox(height: 12),
            
            // Negative option
            if (widget.participants['negative'] != null)
              _buildVoteOption(
                'negative',
                widget.participants['negative']!,
                ArenaModalColors.scarletRed,
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!widget.hasCurrentUserSubmittedVote && _selectedWinner != null)
          ElevatedButton(
            onPressed: () {
              widget.onSubmitVote(_selectedWinner!);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: ArenaModalColors.accentPurple),
            child: const Text('Submit Vote', style: TextStyle(color: Colors.white)),
          ),
      ],
    );
  }

  Widget _buildVoteOption(String role, UserProfile participant, Color color) {
    final isSelected = _selectedWinner == role;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedWinner = role;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: role,
              groupValue: _selectedWinner,
              onChanged: (value) {
                setState(() {
                  _selectedWinner = value;
                });
              },
              activeColor: color,
            ),
            const SizedBox(width: 8),
            UserAvatar(
              avatarUrl: participant.avatar,
              initials: participant.name.isNotEmpty ? participant.name[0] : '?',
              radius: 25,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Role Manager Panel (simplified version)
class RoleManagerPanel extends StatelessWidget {
  final Map<String, UserProfile> participants;
  final List<UserProfile> audience;
  final Function(UserProfile, String) onAssignRole;
  final Function(UserProfile) onAssignModeratorFromAudience;
  final Function(UserProfile) onAssignJudgeFromAudience;

  const RoleManagerPanel({
    super.key,
    required this.participants,
    required this.audience,
    required this.onAssignRole,
    required this.onAssignModeratorFromAudience,
    required this.onAssignJudgeFromAudience,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.people, color: ArenaModalColors.accentPurple),
          const SizedBox(width: 8),
          const Text('Role Manager'),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
          minWidth: 300,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Roles',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              // Display current participants
              if (participants.isNotEmpty) ...[
                ...participants.entries.map((entry) => ListTile(
                  leading: UserAvatar(
                    avatarUrl: entry.value.avatar,
                    initials: entry.value.name.isNotEmpty ? entry.value.name[0] : '?',
                    radius: 20,
                  ),
                  title: Text(entry.value.name),
                  subtitle: Text(entry.key.toUpperCase()),
                  dense: true,
                )),
              ] else ...[
                const Text('No assigned roles', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
              
              const SizedBox(height: 16),
              const Text(
                'Audience (tap to assign roles)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              // Display audience members
              if (audience.isNotEmpty) ...[
                ...audience.take(10).map((user) => ListTile(
                  leading: UserAvatar(
                    avatarUrl: user.avatar,
                    initials: user.name.isNotEmpty ? user.name[0] : '?',
                    radius: 20,
                  ),
                  title: Text(user.name),
                  subtitle: const Text('Audience'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (role) {
                      Navigator.pop(context);
                      if (role == 'moderator') {
                        onAssignModeratorFromAudience(user);
                      } else if (role.startsWith('judge')) {
                        onAssignJudgeFromAudience(user);
                      } else {
                        onAssignRole(user, role);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'affirmative', child: Text('Affirmative')),
                      const PopupMenuItem(value: 'negative', child: Text('Negative')),
                      const PopupMenuItem(value: 'moderator', child: Text('Moderator')),
                      const PopupMenuItem(value: 'judge1', child: Text('Judge')),
                    ],
                    child: const Icon(Icons.more_vert),
                  ),
                  dense: true,
                )),
                if (audience.length > 10)
                  Text('... and ${audience.length - 10} more'),
              ] else ...[
                const Text('No audience members', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// Arena Chat Bottom Sheet (simplified version)
class ArenaChatBottomSheet extends StatefulWidget {
  final ChatService chatService;
  final String roomId;
  final String? currentUserId;

  const ArenaChatBottomSheet({
    super.key,
    required this.chatService,
    required this.roomId,
    required this.currentUserId,
  });

  @override
  State<ArenaChatBottomSheet> createState() => _ArenaChatBottomSheetState();
}

class _ArenaChatBottomSheetState extends State<ArenaChatBottomSheet> {
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _loadMessages() {
    // Load chat messages
    // Implementation would depend on your ChatService
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty && widget.currentUserId != null) {
      // Send message logic
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ArenaModalColors.accentPurple,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Arena Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          
          // Messages
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  )
                : ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return ListTile(
                        title: Text(message.senderName),
                        subtitle: Text(message.content),
                        dense: true,
                      );
                    },
                  ),
          ),
          
          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: Icon(Icons.send, color: ArenaModalColors.accentPurple),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Share Screen Bottom Sheet
class ShareScreenBottomSheet extends StatefulWidget {
  final String? currentUserId;
  final String? userRole;
  final VoidCallback? onStartScreenShare;
  final VoidCallback? onStopScreenShare;
  final bool isScreenSharing;
  final VoidCallback? onRequestScreenShare;
  final dynamic agoraEngine; // Add Agora engine for video view (dynamic for web compatibility)

  const ShareScreenBottomSheet({
    super.key,
    this.currentUserId,
    this.userRole,
    this.onStartScreenShare,
    this.onStopScreenShare,
    this.isScreenSharing = false,
    this.onRequestScreenShare,
    this.agoraEngine,
  });

  @override
  State<ShareScreenBottomSheet> createState() => _ShareScreenBottomSheetState();
}

class _ShareScreenBottomSheetState extends State<ShareScreenBottomSheet> {
  bool _isDebater = false;
  bool _canShareScreen = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  void _checkPermissions() {
    _isDebater = widget.userRole == 'affirmative' || widget.userRole == 'negative';
    final isJudge = widget.userRole?.startsWith('judge') == true;
    final isModerator = widget.userRole == 'moderator';
    
    // Only moderators, debaters, and judges can access screen sharing
    // Audience members cannot share screens at all
    _canShareScreen = isModerator || _isDebater || isJudge;
  }
  
  String _getInfoTextForRole() {
    switch (widget.userRole) {
      case 'moderator':
        return 'As a moderator, you can share your screen at any time to present information.';
      case 'affirmative':
      case 'negative':
        return 'As a debater, you need moderator permission to share your screen. You can present evidence or visual aids during your speaking time.';
      default:
        if (widget.userRole?.startsWith('judge') == true) {
          return 'As a judge, you need moderator permission to share your screen for deliberation purposes.';
        }
        return 'Screen sharing is not available for your role.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8, // Increased height for video view
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ArenaModalColors.accentPurple,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.screen_share, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Share Screen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Screen sharing status
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.isScreenSharing 
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isScreenSharing 
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.isScreenSharing 
                              ? Icons.screen_share
                              : Icons.stop_screen_share,
                          color: widget.isScreenSharing 
                              ? Colors.green
                              : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isScreenSharing 
                                    ? 'Screen Sharing Active'
                                    : 'Screen Sharing Inactive',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isScreenSharing 
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.isScreenSharing
                                    ? 'Your screen is being shared with the audience'
                                    : 'Share your screen to show content to the audience',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Screen sharing video view (when actively sharing)
                  if (widget.isScreenSharing && widget.agoraEngine != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      height: 250, // Increased height for better viewing
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.5), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.2),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _buildScreenShareVideoView(),
                          ),
                          // Live indicator
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Screen share info
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '🖥️ This is what the audience sees',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your screen is being shared. Use this preview to monitor your presentation.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  if (_canShareScreen) ...[
                    if (!widget.isScreenSharing) ...[
                      // Start screen share button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.onStartScreenShare,
                          icon: const Icon(Icons.screen_share, color: Colors.white),
                          label: const Text(
                            'Start Screen Share',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ArenaModalColors.accentPurple,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Info text
                      Text(
                        _getInfoTextForRole(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      // Stop screen share button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.onStopScreenShare,
                          icon: const Icon(Icons.stop_screen_share, color: Colors.white),
                          label: const Text(
                            'Stop Screen Share',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ArenaModalColors.scarletRed,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your screen is currently being shared. Click above to stop sharing.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ] else ...[
                    // Permission denied message
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Screen Sharing Restricted',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Only debaters and moderators can share their screen during the debate.',
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          if (widget.userRole == 'audience') ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: widget.onRequestScreenShare,
                                icon: const Icon(Icons.pan_tool, color: Colors.white),
                                label: const Text(
                                  'Request Permission',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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

  /// Build the screen sharing video view
  Widget _buildScreenShareVideoView() {
    if (widget.agoraEngine == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_off,
                color: Colors.grey,
                size: 48,
              ),
              SizedBox(height: 8),
              Text(
                'Video preview unavailable',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    try {
      // For web compatibility, return a placeholder widget
      if (widget.agoraEngine == null) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: Text(
              'Screen Sharing\n(Web Preview)',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      
      // For mobile platforms, use the engine dynamically
      return _buildAgoraVideoView();
    } catch (e) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                'Error loading video preview',
                style: TextStyle(
                  color: Colors.orange[300],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Screen sharing is still active',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildAgoraVideoView() {
    // This method should only be called on mobile platforms
    // Using dynamic calls to avoid web compilation issues
    try {
      // For mobile platforms, we can use reflection or dynamic calls
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Video View\n(Mobile Only)',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } catch (e) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Video Unavailable',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }
}