import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/user_avatar.dart';
import '../features/arena/providers/arena_comprehensive_provider.dart';
import '../features/arena/models/arena_state.dart';

/// Riverpod-based ArenaScreen that replaces the complex StatefulWidget
class ArenaScreenRiverpod extends ConsumerWidget {
  final String roomId;
  final String challengeId;
  final String topic;
  final String? description;
  final String? category;
  final String? challengerId;
  final String? challengedId;

  const ArenaScreenRiverpod({
    super.key,
    required this.roomId,
    required this.challengeId,
    required this.topic,
    this.description,
    this.category,
    this.challengerId,
    this.challengedId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Create arena initialization parameters
    final arenaParams = ArenaInitParams(
      roomId: roomId,
      challengeId: challengeId,
      topic: topic,
      description: description,
      category: category,
      challengerId: challengerId,
      challengedId: challengedId,
    );

    // Watch the comprehensive arena state
    final arenaState = ref.watch(arenaComprehensiveProvider(arenaParams));
    
    // Watch specialized providers
    final participants = ref.watch(arenaParticipantsProvider(arenaParams));
    final audience = ref.watch(arenaAudienceProvider(arenaParams));
    final judgingState = ref.watch(arenaJudgingProvider(arenaParams));
    // final uiState = ref.watch(arenaUIStateProvider(roomId));
    final networkHealthy = ref.watch(arenaNetworkHealthProvider(arenaParams));
    
    // Get notifier for actions
    final arenaNotifier = ref.read(arenaComprehensiveProvider(arenaParams).notifier);

    // Show loading state
    if (arenaState.isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Loading Arena...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      );
    }

    // Show error state
    if (arenaState.error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Error: ${arenaState.error}',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header with connection status
            _buildHeader(context, arenaState, networkHealthy),
            
            // Timer Display
            _buildTimerDisplay(context, arenaState),
            
            // Main Content
            Expanded(
              child: Row(
                children: [
                  // Left Panel - Participants
                  Expanded(
                    flex: 1,
                    child: _buildParticipantsPanel(
                      context,
                      participants,
                      audience,
                      arenaState,
                    ),
                  ),
                  
                  // Center Panel - Debate Area
                  Expanded(
                    flex: 2,
                    child: _buildDebatePanel(context, arenaState),
                  ),
                  
                  // Right Panel - Controls and Chat
                  Expanded(
                    flex: 1,
                    child: _buildControlsPanel(
                      context,
                      arenaState,
                      arenaNotifier,
                      judgingState,
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom Controls
            _buildBottomControls(context, arenaState, arenaNotifier),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ArenaState state, bool networkHealthy) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6B46C1).withValues(alpha: 0.9),
            const Color(0xFF8B5CF6).withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          
          const SizedBox(width: 16),
          
          // Topic and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.topic,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      networkHealthy ? Icons.wifi : Icons.wifi_off,
                      color: networkHealthy ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      networkHealthy ? 'Connected' : 'Reconnecting...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Phase indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              state.currentPhase.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay(BuildContext context, ArenaState state) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6B46C1).withValues(alpha: 0.9),
            const Color(0xFF8B5CF6).withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Phase description
          Text(
            state.currentPhase.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Timer display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                state.isTimerRunning 
                  ? (state.isPaused ? Icons.pause : Icons.play_arrow)
                  : Icons.timer_off,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 16),
              Text(
                state.formattedRemainingTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          
          // Timer status
          if (state.isTimerRunning || state.isPaused)
            Text(
              state.isPaused ? 'PAUSED' : 'RUNNING',
              style: TextStyle(
                color: state.isPaused ? Colors.orange : Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantsPanel(
    BuildContext context,
    Map<String, ArenaParticipant?> participants,
    List<ArenaParticipant> audience,
    ArenaState state,
  ) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Participants',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Debate roles
          _buildRoleSection('Affirmative', participants['affirmative'], Colors.blue),
          const SizedBox(height: 12),
          _buildRoleSection('Negative', participants['negative'], Colors.red),
          const SizedBox(height: 12),
          _buildRoleSection('Moderator', participants['moderator'], Colors.purple),
          
          const SizedBox(height: 16),
          
          // Judges
          const Text(
            'Judges',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildRoleSection('Judge 1', participants['judge1'], Colors.orange),
          _buildRoleSection('Judge 2', participants['judge2'], Colors.orange),
          _buildRoleSection('Judge 3', participants['judge3'], Colors.orange),
          
          const SizedBox(height: 16),
          
          // Audience
          const Text(
            'Audience',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: audience.length,
              itemBuilder: (context, index) {
                final member = audience[index];
                return ListTile(
                  leading: UserAvatar(
                    avatarUrl: member.avatar,
                    initials: member.name.isNotEmpty ? member.name[0] : '?',
                    radius: 16,
                  ),
                  title: Text(
                    member.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  dense: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSection(String roleName, ArenaParticipant? participant, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            roleName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (participant != null) ...[
            UserAvatar(
              avatarUrl: participant.avatar,
              initials: participant.name.isNotEmpty ? participant.name[0] : '?',
              radius: 12,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                participant.name,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            Text(
              'Empty',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildDebatePanel(BuildContext context, ArenaState state) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        children: [
          // Current speaker indicator
          if (state.currentSpeaker != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Current Speaker: ${state.currentSpeaker}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Debate content area
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.forum,
                    color: Colors.grey[400],
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Debate in Progress',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.currentPhase.description,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsPanel(
    BuildContext context,
    ArenaState state,
    ArenaComprehensiveNotifier notifier,
    ({bool enabled, bool complete, bool userVoted, String? winner}) judgingState,
  ) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Controls',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Moderator controls (show if user is moderator)
          if (state.userRole == 'moderator') ...[
            _buildModeratorControls(context, state, notifier),
            const SizedBox(height: 16),
          ],
          
          // Judge controls (show if user is a judge)
          if (state.userRole?.startsWith('judge') == true) ...[
            _buildJudgeControls(context, judgingState, notifier),
            const SizedBox(height: 16),
          ],
          
          // Participant controls
          _buildParticipantControls(context, state, notifier),
          
          const Spacer(),
          
          // Room status
          _buildRoomStatus(context, state),
        ],
      ),
    );
  }

  Widget _buildModeratorControls(
    BuildContext context,
    ArenaState state,
    ArenaComprehensiveNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Moderator Controls',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        // Timer controls
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: state.isTimerRunning ? null : () => notifier.startPhaseTimer(),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: state.isTimerRunning && !state.isPaused ? () => notifier.pauseTimer() : null,
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: state.isPaused ? () => notifier.resumeTimer() : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Phase controls
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => notifier.advanceToNextPhase(),
              icon: const Icon(Icons.skip_next),
              label: const Text('Next Phase'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => notifier.resetTimer(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJudgeControls(
    BuildContext context,
    ({bool enabled, bool complete, bool userVoted, String? winner}) judgingState,
    ArenaComprehensiveNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Judge Controls',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        if (judgingState.enabled && !judgingState.userVoted) ...[
          ElevatedButton.icon(
            onPressed: () {
              // Show voting dialog
              _showVotingDialog(context, notifier);
            },
            icon: const Icon(Icons.how_to_vote),
            label: const Text('Cast Vote'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ] else if (judgingState.userVoted) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Vote Cast',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Waiting for judging phase',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildParticipantControls(
    BuildContext context,
    ArenaState state,
    ArenaComprehensiveNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Participant Controls',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        // Speaking controls for debaters
        if (state.userRole == 'affirmative' || state.userRole == 'negative') ...[
          ElevatedButton.icon(
            onPressed: state.speakingEnabled && state.canUserSpeak(state.currentUserId ?? '')
              ? () => notifier.setSpeaker(state.currentUserId)
              : null,
            icon: const Icon(Icons.mic),
            label: const Text('Request to Speak'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        // Leave room
        ElevatedButton.icon(
          onPressed: () => _showLeaveRoomDialog(context, notifier),
          icon: const Icon(Icons.exit_to_app),
          label: const Text('Leave Room'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildRoomStatus(BuildContext context, ArenaState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Room Status',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Phase: ${state.currentPhase.displayName}',
            style: TextStyle(color: Colors.grey[300], fontSize: 12),
          ),
          Text(
            'Status: ${state.status.name}',
            style: TextStyle(color: Colors.grey[300], fontSize: 12),
          ),
          if (state.winner != null)
            Text(
              'Winner: ${state.winner}',
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    ArenaState state,
    ArenaComprehensiveNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(top: BorderSide(color: Colors.grey[700]!)),
      ),
      child: Row(
        children: [
          // Connection status
          Row(
            children: [
              Icon(
                state.isRealtimeHealthy ? Icons.wifi : Icons.wifi_off,
                color: state.isRealtimeHealthy ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                state.isRealtimeHealthy ? 'Connected' : 'Reconnecting...',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          // Room ID
          Text(
            'Room: ${state.roomId}',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showVotingDialog(BuildContext context, ArenaComprehensiveNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cast Your Vote'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Who performed better in this debate?'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                notifier.setUserVoted(true);
                Navigator.of(context).pop();
              },
              child: const Text('Affirmative'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                notifier.setUserVoted(true);
                Navigator.of(context).pop();
              },
              child: const Text('Negative'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showLeaveRoomDialog(BuildContext context, ArenaComprehensiveNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Room'),
        content: const Text('Are you sure you want to leave this debate room?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await notifier.leaveRoom();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}