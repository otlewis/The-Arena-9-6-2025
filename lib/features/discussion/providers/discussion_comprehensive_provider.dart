import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import 'dart:async';
import 'dart:convert';
import '../models/discussion_state.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/error/app_error.dart';
import '../../../core/providers/app_providers.dart';
import '../../../services/appwrite_service.dart';
import '../../../services/agora_service.dart';
import '../../../services/firebase_gift_service.dart';
import '../../../models/models.dart';
import 'package:audioplayers/audioplayers.dart';

/// Discussion room initialization parameters
class DiscussionInitParams {
  final Room room;

  DiscussionInitParams({
    required this.room,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscussionInitParams &&
        other.room.id == room.id &&
        other.room.title == room.title &&
        other.room.description == room.description &&
        other.room.type == room.type &&
        other.room.status == room.status &&
        other.room.createdBy == room.createdBy;
  }

  @override
  int get hashCode {
    return Object.hash(
      room.id,
      room.title,
      room.description,
      room.type,
      room.status,
      room.createdBy,
    );
  }
}

/// Comprehensive Discussion Room provider that manages all discussion state
final discussionComprehensiveProvider = StateNotifierProvider.family<DiscussionComprehensiveNotifier, DiscussionState, DiscussionInitParams>(
  (ref, params) => DiscussionComprehensiveNotifier(
    params: params,
    logger: ref.read(loggerProvider),
    appwrite: ref.read(appwriteServiceProvider),
  ),
);

/// Timer stream provider for real-time countdown
final discussionTimerStreamProvider = StreamProvider.family<int, DiscussionInitParams>((ref, params) {
  final discussion = ref.watch(discussionComprehensiveProvider(params));
  
  if (!discussion.timerState.isTimerRunning || discussion.timerState.isTimerPaused) {
    return Stream.value(discussion.timerState.speakingTime);
  }
  
  return Stream.periodic(const Duration(seconds: 1), (count) {
    final remaining = discussion.timerState.speakingTime - count - 1;
    return remaining > 0 ? remaining : 0;
  }).takeWhile((time) => time >= 0);
});

/// Network health provider
final discussionNetworkHealthProvider = Provider.family<bool, DiscussionInitParams>((ref, params) {
  final discussion = ref.watch(discussionComprehensiveProvider(params));
  return discussion.networkState.isRealtimeHealthy;
});

/// Participants provider - returns structured participant data
final discussionParticipantsProvider = Provider.family<({
  List<DiscussionParticipant> moderators,
  List<DiscussionParticipant> speakers,
  List<DiscussionParticipant> audience,
  List<DiscussionParticipant> handsRaised,
}), DiscussionInitParams>((ref, params) {
  final discussion = ref.watch(discussionComprehensiveProvider(params));
  
  return (
    moderators: discussion.moderators,
    speakers: discussion.speakers,
    audience: discussion.audience,
    handsRaised: discussion.participantsWithHandsRaised,
  );
});

/// Voice state provider
final discussionVoiceProvider = Provider.family<VoiceState, DiscussionInitParams>((ref, params) {
  final discussion = ref.watch(discussionComprehensiveProvider(params));
  return discussion.voiceState;
});

/// User role and permissions provider
final discussionUserRoleProvider = Provider.family<({
  bool isModerator,
  bool isSpeaker,
  bool canSpeak,
  bool canModerate,
  String? role,
}), DiscussionInitParams>((ref, params) {
  final discussion = ref.watch(discussionComprehensiveProvider(params));
  
  return (
    isModerator: discussion.isCurrentUserModerator,
    isSpeaker: discussion.isCurrentUserSpeaker,
    canSpeak: discussion.isCurrentUserModerator || discussion.isCurrentUserSpeaker,
    canModerate: discussion.isCurrentUserModerator,
    role: discussion.userRole,
  );
});

/// UI state provider
final discussionUIStateProvider = Provider.family<({
  bool isChatOpen,
  bool showModerationPanel,
  bool isLoading,
  String? error,
}), DiscussionInitParams>((ref, params) {
  final discussion = ref.watch(discussionComprehensiveProvider(params));
  
  return (
    isChatOpen: discussion.isChatOpen,
    showModerationPanel: discussion.showModerationPanel,
    isLoading: discussion.isLoading,
    error: discussion.error,
  );
});

/// Comprehensive Discussion Room Notifier - manages all discussion state
class DiscussionComprehensiveNotifier extends StateNotifier<DiscussionState> {
  DiscussionComprehensiveNotifier({
    required this.params,
    required this.logger,
    required this.appwrite,
  }) : super(DiscussionState(
    roomId: params.room.id,
    room: params.room,
  )) {
    _init();
  }

  final DiscussionInitParams params;
  final AppLogger logger;
  final AppwriteService appwrite;
  
  // Services
  final AgoraService _agoraService = AgoraService();
  final FirebaseGiftService _firebaseGiftService = FirebaseGiftService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Subscriptions and timers
  StreamSubscription? _realtimeSubscription;
  Timer? _speakingTimer;
  Timer? _fallbackRefreshTimer;
  
  // Connection management
  static const int _maxReconnectAttempts = 5;

  Future<void> _init() async {
    try {
      state = state.copyWith(isLoading: true);
      logger.info('Initializing discussion room: ${params.room.id}');
      
      // Initialize audio player
      await _initializeAudioPlayer();
      
      // Get current user
      await _loadCurrentUser();
      
      // Load Firebase coin balance
      await _loadFirebaseCoinBalance();
      
      // Join the room as a participant
      await _joinRoom();
      
      // Load participants and profiles
      await _loadRoomParticipants();
      
      // Load hand raises from participant metadata
      await _loadHandRaisesFromParticipants();
      
      // Set up real-time subscription
      await _setupRealtimeSubscription();
      
      // Initialize Agora voice
      await _initializeAgora();
      
      state = state.copyWith(isLoading: false);
      logger.info('Discussion room initialized successfully: ${params.room.id}');
    } catch (e, stackTrace) {
      final error = ErrorHandler.handleError(e, stackTrace);
      logger.logError(error);
      state = state.copyWith(
        isLoading: false,
        error: ErrorHandler.getUserFriendlyMessage(error),
      );
    }
  }

  Future<void> _initializeAudioPlayer() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      logger.debug('Audio player initialized successfully');
    } catch (e) {
      logger.error('Error initializing audio player: $e');
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final currentUser = await appwrite.account.get();
      state = state.copyWith(currentUserId: currentUser.$id);
      
      // Load current user's profile
      await _loadUserProfile(currentUser.$id);
      
      logger.debug('Current user loaded: ${currentUser.$id}');
    } catch (e) {
      logger.error('Failed to load current user: $e');
      throw DataError(message: 'Failed to load current user: $e');
    }
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      final profile = await appwrite.getUserProfile(userId);
      if (profile != null) {
        state = state.copyWith(
          userProfiles: {...state.userProfiles, userId: profile},
        );
      }
    } catch (e) {
      logger.warning('Failed to load user profile for $userId: $e');
    }
  }

  Future<void> _loadFirebaseCoinBalance() async {
    try {
      final balance = await _firebaseGiftService.getUserCoinBalance(state.currentUserId!);
      state = state.copyWith(coinBalance: balance);
      logger.debug('Firebase coin balance loaded: $balance');
    } catch (e) {
      logger.error('Firebase: Error loading coin balance: $e');
      // Set default 100 coins if Firebase fails
      state = state.copyWith(coinBalance: 100);
      logger.debug('Set default 100 coins due to Firebase error');
    }
  }

  Future<void> _joinRoom() async {
    try {
      // Determine initial role - creator is moderator, others start as audience
      final isCurrentUserModerator = params.room.createdBy == state.currentUserId;
      final initialRole = isCurrentUserModerator ? 'moderator' : 'audience';
      
      // Join the room in the database
      await appwrite.joinRoom(
        roomId: params.room.id,
        userId: state.currentUserId!,
        role: initialRole,
      );
      
      state = state.copyWith(userRole: initialRole);
      logger.info('Joined room ${params.room.id} as $initialRole');
    } catch (e) {
      logger.error('Error joining room: $e');
      // Continue anyway - user might already be in room
    }
  }

  Future<void> _loadRoomParticipants() async {
    try {
      // Get room data with participants
      final roomData = await appwrite.getRoom(params.room.id);
      if (roomData != null) {
        // Extract participants from room data
        final participantsData = roomData['participants'] as List<dynamic>? ?? [];
        
        logger.debug('Loading ${participantsData.length} participants from database');
        
        final participants = <DiscussionParticipant>[];
        
        // Process each participant
        for (final participantData in participantsData) {
          final userId = participantData['userId'];
          final role = participantData['role'];
          
          logger.debug('Found participant: $userId with role: $role');
          
          // Parse metadata
          Map<String, dynamic> metadata = {};
          try {
            final metadataField = participantData['metadata'];
            if (metadataField != null) {
              if (metadataField is String) {
                metadata = json.decode(metadataField);
              } else if (metadataField is Map<String, dynamic>) {
                metadata = metadataField;
              }
            }
          } catch (e) {
            logger.warning('Error parsing metadata for user $userId: $e');
            metadata = {};
          }
          
          // Load user profile if not already loaded
          if (!state.userProfiles.containsKey(userId)) {
            await _loadUserProfile(userId);
          }
          
          final userProfile = state.userProfiles[userId];
          if (userProfile != null) {
            participants.add(DiscussionParticipant(
              userId: userId,
              name: userProfile.displayName,
              role: _parseRole(role),
              avatar: userProfile.avatar,
              isHandRaised: metadata['handRaised'] == true,
              metadata: metadata,
            ));
          }
        }
        
        state = state.copyWith(participants: participants);
        logger.info('Loaded ${participants.length} participants');
      }
    } catch (e) {
      throw DataError(message: 'Failed to load participants: $e');
    }
  }

  DiscussionRole _parseRole(String? roleString) {
    switch (roleString) {
      case 'moderator':
        return DiscussionRole.moderator;
      case 'speaker':
        return DiscussionRole.speaker;
      default:
        return DiscussionRole.audience;
    }
  }

  Future<void> _loadHandRaisesFromParticipants() async {
    logger.debug('Loading hand raises from participants...');
    
    final handsRaised = <String>{};
    for (final participant in state.participants) {
      if (participant.isHandRaised) {
        handsRaised.add(participant.userId);
      }
    }
    
    state = state.copyWith(
      voiceState: state.voiceState.copyWith(handsRaised: handsRaised),
    );
  }

  Future<void> _setupRealtimeSubscription() async {
    try {
      if (state.networkState.reconnectAttempts >= state.networkState.maxReconnectAttempts) {
        logger.error('Maximum realtime reconnection attempts reached. Operating in offline mode.');
        state = state.copyWith(
          networkState: state.networkState.copyWith(isRealtimeHealthy: false),
        );
        _startFallbackRefresh();
        return;
      }

      _realtimeSubscription?.cancel();
      
      logger.debug('Setting up realtime subscription (attempt ${state.networkState.reconnectAttempts + 1}/${state.networkState.maxReconnectAttempts})');
      
      // Subscribe to room participants changes
      final subscription = appwrite.realtimeInstance.subscribe([
        'databases.arena_db.collections.room_participants.documents',
        'databases.arena_db.collections.rooms.documents',
      ]);
      
      _realtimeSubscription = subscription.stream.listen(
        _handleRealtimeEvent,
        onError: _handleRealtimeError,
        onDone: _handleRealtimeDisconnection,
      );
      
      // Reset connection health
      state = state.copyWith(
        networkState: state.networkState.copyWith(
          isRealtimeHealthy: true,
          reconnectAttempts: 0,
        ),
      );
    } catch (e) {
      throw NetworkError(message: 'Failed to setup realtime subscription: $e');
    }
  }

  void _handleRealtimeEvent(RealtimeMessage message) {
    try {
      // Reset reconnect attempts on successful message
      if (state.networkState.reconnectAttempts > 0) {
        state = state.copyWith(
          networkState: state.networkState.copyWith(
            reconnectAttempts: 0,
            isRealtimeHealthy: true,
          ),
        );
        logger.info('Discussion realtime connection restored');
        _stopFallbackRefresh();
      }
      
      logger.debug('Real-time discussion update: ${message.events}');
      
      // Check if this update affects our room
      final payload = message.payload;
      if (payload['roomId'] == params.room.id) {
        logger.debug('Refreshing participants for room update');
        _loadRoomParticipants();
      }
    } catch (e) {
      logger.error('Error handling realtime event: $e');
    }
  }

  void _handleRealtimeError(dynamic error) {
    logger.error('Discussion real-time subscription error: $error');
    
    final newAttempts = state.networkState.reconnectAttempts + 1;
    state = state.copyWith(
      networkState: state.networkState.copyWith(
        isRealtimeHealthy: false,
        reconnectAttempts: newAttempts,
      ),
    );
    
    // Implement exponential backoff
    if (newAttempts < _maxReconnectAttempts) {
      final delaySeconds = 2 << newAttempts.clamp(0, 5);
      logger.debug('Reconnecting in ${delaySeconds}s (attempt $newAttempts/$_maxReconnectAttempts)');
      
      Timer(Duration(seconds: delaySeconds), () {
        if (mounted && !state.isExiting) {
          _setupRealtimeSubscription();
        }
      });
    } else {
      logger.error('Discussion realtime max reconnection attempts reached');
    }
    
    _startFallbackRefresh();
  }

  void _handleRealtimeDisconnection() {
    logger.warning('Discussion real-time subscription closed');
    if (mounted && !state.isExiting && state.networkState.reconnectAttempts < _maxReconnectAttempts) {
      final newAttempts = state.networkState.reconnectAttempts + 1;
      state = state.copyWith(
        networkState: state.networkState.copyWith(reconnectAttempts: newAttempts),
      );
      
      logger.debug('Discussion subscription ended, attempting to reconnect...');
      Timer(const Duration(seconds: 3), () {
        if (mounted && !state.isExiting) {
          _setupRealtimeSubscription();
        }
      });
    }
  }

  void _startFallbackRefresh() {
    _fallbackRefreshTimer?.cancel();
    _fallbackRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted || state.isExiting) {
        timer.cancel();
        return;
      }
      _loadRoomParticipants();
    });
  }

  void _stopFallbackRefresh() {
    _fallbackRefreshTimer?.cancel();
    _fallbackRefreshTimer = null;
  }

  Future<void> _initializeAgora() async {
    try {
      state = state.copyWith(
        voiceState: state.voiceState.copyWith(isConnecting: true),
      );
      
      // Initialize Agora
      await _agoraService.initialize();
      
      // Set up callbacks
      _agoraService.onUserJoined = (uid) {
        state = state.copyWith(
          voiceState: state.voiceState.copyWith(
            remoteUsers: {...state.voiceState.remoteUsers, uid},
          ),
        );
        logger.debug('User $uid joined the voice channel. Total in voice: ${state.voiceState.remoteUsers.length + 1}');
      };
      
      _agoraService.onUserLeft = (uid) {
        final newRemoteUsers = Set<int>.from(state.voiceState.remoteUsers);
        final newSpeakingUsers = Set<int>.from(state.voiceState.speakingUsers);
        newRemoteUsers.remove(uid);
        newSpeakingUsers.remove(uid);
        
        state = state.copyWith(
          voiceState: state.voiceState.copyWith(
            remoteUsers: newRemoteUsers,
            speakingUsers: newSpeakingUsers,
          ),
        );
        logger.debug('User $uid left the voice channel. Total in voice: ${state.voiceState.remoteUsers.length + 1}');
      };
      
      _agoraService.onUserMuteAudio = (uid, muted) {
        final newSpeakingUsers = Set<int>.from(state.voiceState.speakingUsers);
        if (muted) {
          newSpeakingUsers.remove(uid);
        } else {
          newSpeakingUsers.add(uid);
        }
        
        state = state.copyWith(
          voiceState: state.voiceState.copyWith(speakingUsers: newSpeakingUsers),
        );
        logger.debug('User $uid ${muted ? 'muted' : 'unmuted'}');
      };
      
      _agoraService.onJoinChannel = (joined) {
        state = state.copyWith(
          voiceState: state.voiceState.copyWith(isConnecting: false),
        );
      };
      
      // Join the channel as audience initially (even if moderator)
      await _agoraService.joinChannel();
      
      // If user is moderator, automatically become speaker
      if (state.isCurrentUserModerator) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _agoraService.switchToSpeaker();
        state = state.copyWith(
          voiceState: state.voiceState.copyWith(isMuted: false),
        );
      }
      
    } catch (e) {
      state = state.copyWith(
        voiceState: state.voiceState.copyWith(isConnecting: false),
        error: 'Error connecting to voice room: $e',
      );
      logger.error('Error initializing Agora: $e');
    }
  }

  // Voice Chat Methods
  Future<void> toggleMute() async {
    if (_agoraService.isBroadcaster) {
      await _agoraService.muteLocalAudio(state.voiceState.isMuted);
      state = state.copyWith(
        voiceState: state.voiceState.copyWith(isMuted: !state.voiceState.isMuted),
      );
    }
  }

  Future<void> toggleSpeakerphone() async {
    await _agoraService.setEnableSpeakerphone(!state.voiceState.isSpeakerphoneEnabled);
    state = state.copyWith(
      voiceState: state.voiceState.copyWith(
        isSpeakerphoneEnabled: !state.voiceState.isSpeakerphoneEnabled,
      ),
    );
  }

  Future<void> toggleHandRaise() async {
    try {
      final newHandRaiseState = !state.voiceState.isHandRaised;
      
      // Update local state immediately for responsiveness
      state = state.copyWith(
        voiceState: state.voiceState.copyWith(isHandRaised: newHandRaiseState),
      );
      
      // Update participant metadata in the database
      await appwrite.updateParticipantMetadata(
        roomId: params.room.id,
        userId: state.currentUserId!,
        metadata: {'handRaised': newHandRaiseState},
      );
      
      logger.debug(newHandRaiseState 
        ? 'Hand raised by ${state.currentUserId}' 
        : 'Hand lowered by ${state.currentUserId}');
        
    } catch (e) {
      // Revert local state on error
      state = state.copyWith(
        voiceState: state.voiceState.copyWith(isHandRaised: !state.voiceState.isHandRaised),
        error: 'Failed to ${state.voiceState.isHandRaised ? 'lower' : 'raise'} hand',
      );
      logger.error('Error toggling hand raise: $e');
    }
  }

  // Timer Methods
  void startTimer([int? customSeconds]) {
    final duration = customSeconds ?? state.timerState.speakingTimeLimit;
    
    state = state.copyWith(
      timerState: state.timerState.copyWith(
        speakingTime: duration,
        isTimerRunning: true,
        isTimerPaused: false,
        thirtySecondChimePlayed: false,
      ),
    );
    
    _startTimerUpdater();
    logger.info('Started discussion timer: ${duration}s');
  }

  void pauseTimer() {
    state = state.copyWith(
      timerState: state.timerState.copyWith(
        isTimerRunning: false,
        isTimerPaused: true,
      ),
    );
    _stopTimerUpdater();
    logger.debug('Timer paused');
  }

  void resumeTimer() {
    state = state.copyWith(
      timerState: state.timerState.copyWith(
        isTimerRunning: true,
        isTimerPaused: false,
      ),
    );
    _startTimerUpdater();
    logger.debug('Timer resumed');
  }

  void resetTimer() {
    _stopTimerUpdater();
    state = state.copyWith(
      timerState: state.timerState.copyWith(
        speakingTime: state.timerState.speakingTimeLimit,
        isTimerRunning: false,
        isTimerPaused: false,
        thirtySecondChimePlayed: false,
      ),
    );
    logger.debug('Timer reset');
  }

  void setCustomTime(int totalSeconds) {
    state = state.copyWith(
      timerState: state.timerState.copyWith(
        speakingTime: totalSeconds,
        thirtySecondChimePlayed: false,
      ),
    );
    logger.debug('Custom time set: ${totalSeconds}s');
  }

  void _startTimerUpdater() {
    _stopTimerUpdater();
    
    _speakingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || state.isExiting || !state.timerState.isTimerRunning || state.timerState.isTimerPaused) {
        timer.cancel();
        return;
      }
      
      final newTime = state.timerState.speakingTime - 1;
      
      // Play 30-second warning
      if (newTime == 30 && !state.timerState.thirtySecondChimePlayed) {
        _playChimeSound();
        state = state.copyWith(
          timerState: state.timerState.copyWith(thirtySecondChimePlayed: true),
        );
      }
      
      if (newTime <= 0) {
        // Time's up
        timer.cancel();
        state = state.copyWith(
          timerState: state.timerState.copyWith(
            speakingTime: 0,
            isTimerRunning: false,
            isTimerPaused: true,
          ),
        );
        _playBuzzerSound();
        logger.info('Discussion timer finished');
      } else {
        state = state.copyWith(
          timerState: state.timerState.copyWith(speakingTime: newTime),
        );
      }
    });
  }

  void _stopTimerUpdater() {
    _speakingTimer?.cancel();
    _speakingTimer = null;
  }

  Future<void> _playChimeSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/chime.mp3'));
    } catch (e) {
      logger.warning('Failed to play chime sound: $e');
    }
  }

  Future<void> _playBuzzerSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/buzzer.mp3'));
    } catch (e) {
      logger.warning('Failed to play buzzer sound: $e');
    }
  }

  // Moderation Methods
  Future<void> promoteToSpeaker(String userId) async {
    try {
      await appwrite.updateParticipantRole(
        roomId: params.room.id,
        userId: userId,
        newRole: 'speaker',
      );
      
      // Clear hand raise via metadata when promoting to speaker
      await appwrite.updateParticipantMetadata(
        roomId: params.room.id,
        userId: userId,
        metadata: {'handRaised': false},
      );
      
      // If this is the current user being promoted, switch their Agora role
      if (userId == state.currentUserId) {
        await _agoraService.switchToSpeaker();
        state = state.copyWith(
          voiceState: state.voiceState.copyWith(
            isMuted: false,
            isHandRaised: false,
          ),
        );
      }
      
      // Reload participants to reflect changes
      await _loadRoomParticipants();
      
      logger.info('Promoted user $userId to speaker');
    } catch (e) {
      state = state.copyWith(error: 'Error promoting user: $e');
      logger.error('Error promoting user to speaker: $e');
    }
  }

  Future<void> demoteToAudience(String userId) async {
    try {
      await appwrite.updateParticipantRole(
        roomId: params.room.id,
        userId: userId,
        newRole: 'audience',
      );
      
      // If this is the current user being demoted, switch their Agora role
      if (userId == state.currentUserId) {
        await _agoraService.switchToAudience();
        state = state.copyWith(
          voiceState: state.voiceState.copyWith(isMuted: true),
        );
      }
      
      // Reload participants to reflect changes
      await _loadRoomParticipants();
      
      logger.info('Demoted user $userId to audience');
    } catch (e) {
      state = state.copyWith(error: 'Error demoting user: $e');
      logger.error('Error demoting user to audience: $e');
    }
  }

  Future<void> muteAllParticipants() async {
    try {
      if (!state.isCurrentUserModerator) {
        state = state.copyWith(error: 'Only moderators can mute all participants');
        return;
      }

      // Set mute signal in metadata for all non-moderator participants
      final muteAllTasks = <Future>[];
      for (final participant in state.participants) {
        // Don't mute moderators
        if (participant.role != DiscussionRole.moderator) {
          muteAllTasks.add(
            appwrite.updateParticipantMetadata(
              roomId: params.room.id,
              userId: participant.userId,
              metadata: {
                'muteRequested': true,
                'muteRequestedAt': DateTime.now().toIso8601String(),
                'muteRequestedBy': state.currentUserId,
              },
            ),
          );
        }
      }

      // Execute all mute requests in parallel
      await Future.wait(muteAllTasks);

      // Auto-mute current user if they're not a moderator
      if (!state.isCurrentUserModerator && !state.voiceState.isMuted) {
        await toggleMute();
      }

      logger.info('Moderator requested mute all participants');
    } catch (e) {
      state = state.copyWith(error: 'Failed to mute all participants: $e');
      logger.error('Error muting all participants: $e');
    }
  }

  Future<void> closeRoom() async {
    try {
      state = state.copyWith(isExiting: true);
      
      // Update room status to closed
      await appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'rooms',
        documentId: params.room.id,
        data: {
          'status': 'closed',
          'endedAt': DateTime.now().toIso8601String(),
        },
      );
      
      logger.info('Room closed: ${params.room.id}');
    } catch (e) {
      state = state.copyWith(error: 'Error closing room: $e');
      logger.error('Failed to close room: $e');
    }
  }

  Future<void> leaveRoom() async {
    try {
      state = state.copyWith(isExiting: true);
      
      if (state.currentUserId != null) {
        await appwrite.leaveRoom(
          roomId: params.room.id,
          userId: state.currentUserId!,
        );
      }
      
      await _agoraService.leaveChannel();
      logger.info('Left room: ${params.room.id}');
    } catch (e) {
      logger.error('Error leaving room: $e');
      // Continue with cleanup even if leaving fails
    }
  }

  // UI State Methods
  void toggleChat() {
    state = state.copyWith(isChatOpen: !state.isChatOpen);
  }

  void toggleModerationPanel() {
    state = state.copyWith(showModerationPanel: !state.showModerationPanel);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    logger.debug('Disposing discussion provider for room: ${params.room.id}');
    
    _realtimeSubscription?.cancel();
    _speakingTimer?.cancel();
    _fallbackRefreshTimer?.cancel();
    _audioPlayer.dispose();
    _agoraService.dispose();
    
    super.dispose();
  }
}