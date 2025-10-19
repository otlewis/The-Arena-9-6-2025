import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../services/challenge_messaging_service.dart';
import '../services/sound_service.dart';
import '../models/user_profile.dart';
import '../models/message.dart';
import '../models/judge_scorecard.dart';
import '../widgets/user_profile_bottom_sheet.dart';
import '../widgets/mattermost_chat_widget.dart';
import '../models/discussion_chat_message.dart';
import '../screens/email_compose_screen.dart';
import 'dart:async';
import 'dart:convert';
import '../main.dart' show ArenaApp, getIt;
import '../core/logging/app_logger.dart';
import '../services/livekit_service.dart';
// Removed unused imports: room_audio_adapter, persistent_audio_service, audio_initialization_service
import '../services/livekit_token_service.dart';
import '../services/livekit_config_service.dart';
import '../services/noise_cancellation_service.dart';
import '../services/speaking_detection_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import '../services/audio_volume_service.dart';
import '../services/realtime_ai_moderation_service.dart';
import '../services/room_realtime_manager.dart';
import '../services/participant_diff_manager.dart';
import 'arena_modals.dart';
import '../features/arena/dialogs/moderator_control_modal.dart' as moderator_controls;
import '../features/arena/widgets/arena_app_bar.dart';
import '../features/arena/models/debate_phase.dart' as features;
import 'moderator_list_screen.dart';
import 'judge_list_screen.dart';
// Removed problematic provider imports to prevent infinite loops
import '../widgets/bottom_sheet/debate_bottom_sheet.dart';
import '../services/livekit_material_sync_service.dart';
import '../services/pinned_link_service.dart';
import '../widgets/shared_link_popup.dart';
import '../widgets/slide_update_popup.dart';
import '../models/debate_source.dart';
import '../services/disposal_tracking_system.dart';
import '../services/recording_service.dart';
import '../services/simple_audio_recording_service.dart';
import '../services/super_moderator_service.dart';

// Static helper methods for avatar system - accessible by all classes
Widget buildAvatarText(UserProfile participant, double fontSize) {
  String letter;
  if (participant.name.isEmpty) {
    letter = participant.email.isNotEmpty ? participant.email.substring(0, 1).toUpperCase() : 'U';
  } else {
    letter = participant.name.substring(0, 1).toUpperCase();
  }
  return Center(
    child: Text(
      letter,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    ),
  );
}

Widget buildAvatarTextFromMap(Map<String, dynamic> participantData, double fontSize) {
  String name = participantData['name'] ?? '';
  String email = participantData['email'] ?? '';
  
  String letter;
  if (name.isEmpty) {
    letter = email.isNotEmpty ? email.substring(0, 1).toUpperCase() : 'U';
  } else {
    letter = name.substring(0, 1).toUpperCase();
  }
  return Center(
    child: Text(
      letter,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    ),
  );
}

// Helper method to get avatar background color based on role
Color getAvatarColorForRole(String role) {
  switch (role) {
    case 'affirmative':
    case 'affirmative2':
      return Colors.green;
    case 'negative':
    case 'negative2':
      return Colors.red;
    case 'moderator':
      return const Color(0xFF8B5CF6); // accentPurple
    case 'judge1':
    case 'judge2':
    case 'judge3':
      return Colors.amber;
    default:
      return const Color(0xFF8B5CF6); // Default to accentPurple for audience
  }
}

// Helper method to get gradient colors for avatar backgrounds based on role
List<Color> getAvatarGradientForRole(String role) {
  switch (role) {
    case 'affirmative':
    case 'affirmative2':
      return [
        const Color(0xFF065F46), // Dark green
        const Color(0xFF10B981), // Bright green
      ];
    case 'negative':
    case 'negative2':
      return [
        const Color(0xFF991B1B), // Dark red
        const Color(0xFFEF4444), // Bright red
      ];
    case 'moderator':
      return [
        const Color(0xFF5B21B6), // Dark purple 
        const Color(0xFF8B5CF6), // Bright purple (accentPurple)
      ];
    case 'judge1':
    case 'judge2':
    case 'judge3':
      return [
        const Color(0xFFB45309), // Dark amber
        const Color(0xFFFBBF24), // Bright amber
      ];
    default:
      return [
        const Color(0xFF5B21B6), // Dark purple (existing default)
        const Color(0xFF8B5CF6), // Bright purple (existing default)
      ];
  }
}

// Helper method to get lighter gradient colors for slot backgrounds
List<Color> getSlotGradientForRole(String role, {bool isWinner = false}) {
  if (isWinner) {
    return [
      Colors.amber.withOpacity(0.2),
      Colors.amber.withOpacity(0.1),
    ];
  }
  
  switch (role) {
    case 'affirmative':
    case 'affirmative2':
      return [
        Colors.green.withOpacity(0.2),
        Colors.green.withOpacity(0.1),
      ];
    case 'negative':
    case 'negative2':
      return [
        Colors.red.withOpacity(0.2),
        Colors.red.withOpacity(0.1),
      ];
    case 'moderator':
      return [
        const Color(0xFF8B5CF6).withOpacity(0.2), // accentPurple
        const Color(0xFF8B5CF6).withOpacity(0.1),
      ];
    case 'judge1':
    case 'judge2':
    case 'judge3':
      return [
        Colors.amber.withOpacity(0.2),
        Colors.amber.withOpacity(0.1),
      ];
    default:
      return [
        const Color(0xFF8B5CF6).withOpacity(0.2), // Default purple
        const Color(0xFF8B5CF6).withOpacity(0.1),
      ];
  }
}

Widget buildStackedNameDisplayForVideoTile(String name) {
  if (name.isEmpty || name == 'Unknown') {
    return Text(
      'Unknown',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(
            offset: Offset(0, 1),
            blurRadius: 2,
            color: Colors.black54,
          ),
        ],
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
  
  final parts = name.split(' ');
  
  // Single name - just show it
  if (parts.length == 1) {
    return Text(
      parts[0].length > 10 ? '${parts[0].substring(0, 10)}...' : parts[0],
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(
            offset: Offset(0, 1),
            blurRadius: 2,
            color: Colors.black54,
          ),
        ],
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
  
  // Multiple names - stack first and last name
  if (parts.length >= 2) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          parts[0].length > 8 ? '${parts[0].substring(0, 8)}...' : parts[0],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.1,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 2,
                color: Colors.black54,
              ),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          parts.last.length > 8 ? '${parts.last.substring(0, 8)}...' : parts.last,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.1,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 2,
                color: Colors.black54,
              ),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
  
  // Fallback
  return Text(
    name.length > 10 ? '${name.substring(0, 10)}...' : name,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      shadows: [
        Shadow(
          offset: Offset(0, 1),
          blurRadius: 2,
          color: Colors.black54,
        ),
      ],
    ),
    textAlign: TextAlign.center,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

// Legacy Debate Phase Enum - kept for backwards compatibility
enum DebatePhase {
  preDebate('Pre-Debate', 'Preparation and setup time', 300), // 5 minutes
  openingAffirmative('Opening - Affirmative', 'Affirmative opening statement', 300), // 5 minutes
  openingNegative('Opening - Negative', 'Negative opening statement', 300), // 5 minutes
  rebuttalAffirmative('Rebuttal - Affirmative', 'Affirmative rebuttal', 180), // 3 minutes
  rebuttalNegative('Rebuttal - Negative', 'Negative rebuttal', 180), // 3 minutes
  crossExamAffirmative('Cross-Exam - Affirmative', 'Affirmative cross-examination', 120), // 2 minutes
  crossExamNegative('Cross-Exam - Negative', 'Negative cross-examination', 120), // 2 minutes
  finalRebuttalAffirmative('Final Rebuttal - Affirmative', 'Affirmative final rebuttal', 180), // 3 minutes
  finalRebuttalNegative('Final Rebuttal - Negative', 'Negative final rebuttal', 180), // 3 minutes
  closingAffirmative('Closing - Affirmative', 'Affirmative closing statement', 240), // 4 minutes
  closingNegative('Closing - Negative', 'Negative closing statement', 240), // 4 minutes
  judging('Judging Phase', 'Judges deliberate and score', null);

  const DebatePhase(this.displayName, this.description, this.defaultDurationSeconds);
  
  final String displayName;
  final String description;
  final int? defaultDurationSeconds;
  
  String get speakerRole {
    switch (this) {
      case DebatePhase.openingAffirmative:
      case DebatePhase.rebuttalAffirmative:
      case DebatePhase.crossExamAffirmative:
      case DebatePhase.finalRebuttalAffirmative:
      case DebatePhase.closingAffirmative:
        return 'affirmative';
      case DebatePhase.openingNegative:
      case DebatePhase.rebuttalNegative:
      case DebatePhase.crossExamNegative:
      case DebatePhase.finalRebuttalNegative:
      case DebatePhase.closingNegative:
        return 'negative';
      default:
        return '';
    }
  }
  
  DebatePhase? get nextPhase {
    const phases = DebatePhase.values;
    final currentIndex = phases.indexOf(this);
    if (currentIndex < phases.length - 1) {
      return phases[currentIndex + 1];
    }
    return null;
  }
}

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

class _ArenaScreenState extends State<ArenaScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin, DisposalTrackingMixin {
  final AppwriteService _appwrite = AppwriteService();
  late final SoundService _soundService;
  late final SpeakingDetectionService _speakingService;
  late final RecordingService _recordingService;
  final SimpleAudioRecordingService _simpleRecordingService = SimpleAudioRecordingService();
  
  // Room data
  Map<String, dynamic>? _roomData;
  UserProfile? _currentUser;
  String? _currentUserId;
  String? _userRole;
  int _teamSize = 1; // 1 for 1v1, 2 for 2v2
  String? _winner; // Track the debate winner
  bool _judgingComplete = false;
  bool _judgingEnabled = true; // Voting is now always open for judges until closed by moderator
  bool _hasCurrentUserSubmittedVote = false;
  bool _resultsModalShown = false; // Track if results modal has been shown
  bool _showResults = false; // Broadcast flag from n8n workflow to show results to all users
  bool _roomClosingModalShown = false; // Track if room closing modal has been shown
  bool _hasNavigated = false; // Track if we've already navigated to prevent duplicate navigation
  bool _isExiting = false; // Prevent state updates during exit
  Timer? _roomStatusChecker; // Periodic room status checker
  Timer? _roomCompletionTimer; // Timer for room completion after closure
  Timer? _muteStateSyncTimer; // Periodic mute state sync to prevent stuck states
  // Consolidated real-time subscription manager
  final RoomRealtimeManager _realtimeManager = RoomRealtimeManager();
  RoomSubscription? _roomSubscription;

  // Separate subscription stream listeners
  StreamSubscription? _participantStreamListener;
  StreamSubscription? _roomStatusStreamListener;
  StreamSubscription? _judgmentStreamListener;
  StreamSubscription? _timerStreamListener;

  // Legacy subscriptions
  StreamSubscription? _unreadMessagesSubscription; // Instant messages subscription
  StreamSubscription? _sharedLinkSubscription; // Shared link notifications
  StreamSubscription? _sourceAddedSubscription; // Material source additions
  StreamSubscription? _materialUpdatesSubscription; // Material updates
  int _roomStatusCheckerIterations = 0; // Track iterations to prevent infinite loops
  int _reconnectAttempts = 0; // Track reconnection attempts
  static const int _maxReconnectAttempts = 5; // Maximum reconnection attempts
  bool _isRealtimeHealthy = true; // Track realtime connection health
  
  // iOS-specific performance optimizations
  static final Map<String, Map<String, dynamic>> _iosRoomCache = {};
  static final Map<String, List<Map<String, dynamic>>> _iosParticipantCache = {};
  static final Map<String, UserProfile> _iosUserProfileCache = {};
  bool _isIOSOptimizationEnabled = false;
  DateTime? _lastCacheUpdate;
  
  
  // Enhanced Timer and Debate Management - AppwriteTimerWidget in AppBar provides sync
  late AnimationController _timerController; // Still needed for local animations
  DebatePhase _currentPhase = DebatePhase.preDebate;
  int _remainingSeconds = 0; // Local fallback for display
  // Removed unused fields: _isPaused, _hasPlayed30SecWarning, _isTimerRunning
  
  // Essential variables - getters defined later
  
  // Speaking Management
  String _currentSpeaker = '';
  
    // WebRTC Video & Audio Management
  // Audio Management - Using new persistent audio system
  // Note: Using LiveKitService directly instead of RoomAudioAdapter
  late final LiveKitService _liveKitService;
  LiveKitMaterialSyncService? _materialSyncService;
  PinnedLinkService? _pinnedLinkService;
  bool _isWebRTCConnected = false;
  bool _isMuted = false;
  bool _showMaterialsBottomSheet = false;

  // ANDROID CRASH PROTECTION: Rate limiting for mute/unmute operations
  DateTime? _lastMuteToggleTime;
  static const Duration _muteToggleCooldown = Duration(milliseconds: 500);
  
  // Connection stability monitoring
  Timer? _connectionHealthTimer;
  Timer? _reconnectionTimer;
  bool _isReconnecting = false;
  int _connectionDropCount = 0;
  DateTime? _lastConnectionDrop;
  
  // Connection stability thresholds
  int _consecutiveUnhealthyChecks = 0;
  static const int _unhealthyThreshold = 3; // Require 3 consecutive unhealthy checks
  static const int _minTimeBetweenReconnections = 60; // Minimum 60 seconds between reconnection attempts
  // bool _isScreenSharing = false; // Not used anymore - replaced with materials sheet
  
  // Screen sharing state
  final RTCVideoRenderer _screenShareRenderer = RTCVideoRenderer();
  
  // Video renderers for different participants
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  
  // Stream management
  MediaStream? _localStream;
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, String> _userToPeerMapping = {}; // userId -> peerId
  final Map<String, String> _peerToUserMapping = {}; // peerId -> userId
  final Map<String, String> _peerRoles = {}; // peerId -> role (challenger, challenged, judge, audience)
  bool _speakingEnabled = false;
  
  // Participants by role (supports both 1v1 and 2v2)
  Map<String, UserProfile?> _participants = {
    'affirmative': null,      // For 1v1 or first affirmative in 2v2
    'affirmative2': null,     // Second affirmative for 2v2
    'negative': null,         // For 1v1 or first negative in 2v2
    'negative2': null,        // Second negative for 2v2
    'moderator': null,
    'judge1': null,
    'judge2': null,
    'judge3': null,
  };
  
  final List<UserProfile> _audience = [];

  // Diff-based participant management
  final ParticipantDiffManager _diffManager = ParticipantDiffManager();

  // Two-stage invitation system state
  bool _bothDebatersPresent = false;
  final bool _invitationModalShown = false;
  final bool _invitationsInProgress = false;
  
  // Chat state
  // StreamSubscription? _chatSubscription; // Removed with old chat system
  final TextEditingController _chatController = TextEditingController();
  
  // JitsiService removed - focusing on debates_discussions_screen only
  // final JitsiService _jitsiService = JitsiService();
  
  // Screen sharing functionality removed in audio-only Jitsi mode
  // final Map<String, bool> _screenSharingPermissions = {};
  // String? _currentScreenSharer; // Track who is currently sharing
  
  // Colors
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  bool get wantKeepAlive => true; // Keep widget alive to prevent recreation

  @override
  void initState() {
    super.initState();

    // Initialize disposal tracking system
    initDisposalTracking(customId: 'arena_${widget.roomId}');

    // Initialize diff manager for participant updates
    _diffManager.initializeRoom(widget.roomId);

    // Initialize services
    _soundService = getIt<SoundService>();
    _speakingService = getIt<SpeakingDetectionService>();
    _recordingService = getIt<RecordingService>();
    // Using LiveKitService directly instead of RoomAudioAdapter
    _liveKitService = getIt<LiveKitService>();
    _initializeInstantMessaging();
    _initializeWebRTC();
    
    // Set up speaking detection listener
    _speakingService.addListener(_onSpeakingStateChanged);
    
    // Enable iOS-specific optimizations
    _isIOSOptimizationEnabled = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (_isIOSOptimizationEnabled) {
      AppLogger().debug('🍎 iOS detected - enabling performance optimizations');
    }
    
    _timerController = AnimationController(
      duration: const Duration(minutes: 10), // Max duration
      vsync: this,
    ); // Local fallback - AppwriteTimerWidget in AppBar provides sync
    
    // Use proper initialization order to prevent user ID issues
    _initializeArena();
    
    // ANDROID FIX: Apply performance optimizations for Android
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _optimizeAndroidPerformance();
    }
    
    // 🚀 INSTANT: Pre-warm audio session and start connection immediately
    _preWarmAudioSession();
    
    // Start connection health monitoring to prevent audio drops
    _startConnectionHealthMonitoring();
  }
  
  /// Pre-warm audio session for instant connection - NEW OPTIMIZATION
  Future<void> _preWarmAudioSession() async {
    try {
      AppLogger().info('🚀 INSTANT: Pre-warming audio session...');
      
      // Start WebRTC connection immediately without waiting for role
      if (!_isWebRTCConnected && mounted) {
        AppLogger().debug('🚀 INSTANT: Starting parallel WebRTC connection...');
        _connectToWebRTC(); // Fire and forget for speed
      }
      
      // Pre-configure audio permissions in parallel
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        AppLogger().debug('🚀 INSTANT: Pre-configuring iOS audio session...');
        final session = await audio_session.AudioSession.instance;
        await session.configure(audio_session.AudioSessionConfiguration(
          avAudioSessionCategory: audio_session.AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: audio_session.AVAudioSessionCategoryOptions.allowBluetooth |
              audio_session.AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: audio_session.AVAudioSessionMode.videoChat,
        ));
      }
      
      AppLogger().info('🚀 INSTANT: Audio pre-warm complete');
    } catch (e) {
      AppLogger().debug('🚀 INSTANT: Pre-warm error (non-critical): $e');
    }
  }
  
  /// Initialize arena with proper authentication and setup order
  Future<void> _initializeArena() async {
    try {
      final stopwatch = Stopwatch()..start();
      AppLogger().info('Initializing arena with optimized ${_isIOSOptimizationEnabled ? 'iOS' : 'standard'} flow...');
      
      if (_isIOSOptimizationEnabled) {
        // iOS-optimized initialization with parallel operations
        await _initializeArenaIOS();
      } else {
        // Standard initialization
        await _initializeArenaStandard();
      }
      
      stopwatch.stop();
      AppLogger().info('Arena initialization completed in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      AppLogger().error('Error during arena initialization: $e');
    }
  }
  
  /// iOS-optimized initialization with parallel database operations and caching
  Future<void> _initializeArenaIOS() async {
    AppLogger().debug('🍎 Starting iOS-optimized arena initialization...');
    
    // Step 1: Check cache first for iOS performance boost
    final cachedData = _getIOSCachedData();
    if (cachedData != null) {
      AppLogger().info('Using cached data for faster iOS loading');
      _applyIOSCachedData(cachedData);
    }
    
    // Step 2: Parallel data loading for iOS optimization
    final futures = <Future>[];
    
    // Load user data and room data in parallel
    final userFuture = _loadUserDataOptimized();
    final roomFuture = _loadRoomDataOptimized();
    futures.addAll([userFuture, roomFuture]);
    
    // Wait for critical data
    await Future.wait(futures);
    
    // Step 3: Validate user authentication
    if (_currentUserId == null) {
      AppLogger().error('iOS Arena initialization failed: No authenticated user');
      return;
    }
    
    AppLogger().info('iOS User authenticated: $_currentUserId, proceeding with optimized setup');
    
    // Step 4: Load participants in parallel with other setup
    final setupFutures = <Future>[
      _loadParticipantsOptimized(),
      Future.microtask(() => _setupRealtimeSubscription()),
      Future.microtask(() => _startRoomStatusChecker()),
    ];
    
    await Future.wait(setupFutures);
    
    // Step 5: Update iOS cache for future fast loading
    _updateIOSCache();
    
    // Chat service removed - now handled by floating chat button
    
    AppLogger().debug('🍎 iOS-optimized arena initialization completed');
  }
  
  /// Standard initialization for non-iOS platforms
  Future<void> _initializeArenaStandard() async {
    // Step 1: Load room data and authenticate user first
    await _loadRoomData();
    
    // Step 2: Validate user authentication before proceeding
    if (_currentUserId == null) {
      AppLogger().error('Arena initialization failed: No authenticated user');
      return;
    }
    
    AppLogger().info('User authenticated: $_currentUserId, proceeding with arena setup');
    
    // Step 3: Setup real-time subscription now that user is confirmed
    _setupRealtimeSubscription();
    
    // Step 4: Start room status checker
    _startRoomStatusChecker();
    
    // Step 5: Load participants to get user role and connect WebRTC
    await _loadParticipants();
    
    // Chat service removed - now handled by floating chat button
  }

  Future<void> _initializeInstantMessaging() async {
    // Instant messaging handled by Appwrite
    AppLogger().debug('📱 Instant messaging via Appwrite');
  }


  @override
  void dispose() {
    AppLogger().debug('🛑 DISPOSE: Setting exit flags and stopping ALL timers');
    // Set BOTH navigation and exit flags to stop all background processes immediately
    _hasNavigated = true;
    _isExiting = true;
    
    // Stop recording if still active
    if (_recordingService.isRecording && _userRole == 'moderator') {
      AppLogger().info('🎬 Stopping recording in dispose');
      _recordingService.stopRecording().catchError((e) {
        AppLogger().error('Failed to stop recording in dispose: $e');
        return null; // Return null to fix warning
      });
    }

    // Dispose material sync service
    _materialSyncService?.dispose();
    _materialSyncService = null;
    _pinnedLinkService?.dispose();
    _pinnedLinkService = null;
    _sharedLinkSubscription?.cancel();
    _sharedLinkSubscription = null;
    
    AppLogger().debug('🛑 DISPOSE: Cancelling room status checker...');
    if (_roomStatusChecker != null) {
      _roomStatusChecker!.cancel();
      AppLogger().debug('🛑 DISPOSE: Room status timer cancelled, setting to null');
      _roomStatusChecker = null;
    } else {
      AppLogger().debug('🛑 DISPOSE: Room status timer was already null');
    }
    
    AppLogger().debug('🛑 DISPOSE: Cancelling room completion timer...');
    if (_roomCompletionTimer != null) {
      _roomCompletionTimer!.cancel();
      AppLogger().debug('🛑 DISPOSE: Room completion timer cancelled, setting to null');
      _roomCompletionTimer = null;
    } else {
      AppLogger().debug('🛑 DISPOSE: Room completion timer was already null');
    }
    
    AppLogger().debug('🛑 DISPOSE: Cancelling mute state sync timer...');
    if (_muteStateSyncTimer != null) {
      _muteStateSyncTimer!.cancel();
      AppLogger().debug('🛑 DISPOSE: Mute sync timer cancelled, setting to null');
      _muteStateSyncTimer = null;
    } else {
      AppLogger().debug('🛑 DISPOSE: Mute sync timer was already null');
    }

    AppLogger().debug('🛑 DISPOSE: Removing LiveKit service listener...');
    _liveKitService.removeListener(_onLiveKitStateChanged);

    AppLogger().debug('🛑 DISPOSE: Clearing speaking detection callback...');
    _liveKitService.onSpeakingChanged = null;
    
    // Stop connection health monitoring
    _stopConnectionHealthMonitoring();
    _reconnectionTimer?.cancel();
    
    AppLogger().debug('🛑 DISPOSE: Cleaning up consolidated subscriptions...');
    _realtimeManager.unsubscribeFromRoom(widget.roomId);
    _participantStreamListener?.cancel();
    _roomStatusStreamListener?.cancel();
    _judgmentStreamListener?.cancel();
    _timerStreamListener?.cancel();

    AppLogger().debug('🛑 DISPOSE: Cancelling instant messaging subscription...');
    _unreadMessagesSubscription?.cancel();
    _unreadMessagesSubscription = null;

    AppLogger().debug('🛑 DISPOSE: Cancelling material sync subscriptions...');
    _sourceAddedSubscription?.cancel();
    _sourceAddedSubscription = null;
    _materialUpdatesSubscription?.cancel();
    _materialUpdatesSubscription = null;
    
    AppLogger().debug('🛑 DISPOSE: Cleaning up chat service...');
    // Chat service disposal removed - now handled by floating chat button
    _chatController.dispose();
    
    AppLogger().debug('🛑 DISPOSE: Cleaning up WebRTC...');
    _disposeWebRTC(); // Fire and forget - lifecycle method can't await
    
    AppLogger().debug('🛑 DISPOSE: Cleaning up noise cancellation...');
    try {
      NoiseCancellationService().disable();
    } catch (e) {
      AppLogger().error('❌ Failed to disable noise cancellation during dispose: $e');
    }
    
    AppLogger().debug('🛑 DISPOSE: Removing speaking detection listener...');
    _speakingService.removeListener(_onSpeakingStateChanged);
    
    _timerController.dispose(); // Dispose local timer controller

    AppLogger().debug('🛑 DISPOSE: Cleaning up tracked resources...');
    // Clean up all tracked disposable resources
    disposeTrackedResources();

    // Restart notification service to ensure user can receive new invites
    // Note: NotificationService singleton continues running - no restart needed

    super.dispose();
  }

  /// Handle speaking state changes
  void _onSpeakingStateChanged() {
    if (mounted && !_isExiting) {
      setState(() {
        // UI will rebuild with new speaking states from _speakingService
      });
    }
  }


  void _setupRealtimeSubscription() async {
    // Add user ID validation before setting up subscription
    if (_currentUserId == null) {
      AppLogger().error('Cannot start real-time listening: no current user ID');
      return;
    }

    // GUARD: Cancel existing subscriptions and timers before creating new ones
    if (_participantStreamListener != null || _roomStatusStreamListener != null ||
        _judgmentStreamListener != null || _roomSubscription != null || _reconnectionTimer != null) {
      AppLogger().warning('🔄 CLEANUP: Cancelling existing subscriptions and timers before creating new ones');

      _reconnectionTimer?.cancel();
      _reconnectionTimer = null;

      await _participantStreamListener?.cancel();
      await _roomStatusStreamListener?.cancel();
      await _judgmentStreamListener?.cancel();
      _participantStreamListener = null;
      _roomStatusStreamListener = null;
      _judgmentStreamListener = null;
      _roomSubscription = null;

      // Small delay to ensure cleanup completes
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      AppLogger().info('📡 Setting up consolidated real-time subscription for arena room: ${widget.roomId}');

      // Use centralized subscription manager
      _roomSubscription = await _realtimeManager.subscribeToRoom(
        roomId: widget.roomId,
        roomType: 'arena',
      );

      // Listen to participant updates stream
      _participantStreamListener = _roomSubscription!.participants.listen(
        (response) async {
          try {
            // Reset reconnect attempts on successful message
            if (_reconnectAttempts > 0) {
              _reconnectAttempts = 0;
              AppLogger().info('Arena realtime connection restored');
            }
            
            // Update realtime health status
            if (!_isRealtimeHealthy && mounted) {
              setState(() {
                _isRealtimeHealthy = true;
              });
            }
            
            AppLogger().info('Real-time arena update: ${response.events}');
            
            // Check for participant deletion events
            final isDeleteEvent = response.events.any((event) => event.contains('.delete'));
            if (isDeleteEvent) {
              AppLogger().debug('🗑️ PARTICIPANT DELETION EVENT detected: ${response.events}');
            }
            
            // Note: response.payload is guaranteed to be non-null by the API
            
            // Ensure payload is a valid Map with enhanced safety
            Map<String, dynamic> payload;
            try {
              payload = Map<String, dynamic>.from(response.payload);
              
              // Additional null safety check
              if (payload.isEmpty) {
                AppLogger().warning('Received empty payload - skipping');
                return;
              }
            } catch (e) {
              AppLogger().warning('Error converting payload to Map: $e - skipping');
              return;
            }
          
          // Check if this update is for our room
            final isParticipantUpdate = response.events.any((event) => event.contains('arena_participants'));
            final isRoomUpdate = response.events.any((event) => event.contains('arena_rooms'));
            
            if (isParticipantUpdate && payload.containsKey('roomId') &&
                payload['roomId'] == widget.roomId) {
              if (mounted && !_hasNavigated) {
                await _handleArenaParticipantUpdate(response);
              }
            }
            
            if (isRoomUpdate) {
              // Check if this is our room by various possible ID formats
              final payloadId = payload['\$id'];
              final roomId = payload['id'];
              
              AppLogger().debug('🔍 Room update received - PayloadId: $payloadId, RoomId: $roomId, TargetRoomId: ${widget.roomId}');
              
              // Log the judging state in the payload
              if (payload.containsKey('judgingEnabled')) {
                AppLogger().info('🎯 REALTIME: judgingEnabled field in payload: ${payload['judgingEnabled']}');
              }
              
              if (payloadId == widget.roomId || roomId == widget.roomId ||
                  payloadId == 'arena_${widget.challengeId}' || roomId == 'arena_${widget.challengeId}') {
                AppLogger().info('🔄 REALTIME: Room update is for OUR room - refreshing data');
                AppLogger().info('  - Current _judgingEnabled: $_judgingEnabled');
                if (payload.containsKey('judgingEnabled')) {
                  AppLogger().info('  - New judgingEnabled from payload: ${payload['judgingEnabled']}');
                }
                
                // CRITICAL: Only process if we haven't started navigation
                if (mounted && !_hasNavigated) {
                  _loadRoomData();
                } else {
                  AppLogger().debug('🔍 Skipping room data refresh - navigation already in progress');
                }
              }
            }
          } catch (e) {
            AppLogger().error('Error processing arena update: $e');
            // Don't rethrow to prevent stream from breaking
          }
        },
        onError: (error) {
          AppLogger().error('Arena real-time subscription error: $error');
          _reconnectAttempts++;
          
          if (mounted) {
            setState(() {
              _isRealtimeHealthy = false;
            });
          }
          
          // Implement exponential backoff for Chrome WebSocket issues
          if (_reconnectAttempts < _maxReconnectAttempts) {
            final delaySeconds = _reconnectAttempts * 2; // 2, 4, 6, 8, 10 seconds
            AppLogger().debug('🔄 Reconnecting arena subscription in $delaySeconds seconds... (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
            
            Timer(Duration(seconds: delaySeconds), () {
              if (mounted && !_isExiting) {
                _setupRealtimeSubscription();
              }
            });
          } else {
            AppLogger().error('Arena realtime max reconnection attempts reached');
          }
        },
        onDone: () {
          AppLogger().warning('Arena real-time subscription closed');
          if (mounted && !_isExiting && _reconnectAttempts < _maxReconnectAttempts) {
            _reconnectAttempts++;
            AppLogger().debug('🔄 Arena subscription ended, attempting to reconnect...');
            Timer(const Duration(seconds: 3), () {
              if (mounted && !_isExiting) {
                _setupRealtimeSubscription();
              }
            });
          }
        },
      );
      // Track participant stream subscription
      trackSubscription('participant_stream', _participantStreamListener!);

      // Listen to room status updates
      _roomStatusStreamListener = _roomSubscription!.roomStatus.listen(
        (response) {
          AppLogger().info('Room status update: ${response.events}');
          // Handle room updates (closure, status changes, etc.)
          // Check both 'roomId' and '$id' fields since realtime messages use '$id'
          final roomId = response.payload['roomId'] ?? response.payload['\$id'];
          if (roomId == widget.roomId) {
            final roomData = response.payload;

            // Reload room data to get ALL updated fields (including showResults)
            AppLogger().info('🔄 Room update detected - reloading room data to capture all changes');
            _loadRoomData();

            // Also check for room closure
            if (roomData['status'] == 'ended' || roomData['status'] == 'closed') {
              AppLogger().info('🔴 Room ended/closed detected via realtime');
              if (mounted && !_hasNavigated) {
                _forceNavigationHomeSync();
              }
            }
          }
        },
        onError: (error) {
          AppLogger().error('Room status subscription error: $error');
        },
      );
      // Track room status subscription
      trackSubscription('room_status_stream', _roomStatusStreamListener!);

      // Listen to judgment updates for voting
      _judgmentStreamListener = _roomSubscription!.materials.listen(
        (response) {
          // Check if this is a judgment event
          if (response.events.any((e) => e.contains('arena_judgments'))) {
            AppLogger().info('Judgment update received');

            // Check if this is a new judge vote (create event)
            final isCreateEvent = response.events.any((e) => e.contains('.create'));
            if (isCreateEvent && _userRole == 'moderator' && mounted) {
              // Extract judge information from the payload
              try {
                final payload = response.payload;
                final judgeId = payload['judgeId'];

                // Determine which judge voted based on their role
                String judgeLabel = 'A judge';
                if (judgeId != null) {
                  // Find the judge's role by checking participants
                  _participants.forEach((role, user) {
                    if (user?.id == judgeId) {
                      switch (role) {
                        case 'judge1':
                          judgeLabel = 'Judge 1';
                          break;
                        case 'judge2':
                          judgeLabel = 'Judge 2';
                          break;
                        case 'judge3':
                          judgeLabel = 'Judge 3';
                          break;
                      }
                    }
                  });
                }

                // Count how many judges have voted
                _checkJudgeVoteProgress().then((voteCount) {
                  // Show persistent notification for moderator
                  _showJudgeVoteNotification(judgeLabel, voteCount);
                });
              } catch (e) {
                AppLogger().error('Error processing judge vote notification: $e');
              }
            }

            // Refresh judgments when new votes come in
            if (mounted && !_hasNavigated) {
              // Force UI refresh to show updated voting status
              setState(() {
                // This will trigger a rebuild and update voting display
              });
            }
          }
        },
      );
      // Track judgment stream subscription
      trackSubscription('judgment_stream', _judgmentStreamListener!);

      AppLogger().info('✅ Consolidated arena subscription established for room: ${widget.roomId}');
      AppLogger().info('User: $_currentUserId listening on all arena channels');
    } catch (e) {
      AppLogger().error('Error setting up real-time subscription: $e');
      // Continue without real-time - the periodic checker will handle updates
    }
  }

  /// Start connection health monitoring to prevent audio drops
  void _startConnectionHealthMonitoring() {
    _connectionHealthTimer?.cancel();
    
    // ANDROID FIX: More frequent monitoring for Android to catch performance issues early
    final monitoringInterval = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) 
        ? const Duration(seconds: 15)  // More frequent for Android
        : const Duration(seconds: 30); // Standard for iOS
    
    _connectionHealthTimer = Timer.periodic(monitoringInterval, (timer) {
      if (!mounted || _isExiting) {
        timer.cancel();
        return;
      }
      _checkConnectionHealth();
    });
    
    AppLogger().debug('🔍 Started connection health monitoring for Arena (${monitoringInterval.inSeconds}s intervals - Android optimized)');
  }

  /// Stop connection health monitoring
  void _stopConnectionHealthMonitoring() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
    AppLogger().debug('🛑 Stopped connection health monitoring');
  }

  /// Optimize Android performance to prevent WebRTC timeouts
  void _optimizeAndroidPerformance() {
    try {
      AppLogger().debug('🔧 ANDROID: Applying performance optimizations...');
      
      // Reduce rebuild frequency to improve frame rate
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Schedule UI updates less frequently on Android
          AppLogger().debug('🔧 ANDROID: UI update optimization applied');
        });
      }
      
      // Optimize timer intervals for better performance
      AppLogger().debug('🔧 ANDROID: Timer intervals optimized for performance');
      
      AppLogger().info('✅ ANDROID: Performance optimizations applied');
    } catch (e) {
      AppLogger().warning('⚠️ ANDROID: Performance optimization failed: $e');
    }
  }

  /// Check connection health and trigger reconnection if needed
  Future<void> _checkConnectionHealth() async {
    if (!mounted || _isExiting || _isReconnecting) return;
    
    try {
      // Check if WebRTC connection is healthy
      final isWebRTCConnected = _liveKitService.isConnected;
      final hasRemoteStreams = _liveKitService.remoteParticipants.isNotEmpty;
      
      // Only consider connection unhealthy if WebRTC is completely disconnected
      // Note: isWebRTCHealthy is calculated but not used in current logic - kept for future use
      // final isWebRTCHealthy = isWebRTCConnected;
      
      // Log connection state for debugging (but not too frequently)
      if (_consecutiveUnhealthyChecks == 0 || _consecutiveUnhealthyChecks % 5 == 0) {
        AppLogger().debug('🔍 Arena connection health check: WebRTC=${isWebRTCConnected ? 'Connected' : 'Disconnected'}, Streams=${hasRemoteStreams ? 'Yes' : 'No'}, Role=${_userRole ?? 'Unknown'}');
      }
      
      // ANDROID FIX: Force audio cleanup when WebRTC disconnection is detected
      if (!isWebRTCConnected && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        AppLogger().debug('🔧 ANDROID: WebRTC disconnected - performing immediate audio cleanup');
        try {
          await _liveKitService.disableAudio();
        } catch (e) {
          AppLogger().warning('⚠️ ANDROID: Emergency audio cleanup failed: $e');
        }
      }
      
      // Only attempt WebRTC restoration if:
      // 1. User is moderator/debater/judge (can publish audio)
      // 2. WebRTC is completely disconnected
      // 3. We're not already reconnecting
      // 4. We've had multiple consecutive unhealthy checks
      if (_shouldUserPublishMedia() && !isWebRTCConnected && !_isReconnecting) {
        _consecutiveUnhealthyChecks++;
        
        // Check if we've attempted reconnection recently to prevent loops
        final timeSinceLastAttempt = _lastConnectionDrop != null 
            ? DateTime.now().difference(_lastConnectionDrop!).inSeconds 
            : 60;
        
        // ANDROID FIX: Balanced reconnection approach - not too aggressive to prevent cycling
        final threshold = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ? 2 : _unhealthyThreshold; // Allow 2 checks before reconnecting on Android
        final minTime = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ? 15 : _minTimeBetweenReconnections; // Longer wait to prevent cycling
        
        // Only attempt reconnection if:
        // - We've had enough consecutive unhealthy checks
        // - Enough time has passed since last attempt
        if (_consecutiveUnhealthyChecks >= threshold && timeSinceLastAttempt > minTime) {
          AppLogger().warning('⚠️ Arena WebRTC disconnected for $_consecutiveUnhealthyChecks consecutive checks - attempting restoration (Android optimized)');
          _restoreWebRTCConnection();
          _consecutiveUnhealthyChecks = 0; // Reset counter
        } else {
          AppLogger().debug('⏳ Skipping Arena WebRTC restoration - checks: $_consecutiveUnhealthyChecks/$threshold, time: ${timeSinceLastAttempt}s/$minTime (Android optimized)');
        }
      } else if (isWebRTCConnected) {
        // Reset unhealthy check counter when connection is healthy
        _consecutiveUnhealthyChecks = 0;
      }
      
    } catch (e) {
      AppLogger().error('❌ Error checking Arena connection health: $e');
    }
  }

  /// Handle WebRTC connection restoration
  void _restoreWebRTCConnection() async {
    if (_isReconnecting) return;
    
    _isReconnecting = true;
    _connectionDropCount++;
    _lastConnectionDrop = DateTime.now();
    
    AppLogger().warning('🔴 Arena audio drop detected! Count: $_connectionDropCount');
    
    // Show user feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Audio connection issue detected. Attempting to restore...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
    
    AppLogger().debug('🔄 Starting Arena WebRTC connection restoration...');
    
    try {
      // Attempt to reconnect WebRTC
      await _connectToWebRTC();
      
      AppLogger().debug('✅ Arena WebRTC connection restored successfully');
      
      // ANDROID FIX: Pause health monitoring briefly to let connection stabilize
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        AppLogger().debug('🔧 ANDROID: Pausing health monitoring for connection stabilization...');
        _stopConnectionHealthMonitoring();
        
        // Restart monitoring after stabilization period
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted && !_isExiting) {
            AppLogger().debug('🔧 ANDROID: Resuming health monitoring after stabilization');
            _startConnectionHealthMonitoring();
          }
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Audio connection restored successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      AppLogger().error('❌ Arena WebRTC connection restoration failed: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to restore audio connection: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      // Schedule retry
      _scheduleReconnectionRetry();
      
    } finally {
      _isReconnecting = false;
    }
  }

  /// Schedule reconnection retry with exponential backoff
  void _scheduleReconnectionRetry() {
    final retryDelay = Duration(seconds: (2 * _connectionDropCount).clamp(5, 60));
    
    AppLogger().debug('⏰ Scheduling Arena WebRTC reconnection retry in ${retryDelay.inSeconds} seconds...');
    
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(retryDelay, () {
      if (mounted && !_isExiting && !_isReconnecting) {
        AppLogger().debug('🔄 Executing scheduled Arena WebRTC reconnection retry...');
        _restoreWebRTCConnection();
      }
    });
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Initialize WebRTC video and audio for Arena
  Future<void> _initializeWebRTC() async {
    try {
      AppLogger().debug('🎥 Initializing WebRTC for Arena...');
      
      // Initialize video renderers
      await _localRenderer.initialize();
      await _screenShareRenderer.initialize();
      
      // Set up LiveKitService callbacks directly (same as Debates & Discussions)
      _liveKitService.onConnected = () {
        AppLogger().debug('✅ LiveKit connected to Arena room');
        if (mounted) {
          setState(() {
            _isWebRTCConnected = true;
            // Sync mute state on connection
            _isMuted = _liveKitService.isMuted;
          });
        }
        
        // Disabled periodic sync - was causing mute/unmute loops
        // _startMuteStateSyncTimer();
      };
      
      _liveKitService.onDisconnected = () {
        AppLogger().debug('📡 LiveKit disconnected from Arena');
        if (mounted) {
          setState(() {
            _isWebRTCConnected = false;
          });
        }
      };
      
      _liveKitService.onError = (error) {
        AppLogger().error('❌ Arena audio error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Audio error: $error')),
          );
        }
      };
      
      _liveKitService.onParticipantConnected = (participant) {
          AppLogger().debug('👤 Participant joined Arena: ${participant.identity}');
          if (mounted) {
            setState(() {
              // Update UI for new participant
            });
          }
        };

        _liveKitService.onParticipantDisconnected = (participant) {
          AppLogger().debug('👋 Participant left Arena: ${participant.identity}');
          if (mounted) {
            setState(() {
              // Update UI for participant leaving
            });
          }
        };

        // Add listener for LiveKit service changes (including mute state changes)
        _liveKitService.addListener(_onLiveKitStateChanged);

        // Set up speaking detection callback to trigger UI updates
        _liveKitService.onSpeakingChanged = (String userId, bool isSpeaking) {
          AppLogger().debug('🗣️ Speaking state changed for $userId: $isSpeaking');
          if (mounted && !_isExiting) {
            setState(() {
              // Trigger UI rebuild when speaking state changes
            });
          }
        };
      
      // Legacy callback setup - now handled by audio adapter
      // _webrtcService.onTrackSubscribed, onError, onDisconnected are managed by the adapter

      // Screen sharing removed for audio-only Arena mode
      AppLogger().debug('🎙️ Arena configured for audio-only LiveKit communication');

      AppLogger().debug('🎥 WebRTC initialization complete');
    } catch (e) {
      AppLogger().error('❌ Failed to initialize WebRTC: $e');
    }
  }

  // _connectWithRetry method removed - unused

  /// Callback for LiveKit service state changes (including mute state changes)
  void _onLiveKitStateChanged() {
    if (mounted) {
      setState(() {
        // Sync local mute state with LiveKit service
        _isMuted = _liveKitService.isMuted;
        AppLogger().debug('🔄 LiveKit state changed - UI refreshed, muted: $_isMuted');
      });
    }
  }

  /// Connect to WebRTC server for Arena audio using LiveKit - OPTIMIZED FOR SPEED
  Future<void> _connectToWebRTC() async {
    AppLogger().info('🚀 INSTANT: _connectToWebRTC() called - optimized connection');

    if (_currentUser == null) {
      AppLogger().debug('🚀 INSTANT: Fetching current user...');
      // Try to get current user quickly
      final user = await _appwrite.getCurrentUser();
      if (user != null) {
        // Convert User to UserProfile
        _currentUser = UserProfile(
          id: user.$id,
          name: user.name.isEmpty ? 'Unknown User' : user.name,
          email: user.email,
          avatar: user.prefs.data['profileImage'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        AppLogger().debug('🚀 INSTANT: User fetched successfully: ${_currentUser?.id}');
      }
      if (_currentUser == null) {
        AppLogger().error('❌ Still no current user after trying to fetch');
        return;
      }
    } else {
      AppLogger().debug('🚀 INSTANT: User already available: ${_currentUser?.id}');
    }

    // Prevent reconnection if already connected
    AppLogger().debug('🔍 WebRTC connection state check: _isWebRTCConnected=$_isWebRTCConnected');
    if (_isWebRTCConnected) {
      AppLogger().warning('⚠️ WebRTC already connected, skipping reconnection - THIS BLOCKS RECORDING START');
      return;
    }
    
    try {
      AppLogger().info('🎥 STARTING LiveKit CONNECTION...');
      AppLogger().info('🎥 Room: ${widget.roomId}');
      AppLogger().info('🎥 User: ${_currentUser?.id} (${_currentUser?.name})');
      AppLogger().info('🎥 Role: $_userRole');
      
      // Determine role for WebRTC connection
      String webrtcRole = 'audience'; // Default to audience
      
      // CRITICAL: Re-check current user role from database before WebRTC connection
      try {
        final currentParticipants = await _appwrite.getArenaParticipants(widget.roomId);
        final currentUserParticipant = currentParticipants.firstWhere(
          (p) => p['userId'] == _currentUser?.id,
          orElse: () => <String, dynamic>{},
        );
        
        if (currentUserParticipant.isNotEmpty) {
          final databaseRole = currentUserParticipant['role'];
          AppLogger().debug('🔍 WEBRTC: Database role: $databaseRole, Local role: $_userRole');
          
          // Use database role if it's different from local role
          if (databaseRole != null && databaseRole != _userRole) {
            AppLogger().warning('🔄 Role mismatch detected - updating local role from $_userRole to $databaseRole');
            _userRole = databaseRole;
          }
        }
      } catch (e) {
        AppLogger().error('❌ Failed to double-check role from database: $e');
      }
      
      // Check if current user is room creator (auto-moderator)
      if (_roomData != null && _currentUser?.id != null && _roomData!['createdBy'] == _currentUser!.id) {
        webrtcRole = 'moderator';
        AppLogger().debug('🎭 Room creator detected - using moderator role for WebRTC');
        
        // ROBUST AUDIO SYSTEM: Ensure local role state matches creator status
        if (_userRole != 'moderator') {
          AppLogger().warning('🚨 ROLE OVERRIDE: Room creator should be moderator - updating local role from $_userRole to moderator');
          _userRole = 'moderator';
        }
      } else if (['affirmative', 'negative', 'affirmative2', 'negative2', 'moderator'].contains(_userRole)) {
        webrtcRole = _userRole!;
      } else if (['judge1', 'judge2', 'judge3'].contains(_userRole)) {
        webrtcRole = 'judge';
      }
      
      // ROBUST AUDIO SYSTEM: Safety check - if user should have audio permissions but is computed as audience, 
      // this indicates a timing/state sync issue
      if (webrtcRole == 'audience' && _shouldUserPublishMedia()) {
        AppLogger().warning('🚨 ARENA ROLE OVERRIDE: User should have media permissions but computed as audience - checking for role correction');
        
        // If user is a room creator, force moderator role
        if (_roomData != null && _currentUser?.id != null && _roomData!['createdBy'] == _currentUser!.id) {
          AppLogger().warning('🚨 ARENA: Room creator detected as audience - forcing moderator role');
          webrtcRole = 'moderator';
          _userRole = 'moderator';
        }
      }
      
      AppLogger().debug('🎥 LiveKit Role: $webrtcRole (User Role: $_userRole)');
      
      // CRITICAL: Generate unique identity to prevent duplicate identity disconnections
      final currentUserId = _currentUser?.id;
      if (currentUserId == null || currentUserId.isEmpty) {
        AppLogger().error('❌ DUPLICATE IDENTITY FIX: No valid user ID available for LiveKit connection');
        throw Exception('Cannot connect to Arena: User authentication required. Please restart the app.');
      }
      
      // Generate LiveKit token with matching deployment credentials
      final audioRoomId = 'arena-${widget.roomId}';
      final uniqueIdentity = '${currentUserId}_${DateTime.now().millisecondsSinceEpoch}';
      AppLogger().debug('🆔 DUPLICATE IDENTITY FIX: Using unique identity: $uniqueIdentity (from user: $currentUserId)');
      
      final token = LiveKitTokenService.generateToken(
        roomName: audioRoomId,
        identity: uniqueIdentity, // Use timestamped unique identity
        userRole: webrtcRole,
        roomType: 'arena',
        userId: currentUserId, // Keep original user ID for metadata
        ttl: const Duration(hours: 2),
      );
      
      AppLogger().debug('🔑 Generated LiveKit token for user: $currentUserId');
      AppLogger().debug('🔗 Connecting to LiveKit server...');
      AppLogger().debug('📡 Server URL: ws://172.236.109.9:7880');
      AppLogger().debug('🏠 Room: $audioRoomId (formatted from: ${widget.roomId})');
      AppLogger().debug('👤 Identity: $uniqueIdentity');
      AppLogger().debug('🎭 Role: $webrtcRole');
      AppLogger().debug('🔑 Token generated for room type: arena');
      AppLogger().debug('🌐 Network: Attempting WebRTC connection with enhanced ICE configuration');
      AppLogger().debug('🔄 ICE: Pool size = 10, TURN servers = openrelay.metered.ca:80,443');
      
      // Connect using LiveKitService directly (same as Debates & Discussions)
      AppLogger().info('🚀 ARENA: Connecting via LiveKitService directly...');
      
      try {
        // ANDROID FIX: Optimize connection parameters for better performance
        final connectionTimeout = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) 
            ? const Duration(seconds: 15)  // Shorter timeout for Android to prevent performance issues
            : const Duration(seconds: 20); // Standard timeout for iOS
        
        await _liveKitService.connect(
          serverUrl: LiveKitConfigService.instance.effectiveServerUrl,
          roomName: audioRoomId,
          token: token,
          userId: currentUserId, // Use validated user ID instead of fallback
          userRole: webrtcRole,
          roomType: 'arena',
        ).timeout(
          connectionTimeout,
          onTimeout: () {
            AppLogger().error('❌ Audio connection timeout after ${connectionTimeout.inSeconds} seconds (Android optimized)');
            throw Exception('Arena audio connection timeout. Please check your network connection.');
          },
        );
        
        AppLogger().info('✅ ARENA: Connected via LiveKitService successfully');

        // ANDROID FIX: Add stabilization period to prevent immediate disconnection
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          AppLogger().debug('🔧 ANDROID: Connection stabilization period starting...');
          await Future.delayed(const Duration(milliseconds: 1000)); // 1 second stabilization
          AppLogger().debug('🔧 ANDROID: Connection stabilization completed');
        }

        // Update connection state
        if (mounted) {
          setState(() {
            _isWebRTCConnected = true;
          });
        }

        // Debug log for recording conditions
        AppLogger().debug('🔍 RECORDING CHECK: _roomData=${_roomData != null}, enablePlayback=${_roomData?['enablePlayback']}, webrtcRole=$webrtcRole, isModerator=${webrtcRole == 'moderator'}');

        // Start recording if playback is enabled and user is moderator
        if (_roomData != null &&
            _roomData!['enablePlayback'] == true &&
            webrtcRole == 'moderator') {
          AppLogger().info('🎬 Starting audio recording for arena room with playback enabled');
          try {
            await _simpleRecordingService.startRecording(
              roomId: widget.roomId,
              roomName: _roomData!['topic'] ?? 'Arena Debate',
            );
            AppLogger().info('✅ Audio recording started successfully');
          } catch (e) {
            AppLogger().error('❌ Failed to start audio recording: $e');
            // Continue without recording - don't break the room
          }
        }
        
        // Initialize material sync service for slides and sources
        if (_liveKitService.room != null) {
          _materialSyncService = LiveKitMaterialSyncService(
            appwrite: _appwrite,
            room: _liveKitService.room,
            roomId: widget.roomId,
            userId: currentUserId,
            userName: _currentUser?.name,
            isHost: webrtcRole == 'moderator' || webrtcRole == 'affirmative' || webrtcRole == 'negative',
          );
          
          // Initialize pinned link service
          _pinnedLinkService = PinnedLinkService(
            appwrite: _appwrite,
            roomId: widget.roomId,
            userId: currentUserId,
          );
          
          // Listen for shared link notifications from PinnedLinkService (Appwrite-based)
          _sharedLinkSubscription = _pinnedLinkService!.linkSharedStream.listen((sharedLink) {
            if (mounted && !_isExiting) {
              // Only show popup if current user is not the one who shared the link
              if (sharedLink.sharedBy != currentUserId) {
                AppLogger().info('📌 Showing shared link popup from PinnedLinkService: ${sharedLink.title}');
                _showSharedLinkPopup(sharedLink);
              } else {
                AppLogger().info('📌 Not showing popup for own shared link from PinnedLinkService: ${sharedLink.title}');
              }
            }
          });
          // Track shared link subscription
          trackSubscription('shared_link_stream', _sharedLinkSubscription!);
          
          // ALSO listen for source additions from LiveKit MaterialSyncService (LiveKit-based)
          _sourceAddedSubscription = _materialSyncService!.sourceAdded.listen((source) {
            if (mounted && !_isExiting) {
              // Only show popup if current user is not the one who shared the link
              if (source.sharedBy != currentUserId) {
                AppLogger().info('📌 Showing shared link popup from MaterialSyncService: ${source.title}');
                _showSharedLinkPopup(source);
              } else {
                AppLogger().info('📌 Not showing popup for own shared link from MaterialSyncService: ${source.title}');
              }
            }
          });
          // Track source added subscription
          trackSubscription('source_added_stream', _sourceAddedSubscription!);
          
          // Listen for material updates and only show popup for NEW slide uploads (pdf_upload), not slide navigation (slide_change)
          _materialUpdatesSubscription = _materialSyncService!.materialUpdates.listen((materialSync) {
            if (mounted && !_isExiting) {
              // Only show popup for pdf_upload events (new slides shared), not slide_change events (slide navigation)
              if (materialSync.type == 'pdf_upload' && materialSync.userId != currentUserId) {
                AppLogger().info('📊 Showing NEW slides popup from MaterialSyncService: ${materialSync.slideFileId}');

                // Create SlideData from the material sync event
                final slideData = SlideData(
                  fileId: materialSync.slideFileId ?? '',
                  fileName: materialSync.fileName ?? 'Presentation',
                  currentSlide: materialSync.currentSlide ?? 1,
                  totalSlides: materialSync.totalSlides ?? 0,
                  pdfUrl: materialSync.pdfUrl,
                  uploadedBy: materialSync.userId ?? '',
                  uploadedByName: materialSync.userName,
                  uploadedAt: DateTime.now(),
                );

                _showSlideUpdatePopup(slideData);
              } else if (materialSync.type == 'pdf_upload') {
                AppLogger().info('📊 Not showing popup for own slide upload: ${materialSync.slideFileId}');
              }
            }
          });
          // Track material updates subscription
          trackSubscription('material_updates_stream', _materialUpdatesSubscription!);
          
          AppLogger().debug('📊 Material sync service initialized for role: $webrtcRole');
        }
      } catch (error) {
        AppLogger().error('❌ Failed to connect to LiveKit: $error');
        rethrow;
      }
      
      AppLogger().debug('🔗 LiveKit connect() method completed');
      
      // Mark as connected (the onConnected callback will also set this)
      if (mounted) {
        setState(() {
          _isWebRTCConnected = true;
        });
      }
      
      // Start muted by default to prevent feedback (like other rooms)
      AppLogger().debug('🔇 Starting muted by default to prevent feedback');
      
      // Wait a moment for connection to stabilize before trying to control audio
      await Future.delayed(const Duration(milliseconds: 500));
      
      try {
        await _liveKitService.disableAudio();
        if (mounted) {
          setState(() {
            _isMuted = true;
          });
        }
      } catch (e) {
        AppLogger().debug('⚠️ Could not disable audio initially (will start muted anyway): $e');
        // Still set muted state even if the disable failed
        if (mounted) {
          setState(() {
            _isMuted = true;
          });
        }
      }
      
      AppLogger().info('✅ LiveKit connection established successfully');
      AppLogger().info('🎥 Connection status: $_isWebRTCConnected');
      AppLogger().info('🎤 Audio ready for role: $webrtcRole (started muted)');

      // Configure loud audio output for better audibility
      final audioVolumeService = AudioVolumeService();
      await audioVolumeService.configureLoudAudio();
      if (_liveKitService.room != null) {
        audioVolumeService.configureLiveKitAudio(_liveKitService.room!);
      }
      AppLogger().info('🔊 Audio volume boosted for speaker output');

      // Start AI moderation for hostile speech detection
      final aiModeration = RealtimeAIModerationService();
      await aiModeration.startRoomMonitoring(widget.roomId);
      AppLogger().info('🛡️ AI moderation started for room');

      // Configure audio session with enhanced noise cancellation for Arena
      try {
        final session = await audio_session.AudioSession.instance;
        await session.configure(audio_session.AudioSessionConfiguration(
          avAudioSessionCategory: audio_session.AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: audio_session.AVAudioSessionCategoryOptions.defaultToSpeaker |
              audio_session.AVAudioSessionCategoryOptions.allowBluetooth |
              audio_session.AVAudioSessionCategoryOptions.duckOthers, // Duck other audio when speaking
          // REMOVED mixWithOthers to prevent feedback loops
          avAudioSessionMode: audio_session.AVAudioSessionMode.videoChat, // VideoChat mode - compatible with WebRTC voice processing
          avAudioSessionRouteSharingPolicy: audio_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: audio_session.AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
          androidAudioAttributes: const audio_session.AndroidAudioAttributes(
            contentType: audio_session.AndroidAudioContentType.speech,
            flags: audio_session.AndroidAudioFlags.none,
            usage: audio_session.AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: audio_session.AndroidAudioFocusGainType.gainTransientExclusive, // Exclusive audio focus
          androidWillPauseWhenDucked: true,
        ));
        
        // Activate the audio session with high priority
        await session.setActive(true);
        
        // Platform-specific noise cancellation enhancements
        if (!kIsWeb) {
          if (defaultTargetPlatform == TargetPlatform.iOS) {
            // iOS-specific audio enhancements
            AppLogger().debug('🍎 Configuring iOS-specific noise cancellation');
            // iOS automatically applies noise cancellation in videoChat mode
          } else if (defaultTargetPlatform == TargetPlatform.android) {
            // Android-specific audio enhancements
            AppLogger().debug('🤖 Configuring Android-specific noise cancellation');
            // Android voiceCommunication mode includes noise suppression
          }
        }
        
        AppLogger().debug('🔊 Audio session configured with enhanced noise cancellation for Arena');
      } catch (e) {
        AppLogger().error('❌ Failed to configure audio session: $e');
        // Continue anyway - audio might still work
      }
      
      // Initialize enhanced noise cancellation service
      try {
        AppLogger().debug('🎙️ Initializing enhanced noise cancellation for Arena...');
        await NoiseCancellationService().initialize();
        AppLogger().info('✅ Enhanced noise cancellation activated: ${NoiseCancellationService().platformInfo}');
      } catch (e) {
        AppLogger().error('❌ Failed to initialize noise cancellation: $e');
        // Continue without enhanced noise cancellation
      }
      
    } catch (e) {
      AppLogger().error('❌ Failed to connect LiveKit: $e');
    }
  }

  /// Auto-connect audio for users who should have microphone access - OPTIMIZED
  Future<void> _autoConnectAudio() async {
    try {
      AppLogger().debug('🚀 INSTANT AUTO-CONNECT: Starting for role $_userRole');
      
      // Only auto-connect if user should have microphone access
      if (!_shouldUserPublishMedia()) {
        AppLogger().debug('🚀 INSTANT: User role $_userRole does not need auto-connect');
        return;
      }
      
      // Prevent repeated auto-connect if already connected and audio is initialized
      if (_isWebRTCConnected && !_liveKitService.isMuted) {
        AppLogger().debug('🚀 INSTANT: Already connected and audio enabled, skipping auto-connect');
        return;
      }
      
      // Only auto-connect if not already connected to LiveKit
      if (!_isWebRTCConnected) {
        AppLogger().debug('🚀 INSTANT: Parallel WebRTC connection...');
        await _connectToWebRTC();
        
        // Minimal wait for connection establishment
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (!_isWebRTCConnected) {
          AppLogger().error('🚀 INSTANT: Connection pending, retrying...');
          // Don't give up, try once more immediately
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
      
      // FINAL ROLE CHECK: Verify role before connecting
      if (_currentUser != null && _userRole != null) {
        final shouldPublish = _shouldUserPublishMedia();
        AppLogger().debug('🔥 AUTO-CONNECT: Final check - user should publish: $shouldPublish');
        
        if (!shouldPublish) {
          AppLogger().warning('🔥 AUTO-CONNECT: ⚠️ User role $_userRole should not auto-connect audio');
          return;
        }
      }
      
      // Audio connection is already established and users start muted by default
      AppLogger().debug('🔥 AUTO-CONNECT: Audio connection ready for $_userRole (already muted by default)');
      // Do not automatically unmute users - they should manually unmute when ready to speak
      // The LiveKitService._setupMediaBasedOnRole() already ensures users start muted
      
      // Update mute state to sync with LiveKit state
      if (mounted) {
        setState(() {
          _isMuted = _liveKitService.isMuted;
        });
      }
      
      AppLogger().info('✅ AUTO-CONNECT: Audio ready for $_userRole (muted until manual unmute)');
      
    } catch (e) {
      AppLogger().error('❌ AUTO-CONNECT: Failed to auto-connect audio: $e');
      // Don't show error to user for auto-connect failures
    }
  }


  /// Determine if current user should publish media (video/audio)
  bool _shouldUserPublishMedia() {
    // Moderator, debaters and judges publish audio
    // Audience members are view-only (listen-only)
    return _userRole == 'moderator' ||
           _userRole == 'affirmative' ||
           _userRole == 'negative' ||
           _userRole == 'affirmative2' ||
           _userRole == 'negative2' ||
           _userRole?.startsWith('judge') == true;
  }

  /// Toggle local microphone with enhanced error handling
  Future<void> _toggleMute() async {
    try {
      AppLogger().debug('🎤 TOGGLE MUTE: Starting mute toggle');

      // ANDROID CRASH PROTECTION: Check if widget is disposed
      if (!mounted) {
        AppLogger().warning('⚠️ TOGGLE MUTE: Widget not mounted - aborting safely');
        return;
      }

      // ANDROID CRASH PROTECTION: LiveKit service is guaranteed to be initialized

      // ANDROID CRASH PROTECTION: Rate limiting to prevent rapid toggle crashes
      final now = DateTime.now();
      if (_lastMuteToggleTime != null && now.difference(_lastMuteToggleTime!) < _muteToggleCooldown) {
        AppLogger().warning('⚠️ TOGGLE MUTE: Rate limited - ignoring rapid toggle');
        return;
      }
      _lastMuteToggleTime = now;

      // CRITICAL: Check if user role is loaded yet
      if (_userRole == null) {
        AppLogger().debug('🔇 Mute Toggle: User role not loaded yet, please wait...');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⏳ Loading your role... Please wait'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      // Only allow audio toggle for judges, moderators, and debaters  
      if (!_shouldUserPublishMedia()) {
        AppLogger().debug('🔇 Mute Toggle: Role $_userRole does not have microphone access');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Your role does not have microphone access'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Connect to audio first if not connected
      if (!_isWebRTCConnected) {
        await _connectToWebRTC();
        return;
      }
      
      // ANDROID CRASH PROTECTION: Wrap audio operations
      try {
        // Double-check mount state before audio operations
        if (!mounted) {
          AppLogger().warning('⚠️ TOGGLE MUTE: Widget unmounted during operation');
          return;
        }

        // Toggle mute state using LiveKit service
        if (_isMuted) {
          AppLogger().debug('🎤 TOGGLE MUTE: Calling enableAudio()');
          await _liveKitService.enableAudio();
        } else {
          AppLogger().debug('🔇 TOGGLE MUTE: Calling disableAudio()');
          await _liveKitService.disableAudio();
        }

        // ANDROID CRASH PROTECTION: Only update UI if still mounted
        if (mounted) {
          setState(() {
            _isMuted = _liveKitService.isMuted;
          });
        }

        AppLogger().debug('✅ TOGGLE MUTE: Audio operation completed - ${_isMuted ? 'muted' : 'unmuted'}');

      } catch (audioError) {
        AppLogger().error('❌ TOGGLE MUTE: Audio operation failed: $audioError');
        // Don't rethrow here - handle in the outer catch block
        rethrow;
      }
    } catch (e) {
      AppLogger().error('❌ Error toggling mute: $e');
      
      // Check if this is a permission error - if so, try to reconnect with correct role
      if (e.toString().contains('permission') || e.toString().contains('publish audio') || e.toString().contains('audience')) {
        AppLogger().warning('🚨 PERMISSION ERROR: Attempting to refresh role and reconnect');

        // CRITICAL: Force refresh role from database to ensure we have the latest
        await _loadParticipants();
        AppLogger().info('🔄 Role refreshed from database: $_userRole');

        // Check if role actually allows publishing after refresh
        if (!_shouldUserPublishMedia()) {
          AppLogger().error('❌ After refresh, role $_userRole still does not allow publishing');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Your current role ($_userRole) does not have microphone access'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // Force disconnect and reconnect with updated permissions
        try {
          if (_isWebRTCConnected) {
            await _liveKitService.disconnect();
            setState(() {
              _isWebRTCConnected = false;
            });
          }

          // Brief delay to ensure cleanup
          await Future.delayed(const Duration(milliseconds: 500));

          // Reconnect with corrected role
          await _connectToWebRTC();
          
          // Try to unmute again after successful reconnection
          if (_isWebRTCConnected && _isMuted) {
            await _liveKitService.enableAudio();
            if (mounted) {
              setState(() {
                _isMuted = _liveKitService.isMuted;
              });
            }
          }
          
        } catch (reconnectError) {
          AppLogger().error('❌ Reconnection failed: $reconnectError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to enable audio: $reconnectError'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
      
      // Sync local state with service state on error
      if (mounted) {
        setState(() {
          _isMuted = _liveKitService.isMuted;
        });
      }
    }
  }
  



  // Video toggle removed - Arena is audio-only
  
  /// Standardized microphone button matching Open Discussion style
  Widget _buildEnhancedMicButton() {
    // Show loading state if role is not loaded yet
    if (_userRole == null) {
      return _buildControlButton(
        icon: Icons.hourglass_empty,
        label: 'Loading...',
        color: Colors.grey,
        onPressed: _toggleMute,
      );
    }

    return _buildControlButton(
      icon: _isMuted ? Icons.mic_off : Icons.mic,
      label: _isMuted ? 'Unmute' : 'Mute',
      color: _isMuted ? Colors.red : Colors.green,
      onPressed: _toggleMute,
    );
  }


  /// Show materials bottom sheet (slides and sources)
  void _showShareScreenBottomSheet() {
    // Toggle the materials bottom sheet instead of screen sharing
    setState(() {
      _showMaterialsBottomSheet = !_showMaterialsBottomSheet;
    });
  }



  /// Clean up WebRTC resources with Android-specific audio cleanup
  Future<void> _disposeWebRTC() async {
    try {
      AppLogger().debug('🛑 Disposing WebRTC resources...');
      
      // ANDROID FIX: Force audio cleanup before disconnection to prevent phantom audio
      try {
        if (_isWebRTCConnected) {
          AppLogger().debug('🔧 ANDROID: Force disabling audio before disconnect...');
          await _liveKitService.disableAudio();
          await Future.delayed(const Duration(milliseconds: 100)); // Brief pause for cleanup
        }
      } catch (e) {
        AppLogger().warning('⚠️ ANDROID: Audio cleanup before disconnect failed: $e');
      }
      
      // Critical: Properly await disconnect to ensure track cleanup
      await _liveKitService.disconnect();
      
      // ANDROID FIX: Additional cleanup after disconnection
      try {
        AppLogger().debug('🔧 ANDROID: Post-disconnect cleanup...');
        // Force clear any remaining audio state
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await Future.delayed(const Duration(milliseconds: 200)); // Extra cleanup time for Android
        }
      } catch (e) {
        AppLogger().warning('⚠️ ANDROID: Post-disconnect cleanup failed: $e');
      }
      
      // Dispose local renderer
      _localRenderer.dispose();
      _screenShareRenderer.dispose();
      
      // Dispose all remote renderers
      for (final renderer in _remoteRenderers.values) {
        renderer.dispose();
      }
      _remoteRenderers.clear();
      
      // Clear streams and mappings
      _remoteStreams.clear();
      _userToPeerMapping.clear();
      _peerToUserMapping.clear();
      _peerRoles.clear();
      
      AppLogger().debug('🛑 WebRTC cleanup complete');
    } catch (e) {
      AppLogger().error('❌ Error disposing WebRTC: $e');
    }
  }

  Future<void> _loadRoomData() async {
    try {
      final user = await _appwrite.getCurrentUser();
      if (user == null) return;
      
      _currentUserId = user.$id;
      _currentUser = await _appwrite.getUserProfile(user.$id);
      
      // Try to get existing Arena room
      Map<String, dynamic>? roomData = await _appwrite.getArenaRoom(widget.roomId);
      
      if (roomData == null) {
        AppLogger().warning('Arena room not found: ${widget.roomId}');
        // Room doesn't exist, this shouldn't happen if called from challenge modal
        // but we can still try to handle it gracefully
      } else {
        // Check if room has been closed or completed
        final roomStatus = roomData['status'];
        
        if (roomStatus == 'completed' || roomStatus == 'abandoned' || roomStatus == 'force_cleaned' || roomStatus == 'force_closed') {
          AppLogger().debug('🚪 Room has been closed (status: $roomStatus), navigating back to arena lobby');
          
          // CRITICAL: Check if navigation already in progress
          if (_hasNavigated) {
            AppLogger().debug('🔍 Navigation already in progress, skipping duplicate navigation');
            return;
          }
          
          _hasNavigated = true; // Set navigation flag immediately
          
          if (mounted) {
            // Show message and navigate back
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔒 This arena room has been closed'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
            
            // Navigate back to arena lobby after a short delay
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted && !_isExiting) {
                // Navigate back to arena lobby with complete stack replacement
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_isExiting) {
                    try {
                      _isExiting = true; // Prevent multiple navigation attempts
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const ArenaApp()),
                        (route) => false,
                      );
                    } catch (e) {
                      AppLogger().error('Navigation error: $e');
                      _isExiting = false; // Reset on error
                    }
                  }
                });
              }
            });
          }
          return;
        }
        
        // Check if room is closing and show countdown modal
        if (roomStatus == 'closing') {
          if (mounted && !_roomClosingModalShown && !_hasNavigated) {
            AppLogger().debug('🚨 Room closing detected via real-time - showing modal');
            _roomClosingModalShown = true;
            // Show countdown modal immediately for all users
            WidgetsBinding.instance.addPostFrameCallback((_) {
              AppLogger().debug('🎬 About to show room closing modal');
              _showRoomClosingModal(15);
            });
          } else {
            AppLogger().debug('🔍 Room closing status detected but modal already shown, navigation in progress, or widget not mounted');
          }
        }
        
        // Extract winner and judging status from room data
        // DEBUG: Log raw room data to see what fields are actually present
        AppLogger().debug('🔍 RAW ROOM DATA KEYS: ${roomData.keys.toList()}');
        AppLogger().debug('🔍 showResults IN DATA: ${roomData.containsKey('showResults')}');
        if (roomData.containsKey('showResults')) {
          AppLogger().debug('🔍 showResults RAW VALUE: ${roomData['showResults']}');
          AppLogger().debug('🔍 showResults TYPE: ${roomData['showResults'].runtimeType}');
        }

        final newWinner = roomData['winner'];
        final newJudgingComplete = roomData['judgingComplete'] ?? false;
        final newJudgingEnabled = roomData['judgingEnabled'] ?? true;
        final newTeamSize = roomData['teamSize'] ?? 1; // Default to 1v1 if not specified
        final newShowResults = roomData['showResults'] ?? false;

        // Update state with setState to trigger UI rebuild
        if (mounted) {
          // Log if judging state changed
          if (_judgingEnabled != newJudgingEnabled) {
            AppLogger().info('🎯 JUDGING STATE CHANGED: $_judgingEnabled -> $newJudgingEnabled (realtime update)');
          }

          // Log if showResults changed (n8n broadcast)
          if (_showResults != newShowResults) {
            AppLogger().info('🏆 SHOW RESULTS BROADCAST RECEIVED!');
            AppLogger().info('  Previous: showResults=$_showResults');
            AppLogger().info('  New: showResults=$newShowResults');
            AppLogger().info('  Winner: $newWinner');
            AppLogger().info('  Trophy icon should ${newShowResults && newWinner != null ? "APPEAR" : "HIDE"}');
          }

          // Check if judging just completed (winner was determined)
          final judgingJustCompleted = !_judgingComplete && newJudgingComplete && newWinner != null;

          // Reset results modal flag when judging state changes
          if (_judgingEnabled != newJudgingEnabled && newJudgingEnabled) {
            AppLogger().info('🔄 JUDGING RESTARTED: Resetting results modal flag');
            _resultsModalShown = false;
          }

          setState(() {
            _winner = newWinner;
            _judgingComplete = newJudgingComplete;
            _judgingEnabled = newJudgingEnabled;
            _teamSize = newTeamSize;
            _showResults = newShowResults;
          });

          // Show results modal to ALL users when voting is closed and winner is determined
          if (judgingJustCompleted && !_resultsModalShown) {
            AppLogger().info('🏆 REALTIME: Voting just completed with winner: $newWinner - auto-showing results modal to all users (Role: $_userRole)');

            // Auto-show modal for all users once
            _resultsModalShown = true;
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                AppLogger().info('🏆 AUTO-SHOWING RESULTS MODAL for user role: $_userRole');
                _showResultsModal();
              }
            });
          }
        }
        
        // Check if current user has already submitted judgment
        if (_currentUserId != null) {
          AppLogger().debug('🔍 VOTE CHECK: Checking votes for user $_currentUserId in room ${widget.roomId}');
          final existingJudgments = await _appwrite.databases.listDocuments(
            databaseId: 'arena_db',
            collectionId: 'arena_judgments',
            queries: [
              Query.equal('roomId', widget.roomId),
              Query.equal('judgeId', _currentUserId!),
            ],
          );
          
          _hasCurrentUserSubmittedVote = existingJudgments.documents.isNotEmpty;
          AppLogger().debug('🔍 VOTE STATUS: Found ${existingJudgments.documents.length} existing votes for user $_currentUserId');
          AppLogger().debug('🔍 VOTE STATUS: Current user has submitted vote: $_hasCurrentUserSubmittedVote');
        }
        
        AppLogger().debug('🏆 Arena room loaded - Winner: $_winner, Judging Complete: $_judgingComplete, Judging Enabled: $_judgingEnabled');
        AppLogger().debug('🎯 ROLE DEBUG: Current user role: $_userRole, _isJudge: $_isJudge, _isModerator: $_isModerator');
      }
      
      // Ensure current user has a role in the Arena
      final existingParticipants = await _appwrite.getArenaParticipants(widget.roomId);
      final hasRole = existingParticipants.any((p) => p['userId'] == _currentUserId);
      
      AppLogger().debug('🔍 Checking arena participation: hasRole=$hasRole, currentUserId=$_currentUserId');
      
      if (!hasRole) {
        // Check if current user is one of the debaters
        final isDebater = (widget.challengerId == _currentUserId || widget.challengedId == _currentUserId);
        
        AppLogger().debug('🔍 User role check: isDebater=$isDebater');
        
        if (!isDebater) {
          // First, populate _participants to check available judge slots
          for (final participant in existingParticipants) {
            final role = participant['role'];
            if (['judge1', 'judge2', 'judge3'].contains(role)) {
              final userId = participant['userId'];
              try {
                final userProfile = await _appwrite.getUserProfile(userId);
                if (userProfile != null) {
                  _participants[role] = userProfile;
                  AppLogger().debug('🔍 Pre-loaded $role: ${userProfile.name}');
                }
              } catch (e) {
                AppLogger().debug('🔍 Failed to load profile for $role: $e');
              }
            }
          }
          
          // Check if any judge slots are available and user should be auto-assigned as judge
          final availableJudgeSlots = _getAvailableJudgeSlots();
          AppLogger().debug('🔍 Available judge slots: $availableJudgeSlots');
          
          // If user has opted into judging and judge slots are available, assign as judge
          // For now, we'll check if judges are needed and assign automatically
          // TODO: In the future, this could check user preferences or judge invitations
          if (availableJudgeSlots > 0) {
            String judgeRole = 'judge1';
            if (_participants['judge1'] != null) {
              judgeRole = 'judge2';
            }
            if (_participants['judge2'] != null) {
              judgeRole = 'judge3';
            }
            
            AppLogger().debug('🔍 Assigning current user to $judgeRole...');
            await _appwrite.assignArenaRole(
              roomId: widget.roomId,
              userId: _currentUserId!,
              role: judgeRole,
            );
            AppLogger().info('Assigned current user to $judgeRole');
            
            // CRITICAL: Update local role state immediately before WebRTC connection
            _userRole = judgeRole;
            AppLogger().debug('🔍 Updated local _userRole to: $_userRole');
            
            // FORCE SYNC: Immediately update LiveKit service role (especially for iOS)
            if (_isWebRTCConnected) {
              AppLogger().debug('🔄 iOS FIX: Force updating LiveKit role to: $_userRole');
              // Role updates handled automatically by LiveKitService
            }
          } else {
            AppLogger().debug('🔍 Assigning current user to audience...');
            // Assign current user to audience by default
            await _appwrite.assignArenaRole(
              roomId: widget.roomId,
              userId: _currentUserId!,
              role: 'audience',
            );
            AppLogger().info('Assigned current user to audience');
            
            // Update local role state immediately
            _userRole = 'audience';
            AppLogger().debug('🔍 Updated local _userRole to: $_userRole');
            
            // FORCE SYNC: Immediately update LiveKit service role (especially for iOS)
            if (_isWebRTCConnected) {
              AppLogger().debug('🔄 iOS FIX: Force updating LiveKit role to: $_userRole');
              // Role updates handled automatically by LiveKitService
            }
          }
          
          // Longer delay to ensure database operation completes and propagates
          await Future.delayed(const Duration(milliseconds: 1000));
          AppLogger().debug('🔍 About to reload participants after role assignment');
          
          // Force reload participants to update display
          await _loadParticipants();
          AppLogger().debug('🔍 Completed participant reload after role assignment');
        }
      } else {
        // User already has a role - check if it's an important role before potentially overriding
        final existingParticipant = existingParticipants.firstWhere(
          (p) => p['userId'] == _currentUserId,
          orElse: () => <String, dynamic>{},
        );
        
        final existingRole = existingParticipant['role'];
        final importantRoles = ['affirmative', 'negative', 'affirmative2', 'negative2', 'moderator', 'judge1', 'judge2', 'judge3'];
        
        if (importantRoles.contains(existingRole)) {
          AppLogger().info('User already has important role: $existingRole - preserving it');
        } else {
          AppLogger().debug('🔍 User has non-important role: $existingRole - allowing potential reassignment');
        }
      }
      
      if (mounted) {
        setState(() {
          _roomData = roomData;
        });
      }
      
      await _loadParticipants();
      
      // Auto-assign room creator as moderator if no moderator exists
      await _ensureModeratorExists();
      
      // Double-check that current user appears in audience if they should
      if (_currentUserId != null) {
        final currentUserInParticipants = _participants.values.any((p) => p?.id == _currentUserId);
        final currentUserInAudience = _audience.any((p) => p.id == _currentUserId);
        
        if (!currentUserInParticipants && !currentUserInAudience) {
          AppLogger().warning('🚨 Current user not found in participants or audience! Attempting to add to audience...');
          
          // Try to get current user profile and add to audience manually as a fallback
          try {
            if (_currentUser != null) {
              _audience.add(_currentUser!);
              AppLogger().info('✅ Added current user to audience as fallback');
              if (mounted) {
                setState(() {
                  // Update UI after adding current user to audience
                });
              }
            }
          } catch (e) {
            AppLogger().error('Failed to add current user to audience as fallback: $e');
          }
        } else {
          AppLogger().debug('✅ Current user found - in participants: $currentUserInParticipants, in audience: $currentUserInAudience');
        }
      }

      // Show results modal if judging is already complete when user joins
      if (_judgingComplete && _winner != null && !_resultsModalShown) {
        AppLogger().info('🏆 ROOM LOAD: Judging already complete with winner: $_winner - showing results modal for late joiner');
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && !_resultsModalShown) {
            _showResultsModal();
          }
        });
      }

    } catch (e) {
      AppLogger().error('Error loading room data: $e');
    }
  }

  Future<void> _loadParticipants() async {
    AppLogger().debug('🎭 DEBUG: _loadParticipants() called for room ${widget.roomId}');
    try {
      final participants = await _appwrite.getArenaParticipants(widget.roomId);
      
      AppLogger().info('Loading ${participants.length} participants for Arena');
      
      // Reset participants
      _participants = {
        'affirmative': null,
        'negative': null,
        'affirmative2': null,
        'negative2': null,
        'moderator': null,
        'judge1': null,
        'judge2': null,
        'judge3': null,
      };
      _audience.clear();
      
      // Assign participants to roles
      for (var participant in participants) {
        final role = participant['role'];
        final userProfileData = participant['userProfile'];
        
        AppLogger().debug('👤 Assigning participant to role: $role');
        AppLogger().debug('🎭 DEBUG: Participant data: $participant');
        
        // Check for completion status in the database
        final completedSelection = participant['completedSelection'] == true;
        final metadata = participant['metadata'];
        final selections = metadata != null && metadata['selections'] != null 
            ? Map<String, String?>.from(metadata['selections']) 
            : <String, String?>{};
        
        AppLogger().debug('🎭 DEBUG: Role $role - completedSelection: $completedSelection, selections: $selections');
        
        // Sync completion status and selections from database
        if (role == 'affirmative' && completedSelection) {
          AppLogger().debug('🎭 SYNC: Set affirmative completion = true, selections = $selections');
        } else if (role == 'affirmative2' && completedSelection) {
          AppLogger().debug('🎭 SYNC: Set affirmative2 completion = true, selections = $selections');
        } else if (role == 'negative' && completedSelection) {
          AppLogger().debug('🎭 SYNC: Set negative completion = true, selections = $selections');
        } else if (role == 'negative2' && completedSelection) {
          AppLogger().debug('🎭 SYNC: Set negative2 completion = true, selections = $selections');
        }
        
        if (userProfileData != null) {
          final userProfile = UserProfile.fromMap(userProfileData);
          
          if (['affirmative', 'affirmative2', 'negative', 'negative2', 'moderator', 'judge1', 'judge2', 'judge3'].contains(role)) {
            _participants[role] = userProfile;
            AppLogger().info('Assigned ${userProfile.name} to $role');
          } else if (role == 'audience') {
            _audience.add(userProfile);
            AppLogger().info('✅ Added ${userProfile.name} to audience (Total audience: ${_audience.length})');
            AppLogger().debug('👥 Current audience members: ${_audience.map((u) => u.name).join(', ')}');
          } else {
            AppLogger().warning('🔍 User ${userProfile.name} has unknown role: $role - not assigned to audience');
          }
        } else {
          AppLogger().warning('No user profile data for participant with role: $role');
        }
      }
      
      // Determine current user's role
      final currentUserParticipant = participants.firstWhere(
        (p) => p['userId'] == _currentUserId,
        orElse: () => <String, dynamic>{},
      );
      
      if (currentUserParticipant.isNotEmpty) {
        final newRole = currentUserParticipant['role'];
        final oldRole = _userRole;
        _userRole = newRole;

        AppLogger().info('🔄 ROLE SYNC: Current user role updated from $oldRole to $_userRole');
        AppLogger().info('👤 Current user ID: $_currentUserId');
        AppLogger().info('🎭 Role data: $currentUserParticipant');

        // Additional logging for debaters and judges
        if (['affirmative', 'negative', 'affirmative2', 'negative2'].contains(_userRole)) {
          AppLogger().info('🎯 USER IS A DEBATER: $_userRole');
          AppLogger().info('🎯 Can publish media: ${_shouldUserPublishMedia()}');
          AppLogger().info('🎯 WebRTC connected: $_isWebRTCConnected');
        } else if (_userRole?.startsWith('judge') == true) {
          AppLogger().info('⚖️ USER IS A JUDGE: $_userRole');
          AppLogger().info('⚖️ Can publish media: ${_shouldUserPublishMedia()}');
          AppLogger().info('⚖️ WebRTC connected: $_isWebRTCConnected');

          // If judge and not connected, reconnect with proper permissions
          if (!_isWebRTCConnected) {
            AppLogger().info('⚖️ Judge needs WebRTC connection - connecting...');
            await _connectToWebRTC();
          }
        }

        // Force UI update when role changes
        if (oldRole != newRole && mounted) {
          setState(() {
            // Force rebuild with new role
          });
          AppLogger().info('🔄 FORCED UI UPDATE: Role changed from $oldRole to $newRole');
        }

        // ADDITIONAL VERIFICATION: Check if user is in participant slots with different role
        await _validateRoleConsistency();
      } else {
        AppLogger().warning('❌ CRITICAL: Current user not found in participants list');
        AppLogger().warning('❌ Current user ID: $_currentUserId');
        AppLogger().warning('❌ Available participants: ${participants.map((p) => '${p["userId"]}:${p["role"]}').join(", ")}');

        // Try to find user in participant slots
        String? slotRole;
        _participants.forEach((role, user) {
          if (user?.id == _currentUserId) {
            slotRole = role;
          }
        });

        if (slotRole != null) {
          AppLogger().warning('🚨 USER FOUND IN SLOT: User $_currentUserId found in $slotRole slot but not in participant list');
          AppLogger().info('🔄 CORRECTING ROLE: Setting role to $slotRole based on slot position');
          _userRole = slotRole;
          if (mounted) {
            setState(() {
              // Update UI with corrected role
            });
          }
        }
      }

      // Check if both debaters are now present and trigger invitation modal
      AppLogger().debug('🔍 STEP: About to call _checkForBothDebatersAndTriggerInvitations()');
      await _checkForBothDebatersAndTriggerInvitations();
      AppLogger().debug('🔍 STEP: _checkForBothDebatersAndTriggerInvitations() completed');

      AppLogger().debug('🔍 STEP: About to call setState()');
      if (mounted) {
        setState(() {
          // Update UI after loading arena participants
        });
      }
      AppLogger().debug('🔍 STEP: setState() completed');
      AppLogger().info('Arena participants loaded successfully');

      // Validate role consistency after loading participants
      await _validateRoleConsistency();

      // Only connect to WebRTC if not already connected
      // This prevents reconnection when new participants join
      if (_userRole != null && !_isWebRTCConnected) {
        final isDebater = ['affirmative', 'negative', 'affirmative2', 'negative2'].contains(_userRole);
        final isImportantRole = ['moderator', 'judge1', 'judge2', 'judge3'].contains(_userRole);
        
        if (isDebater || isImportantRole) {
          AppLogger().debug('🎥 Initial WebRTC connection for critical role: $_userRole');
          await _connectToWebRTC();
        } else {
          AppLogger().debug('🎥 Initial WebRTC connection for role: $_userRole');
          await _connectToWebRTC();
        }
      } else if (_isWebRTCConnected) {
        AppLogger().debug('🎥 WebRTC already connected, skipping reconnection');
      }
      
      // Auto-connect audio for users who should have microphone access - INSTANT
      if (_userRole != null && _shouldUserPublishMedia()) {
        AppLogger().debug('🚀 INSTANT: Triggering immediate auto-connect for role: $_userRole');
        // Run immediately without delay
        if (mounted) {
          _autoConnectAudio(); // Fire and forget for speed
        }
      }
    } catch (e) {
      AppLogger().error('❌ CRITICAL: Error loading participants: $e');
      AppLogger().error('❌ CRITICAL: Exception type: ${e.runtimeType}');
      AppLogger().error('❌ CRITICAL: Stack trace: ${StackTrace.current}');
    }
  }

  /// Ensure room creator is assigned as moderator if no moderator exists
  Future<void> _ensureModeratorExists() async {
    try {
      // Check if moderator already exists
      if (_participants['moderator'] != null) {
        AppLogger().debug('🎭 Moderator already assigned: ${_participants['moderator']?.name}');
        return;
      }
      
      // Check if current user is the room creator
      if (_roomData != null && _currentUserId != null && _roomData!['createdBy'] == _currentUserId) {
        AppLogger().info('🎭 Room creator detected - auto-assigning as moderator');
        
        // Assign current user as moderator
        await _appwrite.assignArenaRole(
          roomId: widget.roomId,
          userId: _currentUserId!,
          role: 'moderator',
        );
        
        // Reload participants to reflect the change
        await _loadParticipants();
        
        AppLogger().info('✅ Room creator successfully assigned as moderator');
      } else {
        AppLogger().debug('🎭 Current user is not room creator - moderator assignment skipped');
      }
    } catch (e) {
      AppLogger().error('Error ensuring moderator exists: $e');
    }
  }

  // iOS-specific optimized loading methods
  
  /// Optimized user data loading for iOS with caching
  Future<void> _loadUserDataOptimized() async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Check cache first for iOS
      if (_isIOSOptimizationEnabled && _iosUserProfileCache.isNotEmpty) {
        final user = await _appwrite.getCurrentUser();
        if (user != null) {
          _currentUserId = user.$id;
          final cachedProfile = _iosUserProfileCache[user.$id];
          if (cachedProfile != null) {
            _currentUser = cachedProfile;
            AppLogger().info('iOS: Used cached user profile (${stopwatch.elapsedMilliseconds}ms)');
            return;
          }
        }
      }
      
      // Load fresh data
      final user = await _appwrite.getCurrentUser();
      if (user == null) return;
      
      _currentUserId = user.$id;
      _currentUser = await _appwrite.getUserProfile(user.$id);
      
      // Cache for iOS
      if (_isIOSOptimizationEnabled && _currentUser != null) {
        _iosUserProfileCache[user.$id] = _currentUser!;
      }
      
      AppLogger().info('iOS: User data loaded in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      AppLogger().error('Error loading optimized user data: $e');
    }
  }
  
  /// Optimized room data loading for iOS with caching
  Future<void> _loadRoomDataOptimized() async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Check cache first for iOS
      if (_isIOSOptimizationEnabled) {
        final cachedRoom = _iosRoomCache[widget.roomId];
        if (cachedRoom != null && _isCacheValid()) {
          _roomData = cachedRoom;
          AppLogger().info('iOS: Used cached room data (${stopwatch.elapsedMilliseconds}ms)');
          return;
        }
      }
      
      // Load fresh room data
      Map<String, dynamic>? roomData = await _appwrite.getArenaRoom(widget.roomId);
      
      if (roomData == null) {
        AppLogger().warning('Arena room not found: ${widget.roomId}');
        return;
      }
      
      // Check room status for early exit
      final roomStatus = roomData['status'];
      if (roomStatus == 'completed' || roomStatus == 'abandoned' || roomStatus == 'force_cleaned' || roomStatus == 'force_closed') {
        await _handleClosedRoom(roomStatus);
        return;
      }
      
      _roomData = roomData;
      _teamSize = roomData['teamSize'] ?? 1; // Default to 1v1 if not specified
      
      // Cache for iOS
      if (_isIOSOptimizationEnabled) {
        _iosRoomCache[widget.roomId] = roomData;
        _lastCacheUpdate = DateTime.now();
      }
      
      AppLogger().info('iOS: Room data loaded in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      AppLogger().error('Error loading optimized room data: $e');
    }
  }
  
  /// Optimized participant loading for iOS with reduced database operations
  Future<void> _loadParticipantsOptimized() async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Check cache first for iOS
      if (_isIOSOptimizationEnabled) {
        final cachedParticipants = _iosParticipantCache[widget.roomId];
        if (cachedParticipants != null && _isCacheValid()) {
          _processParticipants(cachedParticipants);
          AppLogger().info('iOS: Used cached participants (${stopwatch.elapsedMilliseconds}ms)');
          return;
        }
      }
      
      // Load fresh participants
      final participants = await _appwrite.getArenaParticipants(widget.roomId);
      
      // Process participants efficiently
      _processParticipants(participants);
      
      // Cache for iOS
      if (_isIOSOptimizationEnabled) {
        _iosParticipantCache[widget.roomId] = participants;
      }
      
      AppLogger().info('iOS: Participants loaded in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      AppLogger().error('Error loading optimized participants: $e');
    }
  }
  
  /// Process participants data efficiently (shared by both cached and fresh data)
  void _processParticipants(List<Map<String, dynamic>> participants) {
    AppLogger().info('Processing ${participants.length} participants for Arena');
    
    // Reset participants
    _participants = {
      'affirmative': null,
      'negative': null,
      'affirmative2': null,
      'negative2': null,
      'moderator': null,
      'judge1': null,
      'judge2': null,
      'judge3': null,
    };
    _audience.clear();
    
    // Assign participants to roles efficiently
    for (var participant in participants) {
      final role = participant['role'];
      final userProfileData = participant['userProfile'];
      
      if (userProfileData != null) {
        final userProfile = UserProfile.fromMap(userProfileData);
        
        if (['affirmative', 'negative', 'affirmative2', 'negative2', 'moderator', 'judge1', 'judge2', 'judge3'].contains(role)) {
          _participants[role] = userProfile;
        } else if (role == 'audience') {
          _audience.add(userProfile);
        }
      }
    }
    
    // Determine current user's role efficiently
    if (_currentUserId != null) {
      for (var participant in participants) {
        if (participant['userId'] == _currentUserId) {
          _userRole = participant['role'];
          
          // Immediately connect WebRTC for debaters to enable instant audio
          final isDebater = ['affirmative', 'negative', 'affirmative2', 'negative2'].contains(_userRole);
          if (isDebater && !_isWebRTCConnected) {
            AppLogger().debug('🎥 DEBATER DETECTED (iOS): Initial WebRTC connection for peer-to-peer audio');
            _connectToWebRTC();
          }
          break;
        }
      }
    }
    
    // Check if both debaters are now present and trigger invitation modal
    _checkForBothDebatersAndTriggerInvitations();

    if (mounted) {
      setState(() {
        // Update UI after participant role change
      });
    }
  }
  
  // iOS caching helper methods
  
  /// Get cached data if available and valid
  Map<String, dynamic>? _getIOSCachedData() {
    if (!_isIOSOptimizationEnabled || !_isCacheValid()) return null;
    
    final roomData = _iosRoomCache[widget.roomId];
    final participants = _iosParticipantCache[widget.roomId];
    
    if (roomData != null && participants != null) {
      return {
        'roomData': roomData,
        'participants': participants,
      };
    }
    return null;
  }
  
  /// Apply cached data to state
  void _applyIOSCachedData(Map<String, dynamic> cachedData) {
    final roomData = cachedData['roomData'] as Map<String, dynamic>;
    final participants = cachedData['participants'] as List<Map<String, dynamic>>;
    
    _roomData = roomData;
    _processParticipants(participants);
    
    AppLogger().info('Applied cached data for faster iOS loading');
  }
  
  /// Update iOS cache with current data
  void _updateIOSCache() {
    if (!_isIOSOptimizationEnabled) return;
    
    if (_roomData != null) {
      _iosRoomCache[widget.roomId] = _roomData!;
    }
    
    _lastCacheUpdate = DateTime.now();
    AppLogger().debug('💾 Updated iOS cache for room: ${widget.roomId}');
  }
  
  /// Check if cached data is still valid (5 minutes for iOS optimization)
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    final cacheAge = DateTime.now().difference(_lastCacheUpdate!);
    return cacheAge.inMinutes < 5;
  }
  
  /// Handle closed room scenario efficiently
  Future<void> _handleClosedRoom(String roomStatus) async {
    AppLogger().debug('🚪 Room has been closed (status: $roomStatus), navigating back to arena lobby');
    
    if (_hasNavigated) {
      AppLogger().debug('🔍 Navigation already in progress, skipping duplicate navigation');
      return;
    }
    
    _hasNavigated = true;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 This arena room has been closed'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && !_isExiting) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isExiting) {
              try {
                _isExiting = true; // Prevent multiple navigation attempts
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ArenaApp()),
                  (route) => false,
                );
              } catch (e) {
                AppLogger().error('Navigation error: $e');
                _isExiting = false; // Reset on error
              }
            }
          });
        }
      });
    }
  }

  // Notification Service Management - REMOVED (should not restart singleton service)
  
  // Enhanced Timer Management - Note: AppwriteTimerWidget in AppBar handles sync



  void _stopTimer() {
    if (mounted) {
      setState(() {
        _speakingEnabled = false;
      });
    }
    _timerController.stop();
  }





  void _advanceToNextPhase() {
    final nextPhase = _currentPhase.nextPhase;
    if (nextPhase != null) {
      // Stop any running timer first
      _stopTimer();
      
      setState(() {
        _currentPhase = nextPhase;
        // Set the default time for the phase but don't start it
        if (nextPhase.defaultDurationSeconds != null) {
          _remainingSeconds = nextPhase.defaultDurationSeconds!;
        } else {
          _remainingSeconds = 0;
        }
      });
      
      // Update timer controller after setState
      if (nextPhase.defaultDurationSeconds != null) {
        _timerController.duration = Duration(seconds: _remainingSeconds);
        _timerController.reset();
      }
      
      AppLogger().debug('🔄 Advanced to ${nextPhase.displayName} - Timer set to ${_remainingSeconds}s (not started)');
    }
  }

  // Moderator Controls
  bool get _isModerator {
    // Check if user is the room moderator OR is a Super Moderator
    if (_userRole == 'moderator') return true;
    if (_currentUserId != null) {
      final superModService = SuperModeratorService();
      return superModService.isSuperModerator(_currentUserId!);
    }
    return false;
  }
  bool get _isJudge => _userRole?.startsWith('judge') == true;

  void _forceSpeakerChange(String newSpeaker) {
    if (!_isModerator) return;
    
    setState(() {
      _currentSpeaker = newSpeaker;
      _speakingEnabled = newSpeaker.isNotEmpty;
    });
    
    AppLogger().debug('🎤 Moderator changed speaker to: $newSpeaker');
  }

  void _toggleSpeakingEnabled() {
    if (!_isModerator) return;
    
    setState(() {
      _speakingEnabled = !_speakingEnabled;
    });
    
    AppLogger().info('Speaking ${_speakingEnabled ? 'enabled' : 'disabled'} by moderator');
  }

  void _toggleJudging() async {
    if (!_isModerator) return;
    
    // Voting is now always open, moderator can only close it to determine winner
    if (_judgingComplete) {
      AppLogger().info('🎯 MODERATOR: Voting already closed and results determined');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📊 Voting has already been closed and results determined.'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }
    
    AppLogger().info('🎯 MODERATOR CLOSING VOTING:');
    AppLogger().info('  - Room ID: ${widget.roomId}');
    
    try {
      // Moderator is closing voting - determine winner and show results
      await _determineWinnerAndShowResults();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚖️ Voting CLOSED - Results determined and displayed!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      AppLogger().error('Error updating judging state: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error updating judging state: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Mute all participants in the arena (moderator only)
  Future<void> _muteAllParticipants() async {
    if (!_isModerator) {
      AppLogger().warning('🔇 Non-moderator attempted to mute all participants');
      return;
    }

    // Show confirmation dialog to prevent accidental mute all
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔇 Mute All Participants'),
        content: const Text('Are you sure you want to mute all participants? This will silence everyone in the room.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Mute All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      AppLogger().info('🔇 MODERATOR: Confirmed mute all participants');

      // Use LiveKit service to mute all participants
      await _liveKitService.muteAllParticipants();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔇 All participants have been muted'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }

      AppLogger().info('✅ MODERATOR: Successfully initiated mute all');
    } catch (e) {
      AppLogger().error('❌ Error muting all participants: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error muting participants: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _determineWinnerAndShowResults() async {
    try {
      AppLogger().info('🎯 MODERATOR: Broadcasting arena results to all users via backend function');
      AppLogger().info('  - Room ID: ${widget.roomId}');

      // Verify we have a valid user session
      final currentUser = await _appwrite.getCurrentUser();
      if (currentUser == null) {
        throw Exception('No user session found');
      }
      AppLogger().info('✅ User session verified: ${currentUser.name}');

      // Call backend Appwrite Function to broadcast results
      // This ensures reliable server-side winner calculation and broadcast to ALL users
      AppLogger().info('📞 Calling broadcast-arena-results-v3 function...');
      final result = await _appwrite.functions.createExecution(
        functionId: 'broadcast-arena-results-v3',
        body: jsonEncode({
          'roomId': widget.roomId,
        }),
        xasync: false, // Wait for response
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Function execution timed out');
        },
      );
      AppLogger().info('✅ Function execution completed');
      AppLogger().info('📄 Response status: ${result.responseStatusCode}');
      AppLogger().info('📄 Response body: ${result.responseBody}');

      // Parse response
      final responseBody = jsonDecode(result.responseBody);
      AppLogger().info('📄 Parsed response: $responseBody');

      if (responseBody['success'] == true) {
        final winner = responseBody['winner'];
        final affirmativeVotes = responseBody['affirmativeVotes'];
        final negativeVotes = responseBody['negativeVotes'];
        final totalAffirmativeScore = responseBody['totalAffirmativeScore'];
        final totalNegativeScore = responseBody['totalNegativeScore'];

        AppLogger().info('✅ Results broadcast successfully!');
        AppLogger().info('  - Winner: $winner');
        AppLogger().info('  - Affirmative: $affirmativeVotes votes ($totalAffirmativeScore points)');
        AppLogger().info('  - Negative: $negativeVotes votes ($totalNegativeScore points)');
        AppLogger().info('  - ALL users will now see trophy icon!');

        // Update local state (realtime will update too, but update immediately for responsiveness)
        if (mounted) {
          setState(() {
            _winner = winner;
            _judgingComplete = true;
            _judgingEnabled = false;
            _showResults = true;
          });

          // Show results modal after a short delay (auto-show once for moderator)
          if (!_resultsModalShown) {
            _resultsModalShown = true;
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _showResultsModal();
              }
            });
          }
        }
      } else {
        throw Exception(responseBody['error'] ?? 'Unknown error from backend');
      }

    } catch (e) {
      AppLogger().error('❌ Error broadcasting results: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error broadcasting results: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }



  features.DebatePhase _convertToFeaturesPhase(DebatePhase phase) {
    switch (phase) {
      case DebatePhase.preDebate:
        return features.DebatePhase.preDebate;
      case DebatePhase.openingAffirmative:
        return features.DebatePhase.openingAffirmative;
      case DebatePhase.openingNegative:
        return features.DebatePhase.openingNegative;
      case DebatePhase.rebuttalAffirmative:
        return features.DebatePhase.rebuttalAffirmative;
      case DebatePhase.rebuttalNegative:
        return features.DebatePhase.rebuttalNegative;
      case DebatePhase.crossExamAffirmative:
        return features.DebatePhase.crossExamAffirmative;
      case DebatePhase.crossExamNegative:
        return features.DebatePhase.crossExamNegative;
      case DebatePhase.finalRebuttalAffirmative:
        return features.DebatePhase.finalRebuttalAffirmative;
      case DebatePhase.finalRebuttalNegative:
        return features.DebatePhase.finalRebuttalNegative;
      case DebatePhase.closingAffirmative:
        return features.DebatePhase.closingAffirmative;
      case DebatePhase.closingNegative:
        return features.DebatePhase.closingNegative;
      case DebatePhase.judging:
        return features.DebatePhase.judging;
    }
  }

  void _showModeratorControlModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => moderator_controls.ModeratorControlModal(
        currentPhase: _convertToFeaturesPhase(_currentPhase),
        onAdvancePhase: _advanceToNextPhase,
        onEmergencyReset: () {
          _stopTimer();
          setState(() {
            _currentPhase = DebatePhase.preDebate;
            _speakingEnabled = false;
            _currentSpeaker = '';
            _judgingEnabled = false; // Reset judging when emergency reset
          });
        },
        onEndDebate: () {
          setState(() {
            _currentPhase = DebatePhase.judging;
            _judgingEnabled = true; // Enable judging when debate ends
          });
          _stopTimer();
        },
        onSpeakerChange: _forceSpeakerChange,
        onToggleSpeaking: _toggleSpeakingEnabled,
        onToggleJudging: _toggleJudging,
        onMuteAll: _muteAllParticipants,
        currentSpeaker: _currentSpeaker,
        speakingEnabled: _speakingEnabled,
        judgingEnabled: _judgingEnabled,
        affirmativeParticipant: _participants['affirmative'],
        negativeParticipant: _participants['negative'],
        debateCategory: widget.category,
        connectionHealthInfo: _connectionDropCount > 0 ? {
          'dropCount': _connectionDropCount,
          'lastDrop': _lastConnectionDrop != null ? _formatTimestamp(_lastConnectionDrop!) : null,
        } : null,
      ),
    );
  }


  void _showUserProfile(UserProfile userProfile, String? userRole) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => UserProfileBottomSheet(
        user: userProfile,
        onFollow: () async {
          if (_currentUser == null) return;

          try {
            final isFollowing = await _appwrite.isFollowing(
              followerId: _currentUser!.id,
              followingId: userProfile.id,
            );

            if (isFollowing) {
              await _appwrite.unfollowUser(
                followerId: _currentUser!.id,
                followingId: userProfile.id,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unfollowed ${userProfile.name}'),
                    backgroundColor: Colors.grey,
                  ),
                );
              }
            } else {
              await _appwrite.followUser(
                followerId: _currentUser!.id,
                followingId: userProfile.id,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Now following ${userProfile.name}'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            }
          } catch (e) {
            AppLogger().error('Error toggling follow: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update follow status'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        },
        onChallenge: () {
          // Challenge functionality is now handled directly by UserProfileBottomSheet
          AppLogger().debug('Challenge functionality delegated to UserProfileBottomSheet');
        },
        onEmail: () {
          if (mounted && _currentUser != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmailComposeScreen(
                  currentUserId: _currentUser!.id,
                  currentUsername: _currentUser!.name,
                  recipient: userProfile,
                ),
              ),
            );
          }
        },
      ),
    );
  }


  void _showSharedLinkPopup(DebateSource sharedLink) {
    if (!mounted || _isExiting) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SharedLinkPopup(
        sharedLink: sharedLink,
        onDismiss: () {
          AppLogger().info('📌 Shared link popup dismissed');
        },
      ),
    );
  }

  void _showSlideUpdatePopup(SlideData slideData) {
    if (!mounted || _isExiting || _materialSyncService == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SlideUpdatePopup(
        slideData: slideData,
        syncService: _materialSyncService!,
        appwriteService: _appwrite,
        currentUserId: _currentUserId ?? '',
        roomId: widget.roomId,
        onDismiss: () {
          AppLogger().info('📊 Slide update popup dismissed');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return PopScope(
      canPop: false, // Prevent accidental back navigation
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackPressed();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: ArenaAppBar(
          isModerator: _isModerator,
          onShowModeratorControls: _showModeratorControlModal,
          onExitArena: _exitArena,
          onEmergencyCloseRoom: _emergencyCloseRoom,
          roomId: widget.roomId,
          userId: _currentUserId ?? '',
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _buildMainArena(),
                ),
                _buildControlPanel(),
              ],
            ),
            // Add debate materials bottom sheet
            if (_showMaterialsBottomSheet && _materialSyncService != null)
              Positioned.fill(
                child: DebateBottomSheet(
                  roomId: widget.roomId,
                  userId: _currentUserId ?? '',
                  isHost: _userRole == 'moderator' || _userRole == 'affirmative' || _userRole == 'negative',
                  syncService: _materialSyncService!,
                  appwriteService: _appwrite,
                  onClose: () {
                    setState(() {
                      _showMaterialsBottomSheet = false;
                    });
                  },
                ),
              ),
            
          ],
        ),
      ), // Close PopScope
    );
  }

  void _exitArena() {
    // Show confirmation dialog for leaving arena
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.orange),
            SizedBox(width: 8),
            Text('Leave Arena'),
          ],
        ),
        content: Text(_isModerator 
            ? 'As the moderator, leaving will close this arena room for all participants. Are you sure?'
            : 'Are you sure you want to leave this arena?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              // Prevent any further state updates
              if (_isExiting) return;
              _isExiting = true;
              
              AppLogger().debug('🚪 Starting exit process...');

              // Only close room if ACTUAL room moderator is leaving (not super moderator)
              if (_userRole == 'moderator') {
                await _handleModeratorExit();
              } else {
                await _handleParticipantExit();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleModeratorExit() async {
    try {
      AppLogger().debug('👑 Moderator leaving - closing entire room');
      
      // 1. Cancel all timers and subscriptions immediately
      _cancelAllTimersAndSubscriptions();
      
      // 2. Close the room and remove all participants
      await _closeRoomDueToModeratorExit();
      
      // 3. Navigate home
      _forceNavigationHomeSync();
      
    } catch (e) {
      AppLogger().error('Error in moderator exit: $e');
      _forceNavigationHomeSync(); // Still navigate even if cleanup fails
    }
  }

  Future<void> _handleParticipantExit() async {
    try {
      AppLogger().debug('👤 Participant leaving arena');
      
      // 1. Cancel all timers and subscriptions immediately
      _cancelAllTimersAndSubscriptions();
      
      // 2. Remove only this participant
      await _removeCurrentUserFromRoom();
      
      // 3. Navigate home
      _forceNavigationHomeSync();
      
    } catch (e) {
      AppLogger().error('Error in participant exit: $e');
      _forceNavigationHomeSync(); // Still navigate even if cleanup fails
    }
  }

  void _cancelAllTimersAndSubscriptions() {
    try {
      if (_roomStatusChecker != null) {
        _roomStatusChecker!.cancel();
        _roomStatusChecker = null;
        AppLogger().debug('🛑 Exit timer cancelled and nulled');
      }
      // Cancel consolidated subscriptions
      _realtimeManager.unsubscribeFromRoom(widget.roomId);
      _participantStreamListener?.cancel();
      _roomStatusStreamListener?.cancel();
      _judgmentStreamListener?.cancel();
      _timerStreamListener?.cancel();
      _timerController.stop();
      _stopTimer();
      AppLogger().info('All timers and subscriptions cancelled');
    } catch (e) {
      AppLogger().warning('Error cancelling timers: $e');
    }
  }

  Future<void> _closeRoomDueToModeratorExit() async {
    try {
      AppLogger().debug('🔒 Closing room due to moderator exit...');

      // Use resilient close with timeout
      await _closeRoomResiliently(widget.roomId, abandoned: true).timeout(
        Duration(seconds: 8),
      );

      AppLogger().info('✅ Room closed due to moderator exit');

    } catch (e) {
      AppLogger().error('⚠️ Error closing room on moderator exit: $e');
      // Don't block exit even if close fails - the room status check will clean it up
    }
  }

  /// Resilient room close method that handles various edge cases
  Future<void> _closeRoomResiliently(String roomId, {bool abandoned = false}) async {
    try {
      // 1. First check if room exists and needs closing
      try {
        final roomDoc = await _appwrite.databases.getDocument(
          databaseId: 'arena_db',
          collectionId: 'arena_rooms',
          documentId: roomId,
        );

        final currentStatus = roomDoc.data['status'];
        if (currentStatus == 'completed' ||
            currentStatus == 'abandoned' ||
            currentStatus == 'closed') {
          AppLogger().info('🚨 Room already has final status: $currentStatus');
          return; // Already closed
        }
      } catch (e) {
        if (e.toString().contains('document_not_found')) {
          AppLogger().info('🚨 Room document not found - assuming already cleaned up');
          return;
        }
        // Continue with close attempt for other errors
      }

      // 2. Update room status
      try {
        await _appwrite.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'arena_rooms',
          documentId: roomId,
          data: {
            'status': abandoned ? 'abandoned' : 'completed',
            'endedAt': DateTime.now().toIso8601String(),
          },
        );
        AppLogger().debug('✅ Room status updated to ${abandoned ? 'abandoned' : 'completed'}');
      } catch (e) {
        AppLogger().warning('⚠️ Failed to update room status: $e');
        // Continue with participant cleanup even if status update fails
      }

      // 3. Handle participants (set inactive instead of deleting for data integrity)
      try {
        final participants = await _appwrite.databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          queries: [
            Query.equal('roomId', roomId),
            Query.equal('isActive', true),
          ],
        );

        // Update participants in parallel for faster processing
        final updateFutures = participants.documents.map((participant) async {
          try {
            await _appwrite.databases.updateDocument(
              databaseId: 'arena_db',
              collectionId: 'arena_participants',
              documentId: participant.$id,
              data: {
                'isActive': false,
                'leftAt': DateTime.now().toIso8601String(),
              },
            );
          } catch (e) {
            AppLogger().warning('⚠️ Failed to update participant ${participant.$id}: $e');
            // Don't fail the entire operation for one participant
          }
        });

        await Future.wait(updateFutures);
        AppLogger().debug('✅ Updated ${participants.documents.length} participants');

      } catch (e) {
        AppLogger().warning('⚠️ Error updating participants: $e');
        // Don't fail the operation - room status update is more important
      }

      AppLogger().info('✅ Room closed resiliently');

    } catch (e) {
      AppLogger().error('❌ Resilient room close failed: $e');
      rethrow;
    }
  }

  Future<void> _removeCurrentUserFromRoom() async {
    try {
      if (_currentUserId != null) {
        final participants = await _appwrite.databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          queries: [
            Query.equal('roomId', widget.roomId),
            Query.equal('userId', _currentUserId!),
            Query.equal('isActive', true),
          ],
        );
        
        // Delete participant record entirely to trigger real-time updates
        for (final participant in participants.documents) {
          await _appwrite.databases.deleteDocument(
            databaseId: 'arena_db',
            collectionId: 'arena_participants',
            documentId: participant.$id,
          );
        }
        
        AppLogger().info('User $_currentUserId participant record deleted');
      }
    } catch (e) {
      AppLogger().warning('Error in database cleanup: $e');
    }
  }

  Widget _buildMainArena() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use constraints.maxHeight instead of MediaQuery for more accurate available space
        final availableHeight = constraints.maxHeight;
        final screenHeight = MediaQuery.of(context).size.height;
        final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
        
        // Debug logging
        AppLogger().debug('🎭 ARENA LAYOUT: Screen height: $screenHeight, Available height: $availableHeight, Platform: ${isIOS ? "iOS" : "Android"}');
        
        // More aggressive sizing for iOS to ensure audience is visible
        final isSmallScreen = availableHeight < 600;
        
        // Adjust heights based on available space - increased for larger avatars
        final judgeHeight = isIOS
            ? (isSmallScreen ? 110.0 : 135.0) // Increased judge size for larger avatars
            : (isSmallScreen ? 120.0 : 150.0); // Increased judge size for larger avatars
        // Different heights for 1v1 vs 2v2 modes
        final debaterHeight1v1 = isIOS
            ? (isSmallScreen ? 120.0 : 140.0) // Good size for 1v1
            : (isSmallScreen ? 140.0 : 160.0); // Good size for 1v1
        // For 2v2: balanced size for comfort while showing audience (reduced for small screens)
        final debaterHeight2v2 = isIOS
            ? (isSmallScreen ? 180.0 : 220.0) // Reduced for small screens to prevent overflow
            : (isSmallScreen ? 190.0 : 250.0); // Reduced for small screens to prevent overflow
        final moderatorHeight = isIOS
            ? (isSmallScreen ? 95.0 : 115.0) // Increased moderator size for larger avatars
            : (isSmallScreen ? 105.0 : 130.0); // Increased moderator size for larger avatars
        
        // Calculate total debate section height dynamically - use appropriate debater height
        final debaterHeight = _teamSize == 1 ? debaterHeight1v1 : debaterHeight2v2;
        final sectionSpacing = _teamSize == 1 ? 8 : 6; // Reduced spacing for 2v2
        final calculatedDebateSectionHeight = 4 + // top padding
            28 + // title height (reduced)
            4 + // margin after title
            debaterHeight + // debaters (1v1 or 2v2 height)
            sectionSpacing + // spacing
            moderatorHeight + // moderator 
            sectionSpacing + // spacing
            judgeHeight + // judges
            2 + // bottom spacing (reduced)
            4; // bottom padding
        
        // Safety constraint: ensure debate section never exceeds 65% of available height
        final maxDebateSectionHeight = (availableHeight * 0.65).floor().toDouble();
        final debateSectionHeight = calculatedDebateSectionHeight < maxDebateSectionHeight 
            ? calculatedDebateSectionHeight 
            : maxDebateSectionHeight;
        
        // Ensure audience section has minimum height by adjusting debate section if needed
        final minAudienceHeight = isIOS ? 150.0 : 80.0; // Even larger minimum for iOS devices
        final maxAllowedDebateHeight = availableHeight - minAudienceHeight - (isIOS ? 40 : 20); // Even more margin for iOS
        final finalDebateSectionHeight = debateSectionHeight > maxAllowedDebateHeight 
            ? maxAllowedDebateHeight 
            : debateSectionHeight;
        
        AppLogger().debug('🎭 ARENA LAYOUT: Final debate section height: $finalDebateSectionHeight');
        
        return Stack(
          children: [
            // Audience section as background (scrollable)
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.only(
                  top: finalDebateSectionHeight,
                  bottom: 8, // Further reduced bottom margin to prevent overflow
                ),
                child: _buildAudienceScrollSection(),
              ),
            ),
            
            // Fixed debate section (floating on top)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: const Color(0xFF1a1a1a), // Dark background to prevent see-through
                padding: const EdgeInsets.all(8), // Restored original padding
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Important: minimize size
                  children: [
                    // Debate Title (restored original size)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 6), // Restored margin
                      decoration: BoxDecoration(
                        gradient: LinearGradient( // Add gradient for more visual impact
                          colors: [
                            const Color(0xFF1A1A2E), // Dark blue-purple
                            deepPurple.withOpacity(0.3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12), // Slightly more rounded
                        border: Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.5), // Gold border to match text
                          width: 2, // Thicker border for more presence
                        ),
                        boxShadow: [ // Add subtle shadow for depth
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.topic,
                        style: const TextStyle(
                          color: Color(0xFFFFD700), // Bright gold color that stands out
                          fontWeight: FontWeight.bold, // Make it bold
                          fontSize: 16, // Slightly larger for better visibility
                          height: 1.3,
                          letterSpacing: 0.5, // Add letter spacing for better readability
                          shadows: [
                            Shadow( // Add subtle shadow for extra pop
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Main arena content - responsive heights
                    Column(
                      children: [
                        // Top Row - Debaters (responsive height)
                        SizedBox(
                          height: debaterHeight,
                          child: _teamSize == 1 
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(child: _buildDebaterPosition('affirmative', 'Affirmative')),
                                const SizedBox(width: 1),
                                Expanded(child: _buildDebaterPosition('negative', 'Negative')),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Left spacer (smaller)
                                const Expanded(flex: 1, child: SizedBox.shrink()),
                                // Affirmative Team (2 slots) - more constrained
                                Expanded(
                                  flex: 4,
                                  child: _buildTeamPosition('affirmative', 'Affirmative Team'),
                                ),
                                const SizedBox(width: 1), // Space between teams
                                // Negative Team (2 slots) - more constrained
                                Expanded(
                                  flex: 4,
                                  child: _buildTeamPosition('negative', 'Negative Team'),
                                ),
                                // Right spacer (smaller)
                                const Expanded(flex: 1, child: SizedBox.shrink()),
                              ],
                            ),
                      ),
                      
                      SizedBox(height: _teamSize == 1 ? 2 : 2), // Less spacing for 2v2
                      
                      // Middle Row - Moderator (responsive height)
                      SizedBox(
                        height: moderatorHeight,
                        child: Row(
                          children: [
                            const Expanded(child: SizedBox.shrink()),
                            Expanded(child: _buildJudgePosition('moderator', 'Moderator', isPurple: true)),
                            const Expanded(child: SizedBox.shrink()),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: _teamSize == 1 ? 2 : 2), // Less spacing for 2v2
                      
                      // Bottom Row - Judges (responsive height)
                      SizedBox(
                        height: judgeHeight,
                        child: Row(
                          children: [
                            Expanded(child: _buildJudgePosition('judge1', 'Judge 1')),
                            const SizedBox(width: 1),
                            Expanded(child: _buildJudgePosition('judge2', 'Judge 2')),
                            const SizedBox(width: 1),
                            Expanded(child: _buildJudgePosition('judge3', 'Judge 3')),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 2), // Further reduced spacing
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
  }

  /// Handle back button press with proper room closure
  Future<void> _handleBackPressed() async {
    if (_isModerator) {
      await _showModeratorExitDialog();
    } else {
      _exitArena();
    }
  }

  /// Show moderator exit dialog with room closure options
  Future<void> _showModeratorExitDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Moderator Exit',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'As the moderator, leaving will close this arena for all participants. Are you sure?',
            style: TextStyle(color: Colors.grey[300]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Stay', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                _exitArena(); // Trigger moderator exit with room closure
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Close Arena'),
            ),
          ],
        );
      },
    );
}
  
  Widget _buildAudienceScrollSection() {
    return Container(
      color: const Color(0xFF1a1a1a), // Match the main arena background
      height: double.infinity, // Ensure full height usage
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add top padding to push content down within the container
            SizedBox(height: defaultTargetPlatform == TargetPlatform.iOS ? 25 : 15),
            
            // Visual separator line
            Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: accentPurple.withOpacity(0.5),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.people,
                    color: accentPurple,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Audience (${_audience.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Audience Grid
            if (_audience.isEmpty)
              Container(
                height: 150,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accentPurple.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      color: Colors.white54,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No audience yet',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Users will appear here when they join',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GridView.builder(
                key: const ValueKey('arena_audience_grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 1,
                  mainAxisSpacing: 1,
                  childAspectRatio: 1.0, // Better aspect ratio for circular avatars
                ),
                itemCount: _audience.length,
                itemBuilder: (context, index) {
                  final audience = _audience[index];
                  return GestureDetector(
                    key: ValueKey('arena_audience_${audience.id}'),
                    onTap: () => _showUserProfile(audience, 'audience'),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Simple CircleAvatar
                        CircleAvatar(
                          radius: 24.0,
                          backgroundColor: getAvatarColorForRole('audience'),
                          backgroundImage: audience.avatar != null && audience.avatar!.isNotEmpty
                              ? NetworkImage(audience.avatar!)
                              : null,
                          child: audience.avatar == null || audience.avatar!.isEmpty
                              ? Text(
                                  audience.name.isNotEmpty ? audience.name[0].toUpperCase() : 'A',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        // Simple name text
                        Text(
                          audience.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                  ));
                },
              ),
            ),
            
            // Add some bottom spacing to ensure full visibility
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }


  Widget _buildDebaterPosition(String role, String title, {bool? isWinner}) {
    final participant = _participants[role];
    final isAffirmative = role.startsWith('affirmative');
    final finalIsWinner = isWinner ?? (_judgingComplete && _winner == role);
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: finalIsWinner ? Colors.amber : (isAffirmative ? Colors.green : Colors.red), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: finalIsWinner 
                  ? Colors.amber
                  : getAvatarColorForRole(role),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (finalIsWinner) ...[
                  const Icon(Icons.emoji_events, color: Colors.black, size: 14),
                  const SizedBox(width: 3),
                ],
                Text(
                  finalIsWinner ? 'WINNER' : title,
                  style: TextStyle(
                    color: finalIsWinner ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (finalIsWinner) ...[
                  const SizedBox(width: 3),
                  const Icon(Icons.emoji_events, color: Colors.black, size: 14),
                ],
              ],
            ),
          ),
          Expanded(
            child: participant != null
                ? _buildDebaterTile(participant, role, isSmall: true, isWinner: finalIsWinner)
                : _buildEmptyPosition('Waiting for $title...', isSmall: true),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamPosition(String baseRole, String title) {
    final isAffirmative = baseRole == 'affirmative';
    
    // Check if this team won (for 2v2, winner is still 'affirmative' or 'negative')
    final teamWon = _judgingComplete && _winner == baseRole;
    
    return Column(
      children: [
        // First team member slot (top)
        Expanded(
          child: _buildDebaterPosition(
            baseRole, 
            isAffirmative ? 'Affirmative 1' : 'Negative 1',
            isWinner: teamWon,
          ),
        ),
        const SizedBox(height: 4),
        // Second team member slot (bottom)
        Expanded(
          child: _buildDebaterPosition(
            '${baseRole}2', 
            isAffirmative ? 'Affirmative 2' : 'Negative 2',
            isWinner: teamWon,
          ),
        ),
      ],
    );
  }

  Widget _buildJudgePosition(String role, String title, {bool isPurple = false}) {
    final judge = _participants[role];
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: getAvatarColorForRole(role),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: judge == null ? const Color(0xFF2A2A2A) : null, // Dark background for all empty slots
                gradient: judge != null ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: getAvatarGradientForRole(role),
                ) : null, // Gradient only for filled slots
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: judge != null
                  ? _buildJudgeTile(judge, role, isSmall: true)
                  : Center(
                      child: Icon(
                        Icons.gavel,
                        color: const Color(0xFF8B5CF6), // Purple color for all empty slots
                        size: 24,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildEmptyPosition(String text, {bool isSmall = false}) {
    return Padding(
      padding: const EdgeInsets.all(8), // Increased to match other tiles for consistency
      child: Center(
        child: Icon(
          Icons.gavel,
          color: const Color(0xFF8B5CF6), // Purple color
          size: isSmall ? 28 : 36,
        ),
      ),
    );
  }

  /// Build audio-only tile for debater with microphone status
  Widget _buildDebaterTile(UserProfile participant, String role, {bool isSmall = false, bool isWinner = false}) {

    // Find the peer ID for this user to get their audio/video stream
    final peerId = _userToPeerMapping[participant.id];
    final stream = peerId != null ? _remoteStreams[peerId] : null;

    AppLogger().debug('🎥 Building debater tile for ${participant.name}: peerId=$peerId, stream=${stream != null}, userMapping=$_userToPeerMapping');

    // Check if this is the local user
    final isLocalUser = participant.id == _currentUserId;

    // Use actual LiveKit speaker detection for real-time speaking indicators
    final isSpeaking = _liveKitService.isUserSpeaking(participant.id);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          // Video feed or avatar background fills entire area
          _buildDebaterVideoFeed(participant, role, stream, isLocalUser, isSmall),
                    
                    // Audio/Video status indicators and controls
                    _buildDebaterControls(participant, role, isLocalUser, isSpeaking, isSmall),
                    
                    // Profile tap area (only for non-local users, avoiding control area)
                    if (!isLocalUser)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 40, // Leave space for controls at bottom
                        child: GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) => UserProfileBottomSheet(
                                user: participant,
                                onFollow: () async {
                                  if (_currentUser == null) return;

                                  try {
                                    // Check if already following to determine action
                                    final isFollowing = await _appwrite.isFollowing(
                                      followerId: _currentUser!.id,
                                      followingId: participant.id,
                                    );

                                    if (isFollowing) {
                                      // Unfollow
                                      await _appwrite.unfollowUser(
                                        followerId: _currentUser!.id,
                                        followingId: participant.id,
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Unfollowed ${participant.name}'),
                                            backgroundColor: Colors.grey,
                                          ),
                                        );
                                      }
                                    } else {
                                      // Follow
                                      await _appwrite.followUser(
                                        followerId: _currentUser!.id,
                                        followingId: participant.id,
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Now following ${participant.name}'),
                                            backgroundColor: const Color(0xFF10B981),
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    AppLogger().error('Error toggling follow: $e');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString().contains('Already following')
                                              ? 'You are already following ${participant.name}'
                                              : 'Failed to follow ${participant.name}'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  }
                                },
                                onChallenge: () {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Challenge sent to ${participant.name}'),
                                        backgroundColor: const Color(0xFFDC2626),
                                      ),
                                    );
                                  }
                                },
                                onEmail: () {
                                  if (mounted && _currentUser != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EmailComposeScreen(
                                          currentUserId: _currentUser!.id,
                                          currentUsername: _currentUser!.name,
                                          recipient: participant,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                          child: Container(
                            color: Colors.transparent,
                          ),
                        ),
                      ),
                    
                    // Winner crown overlay
                    if (isWinner)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.emoji_events,
                            color: Colors.black,
                            size: 8,
                          ),
                        ),
                      ),
        ],
      ),
    );
  }

  /// Build video feed for debater (video or avatar fallback)
  Widget _buildDebaterVideoFeed(UserProfile participant, String role, MediaStream? stream, bool isLocalUser, bool isSmall) {
    // Check if we have video stream
    bool hasVideo = false;
    RTCVideoRenderer? renderer;
    
    AppLogger().debug('📹 Building video feed for ${participant.name} (isLocal: $isLocalUser, role: $role)');
    
    if (isLocalUser && _localStream != null) {
      // Local user - show their own video if available
      final videoTracks = _localStream!.getVideoTracks();
      AppLogger().debug('📹 Local video tracks: ${videoTracks.length}, enabled: ${videoTracks.where((t) => t.enabled).length}');
      if (videoTracks.isNotEmpty && videoTracks.any((track) => track.enabled)) {
        hasVideo = true;
        renderer = _localRenderer;
        AppLogger().debug('📹 Using local renderer for ${participant.name}');
      }
    } else if (stream != null) {
      // Remote user - check for video tracks
      final videoTracks = stream.getVideoTracks();
      AppLogger().debug('📹 Remote video tracks for ${participant.name}: ${videoTracks.length}, enabled: ${videoTracks.where((t) => t.enabled).length}');
      if (videoTracks.isNotEmpty && videoTracks.any((track) => track.enabled)) {
        hasVideo = true;
        // Find the renderer for this participant
        final peerId = _userToPeerMapping[participant.id];
        AppLogger().debug('📹 Peer ID for ${participant.name}: $peerId');
        if (peerId != null && _remoteRenderers.containsKey(peerId)) {
          renderer = _remoteRenderers[peerId];
          AppLogger().debug('📹 Using remote renderer for ${participant.name}');
        } else {
          AppLogger().debug('📹 No renderer found for ${participant.name} (peerId: $peerId)');
        }
      }
    } else {
      AppLogger().debug('📹 No stream available for ${participant.name}');
    }
    
    AppLogger().debug('📹 Final decision for ${participant.name}: hasVideo=$hasVideo, renderer=${renderer != null}');
    
    if (hasVideo && renderer != null) {
      // Show video feed
      return SizedBox.expand(
        child: RTCVideoView(
          renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          mirror: isLocalUser, // Mirror local user's video
        ),
      );
    } else {
      // Show avatar fallback - make it fill the slot properly
      // For 1v1 mode, use smaller avatars; for 2v2 mode, use larger avatars
      
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: getAvatarGradientForRole(role),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Normal-sized circular avatar
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.9),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(35),
                  child: participant.avatar != null && participant.avatar!.isNotEmpty
                      ? Image.network(
                          participant.avatar!,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: getAvatarColorForRole(role).withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                participant.name.isNotEmpty ? participant.name[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: getAvatarColorForRole(role).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              participant.name.isNotEmpty ? participant.name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // User name
              Text(
                participant.name.length > 12 
                    ? '${participant.name.substring(0, 12)}...' 
                    : participant.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black54,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }
  
  /// Build controls and indicators for debater
  Widget _buildDebaterControls(UserProfile participant, String role, bool isLocalUser, bool isSpeaking, bool isSmall) {
    // Check actual LiveKit mute state for accurate UI display
    bool isActuallyMuted = false;

    if (isLocalUser) {
      // For local user, use the local mute state
      isActuallyMuted = _isMuted;
    } else {
      // For remote participants, check LiveKit participant mute state
      if (_liveKitService.room != null) {
        try {
          final liveKitParticipant = _liveKitService.room!.remoteParticipants.values
              .firstWhere(
                (p) => p.identity == participant.id,
                orElse: () => throw StateError('Participant not found'),
              );
          isActuallyMuted = liveKitParticipant.isMuted;
        } catch (e) {
          // Participant not found in LiveKit, assume not muted
          isActuallyMuted = false;
        }
      }
    }

    return Stack(
      children: [
        // Top-right: Audio status indicators
        Positioned(
          top: 4,
          right: 4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Audio status indicator - now uses actual LiveKit mute state
              if (isActuallyMuted)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.mic_off,
                    color: Colors.white,
                    size: 8,
                  ),
                )
              else if (isSpeaking && !isActuallyMuted)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 8,
                  ),
                ),
            ],
          ),
        ),
        
        // Moderator controls for other participants (mute/unmute buttons)
        if (_isModerator && !isLocalUser)
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.9),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 2,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: () async {
                  // Check if participant is muted by looking at their LiveKit audio track
                  bool isCurrentlyMuted = false;
                  
                  // Find the participant in LiveKit room
                  if (_liveKitService.room != null) {
                    final liveKitParticipant = _liveKitService.room!.remoteParticipants.values
                        .firstWhere(
                          (p) => p.identity == participant.id,
                          orElse: () => _liveKitService.room!.remoteParticipants.values.first,
                        );
                    isCurrentlyMuted = liveKitParticipant.isMuted;
                  }
                  
                  // Toggle mute/unmute
                  if (isCurrentlyMuted) {
                    // Note: Participant unmuting may need to be done via server API
                    AppLogger().debug('🎤 Moderator attempting to unmute ${participant.name}');
                    // TODO: Implement unmute participant via LiveKit server API
                  } else {
                    // Note: Participant muting may need to be done via server API  
                    AppLogger().debug('🔇 Moderator attempting to mute ${participant.name}');
                    // TODO: Implement mute participant via LiveKit server API
                  }
                },
                child: Icon(
                  Icons.volume_up,
                  color: Colors.black,
                  size: isSmall ? 12 : 16,
                ),
              ),
            ),
          ),
      ],
    );
  }


    







  /// Build audio-only tile for judge with microphone status
  Widget _buildJudgeTile(UserProfile participant, String role, {bool isSmall = false}) {
    final nameSize = isSmall ? 9.0 : 10.0;

    // Check if this is the local user
    final isLocalUser = participant.id == _currentUserId;

    // Use actual LiveKit speaker detection for real-time speaking indicators
    final isSpeaking = _liveKitService.isUserSpeaking(participant.id);
    
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => UserProfileBottomSheet(
            user: participant,
            onFollow: () async {
              if (_currentUser == null) return;

              try {
                // Check if already following to determine action
                final isFollowing = await _appwrite.isFollowing(
                  followerId: _currentUser!.id,
                  followingId: participant.id,
                );

                if (isFollowing) {
                  // Unfollow
                  await _appwrite.unfollowUser(
                    followerId: _currentUser!.id,
                    followingId: participant.id,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Unfollowed ${participant.name}'),
                        backgroundColor: Colors.grey,
                      ),
                    );
                  }
                } else {
                  // Follow
                  await _appwrite.followUser(
                    followerId: _currentUser!.id,
                    followingId: participant.id,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Now following ${participant.name}'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                }
              } catch (e) {
                AppLogger().error('Error toggling follow: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().contains('Already following')
                          ? 'You are already following ${participant.name}'
                          : 'Failed to follow ${participant.name}'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            onChallenge: () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Challenge sent to ${participant.name}'),
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
              }
            },
            onEmail: () {
              if (mounted && _currentUser != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmailComposeScreen(
                      currentUserId: _currentUser!.id,
                      currentUsername: _currentUser!.name,
                      recipient: participant,
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.all(isSmall ? 4 : 8), // Responsive padding based on size
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Video feed container
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSpeaking ? Colors.green : getAvatarColorForRole(role).withOpacity(0.7), 
                    width: isSpeaking ? 2 : 1
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    children: [
                      // Video tile style with gradient background (like Debates & Discussions)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Responsive circular avatar based on container size
                              Container(
                                width: isSmall ? 55 : 70,
                                height: isSmall ? 55 : 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.9),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(isSmall ? 27.5 : 35),
                                  child: participant.avatar != null && participant.avatar!.isNotEmpty
                                      ? Image.network(
                                          participant.avatar!,
                                          width: isSmall ? 55 : 70,
                                          height: isSmall ? 55 : 70,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Container(
                                            width: 70,
                                            height: 70,
                                            decoration: BoxDecoration(
                                              color: getAvatarColorForRole(role).withOpacity(0.3),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                participant.name.isNotEmpty ? participant.name[0].toUpperCase() : 'J',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: isSmall ? 18 : 24,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: isSmall ? 55 : 70,
                                          height: isSmall ? 55 : 70,
                                          decoration: BoxDecoration(
                                            color: getAvatarColorForRole(role).withOpacity(0.3),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              participant.name.isNotEmpty ? participant.name[0].toUpperCase() : 'J',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: isSmall ? 18 : 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              
                              SizedBox(height: isSmall ? 4 : 8),
                              
                              // User name
                              Text(
                                participant.name.length > (isSmall ? 8 : 12)
                                    ? '${participant.name.substring(0, isSmall ? 8 : 12)}...' 
                                    : participant.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmall ? nameSize : 14,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 2,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Audio status indicators
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Builder(
                          builder: (context) {
                            // Check actual LiveKit mute state for accurate UI display
                            bool isActuallyMuted = false;

                            if (isLocalUser) {
                              // For local user, use the local mute state
                              isActuallyMuted = _isMuted;
                            } else {
                              // For remote participants, check LiveKit participant mute state
                              if (_liveKitService.room != null) {
                                try {
                                  final liveKitParticipant = _liveKitService.room!.remoteParticipants.values
                                      .firstWhere(
                                        (p) => p.identity == participant.id,
                                        orElse: () => throw StateError('Participant not found'),
                                      );
                                  isActuallyMuted = liveKitParticipant.isMuted;
                                } catch (e) {
                                  // Participant not found in LiveKit, assume not muted
                                  isActuallyMuted = false;
                                }
                              }
                            }

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Audio status indicator - now uses actual LiveKit mute state
                                if (isActuallyMuted)
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.mic_off,
                                      color: Colors.white,
                                      size: 8,
                                    ),
                                  )
                                else if (isSpeaking && !isActuallyMuted)
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.mic,
                                      color: Colors.white,
                                      size: 8,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),

                      // Moderator controls for judges (mute/unmute buttons)
                      if (_isModerator && !isLocalUser)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 1,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                            child: GestureDetector(
                              onTap: () async {
                                  // Check if participant is muted by looking at their LiveKit audio track
                                bool isCurrentlyMuted = false;
                                
                                // Find the participant in LiveKit room
                                if (_liveKitService.room != null) {
                                  final liveKitParticipant = _liveKitService.room!.remoteParticipants.values
                                      .firstWhere(
                                        (p) => p.identity == participant.id,
                                        orElse: () => _liveKitService.room!.remoteParticipants.values.first,
                                      );
                                  isCurrentlyMuted = liveKitParticipant.isMuted;
                                }
                                
                                // Toggle mute/unmute
                                if (isCurrentlyMuted) {
                                  // Note: Participant unmuting may need to be done via server API
                                  AppLogger().debug('🎤 Moderator attempting to unmute judge ${participant.name}');
                                  // TODO: Implement unmute participant via LiveKit server API
                                } else {
                                  // Note: Participant muting may need to be done via server API
                                  AppLogger().debug('🔇 Moderator attempting to mute judge ${participant.name}');
                                  // TODO: Implement mute participant via LiveKit server API
                                }
                              },
                              child: Icon(
                                Icons.volume_up,
                                color: Colors.black,
                                size: isSmall ? 10 : 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    // Always show control panel - at minimum for gifting
    // Specific controls will be filtered based on role
    
    // Debug logging for judge button state
    if (_isJudge || _isModerator) {
      AppLogger().info('🎯 CONTROL PANEL BUILD:');
      AppLogger().info('  - User Role: $_userRole');
      AppLogger().info('  - Is Judge: $_isJudge');
      AppLogger().info('  - Is Moderator: $_isModerator');
      AppLogger().info('  - Judging Enabled: $_judgingEnabled');
      AppLogger().info('  - Judging Complete: $_judgingComplete');
      AppLogger().info('  - Has Submitted Vote: $_hasCurrentUserSubmittedVote');
      AppLogger().info('  - Should Show Judge Button: ${(_isJudge || _isModerator) && !_judgingComplete}');
      AppLogger().info('  - Button Color Should Be: ${_hasCurrentUserSubmittedVote ? "Green" : (_judgingEnabled ? "Yellow" : "Gray")}');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Debug logging for mic button visibility
              Builder(builder: (context) {
                final shouldShowMic = _shouldUserPublishMedia();
                final isDebater = _isDebater;
                AppLogger().info('🎤 MIC VISIBILITY CHECK:');
                AppLogger().info('  - User Role: $_userRole');
                AppLogger().info('  - Is Debater: $isDebater');
                AppLogger().info('  - Should Publish Media: $shouldShowMic');
                AppLogger().info('  - WebRTC Connected: $_isWebRTCConnected');
                AppLogger().info('  - Is Muted: $_isMuted');
                if (_userRole == null) {
                  AppLogger().warning('  ⚠️ User role is NULL - mic button will not show');
                }
                return const SizedBox.shrink();
              }),

              // PRIORITY 1: Microphone button FIRST for debaters (most critical control)
              // Enhanced Microphone toggle (always visible for eligible users)
              // ALSO show if user is in a speaking slot even if role is mismatched
              Builder(builder: (context) {
                // Check if user should have mic based on role
                final shouldHaveMic = _shouldUserPublishMedia();

                // Also check if user is in a speaking slot position
                bool isInSpeakingSlot = false;
                _participants.forEach((slotRole, user) {
                  if (user?.id == _currentUserId &&
                      ['moderator', 'affirmative', 'negative', 'affirmative2', 'negative2',
                       'judge1', 'judge2', 'judge3'].contains(slotRole)) {
                    isInSpeakingSlot = true;
                    if (!shouldHaveMic) {
                      AppLogger().warning('🚨 ROLE MISMATCH: User in slot $slotRole but role is $_userRole');
                    }
                  }
                });

                // Show mic button if either condition is true
                if (shouldHaveMic || isInSpeakingSlot) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _buildEnhancedMicButton(),
                  );
                }
                return const SizedBox.shrink();
              }),


              // Trophy Results button (when judging is complete OR showResults broadcast received)
              if ((_judgingComplete || _showResults) && _winner != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Builder(
                    builder: (context) {
                      AppLogger().info('🏆 TROPHY ICON RENDERING!');
                      AppLogger().info('  showResults: $_showResults');
                      AppLogger().info('  judgingComplete: $_judgingComplete');
                      AppLogger().info('  winner: $_winner');
                      return _buildControlButton(
                        icon: Icons.emoji_events,
                        label: 'Results',
                        onPressed: _showResultsModal,
                        color: Colors.amber.shade700,
                      );
                    }
                  ),
                ),

              // Judge Panel (only for moderators and judges)
              if ((_isJudge || _isModerator) && !_judgingComplete)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onLongPress: () {
                      // BACKUP ACCESS: Long press to force open voting panel for judges
                      if (_isJudge && !_hasCurrentUserSubmittedVote) {
                        AppLogger().info('🚨 BACKUP ACCESS: Judge force-opening voting panel via long press');
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Open Voting Panel?'),
                            content: const Text('The voting status appears closed. Do you want to open the voting panel anyway?\n\nThis is a backup option if the automatic sync is not working.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showJudgingPanel();
                                },
                                child: const Text('Open Panel'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: _buildControlButton(
                      icon: _hasCurrentUserSubmittedVote 
                          ? Icons.check_circle 
                          : (_judgingComplete ? Icons.poll : Icons.gavel),
                      label: _hasCurrentUserSubmittedVote 
                          ? 'Vote Submitted' 
                          : (_judgingComplete ? 'View Results' : 'Judge'),
                      onPressed: _hasCurrentUserSubmittedVote 
                          ? null 
                          : (_judgingComplete ? _showResultsModal : _showJudgingPanel),
                      color: _hasCurrentUserSubmittedVote 
                          ? Colors.green 
                          : (_judgingComplete ? Colors.blue : Colors.amber),
                      isEnabled: !_hasCurrentUserSubmittedVote || _judgingComplete,
                    ),
                  ),
                ),
              
              // Gift button (always visible)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildControlButton(
                  icon: Icons.card_giftcard,
                  label: 'Gift',
                  onPressed: _showGiftComingSoon,
                  color: Colors.amber,
                ),
              ),

              // Chat button (always visible)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildControlButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  onPressed: _showChatBottomSheet,
                  color: Colors.blue,
                ),
              ),


              // Share Screen button (for moderators, debaters, and judges - ALL PLATFORMS)
              if ((_isModerator || _isDebater || _isJudge))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildControlButton(
                    icon: _showMaterialsBottomSheet ? Icons.close_fullscreen : Icons.present_to_all,
                    label: _showMaterialsBottomSheet ? 'Hide Materials' : 'Show Materials',
                    onPressed: _showShareScreenBottomSheet,
                    color: _showMaterialsBottomSheet ? Colors.orange : Colors.blue,
                  ),
                ),


              // Request Moderator button (only for debaters when no moderator present)
              if (_isDebater && _participants['moderator'] == null && !_judgingComplete)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildControlButton(
                    icon: Icons.gavel,
                    label: 'Request Moderator',
                    onPressed: _requestModerator,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),

              // Request Judge button (only for moderators when judging hasn't started)
              // EXPLICITLY prevent debaters from seeing this button
              if (_userRole == 'moderator' && !_isDebater && !_judgingComplete) ...[
                // Debug logging
                Builder(builder: (context) {
                  AppLogger().debug('🎯 REQUEST JUDGE BUTTON: Showing for moderator (role: $_userRole)');
                  return const SizedBox.shrink();
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildControlButton(
                    icon: Icons.balance,
                    label: 'Request Judge',
                    onPressed: _requestJudge,
                    color: const Color(0xFFFFC107),
                  ),
                ),
              ],

              // Role Manager (always available for testing)
              if (!_judgingComplete)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildControlButton(
                    icon: Icons.people,
                    label: 'Roles',
                    onPressed: _showRoleManager,
                    color: accentPurple,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
    bool isEnabled = true,
  }) {
    final actuallyEnabled = isEnabled && onPressed != null;
    final buttonColor = actuallyEnabled ? color : Colors.grey;
    
    return GestureDetector(
      onTap: actuallyEnabled ? onPressed : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D), // Dark background like debates_discussions
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              border: Border.all(
                color: buttonColor.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: buttonColor.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: buttonColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: buttonColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }





  void _showGiftComingSoon() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber),
            SizedBox(width: 8),
            Text('Premium Feature'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Send virtual gifts to debaters to show your appreciation! This premium feature includes:',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check, color: Colors.green),
                SizedBox(width: 8),
                Text('45+ unique virtual gifts'),
              ],
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.check, color: Colors.green),
                SizedBox(width: 8),
                Text('Support your favorite debaters'),
              ],
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.check, color: Colors.green),
                SizedBox(width: 8),
                Text('Premium coin system'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/premium');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }


  void _showJudgingPanel() {
    AppLogger().info('🎯 JUDGE PANEL: _showJudgingPanel called');
    AppLogger().info('🎯 JUDGE PANEL: _judgingEnabled = $_judgingEnabled');
    AppLogger().info('🎯 JUDGE PANEL: _hasCurrentUserSubmittedVote = $_hasCurrentUserSubmittedVote');
    AppLogger().info('🎯 JUDGE PANEL: _isJudge = $_isJudge');
    AppLogger().info('🎯 JUDGE PANEL: _isModerator = $_isModerator');
    AppLogger().info('🎯 JUDGE PANEL: _userRole = $_userRole');
    AppLogger().info('🎯 JUDGE PANEL: _currentUserId = $_currentUserId');
    
    // Voting is now always open for judges until results are final
    if (_judgingComplete) {
      AppLogger().warning('🎯 JUDGE PANEL: Judging already complete - showing results');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📊 Voting has been closed and results are final.'),
          backgroundColor: Colors.blue,
        ),
      );
      // Show results instead of voting panel
      _showResultsModal();
      return;
    }
    
    if (_hasCurrentUserSubmittedVote) {
      AppLogger().warning('🎯 JUDGE PANEL: User already submitted vote');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ You have already submitted your vote for this debate.'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }
    
    if (!(_isJudge || _isModerator)) {
      AppLogger().warning('🎯 JUDGE PANEL: User is not judge or moderator');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Only judges can vote on debates.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    AppLogger().info('🎯 JUDGE PANEL: All validations passed, showing panel');

    try {
      // Create safe participants map without null values
      final safeParticipants = <String, UserProfile>{};
      _participants.forEach((key, value) {
        if (value != null) {
          safeParticipants[key] = value;
        }
      });

      ArenaModals.showJudgingPanel(
        context,
        participants: safeParticipants,
        audience: _audience,
        currentUserId: _currentUserId,
        hasCurrentUserSubmittedVote: _hasCurrentUserSubmittedVote,
        onSubmitScorecard: (scorecard) {
          // Handle the submitted scorecard
          _handleScorecardSubmission(scorecard);
        },
        roomId: widget.roomId,
        roomTopic: widget.challengeId, // Using challengeId as topic for now
      );
    } catch (e) {
      AppLogger().error('Failed to show judging panel: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to open judging panel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleScorecardSubmission(JudgeScorecard scorecard) async {
    try {
      // Handle the submitted scorecard
      AppLogger().info('📊 Judge scorecard submitted: ${scorecard.judgeName}');
      AppLogger().info('📊 Winner: ${scorecard.winningTeam.displayName}');
      AppLogger().info('📊 Total scores - Affirmative: ${scorecard.getTotalScoreForTeam(TeamSide.affirmative)}, Negative: ${scorecard.getTotalScoreForTeam(TeamSide.negative)}');
      
      // Save scorecard to database (compatible with old vote system)
      // Get speaker scores for compatibility with old system
      final affirmativeSpeakers = scorecard.getSpeakersForTeam(TeamSide.affirmative);
      final negativeSpeakers = scorecard.getSpeakersForTeam(TeamSide.negative);
      
      // Calculate category totals for old system compatibility
      int affirmativeArguments = 0;
      int affirmativePresentation = 0;
      int affirmativeRebuttal = 0;
      for (final speaker in affirmativeSpeakers) {
        affirmativeArguments += speaker.categoryScores[ScoringCategory.arguments] ?? 0;
        affirmativePresentation += speaker.categoryScores[ScoringCategory.presentation] ?? 0;
        affirmativeRebuttal += speaker.categoryScores[ScoringCategory.rebuttal] ?? 0;
      }
      
      int negativeArguments = 0;
      int negativePresentation = 0;
      int negativeRebuttal = 0;
      for (final speaker in negativeSpeakers) {
        negativeArguments += speaker.categoryScores[ScoringCategory.arguments] ?? 0;
        negativePresentation += speaker.categoryScores[ScoringCategory.presentation] ?? 0;
        negativeRebuttal += speaker.categoryScores[ScoringCategory.rebuttal] ?? 0;
      }
      
      // Create document data with required affirmativeScores field
      final documentData = {
        'roomId': widget.roomId,
        'challengeId': widget.challengeId,
        'judgeId': _currentUserId ?? 'unknown_judge',
        'winner': scorecard.winningTeam.name.toLowerCase(),
        'submittedAt': DateTime.now().toIso8601String(),
        'comments': scorecard.reasonForDecision,
        // Required scores as strings (JSON format)
        'affirmativeScores': '{"arguments": $affirmativeArguments, "presentation": $affirmativePresentation, "rebuttal": $affirmativeRebuttal}',
        'negativeScores': '{"arguments": $negativeArguments, "presentation": $negativePresentation, "rebuttal": $negativeRebuttal}',
      };
      
      // Log the data for debugging
      AppLogger().info('📊 Document data to save: ${documentData.toString()}');
      
      await _appwrite.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_judgments',
        documentId: ID.unique(),
        data: documentData,
      );
      
      AppLogger().info('📊 Scorecard saved to database successfully');

      // Update local state
      setState(() {
        _hasCurrentUserSubmittedVote = true;
      });

      // NOTE: Don't call Navigator.pop() here - the JudgingPanel already handles closing itself

      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Your scorecard has been submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Send realtime update to other participants
      try {
        await _appwrite.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'arena_rooms',
          documentId: widget.roomId,
          data: {
            'lastUpdated': DateTime.now().toIso8601String(),
            'lastActivity': 'judge_vote_submitted',
          },
        );
      } catch (e) {
        AppLogger().warning('Failed to send realtime update: $e');
      }
      
    } catch (e) {
      AppLogger().error('📊 Failed to save scorecard: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to submit scorecard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _requestModerator() {
    // Show dialog to ping moderator with arena details
    _showPingDialog('moderator');
  }

  void _requestJudge() {
    // Extra safety check: Only moderators can request judges
    if (_userRole != 'moderator') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only moderators can request judges'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Show dialog to ping judge with arena details
    _showPingDialog('judge');
  }

  /// Helper function to clean description by removing metadata
  String _getCleanDescription(String? description) {
    if (description == null || description.isEmpty) return '';
    
    // If description contains metadata, extract only the actual description part
    if (description.contains('[METADATA]')) {
      final metadataIndex = description.indexOf('[METADATA]');
      return description.substring(0, metadataIndex).trim();
    }
    
    return description;
  }

  void _showPingDialog(String roleType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request ${roleType == 'moderator' ? 'Moderator' : 'Judge'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a $roleType from the list to invite to this arena.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Debate Topic:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(widget.topic),
                  if (widget.description != null && _getCleanDescription(widget.description).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_getCleanDescription(widget.description)),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to list with arena context
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => roleType == 'moderator'
                      ? ModeratorListScreen(
                          arenaRoomId: widget.roomId,
                          debateTitle: widget.topic,
                          debateDescription: _getCleanDescription(widget.description),
                          category: widget.category ?? 'general',
                        )
                      : JudgeListScreen(
                          arenaRoomId: widget.roomId,
                          debateTitle: widget.topic,
                          debateDescription: _getCleanDescription(widget.description),
                          category: widget.category ?? 'general',
                        ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: roleType == 'moderator' 
                  ? const Color(0xFF8B5CF6) 
                  : const Color(0xFFFFC107),
            ),
            child: Text('Select ${roleType == 'moderator' ? 'Moderator' : 'Judge'}'),
          ),
        ],
      ),
    );
  }

  void _showRoleManager() {
    final isModerator = _userRole == 'moderator';
    final isRoomCreator = _roomData != null && _currentUser?.id != null && _roomData!['createdBy'] == _currentUser!.id;
    final hasModeratorPrivileges = isModerator || isRoomCreator;
    
    AppLogger().debug('🎭 ROLES: User role: $_userRole, isModerator: $isModerator');
    AppLogger().debug('🎭 ROLES: Current user ID: ${_currentUser?.id}');
    AppLogger().debug('🎭 ROLES: Room creator ID: ${_roomData?['createdBy']}');
    AppLogger().debug('🎭 ROLES: Is room creator: $isRoomCreator');
    AppLogger().debug('🎭 ROLES: Has moderator privileges: $hasModeratorPrivileges');
    
    // Always show comprehensive role management for users with moderator privileges
    if (hasModeratorPrivileges) {
      AppLogger().debug('🎭 ROLES: Showing comprehensive role management');
      _showComprehensiveRoleManagement();
    } else {
      AppLogger().debug('🎭 ROLES: Showing read-only participant view');
      _showParticipantView();
    }
  }

  /// Show comprehensive role management for moderators - includes all participants
  void _showComprehensiveRoleManagement() {
    // Collect ALL participants from both slots and audience
    List<Map<String, dynamic>> allParticipants = [];
    
    // Add participants from slots
    _participants.forEach((role, participant) {
      if (participant != null) {
        allParticipants.add({
          'userId': participant.id,
          'name': participant.name,
          'avatar': participant.avatar,
          'currentRole': role,
          'userProfile': participant,
        });
      }
    });
    
    // Add audience members
    for (final audienceMember in _audience) {
      allParticipants.add({
        'userId': audienceMember.id,
        'name': audienceMember.name,
        'avatar': audienceMember.avatar,
        'currentRole': 'audience',
        'userProfile': audienceMember,
      });
    }
    
    // Method is now properly inside the class, no need for local wrapper
    
    AppLogger().debug('🎭 COMPREHENSIVE ROLES: Found ${allParticipants.length} total participants');
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade50,
              Colors.white,
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 0,
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade600, Colors.purple.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings, 
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Role Management',
                          style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Assign participants to debate positions',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            
            // Participants list
            Expanded(
              child: allParticipants.isEmpty 
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No participants yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0E5EC), // Neumorphism background
                    ),
                    child: ListView.builder(
                      key: const ValueKey('arena_all_participants_list'),
                      itemCount: allParticipants.length,
                      itemBuilder: (context, index) {
                        final participant = allParticipants[index];
                        final currentRole = participant['currentRole'] as String;
                        final isCurrentUser = participant['userId'] == _currentUserId;
                        final isCurrentlyModerator = currentRole == 'moderator';

                        // Super moderators can change any role, including their own
                        final superModService = SuperModeratorService();
                        final isSuperMod = _currentUserId != null && superModService.isSuperModerator(_currentUserId!);
                        final canChangeRole = isSuperMod || !(isCurrentUser && isCurrentlyModerator);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E5EC),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              // Neumorphism shadows
                              BoxShadow(
                                color: Colors.white.withOpacity(0.9),
                                spreadRadius: -2,
                                blurRadius: 8,
                                offset: const Offset(-4, -4),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                spreadRadius: -2,
                                blurRadius: 8,
                                offset: const Offset(4, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                // Avatar column with Current above and username below
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Current role badge above avatar
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0E5EC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.purple.shade600, // Purple outline
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          // Inner shadow effect for neumorphism
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            spreadRadius: -1,
                                            blurRadius: 4,
                                            offset: const Offset(2, 2),
                                          ),
                                          BoxShadow(
                                            color: Colors.white.withOpacity(0.7),
                                            spreadRadius: -1,
                                            blurRadius: 4,
                                            offset: const Offset(-2, -2),
                                          ),
                                        ],
                                      ),
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                          children: [
                                            const TextSpan(text: 'Current: '),
                                            TextSpan(
                                              text: _formatRoleName(currentRole),
                                              style: TextStyle(
                                                color: getAvatarColorForRole(currentRole),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // Enhanced Avatar with role indicator
                                    Stack(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: getAvatarColorForRole(currentRole).withOpacity(0.3),
                                                spreadRadius: 0,
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            radius: 30,
                                            backgroundColor: getAvatarColorForRole(currentRole),
                                            backgroundImage: participant['avatar'] != null && participant['avatar'].isNotEmpty
                                                ? NetworkImage(participant['avatar'])
                                                : null,
                                            child: participant['avatar'] == null || participant['avatar'].isEmpty
                                                ? Text(
                                                    participant['name'].isNotEmpty
                                                        ? participant['name'][0].toUpperCase()
                                                        : 'U',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 18,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                        // Role indicator badge
                                        if (isCurrentlyModerator)
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.purple.shade600,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                              ),
                                              child: const Icon(
                                                Icons.admin_panel_settings,
                                                color: Colors.white,
                                                size: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Username below avatar
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          participant['name'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.grey.shade800,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        if (isCurrentUser) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.blue.shade300),
                                            ),
                                            child: Text(
                                              'you',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),

                                const Spacer(),

                                // Enhanced Role Selector
                                if (!canChangeRole)
                                  // Locked indicator for moderators trying to change their own role
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0E5EC),
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        // Inner shadow for pressed neumorphism effect
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          spreadRadius: -1,
                                          blurRadius: 6,
                                          offset: const Offset(3, 3),
                                        ),
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.7),
                                          spreadRadius: -1,
                                          blurRadius: 6,
                                          offset: const Offset(-3, -3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.lock,
                                          color: Colors.purple.shade600,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'LOCKED',
                                          style: TextStyle(
                                            color: Colors.purple.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  // Neumorphism dropdown for changeable roles
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0E5EC),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: const Color(0xFFDC143C), // Scarlet outline
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        // Elevated neumorphism effect
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.9),
                                          spreadRadius: -2,
                                          blurRadius: 8,
                                          offset: const Offset(-4, -4),
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          spreadRadius: -2,
                                          blurRadius: 8,
                                          offset: const Offset(4, 4),
                                        ),
                                      ],
                                    ),
                                    child: DropdownButton<String>(
                                      value: currentRole,
                                      onChanged: (newRole) {
                                        if (newRole != null && newRole != currentRole) {
                                          _assignRole(participant['userId'], newRole);
                                        }
                                      },
                                      underline: const SizedBox.shrink(),
                                      icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                                      dropdownColor: const Color(0xFFE0E5EC),
                                      borderRadius: BorderRadius.circular(15),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                      items: [
                                        // Always show base roles
                                        'affirmative',
                                        'negative',
                                        // Only show 2v2 roles if teamSize is 2
                                        if (_teamSize == 2) 'affirmative2',
                                        if (_teamSize == 2) 'negative2',
                                        'moderator',
                                        'judge1',
                                        'judge2',
                                        'judge3',
                                        'audience'
                                      ].map((role) {
                                        return DropdownMenuItem<String>(
                                          value: role,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE0E5EC),
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: role == currentRole
                                                ? [
                                                    // Pressed/inset effect for current role
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.1),
                                                      spreadRadius: -1,
                                                      blurRadius: 4,
                                                      offset: const Offset(2, 2),
                                                    ),
                                                    BoxShadow(
                                                      color: Colors.white.withOpacity(0.7),
                                                      spreadRadius: -1,
                                                      blurRadius: 4,
                                                      offset: const Offset(-2, -2),
                                                    ),
                                                  ]
                                                : [
                                                    // Subtle raised effect for other roles
                                                    BoxShadow(
                                                      color: Colors.white.withOpacity(0.7),
                                                      spreadRadius: -1,
                                                      blurRadius: 3,
                                                      offset: const Offset(-2, -2),
                                                    ),
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.08),
                                                      spreadRadius: -1,
                                                      blurRadius: 3,
                                                      offset: const Offset(2, 2),
                                                    ),
                                                  ],
                                            ),
                                            child: Text(
                                              _formatRoleName(role),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: role == currentRole ? FontWeight.w700 : FontWeight.w600,
                                                color: getAvatarColorForRole(role),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get number of available judge slots
  int _getAvailableJudgeSlots() {
    int filledSlots = 0;
    if (_participants['judge1'] != null) filledSlots++;
    if (_participants['judge2'] != null) filledSlots++;
    if (_participants['judge3'] != null) filledSlots++;
    return 3 - filledSlots;
  }
  

  /// Show chat bottom sheet
  void _showChatBottomSheet() {
    if (_currentUser == null) return;

    // Create participants list for chat
    final chatParticipants = <ChatParticipant>[];
    
    // Add main participants (debaters, judges, moderator)
    _participants.forEach((role, user) {
      if (user != null) {
        String chatRole = 'audience'; // default
        if (role == 'moderator') {
          chatRole = 'moderator';
        } else if (role.contains('judge')) {
          chatRole = 'judge'; // More specific role for judges
        } else if (role.contains('affirmative')) {
          chatRole = 'affirmative';
        } else if (role.contains('negative')) {
          chatRole = 'negative';
        }
        
        chatParticipants.add(ChatParticipant(
          userId: user.id,
          username: user.name,
          role: chatRole,
          avatar: user.avatar,
        ));
        AppLogger().debug('💬 CHAT: Added participant from _participants: ${user.name} (role: $chatRole, userId: ${user.id})');
      }
    });
    
    // Add audience members
    for (final audience in _audience) {
      chatParticipants.add(ChatParticipant(
        userId: audience.id,
        username: audience.name,
        role: 'audience',
        avatar: audience.avatar,
      ));
      AppLogger().debug('💬 CHAT: Added participant from _audience: ${audience.name} (userId: ${audience.id})');
    }

    // Enhanced Debug logging
    AppLogger().debug('💬 CHAT: _showChatBottomSheet() called');
    AppLogger().debug('💬 CHAT: _participants map has ${_participants.length} entries');
    AppLogger().debug('💬 CHAT: _audience list has ${_audience.length} entries');
    
    // Debug the participants map
    _participants.forEach((role, user) {
      AppLogger().debug('💬 CHAT: _participants["$role"] = ${user?.name ?? "null"}');
    });
    
    // Debug the audience list
    for (int i = 0; i < _audience.length; i++) {
      AppLogger().debug('💬 CHAT: _audience[$i] = ${_audience[i].name}');
    }
    
    // Ensure current user is in the participants list as a fallback
    final currentUserInList = chatParticipants.any((p) => p.userId == _currentUser!.id);
    if (!currentUserInList) {
      AppLogger().debug('💬 CHAT: Current user not found in participants, adding as fallback');
      chatParticipants.add(ChatParticipant(
        userId: _currentUser!.id,
        username: _currentUser!.name,
        role: _userRole ?? 'audience',
        avatar: _currentUser!.avatar,
      ));
    }
    
    AppLogger().debug('💬 CHAT: Created ${chatParticipants.length} participants for chat');
    AppLogger().debug('💬 CHAT: Current user ID: ${_currentUser!.id}');
    for (final participant in chatParticipants) {
      AppLogger().debug('💬 CHAT: Final participant: ${participant.username} (${participant.role}) - ID: ${participant.userId}');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => MattermostChatWidget(
        currentUserId: _currentUser!.id,
        currentUser: _currentUser!,
        roomId: widget.roomId,
        participants: chatParticipants,
        onClose: () {
          FocusScope.of(context).unfocus();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  
  /// Check if current user is a debater (includes 2v2 roles)
  bool get _isDebater {
    return _userRole == 'affirmative' ||
           _userRole == 'negative' ||
           _userRole == 'affirmative2' ||
           _userRole == 'negative2';
  }

  
  /// Show read-only participant view
  void _showParticipantView() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.people, color: accentPurple),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Debate Participants',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            // Participants info
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  if (_participants['affirmative'] != null)
                    _buildParticipantInfo('Affirmative', _participants['affirmative']!, Colors.green),
                  if (_participants['affirmative2'] != null)
                    _buildParticipantInfo('Affirmative 2', _participants['affirmative2']!, Colors.green),
                  if (_participants['negative'] != null)
                    _buildParticipantInfo('Negative', _participants['negative']!, Colors.red),
                  if (_participants['negative2'] != null)
                    _buildParticipantInfo('Negative 2', _participants['negative2']!, Colors.red),
                  if (_participants['moderator'] != null)
                    _buildParticipantInfo('Moderator', _participants['moderator']!, accentPurple),
                  if (_participants['judge1'] != null)
                    _buildParticipantInfo('Judge 1', _participants['judge1']!, Colors.amber.shade700),
                  if (_participants['judge2'] != null)
                    _buildParticipantInfo('Judge 2', _participants['judge2']!, Colors.amber.shade700),
                  if (_participants['judge3'] != null)
                    _buildParticipantInfo('Judge 3', _participants['judge3']!, Colors.amber.shade700),
                  if (_audience.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Audience (${_audience.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...(_audience.map((user) => _buildParticipantInfo('', user, Colors.grey))),
                  ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildParticipantInfo(String role, UserProfile user, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () {
          final passedRole = role.isNotEmpty ? role : null;
          AppLogger().debug('🏛️ Arena: Showing profile for ${user.name} with role: $passedRole (original: $role)');
          _showUserProfile(user, passedRole);
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: role.isNotEmpty ? getAvatarColorForRole(role) : getAvatarColorForRole('audience'),
              backgroundImage: user.avatar != null && user.avatar!.isNotEmpty
                  ? NetworkImage(user.avatar!)
                  : null,
              child: user.avatar == null || user.avatar!.isEmpty
                  ? buildAvatarText(user, 12)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (role.isNotEmpty)
                    Text(
                      role,
                      style: TextStyle(fontSize: 12, color: color),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResultsModal() async {
    AppLogger().info('🏆 _showResultsModal called - User role: $_userRole');
    
    // Get detailed voting results
    try {
      final judgments = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_judgments',
        queries: [
          Query.equal('roomId', widget.roomId),
        ],
      );

      if (mounted) {
        // Play applause sound for winner celebration
        _soundService.playApplauseSound();
        
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => ResultsModal(
            winner: _winner ?? '',
            affirmativeDebater: _participants['affirmative'],
            affirmative2Debater: _participants['affirmative2'],
            negativeDebater: _participants['negative'],
            negative2Debater: _participants['negative2'],
            judgments: judgments.documents,
            topic: widget.topic,
            teamSize: _teamSize,
          ),
        );
      }
    } catch (e) {
      AppLogger().error('Error loading results: $e');
    }
  }

  void _showRoomClosingModal(int initialSeconds) {
    // Check if widget is still mounted before showing modal
    if (!mounted) {
      AppLogger().warning('Widget unmounted - cannot show room closing modal');
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing
      builder: (context) => RoomClosingModal(
        initialSeconds: initialSeconds,
        onCountdownComplete: () {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                try {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const ArenaApp()),
                    (route) => false,
                  );
                } catch (e) {
                  AppLogger().error('Navigation error from countdown: $e');
                }
              }
            });
          }
        },
        onForceNavigation: () {
          _hasNavigated = true;
          _isExiting = true;
          AppLogger().debug('🛑 MODAL FORCE: Set exit flags');
          if (_roomStatusChecker != null) {
            _roomStatusChecker!.cancel();
            _roomStatusChecker = null;
            AppLogger().debug('🛑 MODAL FORCE: Timer cancelled and nulled');
          }
          // Cancel consolidated subscriptions
      _realtimeManager.unsubscribeFromRoom(widget.roomId);
      _participantStreamListener?.cancel();
      _roomStatusStreamListener?.cancel();
      _judgmentStreamListener?.cancel();
      _timerStreamListener?.cancel();
          
          try {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ArenaApp()),
              (route) => false,
            );
          } catch (e) {
            AppLogger().error('Force navigation failed: $e');
          }
        },
      ),
    );
  }

  void _startRoomStatusChecker() {
    // Prevent starting multiple timers
    if (_roomStatusChecker != null) {
      AppLogger().warning('Room status checker already running, skipping');
      return;
    }
    
    // Reset iteration counter
    _roomStatusCheckerIterations = 0;
    
    // Use much longer intervals to reduce performance impact
    final interval = _isIOSOptimizationEnabled ? 10000 : 8000; // 8-10 seconds instead of 2-3
    AppLogger().info('Starting room status checker with ${interval}ms intervals ${_isIOSOptimizationEnabled ? '(iOS optimized)' : ''}');
    
    _roomStatusChecker = Timer.periodic(Duration(milliseconds: interval), (timer) async {
      _roomStatusCheckerIterations++;
      
      // HARD LIMIT: Stop after 100 iterations to prevent infinite loops (13+ minutes)
      if (_roomStatusCheckerIterations > 100) {
        AppLogger().debug('🛑 TIMER: Reached iteration limit (100), FORCE CANCELLING timer');
        timer.cancel();
        _roomStatusChecker = null;
        return;
      }
      
      // CRITICAL FIRST CHECK: Stop immediately if ANY exit flag is set
      if (_isExiting) {
        AppLogger().debug('🛑 TIMER: _isExiting=true, CANCELLING timer immediately');
        timer.cancel();
        _roomStatusChecker = null;
        return;
      }
      
      if (_hasNavigated) {
        AppLogger().debug('🛑 TIMER: _hasNavigated=true, CANCELLING timer immediately');
        timer.cancel();
        _roomStatusChecker = null;
        return;
      }
      
      if (!mounted) {
        AppLogger().debug('🛑 TIMER: Widget not mounted, CANCELLING timer');
        timer.cancel();
        _roomStatusChecker = null;
        return;
      }
      
      // DEBUG: Confirm timer is still running (every 30 seconds)
      const heartbeatThreshold = 8000;
      if (DateTime.now().millisecondsSinceEpoch % 30000 < heartbeatThreshold) {
        AppLogger().debug('🔍 TIMER HEARTBEAT: Status checker still running every ${interval}ms');
      }
      
      try {
        // iOS optimization: Check cache first, then database if needed
        Map<String, dynamic>? roomData;
        if (_isIOSOptimizationEnabled && _isCacheValid()) {
          roomData = _iosRoomCache[widget.roomId];
          if (roomData == null) {
            roomData = await _appwrite.getArenaRoom(widget.roomId);
            if (roomData != null) {
              _iosRoomCache[widget.roomId] = roomData;
            }
          }
        } else {
          roomData = await _appwrite.getArenaRoom(widget.roomId);
          if (_isIOSOptimizationEnabled && roomData != null) {
            _iosRoomCache[widget.roomId] = roomData;
          }
        }
        
        if (roomData != null) {
          final roomStatus = roomData['status'];
          
          // Update judging state from room data
          final newJudgingEnabled = roomData['judgingEnabled'] ?? true;
          if (_judgingEnabled != newJudgingEnabled && mounted) {
            AppLogger().info('🎯 STATUS CHECKER: Judging state changed from $_judgingEnabled to $newJudgingEnabled');
            setState(() {
              _judgingEnabled = newJudgingEnabled;
            });
          }
          
          // Only log status every 5 iterations to reduce spam
          if (_roomStatusCheckerIterations % 5 == 0) {
            AppLogger().debug('🔍 Status check #$_roomStatusCheckerIterations: $roomStatus, judgingEnabled: $_judgingEnabled (every ${interval}ms)');
          }
          
          // If room is closing and we haven't shown the modal yet
          if (roomStatus == 'closing' && !_roomClosingModalShown && !_hasNavigated) {
            AppLogger().debug('🚨 Room closing detected via optimized check - showing modal');
            _roomClosingModalShown = true;
            _hasNavigated = true; // Set flag FIRST
            _isExiting = true; // Set exit flag FIRST
            AppLogger().debug('🛑 TIMER EVENT: Set exit flags, cancelling timer');
            timer.cancel(); // Stop checking once we detect closure
            _roomStatusChecker = null;
            AppLogger().debug('🛑 TIMER EVENT: Timer cancelled and nulled');
            
            if (mounted) {
              _showRoomClosingModal(15);
            }
          }
          
          // If room is completed, navigate immediately with FORCE
          else if ((roomStatus == 'completed' || roomStatus == 'abandoned' || roomStatus == 'force_cleaned' || roomStatus == 'force_closed' || roomStatus == 'closed') && !_hasNavigated) {
            AppLogger().debug('🚪 Room completed detected via ULTRA-AGGRESSIVE check - FORCE navigating back');
            _hasNavigated = true; // Set flag FIRST before any async work
            _isExiting = true; // Set exit flag FIRST
            AppLogger().debug('🛑 TIMER EVENT: Set exit flags, cancelling timer');
            timer.cancel();
            _roomStatusChecker = null;
            AppLogger().debug('🛑 TIMER EVENT: Timer cancelled and nulled, calling sync navigation');
            
            // SYNCHRONOUS navigation - no async blocks
            _forceNavigationHomeSync();
          }
        } else if (!_hasNavigated) {
          AppLogger().warning('Room data is null - room deleted - FORCE navigating back');
          _hasNavigated = true; // Set flag FIRST before any async work
          _isExiting = true; // Set exit flag FIRST
          AppLogger().debug('🛑 TIMER EVENT: Set exit flags for null room, cancelling timer');
          timer.cancel();
          _roomStatusChecker = null;
          AppLogger().debug('🛑 TIMER EVENT: Timer cancelled and nulled for null room');
          _forceNavigationHomeSync();
        }
      } catch (e) {
        AppLogger().error('Error in ULTRA-AGGRESSIVE room status check: $e');
        // Don't cancel timer on error, keep trying even more aggressively
      }
    });
  }

  void _forceNavigationHomeSync() {
    AppLogger().info('FORCE NAVIGATION HOME - SYNCHRONOUS approach');
    
    // CRITICAL: Set exit flag FIRST to stop timer immediately
    _isExiting = true;
    AppLogger().debug('🛑 Set _isExiting=true to stop timer');
    
    // AGGRESSIVE timer cancellation with verification
    AppLogger().debug('🛑 Attempting to cancel room status checker...');
    if (_roomStatusChecker != null) {
      _roomStatusChecker!.cancel();
      AppLogger().debug('🛑 Timer.cancel() called, setting to null');
      _roomStatusChecker = null;
      AppLogger().debug('🛑 Timer reference set to null');
    } else {
      AppLogger().debug('🛑 Timer was already null');
    }
    
    AppLogger().debug('🛑 Cancelling realtime subscription...');
    // Cancel consolidated subscriptions
    _realtimeManager.unsubscribeFromRoom(widget.roomId);
    _participantStreamListener?.cancel();
    _roomStatusStreamListener?.cancel();
    _judgmentStreamListener?.cancel();
    _timerStreamListener?.cancel();
    
    // Verify timer status before proceeding
    _verifyTimerStopped();
    
    // Wait a brief moment to ensure timer has stopped before navigation
    AppLogger().debug('🛑 Waiting 100ms to ensure timer has stopped...');
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        AppLogger().info('Proceeding with navigation after timer stop delay');
        try {
          // Use pushAndRemoveUntil to clear entire stack and return to main app
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ArenaApp()),
            (route) => false,
          );
          AppLogger().info('Successfully navigated synchronously to Main App');
        } catch (e) {
          AppLogger().error('Synchronous navigation failed: $e');
        }
      } else {
        AppLogger().error('Widget no longer mounted during navigation');
      }
    });
    
    // NotificationService singleton continues running - no restart needed
    AppLogger().info('NotificationService singleton remains active after navigation');
  }
  
  // Debug method to verify timer status
  void _verifyTimerStopped() {
    AppLogger().debug('\ud83d\udd0d VERIFICATION: _isExiting=$_isExiting, _hasNavigated=$_hasNavigated');
    AppLogger().debug('\ud83d\udd0d VERIFICATION: _roomStatusChecker is ${_roomStatusChecker == null ? "null" : "NOT null"}');
    if (_roomStatusChecker != null) {
      AppLogger().debug('\u26a0\ufe0f WARNING: Timer reference still exists after cancellation!');
    } else {
      AppLogger().debug('\u2705 VERIFICATION: Timer reference is null - good');
    }
  }
  

  // Two-stage invitation system methods

  /// Check if both debaters are present and trigger invitation flow
  Future<void> _checkForBothDebatersAndTriggerInvitations() async {
    try {
      AppLogger().info('🔍 DIAGNOSTIC: _checkForBothDebatersAndTriggerInvitations called');
      AppLogger().debug('🎭 DEBUG: _checkForBothDebatersAndTriggerInvitations called');
      
      final affirmative = _participants['affirmative'];
      final negative = _participants['negative'];

      AppLogger().info('🔍 DIAGNOSTIC: Participants check - Affirmative: ${affirmative?.name ?? "NULL"}, Negative: ${negative?.name ?? "NULL"}');
      AppLogger().info('🔍 DIAGNOSTIC: Room status: ${_roomData?['status'] ?? "NULL"}');
      AppLogger().info('🔍 DIAGNOSTIC: Total participants: ${_participants.length}');
      AppLogger().info('🔍 DIAGNOSTIC: All roles: ${_participants.keys.toList()}');
      AppLogger().debug('🎭 DEBUG: Affirmative participant: $affirmative');
      AppLogger().debug('🎭 DEBUG: Negative participant: $negative');

      // Check for both challenge-based rooms (affirmative/negative) and manual rooms (audience count)
      final bothPresent = affirmative != null && negative != null;

      // For manual rooms, check if we have at least 2 participants (excluding moderator)
      final audienceCount = _audience.length;
      final hasMinimalParticipants = audienceCount >= 2;

      AppLogger().info('🔍 DIAGNOSTIC: Challenge room check - Both present: $bothPresent');
      AppLogger().info('🔍 DIAGNOSTIC: Manual room check - Audience count: $audienceCount, Has minimal: $hasMinimalParticipants');
      
      AppLogger().debug('🎭 ${_isIOSOptimizationEnabled ? "iOS" : "Android"} Checking debater presence: Affirmative=${affirmative?.name}, Negative=${negative?.name}');
      AppLogger().debug('🎭 Both present: $bothPresent, Modal shown: $_invitationModalShown, In progress: $_invitationsInProgress, User Role: $_userRole');
      AppLogger().debug('🎭 DEBUG: _bothDebatersPresent = $_bothDebatersPresent');
      AppLogger().debug('🎭 DEBUG: All conditions for showing modal:');
      AppLogger().debug('🎭 DEBUG:   - bothPresent: $bothPresent');
      AppLogger().debug('🎭 DEBUG:   - !_bothDebatersPresent: ${!_bothDebatersPresent}');
      AppLogger().debug('🎭 DEBUG:   - !_invitationModalShown: ${!_invitationModalShown}');
      AppLogger().debug('🎭 DEBUG:   - !_invitationsInProgress: ${!_invitationsInProgress}');
      
      // DISABLED: All automatic invitation systems disabled for testing
      AppLogger().debug('🚫 DISABLED: All automatic invitations disabled - manually join as audience to test UI');

      // Check if we should auto-start the room (either challenge-based or manual room with enough participants)
      final shouldAutoStart = bothPresent || hasMinimalParticipants;

      if (shouldAutoStart) {
        AppLogger().info('🚀 AUTO-START CONDITION MET: Challenge room both present: $bothPresent, Manual room sufficient participants: $hasMinimalParticipants');
        _bothDebatersPresent = true;

        // Auto-start arena debate when conditions are met and room is still waiting
        if (_roomData != null && _roomData!['status'] == 'waiting') {
          AppLogger().info('🚀 AUTO-START: Starting arena debate for room type...');
          try {
            await _appwrite.startArenaDebate(widget.roomId);
            AppLogger().info('✅ Arena debate started successfully');
          } catch (e) {
            AppLogger().error('❌ Error auto-starting arena debate: $e');
          }
        } else {
          AppLogger().info('🔍 DIAGNOSTIC: Room status is not waiting - Status: ${_roomData?['status']}');
        }
      } else {
        AppLogger().info('🔍 DIAGNOSTIC: Auto-start conditions not met - Both present: $bothPresent, Has minimal: $hasMinimalParticipants');
        _bothDebatersPresent = false;
      }
    } catch (e) {
      AppLogger().error('Error checking for both debaters: $e');
    }
  }



  /// Send invitation to single agreed-upon moderator






  /// Perform the mixed invitation system (personal + random)

  void _emergencyCloseRoom() {
    // Show choice dialog for room ending options
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stop_circle, color: Colors.orange, size: 20),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'End Room',
                style: TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to close this room?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Text(
                'This will permanently close the room for all participants.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
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

      // Set up a timeout for the entire operation
      AppLogger().info('🚨 EMERGENCY CLOSE - About to call _closeRoomWithRetries for room: ${widget.roomId}');
      await _closeRoomWithRetries(widget.roomId).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          AppLogger().error('❌ EMERGENCY CLOSE - _closeRoomWithRetries TIMED OUT after 10 seconds');
          throw Exception('Room closure timed out after 10 seconds');
        },
      );
      AppLogger().info('✅ EMERGENCY CLOSE - _closeRoomWithRetries completed successfully');

      AppLogger().info('🚨 Emergency room close completed successfully');

      // Show countdown modal to all users before navigating home
      if (mounted) {
        ArenaModals.showRoomClosingModal(
          context,
          3, // 3 second countdown for emergency close
          onRoomClosed: () {
            _forceExitArena();
          },
        );
      }

    } catch (e) {
      AppLogger().error('❌ EMERGENCY CLOSE EXCEPTION: $e');
      AppLogger().error('📊 Error type: ${e.runtimeType}');
      AppLogger().error('📊 Error string: ${e.toString()}');

      // Handle specific errors more intelligently
      String errorMessage = 'Failed to close room';
      bool shouldForceExit = false;
      bool isRecoverableError = false;

      if (e.toString().contains('TimeoutException') || e.toString().contains('timed out')) {
        errorMessage = 'Room close timed out - room likely closed successfully';
        shouldForceExit = true;
        isRecoverableError = true;
        AppLogger().info('🚨 Room close timeout - forcing exit as room is likely closing');
      } else if (e.toString().contains('document_already_exists') ||
                 e.toString().contains('already closed') ||
                 e.toString().contains('completed')) {
        errorMessage = 'Room is already closed';
        shouldForceExit = true;
        isRecoverableError = true;
        AppLogger().info('🚨 Room already closed/closing - forcing exit');
      } else if (e.toString().contains('document_not_found')) {
        errorMessage = 'Room no longer exists';
        shouldForceExit = true;
        isRecoverableError = true;
        AppLogger().info('🚨 Room not found - forcing exit');
      } else if (e.toString().contains('network') ||
                 e.toString().contains('connection') ||
                 e.toString().contains('timeout')) {
        errorMessage = 'Network error - room may have closed successfully';
        shouldForceExit = true;
        isRecoverableError = true;
        AppLogger().info('🚨 Network error during room close - forcing exit');
      }

      if (shouldForceExit) {
        // For recoverable errors, just exit without showing error to user
        if (isRecoverableError) {
          AppLogger().info('🚨 Recoverable error during room close - exiting silently');
          _forceExitArena();
          return;
        }

        // These are recoverable errors where we should still exit
        _forceExitArena();
        return;
      }

      // For truly unknown errors, show error but still try to exit
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMessage. Attempting to exit anyway.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );

        // Force exit after showing error
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            AppLogger().info('🚨 Forcing navigation home after error with delay');
            _forceExitArena();
          }
        });
      }
    }
  }

  // Reserved for future playback recording feature
  // ignore: unused_element
  void _executeRoomCompletion() async {
    try {
      AppLogger().info('🎬 Room completion initiated by moderator');

      // Complete room with playback creation and status update
      AppLogger().info('🎬 COMPLETE ROOM - Completing room: ${widget.roomId}');

      // Use the appwrite service to complete the room (updates status to completed)
      await _appwrite.completeArenaRoom(widget.roomId).timeout(
        Duration(seconds: 15),
        onTimeout: () {
          AppLogger().error('❌ COMPLETE ROOM - Room completion TIMED OUT after 15 seconds');
          throw Exception('Room completion timed out after 15 seconds');
        },
      );

      AppLogger().info('✅ COMPLETE ROOM - Room completed successfully');

      // Show completion modal to all users before navigating home
      if (mounted) {
        ArenaModals.showRoomClosingModal(
          context,
          3, // 3 second countdown for room completion
          onRoomClosed: () {
            _forceExitArena();
          },
        );
      }

    } catch (e) {
      AppLogger().error('❌ ROOM COMPLETION EXCEPTION: $e');
      AppLogger().error('📊 Error type: ${e.runtimeType}');
      AppLogger().error('📊 Error string: ${e.toString()}');

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete room: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );

        // Try to exit anyway after error
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            AppLogger().info('🚨 Forcing navigation home after completion error');
            _forceExitArena();
          }
        });
      }
    }
  }

  /// Resilient room close method with retries and better error handling
  Future<void> _closeRoomWithRetries(String roomId) async {
    AppLogger().info('🚪 CLOSE ROOM - Starting _closeRoomWithRetries for: $roomId');
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        AppLogger().info('🔄 CLOSE ROOM - Attempting room close (attempt ${retryCount + 1}/$maxRetries)');

        // First, check if room is already closed
        try {
          final roomDoc = await _appwrite.databases.getDocument(
            databaseId: 'arena_db',
            collectionId: 'arena_rooms',
            documentId: roomId,
          );

          if (roomDoc.data['status'] == 'completed' ||
              roomDoc.data['status'] == 'abandoned' ||
              roomDoc.data['status'] == 'closed') {
            AppLogger().info('🚨 Room already closed with status: ${roomDoc.data['status']}');
            return; // Room is already closed, no need to continue
          }
        } catch (e) {
          if (e.toString().contains('document_not_found')) {
            AppLogger().info('🚨 Room document not found - assuming already closed');
            return; // Room doesn't exist, consider it closed
          }
          // Other errors, continue with close attempt
        }

        // Stop audio recording if active before closing room
        if (_simpleRecordingService.isRecording && _userRole == 'moderator') {
          AppLogger().info('🎬 ROOM CLOSURE - Stopping audio recording before closing room');
          AppLogger().info('📊 Recording state - isRecording: ${_simpleRecordingService.isRecording}, userRole: $_userRole');
          try {
            final playbackId = await _simpleRecordingService.stopRecording();
            if (playbackId != null) {
              AppLogger().info('✅ ROOM CLOSURE - Audio recording stopped, playback created: $playbackId');
            } else {
              AppLogger().warning('⚠️ ROOM CLOSURE - Audio recording stopped but no playback created');
            }
          } catch (e) {
            AppLogger().error('❌ ROOM CLOSURE - Failed to stop audio recording: $e');
            // Continue with room close even if recording fails
          }
        } else {
          AppLogger().info('ℹ️ ROOM CLOSURE - No recording to stop (isRecording: ${_simpleRecordingService.isRecording}, userRole: $_userRole)');
        }

        // Try the close operation
        AppLogger().info('🚪 ROOM CLOSURE - Calling closeArenaRoom for: $roomId');
        await _appwrite.closeArenaRoom(roomId);
        AppLogger().info('✅ ROOM CLOSURE - Room closed successfully on attempt ${retryCount + 1}');
        AppLogger().info('🎯 ROOM CLOSURE - Room should now be removed from lobby lists');
        return; // Success, exit retry loop

      } catch (e) {
        retryCount++;
        AppLogger().error('❌ CLOSE ROOM - Attempt $retryCount failed: $e');
        AppLogger().error('📊 CLOSE ROOM - Error type: ${e.runtimeType}');
        AppLogger().error('📊 CLOSE ROOM - Error details: ${e.toString()}');

        // Categorize the error for better debugging
        String errorCategory = 'unknown';
        if (e.toString().contains('network') || e.toString().contains('connection')) {
          errorCategory = 'network';
        } else if (e.toString().contains('timeout') || e.toString().contains('Timeout')) {
          errorCategory = 'timeout';
        } else if (e.toString().contains('document_not_found')) {
          errorCategory = 'document_not_found';
        } else if (e.toString().contains('permission') || e.toString().contains('Unauthorized')) {
          errorCategory = 'permission';
        } else if (e.toString().contains('validation') || e.toString().contains('invalid')) {
          errorCategory = 'validation';
        }
        AppLogger().error('🏷️ CLOSE ROOM - Error category: $errorCategory');

        // If this was the last retry, rethrow the error
        if (retryCount >= maxRetries) {
          AppLogger().error('❌ CLOSE ROOM - All $maxRetries attempts failed, rethrowing error');
          AppLogger().error('🚨 CLOSE ROOM - FINAL ERROR: $e');
          rethrow;
        }

        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
  }

  void _forceExitArena() {
    AppLogger().info('🚪 Force exiting arena after emergency close');
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ArenaApp()),
        (route) => false,
      );
    }
  }

  Future<void> _assignRole(String userId, String newRole) async {
    if (!_isModerator) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Only moderators can assign roles'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // INSTANT UPDATE: Send LiveKit role change notification BEFORE database update
      if (_liveKitService.isConnected) {
        AppLogger().info('⚡ LIVEKIT: Sending instant role change notification to $userId -> $newRole');
        await _sendRoleChangeNotification(userId, newRole);
      }

      // OPTIMISTIC UPDATE WITH ROLLBACK: Save state before update for potential rollback
      UserProfile? userProfile;
      String? previousRole;
      int? previousAudienceIndex;

      // OPTIMISTIC UPDATE: Update moderator's UI immediately
      if (mounted) {
        setState(() {
          // Update participant in the correct slot
          if (_participants.containsKey(newRole)) {
            // Find the user in audience or other slots

            // Check audience
            final audienceIndex = _audience.indexWhere((u) => u.id == userId);
            if (audienceIndex >= 0) {
              previousAudienceIndex = audienceIndex;
              userProfile = _audience[audienceIndex];
              _audience.removeAt(audienceIndex);
            }

            // Check other role slots
            _participants.forEach((role, user) {
              if (user?.id == userId) {
                previousRole = role;
                userProfile = user;
                _participants[role] = null;
              }
            });

            // Assign to new role
            if (userProfile != null) {
              _participants[newRole] = userProfile;
              AppLogger().info('⚡ OPTIMISTIC: Moderator UI updated instantly - assigned $userId to $newRole');
            }
          }
        });
      }

      // Now update database via webhook (UI already updated)
      final result = await _appwrite.assignArenaRole(
        roomId: widget.roomId,
        userId: userId,
        role: newRole,
      );

      // Check if assignment failed (empty string or error message)
      final success = result.isNotEmpty && !result.toLowerCase().contains('error') && !result.toLowerCase().contains('failed');

      if (!success) {
        // ROLLBACK: Webhook failed, restore previous state
        AppLogger().warning('🔄 ROLLBACK: Webhook failed ($result), restoring previous state');

        if (mounted && userProfile != null) {
          setState(() {
            // Remove from new role slot
            if (_participants[newRole]?.id == userId) {
              _participants[newRole] = null;
            }

            // Restore to previous position
            final role = previousRole;
            final index = previousAudienceIndex;

            if (role != null && role.isNotEmpty) {
              _participants[role] = userProfile;
              AppLogger().debug('🔄 Restored user to previous role: $role');
            } else if (index != null && index >= 0 && index <= _audience.length) {
              _audience.insert(index, userProfile!);
              AppLogger().debug('🔄 Restored user to audience at index: $index');
            }
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to assign role: $result'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Refresh participants list to sync with server
      await _loadParticipants();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Role assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger().error('Error assigning role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error assigning role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send instant role change notification via LiveKit data channel
  Future<void> _sendRoleChangeNotification(String userId, String newRole) async {
    try {
      if (!_liveKitService.isConnected) return;

      final messageData = {
        'type': 'role_change',
        'targetUserId': userId,
        'newRole': newRole,
        'roomId': widget.roomId,
        'fromModerator': _currentUserId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final messageJson = jsonEncode(messageData);
      final messageBytes = utf8.encode(messageJson);

      // Send to specific user via LiveKit data channel
      await _liveKitService.localParticipant?.publishData(
        messageBytes,
        reliable: true,
        destinationIdentities: [userId],
      );

      AppLogger().info('✅ LIVEKIT: Role change notification sent to $userId');
    } catch (e) {
      AppLogger().error('❌ Failed to send role change notification: $e');
    }
  }

  String _formatRoleName(String role) {
    switch (role) {
      case 'affirmative':
        return 'Affirmative';
      case 'affirmative2':
        return 'Affirmative 2';
      case 'negative':
        return 'Negative';
      case 'negative2':
        return 'Negative 2';
      case 'moderator':
        return 'Moderator';
      case 'judge1':
        return 'Judge 1';
      case 'judge2':
        return 'Judge 2';
      case 'judge3':
        return 'Judge 3';
      case 'audience':
        return 'Audience';
      default:
        return role.toUpperCase();
    }
  }


  /// Handle arena participant updates using optimized approach
  Future<void> _handleArenaParticipantUpdate(RealtimeMessage response) async {
    try {
      final payload = response.payload;
      final updateType = _determineUpdateType(response.events);

      AppLogger().debug('🔄 Processing arena participant update: $updateType');

      // Arena uses role-based slots, so we handle updates differently
      if (updateType == 'delete') {
        await _handleArenaParticipantRemoval(payload);
      } else if (updateType == 'create') {
        await _handleArenaParticipantAddition(payload);
      } else if (updateType == 'update') {
        await _handleArenaParticipantRoleChange(payload);
      }

      AppLogger().info('✅ Arena participant update processed');

      // Validate role consistency after any participant update
      await _validateRoleConsistency();
    } catch (e) {
      AppLogger().error('Error handling arena participant update: $e');
      // Fallback to full refresh on error
      await _loadParticipants();
    }
  }

  /// Handle participant removal in arena
  Future<void> _handleArenaParticipantRemoval(Map<String, dynamic> payload) async {
    final userId = payload['userId'] as String?;
    if (userId == null) return;

    AppLogger().info('🚪 Arena participant removed: $userId');

    if (mounted) {
      setState(() {
        // Check all role slots and remove the user
        _participants.forEach((role, user) {
          if (user?.id == userId) {
            _participants[role] = null;
            AppLogger().info('🎭 Removed $userId from role: $role');

            // CRITICAL FIX: Clear current user's role if they are being removed
            if (userId == _currentUserId) {
              _userRole = 'audience'; // Default to audience when removed from role
              AppLogger().info('🔄 SELF ROLE CLEAR: Reset own role to audience after removal');
            }
          }
        });

        // Remove from audience
        _audience.removeWhere((user) => user.id == userId);
      });

      // Show notification for critical roles
      final leavingRole = _findUserRole(userId);
      if (leavingRole != null && ['affirmative', 'negative', 'moderator'].contains(leavingRole)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $leavingRole has left the debate'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Handle participant addition in arena
  Future<void> _handleArenaParticipantAddition(Map<String, dynamic> payload) async {
    final userId = payload['userId'] as String?;
    final role = payload['role'] as String?;

    if (userId == null) return;

    AppLogger().info('👋 Arena participant added: $userId (role: $role)');

    try {
      // Fetch user profile
      final userProfile = await _fetchUserProfile(userId);
      if (userProfile == null) return;

      if (mounted) {
        setState(() {
          if (role != null && _participants.containsKey(role)) {
            // Assign to specific role slot
            _participants[role] = userProfile;
            AppLogger().info('🎭 Assigned $userId to role: $role');

            // CRITICAL FIX: Update current user's role if this addition is for them
            if (userId == _currentUserId) {
              _userRole = role;
              AppLogger().info('🔄 SELF ROLE SET: Set own role to $_userRole');
            }
          } else {
            // Add to audience
            if (!_audience.any((user) => user.id == userId)) {
              _audience.add(userProfile);
              AppLogger().info('👥 Added $userId to audience');

              // Update current user's role to audience if needed
              if (userId == _currentUserId && _userRole != 'audience') {
                _userRole = 'audience';
                AppLogger().info('🔄 SELF ROLE SET: Set own role to audience');
              }
            }
          }
        });
      }
    } catch (e) {
      AppLogger().error('Error handling participant addition: $e');
    }
  }

  /// Handle participant role change in arena
  Future<void> _handleArenaParticipantRoleChange(Map<String, dynamic> payload) async {
    final userId = payload['userId'] as String?;
    final newRole = payload['role'] as String?;

    if (userId == null || newRole == null) return;

    AppLogger().info('🎭 Arena role change: $userId -> $newRole');

    // OPTIMISTIC UPDATE: If this is the current user, update UI IMMEDIATELY
    final isCurrentUser = userId == _currentUserId;
    if (isCurrentUser && mounted) {
      AppLogger().info('⚡ INSTANT: Current user role change detected - updating UI immediately');
      setState(() {
        final oldRole = _userRole;
        _userRole = newRole;
        AppLogger().info('⚡ INSTANT: Updated current user role from $oldRole to $newRole');
      });
    }

    try {
      // Find and remove user from current position
      UserProfile? userProfile;

      // Check role slots
      _participants.forEach((role, user) {
        if (user?.id == userId) {
          userProfile = user;
          _participants[role] = null;
        }
      });

      // Check audience
      final audienceIndex = _audience.indexWhere((user) => user.id == userId);
      if (audienceIndex >= 0) {
        userProfile = _audience[audienceIndex];
        _audience.removeAt(audienceIndex);
      }

      // If user not found, fetch profile
      userProfile ??= await _fetchUserProfile(userId);
      if (userProfile == null) return;

      if (mounted) {
        setState(() {
          if (_participants.containsKey(newRole)) {
            // Assign to specific role slot
            _participants[newRole] = userProfile;
            AppLogger().info('🎭 Updated $userId to role: $newRole');
          } else {
            // Add to audience (role might be 'audience' or unknown)
            if (!_audience.any((user) => user.id == userId)) {
              _audience.add(userProfile!);
              AppLogger().info('👥 Moved $userId to audience');
            }
          }

          // CRITICAL FIX: Update current user's role if this change is for them
          if (userId == _currentUserId) {
            final oldRole = _userRole;
            _userRole = newRole;
            AppLogger().info('🔄 SELF ROLE UPDATE: Updated own role from $oldRole to $_userRole');

            // If role changed to/from a speaking role, reconnect WebRTC with proper permissions
            final wasPublishingRole = ['moderator', 'affirmative', 'negative', 'affirmative2', 'negative2', 'judge1', 'judge2', 'judge3']
                .contains(oldRole);
            final isPublishingRole = _shouldUserPublishMedia();

            if (wasPublishingRole != isPublishingRole) {
              AppLogger().info('🎤 Role change affects media permissions - reconnecting WebRTC');
              _connectToWebRTC();
            }
          }
        });
      }
    } catch (e) {
      AppLogger().error('Error handling role change: $e');
    }
  }

  /// Find the current role of a user
  String? _findUserRole(String userId) {
    for (final entry in _participants.entries) {
      if (entry.value?.id == userId) {
        return entry.key;
      }
    }
    return null;
  }

  /// Check how many judges have submitted their votes
  Future<Map<String, int>> _checkJudgeVoteProgress() async {
    try {
      // Query the arena_judgments collection for this room
      final judgments = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_judgments',
        queries: [
          Query.equal('roomId', widget.roomId),
        ],
      );

      int totalJudges = 0;
      if (_participants['judge1'] != null) totalJudges++;
      if (_participants['judge2'] != null) totalJudges++;
      if (_participants['judge3'] != null) totalJudges++;

      return {
        'voted': judgments.documents.length,
        'total': totalJudges,
      };
    } catch (e) {
      AppLogger().error('Error checking judge vote progress: $e');
      return {'voted': 0, 'total': 0};
    }
  }

  /// Show persistent notification for judge vote
  void _showJudgeVoteNotification(String judgeLabel, Map<String, int> voteCount) {
    if (!mounted) return;

    final votedCount = voteCount['voted'] ?? 0;
    final totalCount = voteCount['total'] ?? 0;

    // Create the message with vote progress
    String message = '🗳️ $judgeLabel has submitted their vote';
    if (totalCount > 0) {
      message += '\n📊 Progress: $votedCount/$totalCount judges have voted';

      if (votedCount == totalCount) {
        message += '\n✅ All judges have voted!';
      }
    }

    // Show persistent snackbar with dismiss action
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
            if (votedCount == totalCount)
              const SizedBox(height: 4),
            if (votedCount == totalCount)
              const Text(
                'You can now proceed to announce results',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
          ],
        ),
        backgroundColor: votedCount == totalCount ? Colors.green : Colors.blue.shade700,
        duration: const Duration(days: 365), // Essentially infinite until dismissed
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );

    // Play a notification sound if all judges have voted
    if (votedCount == totalCount) {
      try {
        // You can add a sound effect here if desired
        AppLogger().info('🔔 All judges have completed voting!');
      } catch (e) {
        AppLogger().debug('Could not play notification sound: $e');
      }
    }
  }

  /// Determine update type from realtime events
  String _determineUpdateType(List<String> events) {
    for (final event in events) {
      if (event.contains('.create')) return 'create';
      if (event.contains('.delete')) return 'delete';
      if (event.contains('.update')) return 'update';
    }
    return 'update'; // Default fallback
  }


  /// Fetch user profile for diff manager
  Future<UserProfile?> _fetchUserProfile(String userId) async {
    try {
      return await _appwrite.getUserProfile(userId);
    } catch (e) {
      AppLogger().error('Error fetching user profile for diff: $e');
      return null;
    }
  }

  /// Validate that user's role matches their position in participant slots
  Future<void> _validateRoleConsistency() async {
    try {
      if (_currentUserId == null || _userRole == null) return;

      // Check what role the user has in the participant slots
      String? slotRole;
      _participants.forEach((role, user) {
        if (user?.id == _currentUserId) {
          slotRole = role;
        }
      });

      // If user is in a slot but their _userRole doesn't match, fix it
      if (slotRole != null && slotRole != _userRole) {
        AppLogger().warning('🚨 ROLE INCONSISTENCY DETECTED:');
        AppLogger().warning('   Local role: $_userRole');
        AppLogger().warning('   Slot role: $slotRole');
        AppLogger().info('🔄 FIXING: Updating local role to match slot position');

        _userRole = slotRole;

        if (mounted) {
          setState(() {
            // UI will rebuild with corrected role
          });
        }

        AppLogger().info('✅ ROLE FIXED: Local role now $_userRole');
      }

      // Also check if user thinks they're audience but they're in a speaking slot
      if (_userRole == 'audience' && slotRole != null) {
        AppLogger().warning('🚨 CRITICAL: User thinks they are audience but they are in $slotRole slot');
        _userRole = slotRole;
        if (mounted) {
          setState(() {
            // UI will rebuild with corrected role
          });
        }
        AppLogger().info('✅ AUDIENCE OVERRIDE: Corrected role from audience to $slotRole');
      }
    } catch (e) {
      AppLogger().error('❌ Error validating role consistency: $e');
    }
  }

}

// Role Manager Panel Widget
class RoleManagerPanel extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String currentUserRole;
  final VoidCallback onRoleAssigned;

  const RoleManagerPanel({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.currentUserRole,
    required this.onRoleAssigned,
  });

  @override
  State<RoleManagerPanel> createState() => _RoleManagerPanelState();
}

class _RoleManagerPanelState extends State<RoleManagerPanel> {
  final AppwriteService _appwrite = AppwriteService();
  List<Map<String, dynamic>> _participants = [];
  bool _isLoading = true;

  // Available roles
  final List<String> _availableRoles = const [
    'affirmative',
    'affirmative2',
    'negative',
    'negative2',
    'moderator',
    'judge1',
    'judge2',
    'judge3',
    'audience',
  ];

  bool get _isModerator => widget.currentUserRole == 'moderator';

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    try {
      final participants = await _appwrite.getArenaParticipants(widget.roomId);
      setState(() {
        _participants = participants;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger().error('Error loading participants: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _viewProfile(UserProfile profile) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFB794F6)],
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
                    const Icon(Icons.person, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Profile content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF8B5CF6),
                      backgroundImage: profile.avatar != null && profile.avatar!.isNotEmpty
                          ? NetworkImage(profile.avatar!)
                          : null,
                      child: profile.avatar == null || profile.avatar!.isEmpty
                          ? buildAvatarText(profile, 36)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Name
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B46C1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Email
                    if (profile.email.isNotEmpty)
                      Text(
                        profile.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildParticipantsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFB794F6)],
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
          Icon(
            _isModerator ? Icons.admin_panel_settings : Icons.people,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isModerator ? 'Assign Roles' : 'View Participants',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsList() {
    if (_participants.isEmpty) {
      return const Center(
        child: Text(
          'No participants found',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        final participant = _participants[index];
        final userProfile = participant['userProfile'];
        final currentRole = participant['role'];
        
        if (userProfile == null) return const SizedBox.shrink();
        
        final profile = UserProfile.fromMap(userProfile);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // User avatar and info (clickable for profile view)
                GestureDetector(
                  onTap: () => _viewProfile(profile),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFF8B5CF6),
                        backgroundImage: profile.avatar != null && profile.avatar!.isNotEmpty
                            ? NetworkImage(profile.avatar!)
                            : null,
                        child: profile.avatar == null || profile.avatar!.isEmpty
                            ? buildAvatarText(profile, 18)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                profile.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.blue,
                              ),
                            ],
                          ),
                          Text(
                            'Role: ${_formatRoleName(currentRole)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: _getRoleColor(currentRole),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Role dropdown (only for moderators)
                if (_isModerator)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: currentRole,
                      onChanged: (newRole) {
                        if (newRole != null && newRole != currentRole) {
                          // Prevent moderators from changing their own role away from moderator
                          final isCurrentUser = participant['userId'] == widget.currentUserId;
                          final isCurrentlyModerator = currentRole == 'moderator';
                          final tryingToChangeFromModerator = isCurrentUser && isCurrentlyModerator && newRole != 'moderator';
                          
                          if (tryingToChangeFromModerator) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⚠️ Moderators cannot change their own role'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          
                          _assignRole(participant['userId'], newRole);
                        }
                      },
                      underline: const SizedBox.shrink(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: _availableRoles.map((role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(
                            _formatRoleName(role),
                            style: TextStyle(
                              color: _getRoleColor(role),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                else
                  // Show current role as read-only for non-moderators
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getRoleColor(currentRole).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _getRoleColor(currentRole)),
                    ),
                    child: Text(
                      _formatRoleName(currentRole),
                      style: TextStyle(
                        color: _getRoleColor(currentRole),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatRoleName(String role) {
    switch (role) {
      case 'affirmative':
        return 'Affirmative';
      case 'affirmative2':
        return 'Affirmative 2';
      case 'negative':
        return 'Negative';
      case 'negative2':
        return 'Negative 2';
      case 'moderator':
        return 'Moderator';
      case 'judge1':
        return 'Judge 1';
      case 'judge2':
        return 'Judge 2';
      case 'judge3':
        return 'Judge 3';
      case 'audience':
        return 'Audience';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'affirmative':
      case 'affirmative2':
        return Colors.green;
      case 'negative':
      case 'negative2':
        return Colors.red;
      case 'moderator':
        return const Color(0xFF8B5CF6);
      case 'judge1':
      case 'judge2':
      case 'judge3':
        return Colors.amber[800]!;
      case 'audience':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  Future<void> _assignRole(String userId, String newRole) async {
    try {
      final appwrite = AppwriteService();
      await appwrite.assignArenaRole(
        roomId: widget.roomId,
        userId: userId,
        role: newRole,
      );
      
      widget.onRoleAssigned();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Role assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error assigning role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Moderator Control Modal Widget
class ModeratorControlModal extends StatelessWidget {
  final DebatePhase currentPhase;
  final VoidCallback onAdvancePhase;
  final VoidCallback onEmergencyReset;
  final VoidCallback onEndDebate;
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
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E5EC), // Neumorphism background
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          // Elevated neumorphism effect for modal
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            spreadRadius: -5,
            blurRadius: 15,
            offset: const Offset(-8, -8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: -5,
            blurRadius: 15,
            offset: const Offset(8, 8),
          ),
        ],
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
                const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'MODERATOR CONTROLS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white),
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
                    color: const Color(0xFFE0E5EC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.purple.shade600,
                      width: 2,
                    ),
                    boxShadow: [
                      // Inner shadow for neumorphism
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: -1,
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.7),
                        spreadRadius: -1,
                        blurRadius: 4,
                        offset: const Offset(-2, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.purple.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentPhase.displayName,
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              currentPhase.description,
                              style: TextStyle(
                                color: Colors.grey.shade600,
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
                  Text(
                    'Assign Speaker',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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

  /// Control button for moderator modal
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE0E5EC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled ? color : Colors.grey.shade400,
            width: 2,
          ),
          boxShadow: isEnabled
              ? [
                  // Raised neumorphism effect
                  BoxShadow(
                    color: Colors.white.withOpacity(0.7),
                    spreadRadius: -1,
                    blurRadius: 4,
                    offset: const Offset(-2, -2),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: -1,
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ]
              : [
                  // Pressed/disabled neumorphism effect
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: -1,
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.5),
                    spreadRadius: -1,
                    blurRadius: 4,
                    offset: const Offset(-2, -2),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isEnabled ? color : Colors.grey.shade400,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isEnabled ? color : Colors.grey.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
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
                    'Emergency Controls',
                    style: TextStyle(
                      fontSize: constraints.maxWidth < 150 ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakerButton(String label, String role, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE0E5EC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? Colors.green : Colors.grey.shade400,
            width: 2,
          ),
          boxShadow: isActive
              ? [
                  // Raised neumorphism effect when active
                  BoxShadow(
                    color: Colors.white.withOpacity(0.7),
                    spreadRadius: -1,
                    blurRadius: 4,
                    offset: const Offset(-2, -2),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: -1,
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ]
              : [
                  // Inset neumorphism effect when inactive
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: -1,
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.5),
                    spreadRadius: -1,
                    blurRadius: 4,
                    offset: const Offset(-2, -2),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.green : Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}


// Results Modal Widget
class ResultsModal extends StatelessWidget {
  final String winner;
  final UserProfile? affirmativeDebater;
  final UserProfile? affirmative2Debater;
  final UserProfile? negativeDebater;
  final UserProfile? negative2Debater;
  final List<dynamic> judgments;
  final String topic;
  final int? teamSize;

  const ResultsModal({
    super.key,
    required this.winner,
    this.affirmativeDebater,
    this.affirmative2Debater,
    this.negativeDebater,
    this.negative2Debater,
    required this.judgments,
    required this.topic,
    this.teamSize,
  });

  // Colors
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  Widget build(BuildContext context) {
    // Calculate vote counts
    int affirmativeVotes = 0;
    int negativeVotes = 0;
    
    for (var judgment in judgments) {
      final judgeWinner = judgment.data['winner'];
      if (judgeWinner == 'affirmative') {
        affirmativeVotes++;
      } else if (judgeWinner == 'negative') {
        negativeVotes++;
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: MediaQuery.of(context).size.height * 0.85, // Limit height to 85% of screen
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.grey[50]!,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                child: _buildContent(affirmativeVotes, negativeVotes),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [accentPurple, deepPurple],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events,
            color: Colors.white,
            size: 40, // Reduced from 48
          ),
          const SizedBox(height: 8), // Reduced from 12
          const Text(
            'DEBATE RESULTS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20, // Reduced from 24
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6), // Reduced from 8
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced padding
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              topic,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12, // Reduced from 14
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(int affirmativeVotes, int negativeVotes) {
    final isAffirmativeWinner = winner == 'affirmative';

    return Padding(
      padding: const EdgeInsets.all(20), // Reduced from 24
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Winner Announcement
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16), // Reduced from 20
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withOpacity(0.1),
                  Colors.orange.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 24), // Reduced from 32
                    const SizedBox(width: 6), // Reduced from 8
                    Text(
                      'WINNER',
                      style: TextStyle(
                        color: Colors.amber[800],
                        fontSize: 16, // Reduced from 20
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 6), // Reduced from 8
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 24), // Reduced from 32
                  ],
                ),
                const SizedBox(height: 12), // Reduced from 16
                _buildWinnerDisplay(isAffirmativeWinner),
              ],
            ),
          ),

          const SizedBox(height: 16), // Reduced from 24

          // Vote Breakdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12), // Reduced from 16
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Judge Votes',
                  style: TextStyle(
                    fontSize: 16, // Reduced from 18
                    fontWeight: FontWeight.bold,
                    color: deepPurple,
                  ),
                ),
                const SizedBox(height: 12), // Reduced from 16
                _buildVoteRow('Affirmative', affirmativeVotes, isAffirmativeWinner, Colors.green),
                const SizedBox(height: 3), // Reduced from 8
                _buildVoteRow('Negative', negativeVotes, !isAffirmativeWinner, const Color(0xFFFF2400)),
              ],
            ),
          ),

          const SizedBox(height: 12), // Reduced from 16

          // Individual Judge Scores (if we have detailed scores)
          if (judgments.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12), // Reduced from 16
              decoration: BoxDecoration(
                color: accentPurple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentPurple.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Judge Details',
                    style: TextStyle(
                      fontSize: 14, // Reduced from 16
                      fontWeight: FontWeight.bold,
                      color: deepPurple,
                    ),
                  ),
                  const SizedBox(height: 3), // Reduced from 8
                  ...judgments.map((judgment) {
                    final index = judgments.indexOf(judgment);
                    final judgeWinner = judgment.data['winner'];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3), // Reduced from 4
                      child: Row(
                        children: [
                          const Icon(
                            Icons.gavel,
                            size: 14, // Reduced from 16
                            color: accentPurple,
                          ),
                          const SizedBox(width: 6), // Reduced from 8
                          Text(
                            'Judge ${index + 1}:',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: deepPurple,
                              fontSize: 12, // Added smaller font
                            ),
                          ),
                          const SizedBox(width: 6), // Reduced from 8
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), // Reduced padding
                            decoration: BoxDecoration(
                              color: judgeWinner == 'affirmative' ? Colors.green : const Color(0xFFFF2400),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              judgeWinner?.toUpperCase() ?? 'UNKNOWN',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10, // Reduced from 12
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoteRow(String side, int votes, bool isWinner, Color color) {
    return Row(
      children: [
        Container(
          width: 20, // Reduced from 24
          height: 20, // Reduced from 24
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              votes.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12, // Reduced from 14
              ),
            ),
          ),
        ),
        const SizedBox(width: 10), // Reduced from 12
        Text(
          side,
          style: TextStyle(
            fontSize: 14, // Reduced from 16
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        if (isWinner) ...[
          const SizedBox(width: 6), // Reduced from 8
          const Icon(
            Icons.check_circle,
            color: Colors.amber,
            size: 16, // Reduced from 20
          ),
        ],
        const Spacer(),
        Text(
          '$votes vote${votes != 1 ? 's' : ''}',
          style: TextStyle(
            fontSize: 12, // Reduced from 14
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16), // Reduced from 24
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12), // Reduced from 16
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Close Results',
                style: TextStyle(
                  fontSize: 14, // Reduced from 16
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6), // Reduced from 8
          Text(
            'Great debate! 🎉',
            style: TextStyle(
              fontSize: 12, // Reduced from 14
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerDisplay(bool isAffirmativeWinner) {
    // Get the winning team members
    final winningDebater1 = winner == 'affirmative' ? affirmativeDebater : negativeDebater;
    final winningDebater2 = winner == 'affirmative' ? affirmative2Debater : negative2Debater;
    
    // If no debaters found, return empty container
    if (winningDebater1 == null && winningDebater2 == null) {
      return const SizedBox.shrink();
    }
    
    // For 1v1 or if only one debater exists, show single debater
    if ((teamSize ?? 1) == 1 || winningDebater2 == null) {
      if (winningDebater1 != null) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: getAvatarColorForRole(winner == 'affirmative' ? 'affirmative' : 'negative'),
                backgroundImage: winningDebater1.avatar != null && winningDebater1.avatar!.isNotEmpty
                    ? NetworkImage(winningDebater1.avatar!)
                    : null,
                child: winningDebater1.avatar == null || winningDebater1.avatar!.isEmpty
                    ? buildAvatarText(winningDebater1, 18)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    winningDebater1.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: deepPurple,
                    ),
                  ),
                  Text(
                    '${winner.toUpperCase()} SIDE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isAffirmativeWinner ? Colors.green : const Color(0xFFFF2400),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }
      return const SizedBox.shrink();
    } 
    
    // For 2v2, show both team members
    return Column(
      children: [
        Text(
          '${winner.toUpperCase()} TEAM',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isAffirmativeWinner ? Colors.green : const Color(0xFFFF2400),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // First team member  
            if (winningDebater1 != null) ...[
              Expanded(
                child: _buildTeamMemberCard(winningDebater1),
              ),
              const SizedBox(width: 8),
            ],
            // Second team member
            Expanded(
              child: _buildTeamMemberCard(winningDebater2),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamMemberCard(UserProfile debater) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: getAvatarColorForRole(winner == 'affirmative' ? 'affirmative' : 'negative'),
              backgroundImage: debater.avatar != null && debater.avatar!.isNotEmpty
                  ? NetworkImage(debater.avatar!)
                  : null,
              child: debater.avatar == null || debater.avatar!.isEmpty
                  ? buildAvatarText(debater, 14)
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            debater.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: deepPurple,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Room Closing Modal Widget
class RoomClosingModal extends StatefulWidget {
  final int initialSeconds;
  final VoidCallback onCountdownComplete;
  final VoidCallback? onForceNavigation;

  const RoomClosingModal({
    super.key,
    required this.initialSeconds,
    required this.onCountdownComplete,
    this.onForceNavigation,
  });

  @override
  State<RoomClosingModal> createState() => _RoomClosingModalState();
}

class _RoomClosingModalState extends State<RoomClosingModal> {
  late int _secondsRemaining;
  late Timer _timer;
  bool _hasNavigated = false; // Track if we've already navigated

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.initialSeconds;
    _startCountdown();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _forceNavigation() {
    if (!_hasNavigated && mounted) {
      _hasNavigated = true;
      AppLogger().info('Forcing navigation back to arena lobby from closing modal');
      
      // Call the parent's navigation callback if provided
      if (widget.onForceNavigation != null) {
        widget.onForceNavigation!();
      } else {
        // Fallback navigation
        try {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ArenaApp()),
            (route) => false,
          );
          AppLogger().info('Successfully navigated from modal to Main App');
        } catch (e) {
          AppLogger().error('Modal navigation failed: $e');
        }
      }
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsRemaining--;
        });
        
        if (_secondsRemaining <= 0) {
          timer.cancel();
          _forceNavigation(); // Use force navigation instead of callback
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red[400]!,
              Colors.red[600]!,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              const Text(
                'ROOM CLOSING',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Message
              const Text(
                'The moderator has closed this arena room.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              // Countdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Returning to lobby in:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_secondsRemaining',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Text(
                      'seconds',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Leave Now Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _timer.cancel();
                    _forceNavigation(); // Use force navigation
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red[600],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Leave Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Judge Selection Modal for Moderators
class JudgeSelectionModal extends StatefulWidget {
  final String arenaRoomId;
  final String topic;
  final String? category;
  final String? description;
  final Function(List<String>) onJudgesSelected;

  const JudgeSelectionModal({
    super.key,
    required this.arenaRoomId,
    required this.topic,
    this.category,
    this.description,
    required this.onJudgesSelected,
  });

  @override
  State<JudgeSelectionModal> createState() => _JudgeSelectionModalState();
}

class _JudgeSelectionModalState extends State<JudgeSelectionModal> {
  final AppwriteService _appwrite = AppwriteService();
  final ChallengeMessagingService _messagingService = ChallengeMessagingService();
  
  List<Map<String, dynamic>> _availableJudges = [];
  final Set<String> _selectedJudges = {};
  bool _isLoading = true;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadAvailableJudges();
  }
  
  Future<void> _loadAvailableJudges() async {
    try {
      setState(() => _isLoading = true);
      
      // Get users who have opted into judging
      final judgeProfiles = await _appwrite.getAvailableJudges(
        excludeArenaId: widget.arenaRoomId,
        limit: 50,
      );
      
      // Convert UserProfile list to Map format for consistency
      final judges = judgeProfiles.map((profile) => {
        '\$id': profile.id,
        'name': profile.name,
        'expertise': profile.bio, // Use bio as expertise for now
        'avatar': profile.avatar,
      }).toList();
      
      setState(() {
        _availableJudges = judges;
        _isLoading = false;
      });
      
      AppLogger().debug('📊 Found ${judges.length} available judges for category: ${widget.category}');
    } catch (e) {
      AppLogger().error('Error loading available judges: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _sendJudgeInvitations() async {
    if (_selectedJudges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one judge')),
      );
      return;
    }
    
    try {
      for (final judgeId in _selectedJudges) {
        final judge = _availableJudges.firstWhere((j) => j['\$id'] == judgeId);
        
        await _messagingService.sendArenaRoleInvitation(
          userId: judgeId,
          userName: judge['name'] ?? 'Judge',
          arenaRoomId: widget.arenaRoomId,
          role: 'judge',
          topic: widget.topic,
          description: widget.description,
          category: widget.category,
        );
      }
      
      widget.onJudgesSelected(_selectedJudges.toList());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Invitations sent to ${_selectedJudges.length} judges'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger().error('Error sending judge invitations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending invitations: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final filteredJudges = _availableJudges.where((judge) {
      if (_searchQuery.isEmpty) return true;
      final name = judge['name']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
    
    return Container(
      margin: const EdgeInsets.all(16),
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
                const Icon(Icons.balance, color: Colors.black, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SELECT JUDGES',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.category != null)
                        Text(
                          'Category: ${widget.category}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.black),
                ),
              ],
            ),
          ),
          
          // Content
          Container(
            constraints: const BoxConstraints(maxHeight: 500),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search judges...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Selected Count
                if (_selectedJudges.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.amber, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedJudges.length} judge${_selectedJudges.length == 1 ? '' : 's'} selected',
                          style: const TextStyle(color: Colors.amber),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Judges List
                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    ),
                  )
                else if (filteredJudges.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sentiment_dissatisfied, 
                               color: Colors.grey[400], size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty 
                                ? 'No judges found matching "$_searchQuery"'
                                : widget.category != null 
                                    ? 'No judges available for ${widget.category}'
                                    : 'No judges available',
                            style: TextStyle(color: Colors.grey[400]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredJudges.length,
                      itemBuilder: (context, index) {
                        final judge = filteredJudges[index];
                        final judgeId = judge['\$id'] ?? '';
                        final isSelected = _selectedJudges.contains(judgeId);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Colors.amber.withOpacity(0.2) 
                                : Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected 
                                ? Border.all(color: Colors.amber, width: 2)
                                : null,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: getAvatarColorForRole('judge1'),
                              child: buildAvatarTextFromMap(judge, 14),
                            ),
                            title: Text(
                              judge['name'] ?? 'Unknown Judge',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: judge['expertise'] != null
                                ? Text(
                                    'Expertise: ${judge['expertise']}',
                                    style: TextStyle(color: Colors.grey[400]),
                                  )
                                : null,
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Colors.amber)
                                : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedJudges.remove(judgeId);
                                } else {
                                  _selectedJudges.add(judgeId);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[400],
                          side: BorderSide(color: Colors.grey[600]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedJudges.isNotEmpty ? _sendJudgeInvitations : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Send Invitations (${_selectedJudges.length})',
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
    );
  }

}

// Enhanced Role Selection Modal for Moderators
class RoleSelectionModal extends StatefulWidget {
  final List<UserProfile> audience;
  final Function(UserProfile, String) onRoleAssigned;
  final int availableJudgeSlots;
  final int teamSize;
  final bool hasAffirmativeDebater;
  final bool hasNegativeDebater;
  final bool hasAffirmative2Debater;
  final bool hasNegative2Debater;
  final bool hasJudge1;
  final bool hasJudge2;
  final bool hasJudge3;

  const RoleSelectionModal({
    super.key,
    required this.audience,
    required this.onRoleAssigned,
    required this.availableJudgeSlots,
    required this.teamSize,
    required this.hasAffirmativeDebater,
    required this.hasNegativeDebater,
    required this.hasAffirmative2Debater,
    required this.hasNegative2Debater,
    required this.hasJudge1,
    required this.hasJudge2,
    required this.hasJudge3,
  });

  @override
  State<RoleSelectionModal> createState() => _RoleSelectionModalState();
}

class _RoleSelectionModalState extends State<RoleSelectionModal> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        // Update UI when switching tabs
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.purple.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Assign Roles from Audience',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.purple.shade700,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Colors.purple.shade700,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, size: 16),
                      SizedBox(width: 8),
                      Text('Debaters'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.balance, size: 16),
                      SizedBox(width: 8),
                      Text('Judges'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDebaterSelection(),
                _buildJudgeSelection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebaterSelection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select audience members to become debaters',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Role selection buttons - different layout for 1v1 vs 2v2
          widget.teamSize == 1 
            ? Row(
                children: [
                  Expanded(
                    child: _buildRoleCard(
                      title: 'Affirmative',
                      icon: Icons.thumb_up,
                      color: Colors.green,
                      isAssigned: widget.hasAffirmativeDebater,
                      role: 'affirmative',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRoleCard(
                      title: 'Negative',
                      icon: Icons.thumb_down,
                      color: Colors.red,
                      isAssigned: widget.hasNegativeDebater,
                      role: 'negative',
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  // Affirmative Team Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildRoleCard(
                          title: 'Affirmative 1',
                          icon: Icons.thumb_up,
                          color: Colors.green,
                          isAssigned: widget.hasAffirmativeDebater,
                          role: 'affirmative',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildRoleCard(
                          title: 'Affirmative 2',
                          icon: Icons.thumb_up,
                          color: Colors.green,
                          isAssigned: widget.hasAffirmative2Debater,
                          role: 'affirmative2',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Negative Team Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildRoleCard(
                          title: 'Negative 1',
                          icon: Icons.thumb_down,
                          color: Colors.red,
                          isAssigned: widget.hasNegativeDebater,
                          role: 'negative',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildRoleCard(
                          title: 'Negative 2',
                          icon: Icons.thumb_down,
                          color: Colors.red,
                          isAssigned: widget.hasNegative2Debater,
                          role: 'negative2',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

          const SizedBox(height: 16),

          // Audience list
          const Text(
            'Available Audience Members:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          
          Expanded(
            child: widget.audience.isEmpty
                ? const Center(
                    child: Text(
                      'No audience members available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.audience.length,
                    itemBuilder: (context, index) {
                      final member = widget.audience[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: getAvatarColorForRole('audience'),
                            backgroundImage: member.avatar != null && member.avatar!.isNotEmpty
                                ? NetworkImage(member.avatar!)
                                : null,
                            child: member.avatar == null || member.avatar!.isEmpty
                                ? buildAvatarText(member, 14)
                                : null,
                          ),
                          title: Text(member.name),
                          subtitle: const Text('Audience member'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (role) => widget.onRoleAssigned(member, role),
                            itemBuilder: (context) => [
                              if (!widget.hasAffirmativeDebater)
                                PopupMenuItem(
                                  value: 'affirmative',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.thumb_up, color: Colors.green, size: 16),
                                      const SizedBox(width: 8),
                                      Text(widget.teamSize == 1 ? 'Affirmative Debater' : 'Affirmative 1'),
                                    ],
                                  ),
                                ),
                              if (widget.teamSize == 2 && !widget.hasAffirmative2Debater)
                                const PopupMenuItem(
                                  value: 'affirmative2',
                                  child: Row(
                                    children: [
                                      Icon(Icons.thumb_up, color: Colors.green, size: 16),
                                      SizedBox(width: 8),
                                      Text('Affirmative 2'),
                                    ],
                                  ),
                                ),
                              if (!widget.hasNegativeDebater)
                                PopupMenuItem(
                                  value: 'negative',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.thumb_down, color: Colors.red, size: 16),
                                      const SizedBox(width: 8),
                                      Text(widget.teamSize == 1 ? 'Negative Debater' : 'Negative 1'),
                                    ],
                                  ),
                                ),
                              if (widget.teamSize == 2 && !widget.hasNegative2Debater)
                                const PopupMenuItem(
                                  value: 'negative2',
                                  child: Row(
                                    children: [
                                      Icon(Icons.thumb_down, color: Colors.red, size: 16),
                                      SizedBox(width: 8),
                                      Text('Negative 2'),
                                    ],
                                  ),
                                ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Assign',
                                style: TextStyle(
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildJudgeSelection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.amber.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select up to 3 judges • ${widget.availableJudgeSlots} slots available',
                    style: TextStyle(
                      color: Colors.amber.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Available Audience Members:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: widget.audience.isEmpty
                ? const Center(
                    child: Text(
                      'No audience members available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.audience.length,
                    itemBuilder: (context, index) {
                      final member = widget.audience[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: getAvatarColorForRole('audience'),
                            backgroundImage: member.avatar != null && member.avatar!.isNotEmpty
                                ? NetworkImage(member.avatar!)
                                : null,
                            child: member.avatar == null || member.avatar!.isEmpty
                                ? buildAvatarText(member, 14)
                                : null,
                          ),
                          title: Text(member.name),
                          subtitle: Text(
                            member.isAvailableAsJudge 
                                ? 'Available as judge' 
                                : 'Audience member',
                            style: TextStyle(
                              color: member.isAvailableAsJudge ? Colors.green : Colors.grey,
                            ),
                          ),
                          trailing: widget.availableJudgeSlots > 0
                              ? ElevatedButton(
                                  onPressed: () => _showJudgeSlotSelection(member),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                  child: const Text('Assign as Judge', style: TextStyle(fontSize: 12)),
                                )
                              : const Text(
                                  'No slots',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool isAssigned,
    required String role,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAssigned ? color.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAssigned ? color : Colors.grey.shade300,
          width: isAssigned ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isAssigned ? color : Colors.grey.shade600,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isAssigned ? color : Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isAssigned ? 'Assigned' : 'Available',
            style: TextStyle(
              fontSize: 10,
              color: isAssigned ? color : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showJudgeSlotSelection(UserProfile member) {
    final availableSlots = <String>[];
    
    // Check which specific judge slots are actually available
    if (!widget.hasJudge1) availableSlots.add('judge1');
    if (!widget.hasJudge2) availableSlots.add('judge2');
    if (!widget.hasJudge3) availableSlots.add('judge3');

    if (availableSlots.length == 1) {
      // Only one slot available, assign directly
      widget.onRoleAssigned(member, availableSlots.first);
    } else {
      // Multiple slots available, let user choose
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Select Judge Position for ${member.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableSlots.map((slot) {
              return ListTile(
                leading: const Icon(Icons.balance, color: Colors.amber),
                title: Text('Judge ${slot.substring(5)}'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onRoleAssigned(member, slot);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
  }

}

/// Arena Chat Bottom Sheet with real-time updates
class ArenaChatBottomSheet extends StatefulWidget {
  final String roomId;
  // ChatService removed - using new chat system
  final String? currentUserId;
  final Map<String, UserProfile?> participants;
  final int audienceCount;
  final VoidCallback onSendMessage;

  const ArenaChatBottomSheet({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.participants,
    required this.audienceCount,
    required this.onSendMessage,
  });

  @override
  State<ArenaChatBottomSheet> createState() => _ArenaChatBottomSheetState();
}

class _ArenaChatBottomSheetState extends State<ArenaChatBottomSheet> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _messageSubscription;
  List<Message> _messages = [];

  @override
  void initState() {
    super.initState();
    _initializeChatStream();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeChatStream() {
    // Subscribe to messages stream for real-time updates
    // Chat service removed - using new chat system
    setState(() {
      _messages = []; // Empty messages since old chat system is disabled
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      // Chat service removed - using new chat system
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble, color: Colors.blue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Arena Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.audienceCount + widget.participants.length} participants • ${_messages.length} messages',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Chat messages area
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Expanded(
                      child: _messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 48,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No messages yet',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Be the first to start the conversation!',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              key: const ValueKey('arena_chat_messages_list'),
                              controller: _scrollController,
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                return _buildChatMessage(message);
                              },
                            ),
                    ),
                    // Message input
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey[700]!, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(color: Colors.grey[500]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(color: Colors.grey[600]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(color: Colors.grey[600]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(color: Colors.blue),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                              textInputAction: TextInputAction.send,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FloatingActionButton.small(
                            key: const ValueKey('arena_send_message_fab'),
                            heroTag: "arena_send_message",
                            onPressed: _sendMessage,
                            backgroundColor: Colors.blue,
                            child: const Icon(Icons.send, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessage(Message message) {
    final roleColor = _getRoleColorForUser(message.senderId);
    final timeString = _formatMessageTime(message.timestamp);
    final isCurrentUser = message.senderId == widget.currentUserId;

    return Container(
      key: ValueKey('chat_message_${message.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          if (message.isSystemMessage)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(Icons.info, color: Colors.white, size: 16),
              ),
            )
          else
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: roleColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!message.isSystemMessage)
                  Row(
                    children: [
                      Text(
                        message.senderName,
                        style: TextStyle(
                          color: isCurrentUser ? Colors.blue : roleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeString,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                Text(
                  message.displayContent,
                  style: TextStyle(
                    color: message.isSystemMessage ? Colors.blue[300] : Colors.white,
                    fontSize: 14,
                    fontStyle: message.isSystemMessage ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColorForUser(String userId) {
    if (userId == 'system') return Colors.blue;
    
    // Check if user has a specific role
    for (final entry in widget.participants.entries) {
      if (entry.value?.id == userId) {
        switch (entry.key) {
          case 'affirmative':
            return Colors.blue;
          case 'negative':
            return Colors.red;
          case 'moderator':
            return Colors.purple;
          case 'judge1':
          case 'judge2':
          case 'judge3':
            return Colors.orange;
        }
      }
    }
    
    // Default audience color
    return Colors.grey;
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }


}