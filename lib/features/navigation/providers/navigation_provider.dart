import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../../services/appwrite_service.dart';
import '../../../services/challenge_messaging_service.dart';
import '../../../services/sound_service.dart';
import '../../../services/audio_initialization_service.dart';
import '../../../services/gift_service.dart';
import '../../../core/logging/app_logger.dart';
import 'package:get_it/get_it.dart';
import '../../../core/providers/app_providers.dart';
import '../../../screens/home_screen.dart';
import '../../../screens/login_screen.dart';
import '../../../screens/profile_screen.dart';
import '../../../screens/email_inbox_screen.dart';
import '../../../screens/premium_store_screen.dart';

/// Navigation state
class NavigationState {
  final int currentIndex;
  final bool isAuthenticated;
  final int pendingChallengeCount;
  final bool isLoading;
  final String? error;

  const NavigationState({
    this.currentIndex = 1, // Default to Account tab
    this.isAuthenticated = false,
    this.pendingChallengeCount = 0,
    this.isLoading = false,
    this.error,
  });

  NavigationState copyWith({
    int? currentIndex,
    bool? isAuthenticated,
    int? pendingChallengeCount,
    bool? isLoading,
    String? error,
  }) {
    return NavigationState(
      currentIndex: currentIndex ?? this.currentIndex,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      pendingChallengeCount: pendingChallengeCount ?? this.pendingChallengeCount,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Navigation state notifier
class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier(this._appwrite, this._logger, this._messagingService, this._soundService)
      : super(const NavigationState()) {
    _checkAuthStatus();
  }

  final AppwriteService _appwrite;
  final AppLogger _logger;
  final ChallengeMessagingService _messagingService;
  final SoundService _soundService;
  
  Key _profileKey = UniqueKey(); // To force ProfileScreen refresh
  List<Widget>? _cachedScreens;
  // ignore: unused_field
  bool _screensCacheValid = false;

  Key get profileKey => _profileKey;

  List<Widget> getScreens({
    required VoidCallback onLoginSuccess,
    required VoidCallback onLogout,
  }) {
    // Force rebuild screens to ensure navigation changes take effect
    // if (_screensCacheValid && _cachedScreens != null) {
    //   return _cachedScreens!;
    // }

    _logger.debug('🔍 Building screens - isAuthenticated: ${state.isAuthenticated}, currentIndex: ${state.currentIndex}');
    _cachedScreens = [
      const EmailInboxScreen(),
      state.isAuthenticated ? const HomeScreen() : LoginScreen(
        onLoginSuccess: onLoginSuccess,
      ),
      const PremiumStoreScreen(),
      state.isAuthenticated ? ProfileScreen(
        key: _profileKey,
        onLogout: onLogout,
      ) : LoginScreen(
        onLoginSuccess: onLoginSuccess,
      ),
    ];
    _screensCacheValid = true;
    return _cachedScreens!;
  }

  void invalidateScreensCache() {
    _screensCacheValid = false;
    _cachedScreens = null;
  }

  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    
    _logger.debug('🔍 Checking authentication status...');
    final user = await _appwrite.getCurrentUser();
    _logger.debug('Current user: ${user != null ? user.email : 'null'}');

    state = state.copyWith(
      isAuthenticated: user != null,
      isLoading: false,
      currentIndex: 1, // Always set to Account tab
    );

    invalidateScreensCache(); // Invalidate cache when auth state changes

    if (user != null) {
      _logger.debug('🔍 User authenticated - staying on Account tab (HomeScreen)');
      await _messagingService.initialize(user.$id);
      _setupMessageListening();
      
      // Initialize gift service for authenticated user
      try {
        await GiftService().initialize(user.$id);
        _logger.debug('🎁 GiftService initialized successfully');
      } catch (e) {
        _logger.warning('Failed to initialize gift service: $e');
        // Don't block authentication for gift service issues
      }
      
      // Initialize persistent audio service for authenticated user
      try {
        final audioInitService = GetIt.instance<AudioInitializationService>();
        await audioInitService.initializeForUser();
      } catch (e) {
        _logger.warning('Failed to initialize audio service: $e');
        // Don't block authentication for audio issues
      }
    } else {
      _logger.debug('🔍 User not authenticated - staying on Account tab (LoginScreen)');
    }
  }

  Future<void> handleLogout() async {
    _logger.debug('🔄 Handling logout - clearing auth state');

    // Clean up messaging service
    _messagingService.dispose();
    
    // Clean up audio service
    try {
      final audioInitService = GetIt.instance<AudioInitializationService>();
      await audioInitService.dispose();
    } catch (e) {
      _logger.warning('Failed to dispose audio service: $e');
    }

    // Update local state - navigate to login tab
    state = state.copyWith(
      isAuthenticated: false,
      currentIndex: 1, // Always navigate to tab 1 (Home/Login tab) after logout
      pendingChallengeCount: 0,
    );

    invalidateScreensCache(); // Invalidate cache when auth state changes
    _profileKey = UniqueKey(); // Force ProfileScreen refresh

    _logger.info('✅ Logout completed - user navigated to login screen');
    _logger.info('Current state: authenticated=${state.isAuthenticated}, tab=${state.currentIndex}');
  }

  void _setupMessageListening() {
    _logger.debug('📱 Setting up message stream listening...');

    // Listen for incoming challenges (triggers challenge modal)
    _messagingService.incomingChallenges.listen((challenge) {
      _logger.debug('📱 🔔 Incoming challenge from ${challenge.challengerName}: ${challenge.topic}');
      
      // Play challenge sound
      _soundService.playChallengeSound();
      
      // Note: Challenge modal handling should be done at the widget level
      // This provider just manages the state
    });

    // Listen for arena role invitations
    _messagingService.arenaRoleInvitations.listen((invitation) {
      _logger.debug('📱 🏛️ Incoming arena role invitation: ${invitation.position} for ${invitation.topic}');
      
      // Note: Arena role modal handling should be done at the widget level
    });

    // Listen for challenge updates (accepted challenges)
    _messagingService.challengeUpdates.listen((challenge) {
      _logger.debug('📱 Challenge update: ${challenge.status}');
      
      // Note: Navigation handling should be done at the widget level
    });

    // Listen for pending challenge count changes (for badge)
    _messagingService.pendingChallenges.listen((challenges) {
      final count = challenges.where((c) => c.isPending && !c.isDismissed).length;
      state = state.copyWith(pendingChallengeCount: count);
    });

    _logger.debug('📱 ✅ Message stream listening setup complete');
  }

  void setCurrentIndex(int index) {
    state = state.copyWith(currentIndex: index);
  }

  void refreshMessaging() {
    if (state.isAuthenticated) {
      _logger.debug('🔄 App resumed - refreshing messaging service...');
      _messagingService.refresh();
    }
  }

  Future<void> refreshAuth() async {
    await _checkAuthStatus();
  }
}

/// Navigation provider
final navigationProvider = StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  final appwrite = ref.read(appwriteServiceProvider);
  final logger = ref.read(loggerProvider);
  final messagingService = ref.read(challengeMessagingServiceProvider);
  final soundService = ref.read(soundServiceProvider);
  return NavigationNotifier(appwrite, logger, messagingService, soundService);
});

/// Convenience providers for easier access
final currentNavigationIndexProvider = Provider<int>((ref) {
  return ref.watch(navigationProvider).currentIndex;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(navigationProvider).isAuthenticated;
});

final pendingChallengeCountProvider = Provider<int>((ref) {
  return ref.watch(navigationProvider).pendingChallengeCount;
});

final isNavigationLoadingProvider = Provider<bool>((ref) {
  return ref.watch(navigationProvider).isLoading;
});