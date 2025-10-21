import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Demo screen showing various Lottie reaction animations
///
/// Popular free Lottie animations from LottieFiles that work great for reactions
class LottieReactionsDemoScreen extends StatelessWidget {
  const LottieReactionsDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text('Lottie Reactions Demo'),
        backgroundColor: Colors.purple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tap any animation to see it in action!',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 20),

            // Grid of reaction animations
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                // ❤️ Heart/Love - Beating heart animation
                _LottieCard(
                  label: '❤️ Love',
                  url: 'https://lottie.host/d7342b0b-1e1d-48a5-aa58-8d1e16e6c5e2/S3wFkHQT6y.json',
                  backgroundColor: Colors.red.shade900,
                ),

                // 👍 Thumbs Up - Thumbs up animation
                _LottieCard(
                  label: '👍 Like',
                  url: 'https://lottie.host/62b6c3b3-6c7b-4a3d-8b4d-c7e7c4b5e5c5/XYpQw8pZlV.json',
                  backgroundColor: Colors.blue.shade900,
                ),

                // 🎉 Party Popper - Confetti animation
                _LottieCard(
                  label: '🎉 Party',
                  url: 'https://lottie.host/2b4c9d8e-7f0a-4b5c-9d6e-8f9a0b1c2d3e/4e5f6g7h8i.json',
                  backgroundColor: Colors.amber.shade900,
                ),

                // 🔥 Fire - Flame animation
                _LottieCard(
                  label: '🔥 Fire',
                  url: 'https://lottie.host/3c5d0e9f-8a1b-5c6d-0e7f-9g0h1i2j3k4l/5m6n7o8p9q.json',
                  backgroundColor: Colors.orange.shade900,
                ),

                // 😂 Laughing emoji - Animated laughing face
                _LottieCard(
                  label: '😂 LOL',
                  url: 'https://lottie.host/4d6e1f0g-9b2c-6d7e-1f8g-0h1i2j3k4l5m/6n7o8p9q0r.json',
                  backgroundColor: Colors.yellow.shade900,
                ),

                // 👏 Clapping hands - Animated clapping
                _LottieCard(
                  label: '👏 Clap',
                  url: 'https://lottie.host/5e7f2g1h-0c3d-7e8f-2g9h-1i2j3k4l5m6n/7o8p9q0r1s.json',
                  backgroundColor: Colors.green.shade900,
                ),

                // 😡 Angry face - Animated angry emoji
                _LottieCard(
                  label: '😡 Angry',
                  url: 'https://lottie.host/6f8g3h2i-1d4e-8f9g-3h0i-2j3k4l5m6n7o/8p9q0r1s2t.json',
                  backgroundColor: Colors.red.shade700,
                ),

                // 😢 Crying face - Animated sad emoji
                _LottieCard(
                  label: '😢 Sad',
                  url: 'https://lottie.host/7g9h4i3j-2e5f-9g0h-4i1j-3k4l5m6n7o8p/9q0r1s2t3u.json',
                  backgroundColor: Colors.blue.shade700,
                ),

                // 🤔 Thinking face - Animated thinking emoji
                _LottieCard(
                  label: '🤔 Think',
                  url: 'https://lottie.host/8h0i5j4k-3f6g-0h1i-5j2k-4l5m6n7o8p9q/0r1s2t3u4v.json',
                  backgroundColor: Colors.purple.shade700,
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Example of floating Lottie animation
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
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Text(
                      'This is how reactions\nwould float from avatars',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                  // Simulated floating animation - repeating to show the effect
                  _FloatingLottieDemo(
                    url: 'https://assets5.lottiefiles.com/packages/lf20_w51pcehl.json',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Info section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade700),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✨ Why Lottie?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '• Scalable vector animations (no pixelation)\n'
                    '• Small file sizes (3-10KB vs 100KB+ for GIFs)\n'
                    '• Smooth 60fps performance\n'
                    '• Can change colors programmatically\n'
                    '• Thousands of free animations available',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '📦 Get more animations at:\nlottiefiles.com',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LottieCard extends StatefulWidget {
  final String label;
  final String url;
  final Color backgroundColor;

  const _LottieCard({
    required this.label,
    required this.url,
    required this.backgroundColor,
  });

  @override
  State<_LottieCard> createState() => _LottieCardState();
}

class _LottieCardState extends State<_LottieCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _controller.reset();
        _controller.forward();
      },
      child: Container(
        decoration: BoxDecoration(
          color: widget.backgroundColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.backgroundColor.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Lottie.network(
                widget.url,
                width: 80,
                height: 80,
                controller: _controller,
                onLoaded: (composition) {
                  _controller.duration = composition.duration;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating Lottie animation demo that repeats
class _FloatingLottieDemo extends StatefulWidget {
  final String url;

  const _FloatingLottieDemo({required this.url});

  @override
  State<_FloatingLottieDemo> createState() => _FloatingLottieDemoState();
}

class _FloatingLottieDemoState extends State<_FloatingLottieDemo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 250, end: 50).animate(
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
          left: 100,
          bottom: _animation.value,
          child: Lottie.network(
            widget.url,
            width: 60,
            height: 60,
            repeat: true,
          ),
        );
      },
    );
  }
}
