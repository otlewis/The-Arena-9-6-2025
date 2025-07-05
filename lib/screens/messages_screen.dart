import 'package:flutter/material.dart';
import '../services/challenge_messaging_service.dart';
import '../widgets/challenge_modal.dart';
import '../widgets/user_avatar.dart';
import '../main.dart' show getIt;
import 'dart:async';
import '../core/logging/app_logger.dart';
import '../core/notifications/notification_service.dart';
import '../core/notifications/widgets/notification_center.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with SingleTickerProviderStateMixin {
  late final ChallengeMessagingService _messagingService;
  late final NotificationService _notificationService;
  late TabController _tabController;
  bool _isInitialized = false;
  
  // Colors matching app theme
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color lightScarlet = Color(0xFFFFF1F0);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Get the singleton service instances from service locator
    _messagingService = getIt<ChallengeMessagingService>();
    _notificationService = getIt<NotificationService>();
    
    // Just mark as initialized since main.dart should have initialized the service
    setState(() {
      _isInitialized = true;
    });
    
    AppLogger().debug('📱 MessagesScreen: Using singleton service, isInitialized: ${_messagingService.isInitialized}');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<ChallengeMessage>> _combineInvitationStreams() {
    // Now that both challenges and arena role invitations are in the same stream,
    // we just need to return the pending challenges stream with proper sorting
    return _messagingService.pendingChallenges.map((challengeList) {
      final sorted = List<ChallengeMessage>.from(challengeList);
      sorted.sort((a, b) {
        // Higher priority first, then newer items first
        if (a.priority != b.priority) {
          return b.priority.compareTo(a.priority);
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      return sorted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: deepPurple,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          StreamBuilder<int>(
            stream: _notificationService.unreadCount,
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    onPressed: _showNotificationCenter,
                    icon: const Icon(Icons.notifications, color: deepPurple),
                    tooltip: 'Notifications',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: scarletRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
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
                    ),
                ],
              );
            },
          ),
          IconButton(
            onPressed: () => _messagingService.refresh(),
            icon: const Icon(Icons.refresh, color: deepPurple),
            tooltip: 'Refresh messages',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: scarletRed,
          tabs: const [
            Tab(icon: Icon(Icons.flash_on), text: 'Challenges'),
            Tab(icon: Icon(Icons.send), text: 'Sent'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChallengesTab(),
          _buildSentTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildChallengesTab() {
    return StreamBuilder<List<ChallengeMessage>>(
      stream: _combineInvitationStreams(),
      builder: (context, snapshot) {
        // Show content immediately, don't wait for stream to be ready
        // This will show "No pending challenges" by default

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading challenges',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _messagingService.refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        final allInvitations = snapshot.data ?? [];
        final pendingInvitations = allInvitations
            .where((invitation) => (invitation.isPending && !invitation.isExpired) || invitation.messageType == 'decline_notification')
            .toList();

        if (pendingInvitations.isEmpty) {
          return _buildEmptyState(
            icon: Icons.flash_off,
            title: 'No pending invitations',
            subtitle: 'Challenge someone to start a debate or wait for arena role invitations!',
          );
        }

        return RefreshIndicator(
          onRefresh: () => _messagingService.refresh(),
          color: deepPurple,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendingInvitations.length,
            itemBuilder: (context, index) {
              final invitation = pendingInvitations[index];
              
              // Check if it's an arena role invitation or regular challenge
              if (invitation.isArenaRole) {
                return _buildArenaRoleCard(invitation);
              } else if (invitation.messageType == 'decline_notification') {
                return _buildDeclinedNotificationCard(invitation);
              } else {
                return _buildChallengeCard(invitation);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildSentTab() {
    return _buildEmptyState(
      icon: Icons.send_outlined,
      title: 'Sent challenges',
      subtitle: 'Track challenges you\'ve sent\n(Coming soon)',
    );
  }

  Widget _buildHistoryTab() {
    return _buildEmptyState(
      icon: Icons.history,
      title: 'Challenge history',
      subtitle: 'View your completed debates\n(Coming soon)',
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(ChallengeMessage challenge) {
    final timeAgo = _getTimeAgo(challenge.createdAt);
    final isExpiringSoon = challenge.expiresAt.difference(DateTime.now()).inHours < 2;
    final isDismissed = challenge.isDismissed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDismissed ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDismissed 
              ? Colors.grey.shade300
              : isExpiringSoon 
                  ? Colors.orange.shade300
                  : scarletRed.withValues(alpha: 0.2),
          width: isDismissed ? 1 : 2,
        ),
      ),
      child: InkWell(
        onTap: () => _showChallengeModal(challenge),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with challenger info and timestamp
              Row(
                children: [
                  UserAvatar(
                    avatarUrl: challenge.challengerAvatar,
                    initials: challenge.challengerName.isNotEmpty ? challenge.challengerName[0] : '?',
                    radius: 20,
                    backgroundColor: lightScarlet,
                    textColor: scarletRed,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.challengerName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDismissed ? Colors.grey[600] : deepPurple,
                          ),
                        ),
                        Text(
                          'wants to debate with you',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDismissed ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      if (isDismissed)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Dismissed',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (isExpiringSoon && !isDismissed)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Expires soon',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Challenge topic
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDismissed ? Colors.grey[50] : lightScarlet,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDismissed ? Colors.grey[200]! : scarletRed.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debate Topic:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDismissed ? Colors.grey[600] : deepPurple,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge.topic,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDismissed ? Colors.grey[700] : scarletRed,
                      ),
                    ),
                    if (challenge.description != null && challenge.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        challenge.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDismissed ? Colors.grey[600] : Colors.grey[700],
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Position info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: challenge.position == 'affirmative' 
                      ? (isDismissed ? Colors.grey[100] : Colors.green.withValues(alpha: 0.1))
                      : (isDismissed ? Colors.grey[100] : Colors.red.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDismissed 
                        ? Colors.grey[300]!
                        : challenge.position == 'affirmative' 
                            ? Colors.green 
                            : Colors.red,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      challenge.position == 'affirmative' ? Icons.thumb_up : Icons.thumb_down,
                      color: isDismissed 
                          ? Colors.grey[500]
                          : challenge.position == 'affirmative' 
                              ? Colors.green 
                              : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${challenge.challengerName} argues ${challenge.position.toUpperCase()} • You argue ${challenge.position == 'affirmative' ? 'AGAINST' : 'FOR'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDismissed 
                            ? Colors.grey[600]
                            : challenge.position == 'affirmative' 
                                ? Colors.green.shade700 
                                : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Quick action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _respondToChallenge(challenge, 'declined'),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDismissed ? Colors.grey[600] : Colors.grey[700],
                        side: BorderSide(color: isDismissed ? Colors.grey[300]! : Colors.grey[400]!),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showChallengeModal(challenge),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDismissed ? Colors.grey[400] : deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _respondToChallenge(challenge, 'accepted'),
                      icon: const Icon(Icons.flash_on, size: 16),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDismissed ? Colors.grey[500] : scarletRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArenaRoleCard(ChallengeMessage invitation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: accentPurple.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showArenaRoleModal(invitation),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row - Inviter info and timestamp
                Row(
                  children: [
                    UserAvatar(
                      avatarUrl: invitation.challengerAvatar,
                      initials: invitation.challengerName.isNotEmpty 
                          ? invitation.challengerName[0] 
                          : '?',
                      radius: 20,
                      backgroundColor: lightScarlet,
                      textColor: accentPurple,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invitation.challengerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: deepPurple,
                            ),
                          ),
                          Text(
                            'invited you to be ${invitation.position}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatTime(invitation.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Arena Role Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentPurple.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            invitation.position == 'moderator' ? Icons.gavel : Icons.balance,
                            color: accentPurple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            invitation.position.toUpperCase() ?? 'ARENA ROLE',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: accentPurple,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        invitation.topic,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: deepPurple,
                        ),
                      ),
                      if (invitation.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          invitation.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _respondToArenaRole(invitation, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scarletRed,
                          side: BorderSide(color: scarletRed),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _respondToArenaRole(invitation, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text('Accept ${invitation.position}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showArenaRoleModal(ChallengeMessage invitation) {
    // For now, just show a simple dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${invitation.position.toUpperCase()} Invitation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${invitation.challengerName}'),
            const SizedBox(height: 8),
            Text('Topic: ${invitation.topic}'),
            if (invitation.description?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('Description: ${invitation.description}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToArenaRole(invitation, false);
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToArenaRole(invitation, true);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _respondToArenaRole(ChallengeMessage invitation, bool accept) async {
    try {
      await _messagingService.respondToArenaRoleInvitation(
        invitationId: invitation.id,
        accept: accept,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept 
              ? '✅ Accepted ${invitation.position} role!'
              : '❌ Declined ${invitation.position} role'),
            backgroundColor: accept ? Colors.green : scarletRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error responding to invitation: $e'),
            backgroundColor: scarletRed,
          ),
        );
      }
    }
  }

  void _showChallengeModal(ChallengeMessage challenge) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => ChallengeModal(
        challenge: challenge.toModalFormat(),
        onDismiss: () {
          Navigator.of(context).pop();
          // Mark as dismissed if user closes modal
          _messagingService.dismissChallenge(challenge.id);
        },
      ),
    );
  }

  Future<void> _respondToChallenge(ChallengeMessage challenge, String response) async {
    try {
      await _messagingService.respondToChallenge(challenge.id, response);
      
      if (mounted) {
        final message = response == 'accepted' 
            ? '⚡ Challenge accepted! Arena room is being created...'
            : '❌ Challenge declined';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: response == 'accepted' ? Colors.green : Colors.orange,
          ),
        );

        // Navigate to arena if accepted
        if (response == 'accepted') {
          // The challenge update will be handled by the stream
          // Navigation will be triggered by the main app listening to challenge updates
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showNotificationCenter() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: NotificationCenter(
          notificationService: _notificationService,
          onNotificationTap: (notification) {
            // Mark as read when tapped
            _notificationService.markAsRead(notification.id);
            
            // Handle deep linking if needed
            if (notification.deepLink != null) {
              // TODO: Implement deep link navigation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deep link: ${notification.deepLink}'),
                  backgroundColor: Colors.blue,
                ),
              );
            }
          },
          onDismiss: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Widget _buildDeclinedNotificationCard(ChallengeMessage notification) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            UserAvatar(
              avatarUrl: notification.challengerAvatar,
              radius: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: <TextSpan>[
                        TextSpan(
                          text: notification.challengerName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' declined your challenge about '),
                        TextSpan(
                          text: '"${notification.topic}"',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.info_outline, color: Colors.grey),
          ],
        ),
      ),
    );
  }
} 