enum VoteType {
  poll('poll'),
  winner('winner'),
  moderatorApproval('moderator_approval'),
  custom('custom');

  const VoteType(this.value);
  final String value;

  static VoteType fromString(String value) {
    return VoteType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => VoteType.poll,
    );
  }
}

class VoteOption {
  final String id;
  final String text;
  final int count;
  final List<String> voterIds;

  VoteOption({
    required this.id,
    required this.text,
    this.count = 0,
    this.voterIds = const [],
  });

  factory VoteOption.fromMap(Map<String, dynamic> map) {
    return VoteOption(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      count: map['count'] ?? 0,
      voterIds: List<String>.from(map['voterIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'count': count,
      'voterIds': voterIds,
    };
  }

  VoteOption copyWith({
    String? id,
    String? text,
    int? count,
    List<String>? voterIds,
  }) {
    return VoteOption(
      id: id ?? this.id,
      text: text ?? this.text,
      count: count ?? this.count,
      voterIds: voterIds ?? this.voterIds,
    );
  }
}

class Vote {
  final String id;
  final String roomId;
  final String createdBy;
  final String creatorName;
  final VoteType type;
  final String question;
  final List<VoteOption> options;
  final DateTime createdAt;
  final DateTime? endsAt;
  final bool isActive;
  final bool allowMultipleChoices;
  final bool isAnonymous;
  final List<String> eligibleVoterIds; // Empty list means all room participants can vote
  final Map<String, dynamic> metadata;

  Vote({
    required this.id,
    required this.roomId,
    required this.createdBy,
    required this.creatorName,
    this.type = VoteType.poll,
    required this.question,
    required this.options,
    required this.createdAt,
    this.endsAt,
    this.isActive = true,
    this.allowMultipleChoices = false,
    this.isAnonymous = false,
    this.eligibleVoterIds = const [],
    this.metadata = const {},
  });

  factory Vote.fromMap(Map<String, dynamic> map) {
    return Vote(
      id: map['id'] ?? '',
      roomId: map['roomId'] ?? '',
      createdBy: map['createdBy'] ?? '',
      creatorName: map['creatorName'] ?? '',
      type: VoteType.fromString(map['type'] ?? 'poll'),
      question: map['question'] ?? '',
      options: (map['options'] as List<dynamic>?)
          ?.map((option) => VoteOption.fromMap(option))
          .toList() ?? [],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      endsAt: map['endsAt'] != null ? DateTime.parse(map['endsAt']) : null,
      isActive: map['isActive'] ?? true,
      allowMultipleChoices: map['allowMultipleChoices'] ?? false,
      isAnonymous: map['isAnonymous'] ?? false,
      eligibleVoterIds: List<String>.from(map['eligibleVoterIds'] ?? []),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomId': roomId,
      'createdBy': createdBy,
      'creatorName': creatorName,
      'type': type.value,
      'question': question,
      'options': options.map((option) => option.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'endsAt': endsAt?.toIso8601String(),
      'isActive': isActive,
      'allowMultipleChoices': allowMultipleChoices,
      'isAnonymous': isAnonymous,
      'eligibleVoterIds': eligibleVoterIds,
      'metadata': metadata,
    };
  }

  Vote copyWith({
    String? id,
    String? roomId,
    String? createdBy,
    String? creatorName,
    VoteType? type,
    String? question,
    List<VoteOption>? options,
    DateTime? createdAt,
    DateTime? endsAt,
    bool? isActive,
    bool? allowMultipleChoices,
    bool? isAnonymous,
    List<String>? eligibleVoterIds,
    Map<String, dynamic>? metadata,
  }) {
    return Vote(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      type: type ?? this.type,
      question: question ?? this.question,
      options: options ?? this.options,
      createdAt: createdAt ?? this.createdAt,
      endsAt: endsAt ?? this.endsAt,
      isActive: isActive ?? this.isActive,
      allowMultipleChoices: allowMultipleChoices ?? this.allowMultipleChoices,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      eligibleVoterIds: eligibleVoterIds ?? this.eligibleVoterIds,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper methods
  bool get hasExpired => endsAt != null && DateTime.now().isAfter(endsAt!);
  bool get canVote => isActive && !hasExpired;
  
  int get totalVotes => options.fold(0, (sum, option) => sum + option.count);
  
  VoteOption? get leadingOption {
    if (options.isEmpty) return null;
    return options.reduce((a, b) => a.count > b.count ? a : b);
  }
  
  bool userHasVoted(String userId) {
    return options.any((option) => option.voterIds.contains(userId));
  }
  
  List<String> getUserVotes(String userId) {
    return options
        .where((option) => option.voterIds.contains(userId))
        .map((option) => option.id)
        .toList();
  }
  
  bool canUserVote(String userId) {
    if (!canVote) return false;
    if (eligibleVoterIds.isNotEmpty && !eligibleVoterIds.contains(userId)) return false;
    if (!allowMultipleChoices && userHasVoted(userId)) return false;
    return true;
  }
  
  // Factory methods for common vote types
  static Vote debateWinner({
    required String roomId,
    required String createdBy,
    required String creatorName,
    required List<String> sideOptions, // e.g., ['Pro Side', 'Con Side']
    DateTime? endsAt,
  }) {
    final options = sideOptions.asMap().entries.map((entry) {
      return VoteOption(
        id: entry.key.toString(),
        text: entry.value,
      );
    }).toList();

    return Vote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: roomId,
      createdBy: createdBy,
      creatorName: creatorName,
      type: VoteType.winner,
      question: 'Who won this debate?',
      options: options,
      createdAt: DateTime.now(),
      endsAt: endsAt,
      allowMultipleChoices: false,
      isAnonymous: false,
    );
  }
  
  static Vote quickPoll({
    required String roomId,
    required String createdBy,
    required String creatorName,
    required String question,
    required List<String> optionTexts,
    bool allowMultiple = false,
    bool anonymous = false,
    Duration? duration,
  }) {
    final options = optionTexts.asMap().entries.map((entry) {
      return VoteOption(
        id: entry.key.toString(),
        text: entry.value,
      );
    }).toList();

    return Vote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: roomId,
      createdBy: createdBy,
      creatorName: creatorName,
      type: VoteType.poll,
      question: question,
      options: options,
      createdAt: DateTime.now(),
      endsAt: duration != null ? DateTime.now().add(duration) : null,
      allowMultipleChoices: allowMultiple,
      isAnonymous: anonymous,
    );
  }
} 