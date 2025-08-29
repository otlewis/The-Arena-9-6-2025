import 'package:flutter/material.dart';
import '../core/logging/app_logger.dart';

/// Service for handling responsive design across different screen sizes and orientations
class ResponsiveService {
  static final ResponsiveService _instance = ResponsiveService._internal();
  factory ResponsiveService() => _instance;
  ResponsiveService._internal();

  final AppLogger _logger = AppLogger();

  // Breakpoints for different screen sizes (in logical pixels)
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1440;

  // Minimum screen dimensions for pixel overflow prevention
  static const double minScreenWidth = 320;
  static const double minScreenHeight = 568;

  /// Get device type based on screen width
  DeviceType getDeviceType(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth < mobileBreakpoint) {
      return DeviceType.mobile;
    } else if (screenWidth < tabletBreakpoint) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  /// Get screen size category
  ScreenSize getScreenSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Handle very small screens (prevent pixel overflow)
    if (screenWidth < 360 || screenHeight < 640) {
      return ScreenSize.small;
    } else if (screenWidth < 768 || screenHeight < 1024) {
      return ScreenSize.medium;
    } else if (screenWidth < 1200 || screenHeight < 1600) {
      return ScreenSize.large;
    } else {
      return ScreenSize.extraLarge;
    }
  }

  /// Get responsive padding based on screen size
  /// Note: App is locked to portrait orientation
  EdgeInsets getResponsivePadding(BuildContext context) {
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return const EdgeInsets.all(16);
      case DeviceType.tablet:
        return const EdgeInsets.all(24);
      case DeviceType.desktop:
        return const EdgeInsets.all(32);
    }
  }

  /// Get responsive margin based on screen size
  EdgeInsets getResponsiveMargin(BuildContext context) {
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return const EdgeInsets.all(8);
      case DeviceType.tablet:
        return const EdgeInsets.all(16);
      case DeviceType.desktop:
        return const EdgeInsets.all(24);
    }
  }

  /// Get responsive font size multiplier
  double getFontSizeMultiplier(BuildContext context) {
    final screenSize = getScreenSize(context);
    
    switch (screenSize) {
      case ScreenSize.small:
        return 0.9;
      case ScreenSize.medium:
        return 1.0;
      case ScreenSize.large:
        return 1.1;
      case ScreenSize.extraLarge:
        return 1.2;
    }
  }

  /// Get responsive column count for grid layouts
  int getResponsiveColumnCount(BuildContext context, {int maxColumns = 4}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final deviceType = getDeviceType(context);
    
    // Calculate based on available width and minimum item width
    const double minItemWidth = 280;
    int calculatedColumns = (screenWidth / minItemWidth).floor();
    
    // Apply device-specific constraints
    switch (deviceType) {
      case DeviceType.mobile:
        return (calculatedColumns.clamp(1, 2)).clamp(1, maxColumns);
      case DeviceType.tablet:
        return (calculatedColumns.clamp(2, 3)).clamp(1, maxColumns);
      case DeviceType.desktop:
        return calculatedColumns.clamp(1, maxColumns);
    }
  }

  /// Get responsive grid spacing
  double getGridSpacing(BuildContext context) {
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return 8.0;
      case DeviceType.tablet:
        return 12.0;
      case DeviceType.desktop:
        return 16.0;
    }
  }

  /// Get safe area adjusted height
  double getSafeAreaHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.height - 
           mediaQuery.padding.top - 
           mediaQuery.padding.bottom;
  }

  /// Get safe area adjusted width
  double getSafeAreaWidth(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.width - 
           mediaQuery.padding.left - 
           mediaQuery.padding.right;
  }

  /// Get responsive dialog width
  double getDialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return screenWidth * 0.9;
      case DeviceType.tablet:
        return (screenWidth * 0.7).clamp(400, 600);
      case DeviceType.desktop:
        return (screenWidth * 0.5).clamp(500, 800);
    }
  }

  /// Get responsive app bar height
  double getAppBarHeight(BuildContext context) {
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return kToolbarHeight;
      case DeviceType.tablet:
        return kToolbarHeight + 8;
      case DeviceType.desktop:
        return kToolbarHeight + 16;
    }
  }

  /// Get responsive card width for horizontal scrolling
  double getCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return screenWidth * 0.85;
      case DeviceType.tablet:
        return 350;
      case DeviceType.desktop:
        return 400;
    }
  }

  /// Get maximum content width for readability
  double getMaxContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return screenWidth;
      case DeviceType.tablet:
        return 768;
      case DeviceType.desktop:
        return 1200;
    }
  }

  /// Get responsive icon size
  double getIconSize(BuildContext context, {IconSizeType type = IconSizeType.normal}) {
    final deviceType = getDeviceType(context);
    
    double baseSize;
    switch (type) {
      case IconSizeType.small:
        baseSize = 16;
        break;
      case IconSizeType.normal:
        baseSize = 24;
        break;
      case IconSizeType.large:
        baseSize = 32;
        break;
      case IconSizeType.extraLarge:
        baseSize = 48;
        break;
    }
    
    switch (deviceType) {
      case DeviceType.mobile:
        return baseSize;
      case DeviceType.tablet:
        return baseSize * 1.1;
      case DeviceType.desktop:
        return baseSize * 1.2;
    }
  }

  /// Get responsive border radius
  double getBorderRadius(BuildContext context, {BorderRadiusType type = BorderRadiusType.normal}) {
    final deviceType = getDeviceType(context);
    
    double baseRadius;
    switch (type) {
      case BorderRadiusType.small:
        baseRadius = 4;
        break;
      case BorderRadiusType.normal:
        baseRadius = 8;
        break;
      case BorderRadiusType.large:
        baseRadius = 16;
        break;
      case BorderRadiusType.extraLarge:
        baseRadius = 24;
        break;
    }
    
    switch (deviceType) {
      case DeviceType.mobile:
        return baseRadius;
      case DeviceType.tablet:
        return baseRadius * 1.1;
      case DeviceType.desktop:
        return baseRadius * 1.2;
    }
  }

  /// Check if screen is too small and might have pixel overflow
  bool hasPixelOverflowRisk(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width < minScreenWidth || size.height < minScreenHeight;
  }

  /// Get adaptive layout for participant grids
  /// Note: App is locked to portrait orientation
  GridLayoutConfig getParticipantGridLayout(BuildContext context, int participantCount) {
    final deviceType = getDeviceType(context);
    final screenWidth = getSafeAreaWidth(context);
    
    // Minimum item size to prevent overflow
    const double minItemSize = 80;
    
    int columns;
    double itemSize;
    
    if (deviceType == DeviceType.mobile) {
      columns = participantCount > 6 ? 4 : 3;
      itemSize = (screenWidth / columns - 16).clamp(minItemSize, 100);
    } else if (deviceType == DeviceType.tablet) {
      columns = 6;
      itemSize = (screenWidth / columns - 20).clamp(minItemSize, 140);
    } else {
      columns = 8;
      itemSize = (screenWidth / columns - 24).clamp(minItemSize, 160);
    }
    
    return GridLayoutConfig(
      columns: columns,
      itemSize: itemSize,
      spacing: getGridSpacing(context),
    );
  }

  /// Log responsive metrics for debugging
  void logResponsiveMetrics(BuildContext context) {
    // Only log in debug mode
    
    final size = MediaQuery.of(context).size;
    final deviceType = getDeviceType(context);
    final screenSize = getScreenSize(context);
    
    _logger.debug('📱 Responsive Metrics:');
    _logger.debug('  Screen: ${size.width.toInt()}x${size.height.toInt()}');
    _logger.debug('  Device: $deviceType');
    _logger.debug('  Size: $screenSize');
    _logger.debug('  Orientation: Portrait (locked)');
    _logger.debug('  Pixel overflow risk: ${hasPixelOverflowRisk(context)}');
  }
}

enum DeviceType { mobile, tablet, desktop }
enum ScreenSize { small, medium, large, extraLarge }
enum IconSizeType { small, normal, large, extraLarge }
enum BorderRadiusType { small, normal, large, extraLarge }

class GridLayoutConfig {
  final int columns;
  final double itemSize;
  final double spacing;

  GridLayoutConfig({
    required this.columns,
    required this.itemSize,
    required this.spacing,
  });
}

/// Extension to make ResponsiveService easily accessible
extension ResponsiveContext on BuildContext {
  ResponsiveService get responsive => ResponsiveService();
}