import 'package:flutter/material.dart';
import '../core/notifications/notifications.dart';

/// Demo screen showing how to use the notification system
class NotificationSystemDemo extends StatefulWidget {
  const NotificationSystemDemo({super.key});

  @override
  State<NotificationSystemDemo> createState() => _NotificationSystemDemoState();
}

class _NotificationSystemDemoState extends State<NotificationSystemDemo> {
  final NotificationService _notificationService = NotificationService();
  final PushNotificationService _pushService = PushNotificationService();
  final NotificationScheduler _scheduler = NotificationScheduler();
  final NotificationAnalytics _analytics = NotificationAnalytics();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    // Initialize notification services for demo user
    await _notificationService.initialize('demo_user_123');
    await _pushService.initialize('demo_user_123');
    
    // Start the scheduler
    _scheduler.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification System Demo'),
        actions: [
          NotificationBell(
            onPressed: () {
              // Bell automatically shows notification center
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            'Basic Notifications',
            [
              _buildDemoButton(
                'Send Challenge Notification',
                () => _sendChallengeNotification(),
              ),
              _buildDemoButton(
                'Send Arena Role Invitation',
                () => _sendArenaRoleInvitation(),
              ),
              _buildDemoButton(
                'Send Achievement',
                () => _sendAchievementNotification(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Scheduled Notifications',
            [
              _buildDemoButton(
                'Schedule Vote Reminder (30s)',
                () => _scheduleVoteReminder(),
              ),
              _buildDemoButton(
                'Schedule Follow-up (1 min)',
                () => _scheduleFollowUp(),
              ),
              _buildDemoButton(
                'Schedule Arena Start Reminder',
                () => _scheduleArenaStart(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Notification Analytics',
            [
              _buildDemoButton(
                'View User Stats',
                () => _showUserStats(),
              ),
              _buildDemoButton(
                'Generate Insights',
                () => _showInsights(),
              ),
              _buildDemoButton(
                'Track Demo Events',
                () => _trackDemoEvents(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Settings & Management',
            [
              _buildDemoButton(
                'Open Notification Settings',
                () => _openNotificationSettings(),
              ),
              _buildDemoButton(
                'Clear All Notifications',
                () => _clearAllNotifications(),
              ),
              _buildDemoButton(
                'Export Analytics Data',
                () => _exportAnalytics(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildNotificationPreview(),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children.map((child) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: child,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoButton(String title, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(title),
      ),
    );
  }

  Widget _buildNotificationPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Notification Stream',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<int>(
              stream: _notificationService.unreadCount,
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Text(
                  'Unread Notifications: $count',
                  style: Theme.of(context).textTheme.bodyLarge,
                );
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<ArenaNotification>>(
              stream: _notificationService.notificationHistory,
              builder: (context, snapshot) {
                final notifications = snapshot.data ?? [];
                if (notifications.isEmpty) {
                  return const Text('No notifications yet');
                }
                
                return Column(
                  children: notifications.take(3).map((notification) {
                    return ListTile(
                      leading: Icon(_getNotificationIcon(notification.type)),
                      title: Text(notification.title),
                      subtitle: Text(notification.message),
                      trailing: Text(
                        '${DateTime.now().difference(notification.createdAt).inSeconds}s ago',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      dense: true,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.challenge:
        return Icons.sports_kabaddi;
      case NotificationType.arenaRole:
        return Icons.gavel;
      case NotificationType.achievement:
        return Icons.star;
      case NotificationType.voteReminder:
        return Icons.how_to_vote;
      default:
        return Icons.notifications;
    }
  }

  // Demo notification methods
  Future<void> _sendChallengeNotification() async {
    await _notificationService.sendChallengeInvitation(
      challengerId: 'challenger_123',
      challengedId: 'demo_user_123',
      challengerName: 'Demo Challenger',
      topic: 'Is pineapple on pizza acceptable?',
      position: 'negative',
      description: 'A friendly debate about controversial food choices',
      category: 'food',
    );
    
    _showSnackBar('Challenge notification sent!');
  }

  Future<void> _sendArenaRoleInvitation() async {
    await _notificationService.sendArenaRoleInvitation(
      userId: 'demo_user_123',
      role: 'judge',
      arenaId: 'arena_456',
      topic: 'Climate Change Policy',
      inviterName: 'Arena System',
      description: 'Help judge this important debate',
    );
    
    _showSnackBar('Arena role invitation sent!');
  }

  Future<void> _sendAchievementNotification() async {
    await _notificationService.sendAchievement(
      userId: 'demo_user_123',
      achievementId: 'first_debate',
      title: 'First Debate!',
      description: 'You completed your first debate in Arena',
      points: 100,
    );
    
    _showSnackBar('Achievement notification sent!');
  }

  Future<void> _scheduleVoteReminder() async {
    final scheduleId = await _scheduler.scheduleVoteReminder(
      userId: 'demo_user_123',
      arenaId: 'arena_789',
      topic: 'Future of AI',
      arenaEndTime: DateTime.now().add(const Duration(seconds: 30)),
      reminderBefore: const Duration(seconds: 10),
    );
    
    _showSnackBar('Vote reminder scheduled! ($scheduleId)');
  }

  Future<void> _scheduleFollowUp() async {
    final scheduleId = await _scheduler.scheduleFollowUpReminder(
      userId: 'demo_user_123',
      challengeId: 'challenge_999',
      challengerName: 'Persistent Challenger',
      topic: 'Space Exploration',
      followUpAfter: const Duration(minutes: 1),
    );
    
    _showSnackBar('Follow-up reminder scheduled! ($scheduleId)');
  }

  Future<void> _scheduleArenaStart() async {
    final scheduleIds = await _scheduler.scheduleArenaStartNotifications(
      arenaId: 'arena_future',
      topic: 'Demo Arena Debate',
      participantIds: ['demo_user_123', 'user_456'],
      arenaStartTime: DateTime.now().add(const Duration(minutes: 2)),
      reminderTimes: [const Duration(minutes: 1), const Duration(seconds: 30)],
    );
    
    _showSnackBar('Arena start reminders scheduled! (${scheduleIds.length} notifications)');
  }

  void _showUserStats() {
    final stats = _analytics.getUserStats('demo_user_123');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Notification Stats'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sent: ${stats.sent}'),
            Text('Opened: ${stats.opened}'),
            Text('Dismissed: ${stats.dismissed}'),
            Text('Actions Taken: ${stats.actionsTaken}'),
            Text('Open Rate: ${(stats.openRate * 100).toStringAsFixed(1)}%'),
            Text('Engagement Rate: ${(stats.engagementRate * 100).toStringAsFixed(1)}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showInsights() {
    final insights = _analytics.generateInsights('demo_user_123');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Insights'),
        content: insights.isEmpty
            ? const Text('No insights available yet. Send some notifications first!')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: insights.map((insight) {
                  return ListTile(
                    title: Text(insight.title),
                    subtitle: Text(insight.description),
                    leading: Icon(
                      insight.severity == InsightSeverity.high
                          ? Icons.warning
                          : insight.severity == InsightSeverity.medium
                              ? Icons.info
                              : Icons.lightbulb,
                      color: insight.severity == InsightSeverity.high
                          ? Colors.red
                          : insight.severity == InsightSeverity.medium
                              ? Colors.orange
                              : Colors.blue,
                    ),
                  );
                }).toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _trackDemoEvents() {
    // Simulate various notification events
    _analytics.trackEvent(
      notificationId: 'demo_notif_1',
      userId: 'demo_user_123',
      type: NotificationType.challenge,
      eventType: NotificationEventType.sent,
    );
    
    _analytics.trackEvent(
      notificationId: 'demo_notif_1',
      userId: 'demo_user_123',
      type: NotificationType.challenge,
      eventType: NotificationEventType.opened,
    );
    
    _analytics.trackEvent(
      notificationId: 'demo_notif_2',
      userId: 'demo_user_123',
      type: NotificationType.achievement,
      eventType: NotificationEventType.sent,
    );
    
    _analytics.trackEvent(
      notificationId: 'demo_notif_2',
      userId: 'demo_user_123',
      type: NotificationType.achievement,
      eventType: NotificationEventType.dismissed,
    );
    
    _showSnackBar('Demo events tracked!');
  }

  void _openNotificationSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NotificationSettingsScreen(),
      ),
    );
  }

  Future<void> _clearAllNotifications() async {
    await _notificationService.markAllAsRead();
    _showSnackBar('All notifications marked as read!');
  }

  void _exportAnalytics() {
    final data = _analytics.exportData(period: const Duration(days: 7));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analytics Export'),
        content: Text(
          'Exported ${data['eventCount']} events from the last 7 days.\n\n'
          'In a real app, this data would be saved to a file or sent to analytics service.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _scheduler.dispose();
    super.dispose();
  }
}

/// Example of how to integrate notification bell in app bar
class AppBarWithNotifications extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const AppBarWithNotifications({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        ...?actions,
        const NotificationBell(),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Example of how to integrate banner notifications in your app
class AppWithNotifications extends StatelessWidget {
  final Widget child;

  const AppWithNotifications({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();

    return Stack(
      children: [
        child,
        // Banner notifications overlay
        NotificationBannerOverlay(
          notificationStream: notificationService.bannerNotifications,
          onNotificationTap: (notification) {
            notificationService.markAsRead(notification.id);
            // Handle navigation if needed
          },
          onNotificationDismiss: (notification) {
            notificationService.markAsDismissed(notification.id);
          },
        ),
      ],
    );
  }
}