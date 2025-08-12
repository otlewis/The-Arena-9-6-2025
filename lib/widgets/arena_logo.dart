import 'package:flutter/material.dart';

class ArenaLogo extends StatelessWidget {
  final double size;
  final Color gavelColor;
  final Color soundBlockColor;

  const ArenaLogo({
    super.key,
    this.size = 120,
    this.gavelColor = const Color(0xFF8B5CF6), // Purple
    this.soundBlockColor = const Color(0xFFDC2626), // Scarlet
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ArenaLogoPainter(
          gavelColor: gavelColor,
          soundBlockColor: soundBlockColor,
        ),
      ),
    );
  }
}

class ArenaLogoPainter extends CustomPainter {
  final Color gavelColor;
  final Color soundBlockColor;

  ArenaLogoPainter({
    required this.gavelColor,
    required this.soundBlockColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Draw sound block (base) in scarlet
    paint.color = soundBlockColor;
    
    // Main sound block base
    final soundBlockRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.8),
        width: size.width * 0.7,
        height: size.height * 0.15,
      ),
      Radius.circular(size.width * 0.05),
    );
    canvas.drawRRect(soundBlockRect, paint);
    
    // Sound block middle ring
    final middleRingRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.72),
        width: size.width * 0.6,
        height: size.height * 0.08,
      ),
      Radius.circular(size.width * 0.03),
    );
    canvas.drawRRect(middleRingRect, paint);
    
    // Sound block top ring
    final topRingRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.66),
        width: size.width * 0.5,
        height: size.height * 0.06,
      ),
      Radius.circular(size.width * 0.02),
    );
    canvas.drawRRect(topRingRect, paint);
    
    // Draw gavel in purple
    paint.color = gavelColor;
    
    // Gavel handle
    
    // Rotate the handle
    canvas.save();
    canvas.translate(size.width * 0.65, size.height * 0.25);
    canvas.rotate(-0.5); // -30 degrees
    canvas.translate(-size.width * 0.2, -size.height * 0.04);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width * 0.4, size.height * 0.08),
        Radius.circular(size.width * 0.04),
      ),
      paint,
    );
    canvas.restore();
    
    // Gavel head (main block)
    final gavelHeadRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.45, size.height * 0.35),
        width: size.width * 0.25,
        height: size.height * 0.15,
      ),
      Radius.circular(size.width * 0.02),
    );
    canvas.drawRRect(gavelHeadRect, paint);
    
    // Gavel top cap
    final topCapRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.45, size.height * 0.2),
        width: size.width * 0.3,
        height: size.height * 0.08,
      ),
      Radius.circular(size.width * 0.04),
    );
    canvas.drawRRect(topCapRect, paint);
    
    // Gavel bottom cap
    final bottomCapRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.45, size.height * 0.5),
        width: size.width * 0.3,
        height: size.height * 0.08,
      ),
      Radius.circular(size.width * 0.04),
    );
    canvas.drawRRect(bottomCapRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}