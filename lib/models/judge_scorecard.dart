enum ScoringCategory {
  arguments('Arguments & Content', 20, 'Strength and logic of arguments, quality of evidence'),
  presentation('Presentation & Delivery', 20, 'Clarity, fluency, voice projection, engagement'),
  rebuttal('Rebuttal & Defence', 20, 'Effective refutation and defense of positions'),
  crossExam('Cross-Examination', 10, 'Quality of questions and responses during cross-examination');

  const ScoringCategory(this.displayName, this.maxPoints, this.description);
  final String displayName;
  final int maxPoints;
  final String description;

  static int get totalMaxPoints => values.fold(0, (sum, category) => sum + category.maxPoints);
}

enum PerformanceLevel {
  excellent('Excellent', 60, 70, 'Excellent performance'),
  good('Good', 50, 59, 'Good performance'),
  average('Average', 40, 49, 'Average performance'),
  belowAverage('Below Average', 30, 39, 'Below average performance'),
  poor('Poor', 0, 29, 'Poor performance');

  const PerformanceLevel(this.label, this.minScore, this.maxScore, this.description);
  final String label;
  final int minScore;
  final int maxScore;
  final String description;

  static PerformanceLevel getLevel(int score) {
    for (final level in values) {
      if (score >= level.minScore && score <= level.maxScore) {
        return level;
      }
    }
    return poor;
  }
}

enum TeamSide {
  affirmative('Affirmative'),
  negative('Negative');

  const TeamSide(this.displayName);
  final String displayName;

  static TeamSide fromString(String value) {
    return values.firstWhere(
      (side) => side.name.toLowerCase() == value.toLowerCase(),
      orElse: () => TeamSide.affirmative,
    );
  }
}

class SpeakerScore {
  final String speakerName;
  final TeamSide teamSide;
  final Map<ScoringCategory, int> categoryScores;
  final String comments;

  SpeakerScore({
    required this.speakerName,
    required this.teamSide,
    Map<ScoringCategory, int>? categoryScores,
    this.comments = '',
  }) : categoryScores = categoryScores ?? {
    for (final category in ScoringCategory.values) category: 0
  };

  factory SpeakerScore.fromMap(Map<String, dynamic> map) {
    final categoryScoresMap = <ScoringCategory, int>{};
    final scoresData = map['categoryScores'] as Map<String, dynamic>? ?? {};
    
    for (final category in ScoringCategory.values) {
      categoryScoresMap[category] = scoresData[category.name] ?? 0;
    }

    return SpeakerScore(
      speakerName: map['speakerName'] ?? '',
      teamSide: TeamSide.fromString(map['teamSide'] ?? 'affirmative'),
      categoryScores: categoryScoresMap,
      comments: map['comments'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    final categoryScoresMap = <String, int>{};
    for (final entry in categoryScores.entries) {
      categoryScoresMap[entry.key.name] = entry.value;
    }

    return {
      'speakerName': speakerName,
      'teamSide': teamSide.name,
      'categoryScores': categoryScoresMap,
      'comments': comments,
    };
  }

  int get totalScore => categoryScores.values.fold(0, (sum, score) => sum + score);
  
  PerformanceLevel get performanceLevel => PerformanceLevel.getLevel(totalScore);

  SpeakerScore copyWith({
    String? speakerName,
    TeamSide? teamSide,
    Map<ScoringCategory, int>? categoryScores,
    String? comments,
  }) {
    return SpeakerScore(
      speakerName: speakerName ?? this.speakerName,
      teamSide: teamSide ?? this.teamSide,
      categoryScores: categoryScores ?? Map.from(this.categoryScores),
      comments: comments ?? this.comments,
    );
  }
}

class JudgeScorecard {
  final String id;
  final String roomId;
  final String judgeId;
  final String judgeName;
  final String debateRound;
  final String debateTopic;
  final DateTime dateScored;
  final List<SpeakerScore> speakerScores;
  final TeamSide winningTeam;
  final String reasonForDecision;
  final bool isSubmitted;

  JudgeScorecard({
    required this.id,
    required this.roomId,
    required this.judgeId,
    required this.judgeName,
    this.debateRound = '',
    this.debateTopic = '',
    DateTime? dateScored,
    List<SpeakerScore>? speakerScores,
    this.winningTeam = TeamSide.affirmative,
    this.reasonForDecision = '',
    this.isSubmitted = false,
  }) : 
    dateScored = dateScored ?? DateTime.now(),
    speakerScores = speakerScores ?? [];

  factory JudgeScorecard.fromMap(Map<String, dynamic> map) {
    final speakerScoresList = (map['speakerScores'] as List<dynamic>?)
        ?.map((scoreMap) => SpeakerScore.fromMap(scoreMap))
        .toList() ?? [];

    return JudgeScorecard(
      id: map['id'] ?? '',
      roomId: map['roomId'] ?? '',
      judgeId: map['judgeId'] ?? '',
      judgeName: map['judgeName'] ?? '',
      debateRound: map['debateRound'] ?? '',
      debateTopic: map['debateTopic'] ?? '',
      dateScored: DateTime.parse(map['dateScored'] ?? DateTime.now().toIso8601String()),
      speakerScores: speakerScoresList,
      winningTeam: TeamSide.fromString(map['winningTeam'] ?? 'affirmative'),
      reasonForDecision: map['reasonForDecision'] ?? '',
      isSubmitted: map['isSubmitted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomId': roomId,
      'judgeId': judgeId,
      'judgeName': judgeName,
      'debateRound': debateRound,
      'debateTopic': debateTopic,
      'dateScored': dateScored.toIso8601String(),
      'speakerScores': speakerScores.map((score) => score.toMap()).toList(),
      'winningTeam': winningTeam.name,
      'reasonForDecision': reasonForDecision,
      'isSubmitted': isSubmitted,
    };
  }

  // Helper methods
  int getTotalScoreForTeam(TeamSide team) {
    return speakerScores
        .where((score) => score.teamSide == team)
        .fold(0, (sum, score) => sum + score.totalScore);
  }

  TeamSide get calculatedWinner {
    final affirmativeTotal = getTotalScoreForTeam(TeamSide.affirmative);
    final negativeTotal = getTotalScoreForTeam(TeamSide.negative);
    
    return affirmativeTotal > negativeTotal ? TeamSide.affirmative : TeamSide.negative;
  }

  bool get isWinnerConsistentWithScores {
    return winningTeam == calculatedWinner;
  }

  List<SpeakerScore> getSpeakersForTeam(TeamSide team) {
    return speakerScores.where((score) => score.teamSide == team).toList();
  }

  bool get isComplete {
    if (speakerScores.isEmpty) return false;
    
    // Check if all speakers have scores for all categories
    for (final speakerScore in speakerScores) {
      for (final category in ScoringCategory.values) {
        if (!speakerScore.categoryScores.containsKey(category) || 
            speakerScore.categoryScores[category]! == 0) {
          return false;
        }
      }
    }
    
    return reasonForDecision.isNotEmpty;
  }

  JudgeScorecard copyWith({
    String? id,
    String? roomId,
    String? judgeId,
    String? judgeName,
    String? debateRound,
    String? debateTopic,
    DateTime? dateScored,
    List<SpeakerScore>? speakerScores,
    TeamSide? winningTeam,
    String? reasonForDecision,
    bool? isSubmitted,
  }) {
    return JudgeScorecard(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      judgeId: judgeId ?? this.judgeId,
      judgeName: judgeName ?? this.judgeName,
      debateRound: debateRound ?? this.debateRound,
      debateTopic: debateTopic ?? this.debateTopic,
      dateScored: dateScored ?? this.dateScored,
      speakerScores: speakerScores ?? List.from(this.speakerScores),
      winningTeam: winningTeam ?? this.winningTeam,
      reasonForDecision: reasonForDecision ?? this.reasonForDecision,
      isSubmitted: isSubmitted ?? this.isSubmitted,
    );
  }
}