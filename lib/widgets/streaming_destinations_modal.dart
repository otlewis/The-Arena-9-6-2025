import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/logging/app_logger.dart';

class StreamingDestinationsModal extends StatefulWidget {
  final String roomId;
  final String roomName;
  final bool isModerator;
  
  const StreamingDestinationsModal({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.isModerator,
  });

  @override
  State<StreamingDestinationsModal> createState() => _StreamingDestinationsModalState();
}

class _StreamingDestinationsModalState extends State<StreamingDestinationsModal> {
  // Selected platforms
  final Set<String> _selectedPlatforms = {};
  
  // Platform configurations
  final Map<String, Map<String, dynamic>> _platforms = {
    'facebook': {
      'name': 'Facebook Live',
      'icon': LucideIcons.facebook,
      'color': const Color(0xFF1877F2),
      'instructions': 'Go to Facebook → Create Post → Live Video → Copy your stream key',
      'streamUrl': 'rtmps://live-api-s.facebook.com:443/rtmp/',
    },
    'youtube': {
      'name': 'YouTube Live',
      'icon': LucideIcons.youtube,
      'color': const Color(0xFFFF0000),
      'instructions': 'Go to YouTube Studio → Go Live → Copy your stream key',
      'streamUrl': 'rtmp://a.rtmp.youtube.com/live2/',
    },
    'instagram': {
      'name': 'Instagram Live',
      'icon': LucideIcons.instagram,
      'color': const Color(0xFFE4405F),
      'instructions': 'Use streaming software with Instagram Live Producer',
      'streamUrl': 'rtmps://live-upload.instagram.com:443/rtmp/',
    },
    'x': {
      'name': 'X (Twitter) Live',
      'icon': LucideIcons.twitter,
      'color': const Color(0xFF000000),
      'instructions': 'Go to X → Media Studio → Producer → Copy your stream key',
      'streamUrl': 'rtmps://production.pscp.tv:443/x/',
    },
  };

  // Generate room stream link
  String get _roomStreamLink {
    // This would be your actual stream URL from LiveKit or your streaming service
    // For now, returning a placeholder that could be used with OBS/StreamYard
    return 'arena://stream/debates/${widget.roomId}';
  }

  void _togglePlatform(String platform) {
    setState(() {
      if (_selectedPlatforms.contains(platform)) {
        _selectedPlatforms.remove(platform);
      } else {
        _selectedPlatforms.add(platform);
      }
    });
  }

  void _copyStreamLink() {
    Clipboard.setData(ClipboardData(text: _roomStreamLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stream link copied to clipboard'),
        backgroundColor: Color(0xFF8B5CF6),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showPlatformInstructions(String platform) {
    final config = _platforms[platform]!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(config['icon'] as IconData, color: config['color'] as Color),
            const SizedBox(width: 8),
            Text(config['name'] as String),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Streaming Instructions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(config['instructions'] as String),
            const SizedBox(height: 16),
            const Text(
              'Stream Server:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      config['streamUrl'] as String,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: config['streamUrl'] as String));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Stream URL copied'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: You\'ll need your own stream key from this platform.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _startStreaming() {
    if (_selectedPlatforms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one streaming platform'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    AppLogger().info('Starting stream to platforms: ${_selectedPlatforms.join(', ')}');
    
    // TODO: Implement actual streaming logic here
    // This would integrate with LiveKit Egress API or your streaming service
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ready to stream to ${_selectedPlatforms.length} platform(s)'),
        backgroundColor: const Color(0xFF8B5CF6),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isModerator) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.shieldOff,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Moderator Only Feature',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Only the room moderator can manage live streaming',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                LucideIcons.radio,
                color: Color(0xFF8B5CF6),
              ),
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
                      'Stream your debate to multiple platforms',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.mic,
                  color: Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.roomName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Room ID: ${widget.roomId.substring(0, 8)}...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: _copyStreamLink,
                  tooltip: 'Copy stream link',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Platform Selection
          const Text(
            'Select Streaming Destinations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Platform Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
            ),
            itemCount: _platforms.length,
            itemBuilder: (context, index) {
              final platform = _platforms.keys.elementAt(index);
              final config = _platforms[platform]!;
              final isSelected = _selectedPlatforms.contains(platform);
              
              return InkWell(
                onTap: () => _togglePlatform(platform),
                onLongPress: () => _showPlatformInstructions(platform),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? (config['color'] as Color).withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    border: Border.all(
                      color: isSelected 
                          ? config['color'] as Color
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        config['icon'] as IconData,
                        color: isSelected 
                            ? config['color'] as Color
                            : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          config['name'] as String,
                          style: TextStyle(
                            color: isSelected 
                                ? config['color'] as Color
                                : Colors.grey,
                            fontWeight: isSelected 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: config['color'] as Color,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 12),
          
          // Info text
          const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Long press on a platform for setup instructions',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _selectedPlatforms.isNotEmpty ? _startStreaming : null,
                  icon: const Icon(LucideIcons.radio),
                  label: Text(
                    _selectedPlatforms.isEmpty 
                        ? 'Select Platform' 
                        : 'Go Live (${_selectedPlatforms.length})',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }
}