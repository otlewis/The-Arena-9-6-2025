import '../core/logging/app_logger.dart';
import 'package:flutter/material.dart';
import '../widgets/appwrite_timer_widget.dart';
import '../widgets/timer_sync_indicator.dart';
import '../models/timer_state.dart';

/// Complete integration examples for Appwrite Timer System
/// Shows how to integrate the server-controlled timer across all room types

class AppwriteTimerIntegrationExamples {
  
  // Example 1: Open Discussion Room Integration
  static Widget openDiscussionIntegration({
    required String roomId,
    required String userId,
    required bool isModerator,
    String? currentSpeaker,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Discussion'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          // Connection status badge
          const ConnectionStatusBadge(),
          
          // Compact timer in app bar
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppwriteTimerWidget(
              roomId: roomId,
              roomType: RoomType.openDiscussion,
              isModerator: isModerator,
              userId: userId,
              currentSpeaker: currentSpeaker,
              compact: true,
              showControls: isModerator,
              onTimerExpired: () {
                _showTimerExpiredDialog('Discussion time is up!');
              },
            ),
          ),
          
          // Sync status button
          IconButton(
            onPressed: () => _showSyncStatus(),
            icon: const TimerSyncIndicator(compact: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main discussion content
          Expanded(
            child: _buildDiscussionContent(),
          ),
          
          // Sync indicator at bottom
          const TimerSyncIndicator(compact: false),
          
          // Moderator timer controls
          if (isModerator) 
            _buildModeratorTimerSection(roomId, userId, RoomType.openDiscussion),
        ],
      ),
    );
  }

  // Example 2: Debates & Discussions Room Integration
  static Widget debatesDiscussionsIntegration({
    required String roomId,
    required String userId,
    required bool isModerator,
    required List<String> speakerPanel,
    String? currentSpeaker,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debates & Discussions'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        actions: [
          const ConnectionStatusBadge(),
          IconButton(
            onPressed: () => SyncStatusBottomSheet.show,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: Column(
        children: [
          // Timer positioned above speaker panel
          Container(
            margin: const EdgeInsets.all(16),
            child: AppwriteTimerWidget(
              roomId: roomId,
              roomType: RoomType.debatesDiscussions,
              isModerator: isModerator,
              userId: userId,
              currentSpeaker: currentSpeaker,
              showControls: isModerator,
              onTimerStarted: () {
                _showSnackBar('Speaker timer started for $currentSpeaker');
              },
              onTimerExpired: () {
                _handleSpeakerTimeExpired(currentSpeaker);
              },
            ),
          ),
          
          // Speaker panel with real-time updates
          _buildSpeakerPanel(speakerPanel, currentSpeaker),
          
          // Discussion content
          Expanded(
            child: _buildDiscussionContent(),
          ),
          
          // Moderator controls with speaker management
          if (isModerator)
            _buildDebatesModeratorControls(roomId, userId, speakerPanel),
        ],
      ),
    );
  }

  // Example 3: Arena Formal Debate Integration
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
      appBar: AppBar(
        title: const Text('The Arena'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          const ConnectionStatusBadge(),
          // Compact sync indicator for judges
          if (isJudge)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: TimerSyncIndicator(compact: true),
            ),
        ],
      ),
      body: Column(
        children: [
          // Arena header with debate info
          _buildArenaHeader(debater1, debater2, currentPhase),
          
          // Central timer display - prominent for formal debates
          Container(
            margin: const EdgeInsets.all(16),
            child: AppwriteTimerWidget(
              roomId: roomId,
              roomType: RoomType.arena,
              isModerator: isJudge,
              userId: userId,
              currentSpeaker: currentDebater,
              showConnectionStatus: true,
              onTimerExpired: () {
                _handleDebatePhaseComplete(currentPhase, currentDebater);
              },
              onTimerStarted: () {
                _announcePhaseStart(currentPhase, currentDebater);
              },
            ),
          ),
          
          // Debate content area with real-time scoring
          Expanded(
            child: _buildDebateContent(debater1, debater2, currentDebater),
          ),
          
          // Judge controls with strict Arena timing rules
          if (isJudge) ...[
            const Divider(),
            _buildArenaJudgeControls(roomId, userId),
          ],
        ],
      ),
    );
  }

  // Example 4: Floating Timer Overlay with Offline Support
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
        
        // Floating timer in corner with sync status
        Positioned(
          top: 100,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Connection status
              const TimerSyncIndicator(compact: true),
              const SizedBox(height: 8),
              
              // Floating timer
              Container(
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
                child: AppwriteTimerWidget(
                  roomId: roomId,
                  roomType: roomType,
                  isModerator: isModerator,
                  userId: userId,
                  currentSpeaker: currentSpeaker,
                  compact: true,
                  showConnectionStatus: false, // Shown separately above
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Example 5: Timer Management Bottom Sheet
  static void showTimerManagementSheet({
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
            
            // Title with sync status
            const Row(
              children: [
                Text(
                  'Timer Control',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                TimerSyncIndicator(compact: true),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Full timer widget
            AppwriteTimerWidget(
              roomId: roomId,
              roomType: roomType,
              isModerator: isModerator,
              userId: userId,
              currentSpeaker: currentSpeaker,
              compact: false,
              showConnectionStatus: true,
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Example 6: Real-time Timer Dashboard for Moderators
  static Widget timerDashboard({
    required List<String> roomIds,
    required String userId,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timer Dashboard'),
        actions: [
          const ConnectionStatusBadge(),
          IconButton(
            onPressed: () => _refreshAllTimers(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Global sync status
          const TimerSyncIndicator(compact: false),
          
          // Room timers
          Expanded(
            child: ListView.builder(
              itemCount: roomIds.length,
              itemBuilder: (context, index) {
                final roomId = roomIds[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Room: $roomId',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      AppwriteTimerWidget(
                        roomId: roomId,
                        roomType: RoomType.openDiscussion, // Could be dynamic
                        isModerator: true,
                        userId: userId,
                        compact: true,
                        showConnectionStatus: false,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper UI Builders
  static Widget _buildDiscussionContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Discussion content with real-time updates...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildSpeakerPanel(List<String> speakers, String? currentSpeaker) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7, // Fixed 7 slots for consistency
        itemBuilder: (context, index) {
          final speaker = index < speakers.length ? speakers[index] : null;
          final isActive = speaker == currentSpeaker;
          final isEmpty = speaker == null;
          
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isEmpty 
                      ? Colors.grey[300]
                      : isActive 
                          ? Colors.blue 
                          : Colors.grey,
                  child: isEmpty
                      ? Icon(Icons.person_add, color: Colors.grey[600])
                      : Text(
                          speaker[0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEmpty ? 'Empty' : speaker,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isEmpty ? Colors.grey : null,
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
        gradient: LinearGradient(
          colors: [Colors.blue[900]!, Colors.blue[700]!],
        ),
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
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    phase,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                  const Spacer(),
                  // Real-time sync indicator
                  const TimerSyncIndicator(compact: true),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gavel, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Judge scoring interface with real-time timer sync...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
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

  static Widget _buildModeratorTimerSection(String roomId, String userId, RoomType roomType) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border(top: BorderSide(color: Colors.green[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Moderator Timer Controls',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Spacer(),
              TimerSyncIndicator(compact: true),
            ],
          ),
          const SizedBox(height: 12),
          AppwriteTimerWidget(
            roomId: roomId,
            roomType: roomType,
            isModerator: true,
            userId: userId,
            compact: false,
            showConnectionStatus: false,
          ),
        ],
      ),
    );
  }

  static Widget _buildDebatesModeratorControls(String roomId, String userId, List<String> speakers) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        border: Border(top: BorderSide(color: Colors.purple[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Moderator Controls',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showTimerManagement(roomId, userId),
                icon: const Icon(Icons.timer, size: 16),
                label: const Text('Timer Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[100],
                  foregroundColor: Colors.purple[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ...speakers.map((speaker) => ActionChip(
                label: Text('Start $speaker'),
                onPressed: () => _startSpeakerTimer(roomId, userId, speaker),
                backgroundColor: Colors.purple[100],
              )),
              ActionChip(
                label: const Text('Q&A Round'),
                onPressed: () => _startQATimer(roomId, userId),
                backgroundColor: Colors.orange[100],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildArenaJudgeControls(String roomId, String userId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(top: BorderSide(color: Colors.blue[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Judge Timer Controls',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Spacer(),
              TimerSyncIndicator(compact: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPhaseButton('Opening', TimerType.openingStatement, roomId, userId),
              _buildPhaseButton('Rebuttal', TimerType.rebuttal, roomId, userId),
              _buildPhaseButton('Closing', TimerType.closingStatement, roomId, userId),
              _buildPhaseButton('Cross-Ex', TimerType.questionRound, roomId, userId),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildPhaseButton(String label, TimerType timerType, String roomId, String userId) {
    return ElevatedButton(
      onPressed: () => _startArenaPhase(roomId, userId, timerType),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  static Widget _buildMainContent() {
    return Container(
      color: Colors.grey[100],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Main screen content with real-time features',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // Action handlers (implement based on your app's needs)
  static void _showTimerExpiredDialog(String message) {
    AppLogger().debug('Timer expired: $message');
    // Show dialog or notification
  }

  static void _showSnackBar(String message) {
    AppLogger().debug('Timer event: $message');
    // Show snackbar
  }

  static void _handleSpeakerTimeExpired(String? speaker) {
    AppLogger().debug('Speaker time expired for: $speaker');
    // Implement speaker rotation logic with server sync
  }

  static void _handleDebatePhaseComplete(String? phase, String? debater) {
    AppLogger().debug('Debate phase complete: $phase for $debater');
    // Implement phase transition logic with server sync
  }

  static void _announcePhaseStart(String? phase, String? debater) {
    AppLogger().debug('Phase started: $phase for $debater');
    // Implement announcement logic
  }

  static void _showSyncStatus() {
    AppLogger().debug('Showing sync status');
    // Show sync status dialog
  }

  static void _refreshAllTimers() {
    AppLogger().debug('Refreshing all timers');
    // Force refresh all timer streams
  }

  static void _showTimerManagement(String roomId, String userId) {
    AppLogger().debug('Showing timer management for room: $roomId');
    // Show timer management interface
  }

  static void _startSpeakerTimer(String roomId, String userId, String speaker) {
    AppLogger().debug('Starting speaker timer for: $speaker');
    // Start timer for specific speaker
  }

  static void _startQATimer(String roomId, String userId) {
    AppLogger().debug('Starting Q&A timer');
    // Start Q&A round timer
  }

  static void _startArenaPhase(String roomId, String userId, TimerType timerType) {
    AppLogger().debug('Starting Arena phase: ${timerType.name}');
    // Start specific Arena phase timer
  }
}

/// Usage instructions for integrating the Appwrite timer into your existing screens:
///
/// 1. **Replace existing timer widgets with AppwriteTimerWidget:**
/// ```dart
/// // Old Firebase timer
/// SynchronizedTimerWidget(...)
/// 
/// // New Appwrite timer
/// AppwriteTimerWidget(
///   roomId: roomId,
///   roomType: RoomType.arena,
///   isModerator: isJudge,
///   userId: userId,
///   currentSpeaker: currentDebater,
/// )
/// ```
///
/// 2. **Add connection status indicators:**
/// ```dart
/// // In app bar
/// AppBar(
///   actions: [
///     ConnectionStatusBadge(),
///     TimerSyncIndicator(compact: true),
///   ],
/// )
/// ```
///
/// 3. **Initialize offline service in main.dart:**
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await AppwriteOfflineService().initialize();
///   runApp(MyApp());
/// }
/// ```
///
/// 4. **Add sync status to critical screens:**
/// ```dart
/// Column(
///   children: [
///     TimerSyncIndicator(compact: false),
///     YourExistingContent(),
///   ],
/// )
/// ```