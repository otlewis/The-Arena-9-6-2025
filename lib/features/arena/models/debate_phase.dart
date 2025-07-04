/// Legacy Debate Phase Enum - kept for backwards compatibility
/// DO NOT MODIFY - Critical to arena functionality
enum DebatePhase {
  preDebate('Pre-Debate', 'Preparation and setup time', 300),
  openingAffirmative('Opening - Affirmative', 'Affirmative opening statement', 300),
  openingNegative('Opening - Negative', 'Negative opening statement', 300),
  rebuttalAffirmative('Rebuttal - Affirmative', 'Affirmative rebuttal', 180),
  rebuttalNegative('Rebuttal - Negative', 'Negative rebuttal', 180),
  crossExamAffirmative('Cross-Exam - Affirmative', 'Affirmative cross-examination', 120),
  crossExamNegative('Cross-Exam - Negative', 'Negative cross-examination', 120),
  finalRebuttalAffirmative('Final Rebuttal - Affirmative', 'Affirmative final rebuttal', 180),
  finalRebuttalNegative('Final Rebuttal - Negative', 'Negative final rebuttal', 180),
  closingAffirmative('Closing - Affirmative', 'Affirmative closing statement', 240),
  closingNegative('Closing - Negative', 'Negative closing statement', 240),
  judging('Judging Phase', 'Judges deliberate and score', null);

  const DebatePhase(this.displayName, this.description, this.defaultDurationSeconds);
  
  final String displayName;
  final String description;
  final int? defaultDurationSeconds;
  
  /// Returns the speaker role for this phase
  String get speakerRole {
    switch (this) {
      case DebatePhase.openingAffirmative:
      case DebatePhase.rebuttalAffirmative:
      case DebatePhase.crossExamAffirmative:
      case DebatePhase.finalRebuttalAffirmative:
      case DebatePhase.closingAffirmative:
        return 'affirmative';
      case DebatePhase.openingNegative:
      case DebatePhase.rebuttalNegative:
      case DebatePhase.crossExamNegative:
      case DebatePhase.finalRebuttalNegative:
      case DebatePhase.closingNegative:
        return 'negative';
      default:
        return '';
    }
  }
  
  /// Returns the next phase in the debate sequence
  DebatePhase? get nextPhase {
    final phases = DebatePhase.values;
    final currentIndex = phases.indexOf(this);
    if (currentIndex < phases.length - 1) {
      return phases[currentIndex + 1];
    }
    return null;
  }
  
  /// Returns true if this phase has a speaker
  bool get hasSpeaker => speakerRole.isNotEmpty;
  
  /// Returns true if this is an affirmative phase
  bool get isAffirmativePhase => speakerRole == 'affirmative';
  
  /// Returns true if this is a negative phase
  bool get isNegativePhase => speakerRole == 'negative';
}