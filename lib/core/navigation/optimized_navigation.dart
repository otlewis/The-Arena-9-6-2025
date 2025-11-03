import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import '../../screens/email_inbox_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/premium_store_screen.dart';
import '../../screens/profile_screen.dart';
import '../../screens/login_screen.dart';
import '../../screens/arena_screen.dart';
import '../../screens/debates_discussions_screen.dart';
import '../../features/navigation/providers/navigation_provider.dart';
import '../../services/challenge_messaging_service.dart';
import '../../services/sound_service.dart';
import '../../services/appwrite_service.dart';
import '../../services/livekit_service.dart';
import '../../widgets/challenge_modal.dart';
import '../../widgets/arena_role_notification_modal.dart';
import '../../widgets/messaging_modal_system.dart';
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

  // Challenge system components - lazy getters to avoid accessing before ready
  ChallengeMessagingService get _messagingService => GetIt.instance<ChallengeMessagingService>();
  SoundService get _soundService => GetIt.instance<SoundService>();
  NotificationService get _notificationService => GetIt.instance<NotificationService>();
  AppwriteService get _appwriteService => GetIt.instance<AppwriteService>();
  LiveKitService get _liveKitService => GetIt.instance<LiveKitService>();

  final List<OverlayEntry> _arenaRoleOverlays = [];
  OverlayEntry? _challengeOverlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Setup challenge listening after first frame (when services are ready)
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
        child: EmailInboxScreen(),
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
        child: PremiumStoreScreen(),
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

  void _navigateToArena(Map<String, dynamic> challenge) async {
    AppLogger().debug('🏛️ Navigating to arena for challenge: ${challenge['id']}');

    // Remove any existing challenge overlay
    _challengeOverlay?.remove();
    _challengeOverlay = null;

    // Get the actual room ID from the challenge
    final roomId = challenge['arenaRoomId'] ?? 'arena_${challenge['id']}';

    // CHECK: Prevent moderators from accepting challenges while moderating a room
    try {
      final currentUser = await _appwriteService.getCurrentUser();
      if (currentUser != null) {
        // Check if user is currently moderating any debates_discussions rooms
        final moderatingRooms = await _appwriteService.databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'debate_discussion_rooms',
          queries: [
            Query.equal('moderatorId', currentUser.$id),
            Query.equal('status', 'active'),
            Query.limit(1),
          ],
        );

        if (moderatingRooms.documents.isNotEmpty) {
          // User is currently moderating a room - block navigation and show message
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.block, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Cannot Accept Challenge'),
                ],
              ),
              content: const Text(
                'You are currently moderating a Debates & Discussions room.\n\n'
                'Please end that room or assign another moderator before accepting arena challenges.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return; // Block navigation to arena
        }
      }
    } catch (e) {
      AppLogger().warning('⚠️ Error checking moderator status: $e');
      // Continue anyway - don't block the user if check fails
    }

    // CRITICAL: Disconnect from LiveKit BEFORE navigating to prevent audio issues
    // This ensures the user's microphone is disconnected from the debates_discussions room
    try {
      if (_liveKitService.isConnected) {
        AppLogger().info('🎤 Disconnecting microphone from debates_discussions room before arena navigation...');
        await _liveKitService.disconnect();
        AppLogger().info('✅ Microphone disconnected');
      }
    } catch (e) {
      AppLogger().warning('⚠️ Error disconnecting microphone: $e');
    }

    // CRITICAL FIX: Clean up Appwrite participants BEFORE navigating to arena
    // This prevents ghost presence (user appearing in both rooms)
    try {
      final currentUser = await _appwriteService.getCurrentUser();
      if (currentUser != null) {
        // Set flag to prevent "kicked from room" modal in debates_discussions_screen
        DebatesDiscussionsScreen.isNavigatingToArena = true;

        AppLogger().info('🧹 Cleaning up debate/discussion rooms BEFORE arena navigation...');
        await _appwriteService.exitAllDebateDiscussionRooms(userId: currentUser.$id);
        AppLogger().info('✅ Successfully cleaned up debate/discussion rooms');
      }
    } catch (e) {
      AppLogger().warning('⚠️ Error during cleanup before arena navigation: $e');
      // Reset flag on error
      DebatesDiscussionsScreen.isNavigatingToArena = false;
    }

    // Navigate to Arena
    if (!mounted) return;
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
    ).then((_) async {
      // Ensure bottom navigation is visible when returning from arena
      _ensureBottomNavigationVisible();

      // Force refresh the widget
      if (mounted) {
        setState(() {
          // Update UI after returning from arena to ensure proper navigation state
        });
      }
    });

    // Show notification that challenge was accepted
    if (!mounted) return;
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
        setState(() {
          // Update UI after clearing overlays and restoring bottom navigation
        });
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
    
    return MessagingModalSystem(
      child: Scaffold(
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
      ),
    );
  }

  Widget _buildOptimizedBottomNav() {
    final navState = ref.watch(navigationProvider);
    final themeService = ThemeService();
    
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeService.isDarkMode 
            ? const Color(0xFF2D2D2D)
            : const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          // Light shadow (top-left)
          BoxShadow(
            color: themeService.isDarkMode 
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.8),
            offset: const Offset(-8, -8),
            blurRadius: 16,
            spreadRadius: 0,
          ),
          // Dark shadow (bottom-right)
          BoxShadow(
            color: themeService.isDarkMode 
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.15),
            offset: const Offset(8, 8),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BottomNavigationBar(
        currentIndex: navState.currentIndex,
        onTap: (index) {
          // Navigate to the selected screen
          ref.read(navigationProvider.notifier).setCurrentIndex(index);
        },
        backgroundColor: Colors.transparent,
        selectedItemColor: themeService.isDarkMode 
            ? const Color(0xFF8B5CF6)
            : const Color(0xFF6B46C1),
        unselectedItemColor: themeService.isDarkMode 
            ? Colors.white54
            : Colors.black54,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: themeService.isDarkMode 
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFFF0F0F3),
                    shape: BoxShape.circle,
                    boxShadow: [
                      // Light shadow (top-left) - very subtle
                      BoxShadow(
                        color: themeService.isDarkMode 
                            ? Colors.white.withOpacity(0.03)
                            : Colors.white.withOpacity(0.7),
                        offset: const Offset(-6, -6),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                      // Dark shadow (bottom-right) - soft
                      BoxShadow(
                        color: themeService.isDarkMode 
                            ? Colors.black.withOpacity(0.5)
                            : const Color(0xFFA3B1C6).withOpacity(0.5),
                        offset: const Offset(6, 6),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.mail,
                      size: 28,
                      color: themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                if (context.unreadMessageCount > 0)
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
                        context.unreadMessageCount > 9 ? '9+' : context.unreadMessageCount.toString(),
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
            label: 'Inbox',
          ),
          BottomNavigationBarItem(
            icon: navState.isAuthenticated 
              ? Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: themeService.isDarkMode 
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFFF0F0F3),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: themeService.isDarkMode 
                            ? Colors.white.withOpacity(0.03)
                            : Colors.white.withOpacity(0.7),
                        offset: const Offset(-6, -6),
                        blurRadius: 12,
                      ),
                      BoxShadow(
                        color: themeService.isDarkMode 
                            ? Colors.black.withOpacity(0.5)
                            : const Color(0xFFA3B1C6).withOpacity(0.5),
                        offset: const Offset(6, 6),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.home_outlined,
                      size: 28,
                      color: navState.currentIndex == 1 
                          ? const Color(0xFF8B5CF6)
                          : (themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                )
              : const Icon(Icons.login),
            label: navState.isAuthenticated ? 'Home' : 'Login',
          ),
          BottomNavigationBarItem(
            icon: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: themeService.isDarkMode 
                    ? const Color(0xFF3A3A3A)
                    : const Color(0xFFF0F0F3),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: themeService.isDarkMode 
                        ? Colors.white.withOpacity(0.03)
                        : Colors.white.withOpacity(0.7),
                    offset: const Offset(-6, -6),
                    blurRadius: 12,
                  ),
                  BoxShadow(
                    color: themeService.isDarkMode 
                        ? Colors.black.withOpacity(0.5)
                        : const Color(0xFFA3B1C6).withOpacity(0.5),
                    offset: const Offset(6, 6),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.diamond_outlined,
                  size: 28,
                  color: navState.currentIndex == 2 
                      ? const Color(0xFF8B5CF6)
                      : (themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
            ),
            label: 'Premium',
          ),
          BottomNavigationBarItem(
            icon: navState.isAuthenticated 
              ? Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: themeService.isDarkMode 
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFFF0F0F3),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: themeService.isDarkMode 
                            ? Colors.white.withOpacity(0.03)
                            : Colors.white.withOpacity(0.7),
                        offset: const Offset(-6, -6),
                        blurRadius: 12,
                      ),
                      BoxShadow(
                        color: themeService.isDarkMode 
                            ? Colors.black.withOpacity(0.5)
                            : const Color(0xFFA3B1C6).withOpacity(0.5),
                        offset: const Offset(6, 6),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 28,
                      color: navState.currentIndex == 3 
                          ? const Color(0xFF8B5CF6)
                          : (themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                )
              : const Icon(Icons.login),
            label: navState.isAuthenticated ? 'Profile' : 'Login',
          ),
        ],
        ),
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