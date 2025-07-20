import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import 'dart:async';
import '../models/arena_state.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/error/app_error.dart';
import '../../../core/providers/app_providers.dart';
import '../../../services/appwrite_service.dart';
import '../../../services/sound_service.dart';
import '../../../services/firebase_arena_timer_service.dart';

/// Arena room provider
final arenaProvider = StateNotifierProvider.family<ArenaNotifier, ArenaState, String>(
  (ref, roomId) => ArenaNotifier(
    roomId: roomId,
    logger: ref.read(loggerProvider),
    appwrite: ref.read(appwriteServiceProvider),
    sound: ref.read(soundServiceProvider),
  ),
);

/// Firebase timer service provider
final firebaseArenaTimerServiceProvider = Provider((ref) => FirebaseArenaTimerService());

/// Arena timer provider - using Firebase real-time sync
final arenaTimerProvider = StreamProvider.family<int, String>((ref, roomId) {
  final firebaseTimer = ref.watch(firebaseArenaTimerServiceProvider);
  
  // Get real-time timer updates from Firebase
  return firebaseTimer.getArenaTimerStream(roomId).asyncMap((timerData) async {
    final isRunning = timerData['isTimerRunning'] ?? false;
    final isPaused = timerData['isPaused'] ?? false;
    final remainingSeconds = timerData['remainingSeconds'] ?? 0;
    
    if (!isRunning || isPaused) {
      // Timer is stopped or paused - return Firebase value
      return remainingSeconds;
    }
    
    // Timer is running - calculate elapsed time since last update
    final lastUpdate = timerData['lastUpdate'];
    if (lastUpdate != null) {
      final elapsed = DateTime.now().difference(lastUpdate.toDate()).inSeconds;
      final adjustedTime = (remainingSeconds - elapsed).clamp(0, double.infinity).toInt();
      return adjustedTime;
    }
    
    return remainingSeconds;
  });
});

/// Arena notification
class ArenaNotifier extends StateNotifier<ArenaState> {
  ArenaNotifier({
    required this.roomId,
    required this.logger,
    required this.appwrite,
    required this.sound,
  }) : super(ArenaState(roomId: roomId, topic: '')) {
    _firebaseTimer = FirebaseArenaTimerService();
    _init();
  }

  final String roomId;
  final AppLogger logger;
  final AppwriteService appwrite;
  final SoundService sound;
  late final FirebaseArenaTimerService _firebaseTimer;
  
  RealtimeSubscription? _subscription;
  StreamSubscription? _firebaseTimerSubscription;

  Future<void> _init() async {
    try {
      state = state.copyWith(isLoading: true);
      
      // Load arena data
      await _loadArenaData();
      
      // Setup realtime subscription for participants
      await _setupRealtimeSubscription();
      
      // Initialize Firebase timer for this room
      await _initializeFirebaseTimer();
      
      // Setup Firebase timer stream
      _setupFirebaseTimerStream();
      
      state = state.copyWith(isLoading: false);
      logger.info('Arena initialized successfully: $roomId');
    } catch (e, stackTrace) {
      final error = ErrorHandler.handleError(e, stackTrace);
      logger.logError(error);
      state = state.copyWith(
        isLoading: false,
        error: ErrorHandler.getUserFriendlyMessage(error),
      );
    }
  }

  Future<void> _loadArenaData() async {
    try {
      // Load arena room details  
      final roomResponse = await appwrite.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
      );

      final roomData = roomResponse.data;
      
      // Load participants
      final participantsResponse = await appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'room_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.limit(50),
        ],
      );

      final participants = <String, ArenaParticipant>{};
      for (final doc in participantsResponse.documents) {
        final data = doc.data;
        final participant = ArenaParticipant(
          userId: data['userId'] ?? '',
          name: data['userName'] ?? 'Unknown',
          role: _parseRole(data['role']),
          avatar: data['avatar'],
          isReady: data['isReady'] ?? false,
          joinedAt: data['joinedAt'] != null 
            ? DateTime.parse(data['joinedAt']) 
            : null,
        );
        participants[participant.userId] = participant;
      }

      state = state.copyWith(
        topic: roomData['topic'] ?? 'Unknown Topic',
        description: roomData['description'],
        category: roomData['category'],
        status: _parseStatus(roomData['status']),
        participants: participants,
        currentPhase: _parsePhase(roomData['currentPhase']),
        remainingSeconds: roomData['remainingTime'] ?? 0,
        isTimerRunning: roomData['isTimerRunning'] ?? false,
        isPaused: roomData['isPaused'] ?? false,
        currentSpeaker: roomData['currentSpeaker'],
      );
      
      logger.debug('🔥 LOADED ARENA: Timer: ${roomData['isTimerRunning']}, Remaining: ${roomData['remainingTime']}, Phase: ${roomData['currentPhase']}');
      logger.debug('🔥 FULL ROOM DATA: $roomData');
    } catch (e) {
      throw DataError(message: 'Failed to load arena data: $e');
    }
  }

  Future<void> _setupRealtimeSubscription() async {
    try {
      _subscription?.close();
      
      final realtime = Realtime(appwrite.client);
      _subscription = realtime.subscribe([
        'databases.arena_db.collections.arena_rooms.documents.$roomId',
        'databases.arena_db.collections.room_participants.documents',
      ]);

      _subscription!.stream.listen(
        _handleRealtimeEvent,
        onError: (error) {
          logger.error('🔥 Arena realtime error', error);
        },
      );
      
      logger.info('🔥 REALTIME SUBSCRIPTION CREATED for: $roomId');
    } catch (e) {
      throw NetworkError(message: 'Failed to setup realtime subscription: $e');
    }
  }

  void _handleRealtimeEvent(RealtimeMessage message) {
    try {
      final events = message.events;
      final payload = message.payload;
      
      logger.debug('🔥 REALTIME EVENT: ${events.join(", ")}');

      if (events.any((e) => e.contains('room_participants'))) {
        _handleParticipantUpdate(payload);
      } else if (events.any((e) => e.contains('arena_rooms'))) {
        logger.debug('🔥 ARENA ROOM UPDATE RECEIVED');
        _handleRoomUpdate(payload);
      }
    } catch (e) {
      logger.error('🔥 Error handling realtime event', e);
    }
  }

  void _handleParticipantUpdate(Map<String, dynamic> payload) {
    try {
      if (payload['roomId'] != roomId) return;

      final participant = ArenaParticipant(
        userId: payload['userId'] ?? '',
        name: payload['userName'] ?? 'Unknown',
        role: _parseRole(payload['role']),
        avatar: payload['avatar'],
        isReady: payload['isReady'] ?? false,
        joinedAt: payload['joinedAt'] != null 
          ? DateTime.parse(payload['joinedAt']) 
          : null,
      );

      final updatedParticipants = Map<String, ArenaParticipant>.from(state.participants);
      updatedParticipants[participant.userId] = participant;

      state = state.copyWith(participants: updatedParticipants);
    } catch (e) {
      logger.error('Error handling participant update', e);
    }
  }

  void _handleRoomUpdate(Map<String, dynamic> payload) {
    try {
      final newStatus = _parseStatus(payload['status']);
      final newPhase = _parsePhase(payload['currentPhase']);

      if (newStatus != state.status) {
        _onStatusChanged(newStatus);
      }

      if (newPhase != state.currentPhase) {
        _onPhaseChanged(newPhase);
      }

      // Extract timer state from database update
      final remainingTime = payload['remainingTime'] ?? state.remainingSeconds;
      final isTimerRunning = payload['isTimerRunning'] ?? false;
      final isPaused = payload['isPaused'] ?? false;

      state = state.copyWith(
        status: newStatus,
        currentPhase: newPhase,
        currentSpeaker: payload['currentSpeaker'],
        remainingSeconds: remainingTime,
        isTimerRunning: isTimerRunning,
        isPaused: isPaused,
      );
      
      logger.debug('🔥 TIMER SYNC: Running: $isTimerRunning, Paused: $isPaused, Remaining: $remainingTime, Phase: ${payload['currentPhase']}');
      logger.debug('🔥 PAYLOAD FULL: $payload');
    } catch (e) {
      logger.error('Error handling room update', e);
    }
  }

  void _onStatusChanged(ArenaStatus newStatus) {
    switch (newStatus) {
      case ArenaStatus.starting:
        sound.playCustomSound('arena_start.mp3');
        break;
      case ArenaStatus.completed:
        sound.playApplauseSound();
        break;
      default:
        break;
    }
  }

  void _onPhaseChanged(DebatePhase newPhase) {
    switch (newPhase) {
      case DebatePhase.openingAffirmative:
      case DebatePhase.openingNegative:
      case DebatePhase.rebuttalAffirmative:
      case DebatePhase.rebuttalNegative:
      case DebatePhase.closingAffirmative:
      case DebatePhase.closingNegative:
        sound.playCustomSound('phase_change.mp3');
        break;
      case DebatePhase.judging:
        sound.playCustomSound('voting_start.mp3');
        break;
      default:
        break;
    }
  }

  // Public methods
  Future<void> joinArena(String userId, ArenaRole role) async {
    try {
      await appwrite.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'room_participants',
        documentId: ID.unique(),
        data: {
          'roomId': roomId,
          'userId': userId,
          'role': role.name,
          'isReady': false,
          'joinedAt': DateTime.now().toIso8601String(),
        },
      );
      
      logger.info('User $userId joined arena as ${role.name}');
    } catch (e) {
      throw DataError(message: 'Failed to join arena: $e');
    }
  }

  Future<void> setReady(String userId, bool isReady) async {
    try {
      // Update in database
      final participantsResponse = await appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'room_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
        ],
      );

      if (participantsResponse.documents.isNotEmpty) {
        await appwrite.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'room_participants',
          documentId: participantsResponse.documents.first.$id,
          data: {'isReady': isReady},
        );
      }
    } catch (e) {
      throw DataError(message: 'Failed to update ready status: $e');
    }
  }

  Future<void> startArena() async {
    try {
      if (!state.isReadyToStart) {
        throw const ValidationError(message: 'Arena is not ready to start');
      }

      await appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'status': ArenaStatus.starting.name,
          'currentPhase': DebatePhase.preDebate.name,
          'startTime': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      throw DataError(message: 'Failed to start arena: $e');
    }
  }

  Future<void> nextPhase() async {
    try {
      final nextPhase = _getNextPhase(state.currentPhase);
      final duration = state.getPhaseDurationSeconds(nextPhase);
      final durationSeconds = duration * 60; // Convert to seconds

      // Use Firebase for phase change
      await _firebaseTimer.nextPhase(roomId, nextPhase.name, durationSeconds);
      
      logger.info('Advanced to phase ${nextPhase.name} with $durationSeconds seconds via Firebase');
    } catch (e) {
      throw DataError(message: 'Failed to advance phase: $e');
    }
  }

  /// Set timer to specific duration
  Future<void> setTimer(int seconds) async {
    try {
      await _firebaseTimer.setTimer(roomId, seconds);
      logger.info('🔥 Timer set to $seconds seconds via Firebase');
    } catch (e) {
      logger.error('Failed to set timer: $e');
      throw DataError(message: 'Failed to set timer: $e');
    }
  }

  // Helper methods
  ArenaRole _parseRole(String? roleString) {
    switch (roleString) {
      case 'affirmative':
        return ArenaRole.affirmative;
      case 'negative':
        return ArenaRole.negative;
      case 'moderator':
        return ArenaRole.moderator;
      case 'judge':
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

  ArenaStatus _parseStatus(String? statusString) {
    return ArenaStatus.values.firstWhere(
      (status) => status.name == statusString,
      orElse: () => ArenaStatus.waiting,
    );
  }

  DebatePhase _parsePhase(String? phaseString) {
    return DebatePhase.values.firstWhere(
      (phase) => phase.name == phaseString,
      orElse: () => DebatePhase.preDebate,
    );
  }

  /// Initialize timer fields for arena room if they don't exist
  Future<void> initializeTimerFields() async {
    try {
      final now = DateTime.now().toIso8601String();
      await appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'currentPhase': 'preDebate',
          'remainingTime': 0,
          'isTimerRunning': false,
          'isPaused': false,
          'phaseStartedAt': now,
          'lastTimerUpdate': now,
        },
      );
      logger.info('Timer fields initialized for room: $roomId');
    } catch (e) {
      logger.warning('Failed to initialize timer fields: $e');
    }
  }

  // Additional methods for the new modular screen
  Future<void> initialize({
    required String challengeId,
    String? topic,
    String? description,
    String? category,
    String? challengerId,
    String? challengedId,
  }) async {
    try {
      // Initialize arena with provided parameters
      await initializeTimerFields();
      logger.info('Arena initialized for room: $roomId');
    } catch (e) {
      logger.error('Failed to initialize arena: $e');
      throw DataError(message: 'Failed to initialize arena: $e');
    }
  }

  Future<void> requestToSpeak() async {
    try {
      final currentUserId = await appwrite.account.get().then((user) => user.$id);
      
      await appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'currentSpeaker': currentUserId,
        },
      );
      
      logger.info('User $currentUserId requested to speak');
    } catch (e) {
      logger.error('Failed to request speaking: $e');
      throw DataError(message: 'Failed to request speaking permission: $e');
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'currentSpeaker': null,
        },
      );
      
      logger.info('User stopped speaking');
    } catch (e) {
      logger.error('Failed to stop speaking: $e');
      throw DataError(message: 'Failed to stop speaking: $e');
    }
  }

  Future<void> startDebate() async {
    try {
      if (!state.isReadyToStart) {
        throw const ValidationError(message: 'Cannot start debate - not all participants are ready');
      }

      await appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'status': ArenaStatus.speaking.name,
          'currentPhase': DebatePhase.openingAffirmative.name,
          'startTime': DateTime.now().toIso8601String(),
          'isTimerRunning': true,
          'remainingTime': 600, // 10 minutes for opening phase
        },
      );
      
      logger.info('Debate started for room: $roomId');
    } catch (e) {
      logger.error('Failed to start debate: $e');
      throw DataError(message: 'Failed to start debate: $e');
    }
  }

  Future<void> sendMessage(String content) async {
    try {
      final currentUser = await appwrite.account.get();
      
      await appwrite.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'messages',
        documentId: 'unique()',
        data: {
          'roomId': roomId,
          'senderId': currentUser.$id,
          'senderName': currentUser.name,
          'content': content,
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'user',
        },
      );
      
      logger.info('Message sent to arena: $roomId');
    } catch (e) {
      logger.error('Failed to send message: $e');
      throw DataError(message: 'Failed to send message: $e');
    }
  }

  Future<void> leaveArena() async {
    try {
      final currentUser = await appwrite.account.get();
      
      // Remove user from participants
      final updatedParticipants = Map<String, ArenaParticipant>.from(state.participants);
      updatedParticipants.remove(currentUser.$id);

      await appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'participants': updatedParticipants.map((k, v) => MapEntry(k, {
            'userId': v.userId,
            'name': v.name,
            'role': v.role.name,
            'isReady': v.isReady,
            'joinedAt': v.joinedAt?.toIso8601String(),
          })),
        },
      );
      
      logger.info('User ${currentUser.$id} left arena: $roomId');
    } catch (e) {
      logger.error('Failed to leave arena: $e');
      // Don't throw error for leaving - allow graceful exit even if update fails
    }
  }

  DebatePhase _getNextPhase(DebatePhase currentPhase) {
    const phases = DebatePhase.values;
    final currentIndex = phases.indexOf(currentPhase);
    
    if (currentIndex < phases.length - 1) {
      return phases[currentIndex + 1];
    }
    
    return DebatePhase.judging; // Default to judging if at end
  }

  /// Initialize Firebase timer for this arena
  Future<void> _initializeFirebaseTimer() async {
    try {
      // Check if timer already exists to avoid duplicates
      final exists = await _firebaseTimer.timerExists(roomId);
      if (!exists) {
        await _firebaseTimer.initializeArenaTimer(roomId);
        logger.info('🔥 Firebase timer initialized for room: $roomId');
      } else {
        logger.info('🔥 Firebase timer already exists for room: $roomId');
      }
    } catch (e) {
      logger.error('Failed to initialize Firebase timer: $e');
      // Don't throw - we can still function without Firebase timer
    }
  }

  /// Setup Firebase timer stream to sync timer state
  void _setupFirebaseTimerStream() {
    try {
      _firebaseTimerSubscription?.cancel();
      _firebaseTimerSubscription = _firebaseTimer.getArenaTimerStream(roomId).listen(
        (timerData) {
          // Update local state with Firebase timer data
          final newPhase = _parsePhase(timerData['currentPhase']);
          final remainingSeconds = timerData['remainingSeconds'] ?? 0;
          final isTimerRunning = timerData['isTimerRunning'] ?? false;
          final isPaused = timerData['isPaused'] ?? false;
          final currentSpeaker = timerData['currentSpeaker'];

          state = state.copyWith(
            currentPhase: newPhase,
            remainingSeconds: remainingSeconds,
            isTimerRunning: isTimerRunning,
            isPaused: isPaused,
            currentSpeaker: currentSpeaker,
          );

          logger.debug('🔥 Firebase timer sync: Phase: ${newPhase.name}, Time: ${remainingSeconds}s, Running: $isTimerRunning');
        },
        onError: (error) {
          logger.error('Firebase timer stream error: $error');
        },
      );
    } catch (e) {
      logger.error('Failed to setup Firebase timer stream: $e');
    }
  }

  Future<void> pauseTimer() async {
    try {
      // Use Firebase for timer control
      await _firebaseTimer.pauseTimer(roomId);
      logger.info('🔥 Timer paused via Firebase');
    } catch (e) {
      logger.error('Failed to pause timer: $e');
      throw DataError(message: 'Failed to pause timer: $e');
    }
  }

  Future<void> resumeTimer() async {
    try {
      // Use Firebase for timer control
      await _firebaseTimer.startTimer(roomId);
      logger.info('🔥 Timer resumed via Firebase');
    } catch (e) {
      logger.error('Failed to resume timer: $e');
      throw DataError(message: 'Failed to resume timer: $e');
    }
  }

  Future<void> addTime(int seconds) async {
    try {
      // Use Firebase for timer control
      await _firebaseTimer.adjustTime(roomId, seconds);
      logger.info('🔥 Added $seconds seconds to timer via Firebase');
    } catch (e) {
      logger.error('Failed to add time: $e');
      throw DataError(message: 'Failed to add time: $e');
    }
  }

  Future<void> assignSpeaker(String userId) async {
    try {
      await appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'currentSpeaker': userId,
        },
      );
      logger.info('Assigned speaker: $userId');
    } catch (e) {
      logger.error('Failed to assign speaker: $e');
      throw DataError(message: 'Failed to assign speaker: $e');
    }
  }

  Future<void> toggleReady(String userId) async {
    final participant = state.participants[userId];
    if (participant != null) {
      await setReady(userId, !participant.isReady);
    }
  }

  Future<void> endDebate() async {
    try {
      await appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'status': ArenaStatus.completed.name,
          'endTime': DateTime.now().toIso8601String(),
          'isTimerRunning': false,
        },
      );
      logger.info('Debate ended for room: $roomId');
    } catch (e) {
      logger.error('Failed to end debate: $e');
      throw DataError(message: 'Failed to end debate: $e');
    }
  }


  @override
  void dispose() {
    _subscription?.close();
    _firebaseTimerSubscription?.cancel();
    // Clean up Firebase timer when leaving arena
    _firebaseTimer.cleanupTimer(roomId);
    super.dispose();
  }
}