import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/logging/app_logger.dart';

// Conditional import for Platform - stub for web
import 'dart:io' if (dart.library.html) '../utils/platform_stub.dart';

/// Service to detect when user is on a phone call
/// Shows phone icon on avatar to notify other users
class PhoneCallDetectionService extends ChangeNotifier {
  static final PhoneCallDetectionService _instance = PhoneCallDetectionService._internal();
  factory PhoneCallDetectionService() => _instance;
  PhoneCallDetectionService._internal();

  final AppLogger _logger = AppLogger();
  static const _platform = MethodChannel('com.thearenadtd.app/phone_call');

  bool _isOnPhoneCall = false;
  Timer? _pollTimer;
  StreamSubscription? _callStateSubscription;

  bool get isOnPhoneCall => _isOnPhoneCall;

  /// Initialize phone call detection
  Future<void> initialize() async {
    _logger.info('📞 Initializing phone call detection service');

    if (kIsWeb || !Platform.isAndroid) {
      _logger.info('📞 Phone call detection not available on this platform');
      return;
    }

    try {
      // Set up method channel for native communication
      _platform.setMethodCallHandler(_handleMethodCall);

      // Start monitoring phone call state
      await _startMonitoring();

      _logger.info('✅ Phone call detection service initialized');
    } catch (e) {
      _logger.error('Failed to initialize phone call detection: $e');
    }
  }

  /// Handle method calls from native Android code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onCallStateChanged':
        final isOnCall = call.arguments['isOnCall'] ?? false;
        _updateCallState(isOnCall);
        break;
      default:
        _logger.warning('Unknown method call: ${call.method}');
    }
  }

  /// Start monitoring phone call state
  Future<void> _startMonitoring() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      // Request initial state
      final initialState = await _platform.invokeMethod('startMonitoring');
      _updateCallState(initialState == true);

      // Poll for call state every 2 seconds as backup
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        try {
          final isOnCall = await _platform.invokeMethod('getCallState');
          _updateCallState(isOnCall == true);
        } catch (e) {
          _logger.debug('Error polling call state: $e');
        }
      });

      _logger.info('✅ Phone call monitoring started');
    } catch (e) {
      _logger.error('Error starting phone call monitoring: $e');
    }
  }

  /// Stop monitoring phone call state
  Future<void> stopMonitoring() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      await _platform.invokeMethod('stopMonitoring');
      _pollTimer?.cancel();
      _pollTimer = null;
      _callStateSubscription?.cancel();
      _callStateSubscription = null;

      _logger.info('📞 Phone call monitoring stopped');
    } catch (e) {
      _logger.error('Error stopping phone call monitoring: $e');
    }
  }

  /// Update call state and notify listeners
  void _updateCallState(bool isOnCall) {
    if (_isOnPhoneCall != isOnCall) {
      _isOnPhoneCall = isOnCall;
      _logger.info('📞 Phone call state changed: ${isOnCall ? "ON CALL" : "IDLE"}');
      notifyListeners();
    }
  }

  /// Check if user is currently on a phone call
  Future<bool> checkCallState() async {
    if (kIsWeb || !Platform.isAndroid) return false;

    try {
      final isOnCall = await _platform.invokeMethod('getCallState');
      return isOnCall == true;
    } catch (e) {
      _logger.debug('Error checking call state: $e');
      return false;
    }
  }

  /// Dispose and cleanup resources
  @override
  void dispose() {
    stopMonitoring();
    _pollTimer?.cancel();
    _callStateSubscription?.cancel();
    super.dispose();
  }
}
