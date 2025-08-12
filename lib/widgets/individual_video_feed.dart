import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class IndividualVideoFeed extends StatefulWidget {
  final String userId;
  final String userName;
  final bool hasVideo;
  final bool isLocalUser;
  final bool isCurrentUserSpeaker;
  final RTCVideoRenderer? videoRenderer;
  final VoidCallback? onToggleVideo; // Only for local user
  final bool showControls;

  const IndividualVideoFeed({
    Key? key,
    required this.userId,
    required this.userName,
    required this.hasVideo,
    required this.isLocalUser,
    required this.isCurrentUserSpeaker,
    this.videoRenderer,
    this.onToggleVideo,
    this.showControls = true,
  }) : super(key: key);

  @override
  State<IndividualVideoFeed> createState() => _IndividualVideoFeedState();
}

class _IndividualVideoFeedState extends State<IndividualVideoFeed> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isLocalUser 
              ? Colors.blue.withValues(alpha: 0.8)
              : Colors.grey.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Video feed or placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: widget.hasVideo && widget.videoRenderer != null
                ? RTCVideoView(
                    widget.videoRenderer!,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.grey[800],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.userName.length > 10 
                              ? '${widget.userName.substring(0, 10)}...'
                              : widget.userName,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
          
          // Username label at bottom
          Positioned(
            bottom: 4,
            left: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.userName.length > 12 
                    ? '${widget.userName.substring(0, 12)}...'
                    : widget.userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          
          // Video controls (only for local user and speakers)
          if (widget.showControls && 
              widget.isLocalUser && 
              widget.isCurrentUserSpeaker &&
              widget.onToggleVideo != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: widget.onToggleVideo,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.hasVideo 
                        ? Colors.green.withValues(alpha: 0.8)
                        : Colors.red.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.hasVideo ? Icons.videocam : Icons.videocam_off,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          
          // Local user indicator
          if (widget.isLocalUser)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'YOU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          
          // Video status indicator
          if (!widget.hasVideo)
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(
                Icons.videocam_off,
                color: Colors.red,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }
}