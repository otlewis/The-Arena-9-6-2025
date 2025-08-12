import 'package:flutter/material.dart';

class AnimatedGavelLogo extends StatefulWidget {
  final double size;
  final Color gavelColor;
  final Color soundBlockColor;
  
  const AnimatedGavelLogo({
    super.key,
    this.size = 120,
    this.gavelColor = const Color(0xFF8B5CF6),
    this.soundBlockColor = const Color(0xFF8B5CF6),
  });

  @override
  State<AnimatedGavelLogo> createState() => _AnimatedGavelLogoState();
}

class _AnimatedGavelLogoState extends State<AnimatedGavelLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _strikeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _strikeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    // Start the animation with a delay, then repeat
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _strikeAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: GavelStrikePainter(
              progress: _strikeAnimation.value,
              gavelColor: widget.gavelColor,
              soundBlockColor: widget.soundBlockColor,
            ),
          );
        },
      ),
    );
  }
}

class GavelStrikePainter extends CustomPainter {
  final double progress;
  final Color gavelColor;
  final Color soundBlockColor;

  GavelStrikePainter({
    required this.progress,
    required this.gavelColor,
    required this.soundBlockColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Calculate strike position (gavel moves down to hit the block)
    final strikeOffset = size.height * 0.15 * _getStrikeProgress();
    
    // Draw sound block (stationary at bottom)
    paint.color = soundBlockColor;
    
    // Main sound block base
    final soundBlockRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.85),
        width: size.width * 0.6,
        height: size.height * 0.12,
      ),
      Radius.circular(size.width * 0.03),
    );
    canvas.drawRRect(soundBlockRect, paint);
    
    // Sound block rings
    final middleRingRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.78),
        width: size.width * 0.5,
        height: size.height * 0.06,
      ),
      Radius.circular(size.width * 0.02),
    );
    canvas.drawRRect(middleRingRect, paint);
    
    final topRingRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.74),
        width: size.width * 0.4,
        height: size.height * 0.04,
      ),
      Radius.circular(size.width * 0.015),
    );
    canvas.drawRRect(topRingRect, paint);
    
    // Draw gavel (moves with strike animation)
    paint.color = gavelColor;
    
    // Gavel handle (angled)
    canvas.save();
    canvas.translate(size.width * 0.7, size.height * 0.3 + strikeOffset);
    canvas.rotate(-0.6); // -35 degrees
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * 0.35,
          height: size.height * 0.06,
        ),
        Radius.circular(size.width * 0.03),
      ),
      paint,
    );
    canvas.restore();
    
    // Gavel head (main striking part)
    final gavelHeadRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.35 + strikeOffset),
        width: size.width * 0.2,
        height: size.height * 0.12,
      ),
      Radius.circular(size.width * 0.015),
    );
    canvas.drawRRect(gavelHeadRect, paint);
    
    // Gavel top cap
    final topCapRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.22 + strikeOffset),
        width: size.width * 0.25,
        height: size.height * 0.06,
      ),
      Radius.circular(size.width * 0.03),
    );
    canvas.drawRRect(topCapRect, paint);
    
    // Gavel bottom cap
    final bottomCapRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.48 + strikeOffset),
        width: size.width * 0.25,
        height: size.height * 0.06,
      ),
      Radius.circular(size.width * 0.03),
    );
    canvas.drawRRect(bottomCapRect, paint);
    
    // Add impact effect when gavel hits the block
    if (_getStrikeProgress() > 0.8) {
      _drawImpactEffect(canvas, size);
    }
  }
  
  double _getStrikeProgress() {
    if (progress <= 0.6) {
      // Strike down phase (0.0 to 0.6)
      return progress / 0.6;
    } else {
      // Return up phase (0.6 to 1.0)
      return 1.0 - ((progress - 0.6) / 0.4);
    }
  }
  
  void _drawImpactEffect(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    
    // Small impact circles around the strike point
    for (int i = 0; i < 3; i++) {
      final radius = (i + 1) * 3.0;
      canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.65),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}