import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../services/challenge_messaging_service.dart';
import '../services/sound_service.dart';
import '../services/chat_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/debater_invite_choice_modal.dart';
import '../models/user_profile.dart';
import '../models/message.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../main.dart' show ArenaApp, getIt;
import '../core/logging/app_logger.dart';
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
    final phases = DebatePhase.values;
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
  final ChallengeMessagingService _messagingService = ChallengeMessagingService();
  final ChatService _chatService = ChatService();
  late final SoundService _soundService;
  
  // Room data
  Map<String, dynamic>? _roomData;
  UserProfile? _currentUser;
  String? _currentUserId;
  String? _userRole;
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
  StreamSubscription? _realtimeSubscription; // Track realtime subscription
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
  bool _speakingEnabled = false;
  
  // Participants by role
  Map<String, UserProfile?> _participants = {
    'affirmative': null,
    'negative': null,
    'moderator': null,
    'judge1': null,
    'judge2': null,
    'judge3': null,
  };
  
  List<UserProfile> _audience = [];
  
  // Two-stage invitation system state
  bool _bothDebatersPresent = false;
  bool _invitationModalShown = false;
  bool _invitationsInProgress = false;
  Map<String, String?> _affirmativeSelections = {'moderator': null};
  Map<String, String?> _negativeSelections = {'moderator': null};
  bool _affirmativeCompletedSelection = false;
  bool _negativeCompletedSelection = false;
  bool _waitingForOtherDebater = false;
  
  // Chat state
  List<Message> _chatMessages = [];
  StreamSubscription? _chatSubscription;
  final TextEditingController _chatController = TextEditingController();
  
  // Colors
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);
  static const Color lightGray = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    
    // Initialize services
    _soundService = getIt<SoundService>();
    
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
    
    // Step 6: Initialize chat service
    _initializeChatService();
    
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
    
    // Step 5: Initialize chat service
    _initializeChatService();
  }

  /// Initialize chat service and subscribe to messages
  void _initializeChatService() {
    AppLogger().debug('💬 Initializing chat service for room: ${widget.roomId}');
    
    // Subscribe to chat messages stream
    _chatSubscription = _chatService.messagesStream.listen((messages) {
      if (mounted) {
        setState(() {
          _chatMessages = messages.reversed.toList(); // Reverse for display (newest at bottom)
        });
        AppLogger().debug('💬 Received ${messages.length} chat messages');
      }
    });
    
    // Subscribe to real-time messages for this room
    _chatService.subscribeToRoomMessages(widget.roomId);
    
    AppLogger().debug('💬 Chat service initialized successfully');
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
    
    AppLogger().debug('🛑 DISPOSE: Cancelling realtime subscription...');
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    
    AppLogger().debug('🛑 DISPOSE: Cleaning up chat service...');
    _chatSubscription?.cancel();
    _chatSubscription = null;
    _chatService.unsubscribe();
    _chatController.dispose();
    
    _timerController.dispose();
    
    // Restart notification service to ensure user can receive new invites
    // Note: NotificationService singleton continues running - no restart needed
    
    super.dispose();
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
            if (!_isRealtimeHealthy) {
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
            
            // Add comprehensive null check for payload - ENHANCED
            if (response.payload == null) {
              AppLogger().warning('Received null payload in arena update - skipping');
              return;
            }
            
            // Ensure payload is a valid Map with enhanced safety
            Map<String, dynamic> payload;
            try {
              if (response.payload is Map<String, dynamic>) {
                payload = response.payload as Map<String, dynamic>;
              } else if (response.payload is Map) {
                payload = Map<String, dynamic>.from(response.payload as Map);
              } else {
                AppLogger().warning('Received invalid payload type: ${response.payload.runtimeType} - skipping');
                return;
              }
              
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
                  setState(() {
                    _affirmativeCompletedSelection = completedSelection;
                  });
                  AppLogger().debug('🎭 Updated affirmative completion status: $completedSelection');
                } else if (completedUserId == widget.challengedId) {
                  setState(() {
                    _negativeCompletedSelection = completedSelection;
                  });
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
          
          setState(() {
            _isRealtimeHealthy = false;
          });
          
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
              SnackBar(
                content: Text('🔒 This arena room has been closed'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
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
        final previousJudgingComplete = _judgingComplete;
        _winner = roomData['winner'];
        _judgingComplete = roomData['judgingComplete'] ?? false;
        _judgingEnabled = roomData['judgingEnabled'] ?? false;
        
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
          AppLogger().debug('🔍 Assigning current user to audience...');
          // Assign current user to audience by default
          await _appwrite.assignArenaRole(
            roomId: widget.roomId,
            userId: _currentUserId!,
            role: 'audience',
          );
          AppLogger().info('Assigned current user to audience');
          
          // Longer delay to ensure database operation completes and propagates
          await Future.delayed(const Duration(milliseconds: 1000));
          AppLogger().debug('🔍 About to reload participants after audience assignment');
        }
      } else {
        // User already has a role - check if it's an important role before potentially overriding
        final existingParticipant = existingParticipants.firstWhere(
          (p) => p['userId'] == _currentUserId,
          orElse: () => <String, dynamic>{},
        );
        
        final existingRole = existingParticipant['role'];
        final importantRoles = ['affirmative', 'negative', 'moderator', 'judge1', 'judge2', 'judge3'];
        
        if (importantRoles.contains(existingRole)) {
          AppLogger().info('User already has important role: $existingRole - preserving it');
        } else {
          AppLogger().debug('🔍 User has non-important role: $existingRole - allowing potential reassignment');
        }
      }
      
      setState(() {
        _roomData = roomData;
      });
      
      await _loadParticipants();
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
          _affirmativeCompletedSelection = true;
          _affirmativeSelections = selections;
          AppLogger().debug('🎭 SYNC: Set affirmative completion = true, selections = $selections');
        } else if (role == 'negative' && completedSelection) {
          _negativeCompletedSelection = true;
          _negativeSelections = selections;
          AppLogger().debug('🎭 SYNC: Set negative completion = true, selections = $selections');
        }
        
        if (userProfileData != null) {
          final userProfile = UserProfile.fromMap(userProfileData);
          
          if (['affirmative', 'negative', 'moderator', 'judge1', 'judge2', 'judge3'].contains(role)) {
            _participants[role] = userProfile;
            AppLogger().info('Assigned ${userProfile.name} to $role');
          } else if (role == 'audience') {
            _audience.add(userProfile);
            AppLogger().info('Added ${userProfile.name} to audience (Total audience: ${_audience.length})');
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
      } else {
        AppLogger().warning('Current user not found in participants list');
      }
      
      // Check if both debaters are now present and trigger invitation modal
      await _checkForBothDebatersAndTriggerInvitations();
      
      setState(() {});
      AppLogger().info('Arena participants loaded successfully');
    } catch (e) {
      AppLogger().error('Error loading participants: $e');
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
        
        if (['affirmative', 'negative', 'moderator', 'judge1', 'judge2', 'judge3'].contains(role)) {
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
        SnackBar(
          content: Text('🔒 This arena room has been closed'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
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
    
    setState(() {
      _remainingSeconds = durationToUse;
      _isTimerRunning = true;
      _isPaused = false;
      _currentSpeaker = _currentPhase.speakerRole;
      _speakingEnabled = _currentSpeaker.isNotEmpty;
      _hasPlayed30SecWarning = false; // Reset warning flag for new phase
    });
    
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
    setState(() {
      _isPaused = true;
      _isTimerRunning = false;
    });
    _timerController.stop();
  }

  void _resumeTimer() {
    setState(() {
      _isPaused = false;
      _isTimerRunning = true;
    });
    _timerController.forward();
  }

  void _stopTimer() {
    setState(() {
      _isTimerRunning = false;
      _isPaused = false;
      _speakingEnabled = false;
    });
    _timerController.stop();
  }

  // Safe setState that respects exit state
  void _safeSetState(VoidCallback callback) {
    if (!_isExiting && mounted) {
      setState(callback);
    }
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
    } catch (e) {
      AppLogger().error('Error updating judging state: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error updating judging state: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No votes submitted yet'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Count votes
      int affirmativeVotes = 0;
      int negativeVotes = 0;
      
      for (var judgment in judgments.documents) {
        final winner = judgment.data['winner'];
        if (winner == 'affirmative') {
          affirmativeVotes++;
        } else if (winner == 'negative') {
          negativeVotes++;
        }
      }
      
      // Determine winner
      String winner;
      if (affirmativeVotes > negativeVotes) {
        winner = 'affirmative';
      } else if (negativeVotes > affirmativeVotes) {
        winner = 'negative';
      } else {
        winner = 'tie';
      }
      
      AppLogger().debug('🏆 Winner determined: $winner (Affirmative: $affirmativeVotes, Negative: $negativeVotes)');
      
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error calculating results: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _closeRoom() async {
    if (!_isModerator) return;
    
    try {
      // Check if widget is still mounted before showing dialog
      if (!mounted) {
        AppLogger().warning('Widget unmounted - cannot show close room dialog');
        return;
      }
      
      // Show confirmation dialog
      final shouldClose = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Close Arena Room'),
            ],
          ),
          content: const Text(
            'Are you sure you want to close this arena room? This will:\n\n'
            '• End the debate immediately\n'
            '• Remove all participants from the room\n'
            '• Mark the room as completed\n\n'
            'All users will be given 15 seconds to see the closure notice.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Close Room'),
            ),
          ],
        ),
      );
      
      if (shouldClose == true) {
        // Trigger the countdown by updating room status to "closing"
        await _appwrite.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'arena_rooms',
          documentId: widget.roomId,
          data: {
            'status': 'closing',
          },
        );
        
        AppLogger().info('Arena room closure initiated by moderator - Status set to "closing"');
        
        // Stop the periodic checker since we're handling closure manually
        _isExiting = true;
        AppLogger().debug('🛑 MANUAL CLOSE: Set _isExiting=true');
        if (_roomStatusChecker != null) {
          _roomStatusChecker!.cancel();
          _roomStatusChecker = null;
          AppLogger().debug('🛑 MANUAL CLOSE: Timer cancelled and nulled');
        }
        _roomClosingModalShown = true;
        
        // Show countdown modal immediately to this user
        _showRoomClosingModal(15);
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔒 Room closure initiated - 15 second countdown started'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        
        // After 15 seconds, mark room as completed - with proper mounted checks
        _roomCompletionTimer = Timer(const Duration(seconds: 15), () async {
          try {
            AppLogger().debug('⏰ 15 seconds elapsed - checking if widget is still mounted');
            
            // Check if widget is still mounted before proceeding
            if (!mounted) {
              AppLogger().warning('Widget unmounted - skipping room completion update');
              return;
            }
            
            AppLogger().debug('⏰ Widget still mounted - marking room as completed');
            await _appwrite.databases.updateDocument(
              databaseId: 'arena_db',
              collectionId: 'arena_rooms',
              documentId: widget.roomId,
              data: {
                'status': 'completed',
              },
            );
            AppLogger().info('Arena room marked as completed after countdown');
            
            // Additional navigation fallback specifically for moderator
            if (mounted && !_hasNavigated) {
              AppLogger().info('Moderator navigation fallback triggered');
              _hasNavigated = true; // Set flag to prevent duplicates
              
              // Use synchronous navigation immediately
              _forceNavigationHomeSync();
            }
          } catch (e) {
            AppLogger().error('Error marking room as completed: $e');
            // Don't try to show UI messages if widget is unmounted
            if (mounted) {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error completing room: $e')),
                );
              } catch (contextError) {
                AppLogger().error('Could not show error message - context unavailable: $contextError');
              }
            }
          }
        });
      }
    } catch (e) {
      AppLogger().error('Error initiating room closure: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error initiating room closure: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  void _showModeratorControlModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ModeratorControlModal(
        currentPhase: _currentPhase,
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
        onCloseRoom: _closeRoom,
        onSpeakerChange: _forceSpeakerChange,
        onToggleSpeaking: _toggleSpeakingEnabled,
        onToggleJudging: _toggleJudging,
        currentSpeaker: _currentSpeaker,
        speakingEnabled: _speakingEnabled,
        judgingEnabled: _judgingEnabled,
        affirmativeParticipant: _participants['affirmative'],
        negativeParticipant: _participants['negative'],
        debateCategory: widget.category,
      ),
    );
  }

  void _showTimerControlModal() {
    showDialog(
      context: context,
      builder: (context) => TimerControlModal(
        currentPhase: _currentPhase,
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
        onAdvancePhase: _advanceToNextPhase,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      toolbarHeight: 56,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => _exitArena(),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Moderator Controls Icon (only visible to moderators)
          if (_isModerator)
            IconButton(
              onPressed: _showModeratorControlModal,
              icon: const Icon(Icons.admin_panel_settings, color: Colors.amber),
              tooltip: 'Moderator Controls',
            )
          else
            const SizedBox(width: 48), // Maintain spacing
          
          // Timer in center (clickable for moderators)
          GestureDetector(
            onTap: _isModerator ? _showTimerControlModal : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isTimerRunning ? scarletRed : accentPurple,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formattedTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (_isModerator) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.settings, color: Colors.white, size: 14),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 48), // Maintain spacing for balance
        ],
      ),
      actions: [
        // Leave button
        IconButton(
          onPressed: () => _exitArena(),
          icon: const Icon(Icons.exit_to_app, color: Colors.white),
          tooltip: 'Leave Arena',
        ),
      ],
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
                      color: deepPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: deepPurple.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.topic,
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
                            Expanded(child: _buildDebaterPosition('affirmative', 'Affirmative')),
                            const SizedBox(width: 8),
                            Expanded(child: _buildDebaterPosition('negative', 'Negative')),
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
                            Expanded(flex: 2, child: _buildJudgePosition('moderator', 'Moderator', isPurple: true)),
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
                            Expanded(child: _buildJudgePosition('judge1', 'Judge 1')),
                            const SizedBox(width: 4),
                            Expanded(child: _buildJudgePosition('judge2', 'Judge 2')),
                            const SizedBox(width: 4),
                            Expanded(child: _buildJudgePosition('judge3', 'Judge 3')),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Audience Display (no height constraints - can expand as needed)
                      _buildCompactAudienceDisplay(),
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

  Widget _buildCompactAudienceDisplay() {
    if (_audience.isEmpty) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              color: Colors.white54,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'No audience yet',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(
                Icons.people,
                color: accentPurple,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Audience (${_audience.length})',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Grid of audience members - fixed height with scrolling
        SizedBox(
          height: 140, // Fixed height like Debates & Discussions
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            physics: const BouncingScrollPhysics(), // Enable scrolling
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // 4 users across
              crossAxisSpacing: 6, // Reduced spacing
              mainAxisSpacing: 6, // Reduced spacing  
              childAspectRatio: 0.85, // Adjusted for compact layout
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
                    radius: 28, // Slightly smaller to fit better with reduced spacing
                  ),
                  const SizedBox(height: 3),
                  Text(
                    audience.name.length > 7 
                        ? '${audience.name.substring(0, 7)}...'
                        : audience.name,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 8,
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
      ],
    );
  }

  Widget _buildDebaterPosition(String role, String title) {
    final participant = _participants[role];
    final isAffirmative = role == 'affirmative';
    final isWinner = _judgingComplete && _winner == role;
    
    return Container(
      decoration: BoxDecoration(
        color: isAffirmative ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        border: Border.all(
          color: isWinner 
              ? Colors.amber 
              : (isAffirmative ? Colors.green : Colors.red),
          width: isWinner ? 4 : 2,
        ),
        borderRadius: BorderRadius.circular(12),
        // Add golden glow effect for winner
        boxShadow: isWinner ? [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.5),
            blurRadius: 12,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ] : null,
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isWinner 
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
                if (isWinner) ...[
                  const Icon(Icons.emoji_events, color: Colors.black, size: 16),
                  const SizedBox(width: 4),
                ],
                Text(
                  isWinner ? 'WINNER' : title,
                  style: TextStyle(
                    color: isWinner ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isWinner) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.emoji_events, color: Colors.black, size: 16),
                ],
              ],
            ),
          ),
          Expanded(
            child: participant != null
                ? _buildParticipantTile(participant, isMain: true, isWinner: isWinner)
                : _buildEmptyPosition('Waiting for $title...'),
          ),
        ],
      ),
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
                ? _buildParticipantTile(judge, isSmall: true)
                : _buildEmptyPosition('Waiting...', isSmall: true),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleAudienceDisplay() {
    if (_audience.isEmpty) {
      return Container(
        height: 50,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              color: Colors.white54,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'No audience yet',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // Calculate grid height for simple display (max 2 rows)
    final rowCount = (_audience.length / 4).ceil();
    final gridHeight = (rowCount * 70.0).clamp(70.0, 140.0); // Max 2 rows for simple view with bigger avatars

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.people,
                color: accentPurple,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Audience (${_audience.length})',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Grid of audience members
          Container(
            height: gridHeight,
            child: GridView.builder(
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, // 4 users across
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1, // Square aspect ratio
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
                      radius: 24, // Bigger avatars consistent with main display
                    ),
                    const SizedBox(height: 2),
                    Text(
                      audience.name.length > 6 
                          ? '${audience.name.substring(0, 6)}...'
                          : audience.name,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 8,
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
        ],
      ),
    );
  }

  Widget _buildParticipantTile(UserProfile participant, {bool isMain = false, bool isSmall = false, bool isWinner = false}) {
    final avatarSize = isMain ? 32.0 : isSmall ? 16.0 : 24.0; // Reduced sizes
    final nameSize = isMain ? 12.0 : isSmall ? 9.0 : 10.0; // Reduced sizes
    
    return Padding(
      padding: const EdgeInsets.all(4), // Reduced from 8
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Crown for winner
          if (isWinner && isMain) ...[
            const Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 18, // Reduced from 24
            ),
            const SizedBox(height: 1), // Reduced from 2
          ],
          
          // Avatar with special border for winner
          Container(
            decoration: isWinner ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.amber,
                width: 2, // Reduced from 3
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 6, // Reduced from 8
                  spreadRadius: 1, // Reduced from 2
                ),
              ],
            ) : null,
            child: UserAvatar(
              avatarUrl: participant.avatar,
              initials: participant.name.isNotEmpty ? participant.name[0] : '?',
              radius: avatarSize,
            ),
          ),
          const SizedBox(height: 2), // Reduced from 4
          Text(
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
        ],
      ),
    );
  }

  Widget _buildEmptyPosition(String text, {bool isSmall = false}) {
    return Padding(
      padding: const EdgeInsets.all(4), // Reduced from default
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
                        : (_judgingEnabled ? _showComingSoonDialog : null),
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
    setState(() {
      _remainingSeconds = _currentPhase.defaultDurationSeconds ?? 0;
      _isTimerRunning = false;
      _isPaused = false;
      _speakingEnabled = false;
      _hasPlayed30SecWarning = false; // Reset warning flag
    });
  }

  Widget _buildTimerDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            deepPurple.withValues(alpha: 0.9),
            accentPurple.withValues(alpha: 0.9),
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
          // Debate Phase Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _currentPhase.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Current Speaker Indicator
          if (_currentSpeaker.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _speakingEnabled ? Icons.mic : Icons.mic_off,
                  color: _speakingEnabled ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Speaker: ${_currentSpeaker.toUpperCase()}',
                  style: TextStyle(
                    color: _speakingEnabled ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          
          // Timer Display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isTimerRunning ? Icons.timer : (_isPaused ? Icons.pause_circle : Icons.timer_off),
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                _formattedTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          
          // Phase Description
          if (_currentPhase.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _currentPhase.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.construction, color: Colors.orange),
            SizedBox(width: 8),
            Text('Coming Soon!'),
          ],
        ),
        content: const Text(
          'This feature is being enhanced and will be available in a future update.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
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
    // Additional validation
    if (!_judgingEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Voting is not open yet. The moderator must enable judging first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_hasCurrentUserSubmittedVote) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ You have already submitted your vote for this debate.'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }
    
    if (!(_isJudge || _isModerator)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Only judges can vote on debates.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => JudgingPanel(
        roomId: widget.roomId,
        challengeId: widget.challengeId,
        affirmativeDebater: _participants['affirmative'],
        negativeDebater: _participants['negative'],
        judgingEnabled: _judgingEnabled,
      ),
    );
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.gavel, color: accentPurple),
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
        hasAffirmativeDebater: _hasRoleAssigned('affirmative'),
        hasNegativeDebater: _hasRoleAssigned('negative'),
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
                               role == 'negative' ? 'Negative Debater' :
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
  
  /// Assign selected audience member as judge
  Future<void> _assignJudgeFromAudience(UserProfile selectedUser) async {
    try {
      // Find next available judge slot
      String? availableSlot;
      if (_participants['judge1'] == null) {
        availableSlot = 'judge1';
      } else if (_participants['judge2'] == null) {
        availableSlot = 'judge2';
      } else if (_participants['judge3'] == null) {
        availableSlot = 'judge3';
      }
      
      if (availableSlot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All judge slots are filled'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      Navigator.pop(context); // Close modal
      
      AppLogger().debug('🎭 ASSIGN: Assigning ${selectedUser.name} as $availableSlot');
      
      // Update user's role in the database
      await _appwrite.assignArenaRole(
        roomId: widget.roomId,
        userId: selectedUser.id,
        role: availableSlot,
      );
      
      // Refresh participants to update UI
      await _loadParticipants();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${selectedUser.name} is now $availableSlot!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      AppLogger().error('Error assigning judge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning judge: $e')),
        );
      }
    }
  }

  /// Show chat bottom sheet
  void _showChatBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) => ArenaChatBottomSheet(
        roomId: widget.roomId,
        chatService: _chatService,
        currentUserId: _currentUserId,
        participants: _participants,
        audienceCount: _audience.length,
        onSendMessage: _sendChatMessage,
      ),
    );
  }

  /// Build a chat message widget
  Widget _buildChatMessage(String username, String message, bool isSystem, Color roleColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: roleColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                username[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        color: roleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'now',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Send a chat message
  Future<void> _sendChatMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    try {
      final success = await _chatService.sendMessage(
        roomId: widget.roomId,
        content: message,
      );

      if (success) {
        _chatController.clear();
        AppLogger().debug('💬 Chat message sent successfully');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send message. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger().error('Error sending chat message: $e');
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

  /// Build a real chat message widget from Message object
  Widget _buildRealChatMessage(Message message) {
    final roleColor = _getRoleColorForUser(message.senderId);
    final timeString = _formatMessageTime(message.timestamp);
    final isCurrentUser = message.senderId == _currentUserId;

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
            UserAvatar(
              avatarUrl: message.senderAvatar,
              initials: message.senderName.isNotEmpty ? message.senderName[0] : '?',
              radius: 16,
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

  /// Get role color for a user
  Color _getRoleColorForUser(String userId) {
    if (userId == 'system') return Colors.blue;
    
    // Check if user has a specific role
    for (final entry in _participants.entries) {
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

  /// Format message timestamp
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.people, color: accentPurple),
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
                  if (_participants['negative'] != null)
                    _buildParticipantInfo('Negative', _participants['negative']!, Colors.red),
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
            negativeDebater: _participants['negative'],
            judgments: judgments.documents,
            topic: widget.topic,
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
      final heartbeatThreshold = 8000;
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
            AppLogger().debug('🔍 Status check #${_roomStatusCheckerIterations}: $roomStatus (every ${interval}ms)');
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
          else if ((roomStatus == 'completed' || roomStatus == 'abandoned' || roomStatus == 'force_cleaned' || roomStatus == 'force_closed') && !_hasNavigated) {
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
  
  void _forceNavigationHome() {
    // Keep old method for backward compatibility but make it call the sync version
    _forceNavigationHomeSync();
  }

  void _forceNavigation() {
    if (!_hasNavigated && mounted) {
      _hasNavigated = true;
      AppLogger().info('Forcing navigation back to arena lobby from closing modal');
      
      // Cancel all background processes immediately
      _isExiting = true;
      AppLogger().debug('🛑 MAIN FORCE: Set _isExiting=true');
      if (_roomStatusChecker != null) {
        _roomStatusChecker!.cancel();
        _roomStatusChecker = null;
        AppLogger().debug('🛑 MAIN FORCE: Timer cancelled and nulled');
      }
      _realtimeSubscription?.cancel();
      _realtimeSubscription = null;
      
      try {
        // Navigate directly without popping modal first - use pushAndRemoveUntil to clear stack
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

  /// Show the debater invitation choice modal
  void _showDebaterInviteChoiceModal() async {
    AppLogger().debug('🎭 DEBUG: _showDebaterInviteChoiceModal called');
    AppLogger().debug('🎭 DEBUG: _invitationModalShown = $_invitationModalShown');
    AppLogger().debug('🎭 DEBUG: _invitationsInProgress = $_invitationsInProgress');
    
    if (_invitationModalShown || _invitationsInProgress) {
      AppLogger().debug('🎭 Invitation modal already shown or in progress, skipping');
      return;
    }
    
    try {
      _invitationModalShown = true;
      AppLogger().debug('🎭 ${_isIOSOptimizationEnabled ? "iOS" : "Android"} Loading user network for role selection...');
      AppLogger().debug('🎭 Current platform: ${_isIOSOptimizationEnabled ? "iOS" : "Standard"}, User Role: $_userRole');
      
      // Load current user's network for arena roles (including current arena audience)
      final networkUsers = await _appwrite.getUserNetworkForArenaRoles(_currentUserId!, arenaRoomId: widget.roomId);
      AppLogger().debug('🎭 Found ${networkUsers.length} network users available for roles (including arena audience)');
      
      if (!mounted) return;
      
      // Show modal
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => DebaterInviteChoiceModal(
          currentUserId: _currentUserId!,
          debaterRole: _userRole!,
          networkUsers: networkUsers,
          challengerId: widget.challengerId,
          challengedId: widget.challengedId,
          onInviteSelectionComplete: (selections) async {
            Navigator.pop(context);
            AppLogger().debug('🎭 User completed selection: $selections');
            AppLogger().debug('🎭 DEBUG: Current user role: $_userRole');
            AppLogger().debug('🎭 DEBUG: Current user ID: $_currentUserId');
            
            // Store selections based on current user's role
            if (_userRole == 'affirmative') {
              _affirmativeSelections = selections;
              AppLogger().debug('🎭 DEBUG: Set affirmative selections to: $_affirmativeSelections');
            } else if (_userRole == 'negative') {
              _negativeSelections = selections;
              AppLogger().debug('🎭 DEBUG: Set negative selections to: $_negativeSelections');
            }
            
            AppLogger().debug('🎭 DEBUG: About to call _handleInviteSelectionComplete');
            // Check if we have selections from both debaters or should proceed
            await _handleInviteSelectionComplete();
          },
          onSkip: () async {
            Navigator.pop(context);
            AppLogger().debug('🎭 User skipped personal invites, proceeding with random');
            
            // Proceed with random invitations only
            await _performMixedInvitations({}, {});
          },
        ),
      );
    } catch (e) {
      AppLogger().error('Error showing debater invite choice modal: $e');
      _invitationModalShown = false;
    }
  }

  /// Handle when a debater completes their invite selection
  Future<void> _handleInviteSelectionComplete() async {
    try {
      AppLogger().debug('🎭 Handling invite selection completion...');
      AppLogger().debug('🎭 Current user role: $_userRole');
      AppLogger().debug('🎭 Affirmative selections: $_affirmativeSelections');
      AppLogger().debug('🎭 Negative selections: $_negativeSelections');
      AppLogger().debug('🎭 DEBUG: Before updates - _affirmativeCompletedSelection: $_affirmativeCompletedSelection');
      AppLogger().debug('🎭 DEBUG: Before updates - _negativeCompletedSelection: $_negativeCompletedSelection');
      
      // Mark current debater as completed and update database
      if (_userRole == 'affirmative') {
        _affirmativeCompletedSelection = true;
        AppLogger().debug('🎭 ✅ Affirmative debater completed selection');
        AppLogger().debug('🎭 DEBUG: Set _affirmativeCompletedSelection = true');
        
        // Update completion status in database for real-time sync
        try {
          await _appwrite.updateArenaParticipantStatus(
            roomId: widget.roomId,
            userId: _currentUserId!,
            completedSelection: true,
            metadata: {
              'role': 'affirmative',
              'selections': _affirmativeSelections,
            },
          );
          AppLogger().debug('🎭 DEBUG: Successfully updated affirmative participant status in database');
        } catch (e) {
          AppLogger().error('Error updating affirmative participant status: $e');
        }
      } else if (_userRole == 'negative') {
        _negativeCompletedSelection = true;
        AppLogger().debug('🎭 ✅ Negative debater completed selection');
        AppLogger().debug('🎭 DEBUG: Set _negativeCompletedSelection = true');
        
        // Update completion status in database for real-time sync
        try {
          await _appwrite.updateArenaParticipantStatus(
            roomId: widget.roomId,
            userId: _currentUserId!,
            completedSelection: true,
            metadata: {
              'role': 'negative',
              'selections': _negativeSelections,
            },
          );
          AppLogger().debug('🎭 DEBUG: Successfully updated negative participant status in database');
        } catch (e) {
          AppLogger().error('Error updating negative participant status: $e');
        }
      }
      
      AppLogger().debug('🎭 DEBUG: After updates - _affirmativeCompletedSelection: $_affirmativeCompletedSelection');
      AppLogger().debug('🎭 DEBUG: After updates - _negativeCompletedSelection: $_negativeCompletedSelection');
      
      // New flow: Wait for both debaters to agree on a single moderator
      if (_affirmativeCompletedSelection && _negativeCompletedSelection) {
        AppLogger().debug('🎭 ✅ Both debaters completed selection - checking for moderator agreement');
        
        final affirmativeModerator = _affirmativeSelections['moderator'];
        final negativeModerator = _negativeSelections['moderator'];
        
        AppLogger().debug('🎭 DEBUG: Affirmative moderator: $affirmativeModerator');
        AppLogger().debug('🎭 DEBUG: Negative moderator: $negativeModerator');
        AppLogger().debug('🎭 DEBUG: Are they both non-null? ${affirmativeModerator != null && negativeModerator != null}');
        AppLogger().debug('🎭 DEBUG: Are they equal? ${affirmativeModerator == negativeModerator}');
        AppLogger().debug('🎭 DEBUG: _invitationsInProgress: $_invitationsInProgress');
        
        if (affirmativeModerator != null && negativeModerator != null) {
          if (affirmativeModerator == negativeModerator) {
            // Both debaters agreed on the same moderator
            AppLogger().debug('🎭 ✅ Debaters agreed on moderator: $affirmativeModerator');
            if (!_invitationsInProgress) {
              AppLogger().debug('🎭 DEBUG: About to call _sendSingleModeratorInvitation with ID: $affirmativeModerator');
              await _sendSingleModeratorInvitation(affirmativeModerator);
            } else {
              AppLogger().debug('🎭 DEBUG: Skipping invitation - already in progress');
            }
          } else {
            // Debaters chose different moderators - need conflict resolution
            AppLogger().debug('🎭 ⚠️ Debaters chose different moderators: $affirmativeModerator vs $negativeModerator');
            AppLogger().debug('🎭 DEBUG: About to show conflict resolution modal');
            _showModeratorConflictResolution(affirmativeModerator, negativeModerator);
          }
        } else {
          // One or both debaters skipped moderator selection
          AppLogger().debug('🎭 ⚠️ One debater skipped moderator selection, proceeding with random');
          AppLogger().debug('🎭 DEBUG: affirmativeModerator is null: ${affirmativeModerator == null}');
          AppLogger().debug('🎭 DEBUG: negativeModerator is null: ${negativeModerator == null}');
          if (!_invitationsInProgress) {
            final agreedModerator = affirmativeModerator ?? negativeModerator;
            AppLogger().debug('🎭 DEBUG: Agreed moderator (fallback): $agreedModerator');
            if (agreedModerator != null) {
              AppLogger().debug('🎭 DEBUG: Sending invitation to agreed moderator: $agreedModerator');
              await _sendSingleModeratorInvitation(agreedModerator);
            } else {
              // Both skipped, send random moderator invite
              AppLogger().debug('🎭 DEBUG: Both skipped, sending random moderator invitation');
              await _sendRandomModeratorInvitation();
            }
          }
        }
      } else {
        AppLogger().debug('🎭 ⏭️ Waiting for other debater to complete selection...');
        AppLogger().debug('🎭 DEBUG: Completion status - affirmative: $_affirmativeCompletedSelection, negative: $_negativeCompletedSelection');
        final completedRole = _userRole == 'affirmative' ? 'Affirmative' : 'Negative';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $completedRole selection complete. Waiting for other debater...'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      
    } catch (e) {
      AppLogger().error('Error handling invite selection: $e');
    }
  }

  /// Send invitation to single agreed-upon moderator
  Future<void> _sendSingleModeratorInvitation(String moderatorId) async {
    try {
      _invitationsInProgress = true;
      AppLogger().debug('🎭 📤 Sending single moderator invitation to: $moderatorId');
      
      // Send invitation to the agreed moderator only
      await _messagingService.sendArenaRoleInvitation(
        userId: moderatorId,
        userName: 'Selected Moderator', // Name will be fetched by the service
        arenaRoomId: widget.roomId,
        role: 'moderator',
        topic: widget.topic,
        description: widget.description,
        category: widget.category,
      );
      
      AppLogger().debug('🎭 ✅ Single moderator invitation sent successfully');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Moderator invitation sent! Waiting for acceptance...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger().error('Error sending single moderator invitation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending invitation: $e')),
        );
      }
    } finally {
      _invitationsInProgress = false;
    }
  }

  /// Send invitation to random moderator when no agreement
  Future<void> _sendRandomModeratorInvitation() async {
    try {
      _invitationsInProgress = true;
      AppLogger().debug('🎭 🎲 Sending random moderator invitation');
      
      // Use the existing mixed invitation system but only for moderator
      await _messagingService.sendMixedArenaInvitations(
        arenaRoomId: widget.roomId,
        topic: widget.topic,
        challengerId: widget.challengerId ?? '',
        challengedId: widget.challengedId ?? '',
        affirmativeSelections: {'moderator': null}, // No specific selection
        negativeSelections: {'moderator': null}, // No specific selection
        description: widget.description,
        category: widget.category,
      );
      
      AppLogger().debug('🎭 ✅ Random moderator invitation sent successfully');
    } catch (e) {
      AppLogger().error('Error sending random moderator invitation: $e');
    } finally {
      _invitationsInProgress = false;
    }
  }

  /// Show conflict resolution when debaters choose different moderators
  void _showModeratorConflictResolution(String affirmativeModerator, String negativeModerator) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Moderator Selection Conflict'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Both debaters chose different moderators:'),
            const SizedBox(height: 12),
            Text('Affirmative chose: ${_getModeratorName(affirmativeModerator)}'),
            Text('Negative chose: ${_getModeratorName(negativeModerator)}'),
            const SizedBox(height: 12),
            const Text('Choose how to resolve this conflict:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sendSingleModeratorInvitation(affirmativeModerator);
            },
            child: Text('Use Affirmative Choice'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sendSingleModeratorInvitation(negativeModerator);
            },
            child: Text('Use Negative Choice'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sendRandomModeratorInvitation();
            },
            child: Text('Select Random Moderator'),
          ),
        ],
      ),
    );
  }

  /// Get moderator name for display
  String _getModeratorName(String moderatorId) {
    // Try to find the moderator in network users or return ID
    // This is a simplified version - in production you'd fetch the actual name
    return 'Moderator ($moderatorId)';
  }

  /// Show approval modal to the other debater to review and approve selections
  void _showApprovalModalToOtherDebater() async {
    if (_waitingForOtherDebater) {
      AppLogger().debug('🎭 Already waiting for other debater approval');
      return;
    }
    
    try {
      _waitingForOtherDebater = true;
      
      // Determine which selections to show for approval
      final otherDebaterRole = _userRole == 'affirmative' ? 'negative' : 'affirmative';
      final selectionsToReview = _userRole == 'affirmative' ? _affirmativeSelections : _negativeSelections;
      
      AppLogger().debug('🎭 📄 Showing approval modal to $otherDebaterRole debater');
      AppLogger().debug('🎭 Selections to review: $selectionsToReview');
      
      if (!mounted) return;
      
      // Determine if current user should see approval modal
      // Current user should see approval modal if the OTHER debater completed first
      final shouldShowApproval = (_userRole == 'affirmative' && _negativeCompletedSelection && !_affirmativeCompletedSelection) ||
                                (_userRole == 'negative' && _affirmativeCompletedSelection && !_negativeCompletedSelection);
      
      if (shouldShowApproval) {
        AppLogger().debug('🎭 Current user should see approval modal for other debater selections');
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildApprovalModal(selectionsToReview, otherDebaterRole),
        );
      } else {
        AppLogger().debug('🎭 Current user completed first, waiting for other debater');
        
        // Show waiting indicator for the debater who completed first
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⏳ Waiting for ${otherDebaterRole} debater to review and approve your selections...'),
              backgroundColor: const Color(0xFF6B46C1),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
      
    } catch (e) {
      AppLogger().error('Error showing approval modal: $e');
      _waitingForOtherDebater = false;
    }
  }

  /// Build approval modal for reviewing other debater's selections
  Widget _buildApprovalModal(Map<String, String?> selectionsToReview, String otherDebaterRole) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxModalHeight = screenHeight * 0.85; // 85% of screen height
    
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: maxModalHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.approval,
                      color: const Color(0xFF6B46C1),
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Review Official Selections',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B46C1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${otherDebaterRole.toUpperCase()} debater has made their selections. Please review and approve:',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Show selections
                Flexible(
                  child: _buildSelectionReview(selectionsToReview),
                ),
                
                const SizedBox(height: 16),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleApprovalResponse(false);
                        },
                        child: const Text(
                          'Request Changes',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleApprovalResponse(true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Approve & Send Invites'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// Build review of selections
  Widget _buildSelectionReview(Map<String, String?> selections) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        children: [
        for (final entry in selections.entries)
          if (entry.value != null)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  entry.key == 'moderator' ? Icons.account_balance : Icons.balance,
                  color: const Color(0xFF6B46C1),
                ),
                title: Text(
                  _getRoleDisplayName(entry.key),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: FutureBuilder<UserProfile?>(
                  future: _appwrite.getUserProfile(entry.value!),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return Text(snapshot.data!.name);
                    }
                    return const Text('Loading...');
                  },
                ),
                trailing: const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
              ),
            ),
        if (selections.values.every((v) => v == null))
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No personal selections made.\nRandom qualified users will be invited.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Handle approval response
  Future<void> _handleApprovalResponse(bool approved) async {
    try {
      AppLogger().debug('🎭 📋 Approval response: $approved');
      
      if (approved) {
        // Both debaters have agreed, proceed with invitations
        AppLogger().debug('🎭 ✅ Approval granted - proceeding with mixed invitations');
        await _performMixedInvitations(_affirmativeSelections, _negativeSelections);
      } else {
        // Request changes - reset the process
        AppLogger().debug('🎭 ❌ Changes requested - resetting selection process');
        _resetInvitationProcess();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔄 Selection process reset. Please make new selections.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        // Show modal again for new selections
        _showDebaterInviteChoiceModal();
      }
      
    } catch (e) {
      AppLogger().error('Error handling approval response: $e');
    } finally {
      _waitingForOtherDebater = false;
    }
  }
  
  /// Reset invitation process state
  void _resetInvitationProcess() {
    _affirmativeSelections.clear();
    _negativeSelections.clear();
    _affirmativeCompletedSelection = false;
    _negativeCompletedSelection = false;
    _invitationModalShown = false;
    _waitingForOtherDebater = false;
    AppLogger().debug('🎭 🔄 Invitation process state reset');
  }
  
  /// Get role display name
  String _getRoleDisplayName(String roleId) {
    switch (roleId) {
      case 'moderator':
        return 'Moderator';
      case 'judge1':
        return 'Judge 1';
      case 'judge2':
        return 'Judge 2';
      case 'judge3':
        return 'Judge 3';
      default:
        return 'Official';
    }
  }

  /// Perform the mixed invitation system (personal + random)
  Future<void> _performMixedInvitations(
    Map<String, String?> affirmativeSelections,
    Map<String, String?> negativeSelections,
  ) async {
    if (_invitationsInProgress) {
      AppLogger().debug('🎭 Invitations already in progress, skipping');
      return;
    }
    
    try {
      _invitationsInProgress = true;
      AppLogger().debug('🎭 🚀 Starting mixed invitation system...');
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('🎭 Sending arena role invitations...'),
              ],
            ),
            backgroundColor: Color(0xFF6B46C1),
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // Send mixed invitations using the messaging service
      await _messagingService.sendMixedArenaInvitations(
        arenaRoomId: widget.roomId,
        topic: widget.topic,
        challengerId: widget.challengerId ?? '',
        challengedId: widget.challengedId ?? '',
        affirmativeSelections: affirmativeSelections,
        negativeSelections: negativeSelections,
        description: widget.description,
        category: widget.category,
      );
      
      AppLogger().debug('🎭 ✅ Mixed invitation system completed successfully');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Arena role invitations sent successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      AppLogger().error('Error performing mixed invitations: $e');
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error sending invitations: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _invitationsInProgress = false;
    }
  }
}

// Judging Panel Widget
class JudgingPanel extends StatefulWidget {
  final String roomId;
  final String challengeId;
  final UserProfile? affirmativeDebater;
  final UserProfile? negativeDebater;
  final bool judgingEnabled;

  const JudgingPanel({
    super.key,
    required this.roomId,
    required this.challengeId,
    this.affirmativeDebater,
    this.negativeDebater,
    required this.judgingEnabled,
  });

  @override
  State<JudgingPanel> createState() => _JudgingPanelState();
}

class _JudgingPanelState extends State<JudgingPanel> {
  final _formKey = GlobalKey<FormState>();
  
  // Scoring (1-10 scale for each category)
  double _affirmativeArguments = 5.0;
  double _affirmativePresentation = 5.0;
  double _affirmativeRebuttal = 5.0;
  
  double _negativeArguments = 5.0;
  double _negativePresentation = 5.0;
  double _negativeRebuttal = 5.0;
  
  String _overallWinner = '';
  String _judgeComments = '';

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
          _buildJudgingHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDebaterScoring('Affirmative', widget.affirmativeDebater),
                    const SizedBox(height: 24),
                    _buildDebaterScoring('Negative', widget.negativeDebater),
                    const SizedBox(height: 24),
                    _buildOverallJudgment(),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJudgingHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6B46C1), Color(0xFF8B5CF6)],
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
          const Icon(Icons.gavel, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Judge This Debate',
              style: TextStyle(
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

  Widget _buildDebaterScoring(String side, UserProfile? debater) {
    final isAffirmative = side == 'Affirmative';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: isAffirmative ? Colors.green : Colors.red),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isAffirmative ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  side,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (debater != null) ...[
                const SizedBox(width: 12),
                Text(
                  debater.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          
          // Arguments & Content
          Text(
            'Arguments & Content (1-10)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Slider(
            value: isAffirmative ? _affirmativeArguments : _negativeArguments,
            min: 1,
            max: 10,
            divisions: 9,
            label: (isAffirmative ? _affirmativeArguments : _negativeArguments).round().toString(),
            onChanged: (value) {
              setState(() {
                if (isAffirmative) {
                  _affirmativeArguments = value;
                } else {
                  _negativeArguments = value;
                }
              });
            },
          ),
          
          // Presentation & Delivery
          Text(
            'Presentation & Delivery (1-10)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Slider(
            value: isAffirmative ? _affirmativePresentation : _negativePresentation,
            min: 1,
            max: 10,
            divisions: 9,
            label: (isAffirmative ? _affirmativePresentation : _negativePresentation).round().toString(),
            onChanged: (value) {
              setState(() {
                if (isAffirmative) {
                  _affirmativePresentation = value;
                } else {
                  _negativePresentation = value;
                }
              });
            },
          ),
          
          // Rebuttal & Defense
          Text(
            'Rebuttal & Defense (1-10)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Slider(
            value: isAffirmative ? _affirmativeRebuttal : _negativeRebuttal,
            min: 1,
            max: 10,
            divisions: 9,
            label: (isAffirmative ? _affirmativeRebuttal : _negativeRebuttal).round().toString(),
            onChanged: (value) {
              setState(() {
                if (isAffirmative) {
                  _affirmativeRebuttal = value;
                } else {
                  _negativeRebuttal = value;
                }
              });
            },
          ),
          
          // Total Score
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Score:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${((isAffirmative ? _affirmativeArguments + _affirmativePresentation + _affirmativeRebuttal : _negativeArguments + _negativePresentation + _negativeRebuttal)).toStringAsFixed(1)}/30',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallJudgment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overall Winner',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Affirmative'),
                value: 'affirmative',
                groupValue: _overallWinner,
                onChanged: (value) {
                  setState(() {
                    _overallWinner = value ?? '';
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Negative'),
                value: 'negative',
                groupValue: _overallWinner,
                onChanged: (value) {
                  setState(() {
                    _overallWinner = value ?? '';
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Judge Comments
        const Text(
          'Judge Comments (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Provide feedback on the debate performance...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: (value) {
            _judgeComments = value;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitJudgment,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5CF6),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'Submit Judgment',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _submitJudgment() async {
    if (!mounted) return;
    
    if (_overallWinner.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a winner')),
        );
      }
      return;
    }

    try {
      final appwrite = AppwriteService();
      final user = await appwrite.getCurrentUser();
      
      AppLogger().debug('🔍 JUDGMENT DEBUG: Starting submission...');
      AppLogger().debug('🔍 JUDGMENT DEBUG: Selected winner: $_overallWinner');
      
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      AppLogger().debug('🔍 JUDGMENT DEBUG: Current user ID: ${user.$id}');

      // Verify user is actually a judge in this arena
      AppLogger().debug('🔍 JUDGMENT DEBUG: Checking participants for room: ${widget.roomId}');
      
      final participants = await appwrite.getArenaParticipants(widget.roomId);
      
      AppLogger().debug('🔍 JUDGMENT DEBUG: Found ${participants.length} participants');
      for (var p in participants) {
        AppLogger().debug('Participant ${p['userId']} has role: ${p['role']}');
      }
      
      final currentUserParticipant = participants.firstWhere(
        (p) => p['userId'] == user.$id,
        orElse: () => <String, dynamic>{},
      );
      
      if (currentUserParticipant.isEmpty) {
        AppLogger().debug('🔍 JUDGMENT DEBUG: User not found in participants');
        throw Exception('You are not a participant in this arena');
      }
      
      final userRole = currentUserParticipant['role'] as String?;
      AppLogger().debug('🔍 JUDGMENT DEBUG: Current user role: $userRole');
      
      if (!(userRole?.startsWith('judge') ?? false)) {
        AppLogger().debug('🔍 JUDGMENT DEBUG: User role does not start with judge');
        throw Exception('Only judges can submit votes. Your role: $userRole');
      }

      // Check if judging is enabled by the moderator
      AppLogger().debug('🔍 JUDGMENT DEBUG: Judging enabled: ${widget.judgingEnabled}');
      if (!widget.judgingEnabled) {
        throw Exception('Voting is not yet open. The moderator must enable judging first.');
      }

      AppLogger().debug('🔍 JUDGMENT DEBUG: All validations passed, submitting judgment...');

      await appwrite.submitArenaJudgment(
        roomId: widget.roomId,
        judgeId: user.$id,
        challengeId: widget.challengeId,
        affirmativeArguments: _affirmativeArguments,
        affirmativePresentation: _affirmativePresentation,
        affirmativeRebuttal: _affirmativeRebuttal,
        negativeArguments: _negativeArguments,
        negativePresentation: _negativePresentation,
        negativeRebuttal: _negativeRebuttal,
        winner: _overallWinner,
        comments: _judgeComments.isNotEmpty ? _judgeComments : null,
      );
      
      AppLogger().debug('🔍 JUDGMENT DEBUG: Judgment submitted successfully!');
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Judgment submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger().debug('🔍 JUDGMENT DEBUG: Error submitting judgment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error submitting judgment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
  final List<String> _availableRoles = [
    'affirmative',
    'negative', 
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Role assigned successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      AppLogger().error('Error assigning role: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error assigning role: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      case 'negative':
        return 'Negative';
      case 'moderator':
        return 'Moderator';
      case 'audience':
        return 'Audience';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'affirmative':
        return Colors.green;
      case 'negative':
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

// Timer Control Modal Widget
class TimerControlModal extends StatefulWidget {
  final DebatePhase currentPhase;
  final int remainingSeconds;
  final bool isTimerRunning;
  final bool isPaused;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onReset;
  final Function(int) onExtendTime;
  final Function(int) onSetCustomTime;
  final VoidCallback onAdvancePhase;

  const TimerControlModal({
    super.key,
    required this.currentPhase,
    required this.remainingSeconds,
    required this.isTimerRunning,
    required this.isPaused,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onReset,
    required this.onExtendTime,
    required this.onSetCustomTime,
    required this.onAdvancePhase,
  });

  @override
  State<TimerControlModal> createState() => _TimerControlModalState();
}

class _TimerControlModalState extends State<TimerControlModal> {
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _secondsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final minutes = widget.remainingSeconds ~/ 60;
    final seconds = widget.remainingSeconds % 60;
    _minutesController.text = minutes.toString();
    _secondsController.text = seconds.toString();
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.timer, color: Colors.purple),
          const SizedBox(width: 8),
          Text('Timer Controls'),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          // Current Phase Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  widget.currentPhase.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.currentPhase.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Custom Time Input
          const Text(
            'Set Custom Time',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(':', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _secondsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Seconds',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Timer Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimerButton(
                icon: widget.isTimerRunning ? Icons.pause : (widget.isPaused ? Icons.play_arrow : Icons.play_arrow),
                label: widget.isTimerRunning ? 'Pause' : (widget.isPaused ? 'Resume' : 'Start'),
                onPressed: () {
                  if (widget.isTimerRunning) {
                    widget.onPause();
                  } else if (widget.isPaused) {
                    widget.onResume();
                  } else {
                    widget.onStart();
                  }
                  Navigator.pop(context);
                },
                color: widget.isTimerRunning ? Colors.orange : Colors.green,
              ),
              _buildTimerButton(
                icon: Icons.stop,
                label: 'Stop',
                onPressed: () {
                  widget.onStop();
                  Navigator.pop(context);
                },
                color: Colors.red,
              ),
              _buildTimerButton(
                icon: Icons.refresh,
                label: 'Reset',
                onPressed: () {
                  widget.onReset();
                  Navigator.pop(context);
                },
                color: Colors.blue,
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Quick Extend Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildExtendButton('+30s', 30),
              _buildExtendButton('+1m', 60),
              _buildExtendButton('+5m', 300),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Advance Phase Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.currentPhase.nextPhase != null ? () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Advance Phase'),
                    content: Text(
                      'Are you sure you want to advance to the next phase?\n\n'
                      'Current: ${widget.currentPhase.displayName}\n'
                      'Next: ${widget.currentPhase.nextPhase?.displayName ?? 'None'}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close confirmation
                          Navigator.pop(context); // Close timer modal
                          widget.onAdvancePhase();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                        child: const Text('Advance', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              } : null,
              icon: const Icon(Icons.skip_next, color: Colors.white),
              label: Text(
                widget.currentPhase.nextPhase != null 
                  ? 'Advance to ${widget.currentPhase.nextPhase!.displayName}'
                  : 'Final Phase',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _setCustomTime,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          child: const Text('Set Time', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildTimerButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildExtendButton(String label, int seconds) {
    return GestureDetector(
      onTap: () {
        widget.onExtendTime(seconds);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.indigo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _setCustomTime() {
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    final totalSeconds = (minutes * 60) + seconds;
    
    if (totalSeconds > 0) {
      widget.onSetCustomTime(totalSeconds);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid time')),
      );
    }
  }
} 

// Results Modal Widget
class ResultsModal extends StatelessWidget {
  final String winner;
  final UserProfile? affirmativeDebater;
  final UserProfile? negativeDebater;
  final List<dynamic> judgments;
  final String topic;

  const ResultsModal({
    super.key,
    required this.winner,
    this.affirmativeDebater,
    this.negativeDebater,
    required this.judgments,
    required this.topic,
  });

  // Colors
  static const Color scarletRed = Color(0xFFFF2400);
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

    final isAffirmativeWinner = winner == 'affirmative';
    final winnerDebater = isAffirmativeWinner ? affirmativeDebater : negativeDebater;

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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentPurple, deepPurple],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.only(
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
    final winnerDebater = isAffirmativeWinner ? affirmativeDebater : negativeDebater;

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
                if (winnerDebater != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 2), // Reduced from 3
                        ),
                        child: UserAvatar(
                          avatarUrl: winnerDebater.avatar,
                          initials: winnerDebater.name.isNotEmpty ? winnerDebater.name[0] : '?',
                          radius: 24, // Reduced from 32
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              winnerDebater.name,
                              style: const TextStyle(
                                fontSize: 16, // Reduced from 20
                                fontWeight: FontWeight.bold,
                                color: deepPurple,
                              ),
                            ),
                            Text(
                              '${winner.toUpperCase()} SIDE',
                              style: TextStyle(
                                fontSize: 12, // Reduced from 14
                                fontWeight: FontWeight.w600,
                                color: isAffirmativeWinner ? Colors.green : scarletRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                _buildVoteRow('Negative', negativeVotes, !isAffirmativeWinner, scarletRed),
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
                          Icon(
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
                              color: judgeWinner == 'affirmative' ? Colors.green : scarletRed,
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
  Set<String> _selectedJudges = {};
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
                        Icon(Icons.check_circle, color: Colors.amber, size: 16),
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
  final bool hasAffirmativeDebater;
  final bool hasNegativeDebater;
  final bool hasJudge1;
  final bool hasJudge2;
  final bool hasJudge3;

  const RoleSelectionModal({
    super.key,
    required this.audience,
    required this.onRoleAssigned,
    required this.availableJudgeSlots,
    required this.hasAffirmativeDebater,
    required this.hasNegativeDebater,
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
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
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
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, size: 16),
                      const SizedBox(width: 8),
                      const Text('Debaters'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.balance, size: 16),
                      const SizedBox(width: 8),
                      const Text('Judges'),
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

          // Role selection buttons
          Row(
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
                                      Icon(Icons.thumb_up, color: Colors.green, size: 16),
                                      const SizedBox(width: 8),
                                      const Text('Affirmative Debater'),
                                    ],
                                  ),
                                ),
                              if (!widget.hasNegativeDebater)
                                PopupMenuItem(
                                  value: 'negative',
                                  child: Row(
                                    children: [
                                      Icon(Icons.thumb_down, color: Colors.red, size: 16),
                                      const SizedBox(width: 8),
                                      const Text('Negative Debater'),
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
                leading: Icon(Icons.balance, color: Colors.amber),
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
  final ChatService chatService;
  final String? currentUserId;
  final Map<String, UserProfile?> participants;
  final int audienceCount;
  final VoidCallback onSendMessage;

  const ArenaChatBottomSheet({
    super.key,
    required this.roomId,
    required this.chatService,
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
    _messageSubscription = widget.chatService.messagesStream.listen((messages) {
      if (mounted) {
        setState(() {
          _messages = messages.reversed.toList(); // Reverse for chronological order
        });
        // Auto-scroll to bottom when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    // Load initial messages
    widget.chatService.getRoomMessages(widget.roomId).then((messages) {
      if (mounted) {
        setState(() {
          _messages = messages.reversed.toList();
        });
        // Auto-scroll to bottom after loading
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      final success = await widget.chatService.sendMessage(
        roomId: widget.roomId,
        content: message,
      );

      if (success) {
        _messageController.clear();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send message. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
                  Icon(Icons.chat_bubble, color: Colors.blue, size: 24),
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