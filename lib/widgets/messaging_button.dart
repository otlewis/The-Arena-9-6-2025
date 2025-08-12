import 'package:flutter/material.dart';
import 'messaging_modal_system.dart';

/// A simple button that opens the messaging modal
/// Can be placed in app bars, navigation, or anywhere in the UI
class MessagingButton extends StatelessWidget {
  final int? unreadCount;
  final Color? iconColor;
  final double size;
  final bool showBadge;

  const MessagingButton({
    super.key,
    this.unreadCount,
    this.iconColor,
    this.size = 24,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.white,
                offset: Offset(-4, -4),
                blurRadius: 8,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.grey,
                offset: Offset(4, 4),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: IconButton(
            onPressed: () => context.openMessagingModal(),
            icon: Icon(
              Icons.chat_bubble_outline,
              color: iconColor ?? Colors.blue.shade600,
              size: size,
            ),
            tooltip: 'Messages',
          ),
        ),
        
        // Unread badge
        if (showBadge && unreadCount != null && unreadCount! > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.red,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  unreadCount! > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Messaging button that automatically shows unread count from the messaging system
class AutoMessagingButton extends StatelessWidget {
  final Color? iconColor;
  final double size;

  const AutoMessagingButton({
    super.key,
    this.iconColor,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    // Get the unread count using the extension
    return MessagingButton(
      unreadCount: context.unreadMessageCount,
      iconColor: iconColor,
      size: size,
    );
  }
}