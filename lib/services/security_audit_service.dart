import 'dart:async';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

/// Security audit logging service
///
/// Logs security-critical events for compliance, forensics, and monitoring.
/// All logs are stored in Appwrite's security_audit_log collection.
///
/// Event types logged:
/// - Authentication (login, logout, failed attempts)
/// - Authorization (permission checks, access denied)
/// - Data access (sensitive data views)
/// - Configuration changes
/// - Super moderator actions
/// - Suspicious activity
class SecurityAuditService {
  static final SecurityAuditService _instance = SecurityAuditService._internal();
  factory SecurityAuditService() => _instance;
  SecurityAuditService._internal();

  final AppLogger _logger = AppLogger();
  final AppwriteService _appwrite = AppwriteService();

  static const String _databaseId = 'arena_db';
  static const String _collectionId = 'security_audit_log';

  /// Log a security event
  ///
  /// All parameters are required for proper audit trail.
  /// Use appropriate severity levels: low, medium, high, critical
  Future<void> logSecurityEvent({
    required String eventType,
    required String userId,
    required String action,
    String? targetUserId,
    String? resourceId,
    String? resourceType,
    String? reason,
    String severity = 'medium',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final eventData = {
        'eventType': eventType,
        'userId': userId,
        'targetUserId': targetUserId,
        'resourceId': resourceId,
        'resourceType': resourceType,
        'action': action,
        'reason': reason ?? 'No reason provided',
        'timestamp': DateTime.now().toIso8601String(),
        'ipAddress': 'client', // Client can't determine real IP
        'userAgent': 'flutter_app', // Or get from device info
        'severity': severity,
        'metadata': metadata != null ? jsonEncode(metadata) : null,
      };

      await _appwrite.databases.createDocument(
        databaseId: _databaseId,
        collectionId: _collectionId,
        documentId: 'unique()',
        data: eventData,
      );

      _logger.debug('Security event logged: $eventType for user $userId');
    } catch (e) {
      // Don't fail the operation if audit logging fails
      _logger.error('Failed to log security event: $e');
    }
  }

  /// Log authentication event
  Future<void> logAuth({
    required String userId,
    required String action, // 'login', 'logout', 'login_failed'
    String? reason,
    Map<String, dynamic>? metadata,
  }) async {
    await logSecurityEvent(
      eventType: action,
      userId: userId,
      action: action,
      reason: reason,
      severity: action.contains('failed') ? 'high' : 'low',
      metadata: metadata,
    );
  }

  /// Log authorization failure
  Future<void> logAuthorizationFailure({
    required String userId,
    required String action,
    required String resourceId,
    String? resourceType,
    String? reason,
  }) async {
    await logSecurityEvent(
      eventType: 'authorization_failed',
      userId: userId,
      action: action,
      resourceId: resourceId,
      resourceType: resourceType,
      reason: reason ?? 'User does not have permission',
      severity: 'high',
      metadata: {
        'attempted_action': action,
      },
    );
  }

  /// Log sensitive data access
  Future<void> logDataAccess({
    required String userId,
    required String dataType,
    String? targetUserId,
    String? reason,
  }) async {
    await logSecurityEvent(
      eventType: 'data_access',
      userId: userId,
      targetUserId: targetUserId,
      action: 'view_$dataType',
      resourceType: dataType,
      reason: reason,
      severity: 'medium',
    );
  }

  /// Log suspicious activity
  Future<void> logSuspiciousActivity({
    required String userId,
    required String description,
    String? action,
    Map<String, dynamic>? metadata,
  }) async {
    await logSecurityEvent(
      eventType: 'suspicious_activity',
      userId: userId,
      action: action ?? 'unknown',
      reason: description,
      severity: 'critical',
      metadata: metadata,
    );
  }

  /// Log configuration change
  Future<void> logConfigChange({
    required String userId,
    required String configKey,
    required String oldValue,
    required String newValue,
  }) async {
    await logSecurityEvent(
      eventType: 'config_change',
      userId: userId,
      action: 'update_config',
      resourceId: configKey,
      resourceType: 'configuration',
      severity: 'medium',
      metadata: {
        'configKey': configKey,
        'oldValue': oldValue,
        'newValue': newValue,
      },
    );
  }

  /// Get audit logs for a specific user
  Future<List<Map<String, dynamic>>> getUserAuditLog({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final result = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [
          Query.equal('userId', userId),
          Query.orderDesc('\$createdAt'),
          Query.limit(limit),
        ],
      );

      return result.documents.map((doc) => doc.data).toList();
    } catch (e) {
      _logger.error('Failed to fetch audit logs: $e');
      return [];
    }
  }

  /// Get recent high-severity events
  Future<List<Map<String, dynamic>>> getHighSeverityEvents({
    int limit = 100,
  }) async {
    try {
      final result = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [
          Query.or([
            Query.equal('severity', 'high'),
            Query.equal('severity', 'critical'),
          ]),
          Query.orderDesc('\$createdAt'),
          Query.limit(limit),
        ],
      );

      return result.documents.map((doc) => doc.data).toList();
    } catch (e) {
      _logger.error('Failed to fetch high severity events: $e');
      return [];
    }
  }

  /// Check for failed login attempts (brute force detection)
  Future<int> getFailedLoginAttempts({
    required String userId,
    int withinMinutes = 15,
  }) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(minutes: withinMinutes));

      final result = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [
          Query.equal('userId', userId),
          Query.equal('eventType', 'login_failed'),
          Query.greaterThan('timestamp', cutoff.toIso8601String()),
        ],
      );

      return result.documents.length;
    } catch (e) {
      _logger.error('Failed to check failed login attempts: $e');
      return 0;
    }
  }
}
