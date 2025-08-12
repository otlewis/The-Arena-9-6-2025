import 'package:flutter/material.dart';
import '../models/room_participant.dart';

/// Microphone control button for debaters in Arena rooms
/// Shows mute/unmute functionality with visual feedback
class MicrophoneControlButton extends StatelessWidget {
  final bool isMuted;
  final bool isEnabled;
  final VoidCallback? onToggleMute;
  final double size;
  final Color? activeColor;
  final Color? mutedColor;
  
  const MicrophoneControlButton({
    super.key,
    required this.isMuted,
    this.isEnabled = true,
    this.onToggleMute,
    this.size = 48.0,
    this.activeColor,
    this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool canInteract = isEnabled && onToggleMute != null;
    
    // Color logic: Green when unmuted, Red when muted, Gray when disabled
    Color buttonColor;
    if (!canInteract) {
      buttonColor = Colors.grey[600]!;
    } else if (isMuted) {
      buttonColor = mutedColor ?? Colors.red;
    } else {
      buttonColor = activeColor ?? Colors.green;
    }
    
    return GestureDetector(
      onTap: canInteract ? onToggleMute : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: buttonColor,
          shape: BoxShape.circle,
          boxShadow: canInteract ? [
            BoxShadow(
              color: buttonColor.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ] : null,
        ),
        child: Icon(
          isMuted ? Icons.mic_off : Icons.mic,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }
}

/// Microphone control panel for debaters
/// Includes mute button with status indicator and speaking indicator
class MicrophoneControlPanel extends StatelessWidget {
  final ParticipantStatus currentStatus;
  final bool isCurrentUser;
  final VoidCallback? onToggleMute;
  final String userName;
  
  const MicrophoneControlPanel({
    super.key,
    required this.currentStatus,
    required this.isCurrentUser,
    this.onToggleMute,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMuted = currentStatus == ParticipantStatus.muted;
    final bool isSpeaking = currentStatus == ParticipantStatus.speaking;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSpeaking ? Colors.green : Colors.grey[700]!,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // User name
          Text(
            userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Speaking indicator
          if (isSpeaking)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SPEAKING',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          
          if (isSpeaking) const SizedBox(width: 12),
          
          // Microphone control (only for current user)
          if (isCurrentUser)
            MicrophoneControlButton(
              isMuted: isMuted,
              onToggleMute: onToggleMute,
              size: 40,
            ),
          
          // Status indicator for other users
          if (!isCurrentUser)
            Icon(
              isMuted ? Icons.mic_off : Icons.mic,
              color: isMuted ? Colors.red : Colors.green,
              size: 20,
            ),
        ],
      ),
    );
  }
}

/// Simple floating microphone button for debaters
/// Positioned as a floating action button style control
class FloatingMicrophoneButton extends StatefulWidget {
  final ParticipantStatus currentStatus;
  final VoidCallback? onToggleMute;
  final bool isVisible;
  
  const FloatingMicrophoneButton({
    super.key,
    required this.currentStatus,
    this.onToggleMute,
    this.isVisible = true,
  });

  @override
  State<FloatingMicrophoneButton> createState() => _FloatingMicrophoneButtonState();
}

class _FloatingMicrophoneButtonState extends State<FloatingMicrophoneButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    // Pulse animation when speaking
    if (widget.currentStatus == ParticipantStatus.speaking) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(FloatingMicrophoneButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update animation based on speaking status
    if (widget.currentStatus == ParticipantStatus.speaking) {
      if (!_animationController.isAnimating) {
        _animationController.repeat(reverse: true);
      }
    } else {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();
    
    final bool isMuted = widget.currentStatus == ParticipantStatus.muted;
    final bool isSpeaking = widget.currentStatus == ParticipantStatus.speaking;
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isSpeaking ? _pulseAnimation.value : 1.0,
          child: FloatingActionButton(
            onPressed: widget.onToggleMute,
            backgroundColor: isMuted ? Colors.red : Colors.green,
            foregroundColor: Colors.white,
            child: Icon(
              isMuted ? Icons.mic_off : Icons.mic,
              size: 28,
            ),
          ),
        );
      },
    );
  }
}