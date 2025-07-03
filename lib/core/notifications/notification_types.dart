/// Notification types supported by the Arena app
enum NotificationType {
  // Existing types (from ChallengeMessagingService)
  challenge('challenge'),
  arenaRole('arena_role'),
  
  // New notification types
  arenaStarted('arena_started'),
  arenaEnded('arena_ended'),
  tournamentInvite('tournament_invite'),
  friendRequest('friend_request'),
  mention('mention'),
  achievement('achievement'),
  systemAnnouncement('system_announcement'),
  roomChat('room_chat'),
  voteReminder('vote_reminder'),
  followUp('follow_up');

  const NotificationType(this.value);
  final String value;
  
  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationType.systemAnnouncement,
    );
  }
}

/// Priority levels for notifications
enum NotificationPriority {
  low(1),
  medium(3),
  high(5),
  urgent(8);

  const NotificationPriority(this.value);
  final int value;
  
  static NotificationPriority fromInt(int value) {
    if (value >= 8) return NotificationPriority.urgent;
    if (value >= 5) return NotificationPriority.high;
    if (value >= 3) return NotificationPriority.medium;
    return NotificationPriority.low;
  }
}

/// Delivery methods for notifications
enum NotificationDeliveryMethod {
  inApp,
  banner,
  modal,
  push,
  sound,
  vibration;
}

/// Actions that can be performed on notifications
class NotificationAction {
  final String id;
  final String label;
  final String? deepLink;
  final Map<String, dynamic>? data;

  const NotificationAction({
    required this.id,
    required this.label,
    this.deepLink,
    this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'deepLink': deepLink,
      'data': data,
    };
  }

  factory NotificationAction.fromMap(Map<String, dynamic> map) {
    return NotificationAction(
      id: map['id'] ?? '',
      label: map['label'] ?? '',
      deepLink: map['deepLink'],
      data: map['data'],
    );
  }
}