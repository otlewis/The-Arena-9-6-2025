import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../services/challenge_messaging_service.dart';
import '../services/sound_service.dart';
import '../widgets/user_avatar.dart';
import '../models/user_profile.dart';
import '../models/message.dart';
import '../models/judge_scorecard.dart';
import '../widgets/user_profile_bottom_sheet.dart';
import '../widgets/mattermost_chat_widget.dart';
import '../models/discussion_chat_message.dart';
import '../screens/email_compose_screen.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../main.dart' show ArenaApp, getIt;
import '../core/logging/app_logger.dart';
import '../services/livekit_service.dart';
import '../services/livekit_token_service.dart';
import '../services/noise_cancellation_service.dart';
import '../services/speaking_detection_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import 'arena_modals.dart';
import '../features/arena/dialogs/moderator_control_modal.dart' as moderator_controls;
import '../features/arena/widgets/arena_app_bar.dart';
import '../features/arena/models/debate_phase.dart' as features;
import '../features/arena/dialogs/timer_control_modal.dart';
// Removed problematic provider imports to prevent infinite loops

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

class _ArenaScreenState extends State<ArenaScreen> with TickerProviderStateMixin {
  final AppwriteService _appwrite = AppwriteService();
  late final SoundService _soundService;
  late final SpeakingDetectionService _speakingService;
  
  // Room data
  Map<String, dynamic>? _roomData;
  UserProfile? _currentUser;
  String? _currentUserId;
  String? _userRole;
  int _teamSize = 1; // 1 for 1v1, 2 for 2v2
  String? _winner; // Track the debate winner
  bool _judgingComplete = false;
  bool _judgingEnabled = false; // Track if judges can submit votes
  bool _hasCurrentUserSubmittedVote = false;
  bool _resultsModalShown = false; // Track if results modal has been shown
  bool _roomClosingModalShown = false; // Track if room closing modal has been shown
  bool _hasNavigated = false; // Track if we've already navigated to prevent duplicate navigation
  bool _isExiting = false; // Prevent state updates during exit
  Timer? _roomStatusChecker; // Periodic room status checker
  Timer? _roomCompletionTimer; // Timer for room completion after closure
  Timer? _muteStateSyncTimer; // Periodic mute state sync to prevent stuck states
  StreamSubscription? _realtimeSubscription; // Track realtime subscription
  StreamSubscription? _unreadMessagesSubscription; // Instant messages subscription
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
  
  
  // Enhanced Timer and Debate Management
  late AnimationController _timerController;
  DebatePhase _currentPhase = DebatePhase.preDebate;
  int _remainingSeconds = 0;
  bool _isTimerRunning = false;
  bool _isPaused = false;
  bool _hasPlayed30SecWarning = false; // Track if 30-sec warning was played
  
  // Speaking Management
  String _currentSpeaker = '';
  
    // WebRTC Video & Audio Management
  final LiveKitService _webrtcService = LiveKitService();
  bool _isWebRTCConnected = false;
  bool _isMuted = false;
  
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
  bool _isScreenSharing = false;
  
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
  void initState() {
    super.initState();
    
    // Initialize services
    _soundService = getIt<SoundService>();
    _speakingService = getIt<SpeakingDetectionService>();
    _initializeInstantMessaging();
    _initializeWebRTC();
    
    // Set up speaking detection listener
    _speakingService.addListener(_onSpeakingStateChanged);
    
    // Enable iOS-specific optimizations
    _isIOSOptimizationEnabled = !kIsWeb && (Platform.isIOS || defaultTargetPlatform == TargetPlatform.iOS);
    if (_isIOSOptimizationEnabled) {
      AppLogger().debug('🍎 iOS detected - enabling performance optimizations');
    }
    
    _timerController = AnimationController(
      duration: const Duration(minutes: 10), // Max duration
      vsync: this,
    );
    
    // Use proper initialization order to prevent user ID issues
    _initializeArena();
    
    // Force WebRTC connection after a delay to ensure room data is loaded
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isWebRTCConnected && mounted) {
        AppLogger().debug('🎥 Force attempting WebRTC connection after delay...');
        _connectToWebRTC();
      }
    });
    
    // Start connection health monitoring to prevent audio drops
    _startConnectionHealthMonitoring();
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
    // Instant messaging removed with Agora chat
    AppLogger().debug('📱 Instant messaging disabled (Agora removed)');
  }


  @override
  void dispose() {
    AppLogger().debug('🛑 DISPOSE: Setting exit flags and stopping ALL timers');
    // Set BOTH navigation and exit flags to stop all background processes immediately
    _hasNavigated = true;
    _isExiting = true;
    
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
    
    // Stop connection health monitoring
    _stopConnectionHealthMonitoring();
    _reconnectionTimer?.cancel();
    
    AppLogger().debug('🛑 DISPOSE: Cancelling realtime subscription...');
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    
    AppLogger().debug('🛑 DISPOSE: Cancelling instant messaging subscription...');
    _unreadMessagesSubscription?.cancel();
    _unreadMessagesSubscription = null;
    
    AppLogger().debug('🛑 DISPOSE: Cleaning up chat service...');
    // Chat service disposal removed - now handled by floating chat button
    _chatController.dispose();
    
    AppLogger().debug('🛑 DISPOSE: Cleaning up WebRTC...');
    _disposeWebRTC();
    
    AppLogger().debug('🛑 DISPOSE: Cleaning up noise cancellation...');
    try {
      NoiseCancellationService().disable();
    } catch (e) {
      AppLogger().error('❌ Failed to disable noise cancellation during dispose: $e');
    }
    
    AppLogger().debug('🛑 DISPOSE: Removing speaking detection listener...');
    _speakingService.removeListener(_onSpeakingStateChanged);
    
    _timerController.dispose();
    
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

  /// Get user role for speaking indicator by userId
  String? _getUserRoleById(String? userId) {
    if (userId == null) return null;
    
    // Check if it's the current user
    if (userId == _currentUserId) {
      return _userRole;
    }
    
    // Check participants for their roles using the _participants map
    for (final entry in _participants.entries) {
      final role = entry.key;
      final participant = entry.value;
      if (participant?.id == userId) {
        return role;
      }
    }
    
    return 'audience';
  }

  void _setupRealtimeSubscription() {
    // Add user ID validation before setting up subscription
    if (_currentUserId == null) {
      AppLogger().error('Cannot start real-time listening: no current user ID');
      return;
    }
    
    try {
      // Cancel any existing subscription first
      _realtimeSubscription?.cancel();
      
      AppLogger().info('Setting up real-time subscription for user: $_currentUserId (attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts)');
      
      // Subscribe to arena participants changes AND room updates
      final subscription = _appwrite.realtimeInstance.subscribe([
        'databases.arena_db.collections.arena_participants.documents',
        'databases.arena_db.collections.arena_rooms.documents'
      ]);
      
      _realtimeSubscription = subscription.stream.listen(
        (response) {
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
            AppLogger().debug('🔄 Refreshing participants for our arena room');
              
              // TODO: Check for completion status updates
              // Need to add completedSelection, completedAt, metadata fields to arena_participants collection first
              /*
              if (payload.containsKey('completedSelection') && payload.containsKey('userId')) {
                final completedUserId = payload['userId'];
                final completedSelection = payload['completedSelection'] == true;
                AppLogger().debug('🎭 Completion status update: User $completedUserId completed: $completedSelection');
                
                // Update local completion flags based on user role
                if (completedUserId == widget.challengerId) {
                  AppLogger().debug('🎭 Updated affirmative completion status: $completedSelection');
                } else if (completedUserId == widget.challengedId) {
                  AppLogger().debug('🎭 Updated negative completion status: $completedSelection');
                }
                
                // Trigger approval modal if the other debater completed and current user hasn't
                if (completedSelection && mounted && !_hasNavigated) {
                  _showApprovalModalToOtherDebater();
                }
              }
              */
              
              if (mounted && !_hasNavigated) { // Check navigation state
            _loadParticipants();
              }
            }
            
            if (isRoomUpdate) {
              // Check if this is our room by various possible ID formats
              final payloadId = payload['\$id'];
              final roomId = payload['id'];
              
              AppLogger().debug('🔍 Room update received - PayloadId: $payloadId, RoomId: $roomId, TargetRoomId: ${widget.roomId}');
              
              if (payloadId == widget.roomId || roomId == widget.roomId ||
                  payloadId == 'arena_${widget.challengeId}' || roomId == 'arena_${widget.challengeId}') {
                AppLogger().debug('🔄 Refreshing room data for winner/status updates');
                
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
      
      AppLogger().info('Real-time arena subscription established successfully for room: ${widget.roomId}');
      AppLogger().info('User: $_currentUserId is now listening for real-time updates');
    } catch (e) {
      AppLogger().error('Error setting up real-time subscription: $e');
      // Continue without real-time - the periodic checker will handle updates
    }
  }

  /// Start connection health monitoring to prevent audio drops
  void _startConnectionHealthMonitoring() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted || _isExiting) {
        timer.cancel();
        return;
      }
      _checkConnectionHealth();
    });
    
    AppLogger().debug('🔍 Started connection health monitoring for Arena (30s intervals)');
  }

  /// Stop connection health monitoring
  void _stopConnectionHealthMonitoring() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
    AppLogger().debug('🛑 Stopped connection health monitoring');
  }

  /// Check connection health and trigger reconnection if needed
  void _checkConnectionHealth() {
    if (!mounted || _isExiting || _isReconnecting) return;
    
    try {
      // Check if WebRTC connection is healthy
      final isWebRTCConnected = _webrtcService.isConnected;
      final hasRemoteStreams = _webrtcService.room?.remoteParticipants.isNotEmpty ?? false;
      
      // Only consider connection unhealthy if WebRTC is completely disconnected
      // Note: isWebRTCHealthy is calculated but not used in current logic - kept for future use
      // final isWebRTCHealthy = isWebRTCConnected;
      
      // Log connection state for debugging (but not too frequently)
      if (_consecutiveUnhealthyChecks == 0 || _consecutiveUnhealthyChecks % 5 == 0) {
        AppLogger().debug('🔍 Arena connection health check: WebRTC=${isWebRTCConnected ? 'Connected' : 'Disconnected'}, Streams=${hasRemoteStreams ? 'Yes' : 'No'}, Role=${_userRole ?? 'Unknown'}');
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
        
        // Only attempt reconnection if:
        // - We've had enough consecutive unhealthy checks
        // - Enough time has passed since last attempt
        if (_consecutiveUnhealthyChecks >= _unhealthyThreshold && timeSinceLastAttempt > _minTimeBetweenReconnections) {
          AppLogger().warning('⚠️ Arena WebRTC disconnected for $_consecutiveUnhealthyChecks consecutive checks - attempting restoration');
          _restoreWebRTCConnection();
          _consecutiveUnhealthyChecks = 0; // Reset counter
        } else {
          AppLogger().debug('⏳ Skipping Arena WebRTC restoration - checks: $_consecutiveUnhealthyChecks/$_unhealthyThreshold, time: ${timeSinceLastAttempt}s/$_minTimeBetweenReconnections');
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
  void _initializeWebRTC() async {
    try {
      AppLogger().debug('🎥 Initializing WebRTC for Arena...');
      
      // Initialize video renderers
      await _localRenderer.initialize();
      await _screenShareRenderer.initialize();
      
      // Set up LiveKit service callbacks
      _webrtcService.onConnected = () {
        AppLogger().debug('✅ LiveKit connected to Arena room');
        if (mounted) {
          setState(() {
            _isWebRTCConnected = true;
            // Sync mute state on connection
            _isMuted = _webrtcService.isMuted;
          });
        }
        
        // Start periodic state sync to prevent stuck states
        _startMuteStateSyncTimer();
      };

      _webrtcService.onParticipantConnected = (participant) {
        AppLogger().debug('👤 LiveKit participant joined Arena: ${participant.identity}');
        if (mounted) {
          setState(() {
            // Update UI for new participant
          });
        }
      };
      
      _webrtcService.onParticipantDisconnected = (participant) {
        AppLogger().debug('👋 LiveKit participant left Arena: ${participant.identity}');
        if (mounted) {
          setState(() {
            // Update UI for participant leaving
          });
        }
      };
      
      _webrtcService.onTrackSubscribed = (publication, participant) {
        AppLogger().debug('🎵 LiveKit track subscribed from ${participant.identity}: ${publication.kind}');
        if (mounted) {
          setState(() {
            // Handle new audio/video tracks
          });
        }
      };

      // Additional LiveKit callbacks for Arena
      _webrtcService.onError = (error) {
        AppLogger().debug('❌ LiveKit error in Arena: $error');
        if (mounted) {
          setState(() {
            // Handle connection errors
          });
        }
      };

      _webrtcService.onDisconnected = () {
        AppLogger().debug('🔌 LiveKit disconnected from Arena');
        if (mounted) {
          setState(() {
            _isWebRTCConnected = false;
          });
        }
      };

      // Screen sharing removed for audio-only Arena mode
      AppLogger().debug('🎙️ Arena configured for audio-only LiveKit communication');

      AppLogger().debug('🎥 WebRTC initialization complete');
    } catch (e) {
      AppLogger().error('❌ Failed to initialize WebRTC: $e');
    }
  }

  /// Connect to WebRTC server for Arena audio using LiveKit
  Future<void> _connectToWebRTC() async {
    AppLogger().info('🎥 _connectToWebRTC() called');
    
    if (_currentUser == null) {
      AppLogger().error('❌ Cannot connect WebRTC: No current user');
      // Try to get current user
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
      }
      if (_currentUser == null) {
        AppLogger().error('❌ Still no current user after trying to fetch');
        return;
      }
    }
    
    // Prevent reconnection if already connected
    if (_isWebRTCConnected) {
      AppLogger().debug('🎥 WebRTC already connected, skipping reconnection attempt');
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
      } else if (['affirmative', 'negative', 'affirmative2', 'negative2', 'moderator'].contains(_userRole)) {
        webrtcRole = _userRole!;
      } else if (['judge1', 'judge2', 'judge3'].contains(_userRole)) {
        webrtcRole = 'judge';
      }
      
      AppLogger().debug('🎥 LiveKit Role: $webrtcRole (User Role: $_userRole)');
      
      // Generate LiveKit token with matching deployment credentials
      final token = LiveKitTokenService.generateToken(
        roomName: widget.roomId,
        identity: _currentUser?.id ?? 'unknown',
        userRole: webrtcRole,
        roomType: 'arena',
        userId: _currentUser?.id ?? 'unknown',
        ttl: const Duration(hours: 2),
      );
      
      AppLogger().debug('🔑 Generated LiveKit token for ${_currentUser?.id}');
      AppLogger().debug('🔗 Connecting to LiveKit server...');
      AppLogger().debug('📡 Server URL: ws://172.236.109.9:7880');
      AppLogger().debug('🏠 Room: ${widget.roomId}');
      AppLogger().debug('👤 Identity: ${_currentUser?.id}');
      AppLogger().debug('🎭 Role: $webrtcRole');
      
      // Connect to LiveKit server
      await _webrtcService.connect(
        serverUrl: 'ws://172.236.109.9:7880', // LiveKit production server
        roomName: widget.roomId,
        token: token,
        userId: _currentUser?.id ?? 'unknown',
        userRole: webrtcRole,
        roomType: 'arena',
      );
      
      AppLogger().debug('🔗 LiveKit connect() method completed');
      
      // Mark as connected (the onConnected callback will also set this)
      if (mounted) {
        setState(() {
          _isWebRTCConnected = true;
        });
      }
      
      // Start muted by default to prevent feedback (like other rooms)
      AppLogger().debug('🔇 Starting muted by default to prevent feedback');
      await _webrtcService.disableAudio();
      if (mounted) {
        setState(() {
          _isMuted = true;
        });
      }
      
      AppLogger().info('✅ LiveKit connection established successfully');
      AppLogger().info('🎥 Connection status: $_isWebRTCConnected');
      AppLogger().info('🎤 Audio ready for role: $webrtcRole (started muted)');
      
      // Configure audio session with enhanced noise cancellation for Arena
      try {
        final session = await audio_session.AudioSession.instance;
        await session.configure(audio_session.AudioSessionConfiguration(
          avAudioSessionCategory: audio_session.AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: audio_session.AVAudioSessionCategoryOptions.defaultToSpeaker |
              audio_session.AVAudioSessionCategoryOptions.allowBluetooth |
              audio_session.AVAudioSessionCategoryOptions.duckOthers, // Duck other audio when speaking
          // REMOVED mixWithOthers to prevent feedback loops
          avAudioSessionMode: audio_session.AVAudioSessionMode.voiceChat, // VoiceChat mode for best echo cancellation
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
            // iOS automatically applies noise cancellation in voiceChat mode
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

  /// Determine if current user should publish media (video/audio)
  bool _shouldUserPublishMedia() {
    // Moderator, debaters and judges publish audio
    // Audience members are view-only
    return _userRole == 'moderator' ||
           _userRole == 'affirmative' || 
           _userRole == 'negative' ||
           _userRole == 'affirmative2' ||
           _userRole == 'negative2' ||
           _userRole?.startsWith('judge') == true;
  }

  /// Toggle local microphone with enhanced error handling
  Future<void> _toggleAudio() async {
    AppLogger().debug('🎤 Toggle audio called - current state: ${_isMuted ? 'muted' : 'unmuted'}');
    AppLogger().debug('🎤 User role: $_userRole, Can publish: ${_shouldUserPublishMedia()}');
    
    // Check if user has permission to use mic
    if (!_shouldUserPublishMedia()) {
      AppLogger().error('❌ User role $_userRole does not have microphone permissions');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Your role does not have microphone access'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Ensure WebRTC is connected first
    if (!_isWebRTCConnected) {
      AppLogger().debug('🎤 WebRTC not connected, attempting to connect...');
      await _connectToWebRTC();
      
      // Wait a moment for connection to establish
      await Future.delayed(const Duration(seconds: 1));
      
      // If still not connected, show error
      if (!_isWebRTCConnected) {
        AppLogger().error('❌ Cannot toggle audio - WebRTC connection failed');
        return;
      }
    }
    
    // CRITICAL iOS FIX: Force sync role with LiveKit before audio operations
    if (_userRole != null && (_userRole!.startsWith('judge') || _userRole == 'moderator' || _userRole!.contains('affirmative') || _userRole!.contains('negative'))) {
      AppLogger().debug('🔄 iOS AUDIO FIX: Force syncing role before audio toggle');
      _webrtcService.forceUpdateRole(_userRole!, 'arena');
    }
    
    try {
      // ENHANCED JUDGE HANDLING: Use special logic for judges
      if (_userRole?.startsWith('judge') == true) {
        AppLogger().debug('⚖️ JUDGE AUDIO: Using enhanced toggle logic...');
        
        if (_isMuted) {
          // Unmuting judge - use enhanced setup
          await _handleJudgeAudioSetup();
          if (mounted) {
            setState(() {
              _isMuted = false;
            });
          }
          AppLogger().info('⚖️ JUDGE AUDIO: Successfully unmuted via enhanced setup');
        } else {
          // Muting judge - use standard method
          await _webrtcService.toggleMute();
          final newMuteState = _webrtcService.isMuted;
          if (mounted) {
            setState(() {
              _isMuted = newMuteState;
            });
          }
          AppLogger().info('⚖️ JUDGE AUDIO: Successfully muted via standard method');
        }
      } else {
        // Standard toggle for non-judges
        await _webrtcService.toggleMute();
        final newMuteState = _webrtcService.isMuted;
        
        if (mounted) {
          setState(() {
            _isMuted = newMuteState;
          });
        }
        
        AppLogger().info('🎤 Audio toggled to: ${newMuteState ? 'MUTED' : 'UNMUTED'} via LiveKit');
      }
      
    } catch (e) {
      AppLogger().error('❌ Failed to toggle audio: $e');
      
      // Try emergency unmute if we were trying to unmute
      if (_isMuted) {
        AppLogger().debug('🚨 Attempting emergency unmute...');
        await _forceUnmute();
      }
    }
  }
  
  /// Disconnect from WebRTC (for reconnection strategies)
  Future<void> _disconnectFromWebRTC() async {
    try {
      AppLogger().debug('🔌 Disconnecting from WebRTC...');
      await _webrtcService.disconnect();
      
      if (mounted) {
        setState(() {
          _isWebRTCConnected = false;
        });
      }
      
      AppLogger().info('✅ Disconnected from WebRTC');
    } catch (e) {
      AppLogger().error('❌ Failed to disconnect from WebRTC: $e');
    }
  }

  /// Enhanced judge audio setup - 10/10 for judges
  Future<void> _handleJudgeAudioSetup() async {
    try {
      AppLogger().debug('⚖️ JUDGE AUDIO 10/10: Starting enhanced audio setup...');
      
      // Step 1: Force role synchronization with LiveKit
      AppLogger().debug('⚖️ Step 1: Force syncing judge role with LiveKit...');
      _webrtcService.forceUpdateRole(_userRole!, 'arena');
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Step 2: Ensure WebRTC connection is stable
      AppLogger().debug('⚖️ Step 2: Ensuring stable WebRTC connection...');
      if (!_isWebRTCConnected) {
        AppLogger().debug('⚖️ Reconnecting to WebRTC...');
        await _connectToWebRTC();
        await Future.delayed(const Duration(seconds: 2));
      }
      
      // Step 3: Try multiple audio enable strategies for judges
      AppLogger().debug('⚖️ Step 3: Attempting judge audio enable strategies...');
      
      // Strategy 1: Direct enable
      try {
        AppLogger().debug('⚖️ Strategy 1: Direct audio enable...');
        await _webrtcService.enableAudio();
        AppLogger().info('⚖️ Strategy 1 SUCCESS: Direct audio enable worked');
        return;
      } catch (e) {
        AppLogger().debug('⚖️ Strategy 1 failed: $e');
      }
      
      // Strategy 2: Force setup judge audio (if method exists)
      try {
        AppLogger().debug('⚖️ Strategy 2: Force setup judge audio...');
        await _webrtcService.forceSetupJudgeAudio();
        AppLogger().info('⚖️ Strategy 2 SUCCESS: Force setup judge audio worked');
        return;
      } catch (e) {
        AppLogger().debug('⚖️ Strategy 2 failed: $e');
      }
      
      // Strategy 3: Reconnect and retry
      try {
        AppLogger().debug('⚖️ Strategy 3: Reconnecting and retrying...');
        await _disconnectFromWebRTC();
        await Future.delayed(const Duration(seconds: 1));
        await _connectToWebRTC();
        await Future.delayed(const Duration(seconds: 2));
        
        // Force role update after reconnection
        _webrtcService.forceUpdateRole(_userRole!, 'arena');
        await Future.delayed(const Duration(milliseconds: 500));
        
        await _webrtcService.enableAudio();
        AppLogger().info('⚖️ Strategy 3 SUCCESS: Reconnection and retry worked');
        return;
      } catch (e) {
        AppLogger().debug('⚖️ Strategy 3 failed: $e');
      }
      
      // Strategy 4: Emergency fallback - try to create new audio track
      try {
        AppLogger().debug('⚖️ Strategy 4: Emergency fallback - creating new audio track...');
        _webrtcService.forceUpdateRole(_userRole!, 'arena');
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Try to enable with fresh connection
        await _webrtcService.enableAudio();
        AppLogger().info('⚖️ Strategy 4 SUCCESS: Emergency fallback worked');
        return;
      } catch (e) {
        AppLogger().debug('⚖️ Strategy 4 failed: $e');
      }
      
      // If all strategies fail, throw comprehensive error
      throw Exception('All judge audio enable strategies failed');
      
    } catch (e) {
      AppLogger().error('❌ JUDGE AUDIO 10/10: Enhanced setup failed: $e');
      rethrow;
    }
  }

  /// Force unmute functionality for stuck microphones
  Future<void> _forceUnmute() async {
    try {
      AppLogger().debug('🚨 FORCE UNMUTE: Attempting to force enable microphone');
      AppLogger().debug('🚨 User role: $_userRole, Can publish: ${_shouldUserPublishMedia()}');
      
      // Check if user has permission
      if (!_shouldUserPublishMedia()) {
        AppLogger().error('❌ User role $_userRole does not have microphone permissions');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Your role does not have microphone access'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Ensure WebRTC is connected
      if (!_isWebRTCConnected) {
        AppLogger().debug('🚨 Connecting to WebRTC first...');
        await _connectToWebRTC();
        await Future.delayed(const Duration(seconds: 1));
      }
      
      // CRITICAL iOS FIX: Force sync role with LiveKit before emergency audio operations
      if (_userRole != null) {
        AppLogger().debug('🔄 EMERGENCY iOS FIX: Force syncing role $_userRole before emergency unmute');
        _webrtcService.forceUpdateRole(_userRole!, 'arena');
      }
      
      // ENHANCED JUDGE AUDIO HANDLING - 10/10 for judges
      if (_userRole?.startsWith('judge') == true) {
        AppLogger().debug('⚖️ JUDGE AUDIO 10/10: Using enhanced judge audio setup...');
        await _handleJudgeAudioSetup();
      } else {
        // Try direct enable for other roles
        await _webrtcService.enableAudio();
      }
      
      // Update state
      if (mounted) {
        setState(() {
          _isMuted = false;
        });
      }
      
      AppLogger().info('✅ FORCE UNMUTE: Successfully enabled audio for $_userRole');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Microphone force enabled'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      AppLogger().error('❌ FORCE UNMUTE: Failed to force enable audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to enable microphone: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Force mute functionality 
  Future<void> _forceMute() async {
    try {
      AppLogger().debug('🔇 FORCE MUTE: Attempting to force disable microphone');
      
      // Try direct LiveKit disable
      await _webrtcService.disableAudio();
      
      // Update state
      if (mounted) {
        setState(() {
          _isMuted = true;
        });
      }
      
      AppLogger().info('🔇 FORCE MUTE: Successfully disabled audio');
      
    } catch (e) {
      AppLogger().error('❌ FORCE MUTE: Failed to force disable audio: $e');
    }
  }

  /// Test audio quality and noise cancellation
  Future<void> _testAudioQuality() async {
    try {
      AppLogger().debug('🎵 Testing Arena audio quality and noise cancellation...');
      
      // Show testing status
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎵 Testing audio quality...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Get noise cancellation status
      final noiseCancellationService = NoiseCancellationService();
      final isNoiseCancellationEnabled = noiseCancellationService.isEnabled;
      final isNoiseCancellationAvailable = noiseCancellationService.isAvailable;
      final platformInfo = noiseCancellationService.platformInfo;
      
      // Test audio by temporarily toggling mute state
      final wasMuted = _isMuted;
      if (!wasMuted) {
        await _webrtcService.disableAudio();
        await Future.delayed(const Duration(milliseconds: 500));
        await _webrtcService.enableAudio();
      }
      
      // Show results
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🎵 Audio Quality Test Results'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connection: ${_webrtcService.isConnected ? '✅ Connected' : '❌ Disconnected'}'),
                Text('Noise Cancellation: ${isNoiseCancellationEnabled ? '✅ Active' : '❌ Inactive'}'),
                Text('Available: ${isNoiseCancellationAvailable ? '✅ Yes' : '❌ No'}'),
                Text('Platform: $platformInfo'),
                const SizedBox(height: 8),
                const Text('Audio quality test completed successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      
      AppLogger().info('✅ Arena audio quality test completed');
      
    } catch (e) {
      AppLogger().error('❌ Failed to test Arena audio quality: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Audio quality test failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Video toggle removed - Arena is audio-only
  
  /// Simple, standard microphone button
  Widget _buildEnhancedMicButton() {
    return GestureDetector(
      // Regular tap for normal toggle
      onTap: _toggleAudio,
      
      // Long press for emergency options
      onLongPress: () {
        _showMicEmergencyControls();
      },
      
      child: Stack(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _isMuted ? Colors.red : Colors.green,
              borderRadius: BorderRadius.circular(8), // Rounded rectangle instead of circle
            ),
            child: Icon(
              _isMuted ? Icons.mic_off : Icons.mic,
              color: Colors.white,
              size: 24,
            ),
          ),
          
          // Connection status indicator
          if (_isReconnecting)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(
                      strokeWidth: 1,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Show emergency microphone control options
  void _showMicEmergencyControls() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            const Text(
              '🎤 Microphone Emergency Controls',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              'Current Status: ${_isMuted ? 'MUTED' : 'UNMUTED'}',
              style: TextStyle(
                fontSize: 16,
                color: _isMuted ? Colors.red : Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            
            // Emergency controls
            Column(
              children: [
                // Force Unmute
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _forceUnmute();
                    },
                    icon: const Icon(Icons.mic, color: Colors.white),
                    label: const Text('FORCE UNMUTE', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Force Mute
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _forceMute();
                    },
                    icon: const Icon(Icons.mic_off, color: Colors.white),
                    label: const Text('FORCE MUTE', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Normal Toggle
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _toggleAudio();
                    },
                    icon: Icon(_isMuted ? Icons.mic : Icons.mic_off),
                    label: Text(_isMuted ? 'Normal Unmute' : 'Normal Mute'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Test Audio Quality
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _testAudioQuality();
                    },
                    icon: const Icon(Icons.audiotrack, color: Colors.blue),
                    label: const Text('Test Audio Quality', style: TextStyle(color: Colors.blue)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Instructions:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Tap mic button: Normal toggle\n• Long press mic button: Emergency controls\n• Force controls bypass normal state checks',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                ),
                child: const Text('Close'),
              ),
            ),
            
            // Safe area padding
            SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Start periodic mute state sync to prevent stuck states
  void _startMuteStateSyncTimer() {
    // Cancel existing timer
    _muteStateSyncTimer?.cancel();
    
    // Start sync every 2 seconds
    _muteStateSyncTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || !_isWebRTCConnected) {
        timer.cancel();
        return;
      }
      
      _syncMuteState();
    });
  }
  
  /// Sync local mute state with LiveKit service state
  void _syncMuteState() {
    if (!_isWebRTCConnected) return;
    
    final livekitMuted = _webrtcService.isMuted;
    if (_isMuted != livekitMuted) {
      AppLogger().debug('🔄 Syncing mute state: local=$_isMuted, livekit=$livekitMuted');
      
      if (mounted) {
        setState(() {
          _isMuted = livekitMuted;
        });
      }
    }
  }

  /// Show screen share bottom sheet
  void _showShareScreenBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
              size: 48,
              color: _isScreenSharing ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              _isScreenSharing ? 'Stop Screen Sharing?' : 'Share Your Screen?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isScreenSharing 
                ? 'Your screen is currently being shared with all participants.'
                : 'Share your screen with all participants in the arena.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _toggleScreenShare();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScreenSharing ? Colors.red : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isScreenSharing ? 'Stop Sharing' : 'Start Sharing',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[600]!),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Toggle screen share
  Future<void> _toggleScreenShare() async {
    try {
      if (_isScreenSharing) {
        // TODO: Implement LiveKit screen share stop
        AppLogger().debug('📺 Screen share stop - to be implemented with LiveKit');
        if (mounted) {
          setState(() {
            _isScreenSharing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Screen sharing stopped'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // TODO: Implement LiveKit screen share start
        AppLogger().debug('📺 Screen share start - to be implemented with LiveKit');
        if (mounted) {
          setState(() {
            _isScreenSharing = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Screen sharing started'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger().error('Failed to toggle screen share: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isScreenSharing ? 'stop' : 'start'} screen share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }




  /// Clean up WebRTC resources
  void _disposeWebRTC() {
    try {
      AppLogger().debug('🛑 Disposing WebRTC resources...');
      
      // Disconnect from WebRTC service
      _webrtcService.disconnect();
      
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
        _winner = roomData['winner'];
        _judgingComplete = roomData['judgingComplete'] ?? false;
        _judgingEnabled = roomData['judgingEnabled'] ?? false;
        _teamSize = roomData['teamSize'] ?? 1; // Default to 1v1 if not specified
        
        // Don't auto-show results here - only show when moderator manually closes voting
        // or when user clicks "View Results" button
        
        // Check if current user has already submitted judgment
        if (_currentUserId != null) {
          final existingJudgments = await _appwrite.databases.listDocuments(
            databaseId: 'arena_db',
            collectionId: 'arena_judgments',
            queries: [
              Query.equal('roomId', widget.roomId),
              Query.equal('judgeId', _currentUserId!),
            ],
          );
          
          _hasCurrentUserSubmittedVote = existingJudgments.documents.isNotEmpty;
          AppLogger().debug('🔍 VOTE STATUS: Current user has submitted vote: $_hasCurrentUserSubmittedVote');
        }
        
        AppLogger().debug('🏆 Arena room loaded - Winner: $_winner, Judging Complete: $_judgingComplete, Judging Enabled: $_judgingEnabled');
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
              _webrtcService.forceUpdateRole(_userRole!, 'arena');
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
              _webrtcService.forceUpdateRole(_userRole!, 'arena');
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
                setState(() {});
              }
            }
          } catch (e) {
            AppLogger().error('Failed to add current user to audience as fallback: $e');
          }
        } else {
          AppLogger().debug('✅ Current user found - in participants: $currentUserInParticipants, in audience: $currentUserInAudience');
        }
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
        _userRole = currentUserParticipant['role'];
        AppLogger().debug('👤 Current user role: $_userRole');
        
        // Special logging for judges
        if (_userRole?.startsWith('judge') == true) {
          AppLogger().info('⚖️ USER IS A JUDGE: $_userRole');
          AppLogger().info('⚖️ Can publish media: ${_shouldUserPublishMedia()}');
          AppLogger().info('⚖️ WebRTC connected: $_isWebRTCConnected');
          
          // If judge and not connected, reconnect with proper permissions
          if (!_isWebRTCConnected) {
            AppLogger().info('⚖️ Judge needs WebRTC connection - connecting...');
            await _connectToWebRTC();
          }
        }
      } else {
        AppLogger().warning('Current user not found in participants list');
      }
      
      // Check if both debaters are now present and trigger invitation modal
      await _checkForBothDebatersAndTriggerInvitations();
      
      if (mounted) {
        setState(() {});
      }
      AppLogger().info('Arena participants loaded successfully');
      
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
    } catch (e) {
      AppLogger().error('Error loading participants: $e');
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
    
    if (mounted) setState(() {});
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
  
  // Enhanced Timer Management
  void _startPhaseTimer() {
    // Use current _remainingSeconds if it's set (custom time), otherwise use phase default
    final durationToUse = _remainingSeconds > 0 ? _remainingSeconds : (_currentPhase.defaultDurationSeconds ?? 0);
    
    if (durationToUse <= 0) {
      AppLogger().error('Cannot start timer: no valid duration');
      return;
    }
    
    if (mounted) {
      setState(() {
        _remainingSeconds = durationToUse;
        _isTimerRunning = true;
        _isPaused = false;
        _currentSpeaker = _currentPhase.speakerRole;
        _speakingEnabled = _currentSpeaker.isNotEmpty;
        _hasPlayed30SecWarning = false; // Reset warning flag for new phase
      });
    }
    
    _timerController.duration = Duration(seconds: durationToUse);
    _timerController.reset();
    _timerController.forward();
    
    AppLogger().info('Started timer with duration: ${durationToUse}s (phase: ${_currentPhase.displayName})');
    
    _timerController.addListener(() {
      if (mounted) {
        setState(() {
          final totalDuration = _timerController.duration?.inSeconds ?? durationToUse;
          _remainingSeconds = (totalDuration * (1 - _timerController.value)).round();
        });
        
        // Play 30-second warning sound (only once per phase)
        if (_remainingSeconds == 30 && !_hasPlayed30SecWarning && _isTimerRunning) {
          _hasPlayed30SecWarning = true;
          _soundService.play30SecWarningSound();
          AppLogger().debug('🔊 Playing 30-second warning sound');
        }
        
        if (_remainingSeconds <= 0) {
          // Play arena timer zero sound
          _soundService.playArenaZeroSound();
          _hasPlayed30SecWarning = false; // Reset for next phase
          _handlePhaseTimeout();
        }
      }
    });
  }

  void _pauseTimer() {
    if (mounted) {
      setState(() {
        _isPaused = true;
        _isTimerRunning = false;
      });
    }
    _timerController.stop();
  }

  void _resumeTimer() {
    if (mounted) {
      setState(() {
        _isPaused = false;
        _isTimerRunning = true;
      });
    }
    _timerController.forward();
  }

  void _stopTimer() {
    if (mounted) {
      setState(() {
        _isTimerRunning = false;
        _isPaused = false;
        _speakingEnabled = false;
      });
    }
    _timerController.stop();
  }


  void _handlePhaseTimeout() {
    _stopTimer();
    
    // Auto-advance to next phase if moderator
    if (_userRole == 'moderator') {
      _showPhaseTimeoutDialog();
    }
  }

  void _showPhaseTimeoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⏰ Time\'s Up!'),
        content: Text('${_currentPhase.displayName} phase has ended.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _extendTime(60); // Add 1 minute
            },
            child: const Text('Extend +1 min'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _advanceToNextPhase();
            },
            child: const Text('Next Phase'),
          ),
        ],
      ),
    );
  }

  void _extendTime(int additionalSeconds) {
    setState(() {
      _remainingSeconds += additionalSeconds;
    });
    
    // Adjust the timer controller
    final totalDuration = _currentPhase.defaultDurationSeconds! + additionalSeconds;
    final elapsedRatio = (_currentPhase.defaultDurationSeconds! - _remainingSeconds) / totalDuration;
    
    _timerController.duration = Duration(seconds: totalDuration);
    _timerController.value = elapsedRatio;
    
    if (_isTimerRunning) {
      _timerController.forward();
    }
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
  bool get _isModerator => _userRole == 'moderator';
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
    
    final newJudgingState = !_judgingEnabled;
    
    try {
      // If closing judging, check if we should determine winner and show results
      if (!newJudgingState && _judgingEnabled) {
        // Moderator is closing voting - determine winner
        await _determineWinnerAndShowResults();
      }
      
      // Update in database for real-time sync
      await _appwrite.updateArenaJudgingEnabled(widget.roomId, newJudgingState);
      
      setState(() {
        _judgingEnabled = newJudgingState;
      });
      
      AppLogger().info('Judging ${_judgingEnabled ? 'enabled' : 'disabled'} by moderator');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _judgingEnabled 
                  ? '⚖️ Judging is now OPEN - Judges can submit votes'
                  : '⚖️ Judging is now CLOSED - Calculating results...'
            ),
            backgroundColor: _judgingEnabled ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
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

  Future<void> _determineWinnerAndShowResults() async {
    try {
      AppLogger().debug('🏆 Determining winner and showing results...');
      
      // Get all judgments for this room
      final judgments = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_judgments',
        queries: [
          Query.equal('roomId', widget.roomId),
        ],
      );

      if (judgments.documents.isEmpty) {
        AppLogger().warning('No votes found, cannot determine winner');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No votes submitted yet'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Count votes and calculate scores (supports both old votes and new scorecards)
      int affirmativeVotes = 0;
      int negativeVotes = 0;
      int totalAffirmativeScore = 0;
      int totalNegativeScore = 0;
      List<Map<String, dynamic>> scorecardDetails = [];
      
      for (var judgment in judgments.documents) {
        final winner = judgment.data['winner'];
        final affirmativeTotal = judgment.data['affirmativeTotal'] ?? 0;
        final negativeTotal = judgment.data['negativeTotal'] ?? 0;
        final judgeName = judgment.data['judgeName'] ?? 'Unknown Judge';
        
        // Count votes (compatible with old and new systems)
        if (winner == 'affirmative') {
          affirmativeVotes++;
        } else if (winner == 'negative') {
          negativeVotes++;
        }
        
        // Accumulate scores for new scorecard system
        totalAffirmativeScore += (affirmativeTotal as num).toInt();
        totalNegativeScore += (negativeTotal as num).toInt();
        
        // Store detailed scorecard info for display
        scorecardDetails.add({
          'judgeName': judgeName,
          'winner': winner,
          'affirmativeScore': affirmativeTotal,
          'negativeScore': negativeTotal,
          'reasoning': judgment.data['reasonForDecision'] ?? '',
        });
      }
      
      // Determine winner (now with both vote count and score totals)
      String winner;
      if (affirmativeVotes > negativeVotes) {
        winner = 'affirmative';
      } else if (negativeVotes > affirmativeVotes) {
        winner = 'negative';
      } else if (totalAffirmativeScore > totalNegativeScore) {
        // Use total scores as tiebreaker
        winner = 'affirmative';
      } else if (totalNegativeScore > totalAffirmativeScore) {
        winner = 'negative';
      } else {
        winner = 'tie';
      }
      
      AppLogger().debug('🏆 Winner determined: $winner');
      AppLogger().debug('📊 Vote breakdown - Affirmative: $affirmativeVotes votes ($totalAffirmativeScore points), Negative: $negativeVotes votes ($totalNegativeScore points)');
      
      // Update room with winner and mark judging as complete
      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: widget.roomId,
        data: {
          'winner': winner,
          'judgingComplete': true,
          'judgingEnabled': false,
        },
      );
      
      // Update local state
      setState(() {
        _winner = winner;
        _judgingComplete = true;
        _judgingEnabled = false;
      });
      
      // Show results modal after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_resultsModalShown) {
          _showResultsModal();
        }
      });
      
    } catch (e) {
      AppLogger().error('Error determining winner: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error calculating results: $e'),
          backgroundColor: Colors.red,
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

  void _showTimerControlModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        color: Colors.transparent,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.5, // Half screen height
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: TimerControlModal(
            remainingSeconds: _remainingSeconds,
            isTimerRunning: _isTimerRunning,
            isPaused: _isPaused,
            onStart: _startPhaseTimer,
            onPause: _pauseTimer,
            onResume: _resumeTimer,
            onStop: _stopTimer,
            onReset: _resetTimer,
            onExtendTime: _extendTime,
            onSetCustomTime: _setCustomTime,
          ),
        ),
      ),
    );
  }

  void _setCustomTime(int seconds) {
    setState(() {
      _remainingSeconds = seconds;
      if (_isTimerRunning) {
        AppLogger().debug('🛑 Stopping timer to set custom time');
        _stopTimer();
      }
    });
    
    // Update the controller duration for the new time
    _timerController.duration = Duration(seconds: seconds);
    _timerController.reset();
    
    AppLogger().debug('⏱️ Set custom time: ${seconds}s (timer ready to start)');
  }

  void _showUserProfile(UserProfile userProfile, String? userRole) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => UserProfileBottomSheet(
        user: userProfile,
        onFollow: () {
          // TODO: Implement follow functionality
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Following ${userProfile.name}'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        },
        onChallenge: () {
          // Challenge functionality is now handled directly by UserProfileBottomSheet
          debugPrint('Challenge functionality delegated to UserProfileBottomSheet');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        appBar: ArenaAppBar(
          isModerator: _isModerator,
          isTimerRunning: _isTimerRunning,
          formattedTime: _formattedTime,
          onShowModeratorControls: _showModeratorControlModal,
          onShowTimerControls: _showTimerControlModal,
          onExitArena: _exitArena,
          onEmergencyCloseRoom: _emergencyCloseRoom,
          roomId: widget.roomId,
          userId: _currentUserId ?? 'unknown',
        ),
        body: Column(
          children: [
            Expanded(
              child: _buildMainArena(),
            ),
            _buildControlPanel(),
          ],
        ),
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
              
              // If moderator is leaving, close the entire room
              if (_isModerator) {
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
      _realtimeSubscription?.cancel();
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
      
      // 1. Update room status to abandoned (only using existing schema fields)
      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: widget.roomId,
        data: {
          'status': 'abandoned',
        },
      );
      
      // 2. Remove all participants
      final participants = await _appwrite.getArenaParticipants(widget.roomId);
      for (final participant in participants) {
        try {
          await _appwrite.databases.deleteDocument(
            databaseId: 'arena_db',
            collectionId: 'arena_participants',
            documentId: participant['id'],
          );
        } catch (e) {
          AppLogger().warning('Error removing participant ${participant['id']}', e);
        }
      }
      
      AppLogger().info('Room closed and all participants removed');
      
    } catch (e) {
      AppLogger().error('Error closing room: $e');
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
        
        // Adjust heights based on available space - balanced for comfort and visibility
        final judgeHeight = isIOS
            ? (isSmallScreen ? 100.0 : 115.0) // Comfortable judge size
            : (isSmallScreen ? 115.0 : 130.0); // Comfortable judge size
        // Different heights for 1v1 vs 2v2 modes
        final debaterHeight1v1 = isIOS
            ? (isSmallScreen ? 120.0 : 140.0) // Good size for 1v1
            : (isSmallScreen ? 140.0 : 160.0); // Good size for 1v1
        // For 2v2: balanced size for comfort while showing audience
        final debaterHeight2v2 = isIOS
            ? (isSmallScreen ? 200.0 : 220.0) // Comfortable for 2v2 (2 rows of debaters)
            : (isSmallScreen ? 220.0 : 250.0); // Comfortable for 2v2 (2 rows of debaters)
        final moderatorHeight = isIOS
            ? (isSmallScreen ? 85.0 : 95.0) // Reasonable moderator size
            : (isSmallScreen ? 95.0 : 110.0); // Reasonable moderator size
        
        // Calculate total debate section height dynamically - use appropriate debater height
        final debaterHeight = _teamSize == 1 ? debaterHeight1v1 : debaterHeight2v2;
        final sectionSpacing = _teamSize == 1 ? 10 : 8; // Balanced spacing for 2v2
        final debateSectionHeight = 4 + // top padding
            30 + // title height
            4 + // margin after title
            debaterHeight + // debaters (1v1 or 2v2 height)
            sectionSpacing + // spacing
            moderatorHeight + // moderator 
            sectionSpacing + // spacing
            judgeHeight + // judges
            4 + // bottom spacing
            4; // bottom padding
        
        AppLogger().debug('🎭 ARENA LAYOUT: Debate section height: $debateSectionHeight');
        
        return Stack(
          children: [
            // Audience section as background (scrollable)
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.only(
                  top: debateSectionHeight,
                  bottom: 40, // Minimal bottom margin to maximize audience visibility
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
                            deepPurple.withValues(alpha: 0.3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12), // Slightly more rounded
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.5), // Gold border to match text
                          width: 2, // Thicker border for more presence
                        ),
                        boxShadow: [ // Add subtle shadow for depth
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
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
                                const SizedBox(width: 20),
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
                                const SizedBox(width: 16), // Space between teams
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
                      
                      SizedBox(height: _teamSize == 1 ? 10 : 6), // Less spacing for 2v2
                      
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
                      
                      SizedBox(height: _teamSize == 1 ? 10 : 6), // Less spacing for 2v2
                      
                      // Bottom Row - Judges (responsive height)
                      SizedBox(
                        height: judgeHeight,
                        child: Row(
                          children: [
                            Expanded(child: _buildJudgePosition('judge1', 'Judge 1')),
                            const SizedBox(width: 4),
                            Expanded(child: _buildJudgePosition('judge2', 'Judge 2')),
                            const SizedBox(width: 4),
                            Expanded(child: _buildJudgePosition('judge3', 'Judge 3')),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 4), // Further reduced spacing
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
  
  Widget _buildAudienceScrollSection() {
    return Container(
      color: const Color(0xFF1a1a1a), // Match the main arena background
      height: double.infinity, // Ensure full height usage
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visual separator line
            Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: accentPurple.withValues(alpha: 0.5),
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
                    color: accentPurple.withValues(alpha: 0.3),
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
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0, // Better aspect ratio for circular avatars
                ),
                itemCount: _audience.length,
                itemBuilder: (context, index) {
                  final audience = _audience[index];
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UserAvatar(
                        avatarUrl: audience.avatar,
                        initials: audience.name.isNotEmpty ? audience.name[0] : '?',
                        radius: 32, // Slightly larger to ensure full visibility
                        onTap: () => _showUserProfile(audience, 'audience'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        audience.name.length > 8
                            ? '${audience.name.substring(0, 8)}...'
                            : audience.name,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
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
        color: finalIsWinner ? Colors.amber.withValues(alpha: 0.1) : (isAffirmative ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1)),
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
                  : (isAffirmative ? Colors.green : Colors.red),
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
        color: isPurple ? accentPurple.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
        border: Border.all(color: isPurple ? accentPurple : Colors.amber, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isPurple ? accentPurple : Colors.amber,
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
            child: judge != null
                ? _buildJudgeTile(judge, role, isSmall: true)
                : _buildEmptyPosition('Waiting...', isSmall: true),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyPosition(String text, {bool isSmall = false}) {
    return Padding(
      padding: const EdgeInsets.all(8), // Increased to match other tiles for consistency
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white54,
            fontSize: isSmall ? 9 : 10, // Reduced sizes
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Build audio-only tile for debater with microphone status
  Widget _buildDebaterTile(UserProfile participant, String role, {bool isSmall = false, bool isWinner = false}) {
    final nameSize = isSmall ? 9.0 : 10.0;
    
    // Find the peer ID for this user to get their audio/video stream
    final peerId = _userToPeerMapping[participant.id];
    final stream = peerId != null ? _remoteStreams[peerId] : null;
    
    AppLogger().debug('🎥 Building tile for ${participant.name}: peerId=$peerId, stream=${stream != null}, userMapping=$_userToPeerMapping');
    
    // Check if we have audio stream
    final hasAudio = stream != null && 
                     stream.getAudioTracks().isNotEmpty &&
                     stream.getAudioTracks().any((track) => track.enabled);
    
    // For local user, check local audio
    final isLocalUser = participant.id == _currentUserId;
    final localHasAudio = isLocalUser && 
                         _localStream != null && 
                         _localStream!.getAudioTracks().isNotEmpty &&
                         _localStream!.getAudioTracks().any((track) => track.enabled);
    
    // Determine if user is speaking (for now, just show if they have audio capability)
    final isSpeaking = isLocalUser ? localHasAudio && !_isMuted : hasAudio;
    
    return Padding(
      padding: const EdgeInsets.all(8), // Increased from 4 to 8 for more room
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Audio participant container
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isWinner ? Colors.amber : (isSpeaking ? Colors.green : Colors.white30),
                  width: isWinner ? 2 : (isSpeaking ? 2 : 1),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Stack(
                  children: [
                    // Video feed or avatar background
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
                                onFollow: () {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Following ${participant.name}'),
                                        backgroundColor: const Color(0xFF10B981),
                                      ),
                                    );
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
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Name label (with profile tap for non-local users)
          GestureDetector(
            onTap: !isLocalUser ? () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => UserProfileBottomSheet(
                  user: participant,
                  onFollow: () {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Following ${participant.name}'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
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
            } : null,
            child: Text(
              participant.name,
              style: TextStyle(
                color: isWinner ? Colors.amber : Colors.white,
                fontWeight: isWinner ? FontWeight.bold : FontWeight.w600,
                fontSize: nameSize,
                shadows: isWinner ? [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 2,
                  ),
                ] : null,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
      final is1v1Mode = _teamSize == 1;
      final participantUserId = participant.id;
      final isSpeaking = _speakingService.isUserSpeaking(participantUserId);
      const isMuted = false; // TODO: Get actual mute state from LiveKit
      
      return Center(
        child: UserAvatarStatus(
          avatarUrl: participant.avatar,
          initials: participant.name.isNotEmpty ? participant.name[0] : '?',
          radius: is1v1Mode ? (isSmall ? 16.0 : 24.0) : (isSmall ? 20.0 : 35.0), // Smaller for 1v1, larger for 2v2
          isSpeaking: isSpeaking,
          isMuted: isMuted,
          userRole: _getUserRoleById(participantUserId),
          isOnline: true,
        ),
      );
    }
  }
  
  /// Build controls and indicators for debater
  Widget _buildDebaterControls(UserProfile participant, String role, bool isLocalUser, bool isSpeaking, bool isSmall) {
    return Stack(
      children: [
        // Top-right: Audio status indicators
        Positioned(
          top: 4,
          right: 4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Audio status indicator
              if (isLocalUser && _isMuted)
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
              else if (isSpeaking)
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
                color: Colors.amber.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
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
                  if (_webrtcService.room != null) {
                    final liveKitParticipant = _webrtcService.room!.remoteParticipants.values
                        .firstWhere(
                          (p) => p.identity == participant.id,
                          orElse: () => _webrtcService.room!.remoteParticipants.values.first,
                        );
                    isCurrentlyMuted = _webrtcService.isParticipantMuted(liveKitParticipant);
                  }
                  
                  // Toggle mute/unmute
                  if (isCurrentlyMuted) {
                    await _webrtcService.unmuteParticipant(participant.id);
                    AppLogger().debug('🎤 Moderator unmuted ${participant.name}');
                  } else {
                    await _webrtcService.muteParticipant(participant.id);
                    AppLogger().debug('🔇 Moderator muted ${participant.name}');
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
    
    // Find the peer ID for this user to get their audio stream
    final peerId = _userToPeerMapping[participant.id];
    final stream = peerId != null ? _remoteStreams[peerId] : null;
    
    // Check if we have audio stream
    final hasAudio = stream != null && 
                     stream.getAudioTracks().isNotEmpty &&
                     stream.getAudioTracks().any((track) => track.enabled);
    
    // For local user, check local audio
    final isLocalUser = participant.id == _currentUserId;
    final localHasAudio = isLocalUser && 
                         _localStream != null && 
                         _localStream!.getAudioTracks().isNotEmpty &&
                         _localStream!.getAudioTracks().any((track) => track.enabled);
    
    // Determine if user is speaking (for now, just show if they have audio capability)
    final isSpeaking = isLocalUser ? localHasAudio && !_isMuted : hasAudio;
    
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => UserProfileBottomSheet(
            user: participant,
            onFollow: () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Following ${participant.name}'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
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
        padding: const EdgeInsets.all(8), // Increased from 4 to 8 to match debater tiles
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Video feed container
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSpeaking ? Colors.green : Colors.amber.withValues(alpha: 0.5), 
                    width: isSpeaking ? 2 : 1
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    children: [
                      // Always show avatar for audio-only mode - make it fill the slot properly
                      // For 1v1 mode, use smaller avatars; for 2v2 mode, use larger avatars
                      Center(
                        child: UserAvatar(
                          avatarUrl: participant.avatar,
                          initials: participant.name.isNotEmpty ? participant.name[0] : '?',
                          radius: _teamSize == 1 ? (isSmall ? 16.0 : 24.0) : (isSmall ? 20.0 : 35.0), // Smaller for 1v1, larger for 2v2
                        ),
                      ),
                      
                      // Audio status indicators
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Audio status indicator
                            if (isLocalUser && _isMuted)
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
                            else if (isSpeaking)
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

                      // Moderator controls for judges (mute/unmute buttons)
                      if (_isModerator && !isLocalUser)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
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
                                if (_webrtcService.room != null) {
                                  final liveKitParticipant = _webrtcService.room!.remoteParticipants.values
                                      .firstWhere(
                                        (p) => p.identity == participant.id,
                                        orElse: () => _webrtcService.room!.remoteParticipants.values.first,
                                      );
                                  isCurrentlyMuted = _webrtcService.isParticipantMuted(liveKitParticipant);
                                }
                                
                                // Toggle mute/unmute
                                if (isCurrentlyMuted) {
                                  await _webrtcService.unmuteParticipant(participant.id);
                                  AppLogger().debug('🎤 Moderator unmuted judge ${participant.name}');
                                } else {
                                  await _webrtcService.muteParticipant(participant.id);
                                  AppLogger().debug('🔇 Moderator muted judge ${participant.name}');
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
            const SizedBox(height: 2),
            // Name label
            Text(
              participant.name,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: nameSize,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    // Always show control panel - at minimum for gifting
    // Specific controls will be filtered based on role

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
              // View Results button (when judging is complete)
              if (_judgingComplete && _winner != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildControlButton(
                    icon: Icons.emoji_events,
                    label: 'View Results',
                    onPressed: _showResultsModal,
                    color: Colors.amber,
                  ),
                ),
              
              // Judge Panel (only for moderators and judges)
              if ((_isJudge || _isModerator) && !_judgingComplete)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildControlButton(
                    icon: _hasCurrentUserSubmittedVote 
                        ? Icons.check_circle 
                        : (_judgingEnabled ? Icons.gavel : Icons.gavel_outlined),
                    label: _hasCurrentUserSubmittedVote 
                        ? 'Vote Submitted' 
                        : (_judgingEnabled ? 'Judge' : 'Vote Closed'),
                    onPressed: _hasCurrentUserSubmittedVote 
                        ? null 
                        : (_judgingEnabled ? _showJudgingPanel : null),
                    color: _hasCurrentUserSubmittedVote 
                        ? Colors.green 
                        : (_judgingEnabled ? Colors.amber : Colors.grey),
                    isEnabled: !_hasCurrentUserSubmittedVote && _judgingEnabled,
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
                    icon: _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                    label: _isScreenSharing ? 'Stop Share' : 'Share Screen',
                    onPressed: _showShareScreenBottomSheet,
                    color: _isScreenSharing ? Colors.red : Colors.green,
                  ),
                ),

              // Enhanced Microphone toggle (always visible for eligible users with emergency options)
              if (_shouldUserPublishMedia())
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildEnhancedMicButton(),
                ),


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
    
    return GestureDetector(
      onTap: actuallyEnabled ? onPressed : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10), // Reduced from 12
            decoration: BoxDecoration(
              color: actuallyEnabled ? color : Colors.grey[600],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20, // Reduced from 24
            ),
          ),
          const SizedBox(height: 3), // Reduced from 4
          Text(
            label,
            style: TextStyle(
              color: actuallyEnabled ? Colors.white : Colors.grey[400],
              fontSize: 10, // Reduced from 12
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _resetTimer() {
    _timerController.reset();
    if (mounted) {
      setState(() {
        _remainingSeconds = _currentPhase.defaultDurationSeconds ?? 0;
        _isTimerRunning = false;
        _isPaused = false;
        _speakingEnabled = false;
        _hasPlayed30SecWarning = false; // Reset warning flag
      });
    }
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
    
    // Additional validation
    if (!_judgingEnabled) {
      AppLogger().warning('🎯 JUDGE PANEL: Judging not enabled');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Voting is not open yet. The moderator must enable judging first.'),
          backgroundColor: Colors.red,
        ),
      );
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

  void _showRoleManager() {
    final currentModerator = _participants['moderator'];
    final isDebater = _userRole == 'affirmative' || _userRole == 'negative';
    final isModerator = _userRole == 'moderator';
    
    AppLogger().debug('🎭 ROLES: User role: $_userRole, isDebater: $isDebater, isModerator: $isModerator');
    AppLogger().debug('🎭 ROLES: Current moderator: ${currentModerator?.name}');
    
    if (currentModerator == null && isDebater) {
      // No moderator assigned and user is a debater - show moderator selection from audience
      AppLogger().debug('🎭 ROLES: Showing moderator selection for debater');
      _showModeratorSelectionFromAudience();
    } else if (currentModerator != null && isModerator) {
      // Moderator is assigned and user is the moderator - show judge selection
      AppLogger().debug('🎭 ROLES: Showing judge selection for moderator');
      _showRoleSelection();
    } else {
      // Default: show read-only participant view
      AppLogger().debug('🎭 ROLES: Showing read-only participant view');
      _showParticipantView();
    }
  }

  /// Show moderator selection modal for debaters to choose from audience
  void _showModeratorSelectionFromAudience() {
    AppLogger().debug('🎭 MODERATOR SELECTION: _audience.length = ${_audience.length}');
    AppLogger().debug('🎭 MODERATOR SELECTION: _audience members:');
    for (var member in _audience) {
      AppLogger().debug('🎭   - ${member.name} (${member.email})');
    }
    
    if (_audience.isEmpty) {
      AppLogger().debug('🎭 MODERATOR SELECTION: No audience members available');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audience members available to select as moderator'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                  const Icon(Icons.gavel, color: accentPurple),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Select Moderator from Audience',
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
            
            // Audience list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _audience.length,
                itemBuilder: (context, index) {
                  final audienceMember = _audience[index];
                  return ListTile(
                    leading: UserAvatar(
                      avatarUrl: audienceMember.avatar,
                      initials: audienceMember.name.isNotEmpty ? audienceMember.name[0].toUpperCase() : '?',
                      radius: 20,
                    ),
                    title: Text(audienceMember.name),
                    subtitle: Text(
                      audienceMember.isAvailableAsModerator 
                          ? 'Available as moderator' 
                          : 'Audience member',
                      style: TextStyle(
                        color: audienceMember.isAvailableAsModerator ? Colors.green : Colors.grey,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _assignModeratorFromAudience(audienceMember),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  /// Assign selected audience member as moderator
  Future<void> _assignModeratorFromAudience(UserProfile selectedUser) async {
    try {
      Navigator.pop(context); // Close modal
      
      AppLogger().debug('🎭 ASSIGN: Assigning ${selectedUser.name} as moderator');
      
      // Update user's role in the database
      await _appwrite.assignArenaRole(
        roomId: widget.roomId,
        userId: selectedUser.id,
        role: 'moderator',
      );
      
      // Refresh participants to update UI
      await _loadParticipants();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${selectedUser.name} is now the moderator!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      AppLogger().error('Error assigning moderator: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning moderator: $e')),
        );
      }
    }
  }
  
  /// Show judge selection modal for moderator
  void _showRoleSelection() {
    AppLogger().debug('🎭 ROLE SELECTION DEBUG:');
    AppLogger().debug('🎭 Total _audience.length = ${_audience.length}');
    AppLogger().debug('🎭 _audience members:');
    for (var member in _audience) {
      AppLogger().debug('🎭   - ${member.name} (${member.email}) [ID: ${member.id}]');
    }
    AppLogger().debug('🎭 Total _participants: ${_participants.length}');
    _participants.forEach((role, participant) {
      if (participant != null) {
        AppLogger().debug('🎭   - $role: ${participant.name} (${participant.email})');
      }
    });
    
    if (_audience.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audience members available for role assignment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RoleSelectionModal(
        audience: _audience,
        onRoleAssigned: (UserProfile user, String role) => _assignRoleToUser(user, role),
        availableJudgeSlots: _getAvailableJudgeSlots(),
        teamSize: _teamSize,
        hasAffirmativeDebater: _hasRoleAssigned('affirmative'),
        hasNegativeDebater: _hasRoleAssigned('negative'),
        hasAffirmative2Debater: _hasRoleAssigned('affirmative2'),
        hasNegative2Debater: _hasRoleAssigned('negative2'),
        hasJudge1: _hasRoleAssigned('judge1'),
        hasJudge2: _hasRoleAssigned('judge2'),
        hasJudge3: _hasRoleAssigned('judge3'),
      ),
    );
  }

  /// Check if a role is already assigned
  bool _hasRoleAssigned(String role) {
    return _participants.values.any((participant) => 
      participant != null && _getUserRole(participant) == role);
  }
  
  /// Get user role from participant data (helper method)
  String _getUserRole(UserProfile user) {
    // Check if this user has a specific role assigned in the arena
    for (final entry in _participants.entries) {
      if (entry.value?.id == user.id) {
        return entry.key; // The key is the role (affirmative, negative, judge1, etc.)
      }
    }
    return 'audience'; // Default to audience if no specific role found
  }

  /// Assign a role to a user (unified method for all roles)
  Future<void> _assignRoleToUser(UserProfile user, String role) async {
    try {
      await _appwrite.assignArenaRole(
        roomId: widget.roomId,
        userId: user.id,
        role: role,
      );
      
      // Refresh participants
      await _loadParticipants();
      
      // Show success message
      if (mounted) {
        final roleDisplayName = role == 'affirmative' ? 'Affirmative Debater' :
                               role == 'affirmative2' ? 'Affirmative 2' :
                               role == 'negative' ? 'Negative Debater' :
                               role == 'negative2' ? 'Negative 2' :
                               role.startsWith('judge') ? 'Judge' :
                               role.replaceAll('_', ' ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${user.name} assigned as $roleDisplayName'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Close the modal
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to assign role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  
  /// Check if current user is a debater
  bool get _isDebater {
    return _userRole == 'affirmative' || _userRole == 'negative';
  }

  
  /// Show read-only participant view
  void _showParticipantView() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
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
            UserAvatar(
              avatarUrl: user.avatar,
              initials: user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              radius: 16,
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
    if (_resultsModalShown) return;
    
    _resultsModalShown = true;
    
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
          _realtimeSubscription?.cancel();
          _realtimeSubscription = null;
          
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
          // Only log status every 5 iterations to reduce spam
          if (_roomStatusCheckerIterations % 5 == 0) {
            AppLogger().debug('🔍 Status check #$_roomStatusCheckerIterations: $roomStatus (every ${interval}ms)');
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
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    
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
      AppLogger().debug('🎭 DEBUG: _checkForBothDebatersAndTriggerInvitations called');
      
      final affirmative = _participants['affirmative'];
      final negative = _participants['negative'];
      
      AppLogger().debug('🎭 DEBUG: Affirmative participant: $affirmative');
      AppLogger().debug('🎭 DEBUG: Negative participant: $negative');
      
      final bothPresent = affirmative != null && negative != null;
      
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
      
      if (bothPresent) {
        AppLogger().debug('🎭 DEBUG: Both present but modal already shown or in progress');
        _bothDebatersPresent = true;
      } else {
        AppLogger().debug('🎭 DEBUG: Not both debaters present yet');
        _bothDebatersPresent = false;
      }
    } catch (e) {
      AppLogger().error('Error checking for both debaters: $e');
    }
  }



  /// Send invitation to single agreed-upon moderator






  /// Perform the mixed invitation system (personal + random)

  void _emergencyCloseRoom() {
    // Show confirmation dialog for emergency room closure
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, color: Colors.red, size: 20),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Emergency Close Room',
                style: TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          child: const Text(
            'Are you sure you want to immediately close this room? This action cannot be undone and will end the debate for all participants.',
            style: TextStyle(fontSize: 14),
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
      
      // Simple emergency close - just delete all participants and close room
      final participants = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.equal('roomId', widget.roomId),
        ],
      );
      
      AppLogger().info('🚨 Found ${participants.documents.length} participants to remove');
      
      // Delete all participants from the room
      for (final participant in participants.documents) {
        try {
          await _appwrite.databases.deleteDocument(
            databaseId: 'arena_db',
            collectionId: 'arena_participants',
            documentId: participant.$id,
          );
          AppLogger().info('🚨 Removed participant: ${participant.$id}');
        } catch (e) {
          AppLogger().warning('🚨 Failed to remove participant ${participant.$id}: $e');
        }
      }
      
      // Update room status to closed (only use existing fields)
      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: widget.roomId,
        data: {
          'status': 'closed',
        },
      );
      
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

  void _forceExitArena() {
    AppLogger().info('🚪 Force exiting arena after emergency close');
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ArenaApp()),
        (route) => false,
      );
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
      await _appwrite.assignArenaRole(
        roomId: widget.roomId,
        userId: userId,
        role: newRole,
      );
      
      // Refresh participants list
      await _loadParticipants();
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
                    UserAvatar(
                      avatarUrl: profile.avatar,
                      initials: profile.name.isNotEmpty ? profile.name[0] : '?',
                      radius: 50,
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
      height: MediaQuery.of(context).size.height * 0.8,
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
                        backgroundImage: profile.avatar != null 
                            ? NetworkImage(profile.avatar!)
                            : null,
                        child: profile.avatar == null 
                            ? Text(profile.name.isNotEmpty ? profile.name[0] : '?')
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
                      color: _getRoleColor(currentRole).withValues(alpha: 0.1),
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
        maxHeight: MediaQuery.of(context).size.height * 0.8,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
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
              color: Colors.black.withValues(alpha: 0.3),
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
              color: Colors.white.withValues(alpha: 0.2),
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
                  Colors.amber.withValues(alpha: 0.1),
                  Colors.orange.withValues(alpha: 0.1),
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
                const SizedBox(height: 6), // Reduced from 8
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
                color: accentPurple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentPurple.withValues(alpha: 0.2)),
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
                  const SizedBox(height: 6), // Reduced from 8
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
              child: UserAvatar(
                avatarUrl: winningDebater1.avatar,
                initials: winningDebater1.name.isNotEmpty ? winningDebater1.name[0] : '?',
                radius: 24,
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
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: UserAvatar(
              avatarUrl: debater.avatar,
              initials: debater.name.isNotEmpty ? debater.name[0] : '?',
              radius: 20,
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
              color: Colors.black.withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
                      color: Colors.amber.withValues(alpha: 0.2),
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
                                ? Colors.amber.withValues(alpha: 0.2) 
                                : Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected 
                                ? Border.all(color: Colors.amber, width: 2)
                                : null,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.amber,
                              child: Text(
                                (judge['name'] ?? 'J')[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
      setState(() {});
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
        maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                            backgroundColor: Colors.grey.shade300,
                            child: Text(
                              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
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
                            backgroundColor: Colors.amber.shade300,
                            child: Text(
                              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
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
        color: isAssigned ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
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