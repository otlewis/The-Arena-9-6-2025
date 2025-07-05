import 'package:flutter_test/flutter_test.dart';
import 'package:arena/core/error/app_error.dart';

void main() {
  group('ErrorHandler', () {
    test('should classify network errors correctly', () {
      final networkError = Exception('network connection failed');
      final appError = ErrorHandler.handleError(networkError);

      expect(appError, isA<NetworkError>());
      expect(appError.message, contains('Network connection failed'));
    });

    test('should classify auth errors correctly', () {
      final authError = Exception('unauthorized access');
      final appError = ErrorHandler.handleError(authError);

      expect(appError, isA<AuthError>());
      expect(appError.message, contains('Authentication failed'));
    });

    test('should classify permission errors correctly', () {
      final permissionError = Exception('access denied to resource');
      final appError = ErrorHandler.handleError(permissionError);

      expect(appError, isA<PermissionError>());
      expect(appError.message, contains('Permission denied'));
    });

    test('should default to DataError for unknown errors', () {
      final unknownError = Exception('some random error');
      final appError = ErrorHandler.handleError(unknownError);

      expect(appError, isA<DataError>());
      expect(appError.message, contains('unexpected error'));
    });

    test('should preserve original error details', () {
      final originalError = Exception('original error message');
      final stackTrace = StackTrace.current;
      final appError = ErrorHandler.handleError(originalError, stackTrace);

      expect(appError.details?['originalError'], contains('original error message'));
      expect(appError.stackTrace, equals(stackTrace));
    });

    test('should return AppError unchanged if already AppError', () {
      const originalAppError = ValidationError(
        message: 'Custom validation error',
        code: 'VALIDATION_001',
      );
      
      final result = ErrorHandler.handleError(originalAppError);
      
      expect(result, equals(originalAppError));
      expect(result.message, 'Custom validation error');
      expect(result.code, 'VALIDATION_001');
    });
  });

  group('getUserFriendlyMessage', () {
    test('should return appropriate message for NetworkError', () {
      const error = NetworkError(message: 'Connection timeout');
      final userMessage = ErrorHandler.getUserFriendlyMessage(error);

      expect(userMessage, contains('check your internet connection'));
    });

    test('should return appropriate message for AuthError', () {
      const error = AuthError(message: 'Invalid session');
      final userMessage = ErrorHandler.getUserFriendlyMessage(error);

      expect(userMessage, contains('log in again'));
    });

    test('should return appropriate message for ValidationError', () {
      const error = ValidationError(message: 'Email is required');
      final userMessage = ErrorHandler.getUserFriendlyMessage(error);

      expect(userMessage, 'Email is required'); // Should return the actual message
    });

    test('should return appropriate message for PermissionError', () {
      const error = PermissionError(message: 'Access denied');
      final userMessage = ErrorHandler.getUserFriendlyMessage(error);

      expect(userMessage, contains('don\'t have permission'));
    });

    test('should return appropriate message for ArenaError', () {
      const error = ArenaError(message: 'Arena is full');
      final userMessage = ErrorHandler.getUserFriendlyMessage(error);

      expect(userMessage, 'Arena is full'); // Should return the actual message
    });

    test('should return generic message for unknown error types', () {
      const error = DataError(message: 'Database error');
      final userMessage = ErrorHandler.getUserFriendlyMessage(error);

      expect(userMessage, contains('Something went wrong'));
    });
  });

  group('AppError types', () {
    test('should create NetworkError with all properties', () {
      const error = NetworkError(
        message: 'Connection failed',
        code: 'NET_001',
        details: {'host': 'api.example.com'},
      );

      expect(error.message, 'Connection failed');
      expect(error.code, 'NET_001');
      expect(error.details?['host'], 'api.example.com');
    });

    test('should create ValidationError correctly', () {
      const error = ValidationError(
        message: 'Invalid input',
        code: 'VAL_001',
      );

      expect(error.message, 'Invalid input');
      expect(error.code, 'VAL_001');
      expect(error.toString(), contains('Invalid input'));
    });

    test('should create ArenaError correctly', () {
      const error = ArenaError(
        message: 'Arena operation failed',
        details: {'roomId': 'room123'},
      );

      expect(error.message, 'Arena operation failed');
      expect(error.details?['roomId'], 'room123');
    });

    test('should have proper toString representation', () {
      const error = DataError(
        message: 'Data access failed',
        code: 'DATA_001',
      );

      final stringRepresentation = error.toString();
      expect(stringRepresentation, contains('AppError'));
      expect(stringRepresentation, contains('Data access failed'));
      expect(stringRepresentation, contains('DATA_001'));
    });
  });
}