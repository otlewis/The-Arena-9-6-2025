import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../models/user_profile.dart';
import 'debate_phase.dart';
import 'participant_role.dart';

part 'arena_room_state.freezed.dart';

/// Represents the complete state of an arena debate room
@freezed
class ArenaRoomState with _$ArenaRoomState {
  const factory ArenaRoomState({
    // Room information
    required String roomId,
    required String challengeId,
    required String topic,
    String? description,
    String? category,
    @Default('active') String status,
    
    // Participants
    @Default({}) Map<String, UserProfile> participants,
    @Default([]) List<UserProfile> audience,
    
    // Current user
    UserProfile? currentUser,
    @Default(ParticipantRole.audience) ParticipantRole currentUserRole,
    
    // Debate state
    @Default(DebatePhase.preDebate) DebatePhase currentPhase,
    String? currentSpeaker,
    @Default(false) bool speakingEnabled,
    @Default(false) bool bothDebatersPresent,
    
    // Timer state
    @Default(0) int remainingSeconds,
    @Default(false) bool isTimerRunning,
    @Default(false) bool isTimerPaused,
    @Default(false) bool hasPlayed30SecWarning,
    
    // Judging state
    @Default(false) bool judgingEnabled,
    @Default(false) bool judgingComplete,
    @Default(false) bool hasCurrentUserSubmittedVote,
    String? winner,
    
    // Invitation state
    @Default(false) bool invitationsInProgress,
    @Default([]) List<String> affirmativeSelections,
    @Default([]) List<String> negativeSelections,
    @Default(false) bool affirmativeCompletedSelection,
    @Default(false) bool negativeCompletedSelection,
    @Default(false) bool invitationModalShown,
    @Default(false) bool waitingForOtherDebater,
    
    // UI state
    @Default(false) bool isLoading,
    @Default(false) bool resultsModalShown,
    @Default(false) bool roomClosingModalShown,
    @Default(false) bool hasNavigated,
    @Default(false) bool isExiting,
    
    // Error state
    String? error,
  }) = _ArenaRoomState;
  
  const ArenaRoomState._();
  
  /// Returns true if the current user is a moderator
  bool get isCurrentUserModerator => currentUserRole == ParticipantRole.moderator;
  
  /// Returns true if the current user is a debater
  bool get isCurrentUserDebater => currentUserRole.isDebater;
  
  /// Returns true if the current user is a judge
  bool get isCurrentUserJudge => currentUserRole.isJudge;
  
  /// Returns true if the current user can vote
  bool get canCurrentUserVote => currentUserRole.canVote && !hasCurrentUserSubmittedVote;
  
  /// Returns true if all required roles are filled
  bool get hasAllRequiredRoles {
    return participants.containsKey('affirmative') && 
           participants.containsKey('negative') && 
           participants.containsKey('moderator');
  }
  
  /// Returns true if the debate is ready to start
  bool get isReadyToStart {
    return hasAllRequiredRoles && 
           !isLoading && 
           currentPhase == DebatePhase.preDebate;
  }
  
  /// Returns true if the debate is in progress
  bool get isDebateInProgress {
    return currentPhase != DebatePhase.preDebate && 
           currentPhase != DebatePhase.judging && 
           !judgingComplete;
  }
  
  /// Returns true if the room can be closed
  bool get canCloseRoom {
    return isCurrentUserModerator && !isExiting;
  }
  
  /// Returns the formatted time string
  String get formattedTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Returns the number of audience members
  int get audienceCount => audience.length;
  
  /// Returns the number of participants (excluding audience)
  int get participantCount => participants.length;
  
  /// Returns all available judge slots
  List<String> get availableJudgeSlots {
    const maxJudges = 3;
    final availableSlots = <String>[];
    
    for (int i = 1; i <= maxJudges; i++) {
      final judgeRole = 'judge$i';
      if (!participants.containsKey(judgeRole)) {
        availableSlots.add(judgeRole);
      }
    }
    
    return availableSlots;
  }
  
  /// Returns true if a specific role is assigned
  bool hasRoleAssigned(String roleId) {
    return participants.containsKey(roleId);
  }
  
  /// Gets participant by role
  UserProfile? getParticipantByRole(String roleId) {
    return participants[roleId];
  }
  
  /// Gets the role of a specific user
  ParticipantRole? getUserRole(String userId) {
    // Check participants
    for (final entry in participants.entries) {
      if (entry.value.id == userId) {
        return ParticipantRole.fromId(entry.key);
      }
    }
    
    // Check if in audience
    if (audience.any((user) => user.id == userId)) {
      return ParticipantRole.audience;
    }
    
    return null;
  }
  
  /// Returns true if the timer should show warning colors
  bool get shouldShowTimerWarning => remainingSeconds <= 30 && remainingSeconds > 0;
  
  /// Returns true if time is up
  bool get isTimeUp => remainingSeconds <= 0 && isTimerRunning;
}