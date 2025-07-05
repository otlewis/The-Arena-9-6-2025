import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../notification_model.dart';
import '../notification_service.dart';
import '../notification_types.dart';

/// Notification center panel that shows notification history
class NotificationCenter extends StatefulWidget {
  final NotificationService notificationService;
  final Function(ArenaNotification)? onNotificationTap;
  final VoidCallback? onDismiss;

  const NotificationCenter({
    super.key,
    required this.notificationService,
    this.onNotificationTap,
    this.onDismiss,
  });

  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter> {
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = widget.notificationService;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      height: 600,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: StreamBuilder<List<ArenaNotification>>(
              stream: _notificationService.notificationHistory,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifications = snapshot.data ?? [];
                
                if (notifications.isEmpty) {
                  return _buildEmptyState(context);
                }

                return _buildNotificationList(context, notifications);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Notifications',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          StreamBuilder<int>(
            stream: _notificationService.unreadCount,
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              if (unreadCount == 0) return const SizedBox.shrink();
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _notificationService.markAllAsRead(),
            icon: const Icon(Icons.mark_email_read),
            tooltip: 'Mark all as read',
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: () => _notificationService.refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: widget.onDismiss,
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).disabledColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you receive notifications, they\'ll appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).disabledColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(BuildContext context, List<ArenaNotification> notifications) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationItem(context, notification);
      },
    );
  }

  Widget _buildNotificationItem(BuildContext context, ArenaNotification notification) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: notification.isRead ? 1 : 3,
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: notification.isRead 
                ? null 
                : Theme.of(context).primaryColor.withValues(alpha: 0.05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildNotificationIcon(notification.type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeago.format(notification.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      _buildPriorityIndicator(notification.priority),
                    ],
                  ),
                ],
              ),
              if (notification.actions.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildNotificationActions(context, notification),
              ],
              if (notification.isExpired) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Expired',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case NotificationType.challenge:
        iconData = Icons.sports_kabaddi;
        color = Colors.orange;
        break;
      case NotificationType.arenaRole:
        iconData = Icons.gavel;
        color = Colors.purple;
        break;
      case NotificationType.arenaStarted:
        iconData = Icons.play_circle;
        color = Colors.green;
        break;
      case NotificationType.arenaEnded:
        iconData = Icons.stop_circle;
        color = Colors.blue;
        break;
      case NotificationType.tournamentInvite:
        iconData = Icons.emoji_events;
        color = Colors.amber;
        break;
      case NotificationType.friendRequest:
        iconData = Icons.person_add;
        color = Colors.teal;
        break;
      case NotificationType.mention:
        iconData = Icons.alternate_email;
        color = Colors.indigo;
        break;
      case NotificationType.achievement:
        iconData = Icons.star;
        color = Colors.yellow;
        break;
      case NotificationType.systemAnnouncement:
        iconData = Icons.campaign;
        color = Colors.red;
        break;
      case NotificationType.roomChat:
        iconData = Icons.chat;
        color = Colors.lightBlue;
        break;
      case NotificationType.voteReminder:
        iconData = Icons.how_to_vote;
        color = Colors.deepOrange;
        break;
      case NotificationType.followUp:
        iconData = Icons.schedule;
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        iconData,
        color: color,
        size: 20,
      ),
    );
  }

  Widget _buildPriorityIndicator(NotificationPriority priority) {
    Color color;
    switch (priority) {
      case NotificationPriority.urgent:
        color = Colors.red;
        break;
      case NotificationPriority.high:
        color = Colors.orange;
        break;
      case NotificationPriority.medium:
        color = Colors.blue;
        break;
      case NotificationPriority.low:
        color = Colors.grey;
        break;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildNotificationActions(BuildContext context, ArenaNotification notification) {
    return Wrap(
      spacing: 8,
      children: notification.actions.map((action) {
        return ElevatedButton(
          onPressed: () => _handleActionTap(action, notification),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action.label,
            style: const TextStyle(fontSize: 12),
          ),
        );
      }).toList(),
    );
  }

  void _handleNotificationTap(ArenaNotification notification) {
    // Use the callback if provided, otherwise handle locally
    if (widget.onNotificationTap != null) {
      widget.onNotificationTap!(notification);
    } else {
      if (!notification.isRead) {
        _notificationService.markAsRead(notification.id);
      }

      // Handle deep linking if available
      if (notification.deepLink != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigate to: ${notification.deepLink}')),
        );
      }
    }
  }

  void _handleActionTap(NotificationAction action, ArenaNotification notification) {
    // Handle different action types
    if (action.data != null) {
      final data = action.data!;
      
      if (data.containsKey('challengeId') && data.containsKey('action')) {
        final challengeId = data['challengeId'] as String;
        final actionType = data['action'] as String;
        
        // Handle challenge actions - show feedback for now
        if (actionType == 'accept') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Challenge accepted: $challengeId')),
          );
        } else if (actionType == 'decline') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Challenge declined: $challengeId')),
          );
        }
        
        // Mark notification as read
        _notificationService.markAsRead(notification.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${actionType.capitalize()}ed challenge')),
        );
      }
    } else if (action.deepLink != null) {
      // Handle deep link
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigate to: ${action.deepLink}')),
      );
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}