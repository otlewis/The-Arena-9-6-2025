
/// Base class for all application errors
abstract class AppError implements Exception {
  const AppError({
    required this.message,
    this.code,
    this.details,
    this.stackTrace,
  });

  final String message;
  final String? code;
  final Map<String, dynamic>? details;
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppError: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Network-related errors
class NetworkError extends AppError {
  const NetworkError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
  });
}

/// Authentication-related errors
class AuthError extends AppError {
  const AuthError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
  });
}

/// Database/API errors
class DataError extends AppError {
  const DataError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
  });
}

/// Validation errors
class ValidationError extends AppError {
  const ValidationError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
  });
}

/// Arena/Room specific errors
class ArenaError extends AppError {
  const ArenaError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
  });
}

/// Permission errors
class PermissionError extends AppError {
  const PermissionError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
  });
}

/// Error handler utilities
class ErrorHandler {
  static AppError handleError(dynamic error, [StackTrace? stackTrace]) {
    if (error is AppError) return error;
    
    final errorMessage = error.toString();
    
    // Network errors
    if (errorMessage.contains('network') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('timeout') ||
        errorMessage.contains('socket')) {
      return NetworkError(
        message: 'Network connection failed. Please check your internet connection.',
        details: {'originalError': errorMessage},
        stackTrace: stackTrace,
      );
    }
    
    // Auth errors
    if (errorMessage.contains('unauthorized') ||
        errorMessage.contains('authentication') ||
        errorMessage.contains('login') ||
        errorMessage.contains('session')) {
      return AuthError(
        message: 'Authentication failed. Please log in again.',
        details: {'originalError': errorMessage},
        stackTrace: stackTrace,
      );
    }
    
    // Permission errors
    if (errorMessage.contains('permission') ||
        errorMessage.contains('access denied')) {
      return PermissionError(
        message: 'Permission denied. Please check your permissions.',
        details: {'originalError': errorMessage},
        stackTrace: stackTrace,
      );
    }
    
    // Default to data error
    return DataError(
      message: 'An unexpected error occurred. Please try again.',
      details: {'originalError': errorMessage},
      stackTrace: stackTrace,
    );
  }
  
  static String getUserFriendlyMessage(AppError error) {
    switch (error) {
      case NetworkError():
        return 'Please check your internet connection and try again.';
      case AuthError():
        return 'Please log in again to continue.';
      case ValidationError():
        return error.message;
      case PermissionError():
        return 'You don\'t have permission to perform this action.';
      case ArenaError():
        return error.message;
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}