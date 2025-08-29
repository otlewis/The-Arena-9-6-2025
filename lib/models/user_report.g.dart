// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserReportImpl _$$UserReportImplFromJson(Map<String, dynamic> json) =>
    _$UserReportImpl(
      id: json['id'] as String,
      reporterId: json['reporterId'] as String,
      reportedUserId: json['reportedUserId'] as String,
      roomId: json['roomId'] as String,
      reportType: json['reportType'] as String,
      description: json['description'] as String,
      evidence:
          ReportEvidence.fromJson(json['evidence'] as Map<String, dynamic>),
      status: json['status'] as String,
      moderatorId: json['moderatorId'] as String?,
      resolution: json['resolution'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$UserReportImplToJson(_$UserReportImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'reporterId': instance.reporterId,
      'reportedUserId': instance.reportedUserId,
      'roomId': instance.roomId,
      'reportType': instance.reportType,
      'description': instance.description,
      'evidence': instance.evidence,
      'status': instance.status,
      'moderatorId': instance.moderatorId,
      'resolution': instance.resolution,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

_$ReportEvidenceImpl _$$ReportEvidenceImplFromJson(Map<String, dynamic> json) =>
    _$ReportEvidenceImpl(
      messageId: json['messageId'] as String?,
      screenshot: json['screenshot'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$$ReportEvidenceImplToJson(
        _$ReportEvidenceImpl instance) =>
    <String, dynamic>{
      'messageId': instance.messageId,
      'screenshot': instance.screenshot,
      'timestamp': instance.timestamp.toIso8601String(),
    };

_$ModerationActionImpl _$$ModerationActionImplFromJson(
        Map<String, dynamic> json) =>
    _$ModerationActionImpl(
      id: json['id'] as String,
      moderatorId: json['moderatorId'] as String,
      targetUserId: json['targetUserId'] as String,
      roomId: json['roomId'] as String?,
      action: json['action'] as String,
      duration: (json['duration'] as num?)?.toInt(),
      reason: json['reason'] as String,
      reportId: json['reportId'] as String?,
      automated: json['automated'] as bool,
      aiScore: json['aiScore'] == null
          ? null
          : AIScore.fromJson(json['aiScore'] as Map<String, dynamic>),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$ModerationActionImplToJson(
        _$ModerationActionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'moderatorId': instance.moderatorId,
      'targetUserId': instance.targetUserId,
      'roomId': instance.roomId,
      'action': instance.action,
      'duration': instance.duration,
      'reason': instance.reason,
      'reportId': instance.reportId,
      'automated': instance.automated,
      'aiScore': instance.aiScore,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };

_$AIScoreImpl _$$AIScoreImplFromJson(Map<String, dynamic> json) =>
    _$AIScoreImpl(
      toxicity: (json['toxicity'] as num?)?.toDouble(),
      threat: (json['threat'] as num?)?.toDouble(),
      profanity: (json['profanity'] as num?)?.toDouble(),
      spam: (json['spam'] as num?)?.toDouble(),
      insult: (json['insult'] as num?)?.toDouble(),
      identityAttack: (json['identityAttack'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$AIScoreImplToJson(_$AIScoreImpl instance) =>
    <String, dynamic>{
      'toxicity': instance.toxicity,
      'threat': instance.threat,
      'profanity': instance.profanity,
      'spam': instance.spam,
      'insult': instance.insult,
      'identityAttack': instance.identityAttack,
    };

_$UserViolationImpl _$$UserViolationImplFromJson(Map<String, dynamic> json) =>
    _$UserViolationImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      violationType: json['violationType'] as String,
      severity: json['severity'] as String,
      warningCount: (json['warningCount'] as num).toInt(),
      strikeCount: (json['strikeCount'] as num).toInt(),
      lastViolation: DateTime.parse(json['lastViolation'] as String),
      status: json['status'] as String,
      muteExpiresAt: json['muteExpiresAt'] == null
          ? null
          : DateTime.parse(json['muteExpiresAt'] as String),
      banExpiresAt: json['banExpiresAt'] == null
          ? null
          : DateTime.parse(json['banExpiresAt'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$UserViolationImplToJson(_$UserViolationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'violationType': instance.violationType,
      'severity': instance.severity,
      'warningCount': instance.warningCount,
      'strikeCount': instance.strikeCount,
      'lastViolation': instance.lastViolation.toIso8601String(),
      'status': instance.status,
      'muteExpiresAt': instance.muteExpiresAt?.toIso8601String(),
      'banExpiresAt': instance.banExpiresAt?.toIso8601String(),
      'notes': instance.notes,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

_$AppealImpl _$$AppealImplFromJson(Map<String, dynamic> json) => _$AppealImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      actionId: json['actionId'] as String,
      appealReason: json['appealReason'] as String,
      evidence: json['evidence'] as String?,
      status: json['status'] as String,
      reviewerId: json['reviewerId'] as String?,
      reviewNotes: json['reviewNotes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      resolvedAt: json['resolvedAt'] == null
          ? null
          : DateTime.parse(json['resolvedAt'] as String),
    );

Map<String, dynamic> _$$AppealImplToJson(_$AppealImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'actionId': instance.actionId,
      'appealReason': instance.appealReason,
      'evidence': instance.evidence,
      'status': instance.status,
      'reviewerId': instance.reviewerId,
      'reviewNotes': instance.reviewNotes,
      'createdAt': instance.createdAt.toIso8601String(),
      'resolvedAt': instance.resolvedAt?.toIso8601String(),
    };

_$BlockedUserImpl _$$BlockedUserImplFromJson(Map<String, dynamic> json) =>
    _$BlockedUserImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      blockedUserId: json['blockedUserId'] as String,
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$BlockedUserImplToJson(_$BlockedUserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'blockedUserId': instance.blockedUserId,
      'reason': instance.reason,
      'createdAt': instance.createdAt.toIso8601String(),
    };

_$ModerationQueueItemImpl _$$ModerationQueueItemImplFromJson(
        Map<String, dynamic> json) =>
    _$ModerationQueueItemImpl(
      id: json['id'] as String,
      itemType: json['itemType'] as String,
      itemId: json['itemId'] as String,
      reason: json['reason'] as String,
      priority: json['priority'] as String,
      aiAnalysis: json['aiAnalysis'] == null
          ? null
          : AIScore.fromJson(json['aiAnalysis'] as Map<String, dynamic>),
      reportCount: (json['reportCount'] as num).toInt(),
      status: json['status'] as String,
      assignedTo: json['assignedTo'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      resolvedAt: json['resolvedAt'] == null
          ? null
          : DateTime.parse(json['resolvedAt'] as String),
    );

Map<String, dynamic> _$$ModerationQueueItemImplToJson(
        _$ModerationQueueItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'itemType': instance.itemType,
      'itemId': instance.itemId,
      'reason': instance.reason,
      'priority': instance.priority,
      'aiAnalysis': instance.aiAnalysis,
      'reportCount': instance.reportCount,
      'status': instance.status,
      'assignedTo': instance.assignedTo,
      'createdAt': instance.createdAt.toIso8601String(),
      'resolvedAt': instance.resolvedAt?.toIso8601String(),
    };
