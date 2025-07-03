import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../models/models.dart';

part 'discussion_state.freezed.dart';

/// Participant in a discussion room
@freezed
class DiscussionParticipant with _$DiscussionParticipant {
  const factory DiscussionParticipant({
    required String userId,
    required String name,
    required DiscussionRole role,
    String? avatar,
    @Default(false) bool isHandRaised,
    @Default(false) bool isSpeaking,
    @Default(false) bool isMuted,
    @Default({}) Map<String, dynamic> metadata,
  }) = _DiscussionParticipant;
}

/// Discussion room roles
enum DiscussionRole {
  moderator,
  speaker,
  audience,
}

extension DiscussionRoleExtension on DiscussionRole {
  String get displayName {
    switch (this) {
      case DiscussionRole.moderator:
        return 'Moderator';
      case DiscussionRole.speaker:
        return 'Speaker';
      case DiscussionRole.audience:
        return 'Audience';
    }
  }

  bool get canSpeak {
    switch (this) {
      case DiscussionRole.moderator:
      case DiscussionRole.speaker:
        return true;
      case DiscussionRole.audience:
        return false;
    }
  }

  bool get canModerate {
    return this == DiscussionRole.moderator;
  }
}

/// Voice chat state
@freezed
class VoiceState with _$VoiceState {
  const factory VoiceState({
    @Default(true) bool isMuted,
    @Default(false) bool isHandRaised,
    @Default(false) bool isConnecting,
    @Default(true) bool isSpeakerphoneEnabled,
    @Default({}) Set<int> remoteUsers,
    @Default({}) Set<int> speakingUsers,
    @Default({}) Set<String> handsRaised,
  }) = _VoiceState;
}

/// Timer state for speaking time management
@freezed
class TimerState with _$TimerState {
  const factory TimerState({
    @Default(300) int speakingTime, // countdown in seconds
    @Default(300) int speakingTimeLimit, // default 5 minutes
    @Default(false) bool isTimerRunning,
    @Default(false) bool isTimerPaused,
    @Default(false) bool thirtySecondChimePlayed,
  }) = _TimerState;
}

/// Network connection health state
@freezed
class NetworkState with _$NetworkState {
  const factory NetworkState({
    @Default(true) bool isRealtimeHealthy,
    @Default(0) int reconnectAttempts,
    @Default(5) int maxReconnectAttempts,
  }) = _NetworkState;
}

/// Main discussion room state
@freezed
class DiscussionState with _$DiscussionState {
  const factory DiscussionState({
    required String roomId,
    required Room room,
    
    // Current user state
    String? currentUserId,
    String? userRole,
    @Default(100) int coinBalance,
    
    // Room data
    @Default([]) List<DiscussionParticipant> participants,
    @Default({}) Map<String, UserProfile> userProfiles,
    Map<String, dynamic>? userParticipation,
    
    // Voice state
    @Default(VoiceState()) VoiceState voiceState,
    
    // Timer state
    @Default(TimerState()) TimerState timerState,
    
    // Network state
    @Default(NetworkState()) NetworkState networkState,
    
    // UI state
    @Default(false) bool isChatOpen,
    @Default(false) bool showModerationPanel,
    @Default(false) bool isLoading,
    @Default(false) bool isExiting,
    String? error,
  }) = _DiscussionState;
}

/// Helper getters for DiscussionState
extension DiscussionStateExtensions on DiscussionState {
  
  /// Get participants by role
  List<DiscussionParticipant> getParticipantsByRole(DiscussionRole role) {
    return participants.where((p) => p.role == role).toList();
  }
  
  /// Get moderators
  List<DiscussionParticipant> get moderators => getParticipantsByRole(DiscussionRole.moderator);
  
  /// Get speakers
  List<DiscussionParticipant> get speakers => getParticipantsByRole(DiscussionRole.speaker);
  
  /// Get audience members
  List<DiscussionParticipant> get audience => getParticipantsByRole(DiscussionRole.audience);
  
  /// Check if current user is moderator
  bool get isCurrentUserModerator {
    return currentUserId != null && 
           participants.any((p) => p.userId == currentUserId && p.role == DiscussionRole.moderator);
  }
  
  /// Check if current user is speaker
  bool get isCurrentUserSpeaker {
    return currentUserId != null && 
           participants.any((p) => p.userId == currentUserId && p.role == DiscussionRole.speaker);
  }
  
  /// Get current user participant data
  DiscussionParticipant? get currentUserParticipant {
    if (currentUserId == null) return null;
    try {
      return participants.firstWhere((p) => p.userId == currentUserId);
    } catch (e) {
      return null;
    }
  }
  
  /// Get participants with hands raised
  List<DiscussionParticipant> get participantsWithHandsRaised {
    return participants.where((p) => p.isHandRaised).toList();
  }
  
  /// Format remaining time as MM:SS
  String get formattedRemainingTime {
    final minutes = timerState.speakingTime ~/ 60;
    final seconds = timerState.speakingTime % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Check if timer is low (under 30 seconds)
  bool get isTimerLow => timerState.speakingTime <= 30;
}