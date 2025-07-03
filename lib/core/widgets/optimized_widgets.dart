import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Collection of performance-optimized widgets
class OptimizedWidgets {
  
  /// Optimized network image with proper caching and error handling
  static Widget networkImage({
    required String url,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    Widget imageWidget = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? 
        Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.image, color: Colors.grey),
        ),
      errorWidget: (context, url, error) => errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      maxWidthDiskCache: 1000,
      maxHeightDiskCache: 1000,
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Optimized user avatar with fallback
  static Widget userAvatar({
    required String? imageUrl,
    required String name,
    required double size,
    Color? backgroundColor,
    Color? textColor,
  }) {
    final radius = size / 2;
    
    if (imageUrl?.isNotEmpty == true) {
      return ClipOval(
        child: networkImage(
          url: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: _buildFallbackAvatar(name, radius, backgroundColor, textColor),
        ),
      );
    }
    
    return _buildFallbackAvatar(name, radius, backgroundColor, textColor);
  }

  static Widget _buildFallbackAvatar(
    String name, 
    double radius, 
    Color? backgroundColor, 
    Color? textColor,
  ) {
    final initials = _getInitials(name);
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? _generateAvatarColor(name),
      child: Text(
        initials,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: radius * 0.6,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static String _getInitials(String name) {
    if (name.isEmpty) return '?';
    
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    
    return name[0].toUpperCase();
  }

  static Color _generateAvatarColor(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    
    final hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }

  /// Optimized list tile with better performance
  static Widget listTile({
    Widget? leading,
    required Widget title,
    Widget? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    EdgeInsetsGeometry? contentPadding,
    bool dense = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: contentPadding ?? const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    title,
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      subtitle,
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 16),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Optimized card with better shadows and performance
  static Widget card({
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    Color? color,
    double? elevation,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
  }) {
    Widget cardContent = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        boxShadow: elevation != null ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: elevation * 2,
            offset: Offset(0, elevation),
          ),
        ] : null,
      ),
      child: child,
    );

    if (onTap != null) {
      cardContent = Material(
        color: Colors.transparent,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          child: cardContent,
        ),
      );
    }

    return Container(
      margin: margin ?? const EdgeInsets.all(8),
      child: cardContent,
    );
  }

  /// Optimized gradient container
  static Widget gradientContainer({
    required Widget child,
    required List<Color> colors,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    double? width,
    double? height,
  }) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: begin,
          end: end,
        ),
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }

  /// Animated counter widget
  static Widget animatedCounter({
    required int value,
    Duration duration = const Duration(milliseconds: 500),
    TextStyle? style,
    String prefix = '',
    String suffix = '',
  }) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      builder: (context, animatedValue, child) {
        return Text(
          '$prefix$animatedValue$suffix',
          style: style,
        );
      },
    );
  }

  /// Optimized separator for lists
  static Widget separator({
    double height = 1,
    Color? color,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      height: height,
      margin: margin,
      color: color ?? Colors.grey[300],
    );
  }

  /// Performance-optimized button
  static Widget button({
    required String text,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
    bool isLoading = false,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        padding: padding ?? const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
      child: isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(text),
            ],
          ),
    );
  }

  /// Optimized badge widget
  static Widget badge({
    required Widget child,
    required String text,
    Color? badgeColor,
    Color? textColor,
    double? size,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (text.isNotEmpty)
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor ?? Colors.red,
                borderRadius: BorderRadius.circular((size ?? 20) / 2),
              ),
              constraints: BoxConstraints(
                minWidth: size ?? 20,
                minHeight: size ?? 20,
              ),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor ?? Colors.white,
                    fontSize: (size ?? 20) * 0.6,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Extension for performance optimizations
extension PerformanceExtensions on Widget {
  /// Add RepaintBoundary for expensive widgets
  Widget withRepaintBoundary() {
    return RepaintBoundary(child: this);
  }

  /// Add AutomaticKeepAlive for list items
  Widget withKeepAlive() {
    return KeepAliveWrapper(child: this);
  }
}

/// Helper widget for keeping widgets alive in lists
class KeepAliveWrapper extends StatefulWidget {
  const KeepAliveWrapper({super.key, required this.child});
  
  final Widget child;

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}