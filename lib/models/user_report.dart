import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_report.freezed.dart';
part 'user_report.g.dart';

@freezed
class UserReport with _$UserReport {
  const factory UserReport({
    required String id,
    required String reporterId,
    required String reportedUserId,
    required String roomId,
    required String reportType,
    required String description,
    required ReportEvidence evidence,
    required String status,
    String? moderatorId,
    String? resolution,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _UserReport;

  factory UserReport.fromJson(Map<String, dynamic> json) => _$UserReportFromJson(json);
}

@freezed
class ReportEvidence with _$ReportEvidence {
  const factory ReportEvidence({
    String? messageId,
    String? screenshot,
    required DateTime timestamp,
  }) = _ReportEvidence;

  factory ReportEvidence.fromJson(Map<String, dynamic> json) => _$ReportEvidenceFromJson(json);
}

@freezed
class ModerationAction with _$ModerationAction {
  const factory ModerationAction({
    required String id,
    required String moderatorId,
    required String targetUserId,
    String? roomId,
    required String action,
    int? duration,
    required String reason,
    String? reportId,
    required bool automated,
    AIScore? aiScore,
    DateTime? expiresAt,
    required DateTime createdAt,
  }) = _ModerationAction;

  factory ModerationAction.fromJson(Map<String, dynamic> json) => _$ModerationActionFromJson(json);
}

@freezed
class AIScore with _$AIScore {
  const factory AIScore({
    double? toxicity,
    double? threat,
    double? profanity,
    double? spam,
    double? insult,
    double? identityAttack,
  }) = _AIScore;

  factory AIScore.fromJson(Map<String, dynamic> json) => _$AIScoreFromJson(json);
}

@freezed
class UserViolation with _$UserViolation {
  const factory UserViolation({
    required String id,
    required String userId,
    required String violationType,
    required String severity,
    required int warningCount,
    required int strikeCount,
    required DateTime lastViolation,
    required String status,
    DateTime? muteExpiresAt,
    DateTime? banExpiresAt,
    String? notes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _UserViolation;

  factory UserViolation.fromJson(Map<String, dynamic> json) => _$UserViolationFromJson(json);
}

@freezed
class Appeal with _$Appeal {
  const factory Appeal({
    required String id,
    required String userId,
    required String actionId,
    required String appealReason,
    String? evidence,
    required String status,
    String? reviewerId,
    String? reviewNotes,
    required DateTime createdAt,
    DateTime? resolvedAt,
  }) = _Appeal;

  factory Appeal.fromJson(Map<String, dynamic> json) => _$AppealFromJson(json);
}

@freezed
class BlockedUser with _$BlockedUser {
  const factory BlockedUser({
    required String id,
    required String userId,
    required String blockedUserId,
    String? reason,
    required DateTime createdAt,
  }) = _BlockedUser;

  factory BlockedUser.fromJson(Map<String, dynamic> json) => _$BlockedUserFromJson(json);
}

@freezed
class ModerationQueueItem with _$ModerationQueueItem {
  const factory ModerationQueueItem({
    required String id,
    required String itemType,
    required String itemId,
    required String reason,
    required String priority,
    AIScore? aiAnalysis,
    required int reportCount,
    required String status,
    String? assignedTo,
    required DateTime createdAt,
    DateTime? resolvedAt,
  }) = _ModerationQueueItem;

  factory ModerationQueueItem.fromJson(Map<String, dynamic> json) => _$ModerationQueueItemFromJson(json);
}

// Enums for better type safety
enum ReportType {
  harassment,
  spam,
  hateSpeech,
  inappropriate,
  threat,
  doxxing,
  other,
}

enum ModerationActionType {
  warning,
  mute,
  kick,
  ban,
  unban,
  unmute,
}

enum ViolationSeverity {
  low,
  medium,
  high,
  critical,
}

enum ModerationStatus {
  pending,
  reviewing,
  resolved,
  dismissed,
  approved,
  denied,
}

enum ModerationPriority {
  low,
  medium,
  high,
  urgent,
}