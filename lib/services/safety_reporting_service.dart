import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';
import 'dart:convert';
import 'package:appwrite/enums.dart';

/// Safety & Moderation Reporting Service
/// Integrates with Odoo CRM via Appwrite Functions for safety incident tracking
class SafetyReportingService {
  static final SafetyReportingService _instance = SafetyReportingService._internal();

  factory SafetyReportingService() {
    return _instance;
  }

  SafetyReportingService._internal();

  final _appwrite = AppwriteService();
  final _logger = AppLogger();

  // Appwrite Function IDs (from appwrite.json)
  static const String _logSafetyReportFunctionId = 'log-safety-report';
  static const String _logGroomingAlertFunctionId = 'log-grooming-alert';
  static const String _recordModeratorActionFunctionId = 'record-moderator-action';

  /// Log a user-reported safety incident
  ///
  /// Report Types:
  /// - harassment
  /// - hate_speech
  /// - inappropriate_content
  /// - safety_concern
  /// - spam
  /// - impersonation
  /// - other
  ///
  /// Example:
  /// ```dart
  /// await SafetyReportingService().logSafetyReport(
  ///   reportType: 'harassment',
  ///   reportedUserEmail: 'bad-actor@arena.com',
  ///   reporterEmail: 'concerned-user@arena.com',
  ///   description: 'User is sending threatening messages',
  ///   contentId: 'message_12345',
  /// );
  /// ```
  Future<Map<String, dynamic>?> logSafetyReport({
    required String reportType,
    String? reportedUserEmail,
    String? reporterEmail,
    String? description,
    String? priority, // low, medium, high, urgent
    String? contentId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.debug('🚨 Logging safety report: $reportType');

      // Validate reportType
      final validTypes = [
        'harassment',
        'hate_speech',
        'inappropriate_content',
        'safety_concern',
        'spam',
        'impersonation',
        'other'
      ];

      if (!validTypes.contains(reportType)) {
        _logger.error('❌ Invalid report type: $reportType');
        return null;
      }

      final payload = {
        'reportType': reportType,
        if (reportedUserEmail != null) 'reportedUserEmail': reportedUserEmail,
        if (reporterEmail != null) 'reporterEmail': reporterEmail,
        if (description != null) 'description': description,
        if (priority != null) 'priority': priority,
        if (contentId != null) 'contentId': contentId,
        if (metadata != null) 'metadata': metadata,
      };

      final execution = await _appwrite.functions.createExecution(
        functionId: _logSafetyReportFunctionId,
        body: jsonEncode(payload),
      );

      if (execution.status == ExecutionStatus.completed && execution.responseStatusCode == 200) {
        final response = jsonDecode(execution.responseBody);
        _logger.debug('✅ Safety report logged: ${response['reportId']}');
        _logger.debug('   Priority: ${response['priority']}');
        return response;
      } else {
        _logger.error('❌ Safety report failed: ${execution.responseBody}');
        return null;
      }
    } catch (e) {
      _logger.error('❌ Error logging safety report: $e');
      return null;
    }
  }

  /// Log a CRITICAL grooming/predatory behavior alert
  ///
  /// Alert Types:
  /// - age_gap_concern
  /// - predatory_language
  /// - personal_info_request (auto-escalated to CRITICAL)
  /// - off_platform_contact (auto-escalated to CRITICAL)
  /// - gift_manipulation
  /// - other
  ///
  /// Example:
  /// ```dart
  /// await SafetyReportingService().logGroomingAlert(
  ///   alertType: 'personal_info_request',
  ///   flaggedUserEmail: 'suspicious-adult@arena.com',
  ///   targetUserEmail: 'young-user@arena.com',
  ///   evidence: 'User asked for phone number and home address',
  ///   severity: 'high',
  /// );
  /// ```
  Future<Map<String, dynamic>?> logGroomingAlert({
    required String alertType,
    required String flaggedUserEmail,
    String? targetUserEmail,
    String? evidence,
    String? severity, // medium, high, critical
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.debug('🚨🚨 GROOMING ALERT: $alertType');

      // Validate alertType
      final validTypes = [
        'age_gap_concern',
        'predatory_language',
        'personal_info_request',
        'off_platform_contact',
        'gift_manipulation',
        'other'
      ];

      if (!validTypes.contains(alertType)) {
        _logger.error('❌ Invalid alert type: $alertType');
        return null;
      }

      final payload = {
        'alertType': alertType,
        'flaggedUserEmail': flaggedUserEmail,
        if (targetUserEmail != null) 'targetUserEmail': targetUserEmail,
        if (evidence != null) 'evidence': evidence,
        if (severity != null) 'severity': severity,
        if (metadata != null) 'metadata': metadata,
      };

      final execution = await _appwrite.functions.createExecution(
        functionId: _logGroomingAlertFunctionId,
        body: jsonEncode(payload),
      );

      if (execution.status == ExecutionStatus.completed && execution.responseStatusCode == 200) {
        final response = jsonDecode(execution.responseBody);
        _logger.debug('✅ Grooming alert logged: ${response['alertId']}');
        _logger.debug('   Severity: ${response['severity']}');
        _logger.debug('   Law Enforcement: ${response['requiresLawEnforcement']}');

        // Alert if this requires law enforcement
        if (response['requiresLawEnforcement'] == true) {
          _logger.error('⚠️  CRITICAL: Law enforcement notification required');
        }

        return response;
      } else {
        _logger.error('❌ Grooming alert failed: ${execution.responseBody}');
        return null;
      }
    } catch (e) {
      _logger.error('❌ Error logging grooming alert: $e');
      return null;
    }
  }

  /// Record a moderator action for accountability
  ///
  /// Action Types:
  /// - warning (low priority)
  /// - temporary_ban (medium priority)
  /// - permanent_ban (high priority)
  /// - content_removal (high priority)
  /// - demotion (medium priority)
  /// - other
  ///
  /// Example:
  /// ```dart
  /// await SafetyReportingService().recordModeratorAction(
  ///   actionType: 'warning',
  ///   targetUserEmail: 'rule-violator@arena.com',
  ///   moderatorEmail: 'mod-team@arena.com',
  ///   reason: 'Violation of community guidelines',
  ///   description: 'First warning for harassment',
  ///   relatedReportId: '1',
  /// );
  /// ```
  Future<Map<String, dynamic>?> recordModeratorAction({
    required String actionType,
    required String targetUserEmail,
    String? moderatorEmail,
    String? reason,
    String? description,
    String? duration,
    String? priority, // low, medium, high, critical
    String? relatedReportId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.debug('⚖️  Recording moderator action: $actionType');

      final payload = {
        'actionType': actionType,
        'targetUserEmail': targetUserEmail,
        if (moderatorEmail != null) 'moderatorEmail': moderatorEmail,
        if (reason != null) 'reason': reason,
        if (description != null) 'description': description,
        if (duration != null) 'duration': duration,
        if (priority != null) 'priority': priority,
        if (relatedReportId != null) 'relatedReportId': relatedReportId,
        if (metadata != null) 'metadata': metadata,
      };

      final execution = await _appwrite.functions.createExecution(
        functionId: _recordModeratorActionFunctionId,
        body: jsonEncode(payload),
      );

      if (execution.status == ExecutionStatus.completed && execution.responseStatusCode == 200) {
        final response = jsonDecode(execution.responseBody);
        _logger.debug('✅ Moderator action recorded: ${response['actionId']}');
        _logger.debug('   Priority: ${response['priority']}');
        return response;
      } else {
        _logger.error('❌ Moderator action recording failed: ${execution.responseBody}');
        return null;
      }
    } catch (e) {
      _logger.error('❌ Error recording moderator action: $e');
      return null;
    }
  }

  /// Auto-detect and log potential grooming behavior patterns
  ///
  /// Call this when detecting suspicious patterns:
  /// - Large age gap in conversation
  /// - Requests for personal information
  /// - Attempts to move conversation off-platform
  /// - Gift-giving to minors
  Future<void> autoDetectGroomingPattern({
    required String flaggedUserEmail,
    String? targetUserEmail,
    required String detectionReason,
    Map<String, dynamic>? context,
  }) async {
    // Determine alert type based on detection reason
    String alertType = 'other';
    String severity = 'medium';

    if (detectionReason.toLowerCase().contains('age gap')) {
      alertType = 'age_gap_concern';
      severity = 'medium';
    } else if (detectionReason.toLowerCase().contains('personal info')) {
      alertType = 'personal_info_request';
      severity = 'critical'; // Will be auto-escalated
    } else if (detectionReason.toLowerCase().contains('off platform')) {
      alertType = 'off_platform_contact';
      severity = 'critical'; // Will be auto-escalated
    } else if (detectionReason.toLowerCase().contains('gift')) {
      alertType = 'gift_manipulation';
      severity = 'high';
    }

    await logGroomingAlert(
      alertType: alertType,
      flaggedUserEmail: flaggedUserEmail,
      targetUserEmail: targetUserEmail,
      evidence: detectionReason,
      severity: severity,
      metadata: {
        'autoDetected': true,
        'detectionTimestamp': DateTime.now().toIso8601String(),
        if (context != null) ...context,
      },
    );
  }
}
