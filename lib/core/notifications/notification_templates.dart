import 'notification_model.dart';
import 'notification_types.dart';
import 'notification_service.dart';

/// Pre-built notification templates for common use cases
class NotificationTemplates {
  
  /// Create a challenge invitation notification
  static ArenaNotification challengeInvitation({
    required String challengerId,
    required String challengedId,
    required String challengerName,
    required String topic,
    required String position,
    String? description,
    String? category,
  }) {
    return ArenaNotification(
      id: 'challenge_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.challenge,
      userId: challengedId,
      title: 'Challenge Invitation',
      message: '$challengerName challenges you to debate "$topic" as the $position side',
      payload: {
        'challengerId': challengerId,
        'challengerName': challengerName,
        'topic': topic,
        'position': position,
        'description': description,
        'category': category,
      },
      priority: NotificationPriority.high,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      actions: [
        NotificationAction(
          id: 'accept',
          label: 'Accept',
          data: {'action': 'accept'},
        ),
        NotificationAction(
          id: 'decline', 
          label: 'Decline',
          data: {'action': 'decline'},
        ),
        NotificationAction(
          id: 'view_details',
          label: 'View Details',
          deepLink: '/challenges/pending',
        ),
      ],
      deliveryMethods: {
        NotificationDeliveryMethod.modal,
        NotificationDeliveryMethod.banner,
        NotificationDeliveryMethod.push,
        NotificationDeliveryMethod.sound,
        NotificationDeliveryMethod.vibration,
      },
    );
  }

  /// Create an arena role invitation notification
  static ArenaNotification arenaRoleInvitation({
    required String userId,
    required String role,
    required String arenaId,
    required String topic,
    String? inviterName,
    String? description,
    Duration? expiry,
  }) {
    final isPersonalInvite = inviterName != null;
    
    return ArenaNotification(
      id: 'arena_role_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.arenaRole,
      userId: userId,
      title: isPersonalInvite ? 'Personal Arena Invitation' : 'Arena Role Invitation',
      message: isPersonalInvite 
          ? '$inviterName invites you to be a $role for "$topic"'
          : 'You\'ve been invited to be a $role for "$topic"',
      payload: {
        'role': role,
        'arenaId': arenaId,
        'topic': topic,
        'inviterName': inviterName,
        'description': description,
      },
      priority: NotificationPriority.urgent,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(expiry ?? const Duration(hours: 2)),
      actions: [
        NotificationAction(
          id: 'accept_role',
          label: 'Accept',
          data: {'action': 'accept', 'arenaId': arenaId},
        ),
        NotificationAction(
          id: 'decline_role',
          label: 'Decline', 
          data: {'action': 'decline', 'arenaId': arenaId},
        ),
        NotificationAction(
          id: 'view_arena',
          label: 'View Arena',
          deepLink: '/arena/$arenaId',
        ),
      ],
      deliveryMethods: {
        NotificationDeliveryMethod.modal,
        NotificationDeliveryMethod.push,
        NotificationDeliveryMethod.sound,
        NotificationDeliveryMethod.vibration,
      },
    );
  }

  /// Create an arena started notification
  static ArenaNotification arenaStarted({
    required String userId,
    required String arenaId,
    required String topic,
    required List<String> participants,
  }) {
    return ArenaNotification(
      id: 'arena_started_${arenaId}_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.arenaStarted,
      userId: userId,
      title: 'Arena Debate Started',
      message: 'The debate "$topic" has begun with ${participants.length} participants',
      payload: {
        'arenaId': arenaId,
        'topic': topic,
        'participants': participants,
      },
      priority: NotificationPriority.medium,
      createdAt: DateTime.now(),
      actions: [
        NotificationAction(
          id: 'join_arena',
          label: 'Join Now',
          deepLink: '/arena/$arenaId',
        ),
      ],
      deliveryMethods: {
        NotificationDeliveryMethod.banner,
        NotificationDeliveryMethod.push,
        NotificationDeliveryMethod.sound,
      },
    );
  }

  /// Create an arena ended notification
  static ArenaNotification arenaEnded({
    required String userId,
    required String arenaId,
    required String topic,
    String? winner,
    Map<String, dynamic>? results,
  }) {
    return ArenaNotification(
      id: 'arena_ended_${arenaId}_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.arenaEnded,
      userId: userId,
      title: 'Arena Debate Ended',
      message: winner != null 
          ? 'The debate "$topic" has ended. Winner: $winner'
          : 'The debate "$topic" has concluded',
      payload: {
        'arenaId': arenaId,
        'topic': topic,
        'winner': winner,
        'results': results,
      },
      priority: NotificationPriority.low,
      createdAt: DateTime.now(),
      actions: [
        NotificationAction(
          id: 'view_results',
          label: 'View Results',
          deepLink: '/arena/$arenaId/results',
        ),
      ],
      deliveryMethods: {
        NotificationDeliveryMethod.banner,
        NotificationDeliveryMethod.push,
      },
      soundFile: 'applause.mp3',
    );
  }

  /// Create a friend request notification
  static ArenaNotification friendRequest({
    required String userId,
    required String requesterId,
    required String requesterName,
    String? requesterAvatar,
  }) {
    return ArenaNotification(
      id: 'friend_request_${requesterId}_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.friendRequest,
      userId: userId,
      title: 'Friend Request',
      message: '$requesterName wants to connect with you',
      payload: {
        'requesterId': requesterId,
        'requesterName': requesterName,
        'requesterAvatar': requesterAvatar,
      },
      priority: NotificationPriority.low,
      createdAt: DateTime.now(),
      imageUrl: requesterAvatar,
      actions: [
        NotificationAction(
          id: 'accept_friend',
          label: 'Accept',
          data: {'action': 'accept', 'requesterId': requesterId},
        ),
        NotificationAction(
          id: 'decline_friend',
          label: 'Decline',
          data: {'action': 'decline', 'requesterId': requesterId},
        ),
      ],
      deliveryMethods: {
        NotificationDeliveryMethod.banner,
        NotificationDeliveryMethod.push,
      },
    );
  }

  /// Create a mention notification
  static ArenaNotification mention({
    required String userId,
    required String mentionerId,
    required String mentionerName,
    required String context,
    required String roomId,
    String? roomName,
  }) {
    return ArenaNotification(
      id: 'mention_${roomId}_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.mention,
      userId: userId,
      title: 'You were mentioned',
      message: '$mentionerName mentioned you${roomName != null ? ' in $roomName' : ''}',
      payload: {
        'mentionerId': mentionerId,
        'mentionerName': mentionerName,
        'context': context,
        'roomId': roomId,
        'roomName': roomName,
      },
      priority: NotificationPriority.medium,
      createdAt: DateTime.now(),
      actions: [
        NotificationAction(
          id: 'view_message',
          label: 'View',
          deepLink: '/room/$roomId',
        ),
      ],
      deliveryMethods: {
        NotificationDeliveryMethod.banner,
        NotificationDeliveryMethod.push,
        NotificationDeliveryMethod.sound,
      },
    );
  }

  /// Create an achievement notification
  static ArenaNotification achievement({
    required String userId,
    required String achievementId,
    required String title,
    required String description,
    String? iconUrl,
    int? points,
  }) {
    return ArenaNotification(
      id: 'achievement_${achievementId}_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.achievement,
      userId: userId,
      title: 'Achievement Unlocked!',
      message: title,
      payload: {
        'achievementId': achievementId,
        'title': title,
        'description': description,
        'points': points,
      },
      priority: NotificationPriority.low,
      createdAt: DateTime.now(),
      imageUrl: iconUrl,
      actions: [
        NotificationAction(
          id: 'view_achievements',
          label: 'View All',
          deepLink: '/profile/achievements',
        ),
      ],
      deliveryMethods: {
        NotificationDeliveryMethod.banner,
        NotificationDeliveryMethod.push,
      },
    );
  }

  /// Create a vote reminder notification
  static ArenaNotification voteReminder({
    required String userId,
    required String arenaId,
    required String topic,
    required Duration timeRemaining,
  }) {
    return ArenaNotification(
      id: 'vote_reminder_${arenaId}_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.voteReminder,
      userId: userId,
      title: 'Vote Reminder',
      message: 'Don\'t forget to vote on "$topic" - ${_formatDuration(timeRemaining)} remaining',
      payload: {
        'arenaId': arenaId,
        'topic': topic,
        'timeRemaining': timeRemaining.inMinutes,
      },
      priority: NotificationPriority.high,
      createdAt: DateTime.now(),
      actions: [
        NotificationAction(
          id: 'vote_now',
          label: 'Vote Now',
          deepLink: '/arena/$arenaId/vote',
        ),
      ],
      deliveryMethods: {
        NotificationDeliveryMethod.banner,
        NotificationDeliveryMethod.push,
        NotificationDeliveryMethod.sound,
        NotificationDeliveryMethod.vibration,
      },
      soundFile: '30sec.mp3',
    );
  }

  /// Create a tournament invitation notification
  static ArenaNotification tournamentInvitation({
    required String userId,
    required String tournamentId,
    required String tournamentName,
    required DateTime startTime,
    int? participantLimit,
    String? prize,
  }) {
    return ArenaNotification(
      id: 'tournament_${tournamentId}_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.tournamentInvite,
      userId: userId,
      title: 'Tournament Invitation',
      message: 'You\'re invited to join "$tournamentName"${prize != null ? ' - Prize: $prize' : ''}',
      payload: {
        'tournamentId': tournamentId,
        'tournamentName': tournamentName,
        'startTime': startTime.toIso8601String(),
        'participantLimit': participantLimit,
        'prize': prize,
      },
      priority: NotificationPriority.medium,
      createdAt: DateTime.now(),
      expiresAt: startTime.subtract(const Duration(hours: 1)), // Expire 1 hour before start
      actions: [
        NotificationAction(
          id: 'join_tournament',
          label: 'Join',
          data: {'action': 'join', 'tournamentId': tournamentId},
        ),
        NotificationAction(
          id: 'view_tournament',
          label: 'View Details',
          deepLink: '/tournaments/$tournamentId',
        ),
      ],
      deliveryMethods: {
        NotificationDeliveryMethod.banner,
        NotificationDeliveryMethod.push,
      },
    );
  }

  /// Create a system announcement notification
  static ArenaNotification systemAnnouncement({
    required String title,
    required String message,
    String? imageUrl,
    String? actionUrl,
    String? actionLabel,
    NotificationPriority priority = NotificationPriority.medium,
  }) {
    return ArenaNotification(
      id: 'system_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.systemAnnouncement,
      userId: '', // Will be sent to all users
      title: title,
      message: message,
      priority: priority,
      createdAt: DateTime.now(),
      imageUrl: imageUrl,
      actions: actionUrl != null ? [
        NotificationAction(
          id: 'system_action',
          label: actionLabel ?? 'Learn More',
          deepLink: actionUrl,
        ),
      ] : [],
      deliveryMethods: {
        NotificationDeliveryMethod.banner,
        NotificationDeliveryMethod.push,
      },
    );
  }

  /// Helper function to format duration
  static String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

/// Extension methods for easier notification creation
extension NotificationServiceTemplates on NotificationService {
  
  /// Send a challenge invitation using template
  Future<void> sendChallengeInvitation({
    required String challengerId,
    required String challengedId,
    required String challengerName,
    required String topic,
    required String position,
    String? description,
    String? category,
  }) async {
    final notification = NotificationTemplates.challengeInvitation(
      challengerId: challengerId,
      challengedId: challengedId,
      challengerName: challengerName,
      topic: topic,
      position: position,
      description: description,
      category: category,
    );
    
    await sendNotification(
      type: notification.type,
      userId: notification.userId,
      title: notification.title,
      message: notification.message,
      payload: notification.payload,
      priority: notification.priority,
      actions: notification.actions,
      deliveryMethods: notification.deliveryMethods,
    );
  }

  /// Send an arena role invitation using template
  Future<void> sendArenaRoleInvitation({
    required String userId,
    required String role,
    required String arenaId,
    required String topic,
    String? inviterName,
    String? description,
    Duration? expiry,
  }) async {
    final notification = NotificationTemplates.arenaRoleInvitation(
      userId: userId,
      role: role,
      arenaId: arenaId,
      topic: topic,
      inviterName: inviterName,
      description: description,
      expiry: expiry,
    );
    
    await sendNotification(
      type: notification.type,
      userId: notification.userId,
      title: notification.title,
      message: notification.message,
      payload: notification.payload,
      priority: notification.priority,
      actions: notification.actions,
      deliveryMethods: notification.deliveryMethods,
    );
  }

  /// Send an achievement notification using template
  Future<void> sendAchievement({
    required String userId,
    required String achievementId,
    required String title,
    required String description,
    String? iconUrl,
    int? points,
  }) async {
    final notification = NotificationTemplates.achievement(
      userId: userId,
      achievementId: achievementId,
      title: title,
      description: description,
      iconUrl: iconUrl,
      points: points,
    );
    
    await sendNotification(
      type: notification.type,
      userId: notification.userId,
      title: notification.title,
      message: notification.message,
      payload: notification.payload,
      priority: notification.priority,
      imageUrl: notification.imageUrl,
      actions: notification.actions,
      deliveryMethods: notification.deliveryMethods,
    );
  }

  /// Send a vote reminder using template
  Future<void> sendVoteReminder({
    required String userId,
    required String arenaId,
    required String topic,
    required Duration timeRemaining,
  }) async {
    final notification = NotificationTemplates.voteReminder(
      userId: userId,
      arenaId: arenaId,
      topic: topic,
      timeRemaining: timeRemaining,
    );
    
    await sendNotification(
      type: notification.type,
      userId: notification.userId,
      title: notification.title,
      message: notification.message,
      payload: notification.payload,
      priority: notification.priority,
      actions: notification.actions,
      soundFile: notification.soundFile,
      deliveryMethods: notification.deliveryMethods,
    );
  }
}