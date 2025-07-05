import 'notification_types.dart';
import 'notification_preferences.dart';
import 'notification_service.dart';
import '../logging/app_logger.dart';

/// Analytics event for notifications
class NotificationEvent {
  final String id;
  final DateTime timestamp;
  final String userId;
  final NotificationType type;
  final NotificationEventType eventType;
  final Map<String, dynamic> metadata;

  const NotificationEvent({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.type,
    required this.eventType,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'type': type.value,
      'eventType': eventType.name,
      'metadata': metadata,
    };
  }

  factory NotificationEvent.fromMap(Map<String, dynamic> map) {
    return NotificationEvent(
      id: map['id'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      userId: map['userId'] ?? '',
      type: NotificationType.fromString(map['type'] ?? ''),
      eventType: NotificationEventType.values.byName(map['eventType'] ?? 'delivered'),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }
}

/// Types of notification events to track
enum NotificationEventType {
  sent,       // Notification was sent
  delivered,  // Notification was delivered to device
  displayed,  // Notification was shown to user
  opened,     // User opened/tapped notification
  dismissed,  // User dismissed notification
  actionTaken, // User took action on notification
  expired,    // Notification expired
  blocked,    // Notification was blocked by preferences
}

/// Analytics for notification performance and user engagement
class NotificationAnalytics {
  static final NotificationAnalytics _instance = NotificationAnalytics._internal();
  factory NotificationAnalytics() => _instance;
  NotificationAnalytics._internal();

  final List<NotificationEvent> _events = [];

  /// Track a notification event
  void trackEvent({
    required String notificationId,
    required String userId,
    required NotificationType type,
    required NotificationEventType eventType,
    Map<String, dynamic> metadata = const {},
  }) {
    final event = NotificationEvent(
      id: '${notificationId}_${eventType.name}_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      userId: userId,
      type: type,
      eventType: eventType,
      metadata: metadata,
    );

    _events.add(event);
    
    AppLogger().debug('🔔 📊 Tracked notification event: ${eventType.name} for ${type.value}');
    
    // Log important events
    switch (eventType) {
      case NotificationEventType.opened:
        AppLogger().info('Notification opened: ${type.value} by user $userId');
        break;
      case NotificationEventType.actionTaken:
        AppLogger().info('Notification action taken: ${metadata['action']} on ${type.value}');
        break;
      case NotificationEventType.blocked:
        AppLogger().debug('Notification blocked: ${type.value} for user $userId');
        break;
      default:
        break;
    }
  }

  /// Get notification statistics for a user
  NotificationStats getUserStats(String userId, {Duration? period}) {
    final since = period != null 
        ? DateTime.now().subtract(period)
        : DateTime.fromMillisecondsSinceEpoch(0);
    
    final userEvents = _events
        .where((e) => e.userId == userId && e.timestamp.isAfter(since))
        .toList();

    return NotificationStats.fromEvents(userEvents);
  }

  /// Get global notification statistics
  NotificationStats getGlobalStats({Duration? period}) {
    final since = period != null 
        ? DateTime.now().subtract(period)
        : DateTime.fromMillisecondsSinceEpoch(0);
    
    final periodEvents = _events
        .where((e) => e.timestamp.isAfter(since))
        .toList();

    return NotificationStats.fromEvents(periodEvents);
  }

  /// Get statistics by notification type
  Map<NotificationType, NotificationStats> getStatsByType({Duration? period}) {
    final since = period != null 
        ? DateTime.now().subtract(period)
        : DateTime.fromMillisecondsSinceEpoch(0);
    
    final periodEvents = _events
        .where((e) => e.timestamp.isAfter(since))
        .toList();

    final statsByType = <NotificationType, NotificationStats>{};
    
    for (final type in NotificationType.values) {
      final typeEvents = periodEvents.where((e) => e.type == type).toList();
      statsByType[type] = NotificationStats.fromEvents(typeEvents);
    }
    
    return statsByType;
  }

  /// Get engagement trends over time
  List<EngagementTrend> getEngagementTrends({
    required Duration period,
    required Duration bucketSize,
  }) {
    final trends = <EngagementTrend>[];
    final endTime = DateTime.now();
    final startTime = endTime.subtract(period);
    
    DateTime currentTime = startTime;
    while (currentTime.isBefore(endTime)) {
      final bucketEnd = currentTime.add(bucketSize);
      final bucketEvents = _events
          .where((e) => e.timestamp.isAfter(currentTime) && e.timestamp.isBefore(bucketEnd))
          .toList();
      
      final sent = bucketEvents.where((e) => e.eventType == NotificationEventType.sent).length;
      final opened = bucketEvents.where((e) => e.eventType == NotificationEventType.opened).length;
      final dismissed = bucketEvents.where((e) => e.eventType == NotificationEventType.dismissed).length;
      
      trends.add(EngagementTrend(
        timestamp: currentTime,
        sent: sent,
        opened: opened,
        dismissed: dismissed,
        engagementRate: sent > 0 ? opened / sent : 0.0,
      ));
      
      currentTime = bucketEnd;
    }
    
    return trends;
  }

  /// Generate insights and recommendations
  List<NotificationInsight> generateInsights(String userId) {
    final insights = <NotificationInsight>[];
    final userEvents = _events.where((e) => e.userId == userId).toList();
    
    if (userEvents.isEmpty) {
      return insights;
    }

    // Check engagement by type
    final typeEngagement = <NotificationType, double>{};
    for (final type in NotificationType.values) {
      final typeEvents = userEvents.where((e) => e.type == type).toList();
      final sent = typeEvents.where((e) => e.eventType == NotificationEventType.sent).length;
      final opened = typeEvents.where((e) => e.eventType == NotificationEventType.opened).length;
      
      if (sent > 0) {
        typeEngagement[type] = opened / sent;
      }
    }

    // Find low engagement types
    final lowEngagementTypes = typeEngagement.entries
        .where((entry) => entry.value < 0.1 && entry.value > 0)
        .map((entry) => entry.key)
        .toList();

    if (lowEngagementTypes.isNotEmpty) {
      insights.add(NotificationInsight(
        type: InsightType.lowEngagement,
        title: 'Low Engagement Types',
        description: 'Consider disabling notifications for: ${lowEngagementTypes.map((t) => t.value).join(', ')}',
        severity: InsightSeverity.medium,
        actionable: true,
        metadata: {'types': lowEngagementTypes.map((t) => t.value).toList()},
      ));
    }

    // Check for notification fatigue
    final recentEvents = userEvents
        .where((e) => e.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .toList();
    
    final recentSent = recentEvents.where((e) => e.eventType == NotificationEventType.sent).length;
    if (recentSent > 50) {
      insights.add(NotificationInsight(
        type: InsightType.notificationFatigue,
        title: 'High Notification Volume',
        description: 'You received $recentSent notifications this week. Consider adjusting preferences.',
        severity: InsightSeverity.high,
        actionable: true,
        metadata: {'weeklyCount': recentSent},
      ));
    }

    // Check time-based patterns
    final hourlyDistribution = <int, int>{};
    for (final event in userEvents.where((e) => e.eventType == NotificationEventType.opened)) {
      final hour = event.timestamp.hour;
      hourlyDistribution[hour] = (hourlyDistribution[hour] ?? 0) + 1;
    }

    if (hourlyDistribution.isNotEmpty) {
      final bestHour = hourlyDistribution.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      
      insights.add(NotificationInsight(
        type: InsightType.timeOptimization,
        title: 'Optimal Notification Time',
        description: 'You\'re most responsive to notifications around $bestHour:00',
        severity: InsightSeverity.low,
        actionable: false,
        metadata: {'optimalHour': bestHour},
      ));
    }

    return insights;
  }

  /// Clear old events (privacy and performance)
  void cleanupOldEvents({Duration retention = const Duration(days: 30)}) {
    final cutoff = DateTime.now().subtract(retention);
    final beforeCount = _events.length;
    
    _events.removeWhere((e) => e.timestamp.isBefore(cutoff));
    
    final removedCount = beforeCount - _events.length;
    if (removedCount > 0) {
      AppLogger().debug('🔔 📊 Cleaned up $removedCount old notification events');
    }
  }

  /// Export analytics data
  Map<String, dynamic> exportData({Duration? period}) {
    final since = period != null 
        ? DateTime.now().subtract(period)
        : DateTime.fromMillisecondsSinceEpoch(0);
    
    final exportEvents = _events
        .where((e) => e.timestamp.isAfter(since))
        .map((e) => e.toMap())
        .toList();

    return {
      'exportTime': DateTime.now().toIso8601String(),
      'period': period?.inDays,
      'eventCount': exportEvents.length,
      'events': exportEvents,
    };
  }
}

/// Statistics for notification performance
class NotificationStats {
  final int sent;
  final int delivered;
  final int displayed;
  final int opened;
  final int dismissed;
  final int actionsTaken;
  final int expired;
  final int blocked;

  const NotificationStats({
    this.sent = 0,
    this.delivered = 0,
    this.displayed = 0,
    this.opened = 0,
    this.dismissed = 0,
    this.actionsTaken = 0,
    this.expired = 0,
    this.blocked = 0,
  });

  double get deliveryRate => sent > 0 ? delivered / sent : 0.0;
  double get openRate => delivered > 0 ? opened / delivered : 0.0;
  double get engagementRate => displayed > 0 ? opened / displayed : 0.0;
  double get actionRate => opened > 0 ? actionsTaken / opened : 0.0;
  double get dismissalRate => displayed > 0 ? dismissed / displayed : 0.0;
  double get blockRate => sent > 0 ? blocked / sent : 0.0;

  factory NotificationStats.fromEvents(List<NotificationEvent> events) {
    return NotificationStats(
      sent: events.where((e) => e.eventType == NotificationEventType.sent).length,
      delivered: events.where((e) => e.eventType == NotificationEventType.delivered).length,
      displayed: events.where((e) => e.eventType == NotificationEventType.displayed).length,
      opened: events.where((e) => e.eventType == NotificationEventType.opened).length,
      dismissed: events.where((e) => e.eventType == NotificationEventType.dismissed).length,
      actionsTaken: events.where((e) => e.eventType == NotificationEventType.actionTaken).length,
      expired: events.where((e) => e.eventType == NotificationEventType.expired).length,
      blocked: events.where((e) => e.eventType == NotificationEventType.blocked).length,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sent': sent,
      'delivered': delivered,
      'displayed': displayed,
      'opened': opened,
      'dismissed': dismissed,
      'actionsTaken': actionsTaken,
      'expired': expired,
      'blocked': blocked,
      'deliveryRate': deliveryRate,
      'openRate': openRate,
      'engagementRate': engagementRate,
      'actionRate': actionRate,
      'dismissalRate': dismissalRate,
      'blockRate': blockRate,
    };
  }
}

/// Engagement trend data point
class EngagementTrend {
  final DateTime timestamp;
  final int sent;
  final int opened;
  final int dismissed;
  final double engagementRate;

  const EngagementTrend({
    required this.timestamp,
    required this.sent,
    required this.opened,
    required this.dismissed,
    required this.engagementRate,
  });
}

/// Notification insight for user recommendations
class NotificationInsight {
  final InsightType type;
  final String title;
  final String description;
  final InsightSeverity severity;
  final bool actionable;
  final Map<String, dynamic> metadata;

  const NotificationInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    required this.actionable,
    this.metadata = const {},
  });
}

enum InsightType {
  lowEngagement,
  notificationFatigue,
  timeOptimization,
  typeRecommendation,
}

enum InsightSeverity {
  low,
  medium,
  high,
}

/// Extension for tracking events easily
extension NotificationServiceAnalytics on NotificationService {
  
  /// Get the analytics instance
  NotificationAnalytics get analytics => NotificationAnalytics();
  
  /// Track when a notification is sent
  void trackSent(String notificationId, String userId, NotificationType type) {
    analytics.trackEvent(
      notificationId: notificationId,
      userId: userId,
      type: type,
      eventType: NotificationEventType.sent,
    );
  }
  
  /// Track when a notification is opened
  void trackOpened(String notificationId, String userId, NotificationType type) {
    analytics.trackEvent(
      notificationId: notificationId,
      userId: userId,
      type: type,
      eventType: NotificationEventType.opened,
    );
  }
}