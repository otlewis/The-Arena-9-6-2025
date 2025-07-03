import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../error/app_error.dart';

/// Centralized logging service for the application
class AppLogger {
  static AppLogger? _instance;
  static AppLogger get instance {
    _instance ??= AppLogger._internal();
    return _instance!;
  }
  
  factory AppLogger() => instance;
  AppLogger._internal();

  Logger? _logger;
  
  Logger get logger {
    _logger ??= Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.none,
      ),
      level: kDebugMode ? Level.debug : Level.warning,
    );
    return _logger!;
  }
  
  void initialize() {
    // Force logger creation
    logger;
  }

  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      logger.d(message, error: error, stackTrace: stackTrace);
    }
  }

  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    logger.i(message, error: error, stackTrace: stackTrace);
  }

  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    logger.w(message, error: error, stackTrace: stackTrace);
  }

  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    logger.e(message, error: error, stackTrace: stackTrace);
  }

  void logError(AppError error) {
    logger.e(
      error.message,
      error: error.details,
      stackTrace: error.stackTrace,
    );
  }

  void logNetworkCall(String method, String url, [Map<String, dynamic>? data]) {
    if (kDebugMode) {
      logger.d('🌐 $method $url', error: data);
    }
  }

  void logUserAction(String action, [Map<String, dynamic>? context]) {
    if (kDebugMode) {
      logger.i('👤 User Action: $action', error: context);
    }
  }

  void logPerformance(String operation, Duration duration) {
    if (kDebugMode) {
      logger.i('⚡ Performance: $operation took ${duration.inMilliseconds}ms');
    }
  }
}