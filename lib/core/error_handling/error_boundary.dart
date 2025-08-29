import 'dart:async';
import 'package:flutter/material.dart';
import '../logging/app_logger.dart';

/// Error types for categorized handling
enum ErrorType {
  network,
  authentication,
  permission,
  livekit,
  appwrite,
  validation,
  unknown
}

/// Error severity levels
enum ErrorSeverity {
  low,      // Info/warning level
  medium,   // User should know but app continues
  high,     // Critical error, user action needed
  critical  // App-breaking error
}

/// Structured error information
class AppError {
  final ErrorType type;
  final ErrorSeverity severity;
  final String message;
  final String userMessage;
  final String? technicalDetails;
  final StackTrace? stackTrace;
  final DateTime? timestamp;
  final String? context;

  const AppError({
    required this.type,
    required this.severity,
    required this.message,
    required this.userMessage,
    this.technicalDetails,
    this.stackTrace,
    this.context,
  }) : timestamp = null;

  AppError._internal({
    required this.type,
    required this.severity,
    required this.message,
    required this.userMessage,
    this.technicalDetails,
    this.stackTrace,
    this.context,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory AppError.create({
    required ErrorType type,
    required ErrorSeverity severity,
    required String message,
    required String userMessage,
    String? technicalDetails,
    StackTrace? stackTrace,
    String? context,
  }) {
    return AppError._internal(
      type: type,
      severity: severity,
      message: message,
      userMessage: userMessage,
      technicalDetails: technicalDetails,
      stackTrace: stackTrace,
      context: context,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() => 'AppError($type, $severity): $message';
}

/// Centralized error boundary and handler
class ErrorBoundary {
  static final ErrorBoundary _instance = ErrorBoundary._internal();
  factory ErrorBoundary() => _instance;
  ErrorBoundary._internal();

  final StreamController<AppError> _errorController = 
      StreamController<AppError>.broadcast();

  /// Stream of errors for UI to listen to
  Stream<AppError> get errorStream => _errorController.stream;

  /// Handle any error and convert to AppError
  void handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    ErrorType? type,
    ErrorSeverity? severity,
  }) {
    final appError = _categorizeError(error, stackTrace, context, type, severity);
    _processError(appError);
  }

  /// Handle specific LiveKit errors
  void handleLiveKitError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
  }) {
    final appError = AppError.create(
      type: ErrorType.livekit,
      severity: _determineSeverity(error),
      message: 'LiveKit Error: ${error.toString()}',
      userMessage: _getLiveKitUserMessage(error),
      technicalDetails: error.toString(),
      stackTrace: stackTrace,
      context: context ?? 'LiveKit Operation',
    );
    _processError(appError);
  }

  /// Handle specific Appwrite errors
  void handleAppwriteError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
  }) {
    final appError = AppError.create(
      type: ErrorType.appwrite,
      severity: _determineSeverity(error),
      message: 'Appwrite Error: ${error.toString()}',
      userMessage: _getAppwriteUserMessage(error),
      technicalDetails: error.toString(),
      stackTrace: stackTrace,
      context: context ?? 'Appwrite Operation',
    );
    _processError(appError);
  }

  /// Handle network errors
  void handleNetworkError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
  }) {
    final appError = AppError.create(
      type: ErrorType.network,
      severity: ErrorSeverity.medium,
      message: 'Network Error: ${error.toString()}',
      userMessage: 'Connection problem. Please check your internet and try again.',
      technicalDetails: error.toString(),
      stackTrace: stackTrace,
      context: context ?? 'Network Operation',
    );
    _processError(appError);
  }

  /// Handle authentication errors
  void handleAuthError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
  }) {
    final appError = AppError.create(
      type: ErrorType.authentication,
      severity: ErrorSeverity.high,
      message: 'Authentication Error: ${error.toString()}',
      userMessage: 'Authentication failed. Please sign in again.',
      technicalDetails: error.toString(),
      stackTrace: stackTrace,
      context: context ?? 'Authentication',
    );
    _processError(appError);
  }

  /// Handle validation errors
  void handleValidationError(
    String field,
    String message, {
    String? context,
  }) {
    final appError = AppError.create(
      type: ErrorType.validation,
      severity: ErrorSeverity.low,
      message: 'Validation Error: $field - $message',
      userMessage: message,
      context: context ?? 'Input Validation',
    );
    _processError(appError);
  }

  /// Categorize unknown errors
  AppError _categorizeError(
    dynamic error,
    StackTrace? stackTrace,
    String? context,
    ErrorType? type,
    ErrorSeverity? severity,
  ) {
    // Try to determine error type from error content
    final errorString = error.toString().toLowerCase();
    
    ErrorType determinedType = type ?? ErrorType.unknown;
    if (type == null) {
      if (errorString.contains('network') || errorString.contains('connection')) {
        determinedType = ErrorType.network;
      } else if (errorString.contains('auth') || errorString.contains('unauthorized')) {
        determinedType = ErrorType.authentication;
      } else if (errorString.contains('permission') || errorString.contains('forbidden')) {
        determinedType = ErrorType.permission;
      } else if (errorString.contains('livekit')) {
        determinedType = ErrorType.livekit;
      } else if (errorString.contains('appwrite')) {
        determinedType = ErrorType.appwrite;
      }
    }

    return AppError.create(
      type: determinedType,
      severity: severity ?? _determineSeverity(error),
      message: error.toString(),
      userMessage: _generateUserMessage(determinedType, error),
      technicalDetails: error.toString(),
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Determine error severity
  ErrorSeverity _determineSeverity(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('critical') || 
        errorString.contains('fatal') ||
        errorString.contains('unauthorized')) {
      return ErrorSeverity.critical;
    } else if (errorString.contains('failed') || 
               errorString.contains('error') ||
               errorString.contains('exception')) {
      return ErrorSeverity.high;
    } else if (errorString.contains('warning') || 
               errorString.contains('timeout')) {
      return ErrorSeverity.medium;
    } else {
      return ErrorSeverity.low;
    }
  }

  /// Generate user-friendly messages
  String _generateUserMessage(ErrorType type, dynamic error) {
    switch (type) {
      case ErrorType.network:
        return 'Connection problem. Please check your internet and try again.';
      case ErrorType.authentication:
        return 'Authentication failed. Please sign in again.';
      case ErrorType.permission:
        return 'You don\'t have permission to perform this action.';
      case ErrorType.livekit:
        return _getLiveKitUserMessage(error);
      case ErrorType.appwrite:
        return _getAppwriteUserMessage(error);
      case ErrorType.validation:
        return 'Please check your input and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  /// Get LiveKit-specific user messages
  String _getLiveKitUserMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('token')) {
      return 'Connection authorization failed. Please try rejoining the room.';
    } else if (errorString.contains('room')) {
      return 'Unable to join the room. Please check if the room exists.';
    } else if (errorString.contains('microphone') || errorString.contains('audio')) {
      return 'Microphone access failed. Please check your audio permissions.';
    } else if (errorString.contains('connection')) {
      return 'Voice connection failed. Please check your internet connection.';
    } else {
      return 'Voice service error. Please try again.';
    }
  }

  /// Get Appwrite-specific user messages
  String _getAppwriteUserMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('not_found') || errorString.contains('document')) {
      return 'The requested information was not found.';
    } else if (errorString.contains('permission') || errorString.contains('unauthorized')) {
      return 'You don\'t have permission to access this information.';
    } else if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Database connection failed. Please try again.';
    } else if (errorString.contains('validation')) {
      return 'Invalid data format. Please check your input.';
    } else {
      return 'Data service error. Please try again.';
    }
  }

  /// Process and log the error
  void _processError(AppError appError) {
    // Log the error appropriately
    switch (appError.severity) {
      case ErrorSeverity.low:
        AppLogger().debug('${appError.type.name.toUpperCase()} INFO: ${appError.message}');
        break;
      case ErrorSeverity.medium:
        AppLogger().warning('${appError.type.name.toUpperCase()} WARNING: ${appError.message}');
        break;
      case ErrorSeverity.high:
        AppLogger().error('${appError.type.name.toUpperCase()} ERROR: ${appError.message}');
        break;
      case ErrorSeverity.critical:
        AppLogger().error('${appError.type.name.toUpperCase()} CRITICAL: ${appError.message}');
        if (appError.stackTrace != null) {
          AppLogger().error('Stack trace: ${appError.stackTrace}');
        }
        break;
    }

    // Emit error for UI handling
    if (!_errorController.isClosed) {
      _errorController.add(appError);
    }
  }

  /// Show error to user (to be implemented by UI layer)
  void showErrorToUser(BuildContext context, AppError error) {
    final color = _getErrorColor(error.severity);
    final icon = _getErrorIcon(error.type);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error.userMessage,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (error.severity == ErrorSeverity.high || error.severity == ErrorSeverity.critical)
                    Text(
                      error.context ?? 'Error occurred',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: Duration(seconds: _getErrorDuration(error.severity)),
        action: error.severity == ErrorSeverity.critical
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  // Retry logic would be handled by the calling component
                },
              )
            : null,
      ),
    );
  }

  /// Get error color based on severity
  Color _getErrorColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return Colors.blue;
      case ErrorSeverity.medium:
        return Colors.orange;
      case ErrorSeverity.high:
        return Colors.red;
      case ErrorSeverity.critical:
        return Colors.red.shade800;
    }
  }

  /// Get error icon based on type
  IconData _getErrorIcon(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.authentication:
        return Icons.lock_outline;
      case ErrorType.permission:
        return Icons.block;
      case ErrorType.livekit:
        return Icons.mic_off;
      case ErrorType.appwrite:
        return Icons.storage;
      case ErrorType.validation:
        return Icons.warning_amber;
      default:
        return Icons.error_outline;
    }
  }

  /// Get error display duration
  int _getErrorDuration(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return 3;
      case ErrorSeverity.medium:
        return 4;
      case ErrorSeverity.high:
        return 6;
      case ErrorSeverity.critical:
        return 8;
    }
  }

  /// Dispose resources
  void dispose() {
    _errorController.close();
    AppLogger().debug('🗑️ ErrorBoundary disposed');
  }
}

/// Widget wrapper for error boundary
class ErrorBoundaryWidget extends StatefulWidget {
  final Widget child;
  final Function(AppError)? onError;

  const ErrorBoundaryWidget({
    Key? key,
    required this.child,
    this.onError,
  }) : super(key: key);

  @override
  State<ErrorBoundaryWidget> createState() => _ErrorBoundaryWidgetState();
}

class _ErrorBoundaryWidgetState extends State<ErrorBoundaryWidget> {
  late StreamSubscription<AppError> _errorSubscription;

  @override
  void initState() {
    super.initState();
    _errorSubscription = ErrorBoundary().errorStream.listen((error) {
      if (mounted) {
        widget.onError?.call(error);
        ErrorBoundary().showErrorToUser(context, error);
      }
    });
  }

  @override
  void dispose() {
    _errorSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}