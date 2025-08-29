// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_report.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserReport _$UserReportFromJson(Map<String, dynamic> json) {
  return _UserReport.fromJson(json);
}

/// @nodoc
mixin _$UserReport {
  String get id => throw _privateConstructorUsedError;
  String get reporterId => throw _privateConstructorUsedError;
  String get reportedUserId => throw _privateConstructorUsedError;
  String get roomId => throw _privateConstructorUsedError;
  String get reportType => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  ReportEvidence get evidence => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get moderatorId => throw _privateConstructorUsedError;
  String? get resolution => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UserReportCopyWith<UserReport> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserReportCopyWith<$Res> {
  factory $UserReportCopyWith(
          UserReport value, $Res Function(UserReport) then) =
      _$UserReportCopyWithImpl<$Res, UserReport>;
  @useResult
  $Res call(
      {String id,
      String reporterId,
      String reportedUserId,
      String roomId,
      String reportType,
      String description,
      ReportEvidence evidence,
      String status,
      String? moderatorId,
      String? resolution,
      DateTime createdAt,
      DateTime updatedAt});

  $ReportEvidenceCopyWith<$Res> get evidence;
}

/// @nodoc
class _$UserReportCopyWithImpl<$Res, $Val extends UserReport>
    implements $UserReportCopyWith<$Res> {
  _$UserReportCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? reporterId = null,
    Object? reportedUserId = null,
    Object? roomId = null,
    Object? reportType = null,
    Object? description = null,
    Object? evidence = null,
    Object? status = null,
    Object? moderatorId = freezed,
    Object? resolution = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      reporterId: null == reporterId
          ? _value.reporterId
          : reporterId // ignore: cast_nullable_to_non_nullable
              as String,
      reportedUserId: null == reportedUserId
          ? _value.reportedUserId
          : reportedUserId // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      reportType: null == reportType
          ? _value.reportType
          : reportType // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      evidence: null == evidence
          ? _value.evidence
          : evidence // ignore: cast_nullable_to_non_nullable
              as ReportEvidence,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      moderatorId: freezed == moderatorId
          ? _value.moderatorId
          : moderatorId // ignore: cast_nullable_to_non_nullable
              as String?,
      resolution: freezed == resolution
          ? _value.resolution
          : resolution // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $ReportEvidenceCopyWith<$Res> get evidence {
    return $ReportEvidenceCopyWith<$Res>(_value.evidence, (value) {
      return _then(_value.copyWith(evidence: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$UserReportImplCopyWith<$Res>
    implements $UserReportCopyWith<$Res> {
  factory _$$UserReportImplCopyWith(
          _$UserReportImpl value, $Res Function(_$UserReportImpl) then) =
      __$$UserReportImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String reporterId,
      String reportedUserId,
      String roomId,
      String reportType,
      String description,
      ReportEvidence evidence,
      String status,
      String? moderatorId,
      String? resolution,
      DateTime createdAt,
      DateTime updatedAt});

  @override
  $ReportEvidenceCopyWith<$Res> get evidence;
}

/// @nodoc
class __$$UserReportImplCopyWithImpl<$Res>
    extends _$UserReportCopyWithImpl<$Res, _$UserReportImpl>
    implements _$$UserReportImplCopyWith<$Res> {
  __$$UserReportImplCopyWithImpl(
      _$UserReportImpl _value, $Res Function(_$UserReportImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? reporterId = null,
    Object? reportedUserId = null,
    Object? roomId = null,
    Object? reportType = null,
    Object? description = null,
    Object? evidence = null,
    Object? status = null,
    Object? moderatorId = freezed,
    Object? resolution = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$UserReportImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      reporterId: null == reporterId
          ? _value.reporterId
          : reporterId // ignore: cast_nullable_to_non_nullable
              as String,
      reportedUserId: null == reportedUserId
          ? _value.reportedUserId
          : reportedUserId // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      reportType: null == reportType
          ? _value.reportType
          : reportType // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      evidence: null == evidence
          ? _value.evidence
          : evidence // ignore: cast_nullable_to_non_nullable
              as ReportEvidence,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      moderatorId: freezed == moderatorId
          ? _value.moderatorId
          : moderatorId // ignore: cast_nullable_to_non_nullable
              as String?,
      resolution: freezed == resolution
          ? _value.resolution
          : resolution // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserReportImpl implements _UserReport {
  const _$UserReportImpl(
      {required this.id,
      required this.reporterId,
      required this.reportedUserId,
      required this.roomId,
      required this.reportType,
      required this.description,
      required this.evidence,
      required this.status,
      this.moderatorId,
      this.resolution,
      required this.createdAt,
      required this.updatedAt});

  factory _$UserReportImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserReportImplFromJson(json);

  @override
  final String id;
  @override
  final String reporterId;
  @override
  final String reportedUserId;
  @override
  final String roomId;
  @override
  final String reportType;
  @override
  final String description;
  @override
  final ReportEvidence evidence;
  @override
  final String status;
  @override
  final String? moderatorId;
  @override
  final String? resolution;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'UserReport(id: $id, reporterId: $reporterId, reportedUserId: $reportedUserId, roomId: $roomId, reportType: $reportType, description: $description, evidence: $evidence, status: $status, moderatorId: $moderatorId, resolution: $resolution, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserReportImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.reporterId, reporterId) ||
                other.reporterId == reporterId) &&
            (identical(other.reportedUserId, reportedUserId) ||
                other.reportedUserId == reportedUserId) &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.reportType, reportType) ||
                other.reportType == reportType) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.evidence, evidence) ||
                other.evidence == evidence) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.moderatorId, moderatorId) ||
                other.moderatorId == moderatorId) &&
            (identical(other.resolution, resolution) ||
                other.resolution == resolution) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      reporterId,
      reportedUserId,
      roomId,
      reportType,
      description,
      evidence,
      status,
      moderatorId,
      resolution,
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UserReportImplCopyWith<_$UserReportImpl> get copyWith =>
      __$$UserReportImplCopyWithImpl<_$UserReportImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserReportImplToJson(
      this,
    );
  }
}

abstract class _UserReport implements UserReport {
  const factory _UserReport(
      {required final String id,
      required final String reporterId,
      required final String reportedUserId,
      required final String roomId,
      required final String reportType,
      required final String description,
      required final ReportEvidence evidence,
      required final String status,
      final String? moderatorId,
      final String? resolution,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$UserReportImpl;

  factory _UserReport.fromJson(Map<String, dynamic> json) =
      _$UserReportImpl.fromJson;

  @override
  String get id;
  @override
  String get reporterId;
  @override
  String get reportedUserId;
  @override
  String get roomId;
  @override
  String get reportType;
  @override
  String get description;
  @override
  ReportEvidence get evidence;
  @override
  String get status;
  @override
  String? get moderatorId;
  @override
  String? get resolution;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$UserReportImplCopyWith<_$UserReportImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ReportEvidence _$ReportEvidenceFromJson(Map<String, dynamic> json) {
  return _ReportEvidence.fromJson(json);
}

/// @nodoc
mixin _$ReportEvidence {
  String? get messageId => throw _privateConstructorUsedError;
  String? get screenshot => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ReportEvidenceCopyWith<ReportEvidence> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReportEvidenceCopyWith<$Res> {
  factory $ReportEvidenceCopyWith(
          ReportEvidence value, $Res Function(ReportEvidence) then) =
      _$ReportEvidenceCopyWithImpl<$Res, ReportEvidence>;
  @useResult
  $Res call({String? messageId, String? screenshot, DateTime timestamp});
}

/// @nodoc
class _$ReportEvidenceCopyWithImpl<$Res, $Val extends ReportEvidence>
    implements $ReportEvidenceCopyWith<$Res> {
  _$ReportEvidenceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? messageId = freezed,
    Object? screenshot = freezed,
    Object? timestamp = null,
  }) {
    return _then(_value.copyWith(
      messageId: freezed == messageId
          ? _value.messageId
          : messageId // ignore: cast_nullable_to_non_nullable
              as String?,
      screenshot: freezed == screenshot
          ? _value.screenshot
          : screenshot // ignore: cast_nullable_to_non_nullable
              as String?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReportEvidenceImplCopyWith<$Res>
    implements $ReportEvidenceCopyWith<$Res> {
  factory _$$ReportEvidenceImplCopyWith(_$ReportEvidenceImpl value,
          $Res Function(_$ReportEvidenceImpl) then) =
      __$$ReportEvidenceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? messageId, String? screenshot, DateTime timestamp});
}

/// @nodoc
class __$$ReportEvidenceImplCopyWithImpl<$Res>
    extends _$ReportEvidenceCopyWithImpl<$Res, _$ReportEvidenceImpl>
    implements _$$ReportEvidenceImplCopyWith<$Res> {
  __$$ReportEvidenceImplCopyWithImpl(
      _$ReportEvidenceImpl _value, $Res Function(_$ReportEvidenceImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? messageId = freezed,
    Object? screenshot = freezed,
    Object? timestamp = null,
  }) {
    return _then(_$ReportEvidenceImpl(
      messageId: freezed == messageId
          ? _value.messageId
          : messageId // ignore: cast_nullable_to_non_nullable
              as String?,
      screenshot: freezed == screenshot
          ? _value.screenshot
          : screenshot // ignore: cast_nullable_to_non_nullable
              as String?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReportEvidenceImpl implements _ReportEvidence {
  const _$ReportEvidenceImpl(
      {this.messageId, this.screenshot, required this.timestamp});

  factory _$ReportEvidenceImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReportEvidenceImplFromJson(json);

  @override
  final String? messageId;
  @override
  final String? screenshot;
  @override
  final DateTime timestamp;

  @override
  String toString() {
    return 'ReportEvidence(messageId: $messageId, screenshot: $screenshot, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReportEvidenceImpl &&
            (identical(other.messageId, messageId) ||
                other.messageId == messageId) &&
            (identical(other.screenshot, screenshot) ||
                other.screenshot == screenshot) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, messageId, screenshot, timestamp);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ReportEvidenceImplCopyWith<_$ReportEvidenceImpl> get copyWith =>
      __$$ReportEvidenceImplCopyWithImpl<_$ReportEvidenceImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReportEvidenceImplToJson(
      this,
    );
  }
}

abstract class _ReportEvidence implements ReportEvidence {
  const factory _ReportEvidence(
      {final String? messageId,
      final String? screenshot,
      required final DateTime timestamp}) = _$ReportEvidenceImpl;

  factory _ReportEvidence.fromJson(Map<String, dynamic> json) =
      _$ReportEvidenceImpl.fromJson;

  @override
  String? get messageId;
  @override
  String? get screenshot;
  @override
  DateTime get timestamp;
  @override
  @JsonKey(ignore: true)
  _$$ReportEvidenceImplCopyWith<_$ReportEvidenceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ModerationAction _$ModerationActionFromJson(Map<String, dynamic> json) {
  return _ModerationAction.fromJson(json);
}

/// @nodoc
mixin _$ModerationAction {
  String get id => throw _privateConstructorUsedError;
  String get moderatorId => throw _privateConstructorUsedError;
  String get targetUserId => throw _privateConstructorUsedError;
  String? get roomId => throw _privateConstructorUsedError;
  String get action => throw _privateConstructorUsedError;
  int? get duration => throw _privateConstructorUsedError;
  String get reason => throw _privateConstructorUsedError;
  String? get reportId => throw _privateConstructorUsedError;
  bool get automated => throw _privateConstructorUsedError;
  AIScore? get aiScore => throw _privateConstructorUsedError;
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ModerationActionCopyWith<ModerationAction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ModerationActionCopyWith<$Res> {
  factory $ModerationActionCopyWith(
          ModerationAction value, $Res Function(ModerationAction) then) =
      _$ModerationActionCopyWithImpl<$Res, ModerationAction>;
  @useResult
  $Res call(
      {String id,
      String moderatorId,
      String targetUserId,
      String? roomId,
      String action,
      int? duration,
      String reason,
      String? reportId,
      bool automated,
      AIScore? aiScore,
      DateTime? expiresAt,
      DateTime createdAt});

  $AIScoreCopyWith<$Res>? get aiScore;
}

/// @nodoc
class _$ModerationActionCopyWithImpl<$Res, $Val extends ModerationAction>
    implements $ModerationActionCopyWith<$Res> {
  _$ModerationActionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? moderatorId = null,
    Object? targetUserId = null,
    Object? roomId = freezed,
    Object? action = null,
    Object? duration = freezed,
    Object? reason = null,
    Object? reportId = freezed,
    Object? automated = null,
    Object? aiScore = freezed,
    Object? expiresAt = freezed,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      moderatorId: null == moderatorId
          ? _value.moderatorId
          : moderatorId // ignore: cast_nullable_to_non_nullable
              as String,
      targetUserId: null == targetUserId
          ? _value.targetUserId
          : targetUserId // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: freezed == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String?,
      action: null == action
          ? _value.action
          : action // ignore: cast_nullable_to_non_nullable
              as String,
      duration: freezed == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int?,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      reportId: freezed == reportId
          ? _value.reportId
          : reportId // ignore: cast_nullable_to_non_nullable
              as String?,
      automated: null == automated
          ? _value.automated
          : automated // ignore: cast_nullable_to_non_nullable
              as bool,
      aiScore: freezed == aiScore
          ? _value.aiScore
          : aiScore // ignore: cast_nullable_to_non_nullable
              as AIScore?,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $AIScoreCopyWith<$Res>? get aiScore {
    if (_value.aiScore == null) {
      return null;
    }

    return $AIScoreCopyWith<$Res>(_value.aiScore!, (value) {
      return _then(_value.copyWith(aiScore: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ModerationActionImplCopyWith<$Res>
    implements $ModerationActionCopyWith<$Res> {
  factory _$$ModerationActionImplCopyWith(_$ModerationActionImpl value,
          $Res Function(_$ModerationActionImpl) then) =
      __$$ModerationActionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String moderatorId,
      String targetUserId,
      String? roomId,
      String action,
      int? duration,
      String reason,
      String? reportId,
      bool automated,
      AIScore? aiScore,
      DateTime? expiresAt,
      DateTime createdAt});

  @override
  $AIScoreCopyWith<$Res>? get aiScore;
}

/// @nodoc
class __$$ModerationActionImplCopyWithImpl<$Res>
    extends _$ModerationActionCopyWithImpl<$Res, _$ModerationActionImpl>
    implements _$$ModerationActionImplCopyWith<$Res> {
  __$$ModerationActionImplCopyWithImpl(_$ModerationActionImpl _value,
      $Res Function(_$ModerationActionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? moderatorId = null,
    Object? targetUserId = null,
    Object? roomId = freezed,
    Object? action = null,
    Object? duration = freezed,
    Object? reason = null,
    Object? reportId = freezed,
    Object? automated = null,
    Object? aiScore = freezed,
    Object? expiresAt = freezed,
    Object? createdAt = null,
  }) {
    return _then(_$ModerationActionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      moderatorId: null == moderatorId
          ? _value.moderatorId
          : moderatorId // ignore: cast_nullable_to_non_nullable
              as String,
      targetUserId: null == targetUserId
          ? _value.targetUserId
          : targetUserId // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: freezed == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String?,
      action: null == action
          ? _value.action
          : action // ignore: cast_nullable_to_non_nullable
              as String,
      duration: freezed == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int?,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      reportId: freezed == reportId
          ? _value.reportId
          : reportId // ignore: cast_nullable_to_non_nullable
              as String?,
      automated: null == automated
          ? _value.automated
          : automated // ignore: cast_nullable_to_non_nullable
              as bool,
      aiScore: freezed == aiScore
          ? _value.aiScore
          : aiScore // ignore: cast_nullable_to_non_nullable
              as AIScore?,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ModerationActionImpl implements _ModerationAction {
  const _$ModerationActionImpl(
      {required this.id,
      required this.moderatorId,
      required this.targetUserId,
      this.roomId,
      required this.action,
      this.duration,
      required this.reason,
      this.reportId,
      required this.automated,
      this.aiScore,
      this.expiresAt,
      required this.createdAt});

  factory _$ModerationActionImpl.fromJson(Map<String, dynamic> json) =>
      _$$ModerationActionImplFromJson(json);

  @override
  final String id;
  @override
  final String moderatorId;
  @override
  final String targetUserId;
  @override
  final String? roomId;
  @override
  final String action;
  @override
  final int? duration;
  @override
  final String reason;
  @override
  final String? reportId;
  @override
  final bool automated;
  @override
  final AIScore? aiScore;
  @override
  final DateTime? expiresAt;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'ModerationAction(id: $id, moderatorId: $moderatorId, targetUserId: $targetUserId, roomId: $roomId, action: $action, duration: $duration, reason: $reason, reportId: $reportId, automated: $automated, aiScore: $aiScore, expiresAt: $expiresAt, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ModerationActionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.moderatorId, moderatorId) ||
                other.moderatorId == moderatorId) &&
            (identical(other.targetUserId, targetUserId) ||
                other.targetUserId == targetUserId) &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.reportId, reportId) ||
                other.reportId == reportId) &&
            (identical(other.automated, automated) ||
                other.automated == automated) &&
            (identical(other.aiScore, aiScore) || other.aiScore == aiScore) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      moderatorId,
      targetUserId,
      roomId,
      action,
      duration,
      reason,
      reportId,
      automated,
      aiScore,
      expiresAt,
      createdAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ModerationActionImplCopyWith<_$ModerationActionImpl> get copyWith =>
      __$$ModerationActionImplCopyWithImpl<_$ModerationActionImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ModerationActionImplToJson(
      this,
    );
  }
}

abstract class _ModerationAction implements ModerationAction {
  const factory _ModerationAction(
      {required final String id,
      required final String moderatorId,
      required final String targetUserId,
      final String? roomId,
      required final String action,
      final int? duration,
      required final String reason,
      final String? reportId,
      required final bool automated,
      final AIScore? aiScore,
      final DateTime? expiresAt,
      required final DateTime createdAt}) = _$ModerationActionImpl;

  factory _ModerationAction.fromJson(Map<String, dynamic> json) =
      _$ModerationActionImpl.fromJson;

  @override
  String get id;
  @override
  String get moderatorId;
  @override
  String get targetUserId;
  @override
  String? get roomId;
  @override
  String get action;
  @override
  int? get duration;
  @override
  String get reason;
  @override
  String? get reportId;
  @override
  bool get automated;
  @override
  AIScore? get aiScore;
  @override
  DateTime? get expiresAt;
  @override
  DateTime get createdAt;
  @override
  @JsonKey(ignore: true)
  _$$ModerationActionImplCopyWith<_$ModerationActionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AIScore _$AIScoreFromJson(Map<String, dynamic> json) {
  return _AIScore.fromJson(json);
}

/// @nodoc
mixin _$AIScore {
  double? get toxicity => throw _privateConstructorUsedError;
  double? get threat => throw _privateConstructorUsedError;
  double? get profanity => throw _privateConstructorUsedError;
  double? get spam => throw _privateConstructorUsedError;
  double? get insult => throw _privateConstructorUsedError;
  double? get identityAttack => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $AIScoreCopyWith<AIScore> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AIScoreCopyWith<$Res> {
  factory $AIScoreCopyWith(AIScore value, $Res Function(AIScore) then) =
      _$AIScoreCopyWithImpl<$Res, AIScore>;
  @useResult
  $Res call(
      {double? toxicity,
      double? threat,
      double? profanity,
      double? spam,
      double? insult,
      double? identityAttack});
}

/// @nodoc
class _$AIScoreCopyWithImpl<$Res, $Val extends AIScore>
    implements $AIScoreCopyWith<$Res> {
  _$AIScoreCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? toxicity = freezed,
    Object? threat = freezed,
    Object? profanity = freezed,
    Object? spam = freezed,
    Object? insult = freezed,
    Object? identityAttack = freezed,
  }) {
    return _then(_value.copyWith(
      toxicity: freezed == toxicity
          ? _value.toxicity
          : toxicity // ignore: cast_nullable_to_non_nullable
              as double?,
      threat: freezed == threat
          ? _value.threat
          : threat // ignore: cast_nullable_to_non_nullable
              as double?,
      profanity: freezed == profanity
          ? _value.profanity
          : profanity // ignore: cast_nullable_to_non_nullable
              as double?,
      spam: freezed == spam
          ? _value.spam
          : spam // ignore: cast_nullable_to_non_nullable
              as double?,
      insult: freezed == insult
          ? _value.insult
          : insult // ignore: cast_nullable_to_non_nullable
              as double?,
      identityAttack: freezed == identityAttack
          ? _value.identityAttack
          : identityAttack // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AIScoreImplCopyWith<$Res> implements $AIScoreCopyWith<$Res> {
  factory _$$AIScoreImplCopyWith(
          _$AIScoreImpl value, $Res Function(_$AIScoreImpl) then) =
      __$$AIScoreImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {double? toxicity,
      double? threat,
      double? profanity,
      double? spam,
      double? insult,
      double? identityAttack});
}

/// @nodoc
class __$$AIScoreImplCopyWithImpl<$Res>
    extends _$AIScoreCopyWithImpl<$Res, _$AIScoreImpl>
    implements _$$AIScoreImplCopyWith<$Res> {
  __$$AIScoreImplCopyWithImpl(
      _$AIScoreImpl _value, $Res Function(_$AIScoreImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? toxicity = freezed,
    Object? threat = freezed,
    Object? profanity = freezed,
    Object? spam = freezed,
    Object? insult = freezed,
    Object? identityAttack = freezed,
  }) {
    return _then(_$AIScoreImpl(
      toxicity: freezed == toxicity
          ? _value.toxicity
          : toxicity // ignore: cast_nullable_to_non_nullable
              as double?,
      threat: freezed == threat
          ? _value.threat
          : threat // ignore: cast_nullable_to_non_nullable
              as double?,
      profanity: freezed == profanity
          ? _value.profanity
          : profanity // ignore: cast_nullable_to_non_nullable
              as double?,
      spam: freezed == spam
          ? _value.spam
          : spam // ignore: cast_nullable_to_non_nullable
              as double?,
      insult: freezed == insult
          ? _value.insult
          : insult // ignore: cast_nullable_to_non_nullable
              as double?,
      identityAttack: freezed == identityAttack
          ? _value.identityAttack
          : identityAttack // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AIScoreImpl implements _AIScore {
  const _$AIScoreImpl(
      {this.toxicity,
      this.threat,
      this.profanity,
      this.spam,
      this.insult,
      this.identityAttack});

  factory _$AIScoreImpl.fromJson(Map<String, dynamic> json) =>
      _$$AIScoreImplFromJson(json);

  @override
  final double? toxicity;
  @override
  final double? threat;
  @override
  final double? profanity;
  @override
  final double? spam;
  @override
  final double? insult;
  @override
  final double? identityAttack;

  @override
  String toString() {
    return 'AIScore(toxicity: $toxicity, threat: $threat, profanity: $profanity, spam: $spam, insult: $insult, identityAttack: $identityAttack)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AIScoreImpl &&
            (identical(other.toxicity, toxicity) ||
                other.toxicity == toxicity) &&
            (identical(other.threat, threat) || other.threat == threat) &&
            (identical(other.profanity, profanity) ||
                other.profanity == profanity) &&
            (identical(other.spam, spam) || other.spam == spam) &&
            (identical(other.insult, insult) || other.insult == insult) &&
            (identical(other.identityAttack, identityAttack) ||
                other.identityAttack == identityAttack));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, toxicity, threat, profanity, spam, insult, identityAttack);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AIScoreImplCopyWith<_$AIScoreImpl> get copyWith =>
      __$$AIScoreImplCopyWithImpl<_$AIScoreImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AIScoreImplToJson(
      this,
    );
  }
}

abstract class _AIScore implements AIScore {
  const factory _AIScore(
      {final double? toxicity,
      final double? threat,
      final double? profanity,
      final double? spam,
      final double? insult,
      final double? identityAttack}) = _$AIScoreImpl;

  factory _AIScore.fromJson(Map<String, dynamic> json) = _$AIScoreImpl.fromJson;

  @override
  double? get toxicity;
  @override
  double? get threat;
  @override
  double? get profanity;
  @override
  double? get spam;
  @override
  double? get insult;
  @override
  double? get identityAttack;
  @override
  @JsonKey(ignore: true)
  _$$AIScoreImplCopyWith<_$AIScoreImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UserViolation _$UserViolationFromJson(Map<String, dynamic> json) {
  return _UserViolation.fromJson(json);
}

/// @nodoc
mixin _$UserViolation {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get violationType => throw _privateConstructorUsedError;
  String get severity => throw _privateConstructorUsedError;
  int get warningCount => throw _privateConstructorUsedError;
  int get strikeCount => throw _privateConstructorUsedError;
  DateTime get lastViolation => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  DateTime? get muteExpiresAt => throw _privateConstructorUsedError;
  DateTime? get banExpiresAt => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UserViolationCopyWith<UserViolation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserViolationCopyWith<$Res> {
  factory $UserViolationCopyWith(
          UserViolation value, $Res Function(UserViolation) then) =
      _$UserViolationCopyWithImpl<$Res, UserViolation>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String violationType,
      String severity,
      int warningCount,
      int strikeCount,
      DateTime lastViolation,
      String status,
      DateTime? muteExpiresAt,
      DateTime? banExpiresAt,
      String? notes,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class _$UserViolationCopyWithImpl<$Res, $Val extends UserViolation>
    implements $UserViolationCopyWith<$Res> {
  _$UserViolationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? violationType = null,
    Object? severity = null,
    Object? warningCount = null,
    Object? strikeCount = null,
    Object? lastViolation = null,
    Object? status = null,
    Object? muteExpiresAt = freezed,
    Object? banExpiresAt = freezed,
    Object? notes = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      violationType: null == violationType
          ? _value.violationType
          : violationType // ignore: cast_nullable_to_non_nullable
              as String,
      severity: null == severity
          ? _value.severity
          : severity // ignore: cast_nullable_to_non_nullable
              as String,
      warningCount: null == warningCount
          ? _value.warningCount
          : warningCount // ignore: cast_nullable_to_non_nullable
              as int,
      strikeCount: null == strikeCount
          ? _value.strikeCount
          : strikeCount // ignore: cast_nullable_to_non_nullable
              as int,
      lastViolation: null == lastViolation
          ? _value.lastViolation
          : lastViolation // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      muteExpiresAt: freezed == muteExpiresAt
          ? _value.muteExpiresAt
          : muteExpiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      banExpiresAt: freezed == banExpiresAt
          ? _value.banExpiresAt
          : banExpiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserViolationImplCopyWith<$Res>
    implements $UserViolationCopyWith<$Res> {
  factory _$$UserViolationImplCopyWith(
          _$UserViolationImpl value, $Res Function(_$UserViolationImpl) then) =
      __$$UserViolationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String violationType,
      String severity,
      int warningCount,
      int strikeCount,
      DateTime lastViolation,
      String status,
      DateTime? muteExpiresAt,
      DateTime? banExpiresAt,
      String? notes,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class __$$UserViolationImplCopyWithImpl<$Res>
    extends _$UserViolationCopyWithImpl<$Res, _$UserViolationImpl>
    implements _$$UserViolationImplCopyWith<$Res> {
  __$$UserViolationImplCopyWithImpl(
      _$UserViolationImpl _value, $Res Function(_$UserViolationImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? violationType = null,
    Object? severity = null,
    Object? warningCount = null,
    Object? strikeCount = null,
    Object? lastViolation = null,
    Object? status = null,
    Object? muteExpiresAt = freezed,
    Object? banExpiresAt = freezed,
    Object? notes = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$UserViolationImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      violationType: null == violationType
          ? _value.violationType
          : violationType // ignore: cast_nullable_to_non_nullable
              as String,
      severity: null == severity
          ? _value.severity
          : severity // ignore: cast_nullable_to_non_nullable
              as String,
      warningCount: null == warningCount
          ? _value.warningCount
          : warningCount // ignore: cast_nullable_to_non_nullable
              as int,
      strikeCount: null == strikeCount
          ? _value.strikeCount
          : strikeCount // ignore: cast_nullable_to_non_nullable
              as int,
      lastViolation: null == lastViolation
          ? _value.lastViolation
          : lastViolation // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      muteExpiresAt: freezed == muteExpiresAt
          ? _value.muteExpiresAt
          : muteExpiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      banExpiresAt: freezed == banExpiresAt
          ? _value.banExpiresAt
          : banExpiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserViolationImpl implements _UserViolation {
  const _$UserViolationImpl(
      {required this.id,
      required this.userId,
      required this.violationType,
      required this.severity,
      required this.warningCount,
      required this.strikeCount,
      required this.lastViolation,
      required this.status,
      this.muteExpiresAt,
      this.banExpiresAt,
      this.notes,
      required this.createdAt,
      required this.updatedAt});

  factory _$UserViolationImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserViolationImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String violationType;
  @override
  final String severity;
  @override
  final int warningCount;
  @override
  final int strikeCount;
  @override
  final DateTime lastViolation;
  @override
  final String status;
  @override
  final DateTime? muteExpiresAt;
  @override
  final DateTime? banExpiresAt;
  @override
  final String? notes;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'UserViolation(id: $id, userId: $userId, violationType: $violationType, severity: $severity, warningCount: $warningCount, strikeCount: $strikeCount, lastViolation: $lastViolation, status: $status, muteExpiresAt: $muteExpiresAt, banExpiresAt: $banExpiresAt, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserViolationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.violationType, violationType) ||
                other.violationType == violationType) &&
            (identical(other.severity, severity) ||
                other.severity == severity) &&
            (identical(other.warningCount, warningCount) ||
                other.warningCount == warningCount) &&
            (identical(other.strikeCount, strikeCount) ||
                other.strikeCount == strikeCount) &&
            (identical(other.lastViolation, lastViolation) ||
                other.lastViolation == lastViolation) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.muteExpiresAt, muteExpiresAt) ||
                other.muteExpiresAt == muteExpiresAt) &&
            (identical(other.banExpiresAt, banExpiresAt) ||
                other.banExpiresAt == banExpiresAt) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      violationType,
      severity,
      warningCount,
      strikeCount,
      lastViolation,
      status,
      muteExpiresAt,
      banExpiresAt,
      notes,
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UserViolationImplCopyWith<_$UserViolationImpl> get copyWith =>
      __$$UserViolationImplCopyWithImpl<_$UserViolationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserViolationImplToJson(
      this,
    );
  }
}

abstract class _UserViolation implements UserViolation {
  const factory _UserViolation(
      {required final String id,
      required final String userId,
      required final String violationType,
      required final String severity,
      required final int warningCount,
      required final int strikeCount,
      required final DateTime lastViolation,
      required final String status,
      final DateTime? muteExpiresAt,
      final DateTime? banExpiresAt,
      final String? notes,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$UserViolationImpl;

  factory _UserViolation.fromJson(Map<String, dynamic> json) =
      _$UserViolationImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get violationType;
  @override
  String get severity;
  @override
  int get warningCount;
  @override
  int get strikeCount;
  @override
  DateTime get lastViolation;
  @override
  String get status;
  @override
  DateTime? get muteExpiresAt;
  @override
  DateTime? get banExpiresAt;
  @override
  String? get notes;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$UserViolationImplCopyWith<_$UserViolationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Appeal _$AppealFromJson(Map<String, dynamic> json) {
  return _Appeal.fromJson(json);
}

/// @nodoc
mixin _$Appeal {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get actionId => throw _privateConstructorUsedError;
  String get appealReason => throw _privateConstructorUsedError;
  String? get evidence => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get reviewerId => throw _privateConstructorUsedError;
  String? get reviewNotes => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get resolvedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $AppealCopyWith<Appeal> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppealCopyWith<$Res> {
  factory $AppealCopyWith(Appeal value, $Res Function(Appeal) then) =
      _$AppealCopyWithImpl<$Res, Appeal>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String actionId,
      String appealReason,
      String? evidence,
      String status,
      String? reviewerId,
      String? reviewNotes,
      DateTime createdAt,
      DateTime? resolvedAt});
}

/// @nodoc
class _$AppealCopyWithImpl<$Res, $Val extends Appeal>
    implements $AppealCopyWith<$Res> {
  _$AppealCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? actionId = null,
    Object? appealReason = null,
    Object? evidence = freezed,
    Object? status = null,
    Object? reviewerId = freezed,
    Object? reviewNotes = freezed,
    Object? createdAt = null,
    Object? resolvedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      actionId: null == actionId
          ? _value.actionId
          : actionId // ignore: cast_nullable_to_non_nullable
              as String,
      appealReason: null == appealReason
          ? _value.appealReason
          : appealReason // ignore: cast_nullable_to_non_nullable
              as String,
      evidence: freezed == evidence
          ? _value.evidence
          : evidence // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      reviewerId: freezed == reviewerId
          ? _value.reviewerId
          : reviewerId // ignore: cast_nullable_to_non_nullable
              as String?,
      reviewNotes: freezed == reviewNotes
          ? _value.reviewNotes
          : reviewNotes // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      resolvedAt: freezed == resolvedAt
          ? _value.resolvedAt
          : resolvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AppealImplCopyWith<$Res> implements $AppealCopyWith<$Res> {
  factory _$$AppealImplCopyWith(
          _$AppealImpl value, $Res Function(_$AppealImpl) then) =
      __$$AppealImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String actionId,
      String appealReason,
      String? evidence,
      String status,
      String? reviewerId,
      String? reviewNotes,
      DateTime createdAt,
      DateTime? resolvedAt});
}

/// @nodoc
class __$$AppealImplCopyWithImpl<$Res>
    extends _$AppealCopyWithImpl<$Res, _$AppealImpl>
    implements _$$AppealImplCopyWith<$Res> {
  __$$AppealImplCopyWithImpl(
      _$AppealImpl _value, $Res Function(_$AppealImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? actionId = null,
    Object? appealReason = null,
    Object? evidence = freezed,
    Object? status = null,
    Object? reviewerId = freezed,
    Object? reviewNotes = freezed,
    Object? createdAt = null,
    Object? resolvedAt = freezed,
  }) {
    return _then(_$AppealImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      actionId: null == actionId
          ? _value.actionId
          : actionId // ignore: cast_nullable_to_non_nullable
              as String,
      appealReason: null == appealReason
          ? _value.appealReason
          : appealReason // ignore: cast_nullable_to_non_nullable
              as String,
      evidence: freezed == evidence
          ? _value.evidence
          : evidence // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      reviewerId: freezed == reviewerId
          ? _value.reviewerId
          : reviewerId // ignore: cast_nullable_to_non_nullable
              as String?,
      reviewNotes: freezed == reviewNotes
          ? _value.reviewNotes
          : reviewNotes // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      resolvedAt: freezed == resolvedAt
          ? _value.resolvedAt
          : resolvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AppealImpl implements _Appeal {
  const _$AppealImpl(
      {required this.id,
      required this.userId,
      required this.actionId,
      required this.appealReason,
      this.evidence,
      required this.status,
      this.reviewerId,
      this.reviewNotes,
      required this.createdAt,
      this.resolvedAt});

  factory _$AppealImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppealImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String actionId;
  @override
  final String appealReason;
  @override
  final String? evidence;
  @override
  final String status;
  @override
  final String? reviewerId;
  @override
  final String? reviewNotes;
  @override
  final DateTime createdAt;
  @override
  final DateTime? resolvedAt;

  @override
  String toString() {
    return 'Appeal(id: $id, userId: $userId, actionId: $actionId, appealReason: $appealReason, evidence: $evidence, status: $status, reviewerId: $reviewerId, reviewNotes: $reviewNotes, createdAt: $createdAt, resolvedAt: $resolvedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppealImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.actionId, actionId) ||
                other.actionId == actionId) &&
            (identical(other.appealReason, appealReason) ||
                other.appealReason == appealReason) &&
            (identical(other.evidence, evidence) ||
                other.evidence == evidence) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.reviewerId, reviewerId) ||
                other.reviewerId == reviewerId) &&
            (identical(other.reviewNotes, reviewNotes) ||
                other.reviewNotes == reviewNotes) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.resolvedAt, resolvedAt) ||
                other.resolvedAt == resolvedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      actionId,
      appealReason,
      evidence,
      status,
      reviewerId,
      reviewNotes,
      createdAt,
      resolvedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AppealImplCopyWith<_$AppealImpl> get copyWith =>
      __$$AppealImplCopyWithImpl<_$AppealImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppealImplToJson(
      this,
    );
  }
}

abstract class _Appeal implements Appeal {
  const factory _Appeal(
      {required final String id,
      required final String userId,
      required final String actionId,
      required final String appealReason,
      final String? evidence,
      required final String status,
      final String? reviewerId,
      final String? reviewNotes,
      required final DateTime createdAt,
      final DateTime? resolvedAt}) = _$AppealImpl;

  factory _Appeal.fromJson(Map<String, dynamic> json) = _$AppealImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get actionId;
  @override
  String get appealReason;
  @override
  String? get evidence;
  @override
  String get status;
  @override
  String? get reviewerId;
  @override
  String? get reviewNotes;
  @override
  DateTime get createdAt;
  @override
  DateTime? get resolvedAt;
  @override
  @JsonKey(ignore: true)
  _$$AppealImplCopyWith<_$AppealImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BlockedUser _$BlockedUserFromJson(Map<String, dynamic> json) {
  return _BlockedUser.fromJson(json);
}

/// @nodoc
mixin _$BlockedUser {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get blockedUserId => throw _privateConstructorUsedError;
  String? get reason => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $BlockedUserCopyWith<BlockedUser> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BlockedUserCopyWith<$Res> {
  factory $BlockedUserCopyWith(
          BlockedUser value, $Res Function(BlockedUser) then) =
      _$BlockedUserCopyWithImpl<$Res, BlockedUser>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String blockedUserId,
      String? reason,
      DateTime createdAt});
}

/// @nodoc
class _$BlockedUserCopyWithImpl<$Res, $Val extends BlockedUser>
    implements $BlockedUserCopyWith<$Res> {
  _$BlockedUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? blockedUserId = null,
    Object? reason = freezed,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      blockedUserId: null == blockedUserId
          ? _value.blockedUserId
          : blockedUserId // ignore: cast_nullable_to_non_nullable
              as String,
      reason: freezed == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BlockedUserImplCopyWith<$Res>
    implements $BlockedUserCopyWith<$Res> {
  factory _$$BlockedUserImplCopyWith(
          _$BlockedUserImpl value, $Res Function(_$BlockedUserImpl) then) =
      __$$BlockedUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String blockedUserId,
      String? reason,
      DateTime createdAt});
}

/// @nodoc
class __$$BlockedUserImplCopyWithImpl<$Res>
    extends _$BlockedUserCopyWithImpl<$Res, _$BlockedUserImpl>
    implements _$$BlockedUserImplCopyWith<$Res> {
  __$$BlockedUserImplCopyWithImpl(
      _$BlockedUserImpl _value, $Res Function(_$BlockedUserImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? blockedUserId = null,
    Object? reason = freezed,
    Object? createdAt = null,
  }) {
    return _then(_$BlockedUserImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      blockedUserId: null == blockedUserId
          ? _value.blockedUserId
          : blockedUserId // ignore: cast_nullable_to_non_nullable
              as String,
      reason: freezed == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BlockedUserImpl implements _BlockedUser {
  const _$BlockedUserImpl(
      {required this.id,
      required this.userId,
      required this.blockedUserId,
      this.reason,
      required this.createdAt});

  factory _$BlockedUserImpl.fromJson(Map<String, dynamic> json) =>
      _$$BlockedUserImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String blockedUserId;
  @override
  final String? reason;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'BlockedUser(id: $id, userId: $userId, blockedUserId: $blockedUserId, reason: $reason, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BlockedUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.blockedUserId, blockedUserId) ||
                other.blockedUserId == blockedUserId) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, userId, blockedUserId, reason, createdAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BlockedUserImplCopyWith<_$BlockedUserImpl> get copyWith =>
      __$$BlockedUserImplCopyWithImpl<_$BlockedUserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BlockedUserImplToJson(
      this,
    );
  }
}

abstract class _BlockedUser implements BlockedUser {
  const factory _BlockedUser(
      {required final String id,
      required final String userId,
      required final String blockedUserId,
      final String? reason,
      required final DateTime createdAt}) = _$BlockedUserImpl;

  factory _BlockedUser.fromJson(Map<String, dynamic> json) =
      _$BlockedUserImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get blockedUserId;
  @override
  String? get reason;
  @override
  DateTime get createdAt;
  @override
  @JsonKey(ignore: true)
  _$$BlockedUserImplCopyWith<_$BlockedUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ModerationQueueItem _$ModerationQueueItemFromJson(Map<String, dynamic> json) {
  return _ModerationQueueItem.fromJson(json);
}

/// @nodoc
mixin _$ModerationQueueItem {
  String get id => throw _privateConstructorUsedError;
  String get itemType => throw _privateConstructorUsedError;
  String get itemId => throw _privateConstructorUsedError;
  String get reason => throw _privateConstructorUsedError;
  String get priority => throw _privateConstructorUsedError;
  AIScore? get aiAnalysis => throw _privateConstructorUsedError;
  int get reportCount => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get assignedTo => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get resolvedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ModerationQueueItemCopyWith<ModerationQueueItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ModerationQueueItemCopyWith<$Res> {
  factory $ModerationQueueItemCopyWith(
          ModerationQueueItem value, $Res Function(ModerationQueueItem) then) =
      _$ModerationQueueItemCopyWithImpl<$Res, ModerationQueueItem>;
  @useResult
  $Res call(
      {String id,
      String itemType,
      String itemId,
      String reason,
      String priority,
      AIScore? aiAnalysis,
      int reportCount,
      String status,
      String? assignedTo,
      DateTime createdAt,
      DateTime? resolvedAt});

  $AIScoreCopyWith<$Res>? get aiAnalysis;
}

/// @nodoc
class _$ModerationQueueItemCopyWithImpl<$Res, $Val extends ModerationQueueItem>
    implements $ModerationQueueItemCopyWith<$Res> {
  _$ModerationQueueItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? itemType = null,
    Object? itemId = null,
    Object? reason = null,
    Object? priority = null,
    Object? aiAnalysis = freezed,
    Object? reportCount = null,
    Object? status = null,
    Object? assignedTo = freezed,
    Object? createdAt = null,
    Object? resolvedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      itemType: null == itemType
          ? _value.itemType
          : itemType // ignore: cast_nullable_to_non_nullable
              as String,
      itemId: null == itemId
          ? _value.itemId
          : itemId // ignore: cast_nullable_to_non_nullable
              as String,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as String,
      aiAnalysis: freezed == aiAnalysis
          ? _value.aiAnalysis
          : aiAnalysis // ignore: cast_nullable_to_non_nullable
              as AIScore?,
      reportCount: null == reportCount
          ? _value.reportCount
          : reportCount // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      assignedTo: freezed == assignedTo
          ? _value.assignedTo
          : assignedTo // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      resolvedAt: freezed == resolvedAt
          ? _value.resolvedAt
          : resolvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $AIScoreCopyWith<$Res>? get aiAnalysis {
    if (_value.aiAnalysis == null) {
      return null;
    }

    return $AIScoreCopyWith<$Res>(_value.aiAnalysis!, (value) {
      return _then(_value.copyWith(aiAnalysis: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ModerationQueueItemImplCopyWith<$Res>
    implements $ModerationQueueItemCopyWith<$Res> {
  factory _$$ModerationQueueItemImplCopyWith(_$ModerationQueueItemImpl value,
          $Res Function(_$ModerationQueueItemImpl) then) =
      __$$ModerationQueueItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String itemType,
      String itemId,
      String reason,
      String priority,
      AIScore? aiAnalysis,
      int reportCount,
      String status,
      String? assignedTo,
      DateTime createdAt,
      DateTime? resolvedAt});

  @override
  $AIScoreCopyWith<$Res>? get aiAnalysis;
}

/// @nodoc
class __$$ModerationQueueItemImplCopyWithImpl<$Res>
    extends _$ModerationQueueItemCopyWithImpl<$Res, _$ModerationQueueItemImpl>
    implements _$$ModerationQueueItemImplCopyWith<$Res> {
  __$$ModerationQueueItemImplCopyWithImpl(_$ModerationQueueItemImpl _value,
      $Res Function(_$ModerationQueueItemImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? itemType = null,
    Object? itemId = null,
    Object? reason = null,
    Object? priority = null,
    Object? aiAnalysis = freezed,
    Object? reportCount = null,
    Object? status = null,
    Object? assignedTo = freezed,
    Object? createdAt = null,
    Object? resolvedAt = freezed,
  }) {
    return _then(_$ModerationQueueItemImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      itemType: null == itemType
          ? _value.itemType
          : itemType // ignore: cast_nullable_to_non_nullable
              as String,
      itemId: null == itemId
          ? _value.itemId
          : itemId // ignore: cast_nullable_to_non_nullable
              as String,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as String,
      aiAnalysis: freezed == aiAnalysis
          ? _value.aiAnalysis
          : aiAnalysis // ignore: cast_nullable_to_non_nullable
              as AIScore?,
      reportCount: null == reportCount
          ? _value.reportCount
          : reportCount // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      assignedTo: freezed == assignedTo
          ? _value.assignedTo
          : assignedTo // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      resolvedAt: freezed == resolvedAt
          ? _value.resolvedAt
          : resolvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ModerationQueueItemImpl implements _ModerationQueueItem {
  const _$ModerationQueueItemImpl(
      {required this.id,
      required this.itemType,
      required this.itemId,
      required this.reason,
      required this.priority,
      this.aiAnalysis,
      required this.reportCount,
      required this.status,
      this.assignedTo,
      required this.createdAt,
      this.resolvedAt});

  factory _$ModerationQueueItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$ModerationQueueItemImplFromJson(json);

  @override
  final String id;
  @override
  final String itemType;
  @override
  final String itemId;
  @override
  final String reason;
  @override
  final String priority;
  @override
  final AIScore? aiAnalysis;
  @override
  final int reportCount;
  @override
  final String status;
  @override
  final String? assignedTo;
  @override
  final DateTime createdAt;
  @override
  final DateTime? resolvedAt;

  @override
  String toString() {
    return 'ModerationQueueItem(id: $id, itemType: $itemType, itemId: $itemId, reason: $reason, priority: $priority, aiAnalysis: $aiAnalysis, reportCount: $reportCount, status: $status, assignedTo: $assignedTo, createdAt: $createdAt, resolvedAt: $resolvedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ModerationQueueItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.itemType, itemType) ||
                other.itemType == itemType) &&
            (identical(other.itemId, itemId) || other.itemId == itemId) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.aiAnalysis, aiAnalysis) ||
                other.aiAnalysis == aiAnalysis) &&
            (identical(other.reportCount, reportCount) ||
                other.reportCount == reportCount) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.assignedTo, assignedTo) ||
                other.assignedTo == assignedTo) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.resolvedAt, resolvedAt) ||
                other.resolvedAt == resolvedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      itemType,
      itemId,
      reason,
      priority,
      aiAnalysis,
      reportCount,
      status,
      assignedTo,
      createdAt,
      resolvedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ModerationQueueItemImplCopyWith<_$ModerationQueueItemImpl> get copyWith =>
      __$$ModerationQueueItemImplCopyWithImpl<_$ModerationQueueItemImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ModerationQueueItemImplToJson(
      this,
    );
  }
}

abstract class _ModerationQueueItem implements ModerationQueueItem {
  const factory _ModerationQueueItem(
      {required final String id,
      required final String itemType,
      required final String itemId,
      required final String reason,
      required final String priority,
      final AIScore? aiAnalysis,
      required final int reportCount,
      required final String status,
      final String? assignedTo,
      required final DateTime createdAt,
      final DateTime? resolvedAt}) = _$ModerationQueueItemImpl;

  factory _ModerationQueueItem.fromJson(Map<String, dynamic> json) =
      _$ModerationQueueItemImpl.fromJson;

  @override
  String get id;
  @override
  String get itemType;
  @override
  String get itemId;
  @override
  String get reason;
  @override
  String get priority;
  @override
  AIScore? get aiAnalysis;
  @override
  int get reportCount;
  @override
  String get status;
  @override
  String? get assignedTo;
  @override
  DateTime get createdAt;
  @override
  DateTime? get resolvedAt;
  @override
  @JsonKey(ignore: true)
  _$$ModerationQueueItemImplCopyWith<_$ModerationQueueItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
