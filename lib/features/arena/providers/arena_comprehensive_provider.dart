import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import 'dart:async';
import '../models/arena_state.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/error/app_error.dart';
import '../../../core/providers/app_providers.dart';
import '../../../services/appwrite_service.dart';
import '../../../services/sound_service.dart';
import '../../../models/user_profile.dart';

/// Arena initialization parameters
class ArenaInitParams {
  final String roomId;
  final String challengeId;
  final String topic;
  final String? description;
  final String? category;
  final String? challengerId;
  final String? challengedId;

  ArenaInitParams({
    required this.roomId,
    required this.challengeId,
    required this.topic,
    this.description,
    this.category,
    this.challengerId,
    this.challengedId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ArenaInitParams &&
        other.roomId == roomId &&
        other.challengeId == challengeId &&
        other.topic == topic &&
        other.description == description &&
        other.category == category &&
        other.challengerId == challengerId &&
        other.challengedId == challengedId;
  }

  @override
  int get hashCode {
    return Object.hash(
      roomId,
      challengeId,
      topic,
      description,
      category,
      challengerId,
      challengedId,
    );
  }
}

/// Comprehensive Arena provider that manages all arena state
final arenaComprehensiveProvider = StateNotifierProvider.family<ArenaComprehensiveNotifier, ArenaState, ArenaInitParams>(
  (ref, params) => ArenaComprehensiveNotifier(
    params: params,
    logger: ref.read(loggerProvider),
    appwrite: ref.read(appwriteServiceProvider),
    sound: ref.read(soundServiceProvider),
  ),
);

/// These providers are convenience providers that work with specific arena instances
/// They should be used with a specific ArenaInitParams instance, not create new ones

/// Timer provider that streams remaining seconds
final arenaTimerStreamProvider = StreamProvider.family<int, ArenaInitParams>((ref, params) {
  final arena = ref.watch(arenaComprehensiveProvider(params));
  
  if (!arena.isTimerRunning || arena.isPaused) {
    return Stream.value(arena.remainingSeconds);
  }
  
  return Stream.periodic(const Duration(seconds: 1), (count) {
    final remaining = arena.remainingSeconds - count - 1;
    return remaining > 0 ? remaining : 0;
  }).takeWhile((time) => time >= 0);
});

/// Network health provider
final arenaNetworkHealthProvider = Provider.family<bool, ArenaInitParams>((ref, params) {
  final arena = ref.watch(arenaComprehensiveProvider(params));
  return arena.isRealtimeHealthy;
});

/// Participants provider - returns structured participant data
final arenaParticipantsProvider = Provider.family<Map<String, ArenaParticipant?>, ArenaInitParams>((ref, params) {
  final arena = ref.watch(arenaComprehensiveProvider(params));
  
  return {
    'affirmative': arena.getParticipantByRole(ArenaRole.affirmative),
    'negative': arena.getParticipantByRole(ArenaRole.negative),
    'moderator': arena.getParticipantByRole(ArenaRole.moderator),
    'judge1': arena.getParticipantByRole(ArenaRole.judge1),
    'judge2': arena.getParticipantByRole(ArenaRole.judge2),
    'judge3': arena.getParticipantByRole(ArenaRole.judge3),
  };
});

/// Audience provider
final arenaAudienceProvider = Provider.family<List<ArenaParticipant>, ArenaInitParams>((ref, params) {
  final arena = ref.watch(arenaComprehensiveProvider(params));
  return arena.audience;
});

/// Judging state provider
final arenaJudgingProvider = Provider.family<({bool enabled, bool complete, bool userVoted, String? winner}), ArenaInitParams>((ref, params) {
  final arena = ref.watch(arenaComprehensiveProvider(params));
  
  return (
    enabled: arena.judgingEnabled,
    complete: arena.judgingComplete,
    userVoted: arena.hasCurrentUserSubmittedVote,
    winner: arena.winner,
  );
});

/// UI state provider for modals and selections
final arenaUIStateProvider = Provider.family<({
  bool bothDebatersPresent,
  bool invitationModalShown,
  bool invitationsInProgress,
  Map<String, String?> affirmativeSelections,
  Map<String, String?> negativeSelections,
  bool affirmativeCompleted,
  bool negativeCompleted,
  bool waitingForOther,
  bool resultsModalShown,
  bool roomClosingModalShown,
}), String>((ref, roomId) {
  final arenaParams = ArenaInitParams(roomId: roomId, challengeId: '', topic: '');
  final arena = ref.watch(arenaComprehensiveProvider(arenaParams));
  
  return (
    bothDebatersPresent: arena.bothDebatersPresent,
    invitationModalShown: arena.invitationModalShown,
    invitationsInProgress: arena.invitationsInProgress,
    affirmativeSelections: arena.affirmativeSelections,
    negativeSelections: arena.negativeSelections,
    affirmativeCompleted: arena.affirmativeCompletedSelection,
    negativeCompleted: arena.negativeCompletedSelection,
    waitingForOther: arena.waitingForOtherDebater,
    resultsModalShown: arena.resultsModalShown,
    roomClosingModalShown: arena.roomClosingModalShown,
  );
});

/// Comprehensive Arena Notifier - manages all arena state
class ArenaComprehensiveNotifier extends StateNotifier<ArenaState> {
  ArenaComprehensiveNotifier({
    required this.params,
    required this.logger,
    required this.appwrite,
    required this.sound,
  }) : super(ArenaState(
    roomId: params.roomId,
    topic: params.topic,
    description: params.description,
    category: params.category,
    challengeId: params.challengeId,
    challengerId: params.challengerId,
    challengedId: params.challengedId,
  )) {
    _init();
  }

  final ArenaInitParams params;
  final AppLogger logger;
  final AppwriteService appwrite;
  final SoundService sound;
  
  // Services (initialized but not used in current implementation)
  // final ChallengeMessagingService _messagingService = ChallengeMessagingService();
  
  // Subscriptions and timers
  StreamSubscription? _realtimeSubscription;
  Timer? _timerUpdater;
  Timer? _roomStatusChecker;
  Timer? _roomCompletionTimer;
  
  // Connection management
  static const int _maxReconnectAttempts = 5;

  Future<void> _init() async {
    try {
      state = state.copyWith(isLoading: true);
      logger.info('Initializing comprehensive arena for room: ${params.roomId}');
      
      // Get current user
      await _loadCurrentUser();
      
      // Load arena data
      await _loadArenaData();
      
      // Load participants
      await _loadParticipants();
      
      // Setup realtime subscription
      await _setupRealtimeSubscription();
      
      // Start room status monitoring
      _startRoomStatusMonitoring();
      
      state = state.copyWith(isLoading: false);
      logger.info('Arena initialized successfully: ${params.roomId}');
    } catch (e, stackTrace) {
      final error = ErrorHandler.handleError(e, stackTrace);
      logger.logError(error);
      state = state.copyWith(
        isLoading: false,
        error: ErrorHandler.getUserFriendlyMessage(error),
      );
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final currentUser = await appwrite.account.get();
      state = state.copyWith(currentUserId: currentUser.$id);
      logger.debug('Current user loaded: ${currentUser.$id}');
    } catch (e) {
      logger.error('Failed to load current user: $e');
      throw DataError(message: 'Failed to load current user: $e');
    }
  }

  Future<void> _loadArenaData() async {
    try {
      final roomData = await appwrite.getArenaRoom(params.roomId);
      state = state.copyWith(roomData: roomData);
      logger.debug('Arena room data loaded');
    } catch (e) {
      throw DataError(message: 'Failed to load arena data: $e');
    }
  }

  Future<void> _loadParticipants() async {
    try {
      final participantsData = await appwrite.getArenaParticipants(params.roomId);
      
      // Convert to participants map and audience list
      final participants = <String, ArenaParticipant>{};
      final audience = <ArenaParticipant>[];
      
      for (var participantData in participantsData) {
        final role = participantData['role'] as String?;
        final userProfileData = participantData['userProfile'];
        
        if (userProfileData != null) {
          final userProfile = UserProfile.fromMap(userProfileData);
          final participant = ArenaParticipant(
            userId: userProfile.id,
            name: userProfile.name,
            role: _parseRole(role),
            avatar: userProfile.avatar,
            isReady: participantData['isReady'] ?? false,
          );
          
          if (role == 'audience') {
            audience.add(participant);
          } else {
            participants[userProfile.id] = participant;
            
            // Set user role if this is current user
            if (userProfile.id == state.currentUserId) {
              state = state.copyWith(userRole: role);
            }
          }
        }
      }
      
      state = state.copyWith(
        participants: participants,
        audience: audience,
        bothDebatersPresent: _checkBothDebatersPresent(participants),
      );
      
      logger.info('Loaded ${participants.length} participants and ${audience.length} audience members');
    } catch (e) {
      throw DataError(message: 'Failed to load participants: $e');
    }
  }

  bool _checkBothDebatersPresent(Map<String, ArenaParticipant> participants) {
    final hasAffirmative = participants.values.any((p) => p.role == ArenaRole.affirmative);
    final hasNegative = participants.values.any((p) => p.role == ArenaRole.negative);
    return hasAffirmative && hasNegative;
  }

  ArenaRole _parseRole(String? roleString) {
    switch (roleString) {
      case 'affirmative':
        return ArenaRole.affirmative;
      case 'negative':
        return ArenaRole.negative;
      case 'moderator':
        return ArenaRole.moderator;
      case 'judge1':
        return ArenaRole.judge1;
      case 'judge2':
        return ArenaRole.judge2;
      case 'judge3':
        return ArenaRole.judge3;
      default:
        return ArenaRole.audience;
    }
  }

  Future<void> _setupRealtimeSubscription() async {
    try {
      _realtimeSubscription?.cancel();
      
      logger.info('Setting up real-time subscription for room: ${params.roomId}');
      
      final subscription = appwrite.realtimeInstance.subscribe([
        'databases.arena_db.collections.arena_participants.documents',
        'databases.arena_db.collections.arena_rooms.documents'
      ]);
      
      _realtimeSubscription = subscription.stream.listen(
        _handleRealtimeEvent,
        onError: _handleRealtimeError,
        onDone: _handleRealtimeDisconnection,
      );
      
      // Reset connection health
      state = state.copyWith(isRealtimeHealthy: true, reconnectAttempts: 0);
    } catch (e) {
      throw NetworkError(message: 'Failed to setup realtime subscription: $e');
    }
  }

  void _handleRealtimeEvent(RealtimeMessage message) {
    try {
      // Reset reconnect attempts on successful message
      if (state.reconnectAttempts > 0) {
        state = state.copyWith(reconnectAttempts: 0, isRealtimeHealthy: true);
        logger.info('Arena realtime connection restored');
      }
      
      logger.debug('Real-time arena update: ${message.events}');
      
      // Handle different event types
      final isParticipantEvent = message.events.any((e) => e.contains('arena_participants'));
      final isRoomEvent = message.events.any((e) => e.contains('arena_rooms'));
      
      if (isParticipantEvent) {
        _handleParticipantRealtimeUpdate(message.payload);
      }
      
      if (isRoomEvent) {
        _handleRoomRealtimeUpdate(message.payload);
      }
      
    } catch (e) {
      logger.error('Error handling realtime event: $e');
    }
  }

  void _handleRealtimeError(dynamic error) {
    logger.error('Arena real-time subscription error: $error');
    
    final newAttempts = state.reconnectAttempts + 1;
    state = state.copyWith(
      isRealtimeHealthy: false,
      reconnectAttempts: newAttempts,
    );
    
    // Implement exponential backoff
    if (newAttempts < _maxReconnectAttempts) {
      final delaySeconds = newAttempts * 2;
      logger.debug('Reconnecting in $delaySeconds seconds... (attempt $newAttempts/$_maxReconnectAttempts)');
      
      Timer(Duration(seconds: delaySeconds), () {
        if (mounted && !state.isExiting) {
          _setupRealtimeSubscription();
        }
      });
    } else {
      logger.error('Arena realtime max reconnection attempts reached');
    }
  }

  void _handleRealtimeDisconnection() {
    logger.warning('Arena real-time subscription closed');
    if (mounted && !state.isExiting && state.reconnectAttempts < _maxReconnectAttempts) {
      final newAttempts = state.reconnectAttempts + 1;
      state = state.copyWith(reconnectAttempts: newAttempts);
      
      logger.debug('Arena subscription ended, attempting to reconnect...');
      Timer(const Duration(seconds: 3), () {
        if (mounted && !state.isExiting) {
          _setupRealtimeSubscription();
        }
      });
    }
  }

  void _handleParticipantRealtimeUpdate(Map<String, dynamic> payload) {
    // Reload participants when there are changes
    _loadParticipants();
  }

  void _handleRoomRealtimeUpdate(Map<String, dynamic> payload) {
    // Handle room status changes, timer updates, etc.
    // This would be implemented based on the specific room update events
    logger.debug('Room update received: $payload');
  }

  void _startRoomStatusMonitoring() {
    _roomStatusChecker = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted || state.isExiting) {
        timer.cancel();
        return;
      }
      _checkRoomStatus();
    });
  }

  Future<void> _checkRoomStatus() async {
    try {
      final roomData = await appwrite.getArenaRoom(params.roomId);
      final roomStatus = roomData?['status'] as String?;
      
      if (roomStatus == 'closed' && !state.roomClosingModalShown) {
        state = state.copyWith(roomClosingModalShown: true);
        // Trigger room closing logic
      }
    } catch (e) {
      logger.warning('Room status check failed: $e');
    }
  }

  // Timer Management Methods
  void startPhaseTimer([int? customSeconds]) {
    final duration = customSeconds ?? state.currentPhase.defaultDurationSeconds ?? 0;
    
    state = state.copyWith(
      remainingSeconds: duration,
      isTimerRunning: true,
      isPaused: false,
      hasPlayed30SecWarning: false,
    );
    
    _startTimerUpdater();
    logger.info('Started timer for ${state.currentPhase.displayName}: ${duration}s');
  }

  void pauseTimer() {
    state = state.copyWith(
      isPaused: true,
      isTimerRunning: false,
    );
    _stopTimerUpdater();
    logger.debug('Timer paused');
  }

  void resumeTimer() {
    state = state.copyWith(
      isPaused: false,
      isTimerRunning: true,
    );
    _startTimerUpdater();
    logger.debug('Timer resumed');
  }

  void stopTimer() {
    state = state.copyWith(
      isTimerRunning: false,
      isPaused: false,
      speakingEnabled: false,
    );
    _stopTimerUpdater();
    logger.debug('Timer stopped');
  }

  void resetTimer() {
    stopTimer();
    state = state.copyWith(
      remainingSeconds: state.currentPhase.defaultDurationSeconds ?? 0,
      hasPlayed30SecWarning: false,
    );
    logger.debug('Timer reset');
  }

  void extendTime(int additionalSeconds) {
    state = state.copyWith(
      remainingSeconds: state.remainingSeconds + additionalSeconds,
    );
    logger.debug('Timer extended by ${additionalSeconds}s');
  }

  void setCustomTime(int seconds) {
    final wasRunning = state.isTimerRunning;
    if (wasRunning) stopTimer();
    
    state = state.copyWith(remainingSeconds: seconds);
    logger.debug('Custom time set: ${seconds}s');
  }

  void _startTimerUpdater() {
    _stopTimerUpdater();
    
    _timerUpdater = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || state.isExiting || !state.isTimerRunning || state.isPaused) {
        timer.cancel();
        return;
      }
      
      final newTime = state.remainingSeconds - 1;
      
      // Play 30-second warning
      if (newTime == 30 && !state.hasPlayed30SecWarning) {
        sound.play30SecWarningSound();
        state = state.copyWith(hasPlayed30SecWarning: true);
      }
      
      if (newTime <= 0) {
        // Time's up
        timer.cancel();
        state = state.copyWith(
          remainingSeconds: 0,
          isTimerRunning: false,
          isPaused: false,
          speakingEnabled: false,
        );
        sound.playArenaZeroSound();
        _handlePhaseTimeout();
      } else {
        state = state.copyWith(remainingSeconds: newTime);
      }
    });
  }

  void _stopTimerUpdater() {
    _timerUpdater?.cancel();
    _timerUpdater = null;
  }

  void _handlePhaseTimeout() {
    logger.info('Phase ${state.currentPhase.displayName} timed out');
    // Auto-advance logic would go here for moderators
  }

  // Phase Management
  void advanceToNextPhase() {
    final nextPhase = state.currentPhase.nextPhase;
    if (nextPhase != null) {
      stopTimer();
      
      state = state.copyWith(
        currentPhase: nextPhase,
        speakingEnabled: false,
        currentSpeaker: null,
      );
      
      // Special handling for judging phase
      if (nextPhase == DebatePhase.judging) {
        state = state.copyWith(judgingEnabled: true);
      }
      
      logger.info('Advanced to ${nextPhase.displayName}');
    }
  }

  void setPhase(DebatePhase phase) {
    stopTimer();
    state = state.copyWith(
      currentPhase: phase,
      speakingEnabled: false,
      currentSpeaker: null,
    );
    logger.info('Set phase to ${phase.displayName}');
  }

  // Speaking Management
  void toggleSpeakingEnabled() {
    state = state.copyWith(speakingEnabled: !state.speakingEnabled);
    logger.debug('Speaking enabled: ${state.speakingEnabled}');
  }

  void setSpeaker(String? speakerId) {
    state = state.copyWith(currentSpeaker: speakerId);
    logger.debug('Current speaker set to: $speakerId');
  }

  // Judging Management
  void toggleJudging() {
    state = state.copyWith(judgingEnabled: !state.judgingEnabled);
    logger.debug('Judging enabled: ${state.judgingEnabled}');
  }

  void setJudgingComplete(bool complete, {String? winner}) {
    state = state.copyWith(
      judgingComplete: complete,
      winner: winner,
    );
    
    if (complete) {
      sound.playApplauseSound();
      logger.info('Judging completed. Winner: $winner');
    }
  }

  void setUserVoted(bool voted) {
    state = state.copyWith(hasCurrentUserSubmittedVote: voted);
    logger.debug('User vote status: $voted');
  }

  // UI State Management
  void setModalShown(String modalType, bool shown) {
    switch (modalType) {
      case 'invitation':
        state = state.copyWith(invitationModalShown: shown);
        break;
      case 'results':
        state = state.copyWith(resultsModalShown: shown);
        break;
      case 'roomClosing':
        state = state.copyWith(roomClosingModalShown: shown);
        break;
    }
  }

  void setInvitationsInProgress(bool inProgress) {
    state = state.copyWith(invitationsInProgress: inProgress);
  }

  void updateDebaterSelections({
    Map<String, String?>? affirmativeSelections,
    Map<String, String?>? negativeSelections,
    bool? affirmativeCompleted,
    bool? negativeCompleted,
  }) {
    state = state.copyWith(
      affirmativeSelections: affirmativeSelections ?? state.affirmativeSelections,
      negativeSelections: negativeSelections ?? state.negativeSelections,
      affirmativeCompletedSelection: affirmativeCompleted ?? state.affirmativeCompletedSelection,
      negativeCompletedSelection: negativeCompleted ?? state.negativeCompletedSelection,
    );
  }

  void setWaitingForOtherDebater(bool waiting) {
    state = state.copyWith(waitingForOtherDebater: waiting);
  }

  // Room Management
  Future<void> closeRoom() async {
    try {
      state = state.copyWith(isExiting: true);
      await appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: params.roomId,
        data: {'status': 'closed'},
      );
      logger.info('Room closed: ${params.roomId}');
    } catch (e) {
      logger.error('Failed to close room: $e');
      throw DataError(message: 'Failed to close room: $e');
    }
  }

  Future<void> leaveRoom() async {
    try {
      state = state.copyWith(isExiting: true);
      
      if (state.currentUserId != null) {
        // Find and remove the participant record
        final participantsResponse = await appwrite.databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          queries: [
            Query.equal('roomId', params.roomId),
            Query.equal('userId', state.currentUserId!),
          ],
        );
        
        if (participantsResponse.documents.isNotEmpty) {
          await appwrite.databases.deleteDocument(
            databaseId: 'arena_db',
            collectionId: 'arena_participants',
            documentId: participantsResponse.documents.first.$id,
          );
        }
      }
      
      logger.info('Left room: ${params.roomId}');
    } catch (e) {
      logger.error('Failed to leave room: $e');
      // Don't throw - allow graceful exit
    }
  }

  @override
  void dispose() {
    logger.debug('Disposing arena provider for room: ${params.roomId}');
    
    _realtimeSubscription?.cancel();
    _timerUpdater?.cancel();
    _roomStatusChecker?.cancel();
    _roomCompletionTimer?.cancel();
    
    super.dispose();
  }
}