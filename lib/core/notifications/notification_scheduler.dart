import 'dart:async';
import 'dart:math';

import 'notification_service.dart';
import 'notification_types.dart';
import '../logging/app_logger.dart';

/// Scheduled notification entry
class ScheduledNotification {
  final String id;
  final DateTime scheduledTime;
  final NotificationType type;
  final String userId;
  final String title;
  final String message;
  final Map<String, dynamic> payload;
  final NotificationPriority priority;
  final List<NotificationAction> actions;
  final bool isRecurring;
  final Duration? recurringInterval;
  final int maxRecurrences;
  final int currentRecurrences;

  const ScheduledNotification({
    required this.id,
    required this.scheduledTime,
    required this.type,
    required this.userId,
    required this.title,
    required this.message,
    this.payload = const {},
    this.priority = NotificationPriority.medium,
    this.actions = const [],
    this.isRecurring = false,
    this.recurringInterval,
    this.maxRecurrences = 1,
    this.currentRecurrences = 0,
  });

  ScheduledNotification copyWith({
    String? id,
    DateTime? scheduledTime,
    NotificationType? type,
    String? userId,
    String? title,
    String? message,
    Map<String, dynamic>? payload,
    NotificationPriority? priority,
    List<NotificationAction>? actions,
    bool? isRecurring,
    Duration? recurringInterval,
    int? maxRecurrences,
    int? currentRecurrences,
  }) {
    return ScheduledNotification(
      id: id ?? this.id,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      payload: payload ?? this.payload,
      priority: priority ?? this.priority,
      actions: actions ?? this.actions,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringInterval: recurringInterval ?? this.recurringInterval,
      maxRecurrences: maxRecurrences ?? this.maxRecurrences,
      currentRecurrences: currentRecurrences ?? this.currentRecurrences,
    );
  }

  bool get isExpired => DateTime.now().isAfter(scheduledTime);
  bool get shouldRecur => isRecurring && currentRecurrences < maxRecurrences;
}

/// Service for scheduling notifications
class NotificationScheduler {
  static final NotificationScheduler _instance = NotificationScheduler._internal();
  factory NotificationScheduler() => _instance;
  NotificationScheduler._internal();

  final NotificationService _notificationService = NotificationService();
  final List<ScheduledNotification> _scheduledNotifications = [];
  Timer? _schedulerTimer;
  bool _isRunning = false;

  List<ScheduledNotification> get scheduledNotifications => 
      List.unmodifiable(_scheduledNotifications);

  /// Start the scheduler
  void start() {
    if (_isRunning) return;
    
    AppLogger().debug('🔔 ⏰ Starting notification scheduler');
    _isRunning = true;
    
    // Check every 30 seconds for due notifications
    _schedulerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _processScheduledNotifications();
    });
  }

  /// Stop the scheduler
  void stop() {
    if (!_isRunning) return;
    
    AppLogger().debug('🔔 ⏰ Stopping notification scheduler');
    _schedulerTimer?.cancel();
    _schedulerTimer = null;
    _isRunning = false;
  }

  /// Schedule a notification
  Future<String> scheduleNotification({
    required DateTime scheduledTime,
    required NotificationType type,
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic> payload = const {},
    NotificationPriority priority = NotificationPriority.medium,
    List<NotificationAction> actions = const [],
    bool isRecurring = false,
    Duration? recurringInterval,
    int maxRecurrences = 1,
  }) async {
    final id = _generateScheduleId();
    
    final scheduledNotification = ScheduledNotification(
      id: id,
      scheduledTime: scheduledTime,
      type: type,
      userId: userId,
      title: title,
      message: message,
      payload: payload,
      priority: priority,
      actions: actions,
      isRecurring: isRecurring,
      recurringInterval: recurringInterval,
      maxRecurrences: maxRecurrences,
    );

    _scheduledNotifications.add(scheduledNotification);
    
    AppLogger().debug('🔔 ⏰ Scheduled notification: $title for ${scheduledTime.toIso8601String()}');
    
    // Start scheduler if not running
    if (!_isRunning) {
      start();
    }
    
    return id;
  }

  /// Schedule a vote reminder for arena debates
  Future<String> scheduleVoteReminder({
    required String userId,
    required String arenaId,
    required String topic,
    required DateTime arenaEndTime,
    Duration reminderBefore = const Duration(minutes: 10),
  }) async {
    final reminderTime = arenaEndTime.subtract(reminderBefore);
    
    if (reminderTime.isBefore(DateTime.now())) {
      // Too late to schedule
      return '';
    }

    return await scheduleNotification(
      scheduledTime: reminderTime,
      type: NotificationType.voteReminder,
      userId: userId,
      title: 'Vote Reminder',
      message: 'Don\'t forget to vote on "$topic" - ${_formatDuration(reminderBefore)} remaining',
      payload: {
        'arenaId': arenaId,
        'topic': topic,
        'timeRemaining': reminderBefore.inMinutes,
      },
      priority: NotificationPriority.high,
      actions: [
        NotificationAction(
          id: 'vote_now',
          label: 'Vote Now',
          deepLink: '/arena/$arenaId/vote',
        ),
      ],
    );
  }

  /// Schedule follow-up notifications for unanswered challenges
  Future<String> scheduleFollowUpReminder({
    required String userId,
    required String challengeId,
    required String challengerName,
    required String topic,
    Duration followUpAfter = const Duration(hours: 12),
  }) async {
    final followUpTime = DateTime.now().add(followUpAfter);

    return await scheduleNotification(
      scheduledTime: followUpTime,
      type: NotificationType.followUp,
      userId: userId,
      title: 'Challenge Reminder',
      message: 'You still have a pending challenge from $challengerName about "$topic"',
      payload: {
        'challengeId': challengeId,
        'challengerName': challengerName,
        'topic': topic,
      },
      priority: NotificationPriority.low,
      actions: [
        NotificationAction(
          id: 'view_challenge',
          label: 'View Challenge',
          deepLink: '/challenges/$challengeId',
        ),
      ],
    );
  }

  /// Schedule arena start notifications for participants
  Future<List<String>> scheduleArenaStartNotifications({
    required String arenaId,
    required String topic,
    required List<String> participantIds,
    required DateTime arenaStartTime,
    List<Duration> reminderTimes = const [
      Duration(hours: 1),
      Duration(minutes: 10),
    ],
  }) async {
    final scheduleIds = <String>[];
    
    for (final reminderTime in reminderTimes) {
      final notificationTime = arenaStartTime.subtract(reminderTime);
      
      if (notificationTime.isBefore(DateTime.now())) {
        continue; // Skip past reminders
      }
      
      for (final participantId in participantIds) {
        final scheduleId = await scheduleNotification(
          scheduledTime: notificationTime,
          type: NotificationType.arenaStarted,
          userId: participantId,
          title: 'Arena Starting Soon',
          message: 'The debate "$topic" starts in ${_formatDuration(reminderTime)}',
          payload: {
            'arenaId': arenaId,
            'topic': topic,
            'reminderTime': reminderTime.inMinutes,
          },
          priority: NotificationPriority.medium,
          actions: [
            NotificationAction(
              id: 'join_arena',
              label: 'Join Arena',
              deepLink: '/arena/$arenaId',
            ),
          ],
        );
        scheduleIds.add(scheduleId);
      }
    }
    
    return scheduleIds;
  }

  /// Schedule recurring system maintenance notifications
  Future<String> scheduleMaintenanceNotifications({
    required DateTime firstNotification,
    required String title,
    required String message,
    Duration interval = const Duration(days: 7),
    int maxNotifications = 4,
  }) async {
    return await scheduleNotification(
      scheduledTime: firstNotification,
      type: NotificationType.systemAnnouncement,
      userId: '', // System-wide
      title: title,
      message: message,
      priority: NotificationPriority.medium,
      isRecurring: true,
      recurringInterval: interval,
      maxRecurrences: maxNotifications,
    );
  }

  /// Cancel a scheduled notification
  Future<bool> cancelScheduledNotification(String scheduleId) async {
    final index = _scheduledNotifications.indexWhere((n) => n.id == scheduleId);
    if (index != -1) {
      _scheduledNotifications.removeAt(index);
      AppLogger().debug('🔔 ⏰ Cancelled scheduled notification: $scheduleId');
      return true;
    }
    return false;
  }

  /// Cancel all scheduled notifications for a user
  Future<int> cancelUserNotifications(String userId) async {
    final count = _scheduledNotifications.where((n) => n.userId == userId).length;
    _scheduledNotifications.removeWhere((n) => n.userId == userId);
    AppLogger().debug('🔔 ⏰ Cancelled $count scheduled notifications for user: $userId');
    return count;
  }

  /// Get scheduled notifications for a user
  List<ScheduledNotification> getUserScheduledNotifications(String userId) {
    return _scheduledNotifications
        .where((n) => n.userId == userId)
        .toList();
  }

  /// Process due notifications
  void _processScheduledNotifications() {
    final now = DateTime.now();
    final dueNotifications = _scheduledNotifications
        .where((n) => n.scheduledTime.isBefore(now) || n.scheduledTime.isAtSameMomentAs(now))
        .toList();

    for (final notification in dueNotifications) {
      _sendScheduledNotification(notification);
      
      // Handle recurring notifications
      if (notification.shouldRecur && notification.recurringInterval != null) {
        final nextTime = notification.scheduledTime.add(notification.recurringInterval!);
        final updatedNotification = notification.copyWith(
          scheduledTime: nextTime,
          currentRecurrences: notification.currentRecurrences + 1,
        );
        
        // Replace with updated recurring notification
        final index = _scheduledNotifications.indexOf(notification);
        _scheduledNotifications[index] = updatedNotification;
      } else {
        // Remove non-recurring or completed notifications
        _scheduledNotifications.remove(notification);
      }
    }

    // Clean up expired notifications
    _scheduledNotifications.removeWhere((n) => 
        n.isExpired && !n.isRecurring);

    // Stop scheduler if no more notifications
    if (_scheduledNotifications.isEmpty && _isRunning) {
      stop();
    }
  }

  /// Send a scheduled notification
  Future<void> _sendScheduledNotification(ScheduledNotification scheduledNotification) async {
    try {
      AppLogger().debug('🔔 ⏰ Sending scheduled notification: ${scheduledNotification.title}');
      
      // Send through notification service
      await _notificationService.sendNotification(
        type: scheduledNotification.type,
        userId: scheduledNotification.userId,
        title: scheduledNotification.title,
        message: scheduledNotification.message,
        payload: scheduledNotification.payload,
        priority: scheduledNotification.priority,
        actions: scheduledNotification.actions,
      );
      
    } catch (e) {
      AppLogger().error('Error sending scheduled notification: $e');
    }
  }

  /// Generate unique schedule ID
  String _generateScheduleId() {
    return 'schedule_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Dispose the scheduler
  void dispose() {
    stop();
    _scheduledNotifications.clear();
  }
}

/// Extension methods for easier scheduling
extension NotificationServiceScheduling on NotificationService {
  
  /// Get the scheduler instance
  NotificationScheduler get scheduler => NotificationScheduler();
  
  /// Schedule a vote reminder
  Future<String> scheduleVoteReminder({
    required String userId,
    required String arenaId,
    required String topic,
    required DateTime arenaEndTime,
    Duration reminderBefore = const Duration(minutes: 10),
  }) async {
    return await scheduler.scheduleVoteReminder(
      userId: userId,
      arenaId: arenaId,
      topic: topic,
      arenaEndTime: arenaEndTime,
      reminderBefore: reminderBefore,
    );
  }
}