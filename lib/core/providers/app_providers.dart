import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../state/app_state.dart';
import '../logging/app_logger.dart';
import '../../services/appwrite_service.dart';
import '../../services/challenge_messaging_service.dart';
import '../../services/sound_service.dart';
import '../../models/user.dart';

/// Logger provider
final loggerProvider = Provider<AppLogger>((ref) {
  final logger = AppLogger();
  logger.initialize();
  return logger;
});

/// Connectivity provider
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Network status provider
final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) => results.isNotEmpty && !results.contains(ConnectivityResult.none),
    loading: () => true, // Assume online while loading
    error: (_, __) => false,
  );
});

/// Core services providers
final appwriteServiceProvider = Provider<AppwriteService>((ref) {
  return AppwriteService();
});

final challengeMessagingServiceProvider = Provider<ChallengeMessagingService>((ref) {
  return ChallengeMessagingService();
});

final soundServiceProvider = Provider<SoundService>((ref) {
  return SoundService();
});

/// Current user provider
final currentUserProvider = FutureProvider<User?>((ref) async {
  final appwrite = ref.read(appwriteServiceProvider);
  final logger = ref.read(loggerProvider);
  
  try {
    final user = await appwrite.getCurrentUser();
    if (user != null) {
      logger.info('User authenticated: ${user.email}');
      return User.fromAppwrite(user);
    }
    return null;
  } catch (e, stackTrace) {
    logger.error('Failed to get current user', e, stackTrace);
    return null;
  }
});

/// Authentication state provider
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AppState>((ref) {
  final logger = ref.read(loggerProvider);
  final appwrite = ref.read(appwriteServiceProvider);
  return AuthStateNotifier(logger, appwrite);
});

/// Authentication state notifier
class AuthStateNotifier extends StateNotifier<AppState> {
  AuthStateNotifier(this._logger, this._appwrite) : super(const AppState()) {
    _init();
  }

  final AppLogger _logger;
  final AppwriteService _appwrite;

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final user = await _appwrite.getCurrentUser();
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: user != null,
        currentUser: user != null ? User.fromAppwrite(user) : null,
      );
    } catch (e, stackTrace) {
      _logger.error('Authentication initialization failed', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        lastError: e.toString(),
      );
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, lastError: null);
    
    try {
      await _appwrite.signIn(email: email, password: password);
      final user = await _appwrite.getCurrentUser();
      
      if (user != null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          currentUser: User.fromAppwrite(user),
        );
        _logger.info('User signed in successfully: ${user.email}');
      }
    } catch (e, stackTrace) {
      _logger.error('Sign in failed', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        lastError: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    
    try {
      await _appwrite.signOut();
      state = const AppState();
      _logger.info('User signed out successfully');
    } catch (e, stackTrace) {
      _logger.error('Sign out failed', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        lastError: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(lastError: null);
  }
}