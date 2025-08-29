import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../notification_model.dart';
import '../notification_types.dart';

/// Banner notification widget that slides down from the top
class NotificationBanner extends StatefulWidget {
  final ArenaNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final Duration displayDuration;

  const NotificationBanner({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
    this.displayDuration = const Duration(seconds: 5),
  });

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _progressController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: widget.displayDuration,
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.linear,
    ));

    // Start animations
    _slideController.forward();
    _progressController.forward();

    // Auto-dismiss after duration
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _slideController.reverse();
    widget.onDismiss?.call();
  }

  void _handleTap() {
    widget.onTap?.call();
    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 50, 16, 0),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).cardColor,
                border: Border.all(
                  color: _getBorderColor(widget.notification.priority),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _buildNotificationIcon(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.notification.title,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.notification.message,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            timeago.format(widget.notification.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _dismiss,
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (widget.notification.actions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildActions(),
                  ],
                  const SizedBox(height: 8),
                  _buildProgressBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    IconData iconData;
    Color color;

    switch (widget.notification.type) {
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
      case NotificationType.instantMessage:
        iconData = Icons.message;
        color = const Color(0xFF8B5CF6);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Icon(
        iconData,
        color: color,
        size: 24,
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: widget.notification.actions.take(2).map((action) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ElevatedButton(
            onPressed: () {
              // Handle action
              _handleTap();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              action.label,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1.5),
            color: Colors.grey.withValues(alpha: 0.2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1.5),
                color: _getBorderColor(widget.notification.priority),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getBorderColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.urgent:
        return Colors.red;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.medium:
        return Colors.blue;
      case NotificationPriority.low:
        return Colors.grey;
    }
  }
}

/// Overlay widget to manage banner notifications
class NotificationBannerOverlay extends StatefulWidget {
  final Stream<ArenaNotification> notificationStream;
  final Function(ArenaNotification)? onNotificationTap;
  final Function(ArenaNotification)? onNotificationDismiss;

  const NotificationBannerOverlay({
    super.key,
    required this.notificationStream,
    this.onNotificationTap,
    this.onNotificationDismiss,
  });

  @override
  State<NotificationBannerOverlay> createState() => _NotificationBannerOverlayState();
}

class _NotificationBannerOverlayState extends State<NotificationBannerOverlay> {
  final List<ArenaNotification> _activeNotifications = [];
  final int _maxConcurrentBanners = 3;

  @override
  void initState() {
    super.initState();
    widget.notificationStream.listen(_handleNewNotification);
  }

  void _handleNewNotification(ArenaNotification notification) {
    setState(() {
      // Remove oldest if we're at the limit
      if (_activeNotifications.length >= _maxConcurrentBanners) {
        _activeNotifications.removeAt(0);
      }
      _activeNotifications.add(notification);
    });

    // Auto-remove after display duration
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _activeNotifications.remove(notification);
        });
      }
    });
  }

  void _dismissNotification(ArenaNotification notification) {
    setState(() {
      _activeNotifications.remove(notification);
    });
    widget.onNotificationDismiss?.call(notification);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _activeNotifications.asMap().entries.map((entry) {
        final index = entry.key;
        final notification = entry.value;
        
        return Positioned(
          top: 0 + (index * 80.0), // Stack them vertically
          left: 0,
          right: 0,
          child: NotificationBanner(
            notification: notification,
            onTap: () {
              _dismissNotification(notification);
              widget.onNotificationTap?.call(notification);
            },
            onDismiss: () => _dismissNotification(notification),
          ),
        );
      }).toList(),
    );
  }
}