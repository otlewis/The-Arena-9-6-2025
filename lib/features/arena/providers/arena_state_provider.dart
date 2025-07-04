import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/appwrite_service.dart';
import '../../../services/challenge_messaging_service.dart';
import '../../../services/sound_service.dart';
import '../services/arena_realtime_service.dart';
import '../services/arena_participant_service.dart';
import '../services/arena_ios_optimization_service.dart';
import '../models/arena_room_state.dart';
import '../models/debate_phase.dart';
import '../models/participant_role.dart';
import '../../../models/user_profile.dart';
import '../utils/arena_constants.dart';
import '../../../core/logging/app_logger.dart';

/// Provider for ArenaRoomState
final arenaStateProvider = StateNotifierProvider.autoDispose
    .family<ArenaStateNotifier, ArenaRoomState, String>(
  (ref, roomId) {
    final appwrite = ref.read(appwriteServiceProvider);
    final messaging = ref.read(challengeMessagingServiceProvider);
    final sound = ref.read(soundServiceProvider);
    final realtime = ref.read(arenaRealtimeServiceProvider);
    final participant = ref.read(arenaParticipantServiceProvider);
    final ios = ref.read(arenaIOSOptimizationServiceProvider);
    
    return ArenaStateNotifier(
      roomId: roomId,
      appwriteService: appwrite,
      messagingService: messaging,
      soundService: sound,
      realtimeService: realtime,
      participantService: participant,
      iosService: ios,
    );
  },
);

/// Service providers
final appwriteServiceProvider = Provider<AppwriteService>((ref) => AppwriteService());
final challengeMessagingServiceProvider = Provider<ChallengeMessagingService>((ref) => ChallengeMessagingService());
final soundServiceProvider = Provider<SoundService>((ref) => SoundService());

/// Arena service providers
final arenaRealtimeServiceProvider = Provider<ArenaRealtimeService>((ref) {
  final appwrite = ref.read(appwriteServiceProvider);
  return ArenaRealtimeService(appwriteService: appwrite);
});

final arenaParticipantServiceProvider = Provider<ArenaParticipantService>((ref) {
  final appwrite = ref.read(appwriteServiceProvider);
  return ArenaParticipantService(appwriteService: appwrite);
});

final arenaIOSOptimizationServiceProvider = Provider<ArenaIOSOptimizationService>((ref) {
  final appwrite = ref.read(appwriteServiceProvider);
  return ArenaIOSOptimizationService(appwriteService: appwrite);
});

/// State notifier for managing arena room state
class ArenaStateNotifier extends StateNotifier<ArenaRoomState> {
  final String roomId;
  final AppwriteService _appwriteService;
  final ChallengeMessagingService _messagingService;
  final SoundService _soundService;
  final ArenaRealtimeService _realtimeService;
  final ArenaParticipantService _participantService;
  final ArenaIOSOptimizationService _iosService;
  
  ArenaStateNotifier({
    required this.roomId,
    required AppwriteService appwriteService,
    required ChallengeMessagingService messagingService,
    required SoundService soundService,
    required ArenaRealtimeService realtimeService,
    required ArenaParticipantService participantService,
    required ArenaIOSOptimizationService iosService,
  }) : _appwriteService = appwriteService,
       _messagingService = messagingService,
       _soundService = soundService,
       _realtimeService = realtimeService,
       _participantService = participantService,
       _iosService = iosService,
       super(ArenaRoomState(
         roomId: roomId,
         challengeId: '',
         topic: 'Loading...',
         participants: {},
         audience: [],
         currentPhase: DebatePhase.preDebate,
         status: ArenaConstants.roomStatusActive,
         isLoading: true,
         judgingEnabled: false,
         currentUserRole: ParticipantRole.audience,
         error: null,
         winner: null,
         currentUser: null,
         description: null,
         category: null,
       )) {
    _initialize();
  }
  
  /// Initialize the arena room
  Future<void> _initialize() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      // Initialize iOS optimizations if needed
      await _iosService.initialize(roomId);
      
      // Load room data
      await _loadRoomData();
      
      // Load participants
      await _loadParticipants();
      
      // Setup realtime subscriptions
      _setupRealtimeSubscriptions();
      
      state = state.copyWith(isLoading: false);
      AppLogger().info('Arena initialized successfully for room: $roomId');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      AppLogger().error('Failed to initialize arena: $e');
    }
  }
  
  /// Load room data from database
  Future<void> _loadRoomData() async {
    try {
      final roomData = await _appwriteService.databases.getDocument(
        databaseId: ArenaConstants.databaseId,
        collectionId: ArenaConstants.debateRoomsCollection,
        documentId: roomId,
      );
      
      final currentUser = await _appwriteService.getCurrentUser();
      
      UserProfile? userProfile;
      if (currentUser != null) {
        try {
          final userData = await _appwriteService.databases.getDocument(
            databaseId: ArenaConstants.databaseId,
            collectionId: ArenaConstants.userProfilesCollection,
            documentId: currentUser.$id,
          );
          userProfile = UserProfile(
            id: userData.$id,
            name: userData.data['name'] ?? 'Unknown User',
            email: userData.data['email'] ?? '',
            avatar: userData.data['avatar'],
            bio: userData.data['bio'],
            reputation: userData.data['reputation'] ?? 0,
            totalWins: userData.data['totalWins'] ?? 0,
            totalDebates: userData.data['totalDebates'] ?? 0,
            createdAt: DateTime.parse(userData.$createdAt),
            updatedAt: DateTime.parse(userData.$updatedAt),
          );
        } catch (e) {
          AppLogger().warning('Failed to load user profile: $e');
        }
      }
      
      state = state.copyWith(
        challengeId: roomData.data['challengeId'] ?? '',
        topic: roomData.data['topic'] ?? '',
        description: roomData.data['description'],
        category: roomData.data['category'],
        status: roomData.data['status'] ?? ArenaConstants.roomStatusActive,
        currentUser: userProfile,
      );
      
      AppLogger().info('Room data loaded: ${roomData.data['topic']}');
    } catch (e) {
      throw Exception('${ArenaConstants.errorLoadingRoom}: $e');
    }
  }
  
  /// Load participants from database
  Future<void> _loadParticipants() async {
    try {
      final participants = await _participantService.loadParticipants(roomId);
      final audience = await _participantService.loadAudience(roomId);
      
      // Determine current user role
      ParticipantRole currentUserRole = ParticipantRole.audience;
      if (state.currentUser != null) {
        final userId = state.currentUser!.id;
        
        // Check if user is a participant
        for (final entry in participants.entries) {
          if (entry.value.id == userId) {
            currentUserRole = ParticipantRole.fromId(entry.key) ?? ParticipantRole.audience;
            break;
          }
        }
      }
      
      state = state.copyWith(
        participants: participants,
        audience: audience,
        currentUserRole: currentUserRole,
        bothDebatersPresent: participants.containsKey('affirmative') && participants.containsKey('negative'),
      );
      
      AppLogger().info('Participants loaded: ${participants.length} participants, ${audience.length} audience');
    } catch (e) {
      throw Exception('${ArenaConstants.errorLoadingParticipants}: $e');
    }
  }
  
  /// Setup realtime subscriptions
  void _setupRealtimeSubscriptions() {
    _realtimeService.subscribeToRoom(
      roomId: roomId,
      onParticipantsChanged: _onParticipantsChanged,
      onRoomDataChanged: _onRoomDataChanged,
    );
  }
  
  /// Handle participants change from realtime
  void _onParticipantsChanged() {
    _loadParticipants();
  }
  
  /// Handle room data change from realtime
  void _onRoomDataChanged() {
    _loadRoomData();
  }
  
  /// Update current phase
  void updatePhase(DebatePhase newPhase) {
    state = state.copyWith(
      currentPhase: newPhase,
      currentSpeaker: newPhase.speakerRole,
      speakingEnabled: newPhase.hasSpeaker,
    );
    AppLogger().info('Phase updated to: ${newPhase.displayName}');
  }
  
  /// Advance to next phase
  void advanceToNextPhase() {
    final nextPhase = state.currentPhase.nextPhase;
    if (nextPhase != null) {
      updatePhase(nextPhase);
    }
  }
  
  /// Update timer state
  void updateTimer({
    int? remainingSeconds,
    bool? isRunning,
    bool? isPaused,
    bool? hasPlayed30SecWarning,
  }) {
    state = state.copyWith(
      remainingSeconds: remainingSeconds ?? state.remainingSeconds,
      isTimerRunning: isRunning ?? state.isTimerRunning,
      isTimerPaused: isPaused ?? state.isTimerPaused,
      hasPlayed30SecWarning: hasPlayed30SecWarning ?? state.hasPlayed30SecWarning,
    );
  }
  
  /// Set custom timer duration
  void setCustomTime(int seconds) {
    state = state.copyWith(
      remainingSeconds: seconds,
      isTimerRunning: false,
      isTimerPaused: false,
    );
    AppLogger().info('Custom time set: ${seconds}s');
  }
  
  /// Handle timer timeout
  void onTimerTimeout() {
    _soundService.playArenaZeroSound();
    state = state.copyWith(
      isTimerRunning: false,
      hasPlayed30SecWarning: false,
    );
    AppLogger().info('Timer timeout for phase: ${state.currentPhase.displayName}');
  }
  
  /// Play 30-second warning
  void play30SecondWarning() {
    if (!state.hasPlayed30SecWarning && state.remainingSeconds == 30) {
      _soundService.play30SecWarningSound();
      state = state.copyWith(hasPlayed30SecWarning: true);
      AppLogger().debug('30-second warning played');
    }
  }
  
  /// Assign role to user
  Future<void> assignRole(UserProfile user, ParticipantRole role) async {
    try {
      await _participantService.assignRole(roomId, user, role);
      AppLogger().info('Role assigned: ${user.name} -> ${role.displayName}');
    } catch (e) {
      state = state.copyWith(error: '${ArenaConstants.errorAssigningRole}: $e');
      AppLogger().error('Failed to assign role: $e');
    }
  }
  
  /// Submit vote
  Future<void> submitVote(String winner) async {
    if (state.hasCurrentUserSubmittedVote || state.currentUser == null) {
      return;
    }
    
    try {
      await _appwriteService.databases.createDocument(
        databaseId: ArenaConstants.databaseId,
        collectionId: ArenaConstants.debateVotesCollection,
        documentId: '${roomId}_${state.currentUser!.id}_vote',
        data: {
          'roomId': roomId,
          'voterId': state.currentUser!.id,
          'winner': winner,
          'submittedAt': DateTime.now().toIso8601String(),
        },
      );
      
      state = state.copyWith(hasCurrentUserSubmittedVote: true);
      AppLogger().info('Vote submitted for: $winner');
    } catch (e) {
      state = state.copyWith(error: '${ArenaConstants.errorSubmittingVote}: $e');
      AppLogger().error('Failed to submit vote: $e');
    }
  }
  
  /// Toggle judging
  void toggleJudging() {
    state = state.copyWith(judgingEnabled: !state.judgingEnabled);
    AppLogger().info('Judging ${state.judgingEnabled ? 'enabled' : 'disabled'}');
  }
  
  /// Toggle speaking
  void toggleSpeaking() {
    state = state.copyWith(speakingEnabled: !state.speakingEnabled);
    AppLogger().info('Speaking ${state.speakingEnabled ? 'enabled' : 'disabled'}');
  }
  
  /// Force speaker change
  void forceSpeakerChange(String newSpeaker) {
    state = state.copyWith(
      currentSpeaker: newSpeaker,
      speakingEnabled: true,
    );
    AppLogger().info('Speaker forced to: $newSpeaker');
  }
  
  /// Set winner
  void setWinner(String winner) {
    state = state.copyWith(
      winner: winner,
      judgingComplete: true,
    );
    AppLogger().info('Winner set: $winner');
  }
  
  /// Close room
  Future<void> closeRoom() async {
    if (!state.canCloseRoom) {
      return;
    }
    
    try {
      state = state.copyWith(isExiting: true);
      
      await _appwriteService.databases.updateDocument(
        databaseId: ArenaConstants.databaseId,
        collectionId: ArenaConstants.debateRoomsCollection,
        documentId: roomId,
        data: {
          'status': ArenaConstants.roomStatusClosed,
          'closedAt': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger().info('Room closed successfully');
    } catch (e) {
      state = state.copyWith(error: '${ArenaConstants.errorClosingRoom}: $e', isExiting: false);
      AppLogger().error('Failed to close room: $e');
    }
  }
  
  /// Update UI state
  void updateUIState({
    bool? resultsModalShown,
    bool? roomClosingModalShown,
    bool? invitationModalShown,
    bool? hasNavigated,
  }) {
    state = state.copyWith(
      resultsModalShown: resultsModalShown ?? state.resultsModalShown,
      roomClosingModalShown: roomClosingModalShown ?? state.roomClosingModalShown,
      invitationModalShown: invitationModalShown ?? state.invitationModalShown,
      hasNavigated: hasNavigated ?? state.hasNavigated,
    );
  }
  
  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
  
  /// Dispose resources
  @override
  void dispose() {
    _realtimeService.dispose();
    _iosService.dispose();
    super.dispose();
  }
}