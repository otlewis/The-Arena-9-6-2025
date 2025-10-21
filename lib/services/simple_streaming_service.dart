import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Social sharing service for debate promotion and participant recruitment
/// Focuses on getting people to JOIN debates, not just watch
class SimpleStreamingService {
  static final SimpleStreamingService _instance = SimpleStreamingService._internal();
  factory SimpleStreamingService() => _instance;
  SimpleStreamingService._internal();


  /// Social promotion platforms for recruiting debate participants
  static const Map<String, StreamingPlatform> platforms = {
    'facebook_share': StreamingPlatform(
      name: 'Facebook Post',
      instructions: '''
🗣️ RECRUIT PARTICIPANTS:
1. Open Facebook app or website
2. Create a new post
3. Copy and paste the Arena debate link
4. Write: "Join me in this live debate about [topic]!"
5. Add hashtags: #debate #discussion #arena
6. Tag friends who might be interested
7. Post to relevant groups/pages

People can join the debate directly - much better than watching!
      ''',
      color: Colors.blue,
      icon: Icons.facebook,
      downloadUrl: null,
    ),
    'streamlabs': StreamingPlatform(
      name: 'Streamlabs',
      instructions: '''
1. Download Streamlabs OBS: https://streamlabs.com/
2. Add "Browser Source"
3. Set URL to: https://arena.app/stream/ROOM_ID
4. Configure your streaming platform
5. Enter your stream key
6. Start streaming
      ''',
      color: Colors.blue,
      icon: Icons.stream,
      downloadUrl: 'https://streamlabs.com/',
    ),
    'restream': StreamingPlatform(
      name: 'Restream.io',
      instructions: '''
1. Sign up at: https://restream.io/
2. Connect your social media accounts
3. Use their browser streaming tool
4. Add Arena room as browser source
5. Stream to multiple platforms simultaneously
      ''',
      color: Colors.orange,
      icon: Icons.broadcast_on_personal,
      downloadUrl: 'https://restream.io/',
    ),
    'streamyard': StreamingPlatform(
      name: 'StreamYard',
      instructions: '''
1. Sign up at: https://streamyard.com/
2. Create a new broadcast
3. Click "Add guests" → "Share your screen"
4. Share your browser tab with Arena room
5. Connect to Facebook, YouTube, LinkedIn Live
6. Professional overlays and branding included
      ''',
      color: Colors.green,
      icon: Icons.videocam,
      downloadUrl: 'https://streamyard.com/',
    ),
    'streamyard_mobile': StreamingPlatform(
      name: 'StreamYard (Mobile Browser)',
      instructions: '''
📱 BEST MOBILE OPTION:
1. Open Chrome/Safari on your phone
2. Go to streamyard.com (works in browser!)
3. Create a broadcast
4. Open Arena in another tab
5. Share your screen/tab to StreamYard
6. Connect Facebook, YouTube, etc.
7. Go Live with your debate!

This works on ONE phone - no second device needed!
      ''',
      color: Colors.green,
      icon: Icons.phone_android,
      downloadUrl: 'https://streamyard.com',
    ),
    'prism_live': StreamingPlatform(
      name: 'Prism Live Studio (Mobile App)',
      instructions: '''
📱 MOBILE SCREEN STREAMING:
1. Download Prism Live Studio app (free)
2. Open Arena debate in your browser
3. In Prism: Add source → Screen Recording
4. Connect your social media accounts
5. Start streaming your screen to Facebook/YouTube
6. Your Arena debate streams live!
      ''',
      color: Colors.purple,
      icon: Icons.phone_android,
      downloadUrl: 'https://prismlive.com/en_us/mapp/',
    ),
    'omlet_arcade': StreamingPlatform(
      name: 'Omlet Arcade (Mobile Gaming)',
      instructions: '''
📱 ANDROID SCREEN STREAMING:
1. Download Omlet Arcade app (free)
2. Open Arena debate in browser
3. Start Omlet Arcade screen recorder
4. Choose "Stream" mode
5. Connect to Facebook/YouTube/Twitch
6. Stream your Arena debate live!
      ''',
      color: Colors.orange,
      icon: Icons.phone_android,
      downloadUrl: 'https://omlet.gg/',
    ),
  };

  /// Generate streaming URL for the room
  String generateStreamingUrl(String roomId, String roomName) {
    // This would be your actual Arena streaming URL
    // For now, return a placeholder that could be implemented
    return 'https://arena.app/embed/debates/$roomId';
  }

  /// Show streaming options modal
  Future<void> showStreamingOptions(BuildContext context, String roomId, String roomName) async {
    final streamUrl = generateStreamingUrl(roomId, roomName);
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StreamingOptionsModal(
        roomId: roomId,
        roomName: roomName,
        streamUrl: streamUrl,
      ),
    );
  }
}

class _StreamingOptionsModal extends StatelessWidget {
  final String roomId;
  final String roomName;
  final String streamUrl;

  const _StreamingOptionsModal({
    required this.roomId,
    required this.roomName,
    required this.streamUrl,
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
                const Icon(Icons.live_tv, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Go Live',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Stream your debate to social media',
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
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
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
                          streamUrl,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () => _copyToClipboard(context, streamUrl),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Streaming Options
            const Text(
              'Choose Your Streaming Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Platform options
            ...SimpleStreamingService.platforms.entries.map((entry) {
              final platform = entry.value;
              return _buildPlatformOption(context, platform);
            }),
            
            const SizedBox(height: 20),
            
            // Info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'How it works',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Choose a streaming software (OBS is free and popular)\n'
                    '2. Add the Arena room URL as a browser source\n'
                    '3. Connect to your social media platform\n'
                    '4. Start streaming to reach your audience!',
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

  Widget _buildPlatformOption(BuildContext context, StreamingPlatform platform) {
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
                  color: platform.color.withOpacity(0.1),
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
                      'Tap for setup instructions',
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

  void _showPlatformInstructions(BuildContext context, StreamingPlatform platform) {
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
                  'Arena Room URL:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    streamUrl,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (platform.downloadUrl != null)
            TextButton.icon(
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download'),
              onPressed: () => _launchUrl(platform.downloadUrl!),
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
    // Implement clipboard copy
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stream URL copied to clipboard'),
        backgroundColor: Color(0xFF8B5CF6),
      ),
    );
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class StreamingPlatform {
  final String name;
  final String instructions;
  final Color color;
  final IconData icon;
  final String? downloadUrl;

  const StreamingPlatform({
    required this.name,
    required this.instructions,
    required this.color,
    required this.icon,
    this.downloadUrl,
  });
}