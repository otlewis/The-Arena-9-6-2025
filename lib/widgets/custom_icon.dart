import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomIcon extends StatelessWidget {
  final String? svgPath;
  final IconData? iconData;
  final double size;
  final Color color;

  const CustomIcon({
    super.key,
    this.svgPath,
    this.iconData,
    this.size = 24.0,
    required this.color,
  }) : assert(svgPath != null || iconData != null, 'Either svgPath or iconData must be provided');

  @override
  Widget build(BuildContext context) {
    if (svgPath != null) {
      return SvgPicture.asset(
        svgPath!,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(
      iconData,
      size: size,
      color: color,
    );
  }
} 