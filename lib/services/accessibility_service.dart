import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logging/app_logger.dart';

class AccessibilityService extends ChangeNotifier {
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  final AppLogger _logger = AppLogger();

  // Accessibility preferences
  bool _largeTextEnabled = false;
  bool _highContrastEnabled = false;
  bool _reducedMotionEnabled = false;
  bool _screenReaderOptimized = false;
  double _textScaleFactor = 1.0;

  // Getters
  bool get largeTextEnabled => _largeTextEnabled;
  bool get highContrastEnabled => _highContrastEnabled;
  bool get reducedMotionEnabled => _reducedMotionEnabled;
  bool get screenReaderOptimized => _screenReaderOptimized;
  double get textScaleFactor => _textScaleFactor;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load saved preferences
      _largeTextEnabled = prefs.getBool('accessibility_large_text') ?? false;
      _highContrastEnabled = prefs.getBool('accessibility_high_contrast') ?? false;
      _reducedMotionEnabled = prefs.getBool('accessibility_reduced_motion') ?? false;
      _screenReaderOptimized = prefs.getBool('accessibility_screen_reader') ?? false;
      _textScaleFactor = prefs.getDouble('accessibility_text_scale') ?? 1.0;

      // Check system accessibility settings
      await _checkSystemAccessibilitySettings();
      
      _logger.info('Accessibility service initialized');
      notifyListeners();
    } catch (e) {
      _logger.error('Error initializing accessibility service: $e');
    }
  }

  Future<void> _checkSystemAccessibilitySettings() async {
    try {
      // Check if system has accessibility features enabled
      final platformDispatcher = WidgetsBinding.instance.platformDispatcher;
      final accessibilityFeatures = platformDispatcher.accessibilityFeatures;
      
      // Auto-enable based on system settings
      if (accessibilityFeatures.boldText && !_largeTextEnabled) {
        await setLargeTextEnabled(true);
      }
      
      if (accessibilityFeatures.highContrast && !_highContrastEnabled) {
        await setHighContrastEnabled(true);
      }
      
      if (accessibilityFeatures.reduceMotion && !_reducedMotionEnabled) {
        await setReducedMotionEnabled(true);
      }

      // Check for screen reader
      if (accessibilityFeatures.accessibleNavigation && !_screenReaderOptimized) {
        await setScreenReaderOptimized(true);
      }

      // Note: textScaleFactor should be accessed from MediaQuery in widget context
      // We'll handle this differently in the widget
      
    } catch (e) {
      _logger.warning('Error checking system accessibility settings: $e');
    }
  }

  Future<void> setLargeTextEnabled(bool enabled) async {
    try {
      _largeTextEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('accessibility_large_text', enabled);
      
      // Automatically adjust text scale when large text is enabled
      if (enabled && _textScaleFactor < 1.3) {
        await setTextScaleFactor(1.3);
      }
      
      _logger.info('Large text ${enabled ? 'enabled' : 'disabled'}');
      notifyListeners();
    } catch (e) {
      _logger.error('Error setting large text: $e');
    }
  }

  Future<void> setHighContrastEnabled(bool enabled) async {
    try {
      _highContrastEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('accessibility_high_contrast', enabled);
      
      _logger.info('High contrast ${enabled ? 'enabled' : 'disabled'}');
      notifyListeners();
    } catch (e) {
      _logger.error('Error setting high contrast: $e');
    }
  }

  Future<void> setReducedMotionEnabled(bool enabled) async {
    try {
      _reducedMotionEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('accessibility_reduced_motion', enabled);
      
      _logger.info('Reduced motion ${enabled ? 'enabled' : 'disabled'}');
      notifyListeners();
    } catch (e) {
      _logger.error('Error setting reduced motion: $e');
    }
  }

  Future<void> setScreenReaderOptimized(bool enabled) async {
    try {
      _screenReaderOptimized = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('accessibility_screen_reader', enabled);
      
      _logger.info('Screen reader optimization ${enabled ? 'enabled' : 'disabled'}');
      notifyListeners();
    } catch (e) {
      _logger.error('Error setting screen reader optimization: $e');
    }
  }

  Future<void> setTextScaleFactor(double scale) async {
    try {
      // Clamp between reasonable bounds
      _textScaleFactor = scale.clamp(0.8, 3.0);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('accessibility_text_scale', _textScaleFactor);
      
      _logger.info('Text scale factor set to: $_textScaleFactor');
      notifyListeners();
    } catch (e) {
      _logger.error('Error setting text scale factor: $e');
    }
  }

  /// Get high contrast color scheme
  ColorScheme getHighContrastColorScheme(bool isDark) {
    if (!_highContrastEnabled) return _getDefaultColorScheme(isDark);
    
    if (isDark) {
      return const ColorScheme.dark(
        primary: Colors.white,
        secondary: Colors.yellow,
        surface: Colors.black,
        onSurface: Colors.white,
        error: Colors.red,
        onError: Colors.white,
      );
    } else {
      return const ColorScheme.light(
        primary: Colors.black,
        secondary: Colors.blue,
        surface: Colors.white,
        onSurface: Colors.black,
        error: Colors.red,
        onError: Colors.white,
      );
    }
  }

  ColorScheme _getDefaultColorScheme(bool isDark) {
    return isDark ? const ColorScheme.dark() : const ColorScheme.light();
  }

  /// Get animation duration considering reduced motion setting
  Duration getAnimationDuration(Duration defaultDuration) {
    if (_reducedMotionEnabled) {
      return Duration.zero;
    }
    return defaultDuration;
  }

  /// Announce message to screen reader
  void announceToScreenReader(String message) {
    if (_screenReaderOptimized) {
      SemanticsService.announce(message, TextDirection.ltr);
      _logger.debug('Screen reader announcement: $message');
    }
  }

  /// Provide haptic feedback if appropriate
  void provideHapticFeedback() {
    if (!_reducedMotionEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  /// Get semantic label for role
  String getRoleSemanticLabel(String role) {
    switch (role.toLowerCase()) {
      case 'moderator':
        return 'Moderator role. Can control room settings and manage participants.';
      case 'speaker':
        return 'Speaker role. Can speak and participate in discussions.';
      case 'audience':
        return 'Audience role. Can listen and raise hand to speak.';
      case 'judge':
        return 'Judge role. Can evaluate and score debates.';
      default:
        return 'Participant role: $role';
    }
  }

  /// Get semantic label for timer state
  String getTimerSemanticLabel(int seconds, bool isRunning) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final timeString = '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    
    if (isRunning) {
      return 'Timer running. $timeString remaining.';
    } else {
      return 'Timer stopped. $timeString set.';
    }
  }

  /// Get semantic label for connection status
  String getConnectionSemanticLabel(bool isConnected) {
    return isConnected 
        ? 'Connected to voice chat' 
        : 'Disconnected from voice chat';
  }

  /// Get semantic label for participant count
  String getParticipantCountSemanticLabel(int count) {
    if (count == 0) return 'No participants in room';
    if (count == 1) return '1 participant in room';
    return '$count participants in room';
  }

  /// Create accessible button widget
  Widget makeAccessibleButton({
    required Widget child,
    required VoidCallback? onPressed,
    required String semanticLabel,
    String? tooltip,
    bool excludeSemantics = false,
  }) {
    Widget button = child;
    
    if (tooltip != null) {
      button = Tooltip(
        message: tooltip,
        child: button,
      );
    }
    
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null,
      excludeSemantics: excludeSemantics,
      child: button,
    );
  }

  /// Create accessible text widget with proper contrast
  Widget makeAccessibleText(
    String text, {
    TextStyle? style,
    Color? color,
    bool isHeading = false,
  }) {
    Color textColor = color ?? Colors.black;
    
    if (_highContrastEnabled) {
      textColor = Colors.black;
    }
    
    final textStyle = (style ?? const TextStyle()).copyWith(
      color: textColor,
      fontSize: (style?.fontSize ?? 14) * _textScaleFactor,
    );
    
    return Semantics(
      label: text,
      header: isHeading,
      child: Text(
        text,
        style: textStyle,
      ),
    );
  }
}