import 'package:flutter/material.dart';
import 'package:animated_emoji/animated_emoji.dart';

/// Demo screen showing animated emojis using the animated_emoji package
///
/// These are real animated emojis from Google's Noto Emoji set!
class AnimatedEmojiDemoScreen extends StatelessWidget {
  const AnimatedEmojiDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text('Animated Emoji Demo'),
        backgroundColor: Colors.purple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Real Animated Emojis! ✨',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tap any emoji to see it animate!',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 30),

            // Grid of animated emojis
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              children: const [
                // Love/Heart ❤️
                _AnimatedEmojiCard(
                  emoji: AnimatedEmojis.redHeart,
                  label: '❤️ Love',
                  backgroundColor: Color(0xFF8B0000),
                ),

                // Thumbs Up 👍
                _AnimatedEmojiCard(
                  emoji: AnimatedEmojis.thumbsUp,
                  label: '👍 Like',
                  backgroundColor: Color(0xFF00008B),
                ),

                // Party Popper 🎉
                _AnimatedEmojiCard(
                  emoji: AnimatedEmojis.partyPopper,
                  label: '🎉 Party',
                  backgroundColor: Color(0xFFFFD700),
                ),

                // Fire 🔥
                _AnimatedEmojiCard(
                  emoji: AnimatedEmojis.fire,
                  label: '🔥 Fire',
                  backgroundColor: Color(0xFFFF4500),
                ),

                // Laughing 😂
                _AnimatedEmojiCard(
                  emoji: AnimatedEmojis.laughing,
                  label: '😂 Laughing',
                  backgroundColor: Color(0xFFFFD700),
                ),

                // Thinking Face 🤔
                _AnimatedEmojiCard(
                  emoji: AnimatedEmojis.thinkingFace,
                  label: '🤔 Thinking',
                  backgroundColor: Color(0xFF9370DB),
                ),

                // Angry Face 😡
                _AnimatedEmojiCard(
                  emoji: AnimatedEmojis.angry,
                  label: '😡 Angry',
                  backgroundColor: Color(0xFFDC143C),
                ),

                // Crying Face 😢
                _AnimatedEmojiCard(
                  emoji: AnimatedEmojis.cry,
                  label: '😢 Crying',
                  backgroundColor: Color(0xFF4169E1),
                ),

                // Loudly Crying 😭
                _AnimatedEmojiCard(
                  emoji: AnimatedEmojis.loudlyCrying,
                  label: '😭 Sobbing',
                  backgroundColor: Color(0xFF1E90FF),
                ),

                // Question Mark ❓
                _AnimatedEmojiCard(
                  emoji: AnimatedEmojis.question,
                  label: '❓ Question',
                  backgroundColor: Color(0xFFFF6347),
                ),

                // 100 Points 💯
                _AnimatedEmojiCard(
                  emoji: AnimatedEmojis.oneHundred,
                  label: '💯 100',
                  backgroundColor: Color(0xFF9370DB),
                ),

                // Sparkling Heart 💖
                _AnimatedEmojiCard(
                  emoji: AnimatedEmojis.sparklingHeart,
                  label: '💖 Heart',
                  backgroundColor: Color(0xFFFF69B4),
                ),

                // Waving Hand 👋
                _AnimatedEmojiCard(
                  emoji: AnimatedEmojis.wave,
                  label: '👋 Wave',
                  backgroundColor: Color(0xFF228B22),
                ),

                // Rage Face 😠
                _AnimatedEmojiCard(
                  emoji: AnimatedEmojis.rage,
                  label: '😠 Rage',
                  backgroundColor: Color(0xFF8B0000),
                ),

                // Eyes 👀
                _AnimatedEmojiCard(
                  emoji: AnimatedEmojis.eyes,
                  label: '👀 Eyes',
                  backgroundColor: Color(0xFF4B0082),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Info card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade900, Colors.blue.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.shade300, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AnimatedEmoji(
                        AnimatedEmojis.sparkles,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Animated Emoji Benefits',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoRow('✅ Built-in Google Noto Emoji'),
                  _InfoRow('✅ No network requests needed'),
                  _InfoRow('✅ Smooth 60fps animations'),
                  _InfoRow('✅ Works offline'),
                  _InfoRow('✅ Consistent across platforms'),
                  _InfoRow('✅ Easy to use'),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Floating example
            const Text(
              'Floating Animation Example:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade300),
              ),
              child: const Stack(
                children: [
                  Center(
                    child: Text(
                      'This is how reactions\nwould float from avatars',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                  _FloatingAnimatedEmoji(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String text;

  const _InfoRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}

class _AnimatedEmojiCard extends StatefulWidget {
  final AnimatedEmojiData emoji;
  final String label;
  final Color backgroundColor;

  const _AnimatedEmojiCard({
    required this.emoji,
    required this.label,
    required this.backgroundColor,
  });

  @override
  State<_AnimatedEmojiCard> createState() => _AnimatedEmojiCardState();
}

class _AnimatedEmojiCardState extends State<_AnimatedEmojiCard>
    with SingleTickerProviderStateMixin {
  bool _animate = false;

  void _triggerAnimation() {
    setState(() {
      _animate = true;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _animate = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _triggerAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: widget.backgroundColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.backgroundColor.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.backgroundColor.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedEmoji(
              widget.emoji,
              size: 64,
              repeat: _animate,
            ),
            const SizedBox(height: 12),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Continuously floating animated emoji
class _FloatingAnimatedEmoji extends StatefulWidget {
  const _FloatingAnimatedEmoji();

  @override
  State<_FloatingAnimatedEmoji> createState() => _FloatingAnimatedEmojiState();
}

class _FloatingAnimatedEmojiState extends State<_FloatingAnimatedEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 250, end: 30).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Positioned(
          left: 120,
          bottom: _animation.value,
          child: const AnimatedEmoji(
            AnimatedEmojis.redHeart,
            size: 48,
            repeat: true,
          ),
        );
      },
    );
  }
}
