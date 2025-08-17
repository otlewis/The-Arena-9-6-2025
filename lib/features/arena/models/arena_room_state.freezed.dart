// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'arena_room_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ArenaRoomState {
// Room information
  String get roomId => throw _privateConstructorUsedError;
  String get challengeId => throw _privateConstructorUsedError;
  String get topic => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get category => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError; // Participants
  Map<String, UserProfile> get participants =>
      throw _privateConstructorUsedError;
  List<UserProfile> get audience =>
      throw _privateConstructorUsedError; // Current user
  UserProfile? get currentUser => throw _privateConstructorUsedError;
  ParticipantRole get currentUserRole =>
      throw _privateConstructorUsedError; // Debate state
  DebatePhase get currentPhase => throw _privateConstructorUsedError;
  String? get currentSpeaker => throw _privateConstructorUsedError;
  bool get speakingEnabled => throw _privateConstructorUsedError;
  bool get bothDebatersPresent =>
      throw _privateConstructorUsedError; // Timer state
  int get remainingSeconds => throw _privateConstructorUsedError;
  bool get isTimerRunning => throw _privateConstructorUsedError;
  bool get isTimerPaused => throw _privateConstructorUsedError;
  bool get hasPlayed30SecWarning =>
      throw _privateConstructorUsedError; // Judging state
  bool get judgingEnabled => throw _privateConstructorUsedError;
  bool get judgingComplete => throw _privateConstructorUsedError;
  bool get hasCurrentUserSubmittedVote => throw _privateConstructorUsedError;
  String? get winner => throw _privateConstructorUsedError; // Invitation state
  bool get invitationsInProgress => throw _privateConstructorUsedError;
  List<String> get affirmativeSelections => throw _privateConstructorUsedError;
  List<String> get negativeSelections => throw _privateConstructorUsedError;
  bool get affirmativeCompletedSelection => throw _privateConstructorUsedError;
  bool get negativeCompletedSelection => throw _privateConstructorUsedError;
  bool get invitationModalShown => throw _privateConstructorUsedError;
  bool get waitingForOtherDebater =>
      throw _privateConstructorUsedError; // UI state
  bool get isLoading => throw _privateConstructorUsedError;
  bool get resultsModalShown => throw _privateConstructorUsedError;
  bool get roomClosingModalShown => throw _privateConstructorUsedError;
  bool get hasNavigated => throw _privateConstructorUsedError;
  bool get isExiting => throw _privateConstructorUsedError; // Error state
  String? get error => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ArenaRoomStateCopyWith<ArenaRoomState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ArenaRoomStateCopyWith<$Res> {
  factory $ArenaRoomStateCopyWith(
          ArenaRoomState value, $Res Function(ArenaRoomState) then) =
      _$ArenaRoomStateCopyWithImpl<$Res, ArenaRoomState>;
  @useResult
  $Res call(
      {String roomId,
      String challengeId,
      String topic,
      String? description,
      String? category,
      String status,
      Map<String, UserProfile> participants,
      List<UserProfile> audience,
      UserProfile? currentUser,
      ParticipantRole currentUserRole,
      DebatePhase currentPhase,
      String? currentSpeaker,
      bool speakingEnabled,
      bool bothDebatersPresent,
      int remainingSeconds,
      bool isTimerRunning,
      bool isTimerPaused,
      bool hasPlayed30SecWarning,
      bool judgingEnabled,
      bool judgingComplete,
      bool hasCurrentUserSubmittedVote,
      String? winner,
      bool invitationsInProgress,
      List<String> affirmativeSelections,
      List<String> negativeSelections,
      bool affirmativeCompletedSelection,
      bool negativeCompletedSelection,
      bool invitationModalShown,
      bool waitingForOtherDebater,
      bool isLoading,
      bool resultsModalShown,
      bool roomClosingModalShown,
      bool hasNavigated,
      bool isExiting,
      String? error});
}

/// @nodoc
class _$ArenaRoomStateCopyWithImpl<$Res, $Val extends ArenaRoomState>
    implements $ArenaRoomStateCopyWith<$Res> {
  _$ArenaRoomStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? roomId = null,
    Object? challengeId = null,
    Object? topic = null,
    Object? description = freezed,
    Object? category = freezed,
    Object? status = null,
    Object? participants = null,
    Object? audience = null,
    Object? currentUser = freezed,
    Object? currentUserRole = null,
    Object? currentPhase = null,
    Object? currentSpeaker = freezed,
    Object? speakingEnabled = null,
    Object? bothDebatersPresent = null,
    Object? remainingSeconds = null,
    Object? isTimerRunning = null,
    Object? isTimerPaused = null,
    Object? hasPlayed30SecWarning = null,
    Object? judgingEnabled = null,
    Object? judgingComplete = null,
    Object? hasCurrentUserSubmittedVote = null,
    Object? winner = freezed,
    Object? invitationsInProgress = null,
    Object? affirmativeSelections = null,
    Object? negativeSelections = null,
    Object? affirmativeCompletedSelection = null,
    Object? negativeCompletedSelection = null,
    Object? invitationModalShown = null,
    Object? waitingForOtherDebater = null,
    Object? isLoading = null,
    Object? resultsModalShown = null,
    Object? roomClosingModalShown = null,
    Object? hasNavigated = null,
    Object? isExiting = null,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      challengeId: null == challengeId
          ? _value.challengeId
          : challengeId // ignore: cast_nullable_to_non_nullable
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
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      participants: null == participants
          ? _value.participants
          : participants // ignore: cast_nullable_to_non_nullable
              as Map<String, UserProfile>,
      audience: null == audience
          ? _value.audience
          : audience // ignore: cast_nullable_to_non_nullable
              as List<UserProfile>,
      currentUser: freezed == currentUser
          ? _value.currentUser
          : currentUser // ignore: cast_nullable_to_non_nullable
              as UserProfile?,
      currentUserRole: null == currentUserRole
          ? _value.currentUserRole
          : currentUserRole // ignore: cast_nullable_to_non_nullable
              as ParticipantRole,
      currentPhase: null == currentPhase
          ? _value.currentPhase
          : currentPhase // ignore: cast_nullable_to_non_nullable
              as DebatePhase,
      currentSpeaker: freezed == currentSpeaker
          ? _value.currentSpeaker
          : currentSpeaker // ignore: cast_nullable_to_non_nullable
              as String?,
      speakingEnabled: null == speakingEnabled
          ? _value.speakingEnabled
          : speakingEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      bothDebatersPresent: null == bothDebatersPresent
          ? _value.bothDebatersPresent
          : bothDebatersPresent // ignore: cast_nullable_to_non_nullable
              as bool,
      remainingSeconds: null == remainingSeconds
          ? _value.remainingSeconds
          : remainingSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      isTimerRunning: null == isTimerRunning
          ? _value.isTimerRunning
          : isTimerRunning // ignore: cast_nullable_to_non_nullable
              as bool,
      isTimerPaused: null == isTimerPaused
          ? _value.isTimerPaused
          : isTimerPaused // ignore: cast_nullable_to_non_nullable
              as bool,
      hasPlayed30SecWarning: null == hasPlayed30SecWarning
          ? _value.hasPlayed30SecWarning
          : hasPlayed30SecWarning // ignore: cast_nullable_to_non_nullable
              as bool,
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
      invitationsInProgress: null == invitationsInProgress
          ? _value.invitationsInProgress
          : invitationsInProgress // ignore: cast_nullable_to_non_nullable
              as bool,
      affirmativeSelections: null == affirmativeSelections
          ? _value.affirmativeSelections
          : affirmativeSelections // ignore: cast_nullable_to_non_nullable
              as List<String>,
      negativeSelections: null == negativeSelections
          ? _value.negativeSelections
          : negativeSelections // ignore: cast_nullable_to_non_nullable
              as List<String>,
      affirmativeCompletedSelection: null == affirmativeCompletedSelection
          ? _value.affirmativeCompletedSelection
          : affirmativeCompletedSelection // ignore: cast_nullable_to_non_nullable
              as bool,
      negativeCompletedSelection: null == negativeCompletedSelection
          ? _value.negativeCompletedSelection
          : negativeCompletedSelection // ignore: cast_nullable_to_non_nullable
              as bool,
      invitationModalShown: null == invitationModalShown
          ? _value.invitationModalShown
          : invitationModalShown // ignore: cast_nullable_to_non_nullable
              as bool,
      waitingForOtherDebater: null == waitingForOtherDebater
          ? _value.waitingForOtherDebater
          : waitingForOtherDebater // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
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
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ArenaRoomStateImplCopyWith<$Res>
    implements $ArenaRoomStateCopyWith<$Res> {
  factory _$$ArenaRoomStateImplCopyWith(_$ArenaRoomStateImpl value,
          $Res Function(_$ArenaRoomStateImpl) then) =
      __$$ArenaRoomStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String roomId,
      String challengeId,
      String topic,
      String? description,
      String? category,
      String status,
      Map<String, UserProfile> participants,
      List<UserProfile> audience,
      UserProfile? currentUser,
      ParticipantRole currentUserRole,
      DebatePhase currentPhase,
      String? currentSpeaker,
      bool speakingEnabled,
      bool bothDebatersPresent,
      int remainingSeconds,
      bool isTimerRunning,
      bool isTimerPaused,
      bool hasPlayed30SecWarning,
      bool judgingEnabled,
      bool judgingComplete,
      bool hasCurrentUserSubmittedVote,
      String? winner,
      bool invitationsInProgress,
      List<String> affirmativeSelections,
      List<String> negativeSelections,
      bool affirmativeCompletedSelection,
      bool negativeCompletedSelection,
      bool invitationModalShown,
      bool waitingForOtherDebater,
      bool isLoading,
      bool resultsModalShown,
      bool roomClosingModalShown,
      bool hasNavigated,
      bool isExiting,
      String? error});
}

/// @nodoc
class __$$ArenaRoomStateImplCopyWithImpl<$Res>
    extends _$ArenaRoomStateCopyWithImpl<$Res, _$ArenaRoomStateImpl>
    implements _$$ArenaRoomStateImplCopyWith<$Res> {
  __$$ArenaRoomStateImplCopyWithImpl(
      _$ArenaRoomStateImpl _value, $Res Function(_$ArenaRoomStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? roomId = null,
    Object? challengeId = null,
    Object? topic = null,
    Object? description = freezed,
    Object? category = freezed,
    Object? status = null,
    Object? participants = null,
    Object? audience = null,
    Object? currentUser = freezed,
    Object? currentUserRole = null,
    Object? currentPhase = null,
    Object? currentSpeaker = freezed,
    Object? speakingEnabled = null,
    Object? bothDebatersPresent = null,
    Object? remainingSeconds = null,
    Object? isTimerRunning = null,
    Object? isTimerPaused = null,
    Object? hasPlayed30SecWarning = null,
    Object? judgingEnabled = null,
    Object? judgingComplete = null,
    Object? hasCurrentUserSubmittedVote = null,
    Object? winner = freezed,
    Object? invitationsInProgress = null,
    Object? affirmativeSelections = null,
    Object? negativeSelections = null,
    Object? affirmativeCompletedSelection = null,
    Object? negativeCompletedSelection = null,
    Object? invitationModalShown = null,
    Object? waitingForOtherDebater = null,
    Object? isLoading = null,
    Object? resultsModalShown = null,
    Object? roomClosingModalShown = null,
    Object? hasNavigated = null,
    Object? isExiting = null,
    Object? error = freezed,
  }) {
    return _then(_$ArenaRoomStateImpl(
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      challengeId: null == challengeId
          ? _value.challengeId
          : challengeId // ignore: cast_nullable_to_non_nullable
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
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      participants: null == participants
          ? _value._participants
          : participants // ignore: cast_nullable_to_non_nullable
              as Map<String, UserProfile>,
      audience: null == audience
          ? _value._audience
          : audience // ignore: cast_nullable_to_non_nullable
              as List<UserProfile>,
      currentUser: freezed == currentUser
          ? _value.currentUser
          : currentUser // ignore: cast_nullable_to_non_nullable
              as UserProfile?,
      currentUserRole: null == currentUserRole
          ? _value.currentUserRole
          : currentUserRole // ignore: cast_nullable_to_non_nullable
              as ParticipantRole,
      currentPhase: null == currentPhase
          ? _value.currentPhase
          : currentPhase // ignore: cast_nullable_to_non_nullable
              as DebatePhase,
      currentSpeaker: freezed == currentSpeaker
          ? _value.currentSpeaker
          : currentSpeaker // ignore: cast_nullable_to_non_nullable
              as String?,
      speakingEnabled: null == speakingEnabled
          ? _value.speakingEnabled
          : speakingEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      bothDebatersPresent: null == bothDebatersPresent
          ? _value.bothDebatersPresent
          : bothDebatersPresent // ignore: cast_nullable_to_non_nullable
              as bool,
      remainingSeconds: null == remainingSeconds
          ? _value.remainingSeconds
          : remainingSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      isTimerRunning: null == isTimerRunning
          ? _value.isTimerRunning
          : isTimerRunning // ignore: cast_nullable_to_non_nullable
              as bool,
      isTimerPaused: null == isTimerPaused
          ? _value.isTimerPaused
          : isTimerPaused // ignore: cast_nullable_to_non_nullable
              as bool,
      hasPlayed30SecWarning: null == hasPlayed30SecWarning
          ? _value.hasPlayed30SecWarning
          : hasPlayed30SecWarning // ignore: cast_nullable_to_non_nullable
              as bool,
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
      invitationsInProgress: null == invitationsInProgress
          ? _value.invitationsInProgress
          : invitationsInProgress // ignore: cast_nullable_to_non_nullable
              as bool,
      affirmativeSelections: null == affirmativeSelections
          ? _value._affirmativeSelections
          : affirmativeSelections // ignore: cast_nullable_to_non_nullable
              as List<String>,
      negativeSelections: null == negativeSelections
          ? _value._negativeSelections
          : negativeSelections // ignore: cast_nullable_to_non_nullable
              as List<String>,
      affirmativeCompletedSelection: null == affirmativeCompletedSelection
          ? _value.affirmativeCompletedSelection
          : affirmativeCompletedSelection // ignore: cast_nullable_to_non_nullable
              as bool,
      negativeCompletedSelection: null == negativeCompletedSelection
          ? _value.negativeCompletedSelection
          : negativeCompletedSelection // ignore: cast_nullable_to_non_nullable
              as bool,
      invitationModalShown: null == invitationModalShown
          ? _value.invitationModalShown
          : invitationModalShown // ignore: cast_nullable_to_non_nullable
              as bool,
      waitingForOtherDebater: null == waitingForOtherDebater
          ? _value.waitingForOtherDebater
          : waitingForOtherDebater // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
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
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$ArenaRoomStateImpl extends _ArenaRoomState {
  const _$ArenaRoomStateImpl(
      {required this.roomId,
      required this.challengeId,
      required this.topic,
      this.description,
      this.category,
      this.status = 'active',
      final Map<String, UserProfile> participants = const {},
      final List<UserProfile> audience = const [],
      this.currentUser,
      this.currentUserRole = ParticipantRole.audience,
      this.currentPhase = DebatePhase.preDebate,
      this.currentSpeaker,
      this.speakingEnabled = false,
      this.bothDebatersPresent = false,
      this.remainingSeconds = 0,
      this.isTimerRunning = false,
      this.isTimerPaused = false,
      this.hasPlayed30SecWarning = false,
      this.judgingEnabled = false,
      this.judgingComplete = false,
      this.hasCurrentUserSubmittedVote = false,
      this.winner,
      this.invitationsInProgress = false,
      final List<String> affirmativeSelections = const [],
      final List<String> negativeSelections = const [],
      this.affirmativeCompletedSelection = false,
      this.negativeCompletedSelection = false,
      this.invitationModalShown = false,
      this.waitingForOtherDebater = false,
      this.isLoading = false,
      this.resultsModalShown = false,
      this.roomClosingModalShown = false,
      this.hasNavigated = false,
      this.isExiting = false,
      this.error})
      : _participants = participants,
        _audience = audience,
        _affirmativeSelections = affirmativeSelections,
        _negativeSelections = negativeSelections,
        super._();

// Room information
  @override
  final String roomId;
  @override
  final String challengeId;
  @override
  final String topic;
  @override
  final String? description;
  @override
  final String? category;
  @override
  @JsonKey()
  final String status;
// Participants
  final Map<String, UserProfile> _participants;
// Participants
  @override
  @JsonKey()
  Map<String, UserProfile> get participants {
    if (_participants is EqualUnmodifiableMapView) return _participants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_participants);
  }

  final List<UserProfile> _audience;
  @override
  @JsonKey()
  List<UserProfile> get audience {
    if (_audience is EqualUnmodifiableListView) return _audience;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_audience);
  }

// Current user
  @override
  final UserProfile? currentUser;
  @override
  @JsonKey()
  final ParticipantRole currentUserRole;
// Debate state
  @override
  @JsonKey()
  final DebatePhase currentPhase;
  @override
  final String? currentSpeaker;
  @override
  @JsonKey()
  final bool speakingEnabled;
  @override
  @JsonKey()
  final bool bothDebatersPresent;
// Timer state
  @override
  @JsonKey()
  final int remainingSeconds;
  @override
  @JsonKey()
  final bool isTimerRunning;
  @override
  @JsonKey()
  final bool isTimerPaused;
  @override
  @JsonKey()
  final bool hasPlayed30SecWarning;
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
// Invitation state
  @override
  @JsonKey()
  final bool invitationsInProgress;
  final List<String> _affirmativeSelections;
  @override
  @JsonKey()
  List<String> get affirmativeSelections {
    if (_affirmativeSelections is EqualUnmodifiableListView)
      return _affirmativeSelections;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_affirmativeSelections);
  }

  final List<String> _negativeSelections;
  @override
  @JsonKey()
  List<String> get negativeSelections {
    if (_negativeSelections is EqualUnmodifiableListView)
      return _negativeSelections;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_negativeSelections);
  }

  @override
  @JsonKey()
  final bool affirmativeCompletedSelection;
  @override
  @JsonKey()
  final bool negativeCompletedSelection;
  @override
  @JsonKey()
  final bool invitationModalShown;
  @override
  @JsonKey()
  final bool waitingForOtherDebater;
// UI state
  @override
  @JsonKey()
  final bool isLoading;
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
// Error state
  @override
  final String? error;

  @override
  String toString() {
    return 'ArenaRoomState(roomId: $roomId, challengeId: $challengeId, topic: $topic, description: $description, category: $category, status: $status, participants: $participants, audience: $audience, currentUser: $currentUser, currentUserRole: $currentUserRole, currentPhase: $currentPhase, currentSpeaker: $currentSpeaker, speakingEnabled: $speakingEnabled, bothDebatersPresent: $bothDebatersPresent, remainingSeconds: $remainingSeconds, isTimerRunning: $isTimerRunning, isTimerPaused: $isTimerPaused, hasPlayed30SecWarning: $hasPlayed30SecWarning, judgingEnabled: $judgingEnabled, judgingComplete: $judgingComplete, hasCurrentUserSubmittedVote: $hasCurrentUserSubmittedVote, winner: $winner, invitationsInProgress: $invitationsInProgress, affirmativeSelections: $affirmativeSelections, negativeSelections: $negativeSelections, affirmativeCompletedSelection: $affirmativeCompletedSelection, negativeCompletedSelection: $negativeCompletedSelection, invitationModalShown: $invitationModalShown, waitingForOtherDebater: $waitingForOtherDebater, isLoading: $isLoading, resultsModalShown: $resultsModalShown, roomClosingModalShown: $roomClosingModalShown, hasNavigated: $hasNavigated, isExiting: $isExiting, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ArenaRoomStateImpl &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.challengeId, challengeId) ||
                other.challengeId == challengeId) &&
            (identical(other.topic, topic) || other.topic == topic) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality()
                .equals(other._participants, _participants) &&
            const DeepCollectionEquality().equals(other._audience, _audience) &&
            (identical(other.currentUser, currentUser) ||
                other.currentUser == currentUser) &&
            (identical(other.currentUserRole, currentUserRole) ||
                other.currentUserRole == currentUserRole) &&
            (identical(other.currentPhase, currentPhase) ||
                other.currentPhase == currentPhase) &&
            (identical(other.currentSpeaker, currentSpeaker) ||
                other.currentSpeaker == currentSpeaker) &&
            (identical(other.speakingEnabled, speakingEnabled) ||
                other.speakingEnabled == speakingEnabled) &&
            (identical(other.bothDebatersPresent, bothDebatersPresent) ||
                other.bothDebatersPresent == bothDebatersPresent) &&
            (identical(other.remainingSeconds, remainingSeconds) ||
                other.remainingSeconds == remainingSeconds) &&
            (identical(other.isTimerRunning, isTimerRunning) ||
                other.isTimerRunning == isTimerRunning) &&
            (identical(other.isTimerPaused, isTimerPaused) ||
                other.isTimerPaused == isTimerPaused) &&
            (identical(other.hasPlayed30SecWarning, hasPlayed30SecWarning) ||
                other.hasPlayed30SecWarning == hasPlayed30SecWarning) &&
            (identical(other.judgingEnabled, judgingEnabled) ||
                other.judgingEnabled == judgingEnabled) &&
            (identical(other.judgingComplete, judgingComplete) ||
                other.judgingComplete == judgingComplete) &&
            (identical(other.hasCurrentUserSubmittedVote,
                    hasCurrentUserSubmittedVote) ||
                other.hasCurrentUserSubmittedVote ==
                    hasCurrentUserSubmittedVote) &&
            (identical(other.winner, winner) || other.winner == winner) &&
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
            (identical(other.invitationModalShown, invitationModalShown) ||
                other.invitationModalShown == invitationModalShown) &&
            (identical(other.waitingForOtherDebater, waitingForOtherDebater) ||
                other.waitingForOtherDebater == waitingForOtherDebater) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.resultsModalShown, resultsModalShown) ||
                other.resultsModalShown == resultsModalShown) &&
            (identical(other.roomClosingModalShown, roomClosingModalShown) ||
                other.roomClosingModalShown == roomClosingModalShown) &&
            (identical(other.hasNavigated, hasNavigated) ||
                other.hasNavigated == hasNavigated) &&
            (identical(other.isExiting, isExiting) || other.isExiting == isExiting) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        roomId,
        challengeId,
        topic,
        description,
        category,
        status,
        const DeepCollectionEquality().hash(_participants),
        const DeepCollectionEquality().hash(_audience),
        currentUser,
        currentUserRole,
        currentPhase,
        currentSpeaker,
        speakingEnabled,
        bothDebatersPresent,
        remainingSeconds,
        isTimerRunning,
        isTimerPaused,
        hasPlayed30SecWarning,
        judgingEnabled,
        judgingComplete,
        hasCurrentUserSubmittedVote,
        winner,
        invitationsInProgress,
        const DeepCollectionEquality().hash(_affirmativeSelections),
        const DeepCollectionEquality().hash(_negativeSelections),
        affirmativeCompletedSelection,
        negativeCompletedSelection,
        invitationModalShown,
        waitingForOtherDebater,
        isLoading,
        resultsModalShown,
        roomClosingModalShown,
        hasNavigated,
        isExiting,
        error
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ArenaRoomStateImplCopyWith<_$ArenaRoomStateImpl> get copyWith =>
      __$$ArenaRoomStateImplCopyWithImpl<_$ArenaRoomStateImpl>(
          this, _$identity);
}

abstract class _ArenaRoomState extends ArenaRoomState {
  const factory _ArenaRoomState(
      {required final String roomId,
      required final String challengeId,
      required final String topic,
      final String? description,
      final String? category,
      final String status,
      final Map<String, UserProfile> participants,
      final List<UserProfile> audience,
      final UserProfile? currentUser,
      final ParticipantRole currentUserRole,
      final DebatePhase currentPhase,
      final String? currentSpeaker,
      final bool speakingEnabled,
      final bool bothDebatersPresent,
      final int remainingSeconds,
      final bool isTimerRunning,
      final bool isTimerPaused,
      final bool hasPlayed30SecWarning,
      final bool judgingEnabled,
      final bool judgingComplete,
      final bool hasCurrentUserSubmittedVote,
      final String? winner,
      final bool invitationsInProgress,
      final List<String> affirmativeSelections,
      final List<String> negativeSelections,
      final bool affirmativeCompletedSelection,
      final bool negativeCompletedSelection,
      final bool invitationModalShown,
      final bool waitingForOtherDebater,
      final bool isLoading,
      final bool resultsModalShown,
      final bool roomClosingModalShown,
      final bool hasNavigated,
      final bool isExiting,
      final String? error}) = _$ArenaRoomStateImpl;
  const _ArenaRoomState._() : super._();

  @override // Room information
  String get roomId;
  @override
  String get challengeId;
  @override
  String get topic;
  @override
  String? get description;
  @override
  String? get category;
  @override
  String get status;
  @override // Participants
  Map<String, UserProfile> get participants;
  @override
  List<UserProfile> get audience;
  @override // Current user
  UserProfile? get currentUser;
  @override
  ParticipantRole get currentUserRole;
  @override // Debate state
  DebatePhase get currentPhase;
  @override
  String? get currentSpeaker;
  @override
  bool get speakingEnabled;
  @override
  bool get bothDebatersPresent;
  @override // Timer state
  int get remainingSeconds;
  @override
  bool get isTimerRunning;
  @override
  bool get isTimerPaused;
  @override
  bool get hasPlayed30SecWarning;
  @override // Judging state
  bool get judgingEnabled;
  @override
  bool get judgingComplete;
  @override
  bool get hasCurrentUserSubmittedVote;
  @override
  String? get winner;
  @override // Invitation state
  bool get invitationsInProgress;
  @override
  List<String> get affirmativeSelections;
  @override
  List<String> get negativeSelections;
  @override
  bool get affirmativeCompletedSelection;
  @override
  bool get negativeCompletedSelection;
  @override
  bool get invitationModalShown;
  @override
  bool get waitingForOtherDebater;
  @override // UI state
  bool get isLoading;
  @override
  bool get resultsModalShown;
  @override
  bool get roomClosingModalShown;
  @override
  bool get hasNavigated;
  @override
  bool get isExiting;
  @override // Error state
  String? get error;
  @override
  @JsonKey(ignore: true)
  _$$ArenaRoomStateImplCopyWith<_$ArenaRoomStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
