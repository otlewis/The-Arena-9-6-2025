import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/logging/app_logger.dart';

// Conditional import for Platform - stub for web
import 'dart:io' if (dart.library.html) '../utils/platform_stub.dart';

/// Service for managing background audio and battery optimizations
class BackgroundAudioService {
  static final BackgroundAudioService _instance = BackgroundAudioService._internal();
  factory BackgroundAudioService() => _instance;
  BackgroundAudioService._internal();

  final _logger = AppLogger();
  static const _platform = MethodChannel('com.thearenadtd.app/background_audio');
  
  bool _isBackgroundServiceActive = false;
  bool _hasBatteryOptimizationExemption = false;
  
  bool get isBackgroundServiceActive => _isBackgroundServiceActive;
  bool get hasBatteryOptimizationExemption => _hasBatteryOptimizationExemption;

  /// Initialize background audio capabilities
  Future<void> initialize() async {
    _logger.info('🎵 Initializing background audio service');
    
    if (kIsWeb || !Platform.isAndroid) {
      _logger.info('🎵 Background audio not required on this platform');
      return;
    }
    
    try {
      // Check current battery optimization status
      await _checkBatteryOptimizationStatus();
      
      // Setup method channel for native communication
      _platform.setMethodCallHandler(_handleMethodCall);
      
      _logger.info('✅ Background audio service initialized');
    } catch (e) {
      _logger.error('Failed to initialize background audio service: $e');
    }
  }
  
  /// Handle method calls from native Android code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onServiceStarted':
        _isBackgroundServiceActive = true;
        _logger.info('🎵 Background audio service started');
        break;
      case 'onServiceStopped':
        _isBackgroundServiceActive = false;
        _logger.info('🎵 Background audio service stopped');
        break;
      case 'onBatteryOptimizationChanged':
        _hasBatteryOptimizationExemption = call.arguments['exempted'] ?? false;
        _logger.info('🔋 Battery optimization exemption: $_hasBatteryOptimizationExemption');
        break;
      default:
        _logger.warning('Unknown method call: ${call.method}');
    }
  }
  
  /// Start background audio service
  Future<bool> startBackgroundService({
    required String roomName,
    required String userName,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return true;
    
    try {
      _logger.info('🎵 Starting background audio service for room: $roomName');
      
      // Request microphone permission first
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        _logger.error('Microphone permission not granted');
        return false;
      }
      
      // Start the foreground service
      final result = await _platform.invokeMethod('startBackgroundService', {
        'roomName': roomName,
        'userName': userName,
      });
      
      _isBackgroundServiceActive = result == true;
      
      if (_isBackgroundServiceActive) {
        _logger.info('✅ Background audio service started successfully');
      } else {
        _logger.error('❌ Failed to start background audio service');
      }
      
      return _isBackgroundServiceActive;
    } catch (e) {
      _logger.error('Error starting background service: $e');
      return false;
    }
  }
  
  /// Stop background audio service
  Future<void> stopBackgroundService() async {
    if (kIsWeb || !Platform.isAndroid || !_isBackgroundServiceActive) return;
    
    try {
      _logger.info('🎵 Stopping background audio service');
      
      await _platform.invokeMethod('stopBackgroundService');
      _isBackgroundServiceActive = false;
      
      _logger.info('✅ Background audio service stopped');
    } catch (e) {
      _logger.error('Error stopping background service: $e');
    }
  }
  
  /// Request battery optimization exemption
  Future<bool> requestBatteryOptimizationExemption() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    
    try {
      _logger.info('🔋 Requesting battery optimization exemption');
      
      final result = await _platform.invokeMethod('requestBatteryOptimizationExemption');
      _hasBatteryOptimizationExemption = result == true;
      
      if (_hasBatteryOptimizationExemption) {
        _logger.info('✅ Battery optimization exemption granted');
      } else {
        _logger.warning('❌ Battery optimization exemption denied');
      }
      
      return _hasBatteryOptimizationExemption;
    } catch (e) {
      _logger.error('Error requesting battery optimization exemption: $e');
      return false;
    }
  }
  
  /// Check current battery optimization status
  Future<void> _checkBatteryOptimizationStatus() async {
    try {
      final result = await _platform.invokeMethod('isBatteryOptimizationExempted');
      _hasBatteryOptimizationExemption = result == true;
      _logger.info('🔋 Battery optimization exempted: $_hasBatteryOptimizationExemption');
    } catch (e) {
      _logger.debug('Could not check battery optimization status: $e');
    }
  }
  
  /// Update background service notification
  Future<void> updateNotification({
    required String roomName,
    required String status,
    required int participantCount,
  }) async {
    if (kIsWeb || !Platform.isAndroid || !_isBackgroundServiceActive) return;
    
    try {
      await _platform.invokeMethod('updateNotification', {
        'roomName': roomName,
        'status': status,
        'participantCount': participantCount,
      });
    } catch (e) {
      _logger.debug('Error updating notification: $e');
    }
  }
  
  /// Show battery optimization dialog if needed
  Future<bool> showBatteryOptimizationDialogIfNeeded() async {
    if (_hasBatteryOptimizationExemption) return true;
    
    // For now, just request the exemption
    // In a real app, you might want to show a dialog first
    return await requestBatteryOptimizationExemption();
  }
  
  /// Check if device requires background optimization
  bool requiresBackgroundOptimization() {
    if (kIsWeb || !Platform.isAndroid) return false;
    
    // Check for known problematic manufacturers
    try {
      // This would typically check Build.MANUFACTURER in native code
      return true; // Assume all Android devices benefit from optimization
    } catch (e) {
      return true;
    }
  }
  
  /// Get manufacturer-specific battery optimization instructions
  String getBatteryOptimizationInstructions() {
    // This would typically detect the manufacturer and return specific instructions
    return '''
To ensure uninterrupted audio during calls:

1. Go to Settings > Apps > Arena
2. Tap "Battery" or "Power Management"
3. Select "Don't optimize" or "Unrestricted"
4. Enable "Allow background activity"

For some devices:
• Samsung: Settings > Device Care > Battery > App Power Management
• Huawei: Settings > Apps > Arena > Battery > Don't allow system to manage automatically
• Xiaomi: Settings > Apps > Manage Apps > Arena > Battery Saver > No restrictions
''';
  }
}

/// Background audio optimization recommendations
class BackgroundAudioOptimizations {
  static const Map<String, AudioOptimizationProfile> _profiles = {
    'default': AudioOptimizationProfile(
      keepScreenOn: false,
      useWakeLock: true,
      notificationPriority: 'high',
      audioFocusRequest: 'audiofocus_gain',
    ),
    'low_end': AudioOptimizationProfile(
      keepScreenOn: false,
      useWakeLock: true,
      notificationPriority: 'max',
      audioFocusRequest: 'audiofocus_gain_transient',
    ),
    'battery_saver': AudioOptimizationProfile(
      keepScreenOn: false,
      useWakeLock: false,
      notificationPriority: 'default',
      audioFocusRequest: 'audiofocus_gain_transient_may_duck',
    ),
  };
  
  static AudioOptimizationProfile getProfile(String profileName) {
    return _profiles[profileName] ?? _profiles['default']!;
  }
}

/// Audio optimization profile for different scenarios
class AudioOptimizationProfile {
  final bool keepScreenOn;
  final bool useWakeLock;
  final String notificationPriority;
  final String audioFocusRequest;
  
  const AudioOptimizationProfile({
    required this.keepScreenOn,
    required this.useWakeLock,
    required this.notificationPriority,
    required this.audioFocusRequest,
  });
  
  Map<String, dynamic> toMap() => {
    'keepScreenOn': keepScreenOn,
    'useWakeLock': useWakeLock,
    'notificationPriority': notificationPriority,
    'audioFocusRequest': audioFocusRequest,
  };
}