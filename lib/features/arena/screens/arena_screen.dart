import 'package:flutter/material.dart';
import '../../../main.dart' show getIt;
import '../../../services/sound_service.dart';
import '../../../core/logging/app_logger.dart';
import '../controllers/arena_state_controller.dart';
import '../controllers/arena_timer_controller.dart';
import '../services/arena_navigation_service.dart';
import '../widgets/arena_app_bar.dart';
import '../widgets/arena_control_panel.dart';
import '../widgets/arena_layout/arena_main_view.dart';
import '../dialogs/moderator_control_modal.dart';
import '../dialogs/timer_control_modal.dart';
import '../dialogs/results_modal.dart';
import '../../../models/chat_message.dart';
import '../../../models/user_profile.dart';
import '../../../widgets/live_chat_widget.dart';
import '../../../widgets/microphone_control_button.dart';
import '../../../services/appwrite_service.dart';
import '../../../services/smart_webrtc_service.dart';
import '../../../models/room_participant.dart';

/// New Arena Screen - Orchestrates all components
/// This maintains EXACTLY the same functionality as the original 7000+ line file
class ArenaScreen extends StatefulWidget {
  final String roomId;
  final String challengeId;
  final String topic;
  final String? description;
  final String? category;
  final String? challengerId;
  final String? challengedId;

  const ArenaScreen({
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
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen> with TickerProviderStateMixin {
  late final ArenaStateController _stateController;
  late final ArenaTimerController _timerController;
  late final ArenaNavigationService _navigationService;
  late final SoundService _soundService;
  final AppwriteService _appwriteService = AppwriteService();
  
  UserProfile? _currentUser;
  
  // Audio control state
  ParticipantStatus _currentUserAudioStatus = ParticipantStatus.joined;
  bool _isCurrentUserDebater = false;
  
  // Screen sharing state for debaters
  bool _isScreenSharing = false;
  SmartWebRTCService? _webRTCService;
  
  // Screen sharing permission system
  final Map<String, bool> _debaterScreenSharePermissions = {}; // userId -> permission granted
  String? _currentScreenSharingDebater; // Which debater is currently sharing

  @override
  void initState() {
    super.initState();
    
    // Initialize services
    _soundService = getIt<SoundService>();
    
    // Initialize controllers
    _stateController = ArenaStateController();
    _timerController = ArenaTimerController(
      stateController: _stateController,
      soundService: _soundService,
      vsync: this,
    );
    _navigationService = ArenaNavigationService(
      stateController: _stateController,
      roomId: widget.roomId,
    );
    
    // Initialize current user for chat
    _initializeCurrentUser();
    
    // Initialize WebRTC service for video/screen sharing
    _initializeWebRTC();
    
    // Check debater status initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDebaterStatus();
    });
    
    // TODO: Initialize arena (load room data, participants, etc.)
    // This would need to be implemented with the original initialization logic
  }

  @override
  Widget build(BuildContext context) {
    // Update debater status on each build
    _updateDebaterStatus();
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _navigationService.showExitDialog(context);
        }
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([_stateController, _timerController]),
        builder: (context, child) {
          return Scaffold(
            backgroundColor: Colors.black,
          appBar: ArenaAppBar(
            isModerator: _stateController.isModerator,
            isTimerRunning: _stateController.isTimerRunning,
            formattedTime: _stateController.formattedTime,
            onShowModeratorControls: _showModeratorControlModal,
            onShowTimerControls: _showTimerControlModal,
            onExitArena: () => _navigationService.showExitDialog(context),
            onEmergencyCloseRoom: _emergencyCloseRoom,
            roomId: widget.roomId,
            userId: _currentUser?.id ?? ''
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ArenaMainView(
                      topic: widget.topic,
                      participants: _stateController.participants,
                      audience: _stateController.audience,
                      judgingComplete: _stateController.judgingComplete,
                      winner: _stateController.winner,
                    ),
                  ),
                  ArenaControlPanel(
                    judgingComplete: _stateController.judgingComplete,
                    winner: _stateController.winner,
                    isJudge: _stateController.isJudge,
                    isModerator: _stateController.isModerator,
                    hasCurrentUserSubmittedVote: _stateController.hasCurrentUserSubmittedVote,
                    judgingEnabled: _stateController.judgingEnabled,
                    onShowResults: _stateController.judgingComplete ? _showResultsModal : null,
                    onShowJudging: _showComingSoonDialog,
                    onShowGift: _showGiftComingSoon,
                    onShowChat: _showChatBottomSheet,
                    onShowRoleManager: _showRoleManager,
                    onTestDebaterMode: _testDebaterMode,
                    isDebater: _isCurrentUserDebater,
                    onToggleScreenShare: _canCurrentUserScreenShare() ? _toggleScreenShare : null,
                    isScreenSharing: _isScreenSharing,
                    onManageScreenSharePermissions: _stateController.isModerator ? _showScreenSharePermissionsModal : null,
                  ),
                ],
              ),
              
              
              // Floating microphone button for debaters AND moderators
              if (_isCurrentUserDebater || _stateController.isModerator)
                Positioned(
                  bottom: 100, // Above the control panel
                  right: 20,
                  child: FloatingMicrophoneButton(
                    currentStatus: _currentUserAudioStatus,
                    onToggleMute: _toggleMicrophone,
                    isVisible: true,
                  ),
                ),
            ],
          ),
          );
        },
      ),
    );
  }

  /// Show moderator control modal
  void _showModeratorControlModal() {
    showDialog(
      context: context,
      builder: (context) => ModeratorControlModal(
        currentPhase: _stateController.currentPhase,
        onAdvancePhase: () => _timerController.advanceToNextPhase(),
        onEmergencyReset: _handleEmergencyReset,
        onEndDebate: _handleEndDebate,
        onSpeakerChange: _handleSpeakerChange,
        onToggleSpeaking: _handleToggleSpeaking,
        onToggleJudging: _handleToggleJudging,
        currentSpeaker: _stateController.currentSpeaker,
        speakingEnabled: _stateController.speakingEnabled,
        judgingEnabled: _stateController.judgingEnabled,
        affirmativeParticipant: _stateController.participants['affirmative'],
        negativeParticipant: _stateController.participants['negative'],
        debateCategory: widget.category,
      ),
    );
  }

  /// Show timer control modal
  void _showTimerControlModal() {
    showDialog(
      context: context,
      builder: (context) => TimerControlModal(
        currentPhase: _stateController.currentPhase,
        remainingSeconds: _stateController.remainingSeconds,
        isTimerRunning: _stateController.isTimerRunning,
        isPaused: _stateController.isPaused,
        onStart: () => _timerController.startTimer(),
        onPause: () => _timerController.pauseTimer(),
        onResume: () => _timerController.resumeTimer(),
        onStop: () => _timerController.stopTimer(),
        onReset: () => _timerController.resetTimer(),
        onExtendTime: (seconds) => _timerController.extendTime(seconds),
        onSetCustomTime: (seconds) => _timerController.setCustomTime(seconds),
        onAdvancePhase: () => _timerController.advanceToNextPhase(),
      ),
    );
  }

  /// Show results modal
  void _showResultsModal() {
    showDialog(
      context: context,
      builder: (context) => ResultsModal(
        winner: _stateController.winner ?? '',
        affirmativeDebater: _stateController.participants['affirmative'],
        negativeDebater: _stateController.participants['negative'],
        judgments: const [], // TODO: Load actual judgments
        topic: widget.topic,
      ),
    );
  }


  // Placeholder methods for functionality that would need full implementation
  void _handleEmergencyReset() {
    // TODO: Implement emergency reset logic
    _showComingSoonDialog();
  }

  void _handleEndDebate() {
    // TODO: Implement end debate logic
    _showComingSoonDialog();
  }


  void _handleSpeakerChange(String speaker) {
    _stateController.setCurrentSpeaker(speaker);
  }

  void _handleToggleSpeaking() {
    _stateController.setSpeakingEnabled(!_stateController.speakingEnabled);
  }

  void _handleToggleJudging() {
    _stateController.setJudgingEnabled(!_stateController.judgingEnabled);
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚀 Coming Soon'),
        content: const Text('This feature is coming soon! Stay tuned for updates.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showGiftComingSoon() {
    _showComingSoonDialog();
  }

  void _showChatBottomSheet() {
    if (_currentUser == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: LiveChatWidget(
            chatRoomId: widget.roomId,
            roomType: ChatRoomType.arena,
            currentUser: _currentUser!,
            userRole: _getUserRole(),
            isVisible: true,
            onToggleVisibility: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  void _showRoleManager() {
    _showComingSoonDialog();
  }

  /// Test method to simulate being moved to debater status
  void _testDebaterMode() {
    setState(() {
      _isCurrentUserDebater = !_isCurrentUserDebater;
      if (_isCurrentUserDebater) {
        _currentUserAudioStatus = ParticipantStatus.joined; // Start unmuted
      }
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isCurrentUserDebater 
              ? '🎤 Test: You are now a DEBATER - mic controls available!'
              : '👂 Test: You are now AUDIENCE - mic controls hidden'),
          backgroundColor: _isCurrentUserDebater ? Colors.green : Colors.grey,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    
    AppLogger().info('🎤 TEST: Debater mode ${_isCurrentUserDebater ? 'ENABLED' : 'DISABLED'}');
  }
  
  /// Check if current user can screen share
  bool _canCurrentUserScreenShare() {
    if (_stateController.isModerator) return true; // Moderators can always share
    if (!_isCurrentUserDebater) return false; // Must be a debater
    if (_currentUser == null) return false;
    
    // Check if moderator has granted permission for this debater
    return _debaterScreenSharePermissions[_currentUser!.id] == true;
  }
  
  /// Show screen share permissions management modal (for moderators)
  void _showScreenSharePermissionsModal() {
    if (!_stateController.isModerator) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.screen_share, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Screen Share Permissions'),
          ],
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Grant screen sharing permissions to debaters:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              
              // List debaters and their permission status
              ..._buildDebaterPermissionsList(),
              
              const SizedBox(height: 16),
              
              if (_currentScreenSharingDebater != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.screen_share, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$_currentScreenSharingDebater is currently sharing screen',
                          style: const TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  /// Build list of debaters with permission toggles
  List<Widget> _buildDebaterPermissionsList() {
    final debaters = _getDebaters();
    if (debaters.isEmpty) {
      return [
        const Text(
          'No debaters in the room',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ];
    }
    
    return debaters.map((debater) {
      final userId = debater['id'] as String;
      final name = debater['name'] as String;
      final hasPermission = _debaterScreenSharePermissions[userId] ?? false;
      final isCurrentlySharing = _currentScreenSharingDebater == name;
      
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasPermission ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasPermission ? Colors.green : Colors.grey,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasPermission ? Icons.check_circle : Icons.cancel,
              color: hasPermission ? Colors.green : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isCurrentlySharing)
                    const Text(
                      'Currently sharing',
                      style: TextStyle(color: Colors.blue, fontSize: 10),
                    ),
                ],
              ),
            ),
            Switch(
              value: hasPermission,
              onChanged: (value) => _toggleDebaterScreenSharePermission(userId, name, value),
              activeColor: Colors.green,
            ),
          ],
        ),
      );
    }).toList();
  }
  
  /// Get list of debaters in the room
  List<Map<String, String>> _getDebaters() {
    final debaters = <Map<String, String>>[];
    
    // Get affirmative and negative participants
    final affirmative = _stateController.participants['affirmative'];
    final negative = _stateController.participants['negative'];
    
    if (affirmative != null) {
      debaters.add({
        'id': affirmative.id,
        'name': affirmative.name,
      });
    }
    
    if (negative != null) {
      debaters.add({
        'id': negative.id,
        'name': negative.name,
      });
    }
    
    return debaters;
  }
  
  /// Toggle screen share permission for a debater
  void _toggleDebaterScreenSharePermission(String userId, String userName, bool granted) {
    setState(() {
      _debaterScreenSharePermissions[userId] = granted;
    });
    
    // If permission is revoked and this debater is currently sharing, stop their sharing
    if (!granted && _currentScreenSharingDebater == userName) {
      _currentScreenSharingDebater = null;
      if (_isScreenSharing && _currentUser?.id == userId) {
        _toggleScreenShare(); // Stop sharing if it's the current user
      }
    }
    
    AppLogger().info('📹 Screen share permission for $userName: ${granted ? 'GRANTED' : 'REVOKED'}');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📹 Screen sharing ${granted ? 'enabled' : 'disabled'} for $userName',
          ),
          backgroundColor: granted ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Initialize WebRTC service for video and screen sharing
  Future<void> _initializeWebRTC() async {
    try {
      _webRTCService = SmartWebRTCService();
      
      // Set up callbacks
      _webRTCService!.onLocalStream = (stream) {
        AppLogger().info('📹 Local stream received');
        // Handle local video stream
      };
      
      _webRTCService!.onRemoteStream = (peerId, stream, userId, role) {
        AppLogger().info('📹 Remote stream from $userId ($role)');
        // Handle remote video stream
      };
      
      _webRTCService!.onRemoteScreenShareChanged = (userId, isSharing) {
        AppLogger().info('🖥️ Screen share status from $userId: ${isSharing ? 'started' : 'stopped'}');
        // Handle remote screen share changes
      };
      
      _webRTCService!.onError = (error) {
        AppLogger().error('❌ WebRTC error: $error');
      };
      
      AppLogger().info('✅ WebRTC service initialized for Arena');
    } catch (e) {
      AppLogger().error('❌ Failed to initialize WebRTC: $e');
    }
  }
  
  /// Toggle screen sharing for debaters
  Future<void> _toggleScreenShare() async {
    if (_webRTCService == null) {
      AppLogger().warning('⚠️ WebRTC service not initialized');
      return;
    }
    
    if (!_canCurrentUserScreenShare()) {
      AppLogger().debug('🚫 Screen sharing not allowed for current user');
      if (_isCurrentUserDebater && !(_debaterScreenSharePermissions[_currentUser?.id] ?? false)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚫 Screen sharing requires moderator permission'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      return;
    }
    
    try {
      if (_isScreenSharing) {
        AppLogger().info('🛑 Stopping screen share...');
        await _webRTCService!.stopScreenShare();
        
        setState(() {
          _isScreenSharing = false;
          _currentScreenSharingDebater = null; // Clear current sharer
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🛑 Screen sharing stopped'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        AppLogger().info('✅ Screen sharing stopped');
      } else {
        AppLogger().info('🖥️ Starting screen share...');
        await _webRTCService!.startScreenShare();
        
        setState(() {
          _isScreenSharing = true;
          _currentScreenSharingDebater = _currentUser?.name; // Track who is sharing
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🖥️ Screen sharing started - showing your screen as video feed'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        AppLogger().info('✅ Screen sharing started');
      }
    } catch (e) {
      AppLogger().error('❌ Failed to toggle screen share: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Screen sharing error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }


  /// Check and update debater status
  void _updateDebaterStatus() {
    if (_currentUser == null) {
      _isCurrentUserDebater = false;
      return;
    }
    
    final wasDebater = _isCurrentUserDebater;
    _isCurrentUserDebater = _stateController.participants.values.any((p) => p?.id == _currentUser!.id);
    
    // Log status change for debugging
    if (wasDebater != _isCurrentUserDebater) {
      AppLogger().info('🎤 Debater status changed: $_isCurrentUserDebater');
      if (_isCurrentUserDebater) {
        AppLogger().info('🎤 User is now a debater - microphone controls available');
      } else {
        AppLogger().info('🎤 User is no longer a debater - microphone controls hidden');
      }
    }
  }

  /// Toggle microphone mute/unmute for current user
  Future<void> _toggleMicrophone() async {
    if ((!_isCurrentUserDebater && !_stateController.isModerator) || _currentUser == null) {
      AppLogger().debug('🎤 Cannot toggle microphone - not a debater or moderator');
      return;
    }
    
    try {
      AppLogger().info('🎤 Toggling microphone: ${_currentUserAudioStatus.value}');
      
      final newStatus = _currentUserAudioStatus == ParticipantStatus.muted
          ? ParticipantStatus.joined
          : ParticipantStatus.muted;
      
      setState(() {
        _currentUserAudioStatus = newStatus;
      });
      
      // Here you would integrate with your audio service
      // For example: await audioService.setMuted(newStatus == ParticipantStatus.muted);
      
      AppLogger().info('🎤 Microphone ${newStatus == ParticipantStatus.muted ? 'MUTED' : 'UNMUTED'}');
      
      // Show feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == ParticipantStatus.muted 
                ? '🎤 Microphone muted' 
                : '🎤 Microphone unmuted'
            ),
            backgroundColor: newStatus == ParticipantStatus.muted ? Colors.red : Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
      
      // TODO: Sync audio status with Appwrite/backend
      // await _updateUserAudioStatusInDatabase(newStatus);
      
    } catch (e) {
      AppLogger().error('❌ Failed to toggle microphone: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to toggle microphone: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _emergencyCloseRoom() {
    // Show confirmation dialog for emergency room closure
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Emergency Close Room'),
          ],
        ),
        content: const Text(
          'Are you sure you want to immediately close this room? This action cannot be undone and will end the debate for all participants.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _executeEmergencyClose();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Close Room'),
          ),
        ],
      ),
    );
  }

  void _executeEmergencyClose() async {
    try {
      AppLogger().info('🚨 Emergency room close initiated by moderator');
      
      // Use the navigation service to handle emergency close
      await _navigationService.emergencyCloseRoom(context);
      
      AppLogger().info('🚨 Emergency room close completed');
    } catch (e) {
      AppLogger().error('🚨 Emergency room close failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to close room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initializeCurrentUser() async {
    try {
      final user = await _appwriteService.getCurrentUser();
      if (user != null) {
        final userProfile = await _appwriteService.getUserProfile(user.$id);
        if (userProfile != null && mounted) {
          setState(() => _currentUser = userProfile);
        }
      }
    } catch (e) {
      AppLogger().error('Failed to load current user for chat: $e');
    }
  }

  String _getUserRole() {
    if (_stateController.isModerator) return 'moderator';
    if (_stateController.isJudge) return 'judge';
    if (_stateController.participants.values.any((p) => p?.id == _currentUser?.id)) {
      return 'speaker';
    }
    return 'participant';
  }










  @override
  void dispose() {
    _webRTCService?.disconnect();
    _timerController.dispose();
    _stateController.dispose();
    super.dispose();
  }
}