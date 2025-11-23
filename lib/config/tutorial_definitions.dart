import 'package:flutter/material.dart';
import '../screens/feature_highlights_screen.dart';

/// Centralized tutorial definitions for all screens
class TutorialDefinitions {
  /// Home Screen tutorials
  static List<FeatureHighlight> homeScreen({
    required GlobalKey arenaKey,
    required GlobalKey findUsersKey,
    required GlobalKey debateKey,
    required GlobalKey discussionKey,
  }) {
    return [
      FeatureHighlight(
        targetKey: arenaKey,
        title: 'The Arena',
        description: 'Challenge others to 1v1 debates! Judges will score your arguments and determine the winner. Build your reputation and earn coins.',
        icon: Icons.sports_martial_arts,
        accentColor: Colors.orange,
      ),
      FeatureHighlight(
        targetKey: findUsersKey,
        title: 'Find Users',
        description: 'Search for other debaters, view their profiles, and send them challenge invitations. Check out their stats and debate history.',
        icon: Icons.search,
        accentColor: Colors.blue,
      ),
      FeatureHighlight(
        targetKey: debateKey,
        title: 'Debates & Discussions',
        description: 'Join live discussion rooms with speakers, moderators, and audience. Raise your hand to speak and participate in engaging conversations.',
        icon: Icons.groups,
        accentColor: Colors.green,
      ),
      FeatureHighlight(
        targetKey: discussionKey,
        title: 'Open Discussions',
        description: 'Create or join open discussion rooms on any topic. Everyone can participate freely without moderation.',
        icon: Icons.forum,
        accentColor: Colors.purple,
      ),
    ];
  }

  /// Arena Screen tutorials
  static List<FeatureHighlight> arenaScreen({
    required GlobalKey createChallengeKey,
    required GlobalKey myChallengesKey,
    required GlobalKey? leaderboardKey,
  }) {
    final highlights = <FeatureHighlight>[
      FeatureHighlight(
        targetKey: createChallengeKey,
        title: 'Create Challenge',
        description: 'Start a new 1v1 debate! Choose your opponent, topic, and debate format. Invite judges to score the match.',
        icon: Icons.add_circle,
        accentColor: Colors.orange,
      ),
      FeatureHighlight(
        targetKey: myChallengesKey,
        title: 'My Challenges',
        description: 'View all your active and past challenges. Accept incoming challenges or check the status of ongoing debates.',
        icon: Icons.list,
        accentColor: Colors.blue,
      ),
    ];

    if (leaderboardKey != null) {
      highlights.add(
        FeatureHighlight(
          targetKey: leaderboardKey,
          title: 'Leaderboard',
          description: 'See how you rank against other debaters! Track wins, losses, and your overall rating.',
          icon: Icons.emoji_events,
          accentColor: Colors.amber,
        ),
      );
    }

    return highlights;
  }

  /// Create Room tutorials (for Debates & Discussions)
  static List<FeatureHighlight> createRoom({
    required GlobalKey roomTitleKey,
    required GlobalKey topicKey,
    required GlobalKey? privacyKey,
  }) {
    final highlights = <FeatureHighlight>[
      FeatureHighlight(
        targetKey: roomTitleKey,
        title: 'Room Title',
        description: 'Give your room a clear, descriptive title so others know what the discussion is about.',
        icon: Icons.title,
        accentColor: Colors.blue,
      ),
      FeatureHighlight(
        targetKey: topicKey,
        title: 'Topic/Description',
        description: 'Provide details about the discussion topic. This helps participants know what to expect.',
        icon: Icons.description,
        accentColor: Colors.green,
      ),
    ];

    if (privacyKey != null) {
      highlights.add(
        FeatureHighlight(
          targetKey: privacyKey,
          title: 'Privacy Settings',
          description: 'Choose between public (anyone can join) or private (invite-only) rooms.',
          icon: Icons.privacy_tip,
          accentColor: Colors.purple,
        ),
      );
    }

    return highlights;
  }

  /// In-Room tutorials (during active debate/discussion)
  static List<FeatureHighlight> inRoom({
    required GlobalKey? raiseHandKey,
    required GlobalKey? muteKey,
    required GlobalKey? leaveKey,
  }) {
    final highlights = <FeatureHighlight>[];

    if (raiseHandKey != null) {
      highlights.add(
        FeatureHighlight(
          targetKey: raiseHandKey,
          title: 'Raise Hand',
          description: 'Want to speak? Raise your hand and wait for the moderator to approve. You\'ll be moved to the speaker panel.',
          icon: Icons.pan_tool,
          accentColor: Colors.amber,
        ),
      );
    }

    if (muteKey != null) {
      highlights.add(
        FeatureHighlight(
          targetKey: muteKey,
          title: 'Mute/Unmute',
          description: 'Control your microphone. Mute when not speaking to avoid background noise.',
          icon: Icons.mic_off,
          accentColor: Colors.red,
        ),
      );
    }

    if (leaveKey != null) {
      highlights.add(
        FeatureHighlight(
          targetKey: leaveKey,
          title: 'Leave Room',
          description: 'Exit the room when you\'re done. Your spot will be freed up for others.',
          icon: Icons.exit_to_app,
          accentColor: Colors.grey,
        ),
      );
    }

    return highlights;
  }

  /// Find Users screen tutorials
  static List<FeatureHighlight> findUsers({
    required GlobalKey searchKey,
    required GlobalKey? filterKey,
  }) {
    final highlights = <FeatureHighlight>[
      FeatureHighlight(
        targetKey: searchKey,
        title: 'Search Users',
        description: 'Find debaters by username, view their profiles, debate history, and win/loss records.',
        icon: Icons.search,
        accentColor: Colors.blue,
      ),
    ];

    if (filterKey != null) {
      highlights.add(
        FeatureHighlight(
          targetKey: filterKey,
          title: 'Filters',
          description: 'Filter users by ranking, activity level, or debate specialty to find the perfect opponent.',
          icon: Icons.filter_list,
          accentColor: Colors.purple,
        ),
      );
    }

    return highlights;
  }
}
