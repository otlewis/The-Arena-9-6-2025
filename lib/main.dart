import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'dart:ui';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/arena_screen.dart';
import 'services/appwrite_service.dart';
import 'services/challenge_messaging_service.dart';
import 'services/theme_service.dart';
import 'services/language_service.dart';
import 'services/accessibility_service.dart';
import 'services/sound_service.dart';
import 'widgets/challenge_modal.dart';
import 'widgets/arena_role_notification_modal.dart';
import 'features/navigation/providers/navigation_provider.dart';
import 'package:get_it/get_it.dart';
import 'core/logging/app_logger.dart';
import 'core/cache/cache_service.dart';
import 'core/error/app_error.dart';
import 'core/performance/performance_monitor.dart';
import 'utils/performance_monitor.dart' as utils;
import 'utils/mobile_performance_optimizer.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/notifications/notification_preferences.dart';
import 'core/notifications/widgets/notification_banner.dart';
import 'core/startup/app_startup_optimizer.dart';
import 'core/cache/smart_cache_manager.dart';
import 'core/navigation/optimized_navigation.dart';
import 'services/network_resilience_service.dart';
import 'core/performance/riverpod_performance_optimizer.dart';
import 'core/performance/virtualized_list_optimizer.dart';
import 'core/performance/network_performance_optimizer.dart';
import 'core/performance/code_splitting_service.dart';
import 'core/performance/widget_rebuild_optimizer.dart';
import 'services/offline_data_cache.dart';
import 'services/offline_conflict_resolver.dart';
import 'services/background_sync_service.dart';
import 'services/livekit_service.dart';
import 'services/speaking_detection_service.dart';
import 'services/persistent_audio_service.dart';
import 'services/audio_initialization_service.dart';
import 'services/room_audio_adapter.dart';
import 'widgets/network_quality_indicator.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'services/firebase_participant_sync_service.dart';
import 'services/super_moderator_service.dart';
import 'services/revenue_cat_service.dart';
import 'services/reputation_service.dart';
import 'services/moderator_reputation_service.dart';
import 'services/gamified_ranking_service.dart';

// Service locator instance
final getIt = GetIt.instance;

void setupServiceLocator() {
  // Register core services - use async singletons for heavy services
  getIt.registerLazySingleton<AppLogger>(() => AppLogger());
  getIt.registerLazySingleton<CacheService>(() => CacheService());
  getIt.registerLazySingleton<PerformanceMonitor>(() => PerformanceMonitor());
  
  // Use factory for services that might be recreated
  getIt.registerLazySingleton<ChallengeMessagingService>(() => ChallengeMessagingService());
  
  // Heavy services - initialize lazily
  getIt.registerLazySingletonAsync<AppwriteService>(() async {
    final service = AppwriteService();
    // Pre-warm any critical connections
    return service;
  });
  
  getIt.registerLazySingleton<SoundService>(() => SoundService());
  
  // Register notification services
  getIt.registerLazySingleton<NotificationService>(() => NotificationService());
  getIt.registerLazySingleton<PushNotificationService>(() => PushNotificationService());
  getIt.registerLazySingleton<NotificationPreferencesService>(() => NotificationPreferencesService());
  
  // Register optimization services
  getIt.registerLazySingleton<SmartCacheManager>(() => SmartCacheManager());
  getIt.registerLazySingleton<AppStartupOptimizer>(() => AppStartupOptimizer());
  
  // Register new performance optimization services
  getIt.registerLazySingleton<RiverpodPerformanceOptimizer>(() => RiverpodPerformanceOptimizer());
  getIt.registerLazySingleton<VirtualizedListOptimizer>(() => VirtualizedListOptimizer());
  getIt.registerLazySingleton<NetworkPerformanceOptimizer>(() => NetworkPerformanceOptimizer());
  getIt.registerLazySingleton<CodeSplittingService>(() => CodeSplittingService());
  getIt.registerLazySingleton<WidgetRebuildOptimizer>(() => WidgetRebuildOptimizer());
  
  // Register network resilience service
  getIt.registerLazySingleton<NetworkResilienceService>(() => NetworkResilienceService());
  
  // Register offline services
  getIt.registerLazySingleton<OfflineDataCache>(() => OfflineDataCache());
  getIt.registerLazySingleton<OfflineConflictResolver>(() => OfflineConflictResolver());
  getIt.registerLazySingleton<BackgroundSyncService>(() => BackgroundSyncService());
  
  // Register Firebase participant sync service
  getIt.registerLazySingleton<FirebaseParticipantSyncService>(() => FirebaseParticipantSyncService());
  
  // Register Super Moderator service
  getIt.registerLazySingleton<SuperModeratorService>(() => SuperModeratorService());
  
  // Register RevenueCat service
  getIt.registerLazySingleton<RevenueCatService>(() => RevenueCatService());
  
  // Register Reputation service
  getIt.registerLazySingleton<ReputationService>(() => ReputationService());
  
  // Register Moderator Reputation service
  getIt.registerLazySingleton<ModeratorReputationService>(() => ModeratorReputationService());
  
  // Register Gamified Ranking service
  getIt.registerLazySingleton<GamifiedRankingService>(() => GamifiedRankingService());
  
  // Register audio/video services
  getIt.registerLazySingleton<LiveKitService>(() => LiveKitService());
  getIt.registerLazySingleton<SpeakingDetectionService>(() => SpeakingDetectionService());
  
  // Register persistent audio service (singleton for app-wide usage)
  getIt.registerLazySingleton<PersistentAudioService>(() => PersistentAudioService());
  getIt.registerLazySingleton<AudioInitializationService>(() => AudioInitializationService());
  getIt.registerLazySingleton<RoomAudioAdapter>(() => RoomAudioAdapter());
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
    
    // Lock app to portrait orientation on all devices
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Initialize MCP Toolkit for Flutter development tools
    if (kDebugMode) {
      MCPToolkitBinding.instance
        ..initialize()
        ..initializeFlutterToolkit();
    }
    
    // Initialize core services first
    setupServiceLocator();
    final logger = getIt<AppLogger>();
    logger.initialize();
    
    // Start performance monitoring in debug mode
    if (kDebugMode) {
      utils.PerformanceMonitor.instance.startMonitoring();
      logger.info('🔍 Performance monitoring enabled');
    }
    
    // Initialize mobile performance optimizations
    await MobilePerformanceOptimizer.instance.initialize();
    logger.info('📱 Mobile performance optimizations initialized');
    
    // Initialize new performance optimization systems
    getIt<RiverpodPerformanceOptimizer>();
    getIt<NetworkPerformanceOptimizer>();
    getIt<CodeSplittingService>();
    getIt<WidgetRebuildOptimizer>();
    logger.info('🚀 Advanced performance optimizations initialized');
    
    // Initialize Super Moderator service
    try {
      await getIt<SuperModeratorService>().initialize();
      logger.info('🛡️ Super Moderator service initialized');
    } catch (e) {
      logger.error('Failed to initialize Super Moderator service: $e');
    }
    
    // Initialize RevenueCat service
    try {
      final revenueCatInitialized = await getIt<RevenueCatService>().initialize();
      if (revenueCatInitialized) {
        logger.info('🏪 RevenueCat service initialized');
      } else {
        logger.warning('⚠️ RevenueCat service failed to initialize');
      }
    } catch (e) {
      logger.error('Failed to initialize RevenueCat service: $e');
    }
    
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
      
      // Initialize Firebase participant sync service (temporarily disabled)
      // await getIt<FirebaseParticipantSyncService>().initialize();
      // logger.info('🔥 Firebase participant sync service initialized');
      
      // Initialize performance monitoring
      getIt<PerformanceMonitor>().initialize();
      
      // Initialize other services
      await ThemeService().initialize();
      await LanguageService().initialize();
      await AccessibilityService().initialize();
      await getIt<SoundService>().initialize();
      
      // Initialize notification preferences (load user settings)
      await getIt<NotificationPreferencesService>().loadPreferences();
      
      // Initialize network resilience service
      await getIt<NetworkResilienceService>().initialize();
      
      // Initialize offline services
      await getIt<OfflineDataCache>().initialize();
      await getIt<OfflineConflictResolver>().loadUnresolvedConflicts();
      await getIt<BackgroundSyncService>().initialize();
      
      // Initialize audio/video services
      getIt<SpeakingDetectionService>().initialize();
      logger.info('🗣️ Speaking detection service initialized');
      
      // Initialize persistent audio infrastructure early (non-blocking)
      _initializeAudioInfrastructure();
      
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
    // Handle MCP Toolkit errors
    if (kDebugMode) {
      MCPToolkitBinding.instance.handleZoneError(error, stack);
    }
    
    // Create a basic logger for zone errors if main logger fails
    if (kDebugMode) {
      AppLogger().debug('Zone error: $error');
      AppLogger().debug('Stack: $stack');
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

/// Initialize audio infrastructure early for instant room connections
void _initializeAudioInfrastructure() {
  Timer(const Duration(milliseconds: 100), () async {
    try {
      AppLogger().info('🎵 STARTUP: Initializing persistent audio infrastructure...');
      
      // Check network connectivity first
      final networkService = getIt<NetworkResilienceService>();
      if (!networkService.isOnline) {
        AppLogger().warning('⚠️ STARTUP: No internet connection - delaying audio initialization');
        // Schedule retry when network is available
        _scheduleAudioInitRetry();
        return;
      }
      
      // Wait for AppwriteService to be ready first (since we need user auth)
      await getIt.isReady<AppwriteService>();
      
      // Initialize audio service for authenticated users
      final audioInitService = getIt<AudioInitializationService>();
      await audioInitService.initializeForUser();
      
      AppLogger().info('✅ STARTUP: Persistent audio infrastructure ready - instant room connections enabled');
    } catch (e) {
      AppLogger().warning('⚠️ STARTUP: Audio infrastructure initialization failed (will retry on first room join): $e');
      // Schedule a retry in case it was a temporary network issue
      _scheduleAudioInitRetry();
    }
  });
}

/// Schedule audio initialization retry when network becomes available
void _scheduleAudioInitRetry() {
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    try {
      final networkService = getIt<NetworkResilienceService>();
      if (networkService.isOnline) {
        AppLogger().info('🔄 STARTUP: Network available - retrying audio initialization');
        timer.cancel();
        
        // Wait for services and retry audio init
        await getIt.isReady<AppwriteService>();
        final audioInitService = getIt<AudioInitializationService>();
        await audioInitService.initializeForUser();
        
        AppLogger().info('✅ STARTUP: Audio infrastructure initialized on retry');
      }
    } catch (e) {
      AppLogger().warning('⚠️ STARTUP: Audio retry failed: $e');
      // Continue retrying - timer will try again in 10 seconds
    }
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
      animation: Listenable.merge([ThemeService(), LanguageService()]),
      builder: (context, child) {
        final themeService = ThemeService();
        final languageService = LanguageService();
        return MaterialApp(
          title: 'Arena - Debate App',
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          locale: languageService.locale,
          supportedLocales: LanguageService.supportedLocales,
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
  
  // Arena role notification overlays
  final List<OverlayEntry> _arenaRoleOverlays = [];
  OverlayEntry? _challengeOverlay;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize services asynchronously to avoid blocking UI
    _initializeServicesAsync();
  }
  
  Future<void> _initializeServicesAsync() async {
    try {
      // Wait for heavy services if they're async
      await getIt.allReady();
      
      // Cleanup removed - we'll test the fix directly
      
      _messagingService = getIt<ChallengeMessagingService>();
      _soundService = getIt<SoundService>();
      _notificationService = getIt<NotificationService>();
      
      // Setup messaging after services are ready
      _setupMessageListening();
    } catch (e) {
      AppLogger().error('Error initializing services: $e');
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Trigger initial auth check after dependencies are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationProvider.notifier).refreshAuth();
    
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
    
    // Always notify persistent audio service of lifecycle changes
    try {
      if (getIt.isRegistered<PersistentAudioService>()) {
        getIt<PersistentAudioService>().onAppLifecycleChanged(state);
      }
    } catch (e) {
      AppLogger().warning('Failed to notify audio service of lifecycle change: $e');
    }
    
    if (state == AppLifecycleState.resumed) {
      AppLogger().debug('🔄 App resumed - refreshing services...');
      ref.read(navigationProvider.notifier).refreshMessaging();
    }
  }

  Future<void> _handleLogout() async {
    // Reset messaging service in service locator
    resetMessagingService();
    
    // Update local references to the new instances
    _messagingService = getIt<ChallengeMessagingService>();
    _notificationService = getIt<NotificationService>();
    
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

  void _navigateToArena(Map<String, dynamic> challenge) async {
    // Remove any existing challenge overlay
    _challengeOverlay?.remove();
    _challengeOverlay = null;
    
    // Get the actual room ID from the challenge (it should have arenaRoomId after acceptance)
    final roomId = challenge['arenaRoomId'] ?? 'arena_${challenge['id']}';
    
    AppLogger().info('🚀 CHALLENGE: Preparing to navigate to Arena room: $roomId');
    
    // Ensure persistent audio is ready before navigation
    try {
      final audioInitService = getIt<AudioInitializationService>();
      if (!audioInitService.isInitialized) {
        AppLogger().info('🚀 CHALLENGE: Waiting for persistent audio initialization...');
        await audioInitService.initializeForUser();
        // Give it a moment to fully establish connection
        await Future.delayed(const Duration(milliseconds: 500));
      }
      AppLogger().info('✅ CHALLENGE: Persistent audio ready, navigating to Arena');
    } catch (e) {
      AppLogger().warning('⚠️ CHALLENGE: Audio preparation failed, proceeding anyway: $e');
    }
    
    // Navigate to Arena
    if (mounted) {
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
    }
    
    // Show notification that challenge was accepted
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ ${challenge['challengedName'] ?? 'Opponent'} accepted your challenge!'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
          // Network quality banner (top)
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: const NetworkQualityBanner(),
          ),
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
        color: themeService.isDarkMode 
            ? const Color(0xFF2D2D2D)
            : const Color(0xFFE8E8E8),
        boxShadow: [
          BoxShadow(
            color: themeService.isDarkMode 
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white.withValues(alpha: 0.8),
            offset: const Offset(0, -4),
            blurRadius: 12,
          ),
          BoxShadow(
            color: themeService.isDarkMode 
                ? Colors.black.withValues(alpha: 0.6)
                : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: navState.currentIndex,
        onTap: (index) {
          ref.read(navigationProvider.notifier).setCurrentIndex(index);
        },
        backgroundColor: Colors.transparent,
        selectedItemColor: const Color(0xFF8B5CF6),
        unselectedItemColor: themeService.isDarkMode 
            ? Colors.white54
            : Colors.grey[600],
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: _buildNeumorphicNavIcon(
              Icons.mail,
              isSelected: navState.currentIndex == 0,
              themeService: themeService,
              badgeCount: 0, // TODO: Replace with unread email count
            ),
            label: 'Inbox', // Changed to ensure hot reload picks up changes
          ),
          BottomNavigationBarItem(
            icon: _buildNeumorphicNavIcon(
              navState.isAuthenticated ? Icons.home_rounded : Icons.login,
              isSelected: navState.currentIndex == 1,
              themeService: themeService,
            ),
            label: navState.isAuthenticated ? 'Home' : 'Login',
          ),
          BottomNavigationBarItem(
            icon: _buildNeumorphicNavIcon(
              Icons.workspace_premium_rounded,
              isSelected: navState.currentIndex == 2,
              themeService: themeService,
            ),
            label: 'Premium',
          ),
          BottomNavigationBarItem(
            icon: _buildNeumorphicNavIcon(
              navState.isAuthenticated ? Icons.person_rounded : Icons.login,
              isSelected: navState.currentIndex == 3,
              themeService: themeService,
            ),
            label: navState.isAuthenticated ? 'Profile' : 'Login',
          ),
        ],
      ),
    );
  }
  
  Widget _buildNeumorphicNavIcon(
    IconData iconData, {
    required bool isSelected,
    required ThemeService themeService,
    int? badgeCount,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        shape: BoxShape.circle,
        boxShadow: isSelected ? [
          BoxShadow(
            color: themeService.isDarkMode 
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.9),
            offset: const Offset(-3, -3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: themeService.isDarkMode 
                ? Colors.black.withValues(alpha: 0.6)
                : const Color(0xFFA3B1C6).withValues(alpha: 0.4),
            offset: const Offset(3, 3),
            blurRadius: 6,
          ),
        ] : [
          BoxShadow(
            color: themeService.isDarkMode 
                ? Colors.black.withValues(alpha: 0.4)
                : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
            offset: const Offset(2, 2),
            blurRadius: 4,
            spreadRadius: -1,
          ),
          BoxShadow(
            color: themeService.isDarkMode 
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.white.withValues(alpha: 0.7),
            offset: const Offset(-2, -2),
            blurRadius: 4,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            iconData,
            size: 24,
            color: isSelected 
                ? const Color(0xFF8B5CF6)
                : (themeService.isDarkMode ? Colors.white54 : Colors.grey[600]),
          ),
          if (badgeCount != null && badgeCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2400),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2400).withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
