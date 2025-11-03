import 'package:flutter/material.dart';
import 'dart:async';

import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import 'follow_notification_modal.dart';

/// Notification bell for follow notifications
class FollowNotificationBell extends StatefulWidget {
  final String userId;
  final Color? iconColor;
  final double iconSize;

  const FollowNotificationBell({
    super.key,
    required this.userId,
    this.iconColor,
    this.iconSize = 24,
  });

  @override
  State<FollowNotificationBell> createState() => _FollowNotificationBellState();
}

class _FollowNotificationBellState extends State<FollowNotificationBell>
    with SingleTickerProviderStateMixin {
  final _appwrite = AppwriteService();
  int _unreadCount = 0;
  Timer? _refreshTimer;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _loadUnreadCount();

    // Refresh count every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _appwrite.getUnreadFollowNotificationCount(widget.userId);
      if (mounted) {
        final oldCount = _unreadCount;
        setState(() {
          _unreadCount = count;
        });

        // Shake animation if new notifications arrived
        if (count > oldCount && count > 0) {
          _shakeController.forward().then((_) {
            _shakeController.reverse();
          });
        }
      }
    } catch (e) {
      AppLogger().error('Error loading unread follow notification count: $e');
    }
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => FollowNotificationModal(
          currentUserId: widget.userId,
          onFollowBack: () {
            // Refresh count after following back
            _loadUnreadCount();
          },
        ),
      ),
    ).then((_) {
      // Refresh count when modal is closed
      _loadUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value * 0.1, 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: _showNotifications,
                icon: Icon(
                  _unreadCount > 0 ? Icons.person_add : Icons.person_add_outlined,
                  color: widget.iconColor ?? Theme.of(context).iconTheme.color,
                  size: widget.iconSize,
                ),
                tooltip: 'New Followers',
              ),
              // Unread count badge
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 1,
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
