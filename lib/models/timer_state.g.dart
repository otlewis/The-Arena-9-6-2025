// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timer_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TimerStateImpl _$$TimerStateImplFromJson(Map<String, dynamic> json) =>
    _$TimerStateImpl(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      roomType: $enumDecode(_$RoomTypeEnumMap, json['roomType']),
      timerType: $enumDecode(_$TimerTypeEnumMap, json['timerType']),
      status: $enumDecode(_$TimerStatusEnumMap, json['status']),
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      remainingSeconds: (json['remainingSeconds'] as num).toInt(),
      startTime: const TimestampConverter().fromJson(json['startTime']),
      pausedAt: const TimestampConverter().fromJson(json['pausedAt']),
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      createdBy: json['createdBy'] as String,
      currentSpeaker: json['currentSpeaker'] as String?,
      description: json['description'] as String?,
      hasExpired: json['hasExpired'] as bool? ?? false,
      soundEnabled: json['soundEnabled'] as bool? ?? false,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$TimerStateImplToJson(_$TimerStateImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'roomId': instance.roomId,
      'roomType': _$RoomTypeEnumMap[instance.roomType]!,
      'timerType': _$TimerTypeEnumMap[instance.timerType]!,
      'status': _$TimerStatusEnumMap[instance.status]!,
      'durationSeconds': instance.durationSeconds,
      'remainingSeconds': instance.remainingSeconds,
      'startTime': const TimestampConverter().toJson(instance.startTime),
      'pausedAt': const TimestampConverter().toJson(instance.pausedAt),
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'createdBy': instance.createdBy,
      'currentSpeaker': instance.currentSpeaker,
      'description': instance.description,
      'hasExpired': instance.hasExpired,
      'soundEnabled': instance.soundEnabled,
      'vibrationEnabled': instance.vibrationEnabled,
      'metadata': instance.metadata,
    };

const _$RoomTypeEnumMap = {
  RoomType.openDiscussion: 'openDiscussion',
  RoomType.debatesDiscussions: 'debatesDiscussions',
  RoomType.arena: 'arena',
};

const _$TimerTypeEnumMap = {
  TimerType.general: 'general',
  TimerType.openingStatement: 'openingStatement',
  TimerType.rebuttal: 'rebuttal',
  TimerType.closingStatement: 'closingStatement',
  TimerType.questionRound: 'questionRound',
  TimerType.speakerTurn: 'speakerTurn',
};

const _$TimerStatusEnumMap = {
  TimerStatus.stopped: 'stopped',
  TimerStatus.running: 'running',
  TimerStatus.paused: 'paused',
  TimerStatus.completed: 'completed',
};

_$TimerConfigurationImpl _$$TimerConfigurationImplFromJson(
        Map<String, dynamic> json) =>
    _$TimerConfigurationImpl(
      type: $enumDecode(_$TimerTypeEnumMap, json['type']),
      label: json['label'] as String,
      description: json['description'] as String,
      defaultDurationSeconds: (json['defaultDurationSeconds'] as num).toInt(),
      minDurationSeconds: (json['minDurationSeconds'] as num).toInt(),
      maxDurationSeconds: (json['maxDurationSeconds'] as num).toInt(),
      presetDurations: (json['presetDurations'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      warningThresholdSeconds:
          (json['warningThresholdSeconds'] as num?)?.toInt() ?? 10,
      allowPause: json['allowPause'] as bool? ?? true,
      allowAddTime: json['allowAddTime'] as bool? ?? true,
      showProgress: json['showProgress'] as bool? ?? true,
      primaryColor: json['primaryColor'] as String? ?? '#2196F3',
      warningColor: json['warningColor'] as String? ?? '#FF5722',
      expiredColor: json['expiredColor'] as String? ?? '#F44336',
    );

Map<String, dynamic> _$$TimerConfigurationImplToJson(
        _$TimerConfigurationImpl instance) =>
    <String, dynamic>{
      'type': _$TimerTypeEnumMap[instance.type]!,
      'label': instance.label,
      'description': instance.description,
      'defaultDurationSeconds': instance.defaultDurationSeconds,
      'minDurationSeconds': instance.minDurationSeconds,
      'maxDurationSeconds': instance.maxDurationSeconds,
      'presetDurations': instance.presetDurations,
      'warningThresholdSeconds': instance.warningThresholdSeconds,
      'allowPause': instance.allowPause,
      'allowAddTime': instance.allowAddTime,
      'showProgress': instance.showProgress,
      'primaryColor': instance.primaryColor,
      'warningColor': instance.warningColor,
      'expiredColor': instance.expiredColor,
    };

_$RoomTimerPresetImpl _$$RoomTimerPresetImplFromJson(
        Map<String, dynamic> json) =>
    _$RoomTimerPresetImpl(
      roomType: $enumDecode(_$RoomTypeEnumMap, json['roomType']),
      name: json['name'] as String,
      description: json['description'] as String,
      timers: (json['timers'] as List<dynamic>)
          .map((e) => TimerConfiguration.fromJson(e as Map<String, dynamic>))
          .toList(),
      maxConcurrentTimers: (json['maxConcurrentTimers'] as num?)?.toInt() ?? 1,
      moderatorOnly: json['moderatorOnly'] as bool? ?? true,
    );

Map<String, dynamic> _$$RoomTimerPresetImplToJson(
        _$RoomTimerPresetImpl instance) =>
    <String, dynamic>{
      'roomType': _$RoomTypeEnumMap[instance.roomType]!,
      'name': instance.name,
      'description': instance.description,
      'timers': instance.timers,
      'maxConcurrentTimers': instance.maxConcurrentTimers,
      'moderatorOnly': instance.moderatorOnly,
    };

_$TimerEventImpl _$$TimerEventImplFromJson(Map<String, dynamic> json) =>
    _$TimerEventImpl(
      timerId: json['timerId'] as String,
      action: json['action'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String,
      details: json['details'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$TimerEventImplToJson(_$TimerEventImpl instance) =>
    <String, dynamic>{
      'timerId': instance.timerId,
      'action': instance.action,
      'timestamp': instance.timestamp.toIso8601String(),
      'userId': instance.userId,
      'details': instance.details,
      'metadata': instance.metadata,
    };
