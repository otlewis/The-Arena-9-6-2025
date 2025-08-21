import '../models/timer_state.dart';

class TimerPresets {
  static const Map<RoomType, RoomTimerPreset> presets = {
    RoomType.openDiscussion: openDiscussionPreset,
    RoomType.debatesDiscussions: debatesDiscussionsPreset,
    RoomType.arena: arenaPreset,
  };

  // Open Discussion Room Presets - Flexible timing for casual conversations
  static const RoomTimerPreset openDiscussionPreset = RoomTimerPreset(
    roomType: RoomType.openDiscussion,
    name: 'Open Discussion',
    description: 'Flexible timers for open discussions and casual debates',
    maxConcurrentTimers: 1,
    moderatorOnly: true,
    timers: [
      TimerConfiguration(
        type: TimerType.general,
        label: 'General Timer',
        description: 'Flexible timer for discussion segments',
        defaultDurationSeconds: 180, // 3 minutes (updated from 5 minutes)
        minDurationSeconds: 60,     // 1 minute
        maxDurationSeconds: 600,    // 10 minutes
        presetDurations: [60, 120, 180, 300, 420, 600], // 1-10 minutes
        warningThresholdSeconds: 30,
        allowPause: true,
        allowAddTime: true,
        showProgress: true,
        primaryColor: '#4CAF50',
        warningColor: '#FF9800',
        expiredColor: '#F44336',
      ),
      TimerConfiguration(
        type: TimerType.speakerTurn,
        label: 'Speaker Turn',
        description: 'Individual speaking time limits',
        defaultDurationSeconds: 180, // 3 minutes (updated from 2 minutes)
        minDurationSeconds: 30,     // 30 seconds
        maxDurationSeconds: 300,    // 5 minutes
        presetDurations: [30, 60, 90, 120, 180, 300],
        warningThresholdSeconds: 15,
        allowPause: true,
        allowAddTime: true,
        showProgress: true,
        primaryColor: '#2196F3',
        warningColor: '#FF9800',
        expiredColor: '#F44336',
      ),
    ],
  );

  // Debates & Discussions Room Presets - Structured rounds
  static const RoomTimerPreset debatesDiscussionsPreset = RoomTimerPreset(
    roomType: RoomType.debatesDiscussions,
    name: 'Debates & Discussions',
    description: 'Structured timing for formal discussions with speaker panels',
    maxConcurrentTimers: 1,
    moderatorOnly: true,
    timers: [
      TimerConfiguration(
        type: TimerType.speakerTurn,
        label: 'Speaker Time',
        description: 'Time limit for each speaker in the panel',
        defaultDurationSeconds: 180, // 3 minutes
        minDurationSeconds: 120,    // 2 minutes
        maxDurationSeconds: 300,    // 5 minutes
        presetDurations: [120, 150, 180, 210, 240, 300],
        warningThresholdSeconds: 20,
        allowPause: true,
        allowAddTime: true,
        showProgress: true,
        primaryColor: '#9C27B0',
        warningColor: '#FF9800',
        expiredColor: '#F44336',
      ),
      TimerConfiguration(
        type: TimerType.questionRound,
        label: 'Q&A Round',
        description: 'Question and answer session timing',
        defaultDurationSeconds: 600, // 10 minutes
        minDurationSeconds: 300,    // 5 minutes
        maxDurationSeconds: 900,    // 15 minutes
        presetDurations: [300, 450, 600, 750, 900],
        warningThresholdSeconds: 60,
        allowPause: true,
        allowAddTime: true,
        showProgress: true,
        primaryColor: '#FF5722',
        warningColor: '#FF9800',
        expiredColor: '#F44336',
      ),
      TimerConfiguration(
        type: TimerType.general,
        label: 'Discussion Round',
        description: 'General discussion timing between structured segments',
        defaultDurationSeconds: 420, // 7 minutes
        minDurationSeconds: 180,    // 3 minutes
        maxDurationSeconds: 600,    // 10 minutes
        presetDurations: [180, 300, 420, 480, 600],
        warningThresholdSeconds: 30,
        allowPause: true,
        allowAddTime: true,
        showProgress: true,
        primaryColor: '#607D8B',
        warningColor: '#FF9800',
        expiredColor: '#F44336',
      ),
    ],
  );

  // Arena Room Presets - Formal debate structure
  static const RoomTimerPreset arenaPreset = RoomTimerPreset(
    roomType: RoomType.arena,
    name: 'The Arena',
    description: 'Formal debate timing with structured rounds and statements',
    maxConcurrentTimers: 1,
    moderatorOnly: true,
    timers: [
      TimerConfiguration(
        type: TimerType.openingStatement,
        label: 'Opening Statement',
        description: 'Initial argument presentation for each debater',
        defaultDurationSeconds: 240, // 4 minutes
        minDurationSeconds: 180,    // 3 minutes
        maxDurationSeconds: 360,    // 6 minutes
        presetDurations: [180, 210, 240, 300, 360],
        warningThresholdSeconds: 30,
        allowPause: false, // No pausing in formal debates
        allowAddTime: false, // Strict timing
        showProgress: true,
        primaryColor: '#1976D2',
        warningColor: '#FF9800',
        expiredColor: '#D32F2F',
      ),
      TimerConfiguration(
        type: TimerType.rebuttal,
        label: 'Rebuttal',
        description: 'Counter-argument and response time',
        defaultDurationSeconds: 180, // 3 minutes
        minDurationSeconds: 120,    // 2 minutes
        maxDurationSeconds: 240,    // 4 minutes
        presetDurations: [120, 150, 180, 210, 240],
        warningThresholdSeconds: 20,
        allowPause: false,
        allowAddTime: false,
        showProgress: true,
        primaryColor: '#388E3C',
        warningColor: '#FF9800',
        expiredColor: '#D32F2F',
      ),
      TimerConfiguration(
        type: TimerType.closingStatement,
        label: 'Closing Statement',
        description: 'Final argument and summary',
        defaultDurationSeconds: 150, // 2.5 minutes
        minDurationSeconds: 120,    // 2 minutes
        maxDurationSeconds: 180,    // 3 minutes
        presetDurations: [120, 135, 150, 165, 180],
        warningThresholdSeconds: 20,
        allowPause: false,
        allowAddTime: false,
        showProgress: true,
        primaryColor: '#7B1FA2',
        warningColor: '#FF9800',
        expiredColor: '#D32F2F',
      ),
      TimerConfiguration(
        type: TimerType.questionRound,
        label: 'Cross-Examination',
        description: 'Question and answer between debaters',
        defaultDurationSeconds: 120, // 2 minutes
        minDurationSeconds: 90,     // 1.5 minutes
        maxDurationSeconds: 180,    // 3 minutes
        presetDurations: [90, 105, 120, 150, 180],
        warningThresholdSeconds: 15,
        allowPause: false,
        allowAddTime: false,
        showProgress: true,
        primaryColor: '#F57C00',
        warningColor: '#FF9800',
        expiredColor: '#D32F2F',
      ),
      TimerConfiguration(
        type: TimerType.general,
        label: 'Preparation Time',
        description: 'Time for debaters to prepare between rounds',
        defaultDurationSeconds: 60,  // 1 minute
        minDurationSeconds: 30,     // 30 seconds
        maxDurationSeconds: 120,    // 2 minutes
        presetDurations: [30, 45, 60, 90, 120],
        warningThresholdSeconds: 10,
        allowPause: true,
        allowAddTime: true,
        showProgress: false, // Less formal timing
        primaryColor: '#795548',
        warningColor: '#FF9800',
        expiredColor: '#D32F2F',
      ),
    ],
  );

  // Helper methods to get specific configurations
  static RoomTimerPreset getPresetForRoom(RoomType roomType) {
    return presets[roomType] ?? openDiscussionPreset;
  }

  static List<TimerConfiguration> getTimersForRoom(RoomType roomType) {
    return getPresetForRoom(roomType).timers;
  }

  static TimerConfiguration? getTimerConfig(RoomType roomType, TimerType timerType) {
    final roomPreset = getPresetForRoom(roomType);
    try {
      return roomPreset.timers.firstWhere((timer) => timer.type == timerType);
    } catch (e) {
      return null;
    }
  }

  static List<int> getPresetDurations(RoomType roomType, TimerType timerType) {
    final config = getTimerConfig(roomType, timerType);
    return config?.presetDurations ?? [60, 120, 180, 300];
  }

  static bool canAddTime(RoomType roomType, TimerType timerType) {
    final config = getTimerConfig(roomType, timerType);
    return config?.allowAddTime ?? true;
  }

  static bool canPause(RoomType roomType, TimerType timerType) {
    final config = getTimerConfig(roomType, timerType);
    return config?.allowPause ?? true;
  }

  static int getMaxConcurrentTimers(RoomType roomType) {
    return getPresetForRoom(roomType).maxConcurrentTimers;
  }

  static bool isModeratorOnly(RoomType roomType) {
    return getPresetForRoom(roomType).moderatorOnly;
  }
}

// Extension to get display names for enums
extension RoomTypeExtension on RoomType {
  String get displayName {
    switch (this) {
      case RoomType.openDiscussion:
        return 'Open Discussion';
      case RoomType.debatesDiscussions:
        return 'Debates & Discussions';
      case RoomType.arena:
        return 'The Arena';
    }
  }

  String get description {
    switch (this) {
      case RoomType.openDiscussion:
        return 'Casual discussions with flexible timing';
      case RoomType.debatesDiscussions:
        return 'Structured discussions with speaker panels';
      case RoomType.arena:
        return 'Formal debates with strict timing rules';
    }
  }
}

extension TimerTypeExtension on TimerType {
  String get displayName {
    switch (this) {
      case TimerType.general:
        return 'General Timer';
      case TimerType.openingStatement:
        return 'Opening Statement';
      case TimerType.rebuttal:
        return 'Rebuttal';
      case TimerType.closingStatement:
        return 'Closing Statement';
      case TimerType.questionRound:
        return 'Q&A Round';
      case TimerType.speakerTurn:
        return 'Speaker Turn';
    }
  }

  String get shortName {
    switch (this) {
      case TimerType.general:
        return 'General';
      case TimerType.openingStatement:
        return 'Opening';
      case TimerType.rebuttal:
        return 'Rebuttal';
      case TimerType.closingStatement:
        return 'Closing';
      case TimerType.questionRound:
        return 'Q&A';
      case TimerType.speakerTurn:
        return 'Speaker';
    }
  }
}