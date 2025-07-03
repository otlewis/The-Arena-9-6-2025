import 'package:freezed_annotation/freezed_annotation.dart';

part 'arena_state.freezed.dart';

/// Arena room states
enum ArenaStatus {
  waiting,
  debateSelection,
  starting,
  speaking,
  voting,
  completed,
  closed,
}

/// Debate phases - matching the original ArenaScreen enum
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

/// User roles in arena
enum ArenaRole {
  affirmative,
  negative,
  moderator,
  judge1,
  judge2,
  judge3,
  audience,
}

/// Arena participant model
@freezed
class ArenaParticipant with _$ArenaParticipant {
  const factory ArenaParticipant({
    required String userId,
    required String name,
    required ArenaRole role,
    String? avatar,
    @Default(false) bool isReady,
    @Default(false) bool isSpeaking,
    @Default(false) bool hasMicrophone,
    @Default(false) bool hasCamera,
    @Default(false) bool isMuted,
    DateTime? joinedAt,
    int? score,
  }) = _ArenaParticipant;
}

/// Arena room state
@freezed
class ArenaState with _$ArenaState {
  const factory ArenaState({
    required String roomId,
    required String topic,
    String? description,
    String? category,
    String? challengeId,
    String? challengerId,
    String? challengedId,
    @Default(ArenaStatus.waiting) ArenaStatus status,
    @Default(DebatePhase.preDebate) DebatePhase currentPhase,
    @Default({}) Map<String, ArenaParticipant> participants,
    @Default([]) List<ArenaParticipant> audience,
    String? currentSpeaker,
    @Default(0) int remainingSeconds,
    @Default(false) bool isTimerRunning,
    @Default(false) bool isPaused,
    @Default(false) bool hasPlayed30SecWarning,
    @Default(false) bool speakingEnabled,
    
    // Network and connection state
    @Default(true) bool isRealtimeHealthy,
    @Default(0) int reconnectAttempts,
    
    // Judging state
    @Default(false) bool judgingEnabled,
    @Default(false) bool judgingComplete,
    @Default(false) bool hasCurrentUserSubmittedVote,
    String? winner,
    
    // UI state
    @Default(false) bool bothDebatersPresent,
    @Default(false) bool invitationModalShown,
    @Default(false) bool invitationsInProgress,
    @Default({}) Map<String, String?> affirmativeSelections,
    @Default({}) Map<String, String?> negativeSelections,
    @Default(false) bool affirmativeCompletedSelection,
    @Default(false) bool negativeCompletedSelection,
    @Default(false) bool waitingForOtherDebater,
    @Default(false) bool resultsModalShown,
    @Default(false) bool roomClosingModalShown,
    @Default(false) bool hasNavigated,
    @Default(false) bool isExiting,
    
    // User context
    String? currentUserId,
    String? userRole,
    
    // Room management
    Map<String, dynamic>? roomData,
    DateTime? startTime,
    DateTime? endTime,
    @Default(false) bool isLoading,
    String? error,
  }) = _ArenaState;
  
  const ArenaState._();
  
  /// Get participants by role
  List<ArenaParticipant> getParticipantsByRole(ArenaRole role) {
    return participants.values.where((p) => p.role == role).toList();
  }
  
  /// Get participant by role (single participant roles)
  ArenaParticipant? getParticipantByRole(ArenaRole role) {
    return participants.values.where((p) => p.role == role).firstOrNull;
  }
  
  /// Get current user role
  ArenaRole? getUserRole(String userId) {
    return participants[userId]?.role;
  }
  
  /// Check if user can speak in current phase
  bool canUserSpeak(String userId) {
    final participant = participants[userId];
    if (participant == null) return false;
    
    // Get the required role for current phase
    final requiredRole = currentPhase.speakerRole;
    if (requiredRole.isEmpty) {
      return participant.role == ArenaRole.moderator;
    }
    
    return participant.role.name == requiredRole || 
           participant.role == ArenaRole.moderator;
  }
  
  /// Check if arena is ready to start
  bool get isReadyToStart {
    final affirmative = getParticipantByRole(ArenaRole.affirmative);
    final negative = getParticipantByRole(ArenaRole.negative);
    final moderator = getParticipantByRole(ArenaRole.moderator);
    
    return affirmative != null && 
           negative != null && 
           moderator != null &&
           affirmative.isReady &&
           negative.isReady &&
           moderator.isReady;
  }
  
  /// Get phase duration in seconds
  int getPhaseDurationSeconds(DebatePhase phase) {
    return phase.defaultDurationSeconds ?? 0;
  }
  
  /// Format remaining time as MM:SS
  String get formattedRemainingTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Check if both debaters are present
  bool get areBothDebatersPresent {
    final affirmative = getParticipantByRole(ArenaRole.affirmative);
    final negative = getParticipantByRole(ArenaRole.negative);
    return affirmative != null && negative != null;
  }
  
  /// Check if all judges have voted
  bool get allJudgesVoted {
    final judges = [
      getParticipantByRole(ArenaRole.judge1),
      getParticipantByRole(ArenaRole.judge2),
      getParticipantByRole(ArenaRole.judge3),
    ].where((j) => j != null).toList();
    
    return judges.isNotEmpty; // Simplified for now
  }
}