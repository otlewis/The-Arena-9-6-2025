import 'package:flutter/material.dart';
import '../features/arena/constants/arena_colors.dart';

/// Custom neon microphone icon with glow effects
/// Purple when unmuted, scarlet red when muted
class NeonMicIcon extends StatefulWidget {
  final bool isMuted;
  final double size;
  final bool isActive;
  final VoidCallback? onTap;
  final Duration animationDuration;

  const NeonMicIcon({
    super.key,
    required this.isMuted,
    this.size = 24.0,
    this.isActive = true,
    this.onTap,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<NeonMicIcon> createState() => _NeonMicIconState();
}

class _NeonMicIconState extends State<NeonMicIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    
    if (!widget.isMuted) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(NeonMicIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMuted != widget.isMuted) {
        if (widget.isMuted) {
        _animationController.reverse();
      } else {
        _animationController.forward();
      }
    }
  }


  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final color = widget.isMuted ? ArenaColors.scarletRed : ArenaColors.accentPurple;
          final glowIntensity = widget.isMuted ? 0.3 : _glowAnimation.value;
          
          return Container(
            width: widget.size + 16, // Extra space for glow
            height: widget.size + 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                // Subtle outer glow
                BoxShadow(
                  color: color.withValues(alpha: glowIntensity * 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
                // Minimal inner glow
                BoxShadow(
                  color: color.withValues(alpha: glowIntensity * 0.4),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Center(
              child: CustomPaint(
                size: Size(widget.size, widget.size),
                painter: NeonMicPainter(
                  color: color,
                  isMuted: widget.isMuted,
                  glowIntensity: glowIntensity,
                  isActive: widget.isActive,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter for the neon microphone icon
class NeonMicPainter extends CustomPainter {
  final Color color;
  final bool isMuted;
  final double glowIntensity;
  final bool isActive;

  NeonMicPainter({
    required this.color,
    required this.isMuted,
    required this.glowIntensity,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: glowIntensity * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    final center = Offset(size.width / 2, size.height / 2);
    final micWidth = size.width * 0.25;
    final micHeight = size.height * 0.4;

    // Draw glow layer first
    if (glowIntensity > 0.1) {
      _drawMicrophone(canvas, glowPaint, center, micWidth, micHeight);
    }

    // Draw main microphone
    _drawMicrophone(canvas, paint, center, micWidth, micHeight);

    // Draw mute slash if muted
    if (isMuted) {
      _drawMuteSlash(canvas, paint, center, size);
    }
  }

  void _drawMicrophone(Canvas canvas, Paint paint, Offset center, double micWidth, double micHeight) {
    // Microphone capsule (rounded rectangle)
    final micRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - micHeight * 0.3),
        width: micWidth,
        height: micHeight,
      ),
      Radius.circular(micWidth / 2),
    );
    canvas.drawRRect(micRect, paint);

    // Microphone stand - vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy + micHeight * 0.1),
      Offset(center.dx, center.dy + micHeight * 0.6),
      paint,
    );

    // Microphone base - horizontal line
    final baseWidth = micWidth * 1.5;
    canvas.drawLine(
      Offset(center.dx - baseWidth / 2, center.dy + micHeight * 0.6),
      Offset(center.dx + baseWidth / 2, center.dy + micHeight * 0.6),
      paint,
    );

    // Microphone arc (sound pickup area)
    final arcRect = Rect.fromCenter(
      center: Offset(center.dx + micWidth * 0.8, center.dy - micHeight * 0.3),
      width: micWidth * 0.6,
      height: micHeight * 0.8,
    );
    
    canvas.drawArc(
      arcRect,
      -1.5708, // -90 degrees in radians
      3.14159, // 180 degrees in radians
      false,
      paint,
    );
  }

  void _drawMuteSlash(Canvas canvas, Paint paint, Offset center, Size size) {
    final slashPaint = Paint()
      ..color = ArenaColors.scarletRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Draw diagonal slash line
    final slashLength = size.width * 0.7;
    final startX = center.dx - slashLength * 0.4;
    final startY = center.dy + slashLength * 0.4;
    final endX = center.dx + slashLength * 0.4;
    final endY = center.dy - slashLength * 0.4;

    canvas.drawLine(
      Offset(startX, startY),
      Offset(endX, endY),
      slashPaint,
    );
  }

  @override
  bool shouldRepaint(NeonMicPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isMuted != isMuted ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.isActive != isActive;
  }
}