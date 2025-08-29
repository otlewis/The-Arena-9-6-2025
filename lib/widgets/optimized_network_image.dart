import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;

/// Optimized network image widget with WebP support and progressive loading
class OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableWebP;
  final bool enableProgressiveLoading;
  final BorderRadius? borderRadius;

  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.enableWebP = true,
    this.enableProgressiveLoading = true,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Optimize image URL for WebP support
    final optimizedUrl = _getOptimizedImageUrl(imageUrl);
    
    Widget imageWidget = CachedNetworkImage(
      imageUrl: optimizedUrl,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      placeholder: (context, url) => placeholder ?? _buildProgressivePlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(context, url, error),
      progressIndicatorBuilder: enableProgressiveLoading 
          ? _buildProgressIndicator 
          : null,
      // Optimize memory usage
      memCacheWidth: width?.round(),
      memCacheHeight: height?.round(),
      // Enable fade-in animation
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
    );

    // Apply border radius if specified
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Generate optimized image URL with WebP support
  String _getOptimizedImageUrl(String originalUrl) {
    if (!enableWebP) return originalUrl;

    // For Appwrite storage URLs, add WebP conversion
    if (originalUrl.contains('appwrite')) {
      // Add WebP format parameter if not already present
      if (!originalUrl.contains('format=')) {
        final separator = originalUrl.contains('?') ? '&' : '?';
        return '$originalUrl${separator}format=webp&quality=85';
      }
    }

    // For other CDNs, add WebP support if possible
    if (originalUrl.contains('cloudinary.com')) {
      return originalUrl.replaceFirst('/upload/', '/upload/f_auto,q_auto/');
    }

    return originalUrl;
  }

  /// Build progressive placeholder with blur effect
  Widget _buildProgressivePlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: Stack(
        children: [
          // Shimmer effect
          _ShimmerEffect(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white,
            ),
          ),
          // Icon overlay
          const Center(
            child: Icon(
              Icons.image,
              color: Colors.grey,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  /// Build error widget
  Widget _buildErrorWidget(BuildContext context, String url, dynamic error) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }

  /// Build progressive loading indicator
  Widget _buildProgressIndicator(BuildContext context, String url, DownloadProgress progress) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: progress.progress,
              strokeWidth: 2,
              backgroundColor: Colors.grey[300],
            ),
            if (progress.progress != null) ...[
              const SizedBox(height: 8),
              Text(
                '${(progress.progress! * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmer effect widget for loading placeholders
class _ShimmerEffect extends StatefulWidget {
  final Widget child;

  const _ShimmerEffect({required this.child});

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat();
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
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.topRight,
              colors: const [
                Colors.transparent,
                Colors.white54,
                Colors.transparent,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ],
              transform: _SlideGradientTransform(_animation.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Custom gradient transform for shimmer effect
class _SlideGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlideGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {ui.TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Utility function to replace regular CachedNetworkImage usage
Widget buildOptimizedAvatar({
  required String? imageUrl,
  required String fallbackText,
  double radius = 25,
  Color? backgroundColor,
}) {
  if (imageUrl == null || imageUrl.isEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[300],
      child: Text(
        fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius * 0.6,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  return ClipOval(
    child: OptimizedNetworkImage(
      imageUrl: imageUrl,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      errorWidget: CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey[300],
        child: Text(
          fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: radius * 0.6,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}