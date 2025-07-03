enum RoomType {
  debate('debate'),
  discussion('discussion'),
  arena('arena');

  const RoomType(this.value);
  final String value;

  static RoomType fromString(String value) {
    return RoomType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => RoomType.discussion,
    );
  }
}

enum RoomStatus {
  scheduled('scheduled'),
  active('active'),
  paused('paused'),
  ended('ended');

  const RoomStatus(this.value);
  final String value;

  static RoomStatus fromString(String value) {
    return RoomStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => RoomStatus.scheduled,
    );
  }
}

enum DebateFormat {
  oxford('oxford'),
  lincolnDouglas('lincoln_douglas'),
  parliamentary('parliamentary'),
  fishbowl('fishbowl'),
  openFloor('open_floor');

  const DebateFormat(this.value);
  final String value;

  static DebateFormat fromString(String value) {
    return DebateFormat.values.firstWhere(
      (format) => format.value == value,
      orElse: () => DebateFormat.openFloor,
    );
  }
}

class Room {
  final String id;
  final String title;
  final String description;
  final RoomType type;
  final RoomStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? clubId;
  final bool isPublic;
  final int maxParticipants;
  final List<String> participantIds;
  final String? moderatorId;
  final Map<String, dynamic> settings;

  // Debate-specific properties
  final DebateFormat? debateFormat;
  final int? timeLimit; // in minutes
  final bool? votingEnabled;
  final String? currentSpeakerId;
  final List<String>? speakerQueue;
  final Map<String, List<String>>? sides; // {'pro': [userIds], 'con': [userIds]}

  // Discussion-specific properties
  final List<String>? tags;

  // Arena-specific properties
  final bool? isFeatured;
  final String? prizeDescription;
  final List<String>? judgeIds;

  Room({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.clubId,
    this.isPublic = true,
    this.maxParticipants = 50,
    this.participantIds = const [],
    this.moderatorId,
    this.settings = const {},
    this.debateFormat,
    this.timeLimit,
    this.votingEnabled,
    this.currentSpeakerId,
    this.speakerQueue,
    this.sides,
    this.tags,
    this.isFeatured,
    this.prizeDescription,
    this.judgeIds,
  });

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: RoomType.fromString(map['type'] ?? 'discussion'),
      status: RoomStatus.fromString(map['status'] ?? 'scheduled'),
      createdBy: map['createdBy'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      scheduledAt: map['scheduledAt'] != null ? DateTime.parse(map['scheduledAt']) : null,
      startedAt: map['startedAt'] != null ? DateTime.parse(map['startedAt']) : null,
      endedAt: map['endedAt'] != null ? DateTime.parse(map['endedAt']) : null,
      clubId: map['clubId'],
      isPublic: map['isPublic'] ?? true,
      maxParticipants: map['maxParticipants'] ?? 50,
      participantIds: List<String>.from(map['participantIds'] ?? []),
      moderatorId: map['moderatorId'],
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
      debateFormat: map['debateFormat'] != null 
          ? DebateFormat.fromString(map['debateFormat']) 
          : null,
      timeLimit: map['timeLimit'],
      votingEnabled: map['votingEnabled'],
      currentSpeakerId: map['currentSpeakerId'],
      speakerQueue: map['speakerQueue'] != null 
          ? List<String>.from(map['speakerQueue']) 
          : null,
      sides: map['sides'] != null 
          ? Map<String, List<String>>.from(
              map['sides'].map((key, value) => MapEntry(key, List<String>.from(value)))
            )
          : null,
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      isFeatured: map['isFeatured'],
      prizeDescription: map['prizeDescription'],
      judgeIds: map['judgeIds'] != null ? List<String>.from(map['judgeIds']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.value,
      'status': status.value,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'scheduledAt': scheduledAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'clubId': clubId,
      'isPublic': isPublic,
      'maxParticipants': maxParticipants,
      'participantIds': participantIds,
      'moderatorId': moderatorId,
      'settings': settings,
      'debateFormat': debateFormat?.value,
      'timeLimit': timeLimit,
      'votingEnabled': votingEnabled,
      'currentSpeakerId': currentSpeakerId,
      'speakerQueue': speakerQueue,
      'sides': sides,
      'tags': tags,
      'isFeatured': isFeatured,
      'prizeDescription': prizeDescription,
      'judgeIds': judgeIds,
    };
  }

  Room copyWith({
    String? id,
    String? title,
    String? description,
    RoomType? type,
    RoomStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? scheduledAt,
    DateTime? startedAt,
    DateTime? endedAt,
    String? clubId,
    bool? isPublic,
    int? maxParticipants,
    List<String>? participantIds,
    String? moderatorId,
    Map<String, dynamic>? settings,
    DebateFormat? debateFormat,
    int? timeLimit,
    bool? votingEnabled,
    String? currentSpeakerId,
    List<String>? speakerQueue,
    Map<String, List<String>>? sides,
    List<String>? tags,
    bool? isFeatured,
    String? prizeDescription,
    List<String>? judgeIds,
  }) {
    return Room(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      clubId: clubId ?? this.clubId,
      isPublic: isPublic ?? this.isPublic,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      participantIds: participantIds ?? this.participantIds,
      moderatorId: moderatorId ?? this.moderatorId,
      settings: settings ?? this.settings,
      debateFormat: debateFormat ?? this.debateFormat,
      timeLimit: timeLimit ?? this.timeLimit,
      votingEnabled: votingEnabled ?? this.votingEnabled,
      currentSpeakerId: currentSpeakerId ?? this.currentSpeakerId,
      speakerQueue: speakerQueue ?? this.speakerQueue,
      sides: sides ?? this.sides,
      tags: tags ?? this.tags,
      isFeatured: isFeatured ?? this.isFeatured,
      prizeDescription: prizeDescription ?? this.prizeDescription,
      judgeIds: judgeIds ?? this.judgeIds,
    );
  }

  // Helper methods
  bool get isDebateRoom => type == RoomType.debate;
  bool get isDiscussionRoom => type == RoomType.discussion;
  bool get isArenaRoom => type == RoomType.arena;
  
  bool get isActive => status == RoomStatus.active;
  bool get isScheduled => status == RoomStatus.scheduled;
  bool get hasEnded => status == RoomStatus.ended;
  
  int get participantCount => participantIds.length;
  bool get isFull => participantCount >= maxParticipants;
  
  bool canJoin(String? userId) {
    return !isFull && 
           status != RoomStatus.ended && 
           (userId == null || !participantIds.contains(userId));
  }
} 