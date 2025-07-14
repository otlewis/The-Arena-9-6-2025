// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'timer_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TimerState _$TimerStateFromJson(Map<String, dynamic> json) {
  return _TimerState.fromJson(json);
}

/// @nodoc
mixin _$TimerState {
  String get id => throw _privateConstructorUsedError;
  String get roomId => throw _privateConstructorUsedError;
  RoomType get roomType => throw _privateConstructorUsedError;
  TimerType get timerType => throw _privateConstructorUsedError;
  TimerStatus get status => throw _privateConstructorUsedError;
  int get durationSeconds => throw _privateConstructorUsedError;
  int get remainingSeconds => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get startTime => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get pausedAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get createdAt => throw _privateConstructorUsedError;
  String get createdBy => throw _privateConstructorUsedError;
  String? get currentSpeaker => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  bool get hasExpired => throw _privateConstructorUsedError;
  bool get soundEnabled => throw _privateConstructorUsedError;
  bool get vibrationEnabled => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  /// Serializes this TimerState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TimerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TimerStateCopyWith<TimerState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TimerStateCopyWith<$Res> {
  factory $TimerStateCopyWith(
          TimerState value, $Res Function(TimerState) then) =
      _$TimerStateCopyWithImpl<$Res, TimerState>;
  @useResult
  $Res call(
      {String id,
      String roomId,
      RoomType roomType,
      TimerType timerType,
      TimerStatus status,
      int durationSeconds,
      int remainingSeconds,
      @TimestampConverter() DateTime? startTime,
      @TimestampConverter() DateTime? pausedAt,
      @TimestampConverter() DateTime? createdAt,
      String createdBy,
      String? currentSpeaker,
      String? description,
      bool hasExpired,
      bool soundEnabled,
      bool vibrationEnabled,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class _$TimerStateCopyWithImpl<$Res, $Val extends TimerState>
    implements $TimerStateCopyWith<$Res> {
  _$TimerStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TimerState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? roomId = null,
    Object? roomType = null,
    Object? timerType = null,
    Object? status = null,
    Object? durationSeconds = null,
    Object? remainingSeconds = null,
    Object? startTime = freezed,
    Object? pausedAt = freezed,
    Object? createdAt = freezed,
    Object? createdBy = null,
    Object? currentSpeaker = freezed,
    Object? description = freezed,
    Object? hasExpired = null,
    Object? soundEnabled = null,
    Object? vibrationEnabled = null,
    Object? metadata = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      roomType: null == roomType
          ? _value.roomType
          : roomType // ignore: cast_nullable_to_non_nullable
              as RoomType,
      timerType: null == timerType
          ? _value.timerType
          : timerType // ignore: cast_nullable_to_non_nullable
              as TimerType,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TimerStatus,
      durationSeconds: null == durationSeconds
          ? _value.durationSeconds
          : durationSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      remainingSeconds: null == remainingSeconds
          ? _value.remainingSeconds
          : remainingSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      startTime: freezed == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      pausedAt: freezed == pausedAt
          ? _value.pausedAt
          : pausedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdBy: null == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String,
      currentSpeaker: freezed == currentSpeaker
          ? _value.currentSpeaker
          : currentSpeaker // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      hasExpired: null == hasExpired
          ? _value.hasExpired
          : hasExpired // ignore: cast_nullable_to_non_nullable
              as bool,
      soundEnabled: null == soundEnabled
          ? _value.soundEnabled
          : soundEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      vibrationEnabled: null == vibrationEnabled
          ? _value.vibrationEnabled
          : vibrationEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TimerStateImplCopyWith<$Res>
    implements $TimerStateCopyWith<$Res> {
  factory _$$TimerStateImplCopyWith(
          _$TimerStateImpl value, $Res Function(_$TimerStateImpl) then) =
      __$$TimerStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String roomId,
      RoomType roomType,
      TimerType timerType,
      TimerStatus status,
      int durationSeconds,
      int remainingSeconds,
      @TimestampConverter() DateTime? startTime,
      @TimestampConverter() DateTime? pausedAt,
      @TimestampConverter() DateTime? createdAt,
      String createdBy,
      String? currentSpeaker,
      String? description,
      bool hasExpired,
      bool soundEnabled,
      bool vibrationEnabled,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class __$$TimerStateImplCopyWithImpl<$Res>
    extends _$TimerStateCopyWithImpl<$Res, _$TimerStateImpl>
    implements _$$TimerStateImplCopyWith<$Res> {
  __$$TimerStateImplCopyWithImpl(
      _$TimerStateImpl _value, $Res Function(_$TimerStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of TimerState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? roomId = null,
    Object? roomType = null,
    Object? timerType = null,
    Object? status = null,
    Object? durationSeconds = null,
    Object? remainingSeconds = null,
    Object? startTime = freezed,
    Object? pausedAt = freezed,
    Object? createdAt = freezed,
    Object? createdBy = null,
    Object? currentSpeaker = freezed,
    Object? description = freezed,
    Object? hasExpired = null,
    Object? soundEnabled = null,
    Object? vibrationEnabled = null,
    Object? metadata = freezed,
  }) {
    return _then(_$TimerStateImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      roomType: null == roomType
          ? _value.roomType
          : roomType // ignore: cast_nullable_to_non_nullable
              as RoomType,
      timerType: null == timerType
          ? _value.timerType
          : timerType // ignore: cast_nullable_to_non_nullable
              as TimerType,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TimerStatus,
      durationSeconds: null == durationSeconds
          ? _value.durationSeconds
          : durationSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      remainingSeconds: null == remainingSeconds
          ? _value.remainingSeconds
          : remainingSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      startTime: freezed == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      pausedAt: freezed == pausedAt
          ? _value.pausedAt
          : pausedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdBy: null == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String,
      currentSpeaker: freezed == currentSpeaker
          ? _value.currentSpeaker
          : currentSpeaker // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      hasExpired: null == hasExpired
          ? _value.hasExpired
          : hasExpired // ignore: cast_nullable_to_non_nullable
              as bool,
      soundEnabled: null == soundEnabled
          ? _value.soundEnabled
          : soundEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      vibrationEnabled: null == vibrationEnabled
          ? _value.vibrationEnabled
          : vibrationEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TimerStateImpl implements _TimerState {
  const _$TimerStateImpl(
      {required this.id,
      required this.roomId,
      required this.roomType,
      required this.timerType,
      required this.status,
      required this.durationSeconds,
      required this.remainingSeconds,
      @TimestampConverter() this.startTime,
      @TimestampConverter() this.pausedAt,
      @TimestampConverter() this.createdAt,
      required this.createdBy,
      this.currentSpeaker,
      this.description,
      this.hasExpired = false,
      this.soundEnabled = false,
      this.vibrationEnabled = false,
      final Map<String, dynamic>? metadata})
      : _metadata = metadata;

  factory _$TimerStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$TimerStateImplFromJson(json);

  @override
  final String id;
  @override
  final String roomId;
  @override
  final RoomType roomType;
  @override
  final TimerType timerType;
  @override
  final TimerStatus status;
  @override
  final int durationSeconds;
  @override
  final int remainingSeconds;
  @override
  @TimestampConverter()
  final DateTime? startTime;
  @override
  @TimestampConverter()
  final DateTime? pausedAt;
  @override
  @TimestampConverter()
  final DateTime? createdAt;
  @override
  final String createdBy;
  @override
  final String? currentSpeaker;
  @override
  final String? description;
  @override
  @JsonKey()
  final bool hasExpired;
  @override
  @JsonKey()
  final bool soundEnabled;
  @override
  @JsonKey()
  final bool vibrationEnabled;
  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'TimerState(id: $id, roomId: $roomId, roomType: $roomType, timerType: $timerType, status: $status, durationSeconds: $durationSeconds, remainingSeconds: $remainingSeconds, startTime: $startTime, pausedAt: $pausedAt, createdAt: $createdAt, createdBy: $createdBy, currentSpeaker: $currentSpeaker, description: $description, hasExpired: $hasExpired, soundEnabled: $soundEnabled, vibrationEnabled: $vibrationEnabled, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimerStateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.roomType, roomType) ||
                other.roomType == roomType) &&
            (identical(other.timerType, timerType) ||
                other.timerType == timerType) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.durationSeconds, durationSeconds) ||
                other.durationSeconds == durationSeconds) &&
            (identical(other.remainingSeconds, remainingSeconds) ||
                other.remainingSeconds == remainingSeconds) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.pausedAt, pausedAt) ||
                other.pausedAt == pausedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.currentSpeaker, currentSpeaker) ||
                other.currentSpeaker == currentSpeaker) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.hasExpired, hasExpired) ||
                other.hasExpired == hasExpired) &&
            (identical(other.soundEnabled, soundEnabled) ||
                other.soundEnabled == soundEnabled) &&
            (identical(other.vibrationEnabled, vibrationEnabled) ||
                other.vibrationEnabled == vibrationEnabled) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      roomId,
      roomType,
      timerType,
      status,
      durationSeconds,
      remainingSeconds,
      startTime,
      pausedAt,
      createdAt,
      createdBy,
      currentSpeaker,
      description,
      hasExpired,
      soundEnabled,
      vibrationEnabled,
      const DeepCollectionEquality().hash(_metadata));

  /// Create a copy of TimerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimerStateImplCopyWith<_$TimerStateImpl> get copyWith =>
      __$$TimerStateImplCopyWithImpl<_$TimerStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TimerStateImplToJson(
      this,
    );
  }
}

abstract class _TimerState implements TimerState {
  const factory _TimerState(
      {required final String id,
      required final String roomId,
      required final RoomType roomType,
      required final TimerType timerType,
      required final TimerStatus status,
      required final int durationSeconds,
      required final int remainingSeconds,
      @TimestampConverter() final DateTime? startTime,
      @TimestampConverter() final DateTime? pausedAt,
      @TimestampConverter() final DateTime? createdAt,
      required final String createdBy,
      final String? currentSpeaker,
      final String? description,
      final bool hasExpired,
      final bool soundEnabled,
      final bool vibrationEnabled,
      final Map<String, dynamic>? metadata}) = _$TimerStateImpl;

  factory _TimerState.fromJson(Map<String, dynamic> json) =
      _$TimerStateImpl.fromJson;

  @override
  String get id;
  @override
  String get roomId;
  @override
  RoomType get roomType;
  @override
  TimerType get timerType;
  @override
  TimerStatus get status;
  @override
  int get durationSeconds;
  @override
  int get remainingSeconds;
  @override
  @TimestampConverter()
  DateTime? get startTime;
  @override
  @TimestampConverter()
  DateTime? get pausedAt;
  @override
  @TimestampConverter()
  DateTime? get createdAt;
  @override
  String get createdBy;
  @override
  String? get currentSpeaker;
  @override
  String? get description;
  @override
  bool get hasExpired;
  @override
  bool get soundEnabled;
  @override
  bool get vibrationEnabled;
  @override
  Map<String, dynamic>? get metadata;

  /// Create a copy of TimerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimerStateImplCopyWith<_$TimerStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TimerConfiguration _$TimerConfigurationFromJson(Map<String, dynamic> json) {
  return _TimerConfiguration.fromJson(json);
}

/// @nodoc
mixin _$TimerConfiguration {
  TimerType get type => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  int get defaultDurationSeconds => throw _privateConstructorUsedError;
  int get minDurationSeconds => throw _privateConstructorUsedError;
  int get maxDurationSeconds => throw _privateConstructorUsedError;
  List<int> get presetDurations => throw _privateConstructorUsedError;
  int get warningThresholdSeconds => throw _privateConstructorUsedError;
  bool get allowPause => throw _privateConstructorUsedError;
  bool get allowAddTime => throw _privateConstructorUsedError;
  bool get showProgress => throw _privateConstructorUsedError;
  String get primaryColor => throw _privateConstructorUsedError;
  String get warningColor => throw _privateConstructorUsedError;
  String get expiredColor => throw _privateConstructorUsedError;

  /// Serializes this TimerConfiguration to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TimerConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TimerConfigurationCopyWith<TimerConfiguration> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TimerConfigurationCopyWith<$Res> {
  factory $TimerConfigurationCopyWith(
          TimerConfiguration value, $Res Function(TimerConfiguration) then) =
      _$TimerConfigurationCopyWithImpl<$Res, TimerConfiguration>;
  @useResult
  $Res call(
      {TimerType type,
      String label,
      String description,
      int defaultDurationSeconds,
      int minDurationSeconds,
      int maxDurationSeconds,
      List<int> presetDurations,
      int warningThresholdSeconds,
      bool allowPause,
      bool allowAddTime,
      bool showProgress,
      String primaryColor,
      String warningColor,
      String expiredColor});
}

/// @nodoc
class _$TimerConfigurationCopyWithImpl<$Res, $Val extends TimerConfiguration>
    implements $TimerConfigurationCopyWith<$Res> {
  _$TimerConfigurationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TimerConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? label = null,
    Object? description = null,
    Object? defaultDurationSeconds = null,
    Object? minDurationSeconds = null,
    Object? maxDurationSeconds = null,
    Object? presetDurations = null,
    Object? warningThresholdSeconds = null,
    Object? allowPause = null,
    Object? allowAddTime = null,
    Object? showProgress = null,
    Object? primaryColor = null,
    Object? warningColor = null,
    Object? expiredColor = null,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as TimerType,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      defaultDurationSeconds: null == defaultDurationSeconds
          ? _value.defaultDurationSeconds
          : defaultDurationSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      minDurationSeconds: null == minDurationSeconds
          ? _value.minDurationSeconds
          : minDurationSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      maxDurationSeconds: null == maxDurationSeconds
          ? _value.maxDurationSeconds
          : maxDurationSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      presetDurations: null == presetDurations
          ? _value.presetDurations
          : presetDurations // ignore: cast_nullable_to_non_nullable
              as List<int>,
      warningThresholdSeconds: null == warningThresholdSeconds
          ? _value.warningThresholdSeconds
          : warningThresholdSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      allowPause: null == allowPause
          ? _value.allowPause
          : allowPause // ignore: cast_nullable_to_non_nullable
              as bool,
      allowAddTime: null == allowAddTime
          ? _value.allowAddTime
          : allowAddTime // ignore: cast_nullable_to_non_nullable
              as bool,
      showProgress: null == showProgress
          ? _value.showProgress
          : showProgress // ignore: cast_nullable_to_non_nullable
              as bool,
      primaryColor: null == primaryColor
          ? _value.primaryColor
          : primaryColor // ignore: cast_nullable_to_non_nullable
              as String,
      warningColor: null == warningColor
          ? _value.warningColor
          : warningColor // ignore: cast_nullable_to_non_nullable
              as String,
      expiredColor: null == expiredColor
          ? _value.expiredColor
          : expiredColor // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TimerConfigurationImplCopyWith<$Res>
    implements $TimerConfigurationCopyWith<$Res> {
  factory _$$TimerConfigurationImplCopyWith(_$TimerConfigurationImpl value,
          $Res Function(_$TimerConfigurationImpl) then) =
      __$$TimerConfigurationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {TimerType type,
      String label,
      String description,
      int defaultDurationSeconds,
      int minDurationSeconds,
      int maxDurationSeconds,
      List<int> presetDurations,
      int warningThresholdSeconds,
      bool allowPause,
      bool allowAddTime,
      bool showProgress,
      String primaryColor,
      String warningColor,
      String expiredColor});
}

/// @nodoc
class __$$TimerConfigurationImplCopyWithImpl<$Res>
    extends _$TimerConfigurationCopyWithImpl<$Res, _$TimerConfigurationImpl>
    implements _$$TimerConfigurationImplCopyWith<$Res> {
  __$$TimerConfigurationImplCopyWithImpl(_$TimerConfigurationImpl _value,
      $Res Function(_$TimerConfigurationImpl) _then)
      : super(_value, _then);

  /// Create a copy of TimerConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? label = null,
    Object? description = null,
    Object? defaultDurationSeconds = null,
    Object? minDurationSeconds = null,
    Object? maxDurationSeconds = null,
    Object? presetDurations = null,
    Object? warningThresholdSeconds = null,
    Object? allowPause = null,
    Object? allowAddTime = null,
    Object? showProgress = null,
    Object? primaryColor = null,
    Object? warningColor = null,
    Object? expiredColor = null,
  }) {
    return _then(_$TimerConfigurationImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as TimerType,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      defaultDurationSeconds: null == defaultDurationSeconds
          ? _value.defaultDurationSeconds
          : defaultDurationSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      minDurationSeconds: null == minDurationSeconds
          ? _value.minDurationSeconds
          : minDurationSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      maxDurationSeconds: null == maxDurationSeconds
          ? _value.maxDurationSeconds
          : maxDurationSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      presetDurations: null == presetDurations
          ? _value._presetDurations
          : presetDurations // ignore: cast_nullable_to_non_nullable
              as List<int>,
      warningThresholdSeconds: null == warningThresholdSeconds
          ? _value.warningThresholdSeconds
          : warningThresholdSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      allowPause: null == allowPause
          ? _value.allowPause
          : allowPause // ignore: cast_nullable_to_non_nullable
              as bool,
      allowAddTime: null == allowAddTime
          ? _value.allowAddTime
          : allowAddTime // ignore: cast_nullable_to_non_nullable
              as bool,
      showProgress: null == showProgress
          ? _value.showProgress
          : showProgress // ignore: cast_nullable_to_non_nullable
              as bool,
      primaryColor: null == primaryColor
          ? _value.primaryColor
          : primaryColor // ignore: cast_nullable_to_non_nullable
              as String,
      warningColor: null == warningColor
          ? _value.warningColor
          : warningColor // ignore: cast_nullable_to_non_nullable
              as String,
      expiredColor: null == expiredColor
          ? _value.expiredColor
          : expiredColor // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TimerConfigurationImpl implements _TimerConfiguration {
  const _$TimerConfigurationImpl(
      {required this.type,
      required this.label,
      required this.description,
      required this.defaultDurationSeconds,
      required this.minDurationSeconds,
      required this.maxDurationSeconds,
      required final List<int> presetDurations,
      this.warningThresholdSeconds = 10,
      this.allowPause = true,
      this.allowAddTime = true,
      this.showProgress = true,
      this.primaryColor = '#2196F3',
      this.warningColor = '#FF5722',
      this.expiredColor = '#F44336'})
      : _presetDurations = presetDurations;

  factory _$TimerConfigurationImpl.fromJson(Map<String, dynamic> json) =>
      _$$TimerConfigurationImplFromJson(json);

  @override
  final TimerType type;
  @override
  final String label;
  @override
  final String description;
  @override
  final int defaultDurationSeconds;
  @override
  final int minDurationSeconds;
  @override
  final int maxDurationSeconds;
  final List<int> _presetDurations;
  @override
  List<int> get presetDurations {
    if (_presetDurations is EqualUnmodifiableListView) return _presetDurations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_presetDurations);
  }

  @override
  @JsonKey()
  final int warningThresholdSeconds;
  @override
  @JsonKey()
  final bool allowPause;
  @override
  @JsonKey()
  final bool allowAddTime;
  @override
  @JsonKey()
  final bool showProgress;
  @override
  @JsonKey()
  final String primaryColor;
  @override
  @JsonKey()
  final String warningColor;
  @override
  @JsonKey()
  final String expiredColor;

  @override
  String toString() {
    return 'TimerConfiguration(type: $type, label: $label, description: $description, defaultDurationSeconds: $defaultDurationSeconds, minDurationSeconds: $minDurationSeconds, maxDurationSeconds: $maxDurationSeconds, presetDurations: $presetDurations, warningThresholdSeconds: $warningThresholdSeconds, allowPause: $allowPause, allowAddTime: $allowAddTime, showProgress: $showProgress, primaryColor: $primaryColor, warningColor: $warningColor, expiredColor: $expiredColor)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimerConfigurationImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.defaultDurationSeconds, defaultDurationSeconds) ||
                other.defaultDurationSeconds == defaultDurationSeconds) &&
            (identical(other.minDurationSeconds, minDurationSeconds) ||
                other.minDurationSeconds == minDurationSeconds) &&
            (identical(other.maxDurationSeconds, maxDurationSeconds) ||
                other.maxDurationSeconds == maxDurationSeconds) &&
            const DeepCollectionEquality()
                .equals(other._presetDurations, _presetDurations) &&
            (identical(
                    other.warningThresholdSeconds, warningThresholdSeconds) ||
                other.warningThresholdSeconds == warningThresholdSeconds) &&
            (identical(other.allowPause, allowPause) ||
                other.allowPause == allowPause) &&
            (identical(other.allowAddTime, allowAddTime) ||
                other.allowAddTime == allowAddTime) &&
            (identical(other.showProgress, showProgress) ||
                other.showProgress == showProgress) &&
            (identical(other.primaryColor, primaryColor) ||
                other.primaryColor == primaryColor) &&
            (identical(other.warningColor, warningColor) ||
                other.warningColor == warningColor) &&
            (identical(other.expiredColor, expiredColor) ||
                other.expiredColor == expiredColor));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      type,
      label,
      description,
      defaultDurationSeconds,
      minDurationSeconds,
      maxDurationSeconds,
      const DeepCollectionEquality().hash(_presetDurations),
      warningThresholdSeconds,
      allowPause,
      allowAddTime,
      showProgress,
      primaryColor,
      warningColor,
      expiredColor);

  /// Create a copy of TimerConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimerConfigurationImplCopyWith<_$TimerConfigurationImpl> get copyWith =>
      __$$TimerConfigurationImplCopyWithImpl<_$TimerConfigurationImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TimerConfigurationImplToJson(
      this,
    );
  }
}

abstract class _TimerConfiguration implements TimerConfiguration {
  const factory _TimerConfiguration(
      {required final TimerType type,
      required final String label,
      required final String description,
      required final int defaultDurationSeconds,
      required final int minDurationSeconds,
      required final int maxDurationSeconds,
      required final List<int> presetDurations,
      final int warningThresholdSeconds,
      final bool allowPause,
      final bool allowAddTime,
      final bool showProgress,
      final String primaryColor,
      final String warningColor,
      final String expiredColor}) = _$TimerConfigurationImpl;

  factory _TimerConfiguration.fromJson(Map<String, dynamic> json) =
      _$TimerConfigurationImpl.fromJson;

  @override
  TimerType get type;
  @override
  String get label;
  @override
  String get description;
  @override
  int get defaultDurationSeconds;
  @override
  int get minDurationSeconds;
  @override
  int get maxDurationSeconds;
  @override
  List<int> get presetDurations;
  @override
  int get warningThresholdSeconds;
  @override
  bool get allowPause;
  @override
  bool get allowAddTime;
  @override
  bool get showProgress;
  @override
  String get primaryColor;
  @override
  String get warningColor;
  @override
  String get expiredColor;

  /// Create a copy of TimerConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimerConfigurationImplCopyWith<_$TimerConfigurationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RoomTimerPreset _$RoomTimerPresetFromJson(Map<String, dynamic> json) {
  return _RoomTimerPreset.fromJson(json);
}

/// @nodoc
mixin _$RoomTimerPreset {
  RoomType get roomType => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  List<TimerConfiguration> get timers => throw _privateConstructorUsedError;
  int get maxConcurrentTimers => throw _privateConstructorUsedError;
  bool get moderatorOnly => throw _privateConstructorUsedError;

  /// Serializes this RoomTimerPreset to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RoomTimerPreset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RoomTimerPresetCopyWith<RoomTimerPreset> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RoomTimerPresetCopyWith<$Res> {
  factory $RoomTimerPresetCopyWith(
          RoomTimerPreset value, $Res Function(RoomTimerPreset) then) =
      _$RoomTimerPresetCopyWithImpl<$Res, RoomTimerPreset>;
  @useResult
  $Res call(
      {RoomType roomType,
      String name,
      String description,
      List<TimerConfiguration> timers,
      int maxConcurrentTimers,
      bool moderatorOnly});
}

/// @nodoc
class _$RoomTimerPresetCopyWithImpl<$Res, $Val extends RoomTimerPreset>
    implements $RoomTimerPresetCopyWith<$Res> {
  _$RoomTimerPresetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RoomTimerPreset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? roomType = null,
    Object? name = null,
    Object? description = null,
    Object? timers = null,
    Object? maxConcurrentTimers = null,
    Object? moderatorOnly = null,
  }) {
    return _then(_value.copyWith(
      roomType: null == roomType
          ? _value.roomType
          : roomType // ignore: cast_nullable_to_non_nullable
              as RoomType,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      timers: null == timers
          ? _value.timers
          : timers // ignore: cast_nullable_to_non_nullable
              as List<TimerConfiguration>,
      maxConcurrentTimers: null == maxConcurrentTimers
          ? _value.maxConcurrentTimers
          : maxConcurrentTimers // ignore: cast_nullable_to_non_nullable
              as int,
      moderatorOnly: null == moderatorOnly
          ? _value.moderatorOnly
          : moderatorOnly // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RoomTimerPresetImplCopyWith<$Res>
    implements $RoomTimerPresetCopyWith<$Res> {
  factory _$$RoomTimerPresetImplCopyWith(_$RoomTimerPresetImpl value,
          $Res Function(_$RoomTimerPresetImpl) then) =
      __$$RoomTimerPresetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {RoomType roomType,
      String name,
      String description,
      List<TimerConfiguration> timers,
      int maxConcurrentTimers,
      bool moderatorOnly});
}

/// @nodoc
class __$$RoomTimerPresetImplCopyWithImpl<$Res>
    extends _$RoomTimerPresetCopyWithImpl<$Res, _$RoomTimerPresetImpl>
    implements _$$RoomTimerPresetImplCopyWith<$Res> {
  __$$RoomTimerPresetImplCopyWithImpl(
      _$RoomTimerPresetImpl _value, $Res Function(_$RoomTimerPresetImpl) _then)
      : super(_value, _then);

  /// Create a copy of RoomTimerPreset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? roomType = null,
    Object? name = null,
    Object? description = null,
    Object? timers = null,
    Object? maxConcurrentTimers = null,
    Object? moderatorOnly = null,
  }) {
    return _then(_$RoomTimerPresetImpl(
      roomType: null == roomType
          ? _value.roomType
          : roomType // ignore: cast_nullable_to_non_nullable
              as RoomType,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      timers: null == timers
          ? _value._timers
          : timers // ignore: cast_nullable_to_non_nullable
              as List<TimerConfiguration>,
      maxConcurrentTimers: null == maxConcurrentTimers
          ? _value.maxConcurrentTimers
          : maxConcurrentTimers // ignore: cast_nullable_to_non_nullable
              as int,
      moderatorOnly: null == moderatorOnly
          ? _value.moderatorOnly
          : moderatorOnly // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RoomTimerPresetImpl implements _RoomTimerPreset {
  const _$RoomTimerPresetImpl(
      {required this.roomType,
      required this.name,
      required this.description,
      required final List<TimerConfiguration> timers,
      this.maxConcurrentTimers = 1,
      this.moderatorOnly = true})
      : _timers = timers;

  factory _$RoomTimerPresetImpl.fromJson(Map<String, dynamic> json) =>
      _$$RoomTimerPresetImplFromJson(json);

  @override
  final RoomType roomType;
  @override
  final String name;
  @override
  final String description;
  final List<TimerConfiguration> _timers;
  @override
  List<TimerConfiguration> get timers {
    if (_timers is EqualUnmodifiableListView) return _timers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_timers);
  }

  @override
  @JsonKey()
  final int maxConcurrentTimers;
  @override
  @JsonKey()
  final bool moderatorOnly;

  @override
  String toString() {
    return 'RoomTimerPreset(roomType: $roomType, name: $name, description: $description, timers: $timers, maxConcurrentTimers: $maxConcurrentTimers, moderatorOnly: $moderatorOnly)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoomTimerPresetImpl &&
            (identical(other.roomType, roomType) ||
                other.roomType == roomType) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._timers, _timers) &&
            (identical(other.maxConcurrentTimers, maxConcurrentTimers) ||
                other.maxConcurrentTimers == maxConcurrentTimers) &&
            (identical(other.moderatorOnly, moderatorOnly) ||
                other.moderatorOnly == moderatorOnly));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      roomType,
      name,
      description,
      const DeepCollectionEquality().hash(_timers),
      maxConcurrentTimers,
      moderatorOnly);

  /// Create a copy of RoomTimerPreset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RoomTimerPresetImplCopyWith<_$RoomTimerPresetImpl> get copyWith =>
      __$$RoomTimerPresetImplCopyWithImpl<_$RoomTimerPresetImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RoomTimerPresetImplToJson(
      this,
    );
  }
}

abstract class _RoomTimerPreset implements RoomTimerPreset {
  const factory _RoomTimerPreset(
      {required final RoomType roomType,
      required final String name,
      required final String description,
      required final List<TimerConfiguration> timers,
      final int maxConcurrentTimers,
      final bool moderatorOnly}) = _$RoomTimerPresetImpl;

  factory _RoomTimerPreset.fromJson(Map<String, dynamic> json) =
      _$RoomTimerPresetImpl.fromJson;

  @override
  RoomType get roomType;
  @override
  String get name;
  @override
  String get description;
  @override
  List<TimerConfiguration> get timers;
  @override
  int get maxConcurrentTimers;
  @override
  bool get moderatorOnly;

  /// Create a copy of RoomTimerPreset
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RoomTimerPresetImplCopyWith<_$RoomTimerPresetImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TimerEvent _$TimerEventFromJson(Map<String, dynamic> json) {
  return _TimerEvent.fromJson(json);
}

/// @nodoc
mixin _$TimerEvent {
  String get timerId => throw _privateConstructorUsedError;
  String get action => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get timestamp => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String? get details => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  /// Serializes this TimerEvent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TimerEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TimerEventCopyWith<TimerEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TimerEventCopyWith<$Res> {
  factory $TimerEventCopyWith(
          TimerEvent value, $Res Function(TimerEvent) then) =
      _$TimerEventCopyWithImpl<$Res, TimerEvent>;
  @useResult
  $Res call(
      {String timerId,
      String action,
      @TimestampConverter() DateTime timestamp,
      String userId,
      String? details,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class _$TimerEventCopyWithImpl<$Res, $Val extends TimerEvent>
    implements $TimerEventCopyWith<$Res> {
  _$TimerEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TimerEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timerId = null,
    Object? action = null,
    Object? timestamp = null,
    Object? userId = null,
    Object? details = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_value.copyWith(
      timerId: null == timerId
          ? _value.timerId
          : timerId // ignore: cast_nullable_to_non_nullable
              as String,
      action: null == action
          ? _value.action
          : action // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      details: freezed == details
          ? _value.details
          : details // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TimerEventImplCopyWith<$Res>
    implements $TimerEventCopyWith<$Res> {
  factory _$$TimerEventImplCopyWith(
          _$TimerEventImpl value, $Res Function(_$TimerEventImpl) then) =
      __$$TimerEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String timerId,
      String action,
      @TimestampConverter() DateTime timestamp,
      String userId,
      String? details,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class __$$TimerEventImplCopyWithImpl<$Res>
    extends _$TimerEventCopyWithImpl<$Res, _$TimerEventImpl>
    implements _$$TimerEventImplCopyWith<$Res> {
  __$$TimerEventImplCopyWithImpl(
      _$TimerEventImpl _value, $Res Function(_$TimerEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of TimerEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timerId = null,
    Object? action = null,
    Object? timestamp = null,
    Object? userId = null,
    Object? details = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_$TimerEventImpl(
      timerId: null == timerId
          ? _value.timerId
          : timerId // ignore: cast_nullable_to_non_nullable
              as String,
      action: null == action
          ? _value.action
          : action // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      details: freezed == details
          ? _value.details
          : details // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TimerEventImpl implements _TimerEvent {
  const _$TimerEventImpl(
      {required this.timerId,
      required this.action,
      @TimestampConverter() required this.timestamp,
      required this.userId,
      this.details,
      final Map<String, dynamic>? metadata})
      : _metadata = metadata;

  factory _$TimerEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$TimerEventImplFromJson(json);

  @override
  final String timerId;
  @override
  final String action;
  @override
  @TimestampConverter()
  final DateTime timestamp;
  @override
  final String userId;
  @override
  final String? details;
  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'TimerEvent(timerId: $timerId, action: $action, timestamp: $timestamp, userId: $userId, details: $details, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimerEventImpl &&
            (identical(other.timerId, timerId) || other.timerId == timerId) &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.details, details) || other.details == details) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, timerId, action, timestamp,
      userId, details, const DeepCollectionEquality().hash(_metadata));

  /// Create a copy of TimerEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimerEventImplCopyWith<_$TimerEventImpl> get copyWith =>
      __$$TimerEventImplCopyWithImpl<_$TimerEventImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TimerEventImplToJson(
      this,
    );
  }
}

abstract class _TimerEvent implements TimerEvent {
  const factory _TimerEvent(
      {required final String timerId,
      required final String action,
      @TimestampConverter() required final DateTime timestamp,
      required final String userId,
      final String? details,
      final Map<String, dynamic>? metadata}) = _$TimerEventImpl;

  factory _TimerEvent.fromJson(Map<String, dynamic> json) =
      _$TimerEventImpl.fromJson;

  @override
  String get timerId;
  @override
  String get action;
  @override
  @TimestampConverter()
  DateTime get timestamp;
  @override
  String get userId;
  @override
  String? get details;
  @override
  Map<String, dynamic>? get metadata;

  /// Create a copy of TimerEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimerEventImplCopyWith<_$TimerEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
