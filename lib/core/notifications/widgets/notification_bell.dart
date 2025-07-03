import 'package:flutter/material.dart';

import '../notification_service.dart';
import 'notification_center.dart';

/// Notification bell icon with badge for app bar
class NotificationBell extends StatefulWidget {
  final VoidCallback? onPressed;
  final Color? iconColor;
  final double iconSize;
  final bool showCenter;

  const NotificationBell({
    super.key,
    this.onPressed,
    this.iconColor,
    this.iconSize = 24,
    this.showCenter = true,
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with TickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  OverlayEntry? _overlayEntry;
  bool _isShowingCenter = false;

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

    // Listen for new notifications to trigger shake animation
    _notificationService.unreadCount.listen((count) {
      if (count > 0 && mounted) {
        _shakeController.forward().then((_) {
          _shakeController.reverse();
        });
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _hideNotificationCenter();
    super.dispose();
  }

  void _handlePress() {
    widget.onPressed?.call();
    
    if (widget.showCenter) {
      if (_isShowingCenter) {
        _hideNotificationCenter();
      } else {
        _showNotificationCenter();
      }
    }
  }

  void _showNotificationCenter() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildNotificationCenterOverlay(),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isShowingCenter = true;
    });
  }

  void _hideNotificationCenter() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isShowingCenter = false;
    });
  }

  Widget _buildNotificationCenterOverlay() {
    return Stack(
      children: [
        // Backdrop to detect outside taps
        Positioned.fill(
          child: GestureDetector(
            onTap: _hideNotificationCenter,
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        ),
        // Notification center positioned near the bell
        Positioned(
          top: kToolbarHeight + 10,
          right: 20,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: NotificationCenter(
              notificationService: _notificationService,
              onNotificationTap: (notification) {
                _notificationService.markAsRead(notification.id);
                _hideNotificationCenter();
              },
              onDismiss: _hideNotificationCenter,
            ),
          ),
        ),
      ],
    );
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
                onPressed: _handlePress,
                icon: Icon(
                  _isShowingCenter ? Icons.notifications_active : Icons.notifications,
                  color: widget.iconColor ?? Theme.of(context).iconTheme.color,
                  size: widget.iconSize,
                ),
                tooltip: 'Notifications',
              ),
              // Unread count badge
              StreamBuilder<int>(
                stream: _notificationService.unreadCount,
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data ?? 0;
                  
                  if (unreadCount == 0) {
                    return const SizedBox.shrink();
                  }

                  return Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
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
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
              // Active indicator for showing center
              if (_isShowingCenter)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
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

/// Simple notification bell for cases where you don't want the center
class SimpleNotificationBell extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? iconColor;
  final double iconSize;

  const SimpleNotificationBell({
    super.key,
    this.onPressed,
    this.iconColor,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationBell(
      onPressed: onPressed,
      iconColor: iconColor,
      iconSize: iconSize,
      showCenter: false,
    );
  }
}