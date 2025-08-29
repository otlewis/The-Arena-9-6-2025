import '../core/logging/app_logger.dart';
import 'package:flutter/material.dart';
import '../widgets/synchronized_timer_widget.dart';
import '../models/timer_state.dart';
import '../config/timer_presets.dart';

/// Integration examples showing how to use the SynchronizedTimerWidget
/// across different room types in the Arena app.

class TimerIntegrationExamples {
  // Example 1: Integration into Open Discussion Room Screen
  static Widget openDiscussionIntegration({
    required String roomId,
    required String userId,
    required bool isModerator,
    String? currentSpeaker,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Discussion'),
        actions: [
          // Compact timer in app bar for always-visible access
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SynchronizedTimerWidget(
              roomId: roomId,
              roomType: RoomType.openDiscussion,
              isModerator: isModerator,
              userId: userId,
              currentSpeaker: currentSpeaker,
              compact: true,
              showControls: isModerator,
              onTimerExpired: () {
                // Handle timer expiry in open discussion
                _showTimerExpiredDialog('Discussion time is up!');
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main content area
          Expanded(
            child: _buildDiscussionContent(),
          ),
          
          // Moderator controls section
          if (isModerator) 
            _buildModeratorTimerControls(roomId, userId),
        ],
      ),
    );
  }

  // Example 2: Integration into Debates & Discussions Room Screen
  static Widget debatesDiscussionsIntegration({
    required String roomId,
    required String userId,
    required bool isModerator,
    required List<String> speakerPanel,
    String? currentSpeaker,
  }) {
    return Scaffold(
      body: Column(
        children: [
          // Timer positioned above speaker panel
          if (isModerator || currentSpeaker != null)
            Container(
              padding: const EdgeInsets.all(16),
              child: SynchronizedTimerWidget(
                roomId: roomId,
                roomType: RoomType.debatesDiscussions,
                isModerator: isModerator,
                userId: userId,
                currentSpeaker: currentSpeaker,
                showControls: isModerator,
                onTimerStarted: () {
                  // Notify when speaker time starts
                  _showSnackBar('Speaker timer started for $currentSpeaker');
                },
                onTimerExpired: () {
                  // Handle speaker time expiry
                  _handleSpeakerTimeExpired(currentSpeaker);
                },
              ),
            ),
          
          // Speaker panel
          _buildSpeakerPanel(speakerPanel, currentSpeaker),
          
          // Discussion content
          Expanded(
            child: _buildDiscussionContent(),
          ),
          
          // Moderator controls
          if (isModerator)
            _buildModeratorControls(roomId, userId, speakerPanel),
        ],
      ),
    );
  }

  // Example 3: Integration into Arena Debate Screen
  static Widget arenaDebateIntegration({
    required String roomId,
    required String userId,
    required bool isJudge,
    required String debater1,
    required String debater2,
    String? currentDebater,
    String? currentPhase,
  }) {
    return Scaffold(
      body: Column(
        children: [
          // Arena header with debate info
          _buildArenaHeader(debater1, debater2, currentPhase),
          
          // Central timer display - prominent for formal debates
          Container(
            margin: const EdgeInsets.all(16),
            child: SynchronizedTimerWidget(
              roomId: roomId,
              roomType: RoomType.arena,
              isModerator: isJudge,
              userId: userId,
              currentSpeaker: currentDebater,
              onTimerExpired: () {
                // Handle formal debate phase completion
                _handleDebatePhaseComplete(currentPhase, currentDebater);
              },
              onTimerStarted: () {
                // Announce phase start
                _announcePhaseStart(currentPhase, currentDebater);
              },
            ),
          ),
          
          // Debate content area
          Expanded(
            child: _buildDebateContent(debater1, debater2, currentDebater),
          ),
          
          // Judge controls (strict timing rules)
          if (isJudge)
            _buildJudgeTimerControls(roomId, userId),
        ],
      ),
    );
  }

  // Example 4: Floating Timer Overlay
  static Widget floatingTimerOverlay({
    required String roomId,
    required RoomType roomType,
    required String userId,
    required bool isModerator,
    String? currentSpeaker,
  }) {
    return Stack(
      children: [
        // Your existing screen content
        _buildMainContent(),
        
        // Floating timer in corner
        Positioned(
          top: 100,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SynchronizedTimerWidget(
              roomId: roomId,
              roomType: roomType,
              isModerator: isModerator,
              userId: userId,
              currentSpeaker: currentSpeaker,
              compact: true,
            ),
          ),
        ),
      ],
    );
  }

  // Example 5: Bottom Sheet Timer Controls
  static void showTimerBottomSheet({
    required BuildContext context,
    required String roomId,
    required RoomType roomType,
    required String userId,
    required bool isModerator,
    String? currentSpeaker,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Timer widget
            SynchronizedTimerWidget(
              roomId: roomId,
              roomType: roomType,
              isModerator: isModerator,
              userId: userId,
              currentSpeaker: currentSpeaker,
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Helper methods for building UI components
  static Widget _buildDiscussionContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: Text(
          'Discussion content goes here...\n'
          'Messages, participant list, etc.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  static Widget _buildModeratorTimerControls(String roomId, String userId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              // Quick start 5-minute discussion timer
              _createQuickTimer(roomId, userId, RoomType.openDiscussion, 300);
            },
            icon: const Icon(Icons.timer),
            label: const Text('5 Min Timer'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // Show timer presets bottom sheet
              // showTimerBottomSheet(...);
            },
            icon: const Icon(Icons.settings),
            label: const Text('Timer Settings'),
          ),
        ],
      ),
    );
  }

  static Widget _buildSpeakerPanel(List<String> speakers, String? currentSpeaker) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: speakers.length,
        itemBuilder: (context, index) {
          final speaker = speakers[index];
          final isActive = speaker == currentSpeaker;
          
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isActive ? Colors.blue : Colors.grey,
                  child: Text(speaker[0]),
                ),
                const SizedBox(height: 4),
                Text(
                  speaker,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _buildArenaHeader(String debater1, String debater2, String? phase) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[900],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  debater1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Pro',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Text(
                'VS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (phase != null)
                Text(
                  phase,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  debater2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Con',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDebateContent(String debater1, String debater2, String? currentDebater) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (currentDebater != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    '$currentDebater is speaking',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Expanded(
            child: Center(
              child: Text(
                'Debate content and judge scoring interface...',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildModeratorControls(String roomId, String userId, List<String> speakers) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border(top: BorderSide(color: Colors.green[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Moderator Controls',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ...speakers.map((speaker) => ActionChip(
                label: Text('Start $speaker'),
                onPressed: () => _startSpeakerTimer(roomId, userId, speaker),
              )),
              ActionChip(
                label: const Text('Q&A Round'),
                onPressed: () => _startQATimer(roomId, userId),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildJudgeTimerControls(String roomId, String userId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        border: Border(top: BorderSide(color: Colors.purple[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPhaseButton('Opening', TimerType.openingStatement, roomId, userId),
          _buildPhaseButton('Rebuttal', TimerType.rebuttal, roomId, userId),
          _buildPhaseButton('Closing', TimerType.closingStatement, roomId, userId),
          _buildPhaseButton('Cross-Ex', TimerType.questionRound, roomId, userId),
        ],
      ),
    );
  }

  static Widget _buildPhaseButton(String label, TimerType timerType, String roomId, String userId) {
    return ElevatedButton(
      onPressed: () => _startDebatePhase(roomId, userId, timerType),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }

  static Widget _buildMainContent() {
    return Container(
      color: Colors.grey[100],
      child: const Center(
        child: Text('Main screen content'),
      ),
    );
  }

  // Helper methods for timer actions (implement based on your app's needs)
  static void _showTimerExpiredDialog(String message) {
    // Show dialog or snackbar
    AppLogger().debug('Timer expired: $message');
  }

  static void _showSnackBar(String message) {
    AppLogger().debug('Timer event: $message');
  }

  static void _handleSpeakerTimeExpired(String? speaker) {
    AppLogger().debug('Speaker time expired for: $speaker');
    // Implement speaker rotation logic
  }

  static void _handleDebatePhaseComplete(String? phase, String? debater) {
    AppLogger().debug('Debate phase complete: $phase for $debater');
    // Implement phase transition logic
  }

  static void _announcePhaseStart(String? phase, String? debater) {
    AppLogger().debug('Phase started: $phase for $debater');
    // Implement announcement logic
  }

  static void _createQuickTimer(String roomId, String userId, RoomType roomType, int duration) {
    AppLogger().debug('Creating quick timer: ${duration}s for room $roomId');
    // Implement timer creation
  }

  static void _startSpeakerTimer(String roomId, String userId, String speaker) {
    AppLogger().debug('Starting speaker timer for: $speaker');
    // Implement speaker timer logic
  }

  static void _startQATimer(String roomId, String userId) {
    AppLogger().debug('Starting Q&A timer');
    // Implement Q&A timer logic
  }

  static void _startDebatePhase(String roomId, String userId, TimerType timerType) {
    AppLogger().debug('Starting debate phase: ${timerType.displayName}');
    // Implement debate phase timer logic
  }
}

/// Usage instructions for integrating the timer into your existing screens:
///
/// 1. **Open Discussion Room Integration:**
/// ```dart
/// // In your open_discussion_room_screen.dart
/// class OpenDiscussionRoomScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return TimerIntegrationExamples.openDiscussionIntegration(
///       roomId: widget.roomId,
///       userId: currentUserId,
///       isModerator: userRole == 'moderator',
///       currentSpeaker: getCurrentSpeaker(),
///     );
///   }
/// }
/// ```
///
/// 2. **Debates & Discussions Integration:**
/// ```dart
/// // Add to your existing screen
/// SynchronizedTimerWidget(
///   roomId: roomId,
///   roomType: RoomType.debatesDiscussions,
///   isModerator: isModerator,
///   userId: userId,
///   currentSpeaker: currentSpeaker,
/// )
/// ```
///
/// 3. **Arena Integration:**
/// ```dart
/// // In your arena_screen.dart
/// SynchronizedTimerWidget(
///   roomId: roomId,
///   roomType: RoomType.arena,
///   isModerator: isJudge,
///   userId: userId,
///   currentSpeaker: currentDebater,
/// )
/// ```