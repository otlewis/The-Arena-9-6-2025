import 'package:flutter/material.dart';

/// Visual indicator that shows when a user is speaking
/// Features:
/// - Animated border when speaking
/// - Pulse animation for active speakers
/// - Different colors for different roles
/// - Smooth transitions
class SpeakingIndicator extends StatefulWidget {
  final Widget child;
  final bool isSpeaking;
  final bool isMuted;
  final String? userRole;
  final double size;
  final double borderWidth;
  final Duration animationDuration;
  
  const SpeakingIndicator({
    super.key,
    required this.child,
    required this.isSpeaking,
    this.isMuted = false,
    this.userRole,
    this.size = 60.0,
    this.borderWidth = 3.0,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<SpeakingIndicator> createState() => _SpeakingIndicatorState();
}

class _SpeakingIndicatorState extends State<SpeakingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _borderController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _borderAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for speaking indication
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Border animation for smooth transitions
    _borderController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _borderAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _borderController,
      curve: Curves.easeInOut,
    ));

    // Start animations based on initial state
    _updateAnimations();
  }

  @override
  void didUpdateWidget(SpeakingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSpeaking != widget.isSpeaking) {
      _updateAnimations();
    }
  }

  void _updateAnimations() {
    if (widget.isSpeaking && !widget.isMuted) {
      _borderController.forward();
      _pulseController.repeat(reverse: true);
    } else {
      _borderController.reverse();
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  Color _getBorderColor() {
    if (widget.isMuted) {
      return Colors.red.withValues(alpha: 0.7);
    }
    
    switch (widget.userRole?.toLowerCase()) {
      case 'moderator':
        return Colors.purple.withValues(alpha: 0.8);
      case 'judge':
      case 'judge1':
      case 'judge2':
      case 'judge3':
        return Colors.amber.withValues(alpha: 0.8);
      case 'debater1':
      case 'debater2':
      case 'speaker':
        return Colors.blue.withValues(alpha: 0.8);
      default:
        return Colors.green.withValues(alpha: 0.8);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _borderAnimation]),
      builder: (context, child) {
        final borderColor = _getBorderColor();
        final isAnimating = widget.isSpeaking && !widget.isMuted;
        
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor.withValues(alpha: borderColor.a * _borderAnimation.value),
              width: widget.borderWidth * _borderAnimation.value,
            ),
            boxShadow: isAnimating ? [
              BoxShadow(
                color: borderColor.withValues(alpha: 0.3 * _borderAnimation.value),
                blurRadius: 10.0 * _borderAnimation.value,
                spreadRadius: 2.0 * _borderAnimation.value,
              ),
            ] : null,
          ),
          child: Transform.scale(
            scale: isAnimating ? _pulseAnimation.value : 1.0,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Simplified speaking indicator for list items or small avatars
class SimpleSpeakingIndicator extends StatelessWidget {
  final bool isSpeaking;
  final bool isMuted;
  final String? userRole;
  final double size;
  
  const SimpleSpeakingIndicator({
    super.key,
    required this.isSpeaking,
    this.isMuted = false,
    this.userRole,
    this.size = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSpeaking && !isMuted) return const SizedBox.shrink();
    
    Color indicatorColor;
    IconData iconData;
    
    if (isMuted) {
      indicatorColor = Colors.red;
      iconData = Icons.mic_off;
    } else if (isSpeaking) {
      switch (userRole?.toLowerCase()) {
        case 'moderator':
          indicatorColor = Colors.purple;
          break;
        case 'judge':
        case 'judge1':
        case 'judge2':
        case 'judge3':
          indicatorColor = Colors.amber;
          break;
        case 'debater1':
        case 'debater2':
        case 'speaker':
          indicatorColor = Colors.blue;
          break;
        default:
          indicatorColor = Colors.green;
      }
      iconData = Icons.mic;
    } else {
      return const SizedBox.shrink();
    }
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: indicatorColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        size: size * 0.6,
        color: Colors.white,
      ),
    );
  }
}

/// Speaking indicator for floating microphone button
class MicrophoneSpeakingIndicator extends StatefulWidget {
  final bool isSpeaking;
  final bool isMuted;
  final VoidCallback? onTap;
  final double size;
  
  const MicrophoneSpeakingIndicator({
    super.key,
    required this.isSpeaking,
    required this.isMuted,
    this.onTap,
    this.size = 56.0,
  });

  @override
  State<MicrophoneSpeakingIndicator> createState() => _MicrophoneSpeakingIndicatorState();
}

class _MicrophoneSpeakingIndicatorState extends State<MicrophoneSpeakingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _updateAnimation();
  }

  @override
  void didUpdateWidget(MicrophoneSpeakingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSpeaking != widget.isSpeaking || oldWidget.isMuted != widget.isMuted) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.isSpeaking && !widget.isMuted) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isMuted ? Colors.red : Colors.green;
    final iconData = widget.isMuted ? Icons.mic_off : Icons.mic;
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isSpeaking && !widget.isMuted ? _pulseAnimation.value : 1.0,
          child: FloatingActionButton(
            onPressed: widget.onTap,
            backgroundColor: backgroundColor,
            child: Icon(
              iconData,
              color: Colors.white,
              size: widget.size * 0.4,
            ),
          ),
        );
      },
    );
  }
}