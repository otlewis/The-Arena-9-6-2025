import 'notification_types.dart';

/// Core notification model for the Arena app
class ArenaNotification {
  final String id;
  final NotificationType type;
  final String userId;
  final String title;
  final String message;
  final Map<String, dynamic> payload;
  final NotificationPriority priority;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isRead;
  final bool isDismissed;
  final List<NotificationAction> actions;
  final String? imageUrl;
  final String? deepLink;
  final String? soundFile;
  final bool enableVibration;
  final Set<NotificationDeliveryMethod> deliveryMethods;

  const ArenaNotification({
    required this.id,
    required this.type,
    required this.userId,
    required this.title,
    required this.message,
    this.payload = const {},
    this.priority = NotificationPriority.medium,
    required this.createdAt,
    this.expiresAt,
    this.isRead = false,
    this.isDismissed = false,
    this.actions = const [],
    this.imageUrl,
    this.deepLink,
    this.soundFile,
    this.enableVibration = false,
    this.deliveryMethods = const {NotificationDeliveryMethod.inApp},
  });

  /// Check if notification is expired
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Check if notification is active (not read, dismissed, or expired)
  bool get isActive => !isRead && !isDismissed && !isExpired;

  /// Get appropriate sound file based on type
  String get defaultSoundFile {
    switch (type) {
      case NotificationType.challenge:
        return 'challenge.mp3';
      case NotificationType.arenaRole:
        return 'challenge.mp3';
      case NotificationType.arenaStarted:
        return 'ding.mp3';
      case NotificationType.arenaEnded:
        return 'applause.mp3';
      case NotificationType.voteReminder:
        return '30sec.mp3';
      default:
        return 'ding.mp3';
    }
  }

  /// Get delivery methods based on priority and type
  Set<NotificationDeliveryMethod> get defaultDeliveryMethods {
    switch (priority) {
      case NotificationPriority.urgent:
        return {
          NotificationDeliveryMethod.modal,
          NotificationDeliveryMethod.push,
          NotificationDeliveryMethod.sound,
          NotificationDeliveryMethod.vibration,
        };
      case NotificationPriority.high:
        return {
          NotificationDeliveryMethod.banner,
          NotificationDeliveryMethod.push,
          NotificationDeliveryMethod.sound,
        };
      case NotificationPriority.medium:
        return {
          NotificationDeliveryMethod.banner,
          NotificationDeliveryMethod.push,
        };
      case NotificationPriority.low:
        return {
          NotificationDeliveryMethod.inApp,
        };
    }
  }

  /// Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.value,
      'userId': userId,
      'title': title,
      'message': message,
      'payload': payload,
      'priority': priority.value,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'isRead': isRead,
      'isDismissed': isDismissed,
      'actions': actions.map((a) => a.toMap()).toList(),
      'imageUrl': imageUrl,
      'deepLink': deepLink,
      'soundFile': soundFile,
      'enableVibration': enableVibration,
      'deliveryMethods': deliveryMethods.map((m) => m.name).toList(),
    };
  }

  /// Create from map
  factory ArenaNotification.fromMap(Map<String, dynamic> map) {
    return ArenaNotification(
      id: map['id'] ?? '',
      type: NotificationType.fromString(map['type'] ?? ''),
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
      priority: NotificationPriority.fromInt(map['priority'] ?? 3),
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      expiresAt: map['expiresAt'] != null ? DateTime.parse(map['expiresAt']) : null,
      isRead: map['isRead'] ?? false,
      isDismissed: map['isDismissed'] ?? false,
      actions: (map['actions'] as List<dynamic>?)
          ?.map((a) => NotificationAction.fromMap(a))
          .toList() ?? [],
      imageUrl: map['imageUrl'],
      deepLink: map['deepLink'],
      soundFile: map['soundFile'],
      enableVibration: map['enableVibration'] ?? false,
      deliveryMethods: (map['deliveryMethods'] as List<dynamic>?)
          ?.map((m) => NotificationDeliveryMethod.values.byName(m))
          .toSet() ?? {NotificationDeliveryMethod.inApp},
    );
  }

  /// Create a copy with updated fields
  ArenaNotification copyWith({
    String? id,
    NotificationType? type,
    String? userId,
    String? title,
    String? message,
    Map<String, dynamic>? payload,
    NotificationPriority? priority,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isRead,
    bool? isDismissed,
    List<NotificationAction>? actions,
    String? imageUrl,
    String? deepLink,
    String? soundFile,
    bool? enableVibration,
    Set<NotificationDeliveryMethod>? deliveryMethods,
  }) {
    return ArenaNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      payload: payload ?? this.payload,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isRead: isRead ?? this.isRead,
      isDismissed: isDismissed ?? this.isDismissed,
      actions: actions ?? this.actions,
      imageUrl: imageUrl ?? this.imageUrl,
      deepLink: deepLink ?? this.deepLink,
      soundFile: soundFile ?? this.soundFile,
      enableVibration: enableVibration ?? this.enableVibration,
      deliveryMethods: deliveryMethods ?? this.deliveryMethods,
    );
  }

  /// Create from existing ChallengeMessage
  factory ArenaNotification.fromChallengeMessage(dynamic challengeMessage) {
    final type = challengeMessage.isArenaRole 
        ? NotificationType.arenaRole 
        : NotificationType.challenge;
    
    final priority = challengeMessage.isArenaRole 
        ? NotificationPriority.urgent 
        : NotificationPriority.high;

    return ArenaNotification(
      id: challengeMessage.id,
      type: type,
      userId: challengeMessage.challengedId,
      title: challengeMessage.isArenaRole 
          ? 'Arena Role Invitation'
          : 'Challenge Received',
      message: challengeMessage.isArenaRole
          ? 'You\'ve been invited to be a ${challengeMessage.position} for "${challengeMessage.topic}"'
          : '${challengeMessage.challengerName} challenges you to debate "${challengeMessage.topic}"',
      payload: challengeMessage.toModalFormat(),
      priority: priority,
      createdAt: challengeMessage.createdAt,
      expiresAt: challengeMessage.expiresAt,
      actions: _getActionsForChallengeMessage(challengeMessage),
      deliveryMethods: priority == NotificationPriority.urgent
          ? {
              NotificationDeliveryMethod.modal,
              NotificationDeliveryMethod.sound,
              NotificationDeliveryMethod.vibration,
            }
          : {
              NotificationDeliveryMethod.banner,
              NotificationDeliveryMethod.sound,
            },
    );
  }

  static List<NotificationAction> _getActionsForChallengeMessage(dynamic challengeMessage) {
    if (challengeMessage.isArenaRole) {
      return [
        NotificationAction(
          id: 'accept_role',
          label: 'Accept',
          data: {'challengeId': challengeMessage.id, 'action': 'accept'},
        ),
        NotificationAction(
          id: 'decline_role',
          label: 'Decline',
          data: {'challengeId': challengeMessage.id, 'action': 'decline'},
        ),
      ];
    } else {
      return [
        NotificationAction(
          id: 'accept_challenge',
          label: 'Accept',
          data: {'challengeId': challengeMessage.id, 'action': 'accept'},
        ),
        NotificationAction(
          id: 'decline_challenge',
          label: 'Decline',
          data: {'challengeId': challengeMessage.id, 'action': 'decline'},
        ),
        NotificationAction(
          id: 'view_challenge',
          label: 'View',
          deepLink: '/challenges/${challengeMessage.id}',
        ),
      ];
    }
  }
}