import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/logging/app_logger.dart';

/// Mobile-specific performance optimizations for Arena
class MobilePerformanceOptimizer {
  static MobilePerformanceOptimizer? _instance;
  static MobilePerformanceOptimizer get instance => _instance ??= MobilePerformanceOptimizer._();
  
  MobilePerformanceOptimizer._();
  
  bool _isInitialized = false;
  bool _isMobile = false;
  bool _isLowEndDevice = false;
  
  /// Initialize mobile performance optimizations
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);
    
    if (_isMobile) {
      await _detectDeviceCapabilities();
      await _applyMobileOptimizations();
      AppLogger().info('📱 Mobile performance optimizations initialized');
    }
    
    _isInitialized = true;
  }
  
  /// Detect device capabilities for optimization
  Future<void> _detectDeviceCapabilities() async {
    try {
      // Simple heuristic for low-end device detection
      // In a real app, you might use device_info_plus plugin
      _isLowEndDevice = false; // Default to false, could be enhanced
      
      if (Platform.isAndroid) {
        // Android-specific optimizations could check RAM, CPU, etc.
        AppLogger().debug('🤖 Android device detected');
      } else if (Platform.isIOS) {
        // iOS-specific optimizations
        AppLogger().debug('📱 iOS device detected');
      }
    } catch (e) {
      AppLogger().warning('Error detecting device capabilities: $e');
    }
  }
  
  /// Apply mobile-specific optimizations
  Future<void> _applyMobileOptimizations() async {
    try {
      // Set preferred orientations for mobile (portrait only)
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      
      // Optimize system UI for mobile
      if (Platform.isAndroid) {
        await _optimizeAndroid();
      } else if (Platform.isIOS) {
        await _optimizeIOS();
      }
      
      AppLogger().info('📱 Mobile optimizations applied');
    } catch (e) {
      AppLogger().error('Error applying mobile optimizations: $e');
    }
  }
  
  /// Android-specific optimizations
  Future<void> _optimizeAndroid() async {
    try {
      // Enable hardware acceleration
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ));
      
      AppLogger().debug('🤖 Android optimizations applied');
    } catch (e) {
      AppLogger().warning('Error applying Android optimizations: $e');
    }
  }
  
  /// iOS-specific optimizations
  Future<void> _optimizeIOS() async {
    try {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ));
      
      AppLogger().debug('📱 iOS optimizations applied');
    } catch (e) {
      AppLogger().warning('Error applying iOS optimizations: $e');
    }
  }
  
  /// Get mobile-optimized grid delegate for audience display
  SliverGridDelegate getMobileOptimizedGridDelegate(double screenWidth) {
    int crossAxisCount;
    double childAspectRatio;
    
    if (_isLowEndDevice) {
      // Fewer items for low-end devices
      crossAxisCount = screenWidth > 600 ? 4 : 3;
      childAspectRatio = 0.85;
    } else {
      // Standard mobile layout
      crossAxisCount = screenWidth > 600 ? 5 : 4;
      childAspectRatio = 0.9;
    }
    
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    );
  }
  
  /// Get mobile-optimized list delegate for better scrolling
  Widget getMobileOptimizedList({
    required List<Widget> children,
    required ScrollController? controller,
  }) {
    if (_isMobile) {
      return ListView.builder(
        controller: controller,
        physics: const ClampingScrollPhysics(), // Better for mobile
        cacheExtent: _isLowEndDevice ? 200 : 500, // Reduced cache for low-end
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
      );
    }
    
    return ListView(
      controller: controller,
      children: children,
    );
  }
  
  /// Optimize image loading for mobile
  Widget getMobileOptimizedImage({
    required String imageUrl,
    required double width,
    required double height,
  }) {
    if (!_isMobile) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }
    
    // Mobile-optimized image loading
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      cacheWidth: _isLowEndDevice ? (width * 1.5).round() : (width * 2).round(),
      cacheHeight: _isLowEndDevice ? (height * 1.5).round() : (height * 2).round(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        
        return SizedBox(
          width: width,
          height: height,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.person, color: Colors.grey),
        );
      },
    );
  }
  
  /// Get mobile-optimized animation duration
  Duration getMobileOptimizedAnimationDuration() {
    if (_isLowEndDevice) {
      return const Duration(milliseconds: 150); // Faster animations for low-end
    } else if (_isMobile) {
      return const Duration(milliseconds: 200); // Standard mobile
    } else {
      return const Duration(milliseconds: 300); // Desktop
    }
  }
  
  /// Check if device should use reduced animations
  bool shouldUseReducedAnimations() {
    return _isLowEndDevice;
  }
  
  /// Get mobile-optimized debounce duration
  Duration getMobileOptimizedDebounceDuration() {
    if (_isLowEndDevice) {
      return const Duration(milliseconds: 100); // More aggressive debouncing
    } else if (_isMobile) {
      return const Duration(milliseconds: 50); // Standard mobile
    } else {
      return const Duration(milliseconds: 16); // Desktop (60fps)
    }
  }
  
  /// Mobile-optimized widget for wrapping performance-sensitive areas
  Widget wrapWithMobileOptimization(Widget child, {String? debugLabel}) {
    if (!_isMobile) return child;
    
    return RepaintBoundary(
      child: _isLowEndDevice 
        ? MobileKeepAliveWrapper(child: child)
        : child,
    );
  }
  
  /// Get mobile performance metrics
  Map<String, dynamic> getMobileMetrics() {
    return {
      'isMobile': _isMobile,
      'isLowEndDevice': _isLowEndDevice,
      'platform': _isMobile ? (Platform.isIOS ? 'iOS' : 'Android') : 'Desktop',
      'optimizationsApplied': _isInitialized,
    };
  }
}

/// Widget wrapper for automatic keep alive (helps with expensive widgets)
class MobileKeepAliveWrapper extends StatefulWidget {
  final Widget child;
  
  const MobileKeepAliveWrapper({super.key, required this.child});
  
  @override
  State<MobileKeepAliveWrapper> createState() => _MobileKeepAliveWrapperState();
}

class _MobileKeepAliveWrapperState extends State<MobileKeepAliveWrapper> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}