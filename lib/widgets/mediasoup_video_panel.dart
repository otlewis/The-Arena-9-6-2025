import 'package:flutter/material.dart';
import '../services/simple_mediasoup_service.dart';
import 'individual_video_feed.dart';

class MediaSoupVideoPanel extends StatefulWidget {
  final SimpleWebRTCService webrtcService;
  final List<Map<String, dynamic>> participants; // {userId, name, role}
  final String? currentUserId;
  final bool isCurrentUserSpeaker;
  final Function(String userId)? onToggleUserVideo; // For individual control

  const MediaSoupVideoPanel({
    Key? key,
    required this.webrtcService,
    required this.participants,
    this.currentUserId,
    required this.isCurrentUserSpeaker,
    this.onToggleUserVideo,
  }) : super(key: key);

  @override
  State<MediaSoupVideoPanel> createState() => _MediaSoupVideoPanelState();
}

class _MediaSoupVideoPanelState extends State<MediaSoupVideoPanel> {
  @override
  void initState() {
    super.initState();
    // Listen to service changes for real-time updates
    widget.webrtcService.addListener(_onServiceStateChanged);
  }

  @override
  void dispose() {
    widget.webrtcService.removeListener(_onServiceStateChanged);
    super.dispose();
  }

  void _onServiceStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<Map<String, dynamic>> _getSpeakersWithVideo() {
    // Filter participants to only show speakers (moderator + speakers)
    return widget.participants
        .where((participant) => 
            participant['role'] == 'moderator' || 
            participant['role'] == 'speaker')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final speakersWithVideo = _getSpeakersWithVideo();
    
    if (speakersWithVideo.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 170,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          // Panel header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(
                  Icons.video_call,
                  color: Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Speakers Video (${speakersWithVideo.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (widget.isCurrentUserSpeaker)
                  GestureDetector(
                    onTap: () {
                      widget.webrtcService.toggleLocalVideo();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.webrtcService.isLocalVideoEnabled 
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.webrtcService.isLocalVideoEnabled 
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.webrtcService.isLocalVideoEnabled 
                                ? Icons.videocam 
                                : Icons.videocam_off,
                            color: widget.webrtcService.isLocalVideoEnabled 
                                ? Colors.green
                                : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.webrtcService.isLocalVideoEnabled 
                                ? 'Video On' 
                                : 'Video Off',
                            style: TextStyle(
                              color: widget.webrtcService.isLocalVideoEnabled 
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Video feeds scroll view
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              itemCount: speakersWithVideo.length,
              itemBuilder: (context, index) {
                final participant = speakersWithVideo[index];
                final userId = participant['userId'] as String;
                final userName = participant['name'] as String? ?? 'Unknown';
                final isLocalUser = userId == widget.currentUserId;
                
                // Get video state and renderer for this user
                final hasVideoEnabled = isLocalUser 
                    ? widget.webrtcService.isLocalVideoEnabled
                    : widget.webrtcService.hasVideoEnabled;
                
                final videoRenderer = widget.webrtcService.videoRenderers[userId];
                
                return IndividualVideoFeed(
                  userId: userId,
                  userName: userName,
                  hasVideo: hasVideoEnabled,
                  isLocalUser: isLocalUser,
                  isCurrentUserSpeaker: widget.isCurrentUserSpeaker,
                  videoRenderer: videoRenderer,
                  onToggleVideo: isLocalUser && widget.isCurrentUserSpeaker
                      ? () => widget.webrtcService.toggleLocalVideo()
                      : null,
                  showControls: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}