import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';
import 'dart:convert';
import 'package:appwrite/enums.dart';

/// CRM Analytics Service
/// Integrates with Odoo CRM via Appwrite Functions for analytics tracking
/// NOTE: Analytics tracking is restricted to Dialectic Labs staff only
class CRMAnalyticsService {
  static final CRMAnalyticsService _instance = CRMAnalyticsService._internal();

  factory CRMAnalyticsService() {
    return _instance;
  }

  CRMAnalyticsService._internal();

  final _appwrite = AppwriteService();
  final _logger = AppLogger();

  // Analytics Configuration
  // Set to true to enable tracking for all users (future)
  static const bool _trackAllUsers = false;

  // Internal Dialectic Labs domains - only these users are tracked
  static const _internalDomains = [
    '@dialecticlabs.com',
    '@thearenadtd.com',
  ];

  /// Check if analytics should be tracked for this user
  /// Currently restricted to Dialectic Labs staff only
  bool _shouldTrack(String? userEmail) {
    if (_trackAllUsers) return true; // Future: enable for everyone

    if (userEmail == null || userEmail.isEmpty) return false;

    // Only track internal team members
    return _internalDomains.any((domain) => userEmail.toLowerCase().endsWith(domain));
  }

  // Appwrite Function IDs (from appwrite.json)
  static const String _trackFunnelEventFunctionId = 'track-funnel-event';
  static const String _submitCSATFunctionId = 'submit-csat-survey';
  static const String _submitNPSFunctionId = 'submit-nps-survey';

  /// Track a funnel event (awareness → interest → activation → engagement → retention → revenue)
  ///
  /// Example:
  /// ```dart
  /// await CRMAnalyticsService().trackFunnelEvent(
  ///   eventName: 'arena_room_created',
  ///   userEmail: 'user@arena.com',
  ///   eventData: {'roomType': 'debate', 'topic': 'Climate Change'},
  /// );
  /// ```
  Future<Map<String, dynamic>?> trackFunnelEvent({
    required String eventName,
    String? userEmail,
    String? userId,
    Map<String, dynamic>? eventData,
    String? sessionId,
    String? deviceInfo,
    String? appVersion,
  }) async {
    // Check if tracking is enabled for this user
    if (!_shouldTrack(userEmail)) {
      _logger.debug('📊 Skipping analytics (user not in internal team): $eventName');
      return null;
    }

    try {
      _logger.debug('📊 Tracking funnel event: $eventName');

      final payload = {
        'eventName': eventName,
        if (userEmail != null) 'userEmail': userEmail,
        if (userId != null) 'userId': userId,
        if (eventData != null) 'eventData': eventData,
        if (sessionId != null) 'sessionId': sessionId,
        if (deviceInfo != null) 'deviceInfo': deviceInfo,
        if (appVersion != null) 'appVersion': appVersion,
      };

      final execution = await _appwrite.functions.createExecution(
        functionId: _trackFunnelEventFunctionId,
        body: jsonEncode(payload),
      );

      if (execution.status == ExecutionStatus.completed && execution.responseStatusCode == 200) {
        final response = jsonDecode(execution.responseBody);
        _logger.debug('✅ Funnel event tracked: ${response['eventId']}');
        return response;
      } else {
        _logger.error('❌ Funnel event tracking failed: ${execution.responseBody}');
        return null;
      }
    } catch (e) {
      _logger.error('❌ Error tracking funnel event: $e');
      return null;
    }
  }

  /// Submit CSAT (Customer Satisfaction) survey response
  ///
  /// Example:
  /// ```dart
  /// await CRMAnalyticsService().submitCSATSurvey(
  ///   userEmail: 'user@arena.com',
  ///   score: 4,  // 1-5 scale
  ///   feedback: 'Great debate experience!',
  ///   surveyContext: 'post_arena_debate',
  /// );
  /// ```
  Future<Map<String, dynamic>?> submitCSATSurvey({
    required String userEmail,
    required int score, // 1-5
    String? feedback,
    String? surveyContext,
    Map<String, dynamic>? metadata,
  }) async {
    // Check if tracking is enabled for this user
    if (!_shouldTrack(userEmail)) {
      _logger.debug('😊 Skipping CSAT (user not in internal team)');
      return null;
    }

    try {
      if (score < 1 || score > 5) {
        _logger.error('❌ CSAT score must be between 1-5');
        return null;
      }

      _logger.debug('😊 Submitting CSAT survey: score=$score');

      final payload = {
        'userEmail': userEmail,
        'score': score,
        if (feedback != null) 'feedback': feedback,
        if (surveyContext != null) 'surveyContext': surveyContext,
        if (metadata != null) 'metadata': metadata,
      };

      final execution = await _appwrite.functions.createExecution(
        functionId: _submitCSATFunctionId,
        body: jsonEncode(payload),
      );

      if (execution.status == ExecutionStatus.completed && execution.responseStatusCode == 200) {
        final response = jsonDecode(execution.responseBody);
        _logger.debug('✅ CSAT survey submitted: ${response['surveyId']}');
        return response;
      } else {
        _logger.error('❌ CSAT submission failed: ${execution.responseBody}');
        return null;
      }
    } catch (e) {
      _logger.error('❌ Error submitting CSAT survey: $e');
      return null;
    }
  }

  /// Submit NPS (Net Promoter Score) survey response
  ///
  /// Example:
  /// ```dart
  /// await CRMAnalyticsService().submitNPSSurvey(
  ///   userEmail: 'user@arena.com',
  ///   score: 9,  // 0-10 scale
  ///   feedback: 'Would definitely recommend Arena to friends!',
  /// );
  /// ```
  Future<Map<String, dynamic>?> submitNPSSurvey({
    required String userEmail,
    required int score, // 0-10
    String? feedback,
    String? surveyContext,
    Map<String, dynamic>? metadata,
  }) async {
    // Check if tracking is enabled for this user
    if (!_shouldTrack(userEmail)) {
      _logger.debug('📈 Skipping NPS (user not in internal team)');
      return null;
    }

    try {
      if (score < 0 || score > 10) {
        _logger.error('❌ NPS score must be between 0-10');
        return null;
      }

      _logger.debug('📈 Submitting NPS survey: score=$score');

      final payload = {
        'userEmail': userEmail,
        'score': score,
        if (feedback != null) 'feedback': feedback,
        if (surveyContext != null) 'surveyContext': surveyContext,
        if (metadata != null) 'metadata': metadata,
      };

      final execution = await _appwrite.functions.createExecution(
        functionId: _submitNPSFunctionId,
        body: jsonEncode(payload),
      );

      if (execution.status == ExecutionStatus.completed && execution.responseStatusCode == 200) {
        final response = jsonDecode(execution.responseBody);
        _logger.debug('✅ NPS survey submitted: ${response['surveyId']}');
        return response;
      } else {
        _logger.error('❌ NPS submission failed: ${execution.responseBody}');
        return null;
      }
    } catch (e) {
      _logger.error('❌ Error submitting NPS survey: $e');
      return null;
    }
  }

  /// Helper to track common funnel events with automatic event data
  Future<void> trackQuickEvent(String eventName, {String? userEmail, String? userId}) {
    return trackFunnelEvent(
      eventName: eventName,
      userEmail: userEmail,
      userId: userId,
      deviceInfo: 'mobile', // Could be enhanced to detect actual device
      appVersion: '1.0.61', // Should pull from package_info_plus
    );
  }
}
