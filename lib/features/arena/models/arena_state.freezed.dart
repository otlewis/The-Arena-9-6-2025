// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'arena_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ArenaParticipant {
  String get userId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  ArenaRole get role => throw _privateConstructorUsedError;
  String? get avatar => throw _privateConstructorUsedError;
  bool get isReady => throw _privateConstructorUsedError;
  bool get isSpeaking => throw _privateConstructorUsedError;
  bool get hasMicrophone => throw _privateConstructorUsedError;
  bool get hasCamera => throw _privateConstructorUsedError;
  bool get isMuted => throw _privateConstructorUsedError;
  DateTime? get joinedAt => throw _privateConstructorUsedError;
  int? get score => throw _privateConstructorUsedError;

  /// Create a copy of ArenaParticipant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ArenaParticipantCopyWith<ArenaParticipant> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ArenaParticipantCopyWith<$Res> {
  factory $ArenaParticipantCopyWith(
          ArenaParticipant value, $Res Function(ArenaParticipant) then) =
      _$ArenaParticipantCopyWithImpl<$Res, ArenaParticipant>;
  @useResult
  $Res call(
      {String userId,
      String name,
      ArenaRole role,
      String? avatar,
      bool isReady,
      bool isSpeaking,
      bool hasMicrophone,
      bool hasCamera,
      bool isMuted,
      DateTime? joinedAt,
      int? score});
}

/// @nodoc
class _$ArenaParticipantCopyWithImpl<$Res, $Val extends ArenaParticipant>
    implements $ArenaParticipantCopyWith<$Res> {
  _$ArenaParticipantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ArenaParticipant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? name = null,
    Object? role = null,
    Object? avatar = freezed,
    Object? isReady = null,
    Object? isSpeaking = null,
    Object? hasMicrophone = null,
    Object? hasCamera = null,
    Object? isMuted = null,
    Object? joinedAt = freezed,
    Object? score = freezed,
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
              as ArenaRole,
      avatar: freezed == avatar
          ? _value.avatar
          : avatar // ignore: cast_nullable_to_non_nullable
              as String?,
      isReady: null == isReady
          ? _value.isReady
          : isReady // ignore: cast_nullable_to_non_nullable
              as bool,
      isSpeaking: null == isSpeaking
          ? _value.isSpeaking
          : isSpeaking // ignore: cast_nullable_to_non_nullable
              as bool,
      hasMicrophone: null == hasMicrophone
          ? _value.hasMicrophone
          : hasMicrophone // ignore: cast_nullable_to_non_nullable
              as bool,
      hasCamera: null == hasCamera
          ? _value.hasCamera
          : hasCamera // ignore: cast_nullable_to_non_nullable
              as bool,
      isMuted: null == isMuted
          ? _value.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
              as bool,
      joinedAt: freezed == joinedAt
          ? _value.joinedAt
          : joinedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      score: freezed == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ArenaParticipantImplCopyWith<$Res>
    implements $ArenaParticipantCopyWith<$Res> {
  factory _$$ArenaParticipantImplCopyWith(_$ArenaParticipantImpl value,
          $Res Function(_$ArenaParticipantImpl) then) =
      __$$ArenaParticipantImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String userId,
      String name,
      ArenaRole role,
      String? avatar,
      bool isReady,
      bool isSpeaking,
      bool hasMicrophone,
      bool hasCamera,
      bool isMuted,
      DateTime? joinedAt,
      int? score});
}

/// @nodoc
class __$$ArenaParticipantImplCopyWithImpl<$Res>
    extends _$ArenaParticipantCopyWithImpl<$Res, _$ArenaParticipantImpl>
    implements _$$ArenaParticipantImplCopyWith<$Res> {
  __$$ArenaParticipantImplCopyWithImpl(_$ArenaParticipantImpl _value,
      $Res Function(_$ArenaParticipantImpl) _then)
      : super(_value, _then);

  /// Create a copy of ArenaParticipant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? name = null,
    Object? role = null,
    Object? avatar = freezed,
    Object? isReady = null,
    Object? isSpeaking = null,
    Object? hasMicrophone = null,
    Object? hasCamera = null,
    Object? isMuted = null,
    Object? joinedAt = freezed,
    Object? score = freezed,
  }) {
    return _then(_$ArenaParticipantImpl(
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
              as ArenaRole,
      avatar: freezed == avatar
          ? _value.avatar
          : avatar // ignore: cast_nullable_to_non_nullable
              as String?,
      isReady: null == isReady
          ? _value.isReady
          : isReady // ignore: cast_nullable_to_non_nullable
              as bool,
      isSpeaking: null == isSpeaking
          ? _value.isSpeaking
          : isSpeaking // ignore: cast_nullable_to_non_nullable
              as bool,
      hasMicrophone: null == hasMicrophone
          ? _value.hasMicrophone
          : hasMicrophone // ignore: cast_nullable_to_non_nullable
              as bool,
      hasCamera: null == hasCamera
          ? _value.hasCamera
          : hasCamera // ignore: cast_nullable_to_non_nullable
              as bool,
      isMuted: null == isMuted
          ? _value.isMuted
          : isMuted // ignore: cast_nullable_to_non_nullable
              as bool,
      joinedAt: freezed == joinedAt
          ? _value.joinedAt
          : joinedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      score: freezed == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc

class _$ArenaParticipantImpl implements _ArenaParticipant {
  const _$ArenaParticipantImpl(
      {required this.userId,
      required this.name,
      required this.role,
      this.avatar,
      this.isReady = false,
      this.isSpeaking = false,
      this.hasMicrophone = false,
      this.hasCamera = false,
      this.isMuted = false,
      this.joinedAt,
      this.score});

  @override
  final String userId;
  @override
  final String name;
  @override
  final ArenaRole role;
  @override
  final String? avatar;
  @override
  @JsonKey()
  final bool isReady;
  @override
  @JsonKey()
  final bool isSpeaking;
  @override
  @JsonKey()
  final bool hasMicrophone;
  @override
  @JsonKey()
  final bool hasCamera;
  @override
  @JsonKey()
  final bool isMuted;
  @override
  final DateTime? joinedAt;
  @override
  final int? score;

  @override
  String toString() {
    return 'ArenaParticipant(userId: $userId, name: $name, role: $role, avatar: $avatar, isReady: $isReady, isSpeaking: $isSpeaking, hasMicrophone: $hasMicrophone, hasCamera: $hasCamera, isMuted: $isMuted, joinedAt: $joinedAt, score: $score)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ArenaParticipantImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.avatar, avatar) || other.avatar == avatar) &&
            (identical(other.isReady, isReady) || other.isReady == isReady) &&
            (identical(other.isSpeaking, isSpeaking) ||
                other.isSpeaking == isSpeaking) &&
            (identical(other.hasMicrophone, hasMicrophone) ||
                other.hasMicrophone == hasMicrophone) &&
            (identical(other.hasCamera, hasCamera) ||
                other.hasCamera == hasCamera) &&
            (identical(other.isMuted, isMuted) || other.isMuted == isMuted) &&
            (identical(other.joinedAt, joinedAt) ||
                other.joinedAt == joinedAt) &&
            (identical(other.score, score) || other.score == score));
  }

  @override
  int get hashCode => Object.hash(runtimeType, userId, name, role, avatar,
      isReady, isSpeaking, hasMicrophone, hasCamera, isMuted, joinedAt, score);

  /// Create a copy of ArenaParticipant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ArenaParticipantImplCopyWith<_$ArenaParticipantImpl> get copyWith =>
      __$$ArenaParticipantImplCopyWithImpl<_$ArenaParticipantImpl>(
          this, _$identity);
}

abstract class _ArenaParticipant implements ArenaParticipant {
  const factory _ArenaParticipant(
      {required final String userId,
      required final String name,
      required final ArenaRole role,
      final String? avatar,
      final bool isReady,
      final bool isSpeaking,
      final bool hasMicrophone,
      final bool hasCamera,
      final bool isMuted,
      final DateTime? joinedAt,
      final int? score}) = _$ArenaParticipantImpl;

  @override
  String get userId;
  @override
  String get name;
  @override
  ArenaRole get role;
  @override
  String? get avatar;
  @override
  bool get isReady;
  @override
  bool get isSpeaking;
  @override
  bool get hasMicrophone;
  @override
  bool get hasCamera;
  @override
  bool get isMuted;
  @override
  DateTime? get joinedAt;
  @override
  int? get score;

  /// Create a copy of ArenaParticipant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ArenaParticipantImplCopyWith<_$ArenaParticipantImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ArenaState {
  String get roomId => throw _privateConstructorUsedError;
  String get topic => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get category => throw _privateConstructorUsedError;
  String? get challengeId => throw _privateConstructorUsedError;
  String? get challengerId => throw _privateConstructorUsedError;
  String? get challengedId => throw _privateConstructorUsedError;
  ArenaStatus get status => throw _privateConstructorUsedError;
  DebatePhase get currentPhase => throw _privateConstructorUsedError;
  Map<String, ArenaParticipant> get participants =>
      throw _privateConstructorUsedError;
  List<ArenaParticipant> get audience => throw _privateConstructorUsedError;
  String? get currentSpeaker => throw _privateConstructorUsedError;
  int get remainingSeconds => throw _privateConstructorUsedError;
  bool get isTimerRunning => throw _privateConstructorUsedError;
  bool get isPaused => throw _privateConstructorUsedError;
  bool get hasPlayed30SecWarning => throw _privateConstructorUsedError;
  bool get speakingEnabled =>
      throw _privateConstructorUsedError; // Network and connection state
  bool get isRealtimeHealthy => throw _privateConstructorUsedError;
  int get reconnectAttempts =>
      throw _privateConstructorUsedError; // Judging state
  bool get judgingEnabled => throw _privateConstructorUsedError;
  bool get judgingComplete => throw _privateConstructorUsedError;
  bool get hasCurrentUserSubmittedVote => throw _privateConstructorUsedError;
  String? get winner => throw _privateConstructorUsedError; // UI state
  bool get bothDebatersPresent => throw _privateConstructorUsedError;
  bool get invitationModalShown => throw _privateConstructorUsedError;
  bool get invitationsInProgress => throw _privateConstructorUsedError;
  Map<String, String?> get affirmativeSelections =>
      throw _privateConstructorUsedError;
  Map<String, String?> get negativeSelections =>
      throw _privateConstructorUsedError;
  bool get affirmativeCompletedSelection => throw _privateConstructorUsedError;
  bool get negativeCompletedSelection => throw _privateConstructorUsedError;
  bool get waitingForOtherDebater => throw _privateConstructorUsedError;
  bool get resultsModalShown => throw _privateConstructorUsedError;
  bool get roomClosingModalShown => throw _privateConstructorUsedError;
  bool get hasNavigated => throw _privateConstructorUsedError;
  bool get isExiting => throw _privateConstructorUsedError; // User context
  String? get currentUserId => throw _privateConstructorUsedError;
  String? get userRole => throw _privateConstructorUsedError; // Room management
  Map<String, dynamic>? get roomData => throw _privateConstructorUsedError;
  DateTime? get startTime => throw _privateConstructorUsedError;
  DateTime? get endTime => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of ArenaState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ArenaStateCopyWith<ArenaState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ArenaStateCopyWith<$Res> {
  factory $ArenaStateCopyWith(
          ArenaState value, $Res Function(ArenaState) then) =
      _$ArenaStateCopyWithImpl<$Res, ArenaState>;
  @useResult
  $Res call(
      {String roomId,
      String topic,
      String? description,
      String? category,
      String? challengeId,
      String? challengerId,
      String? challengedId,
      ArenaStatus status,
      DebatePhase currentPhase,
      Map<String, ArenaParticipant> participants,
      List<ArenaParticipant> audience,
      String? currentSpeaker,
      int remainingSeconds,
      bool isTimerRunning,
      bool isPaused,
      bool hasPlayed30SecWarning,
      bool speakingEnabled,
      bool isRealtimeHealthy,
      int reconnectAttempts,
      bool judgingEnabled,
      bool judgingComplete,
      bool hasCurrentUserSubmittedVote,
      String? winner,
      bool bothDebatersPresent,
      bool invitationModalShown,
      bool invitationsInProgress,
      Map<String, String?> affirmativeSelections,
      Map<String, String?> negativeSelections,
      bool affirmativeCompletedSelection,
      bool negativeCompletedSelection,
      bool waitingForOtherDebater,
      bool resultsModalShown,
      bool roomClosingModalShown,
      bool hasNavigated,
      bool isExiting,
      String? currentUserId,
      String? userRole,
      Map<String, dynamic>? roomData,
      DateTime? startTime,
      DateTime? endTime,
      bool isLoading,
      String? error});
}

/// @nodoc
class _$ArenaStateCopyWithImpl<$Res, $Val extends ArenaState>
    implements $ArenaStateCopyWith<$Res> {
  _$ArenaStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ArenaState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? roomId = null,
    Object? topic = null,
    Object? description = freezed,
    Object? category = freezed,
    Object? challengeId = freezed,
    Object? challengerId = freezed,
    Object? challengedId = freezed,
    Object? status = null,
    Object? currentPhase = null,
    Object? participants = null,
    Object? audience = null,
    Object? currentSpeaker = freezed,
    Object? remainingSeconds = null,
    Object? isTimerRunning = null,
    Object? isPaused = null,
    Object? hasPlayed30SecWarning = null,
    Object? speakingEnabled = null,
    Object? isRealtimeHealthy = null,
    Object? reconnectAttempts = null,
    Object? judgingEnabled = null,
    Object? judgingComplete = null,
    Object? hasCurrentUserSubmittedVote = null,
    Object? winner = freezed,
    Object? bothDebatersPresent = null,
    Object? invitationModalShown = null,
    Object? invitationsInProgress = null,
    Object? affirmativeSelections = null,
    Object? negativeSelections = null,
    Object? affirmativeCompletedSelection = null,
    Object? negativeCompletedSelection = null,
    Object? waitingForOtherDebater = null,
    Object? resultsModalShown = null,
    Object? roomClosingModalShown = null,
    Object? hasNavigated = null,
    Object? isExiting = null,
    Object? currentUserId = freezed,
    Object? userRole = freezed,
    Object? roomData = freezed,
    Object? startTime = freezed,
    Object? endTime = freezed,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      category: freezed == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      challengeId: freezed == challengeId
          ? _value.challengeId
          : challengeId // ignore: cast_nullable_to_non_nullable
              as String?,
      challengerId: freezed == challengerId
          ? _value.challengerId
          : challengerId // ignore: cast_nullable_to_non_nullable
              as String?,
      challengedId: freezed == challengedId
          ? _value.challengedId
          : challengedId // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ArenaStatus,
      currentPhase: null == currentPhase
          ? _value.currentPhase
          : currentPhase // ignore: cast_nullable_to_non_nullable
              as DebatePhase,
      participants: null == participants
          ? _value.participants
          : participants // ignore: cast_nullable_to_non_nullable
              as Map<String, ArenaParticipant>,
      audience: null == audience
          ? _value.audience
          : audience // ignore: cast_nullable_to_non_nullable
              as List<ArenaParticipant>,
      currentSpeaker: freezed == currentSpeaker
          ? _value.currentSpeaker
          : currentSpeaker // ignore: cast_nullable_to_non_nullable
              as String?,
      remainingSeconds: null == remainingSeconds
          ? _value.remainingSeconds
          : remainingSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      isTimerRunning: null == isTimerRunning
          ? _value.isTimerRunning
          : isTimerRunning // ignore: cast_nullable_to_non_nullable
              as bool,
      isPaused: null == isPaused
          ? _value.isPaused
          : isPaused // ignore: cast_nullable_to_non_nullable
              as bool,
      hasPlayed30SecWarning: null == hasPlayed30SecWarning
          ? _value.hasPlayed30SecWarning
          : hasPlayed30SecWarning // ignore: cast_nullable_to_non_nullable
              as bool,
      speakingEnabled: null == speakingEnabled
          ? _value.speakingEnabled
          : speakingEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      isRealtimeHealthy: null == isRealtimeHealthy
          ? _value.isRealtimeHealthy
          : isRealtimeHealthy // ignore: cast_nullable_to_non_nullable
              as bool,
      reconnectAttempts: null == reconnectAttempts
          ? _value.reconnectAttempts
          : reconnectAttempts // ignore: cast_nullable_to_non_nullable
              as int,
      judgingEnabled: null == judgingEnabled
          ? _value.judgingEnabled
          : judgingEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      judgingComplete: null == judgingComplete
          ? _value.judgingComplete
          : judgingComplete // ignore: cast_nullable_to_non_nullable
              as bool,
      hasCurrentUserSubmittedVote: null == hasCurrentUserSubmittedVote
          ? _value.hasCurrentUserSubmittedVote
          : hasCurrentUserSubmittedVote // ignore: cast_nullable_to_non_nullable
              as bool,
      winner: freezed == winner
          ? _value.winner
          : winner // ignore: cast_nullable_to_non_nullable
              as String?,
      bothDebatersPresent: null == bothDebatersPresent
          ? _value.bothDebatersPresent
          : bothDebatersPresent // ignore: cast_nullable_to_non_nullable
              as bool,
      invitationModalShown: null == invitationModalShown
          ? _value.invitationModalShown
          : invitationModalShown // ignore: cast_nullable_to_non_nullable
              as bool,
      invitationsInProgress: null == invitationsInProgress
          ? _value.invitationsInProgress
          : invitationsInProgress // ignore: cast_nullable_to_non_nullable
              as bool,
      affirmativeSelections: null == affirmativeSelections
          ? _value.affirmativeSelections
          : affirmativeSelections // ignore: cast_nullable_to_non_nullable
              as Map<String, String?>,
      negativeSelections: null == negativeSelections
          ? _value.negativeSelections
          : negativeSelections // ignore: cast_nullable_to_non_nullable
              as Map<String, String?>,
      affirmativeCompletedSelection: null == affirmativeCompletedSelection
          ? _value.affirmativeCompletedSelection
          : affirmativeCompletedSelection // ignore: cast_nullable_to_non_nullable
              as bool,
      negativeCompletedSelection: null == negativeCompletedSelection
          ? _value.negativeCompletedSelection
          : negativeCompletedSelection // ignore: cast_nullable_to_non_nullable
              as bool,
      waitingForOtherDebater: null == waitingForOtherDebater
          ? _value.waitingForOtherDebater
          : waitingForOtherDebater // ignore: cast_nullable_to_non_nullable
              as bool,
      resultsModalShown: null == resultsModalShown
          ? _value.resultsModalShown
          : resultsModalShown // ignore: cast_nullable_to_non_nullable
              as bool,
      roomClosingModalShown: null == roomClosingModalShown
          ? _value.roomClosingModalShown
          : roomClosingModalShown // ignore: cast_nullable_to_non_nullable
              as bool,
      hasNavigated: null == hasNavigated
          ? _value.hasNavigated
          : hasNavigated // ignore: cast_nullable_to_non_nullable
              as bool,
      isExiting: null == isExiting
          ? _value.isExiting
          : isExiting // ignore: cast_nullable_to_non_nullable
              as bool,
      currentUserId: freezed == currentUserId
          ? _value.currentUserId
          : currentUserId // ignore: cast_nullable_to_non_nullable
              as String?,
      userRole: freezed == userRole
          ? _value.userRole
          : userRole // ignore: cast_nullable_to_non_nullable
              as String?,
      roomData: freezed == roomData
          ? _value.roomData
          : roomData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      startTime: freezed == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endTime: freezed == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ArenaStateImplCopyWith<$Res>
    implements $ArenaStateCopyWith<$Res> {
  factory _$$ArenaStateImplCopyWith(
          _$ArenaStateImpl value, $Res Function(_$ArenaStateImpl) then) =
      __$$ArenaStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String roomId,
      String topic,
      String? description,
      String? category,
      String? challengeId,
      String? challengerId,
      String? challengedId,
      ArenaStatus status,
      DebatePhase currentPhase,
      Map<String, ArenaParticipant> participants,
      List<ArenaParticipant> audience,
      String? currentSpeaker,
      int remainingSeconds,
      bool isTimerRunning,
      bool isPaused,
      bool hasPlayed30SecWarning,
      bool speakingEnabled,
      bool isRealtimeHealthy,
      int reconnectAttempts,
      bool judgingEnabled,
      bool judgingComplete,
      bool hasCurrentUserSubmittedVote,
      String? winner,
      bool bothDebatersPresent,
      bool invitationModalShown,
      bool invitationsInProgress,
      Map<String, String?> affirmativeSelections,
      Map<String, String?> negativeSelections,
      bool affirmativeCompletedSelection,
      bool negativeCompletedSelection,
      bool waitingForOtherDebater,
      bool resultsModalShown,
      bool roomClosingModalShown,
      bool hasNavigated,
      bool isExiting,
      String? currentUserId,
      String? userRole,
      Map<String, dynamic>? roomData,
      DateTime? startTime,
      DateTime? endTime,
      bool isLoading,
      String? error});
}

/// @nodoc
class __$$ArenaStateImplCopyWithImpl<$Res>
    extends _$ArenaStateCopyWithImpl<$Res, _$ArenaStateImpl>
    implements _$$ArenaStateImplCopyWith<$Res> {
  __$$ArenaStateImplCopyWithImpl(
      _$ArenaStateImpl _value, $Res Function(_$ArenaStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ArenaState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? roomId = null,
    Object? topic = null,
    Object? description = freezed,
    Object? category = freezed,
    Object? challengeId = freezed,
    Object? challengerId = freezed,
    Object? challengedId = freezed,
    Object? status = null,
    Object? currentPhase = null,
    Object? participants = null,
    Object? audience = null,
    Object? currentSpeaker = freezed,
    Object? remainingSeconds = null,
    Object? isTimerRunning = null,
    Object? isPaused = null,
    Object? hasPlayed30SecWarning = null,
    Object? speakingEnabled = null,
    Object? isRealtimeHealthy = null,
    Object? reconnectAttempts = null,
    Object? judgingEnabled = null,
    Object? judgingComplete = null,
    Object? hasCurrentUserSubmittedVote = null,
    Object? winner = freezed,
    Object? bothDebatersPresent = null,
    Object? invitationModalShown = null,
    Object? invitationsInProgress = null,
    Object? affirmativeSelections = null,
    Object? negativeSelections = null,
    Object? affirmativeCompletedSelection = null,
    Object? negativeCompletedSelection = null,
    Object? waitingForOtherDebater = null,
    Object? resultsModalShown = null,
    Object? roomClosingModalShown = null,
    Object? hasNavigated = null,
    Object? isExiting = null,
    Object? currentUserId = freezed,
    Object? userRole = freezed,
    Object? roomData = freezed,
    Object? startTime = freezed,
    Object? endTime = freezed,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(_$ArenaStateImpl(
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      category: freezed == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      challengeId: freezed == challengeId
          ? _value.challengeId
          : challengeId // ignore: cast_nullable_to_non_nullable
              as String?,
      challengerId: freezed == challengerId
          ? _value.challengerId
          : challengerId // ignore: cast_nullable_to_non_nullable
              as String?,
      challengedId: freezed == challengedId
          ? _value.challengedId
          : challengedId // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ArenaStatus,
      currentPhase: null == currentPhase
          ? _value.currentPhase
          : currentPhase // ignore: cast_nullable_to_non_nullable
              as DebatePhase,
      participants: null == participants
          ? _value._participants
          : participants // ignore: cast_nullable_to_non_nullable
              as Map<String, ArenaParticipant>,
      audience: null == audience
          ? _value._audience
          : audience // ignore: cast_nullable_to_non_nullable
              as List<ArenaParticipant>,
      currentSpeaker: freezed == currentSpeaker
          ? _value.currentSpeaker
          : currentSpeaker // ignore: cast_nullable_to_non_nullable
              as String?,
      remainingSeconds: null == remainingSeconds
          ? _value.remainingSeconds
          : remainingSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      isTimerRunning: null == isTimerRunning
          ? _value.isTimerRunning
          : isTimerRunning // ignore: cast_nullable_to_non_nullable
              as bool,
      isPaused: null == isPaused
          ? _value.isPaused
          : isPaused // ignore: cast_nullable_to_non_nullable
              as bool,
      hasPlayed30SecWarning: null == hasPlayed30SecWarning
          ? _value.hasPlayed30SecWarning
          : hasPlayed30SecWarning // ignore: cast_nullable_to_non_nullable
              as bool,
      speakingEnabled: null == speakingEnabled
          ? _value.speakingEnabled
          : speakingEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      isRealtimeHealthy: null == isRealtimeHealthy
          ? _value.isRealtimeHealthy
          : isRealtimeHealthy // ignore: cast_nullable_to_non_nullable
              as bool,
      reconnectAttempts: null == reconnectAttempts
          ? _value.reconnectAttempts
          : reconnectAttempts // ignore: cast_nullable_to_non_nullable
              as int,
      judgingEnabled: null == judgingEnabled
          ? _value.judgingEnabled
          : judgingEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      judgingComplete: null == judgingComplete
          ? _value.judgingComplete
          : judgingComplete // ignore: cast_nullable_to_non_nullable
              as bool,
      hasCurrentUserSubmittedVote: null == hasCurrentUserSubmittedVote
          ? _value.hasCurrentUserSubmittedVote
          : hasCurrentUserSubmittedVote // ignore: cast_nullable_to_non_nullable
              as bool,
      winner: freezed == winner
          ? _value.winner
          : winner // ignore: cast_nullable_to_non_nullable
              as String?,
      bothDebatersPresent: null == bothDebatersPresent
          ? _value.bothDebatersPresent
          : bothDebatersPresent // ignore: cast_nullable_to_non_nullable
              as bool,
      invitationModalShown: null == invitationModalShown
          ? _value.invitationModalShown
          : invitationModalShown // ignore: cast_nullable_to_non_nullable
              as bool,
      invitationsInProgress: null == invitationsInProgress
          ? _value.invitationsInProgress
          : invitationsInProgress // ignore: cast_nullable_to_non_nullable
              as bool,
      affirmativeSelections: null == affirmativeSelections
          ? _value._affirmativeSelections
          : affirmativeSelections // ignore: cast_nullable_to_non_nullable
              as Map<String, String?>,
      negativeSelections: null == negativeSelections
          ? _value._negativeSelections
          : negativeSelections // ignore: cast_nullable_to_non_nullable
              as Map<String, String?>,
      affirmativeCompletedSelection: null == affirmativeCompletedSelection
          ? _value.affirmativeCompletedSelection
          : affirmativeCompletedSelection // ignore: cast_nullable_to_non_nullable
              as bool,
      negativeCompletedSelection: null == negativeCompletedSelection
          ? _value.negativeCompletedSelection
          : negativeCompletedSelection // ignore: cast_nullable_to_non_nullable
              as bool,
      waitingForOtherDebater: null == waitingForOtherDebater
          ? _value.waitingForOtherDebater
          : waitingForOtherDebater // ignore: cast_nullable_to_non_nullable
              as bool,
      resultsModalShown: null == resultsModalShown
          ? _value.resultsModalShown
          : resultsModalShown // ignore: cast_nullable_to_non_nullable
              as bool,
      roomClosingModalShown: null == roomClosingModalShown
          ? _value.roomClosingModalShown
          : roomClosingModalShown // ignore: cast_nullable_to_non_nullable
              as bool,
      hasNavigated: null == hasNavigated
          ? _value.hasNavigated
          : hasNavigated // ignore: cast_nullable_to_non_nullable
              as bool,
      isExiting: null == isExiting
          ? _value.isExiting
          : isExiting // ignore: cast_nullable_to_non_nullable
              as bool,
      currentUserId: freezed == currentUserId
          ? _value.currentUserId
          : currentUserId // ignore: cast_nullable_to_non_nullable
              as String?,
      userRole: freezed == userRole
          ? _value.userRole
          : userRole // ignore: cast_nullable_to_non_nullable
              as String?,
      roomData: freezed == roomData
          ? _value._roomData
          : roomData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      startTime: freezed == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endTime: freezed == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$ArenaStateImpl extends _ArenaState {
  const _$ArenaStateImpl(
      {required this.roomId,
      required this.topic,
      this.description,
      this.category,
      this.challengeId,
      this.challengerId,
      this.challengedId,
      this.status = ArenaStatus.waiting,
      this.currentPhase = DebatePhase.preDebate,
      final Map<String, ArenaParticipant> participants = const {},
      final List<ArenaParticipant> audience = const [],
      this.currentSpeaker,
      this.remainingSeconds = 0,
      this.isTimerRunning = false,
      this.isPaused = false,
      this.hasPlayed30SecWarning = false,
      this.speakingEnabled = false,
      this.isRealtimeHealthy = true,
      this.reconnectAttempts = 0,
      this.judgingEnabled = false,
      this.judgingComplete = false,
      this.hasCurrentUserSubmittedVote = false,
      this.winner,
      this.bothDebatersPresent = false,
      this.invitationModalShown = false,
      this.invitationsInProgress = false,
      final Map<String, String?> affirmativeSelections = const {},
      final Map<String, String?> negativeSelections = const {},
      this.affirmativeCompletedSelection = false,
      this.negativeCompletedSelection = false,
      this.waitingForOtherDebater = false,
      this.resultsModalShown = false,
      this.roomClosingModalShown = false,
      this.hasNavigated = false,
      this.isExiting = false,
      this.currentUserId,
      this.userRole,
      final Map<String, dynamic>? roomData,
      this.startTime,
      this.endTime,
      this.isLoading = false,
      this.error})
      : _participants = participants,
        _audience = audience,
        _affirmativeSelections = affirmativeSelections,
        _negativeSelections = negativeSelections,
        _roomData = roomData,
        super._();

  @override
  final String roomId;
  @override
  final String topic;
  @override
  final String? description;
  @override
  final String? category;
  @override
  final String? challengeId;
  @override
  final String? challengerId;
  @override
  final String? challengedId;
  @override
  @JsonKey()
  final ArenaStatus status;
  @override
  @JsonKey()
  final DebatePhase currentPhase;
  final Map<String, ArenaParticipant> _participants;
  @override
  @JsonKey()
  Map<String, ArenaParticipant> get participants {
    if (_participants is EqualUnmodifiableMapView) return _participants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_participants);
  }

  final List<ArenaParticipant> _audience;
  @override
  @JsonKey()
  List<ArenaParticipant> get audience {
    if (_audience is EqualUnmodifiableListView) return _audience;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_audience);
  }

  @override
  final String? currentSpeaker;
  @override
  @JsonKey()
  final int remainingSeconds;
  @override
  @JsonKey()
  final bool isTimerRunning;
  @override
  @JsonKey()
  final bool isPaused;
  @override
  @JsonKey()
  final bool hasPlayed30SecWarning;
  @override
  @JsonKey()
  final bool speakingEnabled;
// Network and connection state
  @override
  @JsonKey()
  final bool isRealtimeHealthy;
  @override
  @JsonKey()
  final int reconnectAttempts;
// Judging state
  @override
  @JsonKey()
  final bool judgingEnabled;
  @override
  @JsonKey()
  final bool judgingComplete;
  @override
  @JsonKey()
  final bool hasCurrentUserSubmittedVote;
  @override
  final String? winner;
// UI state
  @override
  @JsonKey()
  final bool bothDebatersPresent;
  @override
  @JsonKey()
  final bool invitationModalShown;
  @override
  @JsonKey()
  final bool invitationsInProgress;
  final Map<String, String?> _affirmativeSelections;
  @override
  @JsonKey()
  Map<String, String?> get affirmativeSelections {
    if (_affirmativeSelections is EqualUnmodifiableMapView)
      return _affirmativeSelections;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_affirmativeSelections);
  }

  final Map<String, String?> _negativeSelections;
  @override
  @JsonKey()
  Map<String, String?> get negativeSelections {
    if (_negativeSelections is EqualUnmodifiableMapView)
      return _negativeSelections;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_negativeSelections);
  }

  @override
  @JsonKey()
  final bool affirmativeCompletedSelection;
  @override
  @JsonKey()
  final bool negativeCompletedSelection;
  @override
  @JsonKey()
  final bool waitingForOtherDebater;
  @override
  @JsonKey()
  final bool resultsModalShown;
  @override
  @JsonKey()
  final bool roomClosingModalShown;
  @override
  @JsonKey()
  final bool hasNavigated;
  @override
  @JsonKey()
  final bool isExiting;
// User context
  @override
  final String? currentUserId;
  @override
  final String? userRole;
// Room management
  final Map<String, dynamic>? _roomData;
// Room management
  @override
  Map<String, dynamic>? get roomData {
    final value = _roomData;
    if (value == null) return null;
    if (_roomData is EqualUnmodifiableMapView) return _roomData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final DateTime? startTime;
  @override
  final DateTime? endTime;
  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  @override
  String toString() {
    return 'ArenaState(roomId: $roomId, topic: $topic, description: $description, category: $category, challengeId: $challengeId, challengerId: $challengerId, challengedId: $challengedId, status: $status, currentPhase: $currentPhase, participants: $participants, audience: $audience, currentSpeaker: $currentSpeaker, remainingSeconds: $remainingSeconds, isTimerRunning: $isTimerRunning, isPaused: $isPaused, hasPlayed30SecWarning: $hasPlayed30SecWarning, speakingEnabled: $speakingEnabled, isRealtimeHealthy: $isRealtimeHealthy, reconnectAttempts: $reconnectAttempts, judgingEnabled: $judgingEnabled, judgingComplete: $judgingComplete, hasCurrentUserSubmittedVote: $hasCurrentUserSubmittedVote, winner: $winner, bothDebatersPresent: $bothDebatersPresent, invitationModalShown: $invitationModalShown, invitationsInProgress: $invitationsInProgress, affirmativeSelections: $affirmativeSelections, negativeSelections: $negativeSelections, affirmativeCompletedSelection: $affirmativeCompletedSelection, negativeCompletedSelection: $negativeCompletedSelection, waitingForOtherDebater: $waitingForOtherDebater, resultsModalShown: $resultsModalShown, roomClosingModalShown: $roomClosingModalShown, hasNavigated: $hasNavigated, isExiting: $isExiting, currentUserId: $currentUserId, userRole: $userRole, roomData: $roomData, startTime: $startTime, endTime: $endTime, isLoading: $isLoading, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ArenaStateImpl &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.topic, topic) || other.topic == topic) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.challengeId, challengeId) ||
                other.challengeId == challengeId) &&
            (identical(other.challengerId, challengerId) ||
                other.challengerId == challengerId) &&
            (identical(other.challengedId, challengedId) ||
                other.challengedId == challengedId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.currentPhase, currentPhase) ||
                other.currentPhase == currentPhase) &&
            const DeepCollectionEquality()
                .equals(other._participants, _participants) &&
            const DeepCollectionEquality().equals(other._audience, _audience) &&
            (identical(other.currentSpeaker, currentSpeaker) ||
                other.currentSpeaker == currentSpeaker) &&
            (identical(other.remainingSeconds, remainingSeconds) ||
                other.remainingSeconds == remainingSeconds) &&
            (identical(other.isTimerRunning, isTimerRunning) ||
                other.isTimerRunning == isTimerRunning) &&
            (identical(other.isPaused, isPaused) ||
                other.isPaused == isPaused) &&
            (identical(other.hasPlayed30SecWarning, hasPlayed30SecWarning) ||
                other.hasPlayed30SecWarning == hasPlayed30SecWarning) &&
            (identical(other.speakingEnabled, speakingEnabled) ||
                other.speakingEnabled == speakingEnabled) &&
            (identical(other.isRealtimeHealthy, isRealtimeHealthy) ||
                other.isRealtimeHealthy == isRealtimeHealthy) &&
            (identical(other.reconnectAttempts, reconnectAttempts) ||
                other.reconnectAttempts == reconnectAttempts) &&
            (identical(other.judgingEnabled, judgingEnabled) ||
                other.judgingEnabled == judgingEnabled) &&
            (identical(other.judgingComplete, judgingComplete) ||
                other.judgingComplete == judgingComplete) &&
            (identical(other.hasCurrentUserSubmittedVote, hasCurrentUserSubmittedVote) ||
                other.hasCurrentUserSubmittedVote ==
                    hasCurrentUserSubmittedVote) &&
            (identical(other.winner, winner) || other.winner == winner) &&
            (identical(other.bothDebatersPresent, bothDebatersPresent) ||
                other.bothDebatersPresent == bothDebatersPresent) &&
            (identical(other.invitationModalShown, invitationModalShown) ||
                other.invitationModalShown == invitationModalShown) &&
            (identical(other.invitationsInProgress, invitationsInProgress) ||
                other.invitationsInProgress == invitationsInProgress) &&
            const DeepCollectionEquality()
                .equals(other._affirmativeSelections, _affirmativeSelections) &&
            const DeepCollectionEquality()
                .equals(other._negativeSelections, _negativeSelections) &&
            (identical(other.affirmativeCompletedSelection,
                    affirmativeCompletedSelection) ||
                other.affirmativeCompletedSelection ==
                    affirmativeCompletedSelection) &&
            (identical(other.negativeCompletedSelection, negativeCompletedSelection) ||
                other.negativeCompletedSelection ==
                    negativeCompletedSelection) &&
            (identical(other.waitingForOtherDebater, waitingForOtherDebater) ||
                other.waitingForOtherDebater == waitingForOtherDebater) &&
            (identical(other.resultsModalShown, resultsModalShown) ||
                other.resultsModalShown == resultsModalShown) &&
            (identical(other.roomClosingModalShown, roomClosingModalShown) ||
                other.roomClosingModalShown == roomClosingModalShown) &&
            (identical(other.hasNavigated, hasNavigated) ||
                other.hasNavigated == hasNavigated) &&
            (identical(other.isExiting, isExiting) ||
                other.isExiting == isExiting) &&
            (identical(other.currentUserId, currentUserId) ||
                other.currentUserId == currentUserId) &&
            (identical(other.userRole, userRole) ||
                other.userRole == userRole) &&
            const DeepCollectionEquality().equals(other._roomData, _roomData) &&
            (identical(other.startTime, startTime) || other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.isLoading, isLoading) || other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        roomId,
        topic,
        description,
        category,
        challengeId,
        challengerId,
        challengedId,
        status,
        currentPhase,
        const DeepCollectionEquality().hash(_participants),
        const DeepCollectionEquality().hash(_audience),
        currentSpeaker,
        remainingSeconds,
        isTimerRunning,
        isPaused,
        hasPlayed30SecWarning,
        speakingEnabled,
        isRealtimeHealthy,
        reconnectAttempts,
        judgingEnabled,
        judgingComplete,
        hasCurrentUserSubmittedVote,
        winner,
        bothDebatersPresent,
        invitationModalShown,
        invitationsInProgress,
        const DeepCollectionEquality().hash(_affirmativeSelections),
        const DeepCollectionEquality().hash(_negativeSelections),
        affirmativeCompletedSelection,
        negativeCompletedSelection,
        waitingForOtherDebater,
        resultsModalShown,
        roomClosingModalShown,
        hasNavigated,
        isExiting,
        currentUserId,
        userRole,
        const DeepCollectionEquality().hash(_roomData),
        startTime,
        endTime,
        isLoading,
        error
      ]);

  /// Create a copy of ArenaState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ArenaStateImplCopyWith<_$ArenaStateImpl> get copyWith =>
      __$$ArenaStateImplCopyWithImpl<_$ArenaStateImpl>(this, _$identity);
}

abstract class _ArenaState extends ArenaState {
  const factory _ArenaState(
      {required final String roomId,
      required final String topic,
      final String? description,
      final String? category,
      final String? challengeId,
      final String? challengerId,
      final String? challengedId,
      final ArenaStatus status,
      final DebatePhase currentPhase,
      final Map<String, ArenaParticipant> participants,
      final List<ArenaParticipant> audience,
      final String? currentSpeaker,
      final int remainingSeconds,
      final bool isTimerRunning,
      final bool isPaused,
      final bool hasPlayed30SecWarning,
      final bool speakingEnabled,
      final bool isRealtimeHealthy,
      final int reconnectAttempts,
      final bool judgingEnabled,
      final bool judgingComplete,
      final bool hasCurrentUserSubmittedVote,
      final String? winner,
      final bool bothDebatersPresent,
      final bool invitationModalShown,
      final bool invitationsInProgress,
      final Map<String, String?> affirmativeSelections,
      final Map<String, String?> negativeSelections,
      final bool affirmativeCompletedSelection,
      final bool negativeCompletedSelection,
      final bool waitingForOtherDebater,
      final bool resultsModalShown,
      final bool roomClosingModalShown,
      final bool hasNavigated,
      final bool isExiting,
      final String? currentUserId,
      final String? userRole,
      final Map<String, dynamic>? roomData,
      final DateTime? startTime,
      final DateTime? endTime,
      final bool isLoading,
      final String? error}) = _$ArenaStateImpl;
  const _ArenaState._() : super._();

  @override
  String get roomId;
  @override
  String get topic;
  @override
  String? get description;
  @override
  String? get category;
  @override
  String? get challengeId;
  @override
  String? get challengerId;
  @override
  String? get challengedId;
  @override
  ArenaStatus get status;
  @override
  DebatePhase get currentPhase;
  @override
  Map<String, ArenaParticipant> get participants;
  @override
  List<ArenaParticipant> get audience;
  @override
  String? get currentSpeaker;
  @override
  int get remainingSeconds;
  @override
  bool get isTimerRunning;
  @override
  bool get isPaused;
  @override
  bool get hasPlayed30SecWarning;
  @override
  bool get speakingEnabled; // Network and connection state
  @override
  bool get isRealtimeHealthy;
  @override
  int get reconnectAttempts; // Judging state
  @override
  bool get judgingEnabled;
  @override
  bool get judgingComplete;
  @override
  bool get hasCurrentUserSubmittedVote;
  @override
  String? get winner; // UI state
  @override
  bool get bothDebatersPresent;
  @override
  bool get invitationModalShown;
  @override
  bool get invitationsInProgress;
  @override
  Map<String, String?> get affirmativeSelections;
  @override
  Map<String, String?> get negativeSelections;
  @override
  bool get affirmativeCompletedSelection;
  @override
  bool get negativeCompletedSelection;
  @override
  bool get waitingForOtherDebater;
  @override
  bool get resultsModalShown;
  @override
  bool get roomClosingModalShown;
  @override
  bool get hasNavigated;
  @override
  bool get isExiting; // User context
  @override
  String? get currentUserId;
  @override
  String? get userRole; // Room management
  @override
  Map<String, dynamic>? get roomData;
  @override
  DateTime? get startTime;
  @override
  DateTime? get endTime;
  @override
  bool get isLoading;
  @override
  String? get error;

  /// Create a copy of ArenaState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ArenaStateImplCopyWith<_$ArenaStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
