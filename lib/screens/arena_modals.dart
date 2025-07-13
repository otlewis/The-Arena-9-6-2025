import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/user_avatar.dart';
import '../models/user_profile.dart';
import '../models/message.dart';
import '../models/judge_scorecard.dart';
import '../services/chat_service.dart';
import '../widgets/debater_invite_choice_modal.dart';
import 'package:intl/intl.dart';
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
      required Function(JudgeScorecard) onSubmitScorecard,
      required String roomId,
      String? roomTopic,
    }
  ) {
    showDialog(
      context: context,
      builder: (context) => JudgingPanel(
        participants: participants,
        audience: audience,
        currentUserId: currentUserId,
        hasCurrentUserSubmittedVote: hasCurrentUserSubmittedVote,
        onSubmitScorecard: onSubmitScorecard,
        roomId: roomId,
        roomTopic: roomTopic,
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
          Navigator.pop(context); // Dismiss the modal first
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
          const Icon(
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
            Navigator.pop(context); // Dismiss the modal first
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
  final Function(JudgeScorecard) onSubmitScorecard;
  final String roomId;
  final String? roomTopic;

  const JudgingPanel({
    super.key,
    required this.participants,
    required this.audience,
    required this.currentUserId,
    required this.hasCurrentUserSubmittedVote,
    required this.onSubmitScorecard,
    required this.roomId,
    this.roomTopic,
  });

  @override
  State<JudgingPanel> createState() => _JudgingPanelState();
}

class _JudgingPanelState extends State<JudgingPanel> with TickerProviderStateMixin {
  late TabController _tabController;
  late JudgeScorecard _scorecard;
  final PageController _pageController = PageController();
  int _currentSpeakerIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeScorecard();
  }

  void _initializeScorecard() {
    final currentUser = widget.audience.firstWhere(
      (user) => user.id == widget.currentUserId,
      orElse: () => UserProfile(
        id: widget.currentUserId ?? '',
        name: 'Judge',
        email: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final speakers = <SpeakerScore>[];
    
    // Add affirmative speakers (1v1: just 'affirmative', 2v2: both 'affirmative' and 'affirmative2')
    if (widget.participants['affirmative'] != null) {
      speakers.add(SpeakerScore(
        speakerName: widget.participants['affirmative']!.name,
        teamSide: TeamSide.affirmative,
      ));
    }
    
    if (widget.participants['affirmative2'] != null) {
      speakers.add(SpeakerScore(
        speakerName: widget.participants['affirmative2']!.name,
        teamSide: TeamSide.affirmative,
      ));
    }
    
    // Add negative speakers (1v1: just 'negative', 2v2: both 'negative' and 'negative2')
    if (widget.participants['negative'] != null) {
      speakers.add(SpeakerScore(
        speakerName: widget.participants['negative']!.name,
        teamSide: TeamSide.negative,
      ));
    }
    
    if (widget.participants['negative2'] != null) {
      speakers.add(SpeakerScore(
        speakerName: widget.participants['negative2']!.name,
        teamSide: TeamSide.negative,
      ));
    }

    _scorecard = JudgeScorecard(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: widget.roomId,
      judgeId: currentUser.id,
      judgeName: currentUser.name,
      debateTopic: widget.roomTopic ?? '',
      debateRound: 'Round 1',
      speakerScores: speakers,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hasCurrentUserSubmittedVote) {
      return _buildAlreadySubmittedDialog();
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildScoringTab(),
                  _buildDecisionTab(),
                ],
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadySubmittedDialog() {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('Scorecard Submitted'),
        ],
      ),
      content: const Text('You have already submitted your scorecard for this debate.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: ArenaModalColors.accentPurple,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.gavel, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Judge Scorecard (70-Point Scale)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Judge: ${_scorecard.judgeName} • ${DateFormat('MMM dd, yyyy').format(_scorecard.dateScored)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showRulesModal,
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'View Debate Rules',
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: ArenaModalColors.accentPurple,
        unselectedLabelColor: Colors.grey,
        indicatorColor: ArenaModalColors.accentPurple,
        tabs: const [
          Tab(text: 'Scoring', icon: Icon(Icons.edit_note)),
          Tab(text: 'Decision', icon: Icon(Icons.how_to_vote)),
        ],
      ),
    );
  }

  Widget _buildScoringTab() {
    if (_scorecard.speakerScores.isEmpty) {
      return const Center(
        child: Text('No speakers found for this debate.'),
      );
    }

    return Column(
      children: [
        _buildSpeakerNavigation(),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentSpeakerIndex = index;
              });
            },
            itemCount: _scorecard.speakerScores.length,
            itemBuilder: (context, index) {
              return _buildSpeakerScoringPage(_scorecard.speakerScores[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpeakerNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: _currentSpeakerIndex > 0
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            icon: const Icon(Icons.arrow_back_ios),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Speaker ${_currentSpeakerIndex + 1} of ${_scorecard.speakerScores.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _currentSpeakerIndex < _scorecard.speakerScores.length - 1
                ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            icon: const Icon(Icons.arrow_forward_ios),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakerScoringPage(SpeakerScore speakerScore, int index) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSpeakerHeader(speakerScore),
          const SizedBox(height: 24),
          _buildScoringGuidelines(),
          const SizedBox(height: 24),
          ...ScoringCategory.values.map((category) => 
            _buildCategoryScoring(speakerScore, category, index)
          ),
          const SizedBox(height: 24),
          _buildTotalScore(speakerScore),
          const SizedBox(height: 24),
          _buildCommentsSection(speakerScore, index),
        ],
      ),
    );
  }

  Widget _buildSpeakerHeader(SpeakerScore speakerScore) {
    // Find the correct participant by matching the speaker name
    UserProfile? participant;
    for (final entry in widget.participants.entries) {
      if (entry.value.name == speakerScore.speakerName) {
        participant = entry.value;
        break;
      }
    }

    final teamColor = speakerScore.teamSide == TeamSide.affirmative 
        ? Colors.green 
        : ArenaModalColors.scarletRed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: teamColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: teamColor),
      ),
      child: Row(
        children: [
          if (participant != null) ...[
            UserAvatar(
              avatarUrl: participant.avatar,
              initials: participant.name.isNotEmpty ? participant.name[0] : '?',
              radius: 30,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  speakerScore.speakerName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${speakerScore.teamSide.displayName} Side',
                  style: TextStyle(
                    color: teamColor,
                    fontSize: 14,
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

  Widget _buildScoringGuidelines() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scoring Guidelines (70-Point Scale)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...PerformanceLevel.values.map((level) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${level.minScore}-${level.maxScore}: ${level.description}',
              style: const TextStyle(fontSize: 12),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCategoryScoring(SpeakerScore speakerScore, ScoringCategory category, int speakerIndex) {
    final currentScore = speakerScore.categoryScores[category] ?? 0;
    
    Color getCategoryColor() {
      switch (category) {
        case ScoringCategory.arguments:
          return Colors.blue;
        case ScoringCategory.presentation:
          return Colors.green;
        case ScoringCategory.rebuttal:
          return Colors.orange;
        case ScoringCategory.crossExam:
          return Colors.purple;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: getCategoryColor(),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$currentScore / ${category.maxPoints}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: getCategoryColor(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            category.description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: getCategoryColor(),
              thumbColor: getCategoryColor(),
              overlayColor: getCategoryColor().withValues(alpha: 0.2),
              valueIndicatorColor: getCategoryColor(),
              inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
            ),
            child: Slider(
              value: currentScore.toDouble(),
              min: 0,
              max: category.maxPoints.toDouble(),
              divisions: category.maxPoints,
              label: currentScore.toString(),
              onChanged: (value) {
                setState(() {
                  final updatedSpeaker = speakerScore.copyWith(
                    categoryScores: {
                      ...speakerScore.categoryScores,
                      category: value.round(),
                    },
                  );
                  _scorecard = _scorecard.copyWith(
                    speakerScores: [
                      ..._scorecard.speakerScores.take(speakerIndex),
                      updatedSpeaker,
                      ..._scorecard.speakerScores.skip(speakerIndex + 1),
                    ],
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalScore(SpeakerScore speakerScore) {
    final totalScore = speakerScore.totalScore;
    final performanceLevel = speakerScore.performanceLevel;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ArenaModalColors.accentPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ArenaModalColors.accentPurple),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Score',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                performanceLevel.description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          Text(
            '$totalScore / ${ScoringCategory.totalMaxPoints}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ArenaModalColors.accentPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(SpeakerScore speakerScore, int speakerIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comments/Feedback',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (value) {
            final updatedSpeaker = speakerScore.copyWith(comments: value);
            setState(() {
              _scorecard = _scorecard.copyWith(
                speakerScores: [
                  ..._scorecard.speakerScores.take(speakerIndex),
                  updatedSpeaker,
                  ..._scorecard.speakerScores.skip(speakerIndex + 1),
                ],
              );
            });
          },
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Provide specific feedback on the speaker\'s performance...',
          ),
        ),
      ],
    );
  }

  Widget _buildDecisionTab() {
    final calculatedWinner = _scorecard.calculatedWinner;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTeamScoreSummary(),
          const SizedBox(height: 24),
          _buildWinnerSelection(calculatedWinner),
          const SizedBox(height: 24),
          _buildReasonForDecision(),
          const SizedBox(height: 24),
          _buildValidationWarnings(),
        ],
      ),
    );
  }

  Widget _buildTeamScoreSummary() {
    final affirmativeTotal = _scorecard.getTotalScoreForTeam(TeamSide.affirmative);
    final negativeTotal = _scorecard.getTotalScoreForTeam(TeamSide.negative);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Team Score Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTeamScoreCard(
                  'Affirmative',
                  affirmativeTotal,
                  Colors.green,
                  affirmativeTotal > negativeTotal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTeamScoreCard(
                  'Negative',
                  negativeTotal,
                  ArenaModalColors.scarletRed,
                  negativeTotal > affirmativeTotal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamScoreCard(String teamName, int score, Color color, bool isWinning) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWinning ? color : color.withValues(alpha: 0.3),
          width: isWinning ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            teamName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            score.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (isWinning) ...[
            const SizedBox(height: 4),
            Icon(
              Icons.emoji_events,
              color: color,
              size: 16,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWinnerSelection(TeamSide calculatedWinner) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Winner Declaration',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Based on scores, ${calculatedWinner.displayName} should win.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        ...TeamSide.values.map((side) => _buildWinnerOption(side)),
      ],
    );
  }

  Widget _buildWinnerOption(TeamSide side) {
    final isSelected = _scorecard.winningTeam == side;
    final color = side == TeamSide.affirmative ? Colors.green : ArenaModalColors.scarletRed;

    return GestureDetector(
      onTap: () {
        setState(() {
          _scorecard = _scorecard.copyWith(winningTeam: side);
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<TeamSide>(
              value: side,
              groupValue: _scorecard.winningTeam,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _scorecard = _scorecard.copyWith(winningTeam: value);
                  });
                }
              },
              activeColor: color,
            ),
            Text(
              side.displayName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonForDecision() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reason for Decision',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (value) {
            setState(() {
              _scorecard = _scorecard.copyWith(reasonForDecision: value);
            });
          },
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Explain your decision and key factors that influenced your judgment...',
          ),
        ),
      ],
    );
  }

  Widget _buildValidationWarnings() {
    final warnings = <String>[];
    
    if (!_scorecard.isWinnerConsistentWithScores) {
      warnings.add('Warning: Winner selection does not match score totals.');
    }
    
    if (!_scorecard.isComplete) {
      warnings.add('Please complete all scores and provide a reason for decision.');
    }

    if (warnings.isEmpty) return Container();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                'Validation Issues',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...warnings.map((warning) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $warning',
              style: const TextStyle(fontSize: 12),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _scorecard.isComplete 
                ? () {
                    final finalScorecard = _scorecard.copyWith(
                      isSubmitted: true,
                      dateScored: DateTime.now(),
                    );
                    widget.onSubmitScorecard(finalScorecard);
                    Navigator.pop(context);
                  }
                : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: ArenaModalColors.accentPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit Scorecard'),
            ),
          ),
        ],
      ),
    );
  }

  void _showRulesModal() {
    showDialog(
      context: context,
      builder: (context) => const DebateRulesModal(),
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
      title: const Row(
        children: [
          Icon(Icons.people, color: ArenaModalColors.accentPurple),
          SizedBox(width: 8),
          Text('Role Manager'),
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
            decoration: const BoxDecoration(
              color: ArenaModalColors.accentPurple,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  icon: const Icon(Icons.send, color: ArenaModalColors.accentPurple),
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
            decoration: const BoxDecoration(
              color: ArenaModalColors.accentPurple,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                          const Icon(Icons.info_outline, color: Colors.green, size: 16),
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
                          const Icon(
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

// Debate Rules Modal Component
class DebateRulesModal extends StatelessWidget {
  const DebateRulesModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
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
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: ArenaModalColors.accentPurple,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gavel, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Debate Rules & Guidelines',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      'DEBATE FORMAT',
                      [
                        '• Opening Statements: Each side presents their main arguments (3-5 minutes each)',
                        '• Cross-Examination: Opposing sides question each other directly (2-3 minutes each)',
                        '• Rebuttal Phase: Address opposing arguments and reinforce your position (3-4 minutes each)',
                        '• Closing Statements: Final opportunity to summarize and persuade (2-3 minutes each)',
                      ],
                    ),
                    
                    _buildSection(
                      'SCORING CRITERIA (70 Points Total)',
                      [
                        'Arguments & Content (20 points): Strength and logic of arguments, quality of evidence, relevance to topic',
                        'Presentation & Delivery (20 points): Clarity, fluency, voice projection, engagement with audience',
                        'Rebuttal & Defence (20 points): Effective refutation of opposing arguments, defense of own positions',
                        'Cross-Examination (10 points): Quality of questions asked and responses given during cross-examination',
                      ],
                    ),
                    
                    _buildSection(
                      'PERFORMANCE LEVELS',
                      [
                        'Excellent (60-70 points): Outstanding performance demonstrating mastery',
                        'Good (50-59 points): Strong performance with minor areas for improvement',
                        'Average (40-49 points): Adequate performance meeting basic requirements',
                        'Below Average (30-39 points): Performance needs significant improvement',
                        'Poor (Below 30 points): Performance falls short of expectations',
                      ],
                    ),
                    
                    _buildSection(
                      'CONDUCT RULES',
                      [
                        '• Respect time limits - moderator will enforce strict timing',
                        '• No personal attacks or inappropriate language',
                        '• Address arguments, not individuals',
                        '• Stay on topic and relevant to the debate resolution',
                        '• Allow opponents to speak without interruption',
                        '• Use evidence and sources to support claims',
                      ],
                    ),
                    
                    _buildSection(
                      'JUDGING GUIDELINES',
                      [
                        '• Judges must remain impartial and base decisions solely on performance',
                        '• Consider both content quality and presentation skills',
                        '• Take notes during each phase to support scoring decisions',
                        '• Provide constructive feedback in decision rationale',
                        '• Winner must have higher total points across all categories',
                      ],
                    ),
                    
                    _buildSection(
                      'TECHNICAL REQUIREMENTS',
                      [
                        '• Stable internet connection required for all participants',
                        '• Clear audio and video preferred for optimal experience',
                        '• Backup connection recommended for important debates',
                        '• Screen sharing available for visual aids (debaters and moderators only)',
                        '• Recording may be enabled - participants will be notified',
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Footer note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ArenaModalColors.lightGray,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ArenaModalColors.accentPurple.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: ArenaModalColors.accentPurple,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'These rules ensure fair, educational, and engaging debates. All participants are expected to follow these guidelines.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer with close button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: ArenaModalColors.lightGray,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ArenaModalColors.accentPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ArenaModalColors.deepPurple,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            item,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.black87,
            ),
          ),
        )),
        const SizedBox(height: 24),
      ],
    );
  }
}