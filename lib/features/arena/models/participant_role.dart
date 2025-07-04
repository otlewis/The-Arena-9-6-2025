/// Enum representing different participant roles in an arena debate
enum ParticipantRole {
  affirmative('affirmative', 'Affirmative Debater', 'Argues for the topic'),
  negative('negative', 'Negative Debater', 'Argues against the topic'),
  moderator('moderator', 'Moderator', 'Manages the debate flow'),
  judge1('judge1', 'Judge 1', 'Evaluates the debate'),
  judge2('judge2', 'Judge 2', 'Evaluates the debate'),
  judge3('judge3', 'Judge 3', 'Evaluates the debate'),
  audience('audience', 'Audience', 'Observes the debate');

  const ParticipantRole(this.id, this.displayName, this.description);
  
  final String id;
  final String displayName;
  final String description;
  
  /// Returns true if this role is a debater
  bool get isDebater => this == ParticipantRole.affirmative || this == ParticipantRole.negative;
  
  /// Returns true if this role is a judge
  bool get isJudge => id.startsWith('judge');
  
  /// Returns true if this role can speak during debates
  bool get canSpeak => isDebater || this == ParticipantRole.moderator;
  
  /// Returns true if this role can vote
  bool get canVote => isJudge || this == ParticipantRole.audience;
  
  /// Returns true if this role has administrative privileges
  bool get hasAdminPrivileges => this == ParticipantRole.moderator;
  
  /// Returns the color associated with this role
  String get colorHex {
    switch (this) {
      case ParticipantRole.affirmative:
        return '#4CAF50'; // Green
      case ParticipantRole.negative:
        return '#FF2400'; // Red
      case ParticipantRole.moderator:
        return '#8B5CF6'; // Purple
      case ParticipantRole.judge1:
      case ParticipantRole.judge2:
      case ParticipantRole.judge3:
        return '#FFC107'; // Amber
      case ParticipantRole.audience:
        return '#9E9E9E'; // Grey
    }
  }
  
  /// Gets role by ID
  static ParticipantRole? fromId(String id) {
    try {
      return ParticipantRole.values.firstWhere((role) => role.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Returns all judge roles
  static List<ParticipantRole> get judgeRoles => [
    ParticipantRole.judge1,
    ParticipantRole.judge2,
    ParticipantRole.judge3,
  ];
  
  /// Returns all debater roles
  static List<ParticipantRole> get debaterRoles => [
    ParticipantRole.affirmative,
    ParticipantRole.negative,
  ];
}