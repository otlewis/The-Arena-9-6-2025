enum ParticipantRole {
  listener('listener'),
  speaker('speaker'),
  moderator('moderator'),
  judge('judge');

  const ParticipantRole(this.value);
  final String value;

  static ParticipantRole fromString(String value) {
    return ParticipantRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => ParticipantRole.listener,
    );
  }
}

enum ParticipantStatus {
  joined('joined'),
  speaking('speaking'),
  muted('muted'),
  left('left');

  const ParticipantStatus(this.value);
  final String value;

  static ParticipantStatus fromString(String value) {
    return ParticipantStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ParticipantStatus.joined,
    );
  }
}

class RoomParticipant {
  final String id;
  final String userId;
  final String roomId;
  final String userName;
  final String? userAvatar;
  final ParticipantRole role;
  final ParticipantStatus status;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final DateTime? lastActiveAt;
  final String? side; // For debates: 'pro', 'con', or null
  final int? speakingOrder; // Position in speaker queue
  final Map<String, dynamic> metadata;

  RoomParticipant({
    required this.id,
    required this.userId,
    required this.roomId,
    required this.userName,
    this.userAvatar,
    this.role = ParticipantRole.listener,
    this.status = ParticipantStatus.joined,
    required this.joinedAt,
    this.leftAt,
    this.lastActiveAt,
    this.side,
    this.speakingOrder,
    this.metadata = const {},
  });

  factory RoomParticipant.fromMap(Map<String, dynamic> map) {
    return RoomParticipant(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      roomId: map['roomId'] ?? '',
      userName: map['userName'] ?? '',
      userAvatar: map['userAvatar'],
      role: ParticipantRole.fromString(map['role'] ?? 'listener'),
      status: ParticipantStatus.fromString(map['status'] ?? 'joined'),
      joinedAt: DateTime.parse(map['joinedAt'] ?? DateTime.now().toIso8601String()),
      leftAt: map['leftAt'] != null ? DateTime.parse(map['leftAt']) : null,
      lastActiveAt: map['lastActiveAt'] != null ? DateTime.parse(map['lastActiveAt']) : null,
      side: map['side'],
      speakingOrder: map['speakingOrder'],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'roomId': roomId,
      'userName': userName,
      'userAvatar': userAvatar,
      'role': role.value,
      'status': status.value,
      'joinedAt': joinedAt.toIso8601String(),
      'leftAt': leftAt?.toIso8601String(),
      'lastActiveAt': lastActiveAt?.toIso8601String(),
      'side': side,
      'speakingOrder': speakingOrder,
      'metadata': metadata,
    };
  }

  RoomParticipant copyWith({
    String? id,
    String? userId,
    String? roomId,
    String? userName,
    String? userAvatar,
    ParticipantRole? role,
    ParticipantStatus? status,
    DateTime? joinedAt,
    DateTime? leftAt,
    DateTime? lastActiveAt,
    String? side,
    int? speakingOrder,
    Map<String, dynamic>? metadata,
  }) {
    return RoomParticipant(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      roomId: roomId ?? this.roomId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      side: side ?? this.side,
      speakingOrder: speakingOrder ?? this.speakingOrder,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper methods
  bool get isModerator => role == ParticipantRole.moderator;
  bool get isSpeaker => role == ParticipantRole.speaker;
  bool get isJudge => role == ParticipantRole.judge;
  bool get isListener => role == ParticipantRole.listener;
  
  bool get isActive => status == ParticipantStatus.joined || status == ParticipantStatus.speaking;
  bool get isSpeaking => status == ParticipantStatus.speaking;
  bool get isMuted => status == ParticipantStatus.muted;
  bool get hasLeft => status == ParticipantStatus.left;
  
  bool get isOnProSide => side == 'pro';
  bool get isOnConSide => side == 'con';
  bool get hasChosenSide => side != null;
  
  Duration get timeInRoom {
    final endTime = leftAt ?? DateTime.now();
    return endTime.difference(joinedAt);
  }
} 