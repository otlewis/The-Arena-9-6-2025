import 'package:flutter/material.dart';

class GavelLogo extends StatelessWidget {
  final Color color;
  final double size;
  const GavelLogo({super.key, this.color = const Color(0xFF8B5CF6), this.size = 64});

  @override
  Widget build(BuildContext context) {
    // These values are tuned to match the provided reference image
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Bottom horizontal bar
          Positioned(
            left: size * 0.18,
            bottom: size * 0.13,
            child: Container(
              width: size * 0.55,
              height: size * 0.10,
              color: color,
            ),
          ),
          // Main diagonal bar (longest)
          Positioned(
            left: size * 0.23,
            top: size * 0.38,
            child: Transform.rotate(
              angle: -0.785398, // -45 degrees in radians
              alignment: Alignment.centerLeft,
              child: Container(
                width: size * 0.68,
                height: size * 0.13,
                color: color,
              ),
            ),
          ),
          // Top diagonal bar (shorter)
          Positioned(
            left: size * 0.56,
            top: size * 0.13,
            child: Transform.rotate(
              angle: -0.785398, // -45 degrees in radians
              alignment: Alignment.centerLeft,
              child: Container(
                width: size * 0.28,
                height: size * 0.13,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 