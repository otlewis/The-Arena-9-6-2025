import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:arena/core/providers/app_providers.dart';
import 'package:arena/core/state/app_state.dart';
import 'package:arena/services/appwrite_service.dart';
import 'package:arena/core/logging/app_logger.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:appwrite/models.dart' as models;

import 'app_providers_test.mocks.dart';

@GenerateMocks([
  AppwriteService, 
  AppLogger,
], customMocks: [
  MockSpec<models.User>(as: #MockUser),
  MockSpec<models.Session>(as: #MockSession),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('AuthStateNotifier', () {
    late MockAppwriteService mockAppwrite;
    late MockAppLogger mockLogger;
    late ProviderContainer container;

    setUp(() {
      mockAppwrite = MockAppwriteService();
      mockLogger = MockAppLogger();
      
      container = ProviderContainer(
        overrides: [
          appwriteServiceProvider.overrideWithValue(mockAppwrite),
          loggerProvider.overrideWithValue(mockLogger),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state should be loading false and not authenticated', () {
      final authNotifier = container.read(authStateProvider.notifier);
      final initialState = container.read(authStateProvider);

      expect(initialState.isAuthenticated, false);
      expect(initialState.isLoading, false);
      expect(initialState.currentUser, null);
    });

    test('should authenticate user successfully', () async {
      // Arrange  
      final mockUser = MockUser();
      final mockSession = MockSession();
      when(mockAppwrite.signIn(email: 'test@example.com', password: 'password123'))
          .thenAnswer((_) async => mockSession);
      when(mockAppwrite.getCurrentUser())
          .thenAnswer((_) async => mockUser);
      when(mockUser.$id).thenReturn('user123');
      when(mockUser.email).thenReturn('test@example.com');
      when(mockUser.name).thenReturn('Test User');

      final authNotifier = container.read(authStateProvider.notifier);

      // Act
      await authNotifier.signIn('test@example.com', 'password123');

      // Assert
      final finalState = container.read(authStateProvider);
      expect(finalState.isAuthenticated, true);
      expect(finalState.isLoading, false);
      expect(finalState.currentUser, isNotNull);
      expect(finalState.lastError, null);
    });

    test('should handle sign in error', () async {
      // Arrange
      when(mockAppwrite.signIn(email: 'test@example.com', password: 'wrong'))
          .thenThrow(Exception('Invalid credentials'));

      final authNotifier = container.read(authStateProvider.notifier);

      // Act
      await authNotifier.signIn('test@example.com', 'wrong');

      // Assert
      final finalState = container.read(authStateProvider);
      expect(finalState.isAuthenticated, false);
      expect(finalState.isLoading, false);
      expect(finalState.currentUser, null);
      expect(finalState.lastError, contains('Invalid credentials'));
    });

    test('should sign out user', () async {
      // Arrange
      when(mockAppwrite.signOut()).thenAnswer((_) async => {});
      
      final authNotifier = container.read(authStateProvider.notifier);

      // Act
      await authNotifier.signOut();

      // Assert
      final finalState = container.read(authStateProvider);
      expect(finalState.isAuthenticated, false);
      expect(finalState.currentUser, null);
    });

    test('should clear error', () {
      final authNotifier = container.read(authStateProvider.notifier);
      
      // Set an error state first
      authNotifier.state = authNotifier.state.copyWith(lastError: 'Some error');
      
      // Act
      authNotifier.clearError();

      // Assert
      final finalState = container.read(authStateProvider);
      expect(finalState.lastError, null);
    });
  });

  group('Network Status', () {
    test('should provide online status', () {
      // Test the connectivity provider with override
      final testContainer = ProviderContainer(
        overrides: [
          connectivityProvider.overrideWith((ref) => Stream.value(ConnectivityResult.wifi)),
        ],
      );
      addTearDown(testContainer.dispose);
      
      final isOnline = testContainer.read(isOnlineProvider);
      expect(isOnline, isA<bool>());
    });
  });
}