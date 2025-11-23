import 'package:flutter/material.dart';
import '../widgets/help_modal.dart';

/// Centralized help content for all screens
class HelpContent {
  /// Home Screen help items
  static List<HelpItem> homeScreen() {
    return [
      const HelpItem(
        icon: Icons.sports_martial_arts,
        title: 'The Arena',
        description: 'Challenge others to 1v1 debates! Judges score your arguments and determine the winner. Build your reputation and earn coins.',
      ),
      const HelpItem(
        icon: Icons.search,
        title: 'Find Users',
        description: 'Search for other debaters, view their profiles, and send them challenge invitations. Check out their stats and debate history.',
      ),
      const HelpItem(
        icon: Icons.groups,
        title: 'Debates & Discussions',
        description: 'Join live discussion rooms with speakers, moderators, and audience members. Raise your hand to speak and participate in engaging conversations.',
      ),
      const HelpItem(
        icon: Icons.forum,
        title: 'Open Discussions',
        description: 'Create or join open discussion rooms on any topic. Everyone can participate freely without moderation.',
      ),
      const HelpItem(
        icon: Icons.notifications,
        title: 'Challenge Bell',
        description: 'Get notified when someone challenges you to a debate or sends you invitations.',
      ),
      const HelpItem(
        icon: Icons.mail,
        title: 'Room Invitations',
        description: 'Receive invitations to join ongoing discussion rooms.',
      ),
    ];
  }

  /// In-Room controls help (for Debates & Discussions, Arena)
  static List<HelpItem> roomControls() {
    return [
      const HelpItem(
        icon: Icons.pan_tool,
        title: 'Raise Hand',
        description: 'Request permission to speak. The moderator will approve your request and move you to the speaker panel.',
      ),
      const HelpItem(
        icon: Icons.mic,
        title: 'Mute/Unmute',
        description: 'Control your microphone. Mute when not speaking to avoid background noise. Only speakers and moderators can use the mic.',
      ),
      const HelpItem(
        icon: Icons.settings,
        title: 'Moderator Tools',
        description: 'If you\'re a moderator, access controls to manage speakers, approve hand raises, mute participants, and end the room.',
      ),
      const HelpItem(
        icon: Icons.exit_to_app,
        title: 'Leave Room',
        description: 'Exit the room when you\'re done. Your spot will be freed up for others to join.',
      ),
      const HelpItem(
        icon: Icons.chat,
        title: 'Chat',
        description: 'Send text messages to all participants in the room. Great for sharing links or asking questions.',
      ),
      const HelpItem(
        icon: Icons.card_giftcard,
        title: 'Send Gifts',
        description: 'Show appreciation by sending virtual gifts to speakers. Gifts appear as animations on their avatar.',
      ),
      const HelpItem(
        icon: Icons.more_vert,
        title: 'More Options',
        description: 'Access additional features like sharing the room, viewing participants, or reporting issues.',
      ),
    ];
  }

  /// Arena-specific help
  static List<HelpItem> arenaControls() {
    return [
      const HelpItem(
        icon: Icons.mic,
        title: 'Microphone',
        description: 'Mute/unmute during your turn. Debaters take turns speaking based on the debate format.',
      ),
      const HelpItem(
        icon: Icons.gavel,
        title: 'Judging',
        description: 'Judges score arguments on clarity, logic, and impact. The highest score wins!',
      ),
      const HelpItem(
        icon: Icons.timer,
        title: 'Timer',
        description: 'Each speaker has limited time. Manage your time wisely to make strong arguments.',
      ),
      const HelpItem(
        icon: Icons.exit_to_app,
        title: 'Leave Arena',
        description: 'Exit the debate when finished. Warning: Leaving early may count as a forfeit.',
      ),
      const HelpItem(
        icon: Icons.chat,
        title: 'Chat',
        description: 'Communicate with judges and audience during breaks between rounds.',
      ),
      const HelpItem(
        icon: Icons.card_giftcard,
        title: 'Send Gifts',
        description: 'Show support by sending gifts to debaters. Popular in high-stakes matches!',
      ),
    ];
  }
}
