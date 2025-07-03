// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'discussion_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$DiscussionParticipant {
  String get userId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  DiscussionRole get role => throw _privateConstructorUsedError;
  String? get avatar => throw _privateConstructorUsedError;
  bool get isHandRaised => throw _privateConstructorUsedError;
  bool get isSpeaking => throw _privateConstructorUsedError;
  bool get isMuted => throw _privateConstructorUsedError;
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Create a copy of DiscussionParticipant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DiscussionParticipantCopyWith<DiscussionParticipant> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DiscussionParticipantCopyWith<$Res> {
  factory $DiscussionParticipantCopyWith(DiscussionParticipant value,
          $Res Function(DiscussionParticipant) then) =
      _$DiscussionParticipantCopyWithImpl<$Res, DiscussionParticipant>;
  @useResult
  $Res call(
      {String userId,
      String name,
      DiscussionRole role,
      String? avatar,
      bool isHandRaised,
      bool isSpeaking,
      bool isMuted,
      Map<String, dynamic> metadata});
}

/// @nodoc
class _$DiscussionParticipantCopyWithImpl<$Res,
        $Val extends DiscussionParticipant>
    implements $DiscussionParticipantCopyWith<$Res> {
  _$DiscussionParticipantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DiscussionParticipant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? name = null,
    Object? role = null,
    Object? avatar = freezed,
    Object? isHandRaised = null,
    Object? isSpeaking = null,
    Object? isMuted = null,
    Object? metadata = null,
  }) {
    return _then(_value.copyWith(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as DiscussionRole,
      avatar: freezed == avatar
          ? _value.avatar
          : avatar // ignore: cast_nullable_to_non_nullable
              as String?,
      isHandRaised: null == isHandRaised
          ? _value.isHandRaised
          : isHandRaised // ignore: cast_nullable_to_non_nullable
              as bool,
      isSpeaking: null == isSpeaking
          ? _value.isSpeaking
          : isSpeaking // ignore: cast_nullable_to_non_nullable
              as bool,
      isMuted: null == isMuted
          ? _value.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
              as bool,
      metadata: null == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DiscussionParticipantImplCopyWith<$Res>
    implements $DiscussionParticipantCopyWith<$Res> {
  factory _$$DiscussionParticipantImplCopyWith(
          _$DiscussionParticipantImpl value,
          $Res Function(_$DiscussionParticipantImpl) then) =
      __$$DiscussionParticipantImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String userId,
      String name,
      DiscussionRole role,
      String? avatar,
      bool isHandRaised,
      bool isSpeaking,
      bool isMuted,
      Map<String, dynamic> metadata});
}

/// @nodoc
class __$$DiscussionParticipantImplCopyWithImpl<$Res>
    extends _$DiscussionParticipantCopyWithImpl<$Res,
        _$DiscussionParticipantImpl>
    implements _$$DiscussionParticipantImplCopyWith<$Res> {
  __$$DiscussionParticipantImplCopyWithImpl(_$DiscussionParticipantImpl _value,
      $Res Function(_$DiscussionParticipantImpl) _then)
      : super(_value, _then);

  /// Create a copy of DiscussionParticipant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? name = null,
    Object? role = null,
    Object? avatar = freezed,
    Object? isHandRaised = null,
    Object? isSpeaking = null,
    Object? isMuted = null,
    Object? metadata = null,
  }) {
    return _then(_$DiscussionParticipantImpl(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as DiscussionRole,
      avatar: freezed == avatar
          ? _value.avatar
          : avatar // ignore: cast_nullable_to_non_nullable
              as String?,
      isHandRaised: null == isHandRaised
          ? _value.isHandRaised
          : isHandRaised // ignore: cast_nullable_to_non_nullable
              as bool,
      isSpeaking: null == isSpeaking
          ? _value.isSpeaking
          : isSpeaking // ignore: cast_nullable_to_non_nullable
              as bool,
      isMuted: null == isMuted
          ? _value.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
              as bool,
      metadata: null == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

/// @nodoc

class _$DiscussionParticipantImpl implements _DiscussionParticipant {
  const _$DiscussionParticipantImpl(
      {required this.userId,
      required this.name,
      required this.role,
      this.avatar,
      this.isHandRaised = false,
      this.isSpeaking = false,
      this.isMuted = false,
      final Map<String, dynamic> metadata = const {}})
      : _metadata = metadata;

  @override
  final String userId;
  @override
  final String name;
  @override
  final DiscussionRole role;
  @override
  final String? avatar;
  @override
  @JsonKey()
  final bool isHandRaised;
  @override
  @JsonKey()
  final bool isSpeaking;
  @override
  @JsonKey()
  final bool isMuted;
  final Map<String, dynamic> _metadata;
  @override
  @JsonKey()
  Map<String, dynamic> get metadata {
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_metadata);
  }

  @override
  String toString() {
    return 'DiscussionParticipant(userId: $userId, name: $name, role: $role, avatar: $avatar, isHandRaised: $isHandRaised, isSpeaking: $isSpeaking, isMuted: $isMuted, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DiscussionParticipantImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.avatar, avatar) || other.avatar == avatar) &&
            (identical(other.isHandRaised, isHandRaised) ||
                other.isHandRaised == isHandRaised) &&
            (identical(other.isSpeaking, isSpeaking) ||
                other.isSpeaking == isSpeaking) &&
            (identical(other.isMuted, isMuted) || other.isMuted == isMuted) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      userId,
      name,
      role,
      avatar,
      isHandRaised,
      isSpeaking,
      isMuted,
      const DeepCollectionEquality().hash(_metadata));

  /// Create a copy of DiscussionParticipant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DiscussionParticipantImplCopyWith<_$DiscussionParticipantImpl>
      get copyWith => __$$DiscussionParticipantImplCopyWithImpl<
          _$DiscussionParticipantImpl>(this, _$identity);
}

abstract class _DiscussionParticipant implements DiscussionParticipant {
  const factory _DiscussionParticipant(
      {required final String userId,
      required final String name,
      required final DiscussionRole role,
      final String? avatar,
      final bool isHandRaised,
      final bool isSpeaking,
      final bool isMuted,
      final Map<String, dynamic> metadata}) = _$DiscussionParticipantImpl;

  @override
  String get userId;
  @override
  String get name;
  @override
  DiscussionRole get role;
  @override
  String? get avatar;
  @override
  bool get isHandRaised;
  @override
  bool get isSpeaking;
  @override
  bool get isMuted;
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of DiscussionParticipant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DiscussionParticipantImplCopyWith<_$DiscussionParticipantImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$VoiceState {
  bool get isMuted => throw _privateConstructorUsedError;
  bool get isHandRaised => throw _privateConstructorUsedError;
  bool get isConnecting => throw _privateConstructorUsedError;
  bool get isSpeakerphoneEnabled => throw _privateConstructorUsedError;
  Set<int> get remoteUsers => throw _privateConstructorUsedError;
  Set<int> get speakingUsers => throw _privateConstructorUsedError;
  Set<String> get handsRaised => throw _privateConstructorUsedError;

  /// Create a copy of VoiceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VoiceStateCopyWith<VoiceState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VoiceStateCopyWith<$Res> {
  factory $VoiceStateCopyWith(
          VoiceState value, $Res Function(VoiceState) then) =
      _$VoiceStateCopyWithImpl<$Res, VoiceState>;
  @useResult
  $Res call(
      {bool isMuted,
      bool isHandRaised,
      bool isConnecting,
      bool isSpeakerphoneEnabled,
      Set<int> remoteUsers,
      Set<int> speakingUsers,
      Set<String> handsRaised});
}

/// @nodoc
class _$VoiceStateCopyWithImpl<$Res, $Val extends VoiceState>
    implements $VoiceStateCopyWith<$Res> {
  _$VoiceStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VoiceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isMuted = null,
    Object? isHandRaised = null,
    Object? isConnecting = null,
    Object? isSpeakerphoneEnabled = null,
    Object? remoteUsers = null,
    Object? speakingUsers = null,
    Object? handsRaised = null,
  }) {
    return _then(_value.copyWith(
      isMuted: null == isMuted
          ? _value.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
              as bool,
      isHandRaised: null == isHandRaised
          ? _value.isHandRaised
          : isHandRaised // ignore: cast_nullable_to_non_nullable
              as bool,
      isConnecting: null == isConnecting
          ? _value.isConnecting
          : isConnecting // ignore: cast_nullable_to_non_nullable
              as bool,
      isSpeakerphoneEnabled: null == isSpeakerphoneEnabled
          ? _value.isSpeakerphoneEnabled
          : isSpeakerphoneEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      remoteUsers: null == remoteUsers
          ? _value.remoteUsers
          : remoteUsers // ignore: cast_nullable_to_non_nullable
              as Set<int>,
      speakingUsers: null == speakingUsers
          ? _value.speakingUsers
          : speakingUsers // ignore: cast_nullable_to_non_nullable
              as Set<int>,
      handsRaised: null == handsRaised
          ? _value.handsRaised
          : handsRaised // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VoiceStateImplCopyWith<$Res>
    implements $VoiceStateCopyWith<$Res> {
  factory _$$VoiceStateImplCopyWith(
          _$VoiceStateImpl value, $Res Function(_$VoiceStateImpl) then) =
      __$$VoiceStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool isMuted,
      bool isHandRaised,
      bool isConnecting,
      bool isSpeakerphoneEnabled,
      Set<int> remoteUsers,
      Set<int> speakingUsers,
      Set<String> handsRaised});
}

/// @nodoc
class __$$VoiceStateImplCopyWithImpl<$Res>
    extends _$VoiceStateCopyWithImpl<$Res, _$VoiceStateImpl>
    implements _$$VoiceStateImplCopyWith<$Res> {
  __$$VoiceStateImplCopyWithImpl(
      _$VoiceStateImpl _value, $Res Function(_$VoiceStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of VoiceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isMuted = null,
    Object? isHandRaised = null,
    Object? isConnecting = null,
    Object? isSpeakerphoneEnabled = null,
    Object? remoteUsers = null,
    Object? speakingUsers = null,
    Object? handsRaised = null,
  }) {
    return _then(_$VoiceStateImpl(
      isMuted: null == isMuted
          ? _value.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
              as bool,
      isHandRaised: null == isHandRaised
          ? _value.isHandRaised
          : isHandRaised // ignore: cast_nullable_to_non_nullable
              as bool,
      isConnecting: null == isConnecting
          ? _value.isConnecting
          : isConnecting // ignore: cast_nullable_to_non_nullable
              as bool,
      isSpeakerphoneEnabled: null == isSpeakerphoneEnabled
          ? _value.isSpeakerphoneEnabled
          : isSpeakerphoneEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      remoteUsers: null == remoteUsers
          ? _value._remoteUsers
          : remoteUsers // ignore: cast_nullable_to_non_nullable
              as Set<int>,
      speakingUsers: null == speakingUsers
          ? _value._speakingUsers
          : speakingUsers // ignore: cast_nullable_to_non_nullable
              as Set<int>,
      handsRaised: null == handsRaised
          ? _value._handsRaised
          : handsRaised // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ));
  }
}

/// @nodoc

class _$VoiceStateImpl implements _VoiceState {
  const _$VoiceStateImpl(
      {this.isMuted = true,
      this.isHandRaised = false,
      this.isConnecting = false,
      this.isSpeakerphoneEnabled = true,
      final Set<int> remoteUsers = const {},
      final Set<int> speakingUsers = const {},
      final Set<String> handsRaised = const {}})
      : _remoteUsers = remoteUsers,
        _speakingUsers = speakingUsers,
        _handsRaised = handsRaised;

  @override
  @JsonKey()
  final bool isMuted;
  @override
  @JsonKey()
  final bool isHandRaised;
  @override
  @JsonKey()
  final bool isConnecting;
  @override
  @JsonKey()
  final bool isSpeakerphoneEnabled;
  final Set<int> _remoteUsers;
  @override
  @JsonKey()
  Set<int> get remoteUsers {
    if (_remoteUsers is EqualUnmodifiableSetView) return _remoteUsers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_remoteUsers);
  }

  final Set<int> _speakingUsers;
  @override
  @JsonKey()
  Set<int> get speakingUsers {
    if (_speakingUsers is EqualUnmodifiableSetView) return _speakingUsers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_speakingUsers);
  }

  final Set<String> _handsRaised;
  @override
  @JsonKey()
  Set<String> get handsRaised {
    if (_handsRaised is EqualUnmodifiableSetView) return _handsRaised;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_handsRaised);
  }

  @override
  String toString() {
    return 'VoiceState(isMuted: $isMuted, isHandRaised: $isHandRaised, isConnecting: $isConnecting, isSpeakerphoneEnabled: $isSpeakerphoneEnabled, remoteUsers: $remoteUsers, speakingUsers: $speakingUsers, handsRaised: $handsRaised)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VoiceStateImpl &&
            (identical(other.isMuted, isMuted) || other.isMuted == isMuted) &&
            (identical(other.isHandRaised, isHandRaised) ||
                other.isHandRaised == isHandRaised) &&
            (identical(other.isConnecting, isConnecting) ||
                other.isConnecting == isConnecting) &&
            (identical(other.isSpeakerphoneEnabled, isSpeakerphoneEnabled) ||
                other.isSpeakerphoneEnabled == isSpeakerphoneEnabled) &&
            const DeepCollectionEquality()
                .equals(other._remoteUsers, _remoteUsers) &&
            const DeepCollectionEquality()
                .equals(other._speakingUsers, _speakingUsers) &&
            const DeepCollectionEquality()
                .equals(other._handsRaised, _handsRaised));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      isMuted,
      isHandRaised,
      isConnecting,
      isSpeakerphoneEnabled,
      const DeepCollectionEquality().hash(_remoteUsers),
      const DeepCollectionEquality().hash(_speakingUsers),
      const DeepCollectionEquality().hash(_handsRaised));

  /// Create a copy of VoiceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VoiceStateImplCopyWith<_$VoiceStateImpl> get copyWith =>
      __$$VoiceStateImplCopyWithImpl<_$VoiceStateImpl>(this, _$identity);
}

abstract class _VoiceState implements VoiceState {
  const factory _VoiceState(
      {final bool isMuted,
      final bool isHandRaised,
      final bool isConnecting,
      final bool isSpeakerphoneEnabled,
      final Set<int> remoteUsers,
      final Set<int> speakingUsers,
      final Set<String> handsRaised}) = _$VoiceStateImpl;

  @override
  bool get isMuted;
  @override
  bool get isHandRaised;
  @override
  bool get isConnecting;
  @override
  bool get isSpeakerphoneEnabled;
  @override
  Set<int> get remoteUsers;
  @override
  Set<int> get speakingUsers;
  @override
  Set<String> get handsRaised;

  /// Create a copy of VoiceState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VoiceStateImplCopyWith<_$VoiceStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$TimerState {
  int get speakingTime =>
      throw _privateConstructorUsedError; // countdown in seconds
  int get speakingTimeLimit =>
      throw _privateConstructorUsedError; // default 5 minutes
  bool get isTimerRunning => throw _privateConstructorUsedError;
  bool get isTimerPaused => throw _privateConstructorUsedError;
  bool get thirtySecondChimePlayed => throw _privateConstructorUsedError;

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
      {int speakingTime,
      int speakingTimeLimit,
      bool isTimerRunning,
      bool isTimerPaused,
      bool thirtySecondChimePlayed});
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
    Object? speakingTime = null,
    Object? speakingTimeLimit = null,
    Object? isTimerRunning = null,
    Object? isTimerPaused = null,
    Object? thirtySecondChimePlayed = null,
  }) {
    return _then(_value.copyWith(
      speakingTime: null == speakingTime
          ? _value.speakingTime
          : speakingTime // ignore: cast_nullable_to_non_nullable
              as int,
      speakingTimeLimit: null == speakingTimeLimit
          ? _value.speakingTimeLimit
          : speakingTimeLimit // ignore: cast_nullable_to_non_nullable
              as int,
      isTimerRunning: null == isTimerRunning
          ? _value.isTimerRunning
          : isTimerRunning // ignore: cast_nullable_to_non_nullable
              as bool,
      isTimerPaused: null == isTimerPaused
          ? _value.isTimerPaused
          : isTimerPaused // ignore: cast_nullable_to_non_nullable
              as bool,
      thirtySecondChimePlayed: null == thirtySecondChimePlayed
          ? _value.thirtySecondChimePlayed
          : thirtySecondChimePlayed // ignore: cast_nullable_to_non_nullable
              as bool,
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
      {int speakingTime,
      int speakingTimeLimit,
      bool isTimerRunning,
      bool isTimerPaused,
      bool thirtySecondChimePlayed});
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
    Object? speakingTime = null,
    Object? speakingTimeLimit = null,
    Object? isTimerRunning = null,
    Object? isTimerPaused = null,
    Object? thirtySecondChimePlayed = null,
  }) {
    return _then(_$TimerStateImpl(
      speakingTime: null == speakingTime
          ? _value.speakingTime
          : speakingTime // ignore: cast_nullable_to_non_nullable
              as int,
      speakingTimeLimit: null == speakingTimeLimit
          ? _value.speakingTimeLimit
          : speakingTimeLimit // ignore: cast_nullable_to_non_nullable
              as int,
      isTimerRunning: null == isTimerRunning
          ? _value.isTimerRunning
          : isTimerRunning // ignore: cast_nullable_to_non_nullable
              as bool,
      isTimerPaused: null == isTimerPaused
          ? _value.isTimerPaused
          : isTimerPaused // ignore: cast_nullable_to_non_nullable
              as bool,
      thirtySecondChimePlayed: null == thirtySecondChimePlayed
          ? _value.thirtySecondChimePlayed
          : thirtySecondChimePlayed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$TimerStateImpl implements _TimerState {
  const _$TimerStateImpl(
      {this.speakingTime = 300,
      this.speakingTimeLimit = 300,
      this.isTimerRunning = false,
      this.isTimerPaused = false,
      this.thirtySecondChimePlayed = false});

  @override
  @JsonKey()
  final int speakingTime;
// countdown in seconds
  @override
  @JsonKey()
  final int speakingTimeLimit;
// default 5 minutes
  @override
  @JsonKey()
  final bool isTimerRunning;
  @override
  @JsonKey()
  final bool isTimerPaused;
  @override
  @JsonKey()
  final bool thirtySecondChimePlayed;

  @override
  String toString() {
    return 'TimerState(speakingTime: $speakingTime, speakingTimeLimit: $speakingTimeLimit, isTimerRunning: $isTimerRunning, isTimerPaused: $isTimerPaused, thirtySecondChimePlayed: $thirtySecondChimePlayed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimerStateImpl &&
            (identical(other.speakingTime, speakingTime) ||
                other.speakingTime == speakingTime) &&
            (identical(other.speakingTimeLimit, speakingTimeLimit) ||
                other.speakingTimeLimit == speakingTimeLimit) &&
            (identical(other.isTimerRunning, isTimerRunning) ||
                other.isTimerRunning == isTimerRunning) &&
            (identical(other.isTimerPaused, isTimerPaused) ||
                other.isTimerPaused == isTimerPaused) &&
            (identical(
                    other.thirtySecondChimePlayed, thirtySecondChimePlayed) ||
                other.thirtySecondChimePlayed == thirtySecondChimePlayed));
  }

  @override
  int get hashCode => Object.hash(runtimeType, speakingTime, speakingTimeLimit,
      isTimerRunning, isTimerPaused, thirtySecondChimePlayed);

  /// Create a copy of TimerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimerStateImplCopyWith<_$TimerStateImpl> get copyWith =>
      __$$TimerStateImplCopyWithImpl<_$TimerStateImpl>(this, _$identity);
}

abstract class _TimerState implements TimerState {
  const factory _TimerState(
      {final int speakingTime,
      final int speakingTimeLimit,
      final bool isTimerRunning,
      final bool isTimerPaused,
      final bool thirtySecondChimePlayed}) = _$TimerStateImpl;

  @override
  int get speakingTime; // countdown in seconds
  @override
  int get speakingTimeLimit; // default 5 minutes
  @override
  bool get isTimerRunning;
  @override
  bool get isTimerPaused;
  @override
  bool get thirtySecondChimePlayed;

  /// Create a copy of TimerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimerStateImplCopyWith<_$TimerStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$NetworkState {
  bool get isRealtimeHealthy => throw _privateConstructorUsedError;
  int get reconnectAttempts => throw _privateConstructorUsedError;
  int get maxReconnectAttempts => throw _privateConstructorUsedError;

  /// Create a copy of NetworkState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NetworkStateCopyWith<NetworkState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NetworkStateCopyWith<$Res> {
  factory $NetworkStateCopyWith(
          NetworkState value, $Res Function(NetworkState) then) =
      _$NetworkStateCopyWithImpl<$Res, NetworkState>;
  @useResult
  $Res call(
      {bool isRealtimeHealthy,
      int reconnectAttempts,
      int maxReconnectAttempts});
}

/// @nodoc
class _$NetworkStateCopyWithImpl<$Res, $Val extends NetworkState>
    implements $NetworkStateCopyWith<$Res> {
  _$NetworkStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NetworkState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isRealtimeHealthy = null,
    Object? reconnectAttempts = null,
    Object? maxReconnectAttempts = null,
  }) {
    return _then(_value.copyWith(
      isRealtimeHealthy: null == isRealtimeHealthy
          ? _value.isRealtimeHealthy
          : isRealtimeHealthy // ignore: cast_nullable_to_non_nullable
              as bool,
      reconnectAttempts: null == reconnectAttempts
          ? _value.reconnectAttempts
          : reconnectAttempts // ignore: cast_nullable_to_non_nullable
              as int,
      maxReconnectAttempts: null == maxReconnectAttempts
          ? _value.maxReconnectAttempts
          : maxReconnectAttempts // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NetworkStateImplCopyWith<$Res>
    implements $NetworkStateCopyWith<$Res> {
  factory _$$NetworkStateImplCopyWith(
          _$NetworkStateImpl value, $Res Function(_$NetworkStateImpl) then) =
      __$$NetworkStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool isRealtimeHealthy,
      int reconnectAttempts,
      int maxReconnectAttempts});
}

/// @nodoc
class __$$NetworkStateImplCopyWithImpl<$Res>
    extends _$NetworkStateCopyWithImpl<$Res, _$NetworkStateImpl>
    implements _$$NetworkStateImplCopyWith<$Res> {
  __$$NetworkStateImplCopyWithImpl(
      _$NetworkStateImpl _value, $Res Function(_$NetworkStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of NetworkState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isRealtimeHealthy = null,
    Object? reconnectAttempts = null,
    Object? maxReconnectAttempts = null,
  }) {
    return _then(_$NetworkStateImpl(
      isRealtimeHealthy: null == isRealtimeHealthy
          ? _value.isRealtimeHealthy
          : isRealtimeHealthy // ignore: cast_nullable_to_non_nullable
              as bool,
      reconnectAttempts: null == reconnectAttempts
          ? _value.reconnectAttempts
          : reconnectAttempts // ignore: cast_nullable_to_non_nullable
              as int,
      maxReconnectAttempts: null == maxReconnectAttempts
          ? _value.maxReconnectAttempts
          : maxReconnectAttempts // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$NetworkStateImpl implements _NetworkState {
  const _$NetworkStateImpl(
      {this.isRealtimeHealthy = true,
      this.reconnectAttempts = 0,
      this.maxReconnectAttempts = 5});

  @override
  @JsonKey()
  final bool isRealtimeHealthy;
  @override
  @JsonKey()
  final int reconnectAttempts;
  @override
  @JsonKey()
  final int maxReconnectAttempts;

  @override
  String toString() {
    return 'NetworkState(isRealtimeHealthy: $isRealtimeHealthy, reconnectAttempts: $reconnectAttempts, maxReconnectAttempts: $maxReconnectAttempts)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NetworkStateImpl &&
            (identical(other.isRealtimeHealthy, isRealtimeHealthy) ||
                other.isRealtimeHealthy == isRealtimeHealthy) &&
            (identical(other.reconnectAttempts, reconnectAttempts) ||
                other.reconnectAttempts == reconnectAttempts) &&
            (identical(other.maxReconnectAttempts, maxReconnectAttempts) ||
                other.maxReconnectAttempts == maxReconnectAttempts));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, isRealtimeHealthy, reconnectAttempts, maxReconnectAttempts);

  /// Create a copy of NetworkState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NetworkStateImplCopyWith<_$NetworkStateImpl> get copyWith =>
      __$$NetworkStateImplCopyWithImpl<_$NetworkStateImpl>(this, _$identity);
}

abstract class _NetworkState implements NetworkState {
  const factory _NetworkState(
      {final bool isRealtimeHealthy,
      final int reconnectAttempts,
      final int maxReconnectAttempts}) = _$NetworkStateImpl;

  @override
  bool get isRealtimeHealthy;
  @override
  int get reconnectAttempts;
  @override
  int get maxReconnectAttempts;

  /// Create a copy of NetworkState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NetworkStateImplCopyWith<_$NetworkStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DiscussionState {
  String get roomId => throw _privateConstructorUsedError;
  Room get room => throw _privateConstructorUsedError; // Current user state
  String? get currentUserId => throw _privateConstructorUsedError;
  String? get userRole => throw _privateConstructorUsedError;
  int get coinBalance => throw _privateConstructorUsedError; // Room data
  List<DiscussionParticipant> get participants =>
      throw _privateConstructorUsedError;
  Map<String, UserProfile> get userProfiles =>
      throw _privateConstructorUsedError;
  Map<String, dynamic>? get userParticipation =>
      throw _privateConstructorUsedError; // Voice state
  VoiceState get voiceState =>
      throw _privateConstructorUsedError; // Timer state
  TimerState get timerState =>
      throw _privateConstructorUsedError; // Network state
  NetworkState get networkState =>
      throw _privateConstructorUsedError; // UI state
  bool get isChatOpen => throw _privateConstructorUsedError;
  bool get showModerationPanel => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  bool get isExiting => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of DiscussionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DiscussionStateCopyWith<DiscussionState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DiscussionStateCopyWith<$Res> {
  factory $DiscussionStateCopyWith(
          DiscussionState value, $Res Function(DiscussionState) then) =
      _$DiscussionStateCopyWithImpl<$Res, DiscussionState>;
  @useResult
  $Res call(
      {String roomId,
      Room room,
      String? currentUserId,
      String? userRole,
      int coinBalance,
      List<DiscussionParticipant> participants,
      Map<String, UserProfile> userProfiles,
      Map<String, dynamic>? userParticipation,
      VoiceState voiceState,
      TimerState timerState,
      NetworkState networkState,
      bool isChatOpen,
      bool showModerationPanel,
      bool isLoading,
      bool isExiting,
      String? error});

  $VoiceStateCopyWith<$Res> get voiceState;
  $TimerStateCopyWith<$Res> get timerState;
  $NetworkStateCopyWith<$Res> get networkState;
}

/// @nodoc
class _$DiscussionStateCopyWithImpl<$Res, $Val extends DiscussionState>
    implements $DiscussionStateCopyWith<$Res> {
  _$DiscussionStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DiscussionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? roomId = null,
    Object? room = null,
    Object? currentUserId = freezed,
    Object? userRole = freezed,
    Object? coinBalance = null,
    Object? participants = null,
    Object? userProfiles = null,
    Object? userParticipation = freezed,
    Object? voiceState = null,
    Object? timerState = null,
    Object? networkState = null,
    Object? isChatOpen = null,
    Object? showModerationPanel = null,
    Object? isLoading = null,
    Object? isExiting = null,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      room: null == room
          ? _value.room
          : room // ignore: cast_nullable_to_non_nullable
              as Room,
      currentUserId: freezed == currentUserId
          ? _value.currentUserId
          : currentUserId // ignore: cast_nullable_to_non_nullable
              as String?,
      userRole: freezed == userRole
          ? _value.userRole
          : userRole // ignore: cast_nullable_to_non_nullable
              as String?,
      coinBalance: null == coinBalance
          ? _value.coinBalance
          : coinBalance // ignore: cast_nullable_to_non_nullable
              as int,
      participants: null == participants
          ? _value.participants
          : participants // ignore: cast_nullable_to_non_nullable
              as List<DiscussionParticipant>,
      userProfiles: null == userProfiles
          ? _value.userProfiles
          : userProfiles // ignore: cast_nullable_to_non_nullable
              as Map<String, UserProfile>,
      userParticipation: freezed == userParticipation
          ? _value.userParticipation
          : userParticipation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      voiceState: null == voiceState
          ? _value.voiceState
          : voiceState // ignore: cast_nullable_to_non_nullable
              as VoiceState,
      timerState: null == timerState
          ? _value.timerState
          : timerState // ignore: cast_nullable_to_non_nullable
              as TimerState,
      networkState: null == networkState
          ? _value.networkState
          : networkState // ignore: cast_nullable_to_non_nullable
              as NetworkState,
      isChatOpen: null == isChatOpen
          ? _value.isChatOpen
          : isChatOpen // ignore: cast_nullable_to_non_nullable
              as bool,
      showModerationPanel: null == showModerationPanel
          ? _value.showModerationPanel
          : showModerationPanel // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isExiting: null == isExiting
          ? _value.isExiting
          : isExiting // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of DiscussionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $VoiceStateCopyWith<$Res> get voiceState {
    return $VoiceStateCopyWith<$Res>(_value.voiceState, (value) {
      return _then(_value.copyWith(voiceState: value) as $Val);
    });
  }

  /// Create a copy of DiscussionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TimerStateCopyWith<$Res> get timerState {
    return $TimerStateCopyWith<$Res>(_value.timerState, (value) {
      return _then(_value.copyWith(timerState: value) as $Val);
    });
  }

  /// Create a copy of DiscussionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NetworkStateCopyWith<$Res> get networkState {
    return $NetworkStateCopyWith<$Res>(_value.networkState, (value) {
      return _then(_value.copyWith(networkState: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$DiscussionStateImplCopyWith<$Res>
    implements $DiscussionStateCopyWith<$Res> {
  factory _$$DiscussionStateImplCopyWith(_$DiscussionStateImpl value,
          $Res Function(_$DiscussionStateImpl) then) =
      __$$DiscussionStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String roomId,
      Room room,
      String? currentUserId,
      String? userRole,
      int coinBalance,
      List<DiscussionParticipant> participants,
      Map<String, UserProfile> userProfiles,
      Map<String, dynamic>? userParticipation,
      VoiceState voiceState,
      TimerState timerState,
      NetworkState networkState,
      bool isChatOpen,
      bool showModerationPanel,
      bool isLoading,
      bool isExiting,
      String? error});

  @override
  $VoiceStateCopyWith<$Res> get voiceState;
  @override
  $TimerStateCopyWith<$Res> get timerState;
  @override
  $NetworkStateCopyWith<$Res> get networkState;
}

/// @nodoc
class __$$DiscussionStateImplCopyWithImpl<$Res>
    extends _$DiscussionStateCopyWithImpl<$Res, _$DiscussionStateImpl>
    implements _$$DiscussionStateImplCopyWith<$Res> {
  __$$DiscussionStateImplCopyWithImpl(
      _$DiscussionStateImpl _value, $Res Function(_$DiscussionStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of DiscussionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? roomId = null,
    Object? room = null,
    Object? currentUserId = freezed,
    Object? userRole = freezed,
    Object? coinBalance = null,
    Object? participants = null,
    Object? userProfiles = null,
    Object? userParticipation = freezed,
    Object? voiceState = null,
    Object? timerState = null,
    Object? networkState = null,
    Object? isChatOpen = null,
    Object? showModerationPanel = null,
    Object? isLoading = null,
    Object? isExiting = null,
    Object? error = freezed,
  }) {
    return _then(_$DiscussionStateImpl(
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      room: null == room
          ? _value.room
          : room // ignore: cast_nullable_to_non_nullable
              as Room,
      currentUserId: freezed == currentUserId
          ? _value.currentUserId
          : currentUserId // ignore: cast_nullable_to_non_nullable
              as String?,
      userRole: freezed == userRole
          ? _value.userRole
          : userRole // ignore: cast_nullable_to_non_nullable
              as String?,
      coinBalance: null == coinBalance
          ? _value.coinBalance
          : coinBalance // ignore: cast_nullable_to_non_nullable
              as int,
      participants: null == participants
          ? _value._participants
          : participants // ignore: cast_nullable_to_non_nullable
              as List<DiscussionParticipant>,
      userProfiles: null == userProfiles
          ? _value._userProfiles
          : userProfiles // ignore: cast_nullable_to_non_nullable
              as Map<String, UserProfile>,
      userParticipation: freezed == userParticipation
          ? _value._userParticipation
          : userParticipation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      voiceState: null == voiceState
          ? _value.voiceState
          : voiceState // ignore: cast_nullable_to_non_nullable
              as VoiceState,
      timerState: null == timerState
          ? _value.timerState
          : timerState // ignore: cast_nullable_to_non_nullable
              as TimerState,
      networkState: null == networkState
          ? _value.networkState
          : networkState // ignore: cast_nullable_to_non_nullable
              as NetworkState,
      isChatOpen: null == isChatOpen
          ? _value.isChatOpen
          : isChatOpen // ignore: cast_nullable_to_non_nullable
              as bool,
      showModerationPanel: null == showModerationPanel
          ? _value.showModerationPanel
          : showModerationPanel // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isExiting: null == isExiting
          ? _value.isExiting
          : isExiting // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$DiscussionStateImpl implements _DiscussionState {
  const _$DiscussionStateImpl(
      {required this.roomId,
      required this.room,
      this.currentUserId,
      this.userRole,
      this.coinBalance = 100,
      final List<DiscussionParticipant> participants = const [],
      final Map<String, UserProfile> userProfiles = const {},
      final Map<String, dynamic>? userParticipation,
      this.voiceState = const VoiceState(),
      this.timerState = const TimerState(),
      this.networkState = const NetworkState(),
      this.isChatOpen = false,
      this.showModerationPanel = false,
      this.isLoading = false,
      this.isExiting = false,
      this.error})
      : _participants = participants,
        _userProfiles = userProfiles,
        _userParticipation = userParticipation;

  @override
  final String roomId;
  @override
  final Room room;
// Current user state
  @override
  final String? currentUserId;
  @override
  final String? userRole;
  @override
  @JsonKey()
  final int coinBalance;
// Room data
  final List<DiscussionParticipant> _participants;
// Room data
  @override
  @JsonKey()
  List<DiscussionParticipant> get participants {
    if (_participants is EqualUnmodifiableListView) return _participants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_participants);
  }

  final Map<String, UserProfile> _userProfiles;
  @override
  @JsonKey()
  Map<String, UserProfile> get userProfiles {
    if (_userProfiles is EqualUnmodifiableMapView) return _userProfiles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_userProfiles);
  }

  final Map<String, dynamic>? _userParticipation;
  @override
  Map<String, dynamic>? get userParticipation {
    final value = _userParticipation;
    if (value == null) return null;
    if (_userParticipation is EqualUnmodifiableMapView)
      return _userParticipation;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

// Voice state
  @override
  @JsonKey()
  final VoiceState voiceState;
// Timer state
  @override
  @JsonKey()
  final TimerState timerState;
// Network state
  @override
  @JsonKey()
  final NetworkState networkState;
// UI state
  @override
  @JsonKey()
  final bool isChatOpen;
  @override
  @JsonKey()
  final bool showModerationPanel;
  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool isExiting;
  @override
  final String? error;

  @override
  String toString() {
    return 'DiscussionState(roomId: $roomId, room: $room, currentUserId: $currentUserId, userRole: $userRole, coinBalance: $coinBalance, participants: $participants, userProfiles: $userProfiles, userParticipation: $userParticipation, voiceState: $voiceState, timerState: $timerState, networkState: $networkState, isChatOpen: $isChatOpen, showModerationPanel: $showModerationPanel, isLoading: $isLoading, isExiting: $isExiting, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DiscussionStateImpl &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.room, room) || other.room == room) &&
            (identical(other.currentUserId, currentUserId) ||
                other.currentUserId == currentUserId) &&
            (identical(other.userRole, userRole) ||
                other.userRole == userRole) &&
            (identical(other.coinBalance, coinBalance) ||
                other.coinBalance == coinBalance) &&
            const DeepCollectionEquality()
                .equals(other._participants, _participants) &&
            const DeepCollectionEquality()
                .equals(other._userProfiles, _userProfiles) &&
            const DeepCollectionEquality()
                .equals(other._userParticipation, _userParticipation) &&
            (identical(other.voiceState, voiceState) ||
                other.voiceState == voiceState) &&
            (identical(other.timerState, timerState) ||
                other.timerState == timerState) &&
            (identical(other.networkState, networkState) ||
                other.networkState == networkState) &&
            (identical(other.isChatOpen, isChatOpen) ||
                other.isChatOpen == isChatOpen) &&
            (identical(other.showModerationPanel, showModerationPanel) ||
                other.showModerationPanel == showModerationPanel) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isExiting, isExiting) ||
                other.isExiting == isExiting) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      roomId,
      room,
      currentUserId,
      userRole,
      coinBalance,
      const DeepCollectionEquality().hash(_participants),
      const DeepCollectionEquality().hash(_userProfiles),
      const DeepCollectionEquality().hash(_userParticipation),
      voiceState,
      timerState,
      networkState,
      isChatOpen,
      showModerationPanel,
      isLoading,
      isExiting,
      error);

  /// Create a copy of DiscussionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DiscussionStateImplCopyWith<_$DiscussionStateImpl> get copyWith =>
      __$$DiscussionStateImplCopyWithImpl<_$DiscussionStateImpl>(
          this, _$identity);
}

abstract class _DiscussionState implements DiscussionState {
  const factory _DiscussionState(
      {required final String roomId,
      required final Room room,
      final String? currentUserId,
      final String? userRole,
      final int coinBalance,
      final List<DiscussionParticipant> participants,
      final Map<String, UserProfile> userProfiles,
      final Map<String, dynamic>? userParticipation,
      final VoiceState voiceState,
      final TimerState timerState,
      final NetworkState networkState,
      final bool isChatOpen,
      final bool showModerationPanel,
      final bool isLoading,
      final bool isExiting,
      final String? error}) = _$DiscussionStateImpl;

  @override
  String get roomId;
  @override
  Room get room; // Current user state
  @override
  String? get currentUserId;
  @override
  String? get userRole;
  @override
  int get coinBalance; // Room data
  @override
  List<DiscussionParticipant> get participants;
  @override
  Map<String, UserProfile> get userProfiles;
  @override
  Map<String, dynamic>? get userParticipation; // Voice state
  @override
  VoiceState get voiceState; // Timer state
  @override
  TimerState get timerState; // Network state
  @override
  NetworkState get networkState; // UI state
  @override
  bool get isChatOpen;
  @override
  bool get showModerationPanel;
  @override
  bool get isLoading;
  @override
  bool get isExiting;
  @override
  String? get error;

  /// Create a copy of DiscussionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DiscussionStateImplCopyWith<_$DiscussionStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
