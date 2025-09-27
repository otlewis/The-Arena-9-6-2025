import 'dart:async';
import '../core/logging/app_logger.dart';
import '../models/user_profile.dart';

/// Manages granular state updates to minimize UI rebuilds
/// Allows components to subscribe to specific data changes
class GranularStateManager {
  final AppLogger _logger = AppLogger();

  // Specialized stream controllers for different UI sections
  final StreamController<ParticipantUpdate> _participantUpdates = StreamController.broadcast();
  final StreamController<ChatUpdate> _chatUpdates = StreamController.broadcast();
  final StreamController<RoomStatusUpdate> _roomStatusUpdates = StreamController.broadcast();
  final StreamController<TimerUpdate> _timerUpdates = StreamController.broadcast();
  final StreamController<HandRaiseUpdate> _handRaiseUpdates = StreamController.broadcast();

  // Streams for subscribers
  Stream<ParticipantUpdate> get participantUpdates => _participantUpdates.stream;
  Stream<ChatUpdate> get chatUpdates => _chatUpdates.stream;
  Stream<RoomStatusUpdate> get roomStatusUpdates => _roomStatusUpdates.stream;
  Stream<TimerUpdate> get timerUpdates => _timerUpdates.stream;
  Stream<HandRaiseUpdate> get handRaiseUpdates => _handRaiseUpdates.stream;

  // Current state cache to avoid unnecessary updates
  final Map<String, ParticipantState> _participantStates = {};
  final Map<String, ChatState> _chatStates = {};
  final Map<String, RoomState> _roomStates = {};

  /// Update specific participant data
  void updateParticipant({
    required String roomId,
    required String userId,
    String? role,
    bool? isSpeaking,
    bool? isMuted,
    UserProfile? profile,
    ParticipantUpdateType type = ParticipantUpdateType.modified,
  }) {
    final key = '${roomId}_$userId';
    final currentState = _participantStates[key];

    // Create new state
    final newState = ParticipantState(
      userId: userId,
      role: role ?? currentState?.role,
      isSpeaking: isSpeaking ?? currentState?.isSpeaking ?? false,
      isMuted: isMuted ?? currentState?.isMuted ?? false,
      profile: profile ?? currentState?.profile,
      lastUpdate: DateTime.now(),
    );

    // Only emit if state actually changed
    if (currentState == null || !currentState.isEqual(newState)) {
      _participantStates[key] = newState;

      final update = ParticipantUpdate(
        roomId: roomId,
        userId: userId,
        type: type,
        state: newState,
        previousState: currentState,
      );

      _participantUpdates.add(update);
      _logger.debug('🔄 Granular participant update: $userId ($type)');
    }
  }

  /// Update chat message state
  void updateChat({
    required String roomId,
    required String messageId,
    required String content,
    required String senderId,
    required String senderName,
    required DateTime timestamp,
    ChatUpdateType type = ChatUpdateType.newMessage,
  }) {
    final key = '${roomId}_$messageId';

    final newState = ChatState(
      messageId: messageId,
      content: content,
      senderId: senderId,
      senderName: senderName,
      timestamp: timestamp,
      lastUpdate: DateTime.now(),
    );

    _chatStates[key] = newState;

    final update = ChatUpdate(
      roomId: roomId,
      messageId: messageId,
      type: type,
      state: newState,
    );

    _chatUpdates.add(update);
    _logger.debug('🔄 Granular chat update: $messageId ($type)');
  }

  /// Update room status
  void updateRoomStatus({
    required String roomId,
    String? status,
    int? participantCount,
    bool? isRecording,
    String? currentTopic,
    RoomStatusUpdateType type = RoomStatusUpdateType.statusChange,
  }) {
    final currentState = _roomStates[roomId];

    final newState = RoomState(
      roomId: roomId,
      status: status ?? currentState?.status,
      participantCount: participantCount ?? currentState?.participantCount ?? 0,
      isRecording: isRecording ?? currentState?.isRecording ?? false,
      currentTopic: currentTopic ?? currentState?.currentTopic,
      lastUpdate: DateTime.now(),
    );

    if (currentState == null || !currentState.isEqual(newState)) {
      _roomStates[roomId] = newState;

      final update = RoomStatusUpdate(
        roomId: roomId,
        type: type,
        state: newState,
        previousState: currentState,
      );

      _roomStatusUpdates.add(update);
      _logger.debug('🔄 Granular room status update: $roomId ($type)');
    }
  }

  /// Update timer state
  void updateTimer({
    required String roomId,
    required int timeRemaining,
    required bool isRunning,
    String? phase,
  }) {
    final update = TimerUpdate(
      roomId: roomId,
      timeRemaining: timeRemaining,
      isRunning: isRunning,
      phase: phase,
      timestamp: DateTime.now(),
    );

    _timerUpdates.add(update);
    _logger.debug('🔄 Granular timer update: $roomId (${timeRemaining}s, running: $isRunning)');
  }

  /// Update hand raise state
  void updateHandRaise({
    required String roomId,
    required String userId,
    required bool isRaised,
    DateTime? timestamp,
  }) {
    final update = HandRaiseUpdate(
      roomId: roomId,
      userId: userId,
      isRaised: isRaised,
      timestamp: timestamp ?? DateTime.now(),
    );

    _handRaiseUpdates.add(update);
    _logger.debug('🔄 Granular hand raise update: $userId (raised: $isRaised)');
  }

  /// Remove participant from tracking
  void removeParticipant(String roomId, String userId) {
    final key = '${roomId}_$userId';
    final currentState = _participantStates.remove(key);

    if (currentState != null) {
      updateParticipant(
        roomId: roomId,
        userId: userId,
        type: ParticipantUpdateType.removed,
      );
    }
  }

  /// Clear all state for a room
  void clearRoom(String roomId) {
    // Remove participant states
    _participantStates.removeWhere((key, _) => key.startsWith('${roomId}_'));

    // Remove chat states
    _chatStates.removeWhere((key, _) => key.startsWith('${roomId}_'));

    // Remove room state
    _roomStates.remove(roomId);

    _logger.info('🧹 Cleared granular state for room: $roomId');
  }

  /// Get current participant state
  ParticipantState? getParticipantState(String roomId, String userId) {
    return _participantStates['${roomId}_$userId'];
  }

  /// Get current room state
  RoomState? getRoomState(String roomId) {
    return _roomStates[roomId];
  }

  /// Dispose and clean up
  void dispose() {
    _participantUpdates.close();
    _chatUpdates.close();
    _roomStatusUpdates.close();
    _timerUpdates.close();
    _handRaiseUpdates.close();

    _participantStates.clear();
    _chatStates.clear();
    _roomStates.clear();

    _logger.info('🧹 Granular state manager disposed');
  }
}

// Data classes for state management

class ParticipantState {
  final String userId;
  final String? role;
  final bool isSpeaking;
  final bool isMuted;
  final UserProfile? profile;
  final DateTime lastUpdate;

  ParticipantState({
    required this.userId,
    this.role,
    required this.isSpeaking,
    required this.isMuted,
    this.profile,
    required this.lastUpdate,
  });

  bool isEqual(ParticipantState other) {
    return userId == other.userId &&
           role == other.role &&
           isSpeaking == other.isSpeaking &&
           isMuted == other.isMuted &&
           profile?.id == other.profile?.id;
  }
}

class ChatState {
  final String messageId;
  final String content;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final DateTime lastUpdate;

  ChatState({
    required this.messageId,
    required this.content,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    required this.lastUpdate,
  });
}

class RoomState {
  final String roomId;
  final String? status;
  final int participantCount;
  final bool isRecording;
  final String? currentTopic;
  final DateTime lastUpdate;

  RoomState({
    required this.roomId,
    this.status,
    required this.participantCount,
    required this.isRecording,
    this.currentTopic,
    required this.lastUpdate,
  });

  bool isEqual(RoomState other) {
    return roomId == other.roomId &&
           status == other.status &&
           participantCount == other.participantCount &&
           isRecording == other.isRecording &&
           currentTopic == other.currentTopic;
  }
}

// Update classes

enum ParticipantUpdateType { added, removed, modified, roleChanged, speakingChanged }
enum ChatUpdateType { newMessage, messageEdited, messageDeleted }
enum RoomStatusUpdateType { statusChange, participantCountChange, recordingChange, topicChange }

class ParticipantUpdate {
  final String roomId;
  final String userId;
  final ParticipantUpdateType type;
  final ParticipantState state;
  final ParticipantState? previousState;

  ParticipantUpdate({
    required this.roomId,
    required this.userId,
    required this.type,
    required this.state,
    this.previousState,
  });
}

class ChatUpdate {
  final String roomId;
  final String messageId;
  final ChatUpdateType type;
  final ChatState state;

  ChatUpdate({
    required this.roomId,
    required this.messageId,
    required this.type,
    required this.state,
  });
}

class RoomStatusUpdate {
  final String roomId;
  final RoomStatusUpdateType type;
  final RoomState state;
  final RoomState? previousState;

  RoomStatusUpdate({
    required this.roomId,
    required this.type,
    required this.state,
    this.previousState,
  });
}

class TimerUpdate {
  final String roomId;
  final int timeRemaining;
  final bool isRunning;
  final String? phase;
  final DateTime timestamp;

  TimerUpdate({
    required this.roomId,
    required this.timeRemaining,
    required this.isRunning,
    this.phase,
    required this.timestamp,
  });
}

class HandRaiseUpdate {
  final String roomId;
  final String userId;
  final bool isRaised;
  final DateTime timestamp;

  HandRaiseUpdate({
    required this.roomId,
    required this.userId,
    required this.isRaised,
    required this.timestamp,
  });
}