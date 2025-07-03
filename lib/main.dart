import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/arena_screen.dart';
import 'services/appwrite_service.dart';
import 'services/challenge_messaging_service.dart';
import 'services/theme_service.dart';
import 'services/sound_service.dart';
import 'widgets/challenge_modal.dart';
import 'widgets/arena_role_notification_modal.dart';
import 'features/navigation/providers/navigation_provider.dart';
import 'package:get_it/get_it.dart';
import 'core/logging/app_logger.dart';
import 'core/cache/cache_service.dart';
import 'core/error/app_error.dart';
import 'core/performance/performance_monitor.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/notifications/notification_preferences.dart';
import 'core/notifications/widgets/notification_banner.dart';
import 'core/startup/app_startup_optimizer.dart';
import 'core/cache/smart_cache_manager.dart';
import 'core/agora/optimized_agora_service.dart';
import 'core/navigation/optimized_navigation.dart';

// Service locator instance
final getIt = GetIt.instance;

void setupServiceLocator() {
  // Register core services
  getIt.registerLazySingleton<AppLogger>(() => AppLogger());
  getIt.registerLazySingleton<CacheService>(() => CacheService());
  getIt.registerLazySingleton<PerformanceMonitor>(() => PerformanceMonitor());
  getIt.registerLazySingleton<ChallengeMessagingService>(() => ChallengeMessagingService());
  getIt.registerLazySingleton<AppwriteService>(() => AppwriteService());
  getIt.registerLazySingleton<SoundService>(() => SoundService());
  
  // Register notification services
  getIt.registerLazySingleton<NotificationService>(() => NotificationService());
  getIt.registerLazySingleton<PushNotificationService>(() => PushNotificationService());
  getIt.registerLazySingleton<NotificationPreferencesService>(() => NotificationPreferencesService());
  
  // Register optimization services
  getIt.registerLazySingleton<SmartCacheManager>(() => SmartCacheManager());
  getIt.registerLazySingleton<OptimizedAgoraService>(() => OptimizedAgoraService());
  getIt.registerLazySingleton<AppStartupOptimizer>(() => AppStartupOptimizer());
}

void resetMessagingService() {
  // Dispose and re-register the messaging service
  if (getIt.isRegistered<ChallengeMessagingService>()) {
    getIt.unregister<ChallengeMessagingService>();
  }
  getIt.registerLazySingleton<ChallengeMessagingService>(() => ChallengeMessagingService());
  
  // Reset notification services
  if (getIt.isRegistered<NotificationService>()) {
    getIt<NotificationService>().dispose();
    getIt.unregister<NotificationService>();
    getIt.registerLazySingleton<NotificationService>(() => NotificationService());
  }
  
  if (getIt.isRegistered<PushNotificationService>()) {
    getIt<PushNotificationService>().dispose();
    getIt.unregister<PushNotificationService>();
    getIt.registerLazySingleton<PushNotificationService>(() => PushNotificationService());
  }
}

void main() async {
  // Ensure Flutter bindings are initialized in the same zone as runApp
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize core services first
    setupServiceLocator();
    final logger = getIt<AppLogger>();
    logger.initialize();
    
    // Set up global error handling with proper logging
    FlutterError.onError = (FlutterErrorDetails details) {
      final error = ErrorHandler.handleError(details.exception, details.stack);
      logger.logError(error);
      
      // Don't crash in release mode for known issues
      if (!kDebugMode && details.exception.toString().contains('RealtimeResponse')) {
        return;
      }
      
      FlutterError.presentError(details);
    };

    try {
      // Initialize Firebase (with additional safety check)
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
          logger.info('Firebase initialized successfully');
        } catch (e) {
          if (e.toString().contains('duplicate-app')) {
            logger.warning('Firebase already initialized, continuing...');
          } else {
            rethrow;
          }
        }
      } else {
        logger.debug('Firebase already initialized, skipping...');
      }
      
      // Initialize cache service
      await getIt<CacheService>().initialize();
      
      // Initialize performance monitoring
      getIt<PerformanceMonitor>().initialize();
      
      // Initialize other services
      await ThemeService().initialize();
      await getIt<SoundService>().initialize();
      
      // Initialize notification preferences (load user settings)
      await getIt<NotificationPreferencesService>().loadPreferences();
      
      // Start app optimization in background (non-blocking)
      _startAppOptimization();
      
      // Setup platform error handling
      PlatformDispatcher.instance.onError = (error, stack) {
        final appError = ErrorHandler.handleError(error, stack);
        logger.logError(appError);
        
        // Handle known non-critical errors
        if (error.toString().contains('RealtimeResponse') || 
            error.toString().contains('type \'Null\' is not a subtype of type \'Map<dynamic, dynamic>\'')) {
          return true; // Mark as handled
        }
        
        return kDebugMode ? false : true; // Crash in debug, handle in release
      };

      runApp(
        const ProviderScope(
          child: ArenaApp(),
        ),
      );
    } catch (e, stackTrace) {
      final error = ErrorHandler.handleError(e, stackTrace);
      logger.logError(error);
      if (kDebugMode) rethrow;
    }
  }, (error, stack) {
    // Create a basic logger for zone errors if main logger fails
    if (kDebugMode) {
      print('Zone error: $error');
      print('Stack: $stack');
    }
    
    // Handle known issues gracefully
    if (error.toString().contains('RealtimeResponse') || 
        error.toString().contains('type \'Null\' is not a subtype of type \'Map<dynamic, dynamic>\'') ||
        error.toString().contains('LateInitializationError')) {
      return;
    }
    
    if (kDebugMode) throw error;
  });
}

/// Start app optimization in background (non-blocking)
void _startAppOptimization() {
  Timer(const Duration(milliseconds: 500), () async {
    try {
      final optimizer = getIt<AppStartupOptimizer>();
      await optimizer.optimizeStartup();
      AppLogger().info('🚀 App optimization completed');
    } catch (e) {
      AppLogger().warning('App optimization failed: $e');
    }
  });
}

class ArenaApp extends StatelessWidget {
  const ArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService(),
      builder: (context, child) {
        final themeService = ThemeService();
        return MaterialApp(
          title: 'Arena - Debate App',
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const OptimizedMainNavigator(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class MainNavigator extends ConsumerStatefulWidget {
  const MainNavigator({super.key});

  @override
  ConsumerState<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends ConsumerState<MainNavigator> with WidgetsBindingObserver {
  late final ChallengeMessagingService _messagingService;
  late final SoundService _soundService;
  late final NotificationService _notificationService;
  late final PushNotificationService _pushNotificationService;
  
  // Arena role notification overlays
  final List<OverlayEntry> _arenaRoleOverlays = [];
  OverlayEntry? _challengeOverlay;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize services
    _messagingService = getIt<ChallengeMessagingService>();
    _soundService = getIt<SoundService>();
    _notificationService = getIt<NotificationService>();
    _pushNotificationService = getIt<PushNotificationService>();
    
    // Trigger initial auth check and setup messaging
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationProvider.notifier).refreshAuth();
      _setupMessageListening();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Clean up overlays
    try {
      _challengeOverlay?.remove();
      for (var overlay in _arenaRoleOverlays) {
        overlay.remove();
      }
      _arenaRoleOverlays.clear();
    } catch (e) {
      AppLogger().warning('Error clearing overlays: $e');
    }
    
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      AppLogger().debug('🔄 App resumed - refreshing messaging service...');
      ref.read(navigationProvider.notifier).refreshMessaging();
    }
  }

  Future<void> _handleLogout() async {
    // Reset messaging service in service locator
    resetMessagingService();
    
    // Update local references to the new instances
    _messagingService = getIt<ChallengeMessagingService>();
    _notificationService = getIt<NotificationService>();
    _pushNotificationService = getIt<PushNotificationService>();
    
    // Clear any overlays
    _ensureBottomNavigationVisible();
    
    // Handle logout through provider
    await ref.read(navigationProvider.notifier).handleLogout();
  }

  void _setupMessageListening() {
    AppLogger().debug('📱 Setting up UI message stream listening...');
    
    // Listen for incoming challenges (triggers challenge modal)
    _messagingService.incomingChallenges.listen((challenge) {
      AppLogger().debug('📱 🔔 Incoming challenge from ${challenge.challengerName}: ${challenge.topic}');
      
      // Play challenge sound
      _soundService.playChallengeSound();
      
      if (mounted) {
        _showChallengeModal(challenge.toModalFormat());
      }
    });
    
    // Listen for arena role invitations (triggers arena role modal)
    _messagingService.arenaRoleInvitations.listen((invitation) {
      AppLogger().debug('📱 🏛️ Incoming arena role invitation: ${invitation.position} for ${invitation.topic}');
      
      if (mounted) {
        _showArenaRoleModal(invitation.toModalFormat());
      }
    });
    
    // Listen for challenge updates (accepted challenges)
    _messagingService.challengeUpdates.listen((challenge) {
      AppLogger().debug('📱 Challenge update: ${challenge.status}');
      
      if (challenge.status == 'accepted' && challenge.arenaRoomId != null) {
        if (mounted) {
          // Navigate to arena room
          _navigateToArena(challenge.toModalFormat());
        }
      }
    });
    
    AppLogger().debug('📱 ✅ UI message stream listening setup complete');
  }

  void _navigateToArena(Map<String, dynamic> challenge) {
    // Remove any existing challenge overlay
    _challengeOverlay?.remove();
    _challengeOverlay = null;
    
    // Get the actual room ID from the challenge (it should have arenaRoomId after acceptance)
    final roomId = challenge['arenaRoomId'] ?? 'arena_${challenge['id']}';
    
    // Navigate to Arena
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ArenaScreen(
          roomId: roomId,
          challengeId: challenge['id'],
          topic: challenge['topic'] ?? 'Debate Topic',
          description: challenge['description'],
          category: challenge['category'],
          challengerId: challenge['challengerId'],
          challengedId: challenge['challengedId'],
        ),
      ),
    ).then((_) {
      // When user returns from arena, ensure bottom navigation is visible
      _ensureBottomNavigationVisible();
      
      // Additional safety: force refresh the entire widget
      if (mounted) {
        setState(() {
          // This will trigger a full rebuild including bottom navigation
        });
      }
    });
    
    // Show notification that challenge was accepted
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚡ ${challenge['challengedName'] ?? 'Opponent'} accepted your challenge!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showChallengeModal(Map<String, dynamic> challenge) {
    AppLogger().debug('_showChallengeModal called with challenge: ${challenge['id']}');
    
    // Remove existing overlay if any
    if (_challengeOverlay != null) {
      AppLogger().debug('🎭 Removing existing challenge overlay');
      _challengeOverlay?.remove();
      _challengeOverlay = null;
    }
    
    AppLogger().debug('🎭 Creating new challenge overlay entry');
    _challengeOverlay = OverlayEntry(
      builder: (context) {
        AppLogger().debug('🎭 Building ChallengeModal widget');
        return ChallengeModal(
          challenge: challenge,
          onDismiss: () {
            AppLogger().debug('🎭 Challenge modal dismissed');
            _challengeOverlay?.remove();
            _challengeOverlay = null;
          },
        );
      },
    );
    
    AppLogger().debug('🎭 Inserting challenge overlay into widget tree');
    try {
      Overlay.of(context).insert(_challengeOverlay!);
      AppLogger().debug('🎭 ✅ Challenge modal successfully inserted into overlay');
    } catch (e) {
      AppLogger().error('Error inserting challenge modal: $e');
    }
  }

  void _showArenaRoleModal(Map<String, dynamic> arenaNotification) {
    AppLogger().info('_showArenaRoleModal called!');
    AppLogger().info('Arena notification data: $arenaNotification');
    
    // Calculate position based on existing overlays
    final overlayIndex = _arenaRoleOverlays.length;
    final topOffset = 100.0 + (overlayIndex * 180.0); // Stack them 180px apart
    
    // Declare overlay as late to avoid forward reference
    late OverlayEntry overlay;
    
    overlay = OverlayEntry(
      builder: (context) => Positioned(
        top: topOffset,
        left: 20,
        right: 20,
        child: ArenaRoleNotificationModal(
          notification: arenaNotification,
          onDismiss: () {
            _removeArenaRoleOverlay(overlay);
          },
        ),
      ),
    );
    
    _arenaRoleOverlays.add(overlay);
    Overlay.of(context).insert(overlay);
    AppLogger().info('Arena role modal overlay inserted at position $overlayIndex (top: $topOffset)');
  }
  
  void _removeArenaRoleOverlay(OverlayEntry overlay) {
    try {
      overlay.remove();
      _arenaRoleOverlays.remove(overlay);
      AppLogger().info('Arena role overlay removed');
    } catch (e) {
      AppLogger().warning('Error removing arena role overlay: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force clear any stuck overlays (safety mechanism)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureBottomNavigationVisible();
    });
    
    final navState = ref.watch(navigationProvider);
    final navNotifier = ref.read(navigationProvider.notifier);
    final screens = navNotifier.getScreens(
      onLoginSuccess: () {
        AppLogger().debug('🔑 Login success callback triggered');
        ref.read(navigationProvider.notifier).refreshAuth();
      },
      onLogout: _handleLogout,
    );
    
    return Scaffold(
      body: Stack(
        children: [
          screens[navState.currentIndex],
          // Banner notifications overlay
          NotificationBannerOverlay(
            notificationStream: _notificationService.bannerNotifications,
            onNotificationTap: (notification) {
              _notificationService.markAsRead(notification.id);
              // Handle deep linking if needed
              if (notification.deepLink != null) {
                // TODO: Implement deep link navigation
              }
            },
            onNotificationDismiss: (notification) {
              _notificationService.markAsDismissed(notification.id);
            },
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
  
  void _ensureBottomNavigationVisible() {
    try {
      // Clear any stuck overlays that might be hiding the bottom navigation
      if (_challengeOverlay != null) {
        AppLogger().warning('Clearing stuck challenge overlay');
        _challengeOverlay?.remove();
        _challengeOverlay = null;
      }
      
      // Clear arena role overlays if any
      for (var overlay in _arenaRoleOverlays) {
        overlay.remove();
      }
      _arenaRoleOverlays.clear();
      
      // Refresh the widget state to ensure bottom navigation is visible
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      AppLogger().warning('Error ensuring bottom navigation visibility: $e');
    }
  }

  Widget _buildBottomNavigationBar() {
    final navState = ref.watch(navigationProvider);
    final themeService = ThemeService();
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: themeService.isDarkMode 
              ? [
                  const Color(0xFF6B46C1).withValues(alpha: 0.9), // Purple in dark mode
                  const Color(0xFF8B5CF6).withValues(alpha: 0.9),
                ]
              : [
                  const Color(0xFFFF2400), // Pure scarlet in light mode
                  const Color(0xFFDC2626), // Darker scarlet
                ],
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: navState.currentIndex,
        onTap: (index) {
          ref.read(navigationProvider.notifier).setCurrentIndex(index);
        },
        backgroundColor: Colors.transparent,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white60,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.message),
                if (navState.pendingChallengeCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2400),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        navState.pendingChallengeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(navState.isAuthenticated ? Icons.home : Icons.login),
            label: navState.isAuthenticated ? 'Home' : 'Login',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.diamond),
            label: 'Premium',
          ),
          BottomNavigationBarItem(
            icon: Icon(navState.isAuthenticated ? Icons.person : Icons.login),
            label: navState.isAuthenticated ? 'Profile' : 'Login',
          ),
        ],
      ),
    );
  }
}
