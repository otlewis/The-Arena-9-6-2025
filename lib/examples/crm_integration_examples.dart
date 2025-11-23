import '../services/crm_analytics_service.dart';
import '../services/safety_reporting_service.dart';

/// CRM Integration Examples
/// Shows how to integrate analytics and safety reporting throughout the Arena app

class CRMIntegrationExamples {
  final _analytics = CRMAnalyticsService();
  final _safety = SafetyReportingService();

  // ============================================================================
  // ANALYTICS TRACKING EXAMPLES
  // ============================================================================

  /// Track funnel events throughout user journey
  Future<void> trackingExamples() async {
    // 1. AWARENESS - User discovers Arena
    await _analytics.trackFunnelEvent(
      eventName: 'app_opened',
      userEmail: 'user@arena.com',
      eventData: {'source': 'app_icon'},
    );

    // 2. INTEREST - User views features
    await _analytics.trackFunnelEvent(
      eventName: 'feature_viewed',
      userEmail: 'user@arena.com',
      eventData: {'feature': 'arena_debates'},
    );

    // 3. CONSIDERATION - User explores rooms
    await _analytics.trackFunnelEvent(
      eventName: 'room_browsed',
      userEmail: 'user@arena.com',
      eventData: {
        'roomType': 'debate_discussion',
        'topic': 'Climate Change',
      },
    );

    // 4. ACTIVATION - User creates account / first action
    await _analytics.trackFunnelEvent(
      eventName: 'account_created',
      userEmail: 'newuser@arena.com',
      eventData: {'signupMethod': 'email'},
    );

    // 5. ENGAGEMENT - User participates
    await _analytics.trackFunnelEvent(
      eventName: 'arena_room_joined',
      userEmail: 'user@arena.com',
      eventData: {
        'roomId': 'room_123',
        'role': 'speaker',
      },
    );

    // 6. RETENTION - User returns
    await _analytics.trackFunnelEvent(
      eventName: 'user_returned',
      userEmail: 'user@arena.com',
      eventData: {
        'daysSinceLastVisit': 7,
        'sessionCount': 15,
      },
    );

    // 7. REVENUE - User makes purchase
    await _analytics.trackFunnelEvent(
      eventName: 'tip_sent',
      userEmail: 'user@arena.com',
      eventData: {
        'amount': 5.00,
        'currency': 'USD',
        'recipientEmail': 'debater@arena.com',
      },
    );
  }

  /// Collect CSAT feedback after key experiences
  Future<void> csatExamples() async {
    // After an arena debate ends
    await _analytics.submitCSATSurvey(
      userEmail: 'user@arena.com',
      score: 4, // 1-5 scale
      feedback: 'Great debate, learned a lot!',
      surveyContext: 'post_arena_debate',
      metadata: {
        'roomId': 'arena_123',
        'duration_minutes': 45,
        'role': 'judge',
      },
    );

    // After using a specific feature
    await _analytics.submitCSATSurvey(
      userEmail: 'user@arena.com',
      score: 5,
      feedback: 'Timer feature works perfectly',
      surveyContext: 'timer_feature',
    );

    // After support interaction
    await _analytics.submitCSATSurvey(
      userEmail: 'user@arena.com',
      score: 3,
      feedback: 'Response was slow but helpful',
      surveyContext: 'customer_support',
    );
  }

  /// Collect NPS to measure overall satisfaction
  Future<void> npsExamples() async {
    // After 30 days of use
    await _analytics.submitNPSSurvey(
      userEmail: 'user@arena.com',
      score: 9, // 0-10 scale
      feedback: 'Would definitely recommend Arena to friends interested in debate!',
      surveyContext: '30_day_milestone',
    );

    // After major feature release
    await _analytics.submitNPSSurvey(
      userEmail: 'user@arena.com',
      score: 10,
      feedback: 'The new hand-raise feature is amazing!',
      surveyContext: 'feature_release_v1.0.61',
    );
  }

  // ============================================================================
  // SAFETY REPORTING EXAMPLES
  // ============================================================================

  /// User reports safety incidents
  Future<void> safetyReportingExamples() async {
    // User reports harassment
    await _safety.logSafetyReport(
      reportType: 'harassment',
      reportedUserEmail: 'bad-actor@arena.com',
      reporterEmail: 'victim@arena.com',
      description: 'User is sending threatening messages in the debate room',
      contentId: 'message_12345',
      metadata: {
        'roomId': 'debate_room_789',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    // User reports hate speech
    await _safety.logSafetyReport(
      reportType: 'hate_speech',
      reportedUserEmail: 'hater@arena.com',
      reporterEmail: 'witness@arena.com',
      description: 'User made racist comments during arena debate',
      priority: 'high',
      metadata: {
        'arenaId': 'arena_456',
        'messageContent': '[REDACTED]',
      },
    );

    // User reports inappropriate content
    await _safety.logSafetyReport(
      reportType: 'inappropriate_content',
      reportedUserEmail: 'spammer@arena.com',
      description: 'Profile picture contains NSFW content',
      contentId: 'profile_image_789',
    );
  }

  /// Auto-detect grooming patterns (CRITICAL)
  Future<void> groomingDetectionExamples() async {
    // System detects large age gap conversation
    await _safety.autoDetectGroomingPattern(
      flaggedUserEmail: 'adult-45@arena.com',
      targetUserEmail: 'teen-15@arena.com',
      detectionReason: 'Age gap concern: 45yo messaging 15yo',
      context: {
        'ageGap': 30,
        'messageCount': 15,
        'conversationDuration_minutes': 45,
      },
    );

    // System detects personal info request
    await _safety.logGroomingAlert(
      alertType: 'personal_info_request',
      flaggedUserEmail: 'suspicious@arena.com',
      targetUserEmail: 'young-user@arena.com',
      evidence: 'User asked: "Can I get your phone number?" and "Where do you live?"',
      severity: 'high', // Auto-escalated to critical
      metadata: {
        'conversationId': 'conv_123',
        'messages': ['Can I get your phone number?', 'Where do you live?'],
      },
    );

    // System detects off-platform contact attempt
    await _safety.logGroomingAlert(
      alertType: 'off_platform_contact',
      flaggedUserEmail: 'predator@arena.com',
      targetUserEmail: 'minor@arena.com',
      evidence: 'User said: "Let\'s continue this on Discord, add me: username#1234"',
      severity: 'critical',
    );
  }

  /// Moderator actions (for audit trail)
  Future<void> moderatorActionExamples() async {
    // Issue a warning
    await _safety.recordModeratorAction(
      actionType: 'warning',
      targetUserEmail: 'rule-violator@arena.com',
      moderatorEmail: 'mod-team@arena.com',
      reason: 'Violation of community guidelines - excessive interruptions',
      description: 'First warning issued. User interrupted speakers 5 times in 10 minutes.',
      relatedReportId: '1',
    );

    // Temporary ban
    await _safety.recordModeratorAction(
      actionType: 'temporary_ban',
      targetUserEmail: 'repeat-offender@arena.com',
      moderatorEmail: 'mod-team@arena.com',
      reason: 'Second violation of harassment policy',
      description: 'User banned for 7 days due to repeated harassment after first warning',
      duration: '7 days',
      relatedReportId: '2',
    );

    // Permanent ban
    await _safety.recordModeratorAction(
      actionType: 'permanent_ban',
      targetUserEmail: 'serious-violator@arena.com',
      moderatorEmail: 'mod-team@arena.com',
      reason: 'CRITICAL: Grooming behavior detected',
      description: 'Permanent ban for attempting to solicit personal information from minor',
      priority: 'critical',
      relatedReportId: '3',
    );

    // Content removal
    await _safety.recordModeratorAction(
      actionType: 'content_removal',
      targetUserEmail: 'inappropriate-user@arena.com',
      moderatorEmail: 'mod-team@arena.com',
      reason: 'NSFW profile image',
      description: 'Removed profile image containing inappropriate content',
      priority: 'high',
      metadata: {
        'contentType': 'profile_image',
        'contentId': 'img_789',
      },
    );
  }

  // ============================================================================
  // INTEGRATION POINTS IN APP
  // ============================================================================

  /// Where to add analytics tracking in your app:
  ///
  /// 1. LOGIN SCREEN (lib/screens/login_screen.dart)
  ///    - trackFunnelEvent('user_logged_in')
  ///
  /// 2. SIGNUP SCREEN (lib/screens/signup_screen.dart)
  ///    - trackFunnelEvent('account_created')
  ///
  /// 3. HOME SCREEN (lib/screens/home_screen.dart)
  ///    - trackFunnelEvent('app_opened')
  ///    - trackFunnelEvent('feature_viewed')
  ///
  /// 4. ARENA SCREEN (lib/screens/arena_screen.dart)
  ///    - trackFunnelEvent('arena_room_created')
  ///    - trackFunnelEvent('arena_room_joined')
  ///    - submitCSATSurvey() after debate ends
  ///
  /// 5. DEBATES & DISCUSSIONS SCREEN (lib/screens/debates_discussions_screen.dart)
  ///    - trackFunnelEvent('dd_room_created')
  ///    - trackFunnelEvent('dd_room_joined')
  ///    - trackFunnelEvent('hand_raised')
  ///    - trackFunnelEvent('speaker_promoted')
  ///
  /// 6. INSTANT MESSAGING (lib/widgets/simple_instant_messaging.dart)
  ///    - trackFunnelEvent('message_sent')
  ///    - Auto-detect grooming patterns in messages
  ///
  /// 7. GIFT/TIP SYSTEM (lib/services/gift_service.dart)
  ///    - trackFunnelEvent('tip_sent')
  ///    - trackFunnelEvent('gift_purchased')
  ///
  /// 8. USER PROFILE (lib/widgets/user_profile_bottom_sheet.dart)
  ///    - Add "Report User" button → logSafetyReport()
  ///
  /// 9. MODERATOR TOOLS (lib/screens/debates_discussions_screen.dart)
  ///    - recordModeratorAction() when moderator kicks/bans user
  ///
  /// 10. SETTINGS/FEEDBACK (create new screen)
  ///     - Add survey prompts
  ///     - submitNPSSurvey() after 30 days
  ///     - submitCSATSurvey() for specific features

  /// Quick helper for common tracking
  Future<void> quickTrack({
    required String event,
    String? userEmail,
  }) {
    return _analytics.trackQuickEvent(event, userEmail: userEmail);
  }
}
