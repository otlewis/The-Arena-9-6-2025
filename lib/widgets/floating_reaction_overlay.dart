import 'package:flutter/material.dart';
import 'package:animated_emoji/animated_emoji.dart';
import 'dart:math' as math;

/// Floating reaction animation that rises from a user's avatar
///
/// Usage:
/// ```dart
/// FloatingReactionOverlay(
///   emoji: AnimatedEmojis.thumbsUp,
///   startPosition: Offset(100, 200), // Avatar position
/// )
/// ```
class FloatingReactionOverlay extends StatefulWidget {
  final AnimatedEmojiData emoji;
  final Offset startPosition;
  final Duration duration;
  final double maxHeight;

  const FloatingReactionOverlay({
    super.key,
    required this.emoji,
    required this.startPosition,
    this.duration = const Duration(milliseconds: 2000),
    this.maxHeight = 150,
  });

  @override
  State<FloatingReactionOverlay> createState() => _FloatingReactionOverlayState();
}

class _FloatingReactionOverlayState extends State<FloatingReactionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _sizeAnimation;
  late Animation<double> _wobbleAnimation;

  // Random horizontal drift
  final double _randomDrift = (math.Random().nextDouble() - 0.5) * 40;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Rise animation (0 -> maxHeight)
    _heightAnimation = Tween<double>(
      begin: 0,
      end: -widget.maxHeight,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Fade out near the end
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    ));

    // Emoji size: pop in effect then settle
    _sizeAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
    ));

    // Subtle wobble animation
    _wobbleAnimation = Tween<double>(
      begin: -0.1,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.startPosition.dx + _randomDrift * _controller.value,
          top: widget.startPosition.dy + _heightAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.rotate(
              angle: _wobbleAnimation.value,
              child: Transform.scale(
                scale: _sizeAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: AnimatedEmoji(
                    widget.emoji,
                    size: 32,
                    repeat: true,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Reaction button with ripple feedback when pressed
class ReactionButton extends StatefulWidget {
  final AnimatedEmojiData emoji;
  final VoidCallback onPressed;
  final bool isActive;

  const ReactionButton({
    super.key,
    required this.emoji,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;
  bool _showRipple = false;

  @override
  void initState() {
    super.initState();

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));

    _rippleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showRipple = false;
        });
        _rippleController.reset();
      }
    });
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  void _handlePress() {
    setState(() {
      _showRipple = true;
    });
    _rippleController.forward();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handlePress,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple effect
          if (_showRipple)
            AnimatedBuilder(
              animation: _rippleAnimation,
              builder: (context, child) {
                return Container(
                  width: 48 + (20 * _rippleAnimation.value),
                  height: 48 + (20 * _rippleAnimation.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purple.withOpacity(0.3 * (1 - _rippleAnimation.value)),
                  ),
                );
              },
            ),
          // Button itself
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: widget.isActive ? Colors.purple.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isActive ? Colors.purple : Colors.transparent,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: AnimatedEmoji(
              widget.emoji,
              size: 24,
              repeat: widget.isActive,
            ),
          ),
        ],
      ),
    );
  }
}
