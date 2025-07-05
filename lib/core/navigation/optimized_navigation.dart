import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../screens/messages_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/premium_screen.dart';
import '../../screens/profile_screen.dart';
import '../../screens/login_screen.dart';
import '../../screens/arena_screen.dart';
import '../../features/navigation/providers/navigation_provider.dart';
import '../../services/challenge_messaging_service.dart';
import '../../services/sound_service.dart';
import '../../widgets/challenge_modal.dart';
import '../../widgets/arena_role_notification_modal.dart';
import '../../core/logging/app_logger.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/notifications/widgets/notification_banner.dart';
import 'package:get_it/get_it.dart';
import '../../services/theme_service.dart';

/// Optimized navigation using IndexedStack to preserve screen state
class OptimizedMainNavigator extends ConsumerStatefulWidget {
  const OptimizedMainNavigator({super.key});

  @override
  ConsumerState<OptimizedMainNavigator> createState() => _OptimizedMainNavigatorState();
}

class _OptimizedMainNavigatorState extends ConsumerState<OptimizedMainNavigator> with WidgetsBindingObserver {
  
  // Challenge system components
  late final ChallengeMessagingService _messagingService;
  late final SoundService _soundService;
  late final NotificationService _notificationService;
  final List<OverlayEntry> _arenaRoleOverlays = [];
  OverlayEntry? _challengeOverlay;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize services
    _messagingService = GetIt.instance<ChallengeMessagingService>();
    _soundService = GetIt.instance<SoundService>();
    _notificationService = GetIt.instance<NotificationService>();
    
    
    // Setup challenge listening after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationProvider.notifier).refreshAuth();
      _setupChallengeListening();
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


  List<Widget> _buildScreensBasedOnAuth() {
    final navState = ref.watch(navigationProvider);
    
    return [
      const _PersistentScreenWrapper(
        screenIndex: 0,
        child: MessagesScreen(),
      ),
      _PersistentScreenWrapper(
        screenIndex: 1,
        child: navState.isAuthenticated 
          ? const HomeScreen() 
          : LoginScreen(
              onLoginSuccess: () {
                AppLogger().debug('🔑 Login success callback triggered');
                ref.read(navigationProvider.notifier).refreshAuth();
              },
            ),
      ),
      const _PersistentScreenWrapper(
        screenIndex: 2,
        child: PremiumScreen(),
      ),
      _PersistentScreenWrapper(
        screenIndex: 3,
        child: navState.isAuthenticated 
          ? ProfileScreen(
              onLogout: _handleLogout,
            )
          : LoginScreen(
              onLoginSuccess: () {
                AppLogger().debug('🔑 Login success callback triggered');
                ref.read(navigationProvider.notifier).refreshAuth();
              },
            ),
      ),
    ];
  }

  Future<void> _handleLogout() async {
    // Clear any overlays
    _ensureBottomNavigationVisible();
    
    // Handle logout through provider
    await ref.read(navigationProvider.notifier).handleLogout();
  }

  void _setupChallengeListening() {
    AppLogger().debug('📱 Setting up optimized challenge listening...');
    
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
    
    // 🚀 CRITICAL: Listen for challenge updates (accepted challenges)
    _messagingService.challengeUpdates.listen((challenge) {
      AppLogger().debug('📱 Challenge update: ${challenge.status}');
      
      if (challenge.status == 'accepted' && challenge.arenaRoomId != null) {
        if (mounted) {
          // Navigate to arena room
          _navigateToArena(challenge.toModalFormat());
        }
      }
    });
    
    // Listen for declined challenge notifications (for challenger)
    _messagingService.challengeDeclined.listen((challenge) {
      AppLogger().debug('📱 💔 Challenge declined notification received for: ${challenge.topic}');
      
      // Play denied sound to notify the challenger their challenge was declined
      _soundService.playDeniedSound();
    });
    
    AppLogger().debug('📱 ✅ Optimized challenge listening setup complete');
  }

  void _navigateToArena(Map<String, dynamic> challenge) {
    AppLogger().debug('🏛️ Navigating to arena for challenge: ${challenge['id']}');
    
    // Remove any existing challenge overlay
    _challengeOverlay?.remove();
    _challengeOverlay = null;
    
    // Get the actual room ID from the challenge
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
      
      // Force refresh the widget
      if (mounted) {
        setState(() {});
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
    AppLogger().debug('🎭 Showing challenge modal for: ${challenge['id']}');
    
    // Remove existing overlay if any
    if (_challengeOverlay != null) {
      _challengeOverlay?.remove();
      _challengeOverlay = null;
    }
    
    _challengeOverlay = OverlayEntry(
      builder: (context) {
        return ChallengeModal(
          challenge: challenge,
          onDismiss: () {
            _challengeOverlay?.remove();
            _challengeOverlay = null;
          },
        );
      },
    );
    
    try {
      Overlay.of(context).insert(_challengeOverlay!);
      AppLogger().debug('🎭 ✅ Challenge modal inserted');
    } catch (e) {
      AppLogger().error('Error inserting challenge modal: $e');
    }
  }

  void _showArenaRoleModal(Map<String, dynamic> arenaNotification) {
    AppLogger().debug('🏛️ Showing arena role modal');
    
    // Calculate position based on existing overlays
    final overlayIndex = _arenaRoleOverlays.length;
    final topOffset = 100.0 + (overlayIndex * 180.0);
    
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
  }
  
  void _removeArenaRoleOverlay(OverlayEntry overlay) {
    try {
      overlay.remove();
      _arenaRoleOverlays.remove(overlay);
    } catch (e) {
      AppLogger().warning('Error removing arena role overlay: $e');
    }
  }

  void _ensureBottomNavigationVisible() {
    try {
      // Clear any stuck overlays
      if (_challengeOverlay != null) {
        _challengeOverlay?.remove();
        _challengeOverlay = null;
      }
      
      // Clear arena role overlays
      for (var overlay in _arenaRoleOverlays) {
        overlay.remove();
      }
      _arenaRoleOverlays.clear();
      
      // Refresh the widget state
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      AppLogger().warning('Error ensuring bottom navigation visibility: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentNavigationIndexProvider);
    
    // Build screens based on current authentication state
    final screens = _buildScreensBasedOnAuth();
    
    // Force clear any stuck overlays (safety mechanism)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureBottomNavigationVisible();
    });
    
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: screens,
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
      bottomNavigationBar: _buildOptimizedBottomNav(),
    );
  }

  Widget _buildOptimizedBottomNav() {
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
          // Instant navigation - no rebuild needed
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

/// Wrapper to maintain screen state and handle lifecycle
class _PersistentScreenWrapper extends StatefulWidget {
  final Widget child;
  final int screenIndex;

  const _PersistentScreenWrapper({
    required this.child,
    required this.screenIndex,
  });

  @override
  State<_PersistentScreenWrapper> createState() => _PersistentScreenWrapperState();
}

class _PersistentScreenWrapperState extends State<_PersistentScreenWrapper>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true; // Preserve state
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}