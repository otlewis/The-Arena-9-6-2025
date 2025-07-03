enum MembershipRole {
  member('member'),
  moderator('moderator'),
  admin('admin'),
  owner('owner');

  const MembershipRole(this.value);
  final String value;

  static MembershipRole fromString(String value) {
    return MembershipRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => MembershipRole.member,
    );
  }
}

enum MembershipStatus {
  active('active'),
  suspended('suspended'),
  pending('pending'),
  removed('removed');

  const MembershipStatus(this.value);
  final String value;

  static MembershipStatus fromString(String value) {
    return MembershipStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => MembershipStatus.active,
    );
  }
}

class Membership {
  final String id;
  final String userId;
  final String clubId;
  final String userName;
  final String? userAvatar;
  final String clubName;
  final MembershipRole role;
  final MembershipStatus status;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final String? invitedBy;
  final Map<String, dynamic> permissions;
  final Map<String, dynamic> metadata;

  Membership({
    required this.id,
    required this.userId,
    required this.clubId,
    required this.userName,
    this.userAvatar,
    required this.clubName,
    this.role = MembershipRole.member,
    this.status = MembershipStatus.active,
    required this.joinedAt,
    this.leftAt,
    this.invitedBy,
    this.permissions = const {},
    this.metadata = const {},
  });

  factory Membership.fromMap(Map<String, dynamic> map) {
    return Membership(
      id: map['\$id'] ?? map['id'] ?? '',
      userId: map['userId'] ?? '',
      clubId: map['clubId'] ?? '',
      userName: map['userName'] ?? '',
      userAvatar: map['userAvatar'],
      clubName: map['clubName'] ?? '',
      role: MembershipRole.fromString(map['role'] ?? 'member'),
      status: MembershipStatus.fromString(map['status'] ?? 'active'),
      joinedAt: DateTime.parse(map['joinedAt'] ?? map['\$createdAt'] ?? DateTime.now().toIso8601String()),
      leftAt: map['leftAt'] != null ? DateTime.parse(map['leftAt']) : null,
      invitedBy: map['invitedBy'],
      permissions: Map<String, dynamic>.from(map['permissions'] ?? {}),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'clubId': clubId,
      'userName': userName,
      'userAvatar': userAvatar,
      'clubName': clubName,
      'role': role.value,
      'status': status.value,
      'joinedAt': joinedAt.toIso8601String(),
      'leftAt': leftAt?.toIso8601String(),
      'invitedBy': invitedBy,
      'permissions': permissions,
      'metadata': metadata,
    };
  }

  Membership copyWith({
    String? id,
    String? userId,
    String? clubId,
    String? userName,
    String? userAvatar,
    String? clubName,
    MembershipRole? role,
    MembershipStatus? status,
    DateTime? joinedAt,
    DateTime? leftAt,
    String? invitedBy,
    Map<String, dynamic>? permissions,
    Map<String, dynamic>? metadata,
  }) {
    return Membership(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      clubId: clubId ?? this.clubId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      clubName: clubName ?? this.clubName,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      invitedBy: invitedBy ?? this.invitedBy,
      permissions: permissions ?? this.permissions,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper methods
  bool get isActive => status == MembershipStatus.active;
  bool get isPending => status == MembershipStatus.pending;
  bool get isSuspended => status == MembershipStatus.suspended;
  bool get isRemoved => status == MembershipStatus.removed;

  bool get isMember => role == MembershipRole.member;
  bool get isModerator => role == MembershipRole.moderator;
  bool get isAdmin => role == MembershipRole.admin;
  bool get isOwner => role == MembershipRole.owner;

  bool get canModerate => role == MembershipRole.moderator || role == MembershipRole.admin || role == MembershipRole.owner;
  bool get canAdministrate => role == MembershipRole.admin || role == MembershipRole.owner;
  bool get canManageClub => role == MembershipRole.owner;

  Duration get membershipDuration {
    final endTime = leftAt ?? DateTime.now();
    return endTime.difference(joinedAt);
  }

  bool hasPermission(String permission) {
    return permissions[permission] == true;
  }

  @override
  String toString() {
    return 'Membership(id: $id, userId: $userId, clubId: $clubId, role: ${role.value})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Membership && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 