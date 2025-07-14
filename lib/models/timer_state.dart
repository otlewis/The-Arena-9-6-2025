import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'timer_state.freezed.dart';
part 'timer_state.g.dart';

enum RoomType {
  openDiscussion,
  debatesDiscussions,
  arena,
}

enum TimerStatus {
  stopped,
  running,
  paused,
  completed,
}

enum TimerType {
  general,
  openingStatement,
  rebuttal,
  closingStatement,
  questionRound,
  speakerTurn,
}

@freezed
class TimerState with _$TimerState {
  const factory TimerState({
    required String id,
    required String roomId,
    required RoomType roomType,
    required TimerType timerType,
    required TimerStatus status,
    required int durationSeconds,
    required int remainingSeconds,
    @TimestampConverter() DateTime? startTime,
    @TimestampConverter() DateTime? pausedAt,
    @TimestampConverter() DateTime? createdAt,
    required String createdBy,
    String? currentSpeaker,
    String? description,
    @Default(false) bool hasExpired,
    @Default(false) bool soundEnabled,
    @Default(false) bool vibrationEnabled,
    Map<String, dynamic>? metadata,
  }) = _TimerState;

  factory TimerState.fromJson(Map<String, dynamic> json) =>
      _$TimerStateFromJson(json);

  factory TimerState.initial({
    required String roomId,
    required RoomType roomType,
    required TimerType timerType,
    required int durationSeconds,
    required String createdBy,
    String? description,
    String? currentSpeaker,
  }) {
    return TimerState(
      id: '',
      roomId: roomId,
      roomType: roomType,
      timerType: timerType,
      status: TimerStatus.stopped,
      durationSeconds: durationSeconds,
      remainingSeconds: durationSeconds,
      createdBy: createdBy,
      description: description,
      currentSpeaker: currentSpeaker,
      soundEnabled: true,
      vibrationEnabled: true,
    );
  }
}

@freezed
class TimerConfiguration with _$TimerConfiguration {
  const factory TimerConfiguration({
    required TimerType type,
    required String label,
    required String description,
    required int defaultDurationSeconds,
    required int minDurationSeconds,
    required int maxDurationSeconds,
    required List<int> presetDurations,
    @Default(10) int warningThresholdSeconds,
    @Default(true) bool allowPause,
    @Default(true) bool allowAddTime,
    @Default(true) bool showProgress,
    @Default('#2196F3') String primaryColor,
    @Default('#FF5722') String warningColor,
    @Default('#F44336') String expiredColor,
  }) = _TimerConfiguration;

  factory TimerConfiguration.fromJson(Map<String, dynamic> json) =>
      _$TimerConfigurationFromJson(json);
}

@freezed
class RoomTimerPreset with _$RoomTimerPreset {
  const factory RoomTimerPreset({
    required RoomType roomType,
    required String name,
    required String description,
    required List<TimerConfiguration> timers,
    @Default(1) int maxConcurrentTimers,
    @Default(true) bool moderatorOnly,
  }) = _RoomTimerPreset;

  factory RoomTimerPreset.fromJson(Map<String, dynamic> json) =>
      _$RoomTimerPresetFromJson(json);
}

@freezed
class TimerEvent with _$TimerEvent {
  const factory TimerEvent({
    required String timerId,
    required String action,
    @TimestampConverter() required DateTime timestamp,
    required String userId,
    String? details,
    Map<String, dynamic>? metadata,
  }) = _TimerEvent;

  factory TimerEvent.fromJson(Map<String, dynamic> json) =>
      _$TimerEventFromJson(json);
}

class TimestampConverter implements JsonConverter<DateTime?, Object?> {
  const TimestampConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) return null;
    if (json is Timestamp) return json.toDate();
    if (json is String) return DateTime.parse(json);
    if (json is int) return DateTime.fromMillisecondsSinceEpoch(json);
    return null;
  }

  @override
  Object? toJson(DateTime? object) {
    return object?.toIso8601String();
  }
}

extension TimerStateX on TimerState {
  bool get isActive => status == TimerStatus.running;
  bool get isPaused => status == TimerStatus.paused;
  bool get isStopped => status == TimerStatus.stopped;
  bool get isCompleted => status == TimerStatus.completed;
  
  bool get isNearExpiry => 
      remainingSeconds <= 30 && remainingSeconds > 0 && isActive;
  
  bool get isInWarningZone =>
      remainingSeconds <= 10 && remainingSeconds > 0 && isActive;
  
  double get progress {
    if (durationSeconds == 0) return 0.0;
    return (durationSeconds - remainingSeconds) / durationSeconds;
  }
  
  String get formattedTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  String get statusText {
    switch (status) {
      case TimerStatus.stopped:
        return 'Ready';
      case TimerStatus.running:
        return 'Running';
      case TimerStatus.paused:
        return 'Paused';
      case TimerStatus.completed:
        return 'Completed';
    }
  }
}