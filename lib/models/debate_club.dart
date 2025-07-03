class DebateClub {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;
  final int maxMembers;
  final List<String> tags;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> metadata;

  DebateClub({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isPublic = true,
    this.maxMembers = 100,
    this.tags = const [],
    this.settings = const {},
    this.metadata = const {},
  });

  factory DebateClub.fromMap(Map<String, dynamic> map) {
    return DebateClub(
      id: map['\$id'] ?? map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: DateTime.parse(map['\$createdAt'] ?? map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['\$updatedAt'] ?? map['updatedAt'] ?? DateTime.now().toIso8601String()),
      isPublic: map['isPublic'] ?? true,
      maxMembers: map['maxMembers'] ?? 100,
      tags: List<String>.from(map['tags'] ?? []),
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'isPublic': isPublic,
      'maxMembers': maxMembers,
      'tags': tags,
      'settings': settings,
      'metadata': metadata,
    };
  }

  DebateClub copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    int? maxMembers,
    List<String>? tags,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? metadata,
  }) {
    return DebateClub(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
      maxMembers: maxMembers ?? this.maxMembers,
      tags: tags ?? this.tags,
      settings: settings ?? this.settings,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper methods
  bool get isPrivate => !isPublic;
  
  bool hasTag(String tag) => tags.contains(tag);
  
  @override
  String toString() {
    return 'DebateClub(id: $id, name: $name, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DebateClub && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 