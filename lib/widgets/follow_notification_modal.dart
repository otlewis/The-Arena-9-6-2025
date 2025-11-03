import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

/// Modal to display follow notifications
class FollowNotificationModal extends StatefulWidget {
  final String currentUserId;
  final VoidCallback? onFollowBack;

  const FollowNotificationModal({
    super.key,
    required this.currentUserId,
    this.onFollowBack,
  });

  @override
  State<FollowNotificationModal> createState() => _FollowNotificationModalState();
}

class _FollowNotificationModalState extends State<FollowNotificationModal> {
  final _appwrite = AppwriteService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await _appwrite.getFollowNotifications(widget.currentUserId);
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger().error('Error loading follow notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _followBack(String followerId, String notificationId) async {
    try {
      HapticFeedback.lightImpact();

      // Follow the user back
      await _appwrite.followUser(
        followerId: widget.currentUserId,
        followingId: followerId,
      );

      // Mark notification as read
      await _appwrite.markFollowNotificationAsRead(notificationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ You followed them back!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Remove from list
        setState(() {
          _notifications.removeWhere((n) => n['id'] == notificationId);
        });

        widget.onFollowBack?.call();
      }
    } catch (e) {
      AppLogger().error('Error following back: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _dismissNotification(String notificationId) async {
    try {
      HapticFeedback.lightImpact();

      // Mark as read (dismiss)
      await _appwrite.markFollowNotificationAsRead(notificationId);

      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => n['id'] == notificationId);
        });
      }
    } catch (e) {
      AppLogger().error('Error dismissing notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.person_add,
                  color: Color(0xFF8B5CF6),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'New Followers',
                    style: TextStyle(
                      color: Color(0xFF2D3748),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(),

          // Content
          Flexible(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _notifications.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_none,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No new followers',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          final followerName = notification['followerName'] ?? 'Someone';
                          final followerAvatar = notification['followerAvatar'] ?? '';
                          final followerId = notification['followerId'] ?? '';
                          final notificationId = notification['id'] ?? '';

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  offset: const Offset(0, 2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Avatar
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: const Color(0xFF8B5CF6),
                                    backgroundImage: followerAvatar.isNotEmpty
                                        ? NetworkImage(followerAvatar)
                                        : null,
                                    child: followerAvatar.isEmpty
                                        ? Text(
                                            followerName.isNotEmpty
                                                ? followerName[0].toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),

                                  const SizedBox(width: 12),

                                  // Message
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              color: Color(0xFF2D3748),
                                              fontSize: 15,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: followerName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const TextSpan(
                                                text: ' started following you',
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Follow back to get pinged into rooms!',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Actions
                                  Column(
                                    children: [
                                      // Follow Back button
                                      ElevatedButton(
                                        onPressed: () => _followBack(followerId, notificationId),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF8B5CF6),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          'Follow Back',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      // Dismiss button
                                      TextButton(
                                        onPressed: () => _dismissNotification(notificationId),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.grey.shade600,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 4,
                                          ),
                                        ),
                                        child: const Text(
                                          'Dismiss',
                                          style: TextStyle(
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
