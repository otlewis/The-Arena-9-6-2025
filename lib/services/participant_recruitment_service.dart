import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Participant recruitment service for debate promotion
/// Focuses on getting people to JOIN debates, not just watch
class ParticipantRecruitmentService {
  static final ParticipantRecruitmentService _instance = ParticipantRecruitmentService._internal();
  factory ParticipantRecruitmentService() => _instance;
  ParticipantRecruitmentService._internal();


  /// Social platforms for recruiting debate participants
  static const Map<String, RecruitmentPlatform> platforms = {
    'facebook': RecruitmentPlatform(
      name: 'Facebook',
      instructions: '''
🗣️ RECRUIT PARTICIPANTS:
1. Open Facebook app or facebook.com
2. Create a new post
3. Write: "Join me in this live debate about [topic]!"
4. Copy and paste the room info below
5. Add hashtags: #debate #discussion #politics
6. Tag friends who love debates
7. Share in relevant groups/pages

💡 Tip: Ask a provocative question to spark interest!
      ''',
      color: Colors.blue,
      icon: Icons.facebook,
      shareTemplate: "🔥 Join me in this live debate!\n\n[TOPIC]\n\n[LINK]\n\n#debate #discussion #arena #beta",
    ),
    'twitter': RecruitmentPlatform(
      name: 'X (Twitter)',
      instructions: '''
🗣️ RECRUIT PARTICIPANTS:
1. Open X app or x.com
2. Create a new post
3. Write a provocative hook about your debate topic
4. Add the Arena room info
5. Use trending hashtags related to your topic
6. Tag influencers or experts in the field
7. Retweet with your followers

💡 Keep it under 280 characters!
      ''',
      color: Colors.black,
      icon: Icons.comment,
      shareTemplate: "🔥 Live debate happening now: [TOPIC]\n\n[LINK]\n\n#debate #politics #discussion #beta",
    ),
    'instagram': RecruitmentPlatform(
      name: 'Instagram Stories',
      instructions: '''
🗣️ RECRUIT PARTICIPANTS:
1. Open Instagram app
2. Go to your story
3. Take a screenshot of your Arena debate
4. Add text: "Join this live debate!"
5. Share the room info in your story
6. Use story stickers and polls
7. Tag relevant accounts

💡 Tell people Arena is in beta testing - share Room ID!
      ''',
      color: Colors.pink,
      icon: Icons.camera_alt,
      shareTemplate: "🔥 Live debate happening now!\n\n[TOPIC]\n\n[LINK]\n\n#debate #discussion #beta",
    ),
    'discord': RecruitmentPlatform(
      name: 'Discord',
      instructions: '''
🗣️ RECRUIT PARTICIPANTS:
1. Open relevant Discord servers
2. Find #general or debate channels
3. Post: "Live debate happening now!"
4. Share the Arena room info
5. @mention active members
6. Cross-post in multiple servers
7. Pin the message if you're a mod

💡 Share the Room ID so they can join via the Arena app!
      ''',
      color: Colors.deepPurple,
      icon: Icons.chat_bubble,
      shareTemplate: "🔥 @everyone Live debate starting!\n\nTopic: [TOPIC]\n\n[LINK]\n\nLet's debate! 🗣️ (Arena beta)",
    ),
    'reddit': RecruitmentPlatform(
      name: 'Reddit',
      instructions: '''
🗣️ RECRUIT PARTICIPANTS:
1. Find relevant subreddits for your topic
2. Create a post: "Live debate happening now"
3. Follow subreddit rules for app promotion
4. Engage with comments quickly
5. Cross-post to related subreddits
6. Join the debate yourself to keep it active

💡 Share the Room ID for people to join via Arena app!
      ''',
      color: Colors.orange,
      icon: Icons.reddit,
      shareTemplate: "🔥 Live debate: [TOPIC]\n\n[LINK]\n\nLet's hear all perspectives! (Arena beta)",
    ),
    'linkedin': RecruitmentPlatform(
      name: 'LinkedIn',
      instructions: '''
🗣️ RECRUIT PARTICIPANTS:
1. Open LinkedIn
2. Create a professional post
3. Frame as "thought leadership discussion"
4. Share the Arena room info
5. Tag industry professionals
6. Use relevant professional hashtags
7. Engage with comments professionally

💡 Perfect for professional debates - share the Room ID!
      ''',
      color: Colors.blue,
      icon: Icons.business,
      shareTemplate: "💼 Professional discussion: [TOPIC]\n\n[LINK]\n\n#leadership #business #discussion #beta",
    ),
  };

  /// Show participant recruitment options
  Future<void> showRecruitmentOptions(BuildContext context, String roomId, String roomName) async {
    final roomUrl = _generateRoomUrl(roomId);
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecruitmentModal(
        roomId: roomId,
        roomName: roomName,
        roomUrl: roomUrl,
      ),
    );
  }

  /// Generate the shareable room information
  String _generateRoomUrl(String roomId) {
    return 'Room ID: $roomId\n\nTo join this debate:\n1. Download Arena from TestFlight (iOS) or APK (Android)\n2. Open Arena app\n3. Use Room ID: $roomId to join';
  }
}

class _RecruitmentModal extends StatelessWidget {
  final String roomId;
  final String roomName;
  final String roomUrl;

  const _RecruitmentModal({
    required this.roomId,
    required this.roomName,
    required this.roomUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.people, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recruit Participants',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Get people to join your debate',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Room Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.room, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          roomName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.link, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          roomUrl,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () => _copyToClipboard(context, roomUrl),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Platform options
            const Text(
              'Share to Recruit Participants',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ...ParticipantRecruitmentService.platforms.entries.map((entry) {
              final platform = entry.value;
              return _buildPlatformOption(context, platform);
            }),
            
            const SizedBox(height: 20),
            
            // Info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Pro Tips',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Post in relevant groups/communities for your topic\n'
                    '• Tag friends and experts who love debates\n'
                    '• Use provocative questions to spark interest\n'
                    '• Join the debate yourself to keep it active\n'
                    '• Participants are 10x more valuable than viewers!',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformOption(BuildContext context, RecruitmentPlatform platform) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showPlatformInstructions(context, platform),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: platform.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  platform.icon,
                  color: platform.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      platform.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Tap for sharing instructions',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlatformInstructions(BuildContext context, RecruitmentPlatform platform) {
    final shareText = platform.shareTemplate
        .replaceAll('[TOPIC]', roomName)
        .replaceAll('[LINK]', roomUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(
          children: [
            Icon(platform.icon, color: platform.color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                platform.name,
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  platform.instructions,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sample Post:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    shareText,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copyToClipboard(context, shareText),
            child: const Text('Copy Text'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        backgroundColor: Color(0xFF8B5CF6),
      ),
    );
  }
}

class RecruitmentPlatform {
  final String name;
  final String instructions;
  final Color color;
  final IconData icon;
  final String shareTemplate;

  const RecruitmentPlatform({
    required this.name,
    required this.instructions,
    required this.color,
    required this.icon,
    required this.shareTemplate,
  });
}