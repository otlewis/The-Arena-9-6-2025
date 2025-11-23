import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/debate_clubs_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/slide_library_screen.dart';
// import 'create_open_screen.dart'; // Disabled
import '../models/user_profile.dart';
import '../screens/arena_lobby_screen.dart';
import '../screens/find_users_screen.dart';
import 'discussions_room_list_screen.dart';
import 'moderator_list_screen.dart';
import 'judge_list_screen.dart';
import 'moderator_agreement_screen.dart';
import 'judge_agreement_screen.dart';
import '../services/appwrite_service.dart';
import '../services/challenge_messaging_service.dart';
import '../services/theme_service.dart';
import '../services/sound_service.dart';
import '../services/user_presence_service.dart';
import '../constants/appwrite.dart';
import 'package:appwrite/appwrite.dart';
import '../widgets/arena_role_notification_modal.dart';
import '../widgets/animated_fade_in.dart';
import '../widgets/challenge_bell.dart';
import '../widgets/audio_status_indicator.dart';
import 'package:get_it/get_it.dart';
import '../core/logging/app_logger.dart';
import '../widgets/ping_notification_modal.dart';
import '../widgets/room_invitation_bell.dart';
import '../widgets/room_invitation_modal.dart';
import '../models/moderator_judge.dart';
import 'super_mod_dashboard.dart';
import '../services/super_moderator_service.dart';
import '../services/gamified_ranking_service.dart';
import '../services/ranking_sync_service.dart';
import 'rankings_screen.dart';
import 'onboarding_screen.dart';
import '../widgets/help_modal.dart';
import '../config/help_content.dart';
import '../services/crm_analytics_service.dart';
// All test screen imports removed - files deleted

class HomeScreen extends StatefulWidget {
  final bool showFeatureHighlights;

  const HomeScreen({
    super.key,
    this.showFeatureHighlights = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final AppwriteService _appwrite = AppwriteService();
  final ThemeService _themeService = ThemeService();
  final SoundService _soundService = SoundService();
  final UserPresenceService _presenceService = UserPresenceService();
  late final ChallengeMessagingService _messagingService;
  final GamifiedRankingService _rankingService = GetIt.instance<GamifiedRankingService>();
  final RankingSyncService _syncService = RankingSyncService();
  final CRMAnalyticsService _analytics = CRMAnalyticsService();
  UserProfile? _currentUserProfile;
  Map<String, dynamic>? _userRankingData;
  int _arenaRoleInvitations = 0;
  bool _isLoading = true;
  RealtimeSubscription? _pingSubscription;
  RealtimeSubscription? _roomInvitationSubscription;
  Timer? _roleCheckTimer;
  bool _isCurrentUserModerator = false;
  bool _isCurrentUserJudge = false;
  OverlayEntry? _currentInvitationOverlay;
  bool _showOnboarding = false;
  StreamSubscription? _arenaRoleInvitationSubscription;
  StreamSubscription? _challengeDeclinedSubscription;
  StreamSubscription? _roomInvitationStreamSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messagingService = GetIt.instance<ChallengeMessagingService>();
    _syncService.initialize();
    _loadCurrentUserProfile();
    _setupArenaRoleInvitationListener();
    _setupChallengeDeclinedListener();
    _setupPingRequestListener();
    _setupRoomInvitationListener();
    _checkUserRoles();
    _checkAndShowWelcomeHelp();

    // Periodic role check for debugging (every 30 seconds)
    _roleCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        AppLogger().debug('⏰ Periodic role check triggered');
        _checkUserRoles();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _roleCheckTimer?.cancel();
    _presenceService.stopTracking();
    WidgetsBinding.instance.removeObserver(this);
    _pingSubscription?.close();
    _roomInvitationSubscription?.close();
    _arenaRoleInvitationSubscription?.cancel();
    _challengeDeclinedSubscription?.cancel();
    _roomInvitationStreamSubscription?.cancel();
    _currentInvitationOverlay?.remove();
    _currentInvitationOverlay = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      AppLogger().debug('📱 App resumed - checking user roles');
      _checkUserRoles();
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    try {
      final currentUser = await _appwrite.getCurrentUser();
      if (currentUser != null) {
        final profile = await _appwrite.getUserProfile(currentUser.$id);
        
        // Load user ranking data from the proper ranking system
        Map<String, dynamic>? rankingData;
        try {
          AppLogger().info('🎯 Loading ranking data for user: ${currentUser.$id}');
          rankingData = await _rankingService.getUserCurrentStats(currentUser.$id);
          
        } catch (e) {
          AppLogger().debug('Error loading user ranking data: $e');
        }
        
        if (mounted) {
          setState(() {
            _currentUserProfile = profile;
            _userRankingData = rankingData;
            _isLoading = false;
          });
          // Check roles after profile is loaded
          _checkUserRoles();

          // Start tracking user presence for online status
          _presenceService.startTracking(currentUser.$id);

          // Track app opened event (staff only - automatically filtered)
          _analytics.trackFunnelEvent(
            eventName: 'app_opened',
            userEmail: profile?.email,
            userId: currentUser.$id,
            eventData: {
              'hasProfile': profile != null,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      AppLogger().debug('Error loading current user profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupArenaRoleInvitationListener() {
    _arenaRoleInvitationSubscription = _messagingService.arenaRoleInvitations.listen((invitation) {
      if (mounted) {
        setState(() {
          _arenaRoleInvitations++;
        });

        // Show arena role notification modal
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ArenaRoleNotificationModal(
            notification: invitation.toModalFormat(),
            onDismiss: () {
              Navigator.of(context).pop();
              setState(() {
                _arenaRoleInvitations = (_arenaRoleInvitations - 1).clamp(0, 999);
              });
            },
          ),
        );
      }
    });
  }

  void _setupChallengeDeclinedListener() {
    _challengeDeclinedSubscription = _messagingService.challengeDeclined.listen((challenge) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${challenge.challengerName} declined your challenge'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _setupPingRequestListener() async {
    final currentUser = await _appwrite.getCurrentUser();
    if (currentUser == null) return;

    _pingSubscription = _appwrite.subscribeToPingRequests(
      currentUser.$id,
      (RealtimeMessage message) {
        if (mounted && message.events.contains('databases.*.collections.*.documents.*.create')) {
          _handlePingRequest(message.payload);
        }
      },
    );
  }

  void _handlePingRequest(Map<String, dynamic> data) {
    try {
      final pingRequest = PingRequest.fromJson(data);

      AppLogger().info('Received ping request: ${pingRequest.id}');

      // Show the ping notification modal
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => PingNotificationModal(
            pingRequest: pingRequest,
            onDismiss: () {
              Navigator.of(context).pop();
            },
          ),
        );
      }
    } catch (e) {
      AppLogger().error('Error handling ping request: $e');
    }
  }

  void _setupRoomInvitationListener() async {
    final currentUser = await _appwrite.getCurrentUser();
    if (currentUser == null) return;

    try {
      final realtime = _appwrite.realtime;

      _roomInvitationSubscription = realtime.subscribe([
        'databases.arena_db.collections.room_invitations.documents'
      ]);

      _roomInvitationStreamSubscription = _roomInvitationSubscription!.stream.listen((response) {
        if (!mounted) return;

        final payload = response.payload;

        // Check if this invitation is for current user and is new
        if (payload['inviteeId'] == currentUser.$id &&
            payload['status'] == 'pending' &&
            response.events.contains('databases.*.collections.*.documents.*.create')) {

          AppLogger().info('📨 New room invitation received!');

          // Show auto-popup modal
          _showRoomInvitationModal(payload);
        }
      });

      AppLogger().info('📨 Subscribed to room invitations for user ${currentUser.$id}');
    } catch (e) {
      AppLogger().error('Failed to subscribe to room invitations: $e');
    }
  }

  void _showRoomInvitationModal(Map<String, dynamic> invitation) {
    if (!mounted) return;

    // Play ping sound
    _soundService.playPing();

    // Remove any existing overlay
    _currentInvitationOverlay?.remove();
    _currentInvitationOverlay = null;

    // Create overlay entry
    _currentInvitationOverlay = OverlayEntry(
      builder: (context) => RoomInvitationModal(
        invitation: invitation,
        onDismiss: () {
          _currentInvitationOverlay?.remove();
          _currentInvitationOverlay = null;
        },
      ),
    );

    // Insert overlay
    Overlay.of(context).insert(_currentInvitationOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Stack(
      children: [
        // Background color based on theme
        Container(
          color: _themeService.isDarkMode
              ? const Color(0xFF1A1A1A)  // Dark background
              : const Color(0xFFE8E4F3),  // Light purple/lavender background
        ),
        // Content
        Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildFeatureGrid(),
                        const SizedBox(height: 24),
                        _buildModeratorJudgeSection(),
                        const SizedBox(height: 24),
                        _buildBecomeSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            floatingActionButton: _buildFloatingActionButton(),
          ),
        if (_showOnboarding)
          OnboardingScreen(
            onComplete: () {
              setState(() {
                _showOnboarding = false;
              });
            },
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
        color: Colors.transparent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(
            children: [
              // Top row with greeting and icons
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 100),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF2400),  // Scarlet color
                            ),
                          ),
                          Text(
                            _currentUserProfile?.name ?? 'User',  // Removed @
                            style: const TextStyle(
                              fontSize: 16,  // Enlarged from 12
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8B5CF6),  // Purple color
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AnimatedScaleIn(
                      delay: const Duration(milliseconds: 375),
                      child: Container(
                        width: 36, // Reduced from 44
                        height: 36, // Reduced from 44
                        decoration: BoxDecoration(
                          color: _themeService.isDarkMode 
                              ? const Color(0xFF3A3A3A)
                              : const Color(0xFFF0F0F3),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _themeService.isDarkMode 
                                  ? Colors.white.withOpacity(0.03)
                                  : Colors.white.withOpacity(0.7),
                              offset: const Offset(-4, -4),
                              blurRadius: 8,
                            ),
                            BoxShadow(
                              color: _themeService.isDarkMode 
                                  ? Colors.black.withOpacity(0.5)
                                  : const Color(0xFFA3B1C6).withOpacity(0.5),
                              offset: const Offset(4, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: AudioStatusIndicator(
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4), // Reduced from 8
                    AnimatedScaleIn(
                      delay: const Duration(milliseconds: 375),
                      child: _buildHeaderIcon(
                        Icons.help_outline,
                        () {
                          showDialog(
                            context: context,
                            builder: (context) => HelpModal(
                              title: 'Home Screen Guide',
                              items: HelpContent.homeScreen(),
                              accentColor: const Color(0xFF8B5CF6),
                            ),
                          );
                        },
                        iconColor: const Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(width: 4), // Reduced from 8
                    AnimatedScaleIn(
                      delay: const Duration(milliseconds: 400),
                      child: _buildHeaderIcon(
                        _themeService.isDarkMode ? LucideIcons.sun : LucideIcons.moon,
                        () {
                          _themeService.toggleTheme();
                          setState(() {
                            // Update UI to reflect theme change
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 4), // Reduced from 8
                    AnimatedScaleIn(
                      delay: const Duration(milliseconds: 500),
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                        ),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6),  // Purple background
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),  // Purple glow
                                blurRadius: 15,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _currentUserProfile?.avatar != null
                                ? Image.network(
                                    _currentUserProfile!.avatar!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildProfileInitials(),
                                  )
                                : _buildProfileInitials(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Welcome card with neumorphism design
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 600),
                child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _themeService.isDarkMode
                            ? const Color(0xFF2D2D2D)  // Dark card
                            : const Color(0xFFE8E4F3),  // Light purple
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: _themeService.isDarkMode
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  offset: const Offset(-8, -8),
                                  blurRadius: 16,
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  offset: const Offset(8, 8),
                                  blurRadius: 16,
                                ),
                              ]
                            : [
                                // Light mode neumorphic shadows
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.8),  // Light shadow (white highlight)
                                  offset: const Offset(-8, -8),
                                  blurRadius: 16,
                                ),
                                BoxShadow(
                                  color: const Color(0xFFC8C0DC).withValues(alpha: 0.5),  // Dark shadow (darker purple)
                                  offset: const Offset(8, 8),
                                  blurRadius: 16,
                                ),
                              ],
                      ),
                      child: Column(
                        children: [
                          // Modern Arena logo with gradient background
                          AnimatedScaleIn(
                            delay: const Duration(milliseconds: 800),
                            curve: Curves.elasticOut,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6B46C1), // Purple
                                    Color(0xFF8B5CF6), // Lighter purple
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6B46C1).withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 75,
                                    height: 75,
                                    color: Colors.white,
                                    child: Image.asset(
                                      'assets/images/2logo.png',
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(
                                          Icons.gavel,
                                          size: 40,
                                          color: Color(0xFF8B5CF6),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedFadeIn(
                            delay: const Duration(milliseconds: 1000),
                            child: Text(
                              'Welcome to The Arena DTD',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _themeService.isDarkMode
                                    ? const Color(0xFFE0E0E0)  // Light text in dark mode
                                    : const Color(0xFF4A4458),  // Dark purple text in light mode
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedFadeIn(
                            delay: const Duration(milliseconds: 1100),
                            child: Text(
                              'Where Debate is Royalty',
                              style: TextStyle(
                                fontSize: 14,
                                color: _themeService.isDarkMode
                                    ? const Color(0xFFB0B0B0)  // Lighter gray in dark mode
                                    : const Color(0xFF6B5F7A),  // Medium purple text in light mode
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Stats row with bells and rank
                          AnimatedSlideIn(
                            delay: const Duration(milliseconds: 1200),
                            beginOffset: const Offset(0, 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                // Challenge Bell
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Center(
                                    child: ChallengeBell(
                                      iconColor: Color(0xFFDC143C), // Scarlet red
                                      iconSize: 32,
                                    ),
                                  ),
                                ),
                                // Room Invitation Bell
                                if (_currentUserProfile != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Center(
                                      child: RoomInvitationBell(
                                        userId: _currentUserProfile!.id,
                                      ),
                                    ),
                                  ),
                                // Rank
                                _buildStatColumn(
                                  _userRankingData?['globalRank']?.toString() ?? '—',
                                  'Rank',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  /// Check if this is the user's first visit and show welcome help modal
  Future<void> _checkAndShowWelcomeHelp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenWelcomeHelp = prefs.getBool('has_seen_welcome_help') ?? false;

      if (!hasSeenWelcomeHelp) {
        // Wait for UI to settle before showing modal
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false, // Force user to acknowledge
              builder: (context) => HelpModal(
                title: 'Welcome to The Arena!',
                items: HelpContent.homeScreen(),
                accentColor: const Color(0xFF8B5CF6),
              ),
            );
            // Mark as seen
            prefs.setBool('has_seen_welcome_help', true);
          }
        });
      }
    } catch (e) {
      AppLogger().error('Error checking welcome help status: $e');
    }
  }

  Future<void> _checkUserRoles() async {
    if (_currentUserProfile == null) return;
    
    try {
      AppLogger().debug('🔍 Checking user roles for: ${_currentUserProfile!.id}');
      
      // Check if user is already a moderator
      final moderatorResponse = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.moderatorsCollection,
        queries: [
          Query.equal('userId', _currentUserProfile!.id),
        ],
      );
      
      // Check if user is already a judge
      final judgeResponse = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.judgesCollection,
        queries: [
          Query.equal('userId', _currentUserProfile!.id),
        ],
      );
      
      final isModerator = moderatorResponse.documents.isNotEmpty;
      final isJudge = judgeResponse.documents.isNotEmpty;
      
      AppLogger().debug('🔍 Role check results - Moderator: $isModerator (${moderatorResponse.documents.length} docs), Judge: $isJudge (${judgeResponse.documents.length} docs)');
      
      if (mounted) {
        setState(() {
          _isCurrentUserModerator = isModerator;
          _isCurrentUserJudge = isJudge;
        });
        
        AppLogger().debug('🔍 UI state updated - Showing moderator card: $_isCurrentUserModerator, Showing judge card: $_isCurrentUserJudge');
      }
    } catch (e) {
      AppLogger().error('Error checking user roles: $e');
    }
  }

  void _showModeratorRegistration() {
    // Check if already a moderator
    if (_isCurrentUserModerator) {
      _showAlreadyRegisteredDialog('moderator');
    } else {
      // Show community rules and agreement for becoming a moderator
      _showCommunityAgreement('moderator');
    }
  }

  void _showJudgeRegistration() {
    // Check if already a judge
    if (_isCurrentUserJudge) {
      _showAlreadyRegisteredDialog('judge');
    } else {
      // Show community rules and agreement for becoming a judge
      _showCommunityAgreement('judge');
    }
  }

  void _showAlreadyRegisteredDialog(String roleType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              roleType == 'moderator' ? Icons.gavel : Icons.balance,
              color: roleType == 'moderator' 
                  ? const Color(0xFF8B5CF6) 
                  : const Color(0xFFFFC107),
            ),
            const SizedBox(width: 8),
            const Text('Already Registered'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are already registered as a $roleType!',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'To view or edit your profile, please use:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (roleType == 'moderator'
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFFFFC107)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    roleType == 'moderator' ? Icons.gavel : Icons.balance,
                    color: roleType == 'moderator' 
                        ? const Color(0xFF8B5CF6) 
                        : const Color(0xFFFFC107),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"My ${roleType == 'moderator' ? 'Moderator' : 'Judge'} Profile" in Community Roles',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: roleType == 'moderator' 
                            ? const Color(0xFF8B5CF6) 
                            : const Color(0xFFFFC107),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate directly to the appropriate profile
              if (roleType == 'moderator') {
                _navigateToModerators();
              } else {
                _navigateToJudges();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: roleType == 'moderator' 
                  ? const Color(0xFF8B5CF6) 
                  : const Color(0xFFFFC107),
            ),
            child: const Text('Go to Profile'),
          ),
        ],
      ),
    );
  }

  void _showCommunityAgreement(String roleType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join the Community as ${roleType.toUpperCase()}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Community Guidelines',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '• Maintain professionalism and respect\n'
                '• Be fair and impartial in your role\n'
                '• Follow all community standards\n'
                '• Contribute positively to debates\n'
                '• Report any violations',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Text(
                '${roleType == 'moderator' ? 'Moderator' : 'Judge'} Responsibilities',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                roleType == 'moderator'
                    ? '• Facilitate fair debates\n'
                      '• Manage speaking time\n'
                      '• Ensure rules compliance\n'
                      '• Keep discussions on topic'
                    : '• Evaluate arguments objectively\n'
                      '• Provide constructive feedback\n'
                      '• Score based on merit\n'
                      '• Maintain neutrality',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to agreement screen
              if (roleType == 'moderator') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ModeratorAgreementScreen(
                      currentUserId: _currentUserProfile?.id ?? '',
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => JudgeAgreementScreen(
                      currentUserId: _currentUserProfile?.id ?? '',
                    ),
                  ),
                );
              }
            },
            child: const Text('I Agree - Continue'),
          ),
        ],
      ),
    );
  }

  // _buildCommunityRoleButton method removed - unused

  Widget _buildHeaderIcon(IconData icon, VoidCallback onTap, {Color? iconColor, double size = 36}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6),  // Purple background
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),  // Purple glow
              blurRadius: 15,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,  // White icons
          size: size * 0.5, // Proportional to container size
        ),
      ),
    );
  }

  Widget _buildProfileInitials() {
    return Center(
      child: Text(
        _currentUserProfile?.initials ?? 'U',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : const Color(0xFFE8E4F3),  // Same as background
        borderRadius: BorderRadius.circular(15),
        boxShadow: _themeService.isDarkMode
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ]
            : [
                // Subtle neumorphic effect for stats
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.7),
                  offset: const Offset(-4, -4),
                  blurRadius: 8,
                ),
                BoxShadow(
                  color: const Color(0xFFC8C0DC).withValues(alpha: 0.4),
                  offset: const Offset(4, 4),
                  blurRadius: 8,
                ),
              ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _themeService.isDarkMode
                  ? const Color(0xFF4A4458)  // Dark purple text in dark mode (readable on light container)
                  : const Color(0xFF4A4458),  // Dark purple text in light mode
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFFF2400),  // Scarlet red for label
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildFeatureGrid() {
    return Column(
      children: [
        // Top row - 3 cards
        Row(
          children: [
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 1400),
                child: _buildFeatureCard('TheArena', 'The Arena', () => _navigateToArena()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 1500),
                child: _buildFeatureCard('FindUsers', 'Find Users', () => _navigateToFindUsers()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 1600),
                child: _buildFeatureCard('Debate', 'Debate', () => _navigateToDebate()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Middle row - 3 cards
        Row(
          children: [
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 1700),
                child: _buildFeatureCard('Take', 'Take', () => _navigateToTake()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 1800),
                child: _buildFeatureCard('Discussion', 'Discussion', () => _navigateToDiscussion()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 1850),
                child: _buildFeatureCard('MySlides', 'My Slides', () => _navigateToSlides()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Bottom row - 3 cards
        Row(
          children: [
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 1900),
                child: _buildFeatureCard('DebateClubs', 'Debate Clubs', () => _navigateToDebateClubs()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 2000),
                child: _buildFeatureCard('Tournaments', 'Tournaments', () => _navigateToTournaments()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 2100),
                child: _buildFeatureCard('Rankings', 'Rankings', () => _navigateToRankings()),
              ),
            ),
          ],
        ),
        // Error reporting row - available to all users
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 2200),
                child: _buildFeatureCard('Feedback', 'Report Error', () => _showBetaFeedbackDialog()),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()), // Empty space
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()), // Empty space
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(String feature, String title, VoidCallback onTap, {GlobalKey? key}) {
    // Map of feature icons to actual assets or Icons
    final iconMap = {
      'TheArena': Icons.gavel, // Use gavel icon for Arena
      'FindUsers': 'assets/icons/find.png',
      'Debate': 'assets/images/1v1.png',
      'Take': 'assets/icons/debatetakesdiscuss.png',
      'Discussion': 'assets/images/discussions1.png',
      'MySlides': Icons.slideshow, // Use slideshow icon for My Slides
      'DebateClubs': 'assets/icons/debate clubs.png',
      'Tournaments': 'assets/images/bracket.png',
      'Rankings': 'assets/icons/rank1.png',
      'Feedback': Icons.feedback, // Beta feedback icon for all users
    };
    
    final iconAsset = iconMap[feature];
    
    // Get screen dimensions for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 400 || screenHeight < 750; // Expanded threshold for iPhone 12
    
    // Responsive sizing based on screen size - even larger icons
    final iconContainerSize = isSmallScreen ? 60.0 : 60.0; // Even larger icons on small screens
    final iconSize = isSmallScreen ? 34.0 : 32.0; // Even larger icons on small screens
    final imageSize = isSmallScreen ? 42.0 : 40.0; // Even larger images on small screens
    final fontSize = isSmallScreen ? 11.0 : 15.0; // Smaller text on small screens
    final verticalSpacing = isSmallScreen ? 4.0 : 8.0; // Minimal spacing for more text room
    final horizontalPadding = isSmallScreen ? 4.0 : 10.0;
    
    return AspectRatio(
      aspectRatio: 1.0,
      child: GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
              decoration: BoxDecoration(
                color: _themeService.isDarkMode
                    ? const Color(0xFF2D2D2D)  // Dark card color
                    : const Color(0xFFE8E4F3),  // Light purple
                borderRadius: BorderRadius.circular(24),
                boxShadow: _themeService.isDarkMode
                    ? [
                        // Dark mode shadows
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          offset: const Offset(-6, -6),
                          blurRadius: 12,
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.05),
                          offset: const Offset(6, 6),
                          blurRadius: 12,
                        ),
                      ]
                    : [
                        // Light mode neumorphic shadows
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          offset: const Offset(-6, -6),
                          blurRadius: 12,
                        ),
                        BoxShadow(
                          color: const Color(0xFFC8C0DC).withValues(alpha: 0.5),
                          offset: const Offset(6, 6),
                          blurRadius: 12,
                        ),
                      ],
              ),
              child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: isSmallScreen ? 4.0 : 12.0, // Reduced vertical padding on small screens
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon directly on card (no background circle)
                Container(
                  width: iconContainerSize,
                  height: iconContainerSize,
                  child: iconAsset is IconData
                    ? Icon(
                        iconAsset,
                        size: iconSize,
                        color: const Color(0xFF8B5CF6),  // Purple icons
                      )
                    : iconAsset is String
                      ? (iconAsset == 'assets/images/1v1.png' && _themeService.isDarkMode)
                        ? ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                            child: Image.asset(
                              iconAsset,
                              width: imageSize,
                              height: imageSize,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.category_rounded,
                                  size: iconSize,
                                  color: const Color(0xFF8B5CF6),
                                );
                              },
                            ),
                          )
                        : Image.asset(
                            iconAsset,
                            width: imageSize,
                            height: imageSize,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.category_rounded,
                                size: iconSize,
                                color: const Color(0xFF8B5CF6),
                              );
                            },
                          )
                      : Icon(
                          Icons.category_rounded,
                          size: iconSize,
                          color: const Color(0xFF8B5CF6),  // Purple fallback
                        ),
                ),
                SizedBox(height: verticalSpacing),
                if (title.isNotEmpty)
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600, // Consistent weight
                        color: const Color(0xFFFF2400),  // Scarlet text
                        height: isSmallScreen ? 1.0 : 1.1, // Even tighter line height on small screens
                      ),
                      textAlign: TextAlign.center,
                      maxLines: isSmallScreen ? 4 : 3, // More lines on small screens
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToArena() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ArenaLobbyScreen()));
  }

  void _navigateToFindUsers() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const FindUsersScreen()));
  }

  void _navigateToDebate() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const DiscussionsRoomListScreen(preSelectedFormat: 'Debate')));
  }

  void _navigateToTake() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const DiscussionsRoomListScreen(preSelectedFormat: 'Take')));
  }

  void _navigateToDiscussion() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const DiscussionsRoomListScreen(preSelectedFormat: 'Discussion')));
  }

  // ignore: unused_element
  void _navigateToProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
  }

  void _navigateToDebateClubs() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const DebateClubsScreen()));
  }

  void _navigateToTournaments() {
    // TODO: Navigate to tournaments screen when implemented
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tournament feature coming soon!'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _navigateToRankings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RankingsScreen(),
      ),
    );
  }

  void _navigateToSlides() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const SlideLibraryScreen()));
  }

  Widget _buildModeratorJudgeSection() {
    // Only show this section if user has at least one role
    if (!_isCurrentUserModerator && !_isCurrentUserJudge) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'My Community Roles',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A4458),  // Dark purple text
            ),
          ),
        ),
        
        // Moderator and Judge cards - only show the ones user has
        Row(
          children: [
            if (_isCurrentUserModerator)
              Expanded(
                child: AnimatedScaleIn(
                  delay: const Duration(milliseconds: 2000),
                  child: _buildRoleCard(
                    'My Moderator Profile',
                    'View and edit your moderator profile',
                    Icons.balance,  // Scales icon
                    const Color(0xFF8B5CF6),
                    () => _navigateToModerators(),
                  ),
                ),
              ),
            if (_isCurrentUserModerator && _isCurrentUserJudge)
              const SizedBox(width: 12),
            if (_isCurrentUserJudge)
              Expanded(
                child: AnimatedScaleIn(
                  delay: const Duration(milliseconds: 2100),
                  child: _buildRoleCard(
                    'My Judge Profile',
                    'View and edit your judge profile',
                    Icons.gavel,  // Gavel icon
                    const Color(0xFFFFC107),
                    () => _navigateToJudges(),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBecomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Join the Community',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A4458),  // Dark purple text
            ),
          ),
        ),
        
        // Become buttons
        Row(
          children: [
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 2200),
                child: _buildBecomeCard(
                  'Become Moderator',
                  'Read rules and join as a moderator',
                  Icons.balance,  // Scales icon
                  const Color(0xFF8B5CF6),
                  () => _showModeratorRegistration(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 2300),
                child: _buildBecomeCard(
                  'Become Judge',
                  'Read rules and join as a judge',
                  Icons.gavel,  // Gavel icon
                  const Color(0xFFFFC107),
                  () => _showJudgeRegistration(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleCard(String title, String description, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _themeService.isDarkMode
                  ? const Color(0xFF1A1A1A)  // Dark mode
                  : const Color(0xFFE8E4F3),  // Light mode
              borderRadius: BorderRadius.circular(24),
              boxShadow: _themeService.isDarkMode
                  ? [
                      // Dark mode shadows
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        offset: const Offset(-6, -6),
                        blurRadius: 12,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.05),
                        offset: const Offset(6, 6),
                        blurRadius: 12,
                      ),
                    ]
                  : [
                      // Light mode neumorphic shadows
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.8),
                        offset: const Offset(-6, -6),
                        blurRadius: 12,
                      ),
                      BoxShadow(
                        color: const Color(0xFFC8C0DC).withValues(alpha: 0.5),
                        offset: const Offset(6, 6),
                        blurRadius: 12,
                      ),
                    ],
            ),
            child: Column(
              children: [
                // Icon with neumorphic background
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _themeService.isDarkMode
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFFE8E4F3),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _themeService.isDarkMode
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              offset: const Offset(-3, -3),
                              blurRadius: 6,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.05),
                              offset: const Offset(3, 3),
                              blurRadius: 6,
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.7),
                              offset: const Offset(-3, -3),
                              blurRadius: 6,
                            ),
                            BoxShadow(
                              color: const Color(0xFFC8C0DC).withValues(alpha: 0.4),
                              offset: const Offset(3, 3),
                              blurRadius: 6,
                            ),
                          ],
                  ),
                  child: Icon(
                    icon,
                    color: color,  // Use the passed color
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,  // Use the passed color
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),

                // Description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,  // Use the passed color
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
      ),
    );
  }

  void _navigateToModerators() {
    // Show user's moderator profile and allow editing if they have one
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ModeratorListScreen(),
      ),
    );
  }

  void _navigateToJudges() {
    // Show user's judge profile and allow editing if they have one  
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JudgeListScreen(),
      ),
    );
  }

  Widget _buildBecomeCard(String title, String description, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _themeService.isDarkMode
                  ? const Color(0xFF1A1A1A)  // Dark mode
                  : const Color(0xFFE8E4F3),  // Light mode
              borderRadius: BorderRadius.circular(24),
              boxShadow: _themeService.isDarkMode
                  ? [
                      // Dark mode shadows
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        offset: const Offset(-6, -6),
                        blurRadius: 12,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.05),
                        offset: const Offset(6, 6),
                        blurRadius: 12,
                      ),
                    ]
                  : [
                      // Light mode neumorphic shadows
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.8),
                        offset: const Offset(-6, -6),
                        blurRadius: 12,
                      ),
                      BoxShadow(
                        color: const Color(0xFFC8C0DC).withValues(alpha: 0.5),
                        offset: const Offset(6, 6),
                        blurRadius: 12,
                      ),
                    ],
            ),
            child: Column(
              children: [
                // Icon with neumorphic background
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _themeService.isDarkMode
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFFE8E4F3),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _themeService.isDarkMode
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              offset: const Offset(-3, -3),
                              blurRadius: 6,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.05),
                              offset: const Offset(3, 3),
                              blurRadius: 6,
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.7),
                              offset: const Offset(-3, -3),
                              blurRadius: 6,
                            ),
                            BoxShadow(
                              color: const Color(0xFFC8C0DC).withValues(alpha: 0.4),
                              offset: const Offset(3, 3),
                              blurRadius: 6,
                            ),
                          ],
                  ),
                  child: Icon(
                    icon,
                    color: color,  // Use the passed color
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,  // Use the passed color
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),

                // Description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,  // Use the passed color
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
      ),
    );
  }


  Widget? _buildFloatingActionButton() {
    // Check if current user is a super moderator
    final userId = _currentUserProfile?.id;
    if (userId == null) return null;
    
    final superModService = SuperModeratorService();
    final isSuperMod = superModService.isSuperModerator(userId);
    
    if (isSuperMod) {
      // Show Super Moderator dashboard for super mods only
      return FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SuperModDashboard(),
            ),
          );
        },
        backgroundColor: const Color(0xFFFF6B35), // Orange color for super mod
        icon: const Icon(Icons.security, color: Colors.white),
        label: const Text('Super Mod', style: TextStyle(color: Colors.white)),
      );
    }
    
    // Regular users don't see any reports button
    return null;
  }

  void _showBetaFeedbackDialog() {
    final errorController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.isDarkMode
            ? const Color(0xFF1A1A1A)
            : Colors.white,
        title: Text(
          'Report an Error',
          style: TextStyle(
            color: _themeService.isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found a bug or error? Let us know!',
                style: TextStyle(
                  color: _themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: errorController,
                style: TextStyle(
                  color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                ),
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: 'Describe the error',
                  labelStyle: TextStyle(
                    color: _themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  hintText: 'What happened? What were you trying to do? What did you expect to happen?',
                  hintStyle: TextStyle(
                    color: _themeService.isDarkMode ? Colors.grey[600] : Colors.grey[400],
                    fontSize: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _themeService.isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.orange),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: _themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (errorController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please describe the error'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _sendErrorEmail(errorController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Send Report'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendErrorEmail(String errorDescription) async {
    try {
      final userName = _currentUserProfile?.name ?? 'Unknown User';
      final userId = _currentUserProfile?.id ?? 'Unknown ID';
      final userEmail = _currentUserProfile?.email ?? 'No email';

      final emailBody = '''
Error Report from The Arena DTD App

User: $userName
User ID: $userId
User Email: $userEmail
Date: ${DateTime.now().toIso8601String()}

ERROR DESCRIPTION:
$errorDescription

---
This is an automated error report from The Arena DTD mobile app.
''';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening email app...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Log the error for debugging
      AppLogger().info('📧 Error report email prepared for: $userName');
      AppLogger().info('📋 Error description: $errorDescription');

      // Send email to support and erica
      try {
        // Send email via Appwrite function
        await _appwrite.functions.createExecution(
          functionId: 'send-error-report',
          body: jsonEncode({
            'to': ['support@thearenadtd.com', 'erica@dialecticlabs.com'],
            'subject': 'Error Report from The Arena DTD App',
            'body': emailBody,
            'userName': userName,
            'userId': userId,
          }),
        );

        // Create support ticket in Odoo CRM
        try {
          await _appwrite.functions.createExecution(
            functionId: 'create-support-ticket',
            body: jsonEncode({
              'userId': userId,
              'userEmail': userEmail,
              'userName': userName,
              'issueType': 'bug',
              'subject': 'App Error Report',
              'description': errorDescription,
              'deviceInfo': '${Theme.of(context).platform}',
              'appVersion': '1.0.61', // TODO: Get from package_info
            }),
          );
          AppLogger().info('✅ Support ticket created in Odoo CRM');
        } catch (ticketError) {
          AppLogger().warning('Failed to create Odoo ticket: $ticketError');
          // Don't block user flow if ticket creation fails
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error report sent to support team!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        AppLogger().error('Failed to send error report: $e');

        // Fallback: Show the formatted email body to the user
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please email this error report to: support@thearenadtd.com and erica@dialecticlabs.com'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View Report',
              textColor: Colors.white,
              onPressed: () {
                // Show the email body in a dialog
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Error Report'),
                    content: SingleChildScrollView(
                      child: Text(emailBody),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        }
      }
    } catch (e) {
      AppLogger().error('❌ Failed to prepare error email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create email. Please email support@thearenadtd.com directly.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

