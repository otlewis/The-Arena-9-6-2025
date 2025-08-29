import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';
import '../screens/debate_clubs_screen.dart';
import '../screens/profile_screen.dart';
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
import '../constants/appwrite.dart';
import 'package:appwrite/appwrite.dart';
import '../widgets/arena_role_notification_modal.dart';
import '../widgets/animated_fade_in.dart';
import '../widgets/simple_message_bell.dart';
import '../widgets/challenge_bell.dart';
import '../widgets/audio_status_indicator.dart';
import 'package:get_it/get_it.dart';
import '../core/logging/app_logger.dart';
import '../debug_coin_initializer.dart';
import '../widgets/ping_notification_modal.dart';
import '../models/moderator_judge.dart';
import 'moderation_dashboard_screen.dart';
// All test screen imports removed - files deleted

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final AppwriteService _appwrite = AppwriteService();
  final ThemeService _themeService = ThemeService();
  late final ChallengeMessagingService _messagingService;
  UserProfile? _currentUserProfile;
  int _arenaRoleInvitations = 0;
  bool _isLoading = true;
  RealtimeSubscription? _pingSubscription;
  Timer? _roleCheckTimer;
  bool _isCurrentUserModerator = false;
  bool _isCurrentUserJudge = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messagingService = GetIt.instance<ChallengeMessagingService>();
    _loadCurrentUserProfile();
    _setupArenaRoleInvitationListener();
    _setupChallengeDeclinedListener();
    _setupPingRequestListener();
    _checkUserRoles();
    
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
    WidgetsBinding.instance.removeObserver(this);
    _pingSubscription?.close();
    _roleCheckTimer?.cancel();
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
        if (mounted) {
          setState(() {
            _currentUserProfile = profile;
            _isLoading = false;
          });
          // Check roles after profile is loaded
          _checkUserRoles();
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
    _messagingService.arenaRoleInvitations.listen((invitation) {
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
    _messagingService.challengeDeclined.listen((challenge) {
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _themeService.isDarkMode 
          ? const Color(0xFF2D2D2D)
          : const Color(0xFFE8E8E8),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ModerationDashboardScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
        label: const Text('Reports', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onLongPress: _showDebugOptions,
      child: Container(
        color: _themeService.isDarkMode 
            ? const Color(0xFF2D2D2D)
            : const Color(0xFFE8E8E8),
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
                              fontSize: 18, // Reduced from 20
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF8B5CF6),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '@${_currentUserProfile?.name ?? 'User'}',
                            style: TextStyle(
                              fontSize: 13, // Reduced from 14
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AnimatedScaleIn(
                      delay: const Duration(milliseconds: 300),
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
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.white.withValues(alpha: 0.7),
                              offset: const Offset(-4, -4),
                              blurRadius: 8,
                            ),
                            BoxShadow(
                              color: _themeService.isDarkMode 
                                  ? Colors.black.withValues(alpha: 0.5)
                                  : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
                              offset: const Offset(4, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: ChallengeBell(
                            iconColor: Color(0xFFDC143C), // Scarlet red
                            iconSize: 20, // Reduced from 24
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4), // Reduced from 8
                    AnimatedScaleIn(
                      delay: const Duration(milliseconds: 350),
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
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.white.withValues(alpha: 0.7),
                              offset: const Offset(-4, -4),
                              blurRadius: 8,
                            ),
                            BoxShadow(
                              color: _themeService.isDarkMode 
                                  ? Colors.black.withValues(alpha: 0.5)
                                  : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
                              offset: const Offset(4, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: SimpleMessageBell(
                            iconColor: Color(0xFF8B5CF6), // Purple
                            iconSize: 20, // Reduced from 24
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4), // Reduced from 8
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
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.white.withValues(alpha: 0.7),
                              offset: const Offset(-4, -4),
                              blurRadius: 8,
                            ),
                            BoxShadow(
                              color: _themeService.isDarkMode 
                                  ? Colors.black.withValues(alpha: 0.5)
                                  : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
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
                      delay: const Duration(milliseconds: 400),
                      child: _buildHeaderIcon(
                        _themeService.isDarkMode ? LucideIcons.sun : LucideIcons.moon,
                        () {
                          _themeService.toggleTheme();
                          setState(() {});
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
                            color: _themeService.isDarkMode 
                                ? const Color(0xFF3A3A3A)
                                : const Color(0xFFF0F0F3),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _themeService.isDarkMode 
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : Colors.white.withValues(alpha: 0.7),
                                offset: const Offset(-4, -4),
                                blurRadius: 8,
                              ),
                              BoxShadow(
                                color: _themeService.isDarkMode 
                                    ? Colors.black.withValues(alpha: 0.5)
                                    : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
                                offset: const Offset(4, 4),
                                blurRadius: 8,
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
              // Welcome card with Neumorphic design and scarlet outline
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 600),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _themeService.isDarkMode 
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFFF0F0F3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFF2400).withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _themeService.isDarkMode 
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.white.withValues(alpha: 0.8),
                        offset: const Offset(-8, -8),
                        blurRadius: 16,
                      ),
                      BoxShadow(
                        color: _themeService.isDarkMode 
                            ? Colors.black.withValues(alpha: 0.5)
                            : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
                        offset: const Offset(8, 8),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Arena logo with neumorphic circle - smaller
                      AnimatedScaleIn(
                        delay: const Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _themeService.isDarkMode 
                                ? const Color(0xFF3A3A3A)
                                : const Color(0xFFF0F0F3),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _themeService.isDarkMode 
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : Colors.white.withValues(alpha: 0.7),
                                offset: const Offset(-6, -6),
                                blurRadius: 12,
                              ),
                              BoxShadow(
                                color: _themeService.isDarkMode 
                                    ? Colors.black.withValues(alpha: 0.5)
                                    : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
                                offset: const Offset(6, 6),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/Arenalogo.png',
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
                      const SizedBox(height: 12),
                      const AnimatedFadeIn(
                        delay: Duration(milliseconds: 1000),
                        child: Text(
                          'Welcome to The Arena',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B5CF6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const AnimatedFadeIn(
                        delay: Duration(milliseconds: 1100),
                        child: Text(
                          'Where Debate is Royalty',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFFFF2400),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Stats row
                      AnimatedSlideIn(
                        delay: const Duration(milliseconds: 1200),
                        beginOffset: const Offset(0, 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn(
                              '${_currentUserProfile?.totalWins ?? 0}',
                              'Wins',
                            ),
                            _buildStatColumn(
                              '${_currentUserProfile?.totalDebates ?? 0}',
                              'Debates',
                            ),
                            _buildStatColumn(
                              _currentUserProfile?.reputation != null
                                  ? (_currentUserProfile!.reputation / 100).toStringAsFixed(1)
                                  : '0.0',
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
                    : const Color(0xFFFFC107)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: roleType == 'moderator' 
                      ? const Color(0xFF8B5CF6) 
                      : const Color(0xFFFFC107),
                ),
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
    final color = iconColor ?? const Color(0xFF8B5CF6);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _themeService.isDarkMode 
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFF0F0F3),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _themeService.isDarkMode 
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white.withValues(alpha: 0.7),
              offset: const Offset(-4, -4),
              blurRadius: 8,
            ),
            BoxShadow(
              color: _themeService.isDarkMode 
                  ? Colors.black.withValues(alpha: 0.5)
                  : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
              offset: const Offset(4, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.6, // Proportional to container size
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
            ? const Color(0xFF2D2D2D)
            : const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.black.withValues(alpha: 0.6)
                : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
            offset: const Offset(3, 3),
            blurRadius: 6,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.white.withValues(alpha: 0.8),
            offset: const Offset(-3, -3),
            blurRadius: 6,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _themeService.isDarkMode 
                  ? Colors.white54
                  : Colors.grey[600],
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
        // Middle row - 2 cards
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
            // Empty space to maintain grid
            Expanded(child: Container()),
          ],
        ),
        const SizedBox(height: 12),
        // Bottom row - 2 cards
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
            // Empty space to maintain grid
            Expanded(child: Container()),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(String feature, String title, VoidCallback onTap) {
    // Map of feature icons to actual assets or Icons
    final iconMap = {
      'TheArena': Icons.gavel, // Use gavel icon for Arena
      'FindUsers': 'assets/icons/find.png',
      'Debate': 'assets/images/debate1.png',
      'Take': 'assets/images/take5.png',
      'Discussion': 'assets/images/discussions1.png',
      'DebateClubs': 'assets/icons/debate clubs.png',
      'Tournaments': 'assets/images/bracket.png',
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
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _themeService.isDarkMode 
                ? const Color(0xFF3A3A3A)
                : const Color(0xFFF0F0F3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF2400).withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _themeService.isDarkMode 
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.7),
                offset: const Offset(-6, -6),
                blurRadius: 12,
              ),
              BoxShadow(
                color: _themeService.isDarkMode 
                    ? Colors.black.withValues(alpha: 0.5)
                    : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
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
                Container(
                  width: iconContainerSize,
                  height: iconContainerSize,
                  decoration: BoxDecoration(
                    color: _themeService.isDarkMode 
                        ? const Color(0xFF2D2D2D)
                        : const Color(0xFFE8E8E8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _themeService.isDarkMode 
                            ? Colors.black.withValues(alpha: 0.6)
                            : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                        offset: const Offset(3, 3),
                        blurRadius: 6,
                        spreadRadius: -2,
                      ),
                      BoxShadow(
                        color: _themeService.isDarkMode 
                            ? Colors.white.withValues(alpha: 0.02)
                            : Colors.white.withValues(alpha: 0.8),
                        offset: const Offset(-3, -3),
                        blurRadius: 6,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: iconAsset is IconData
                    ? Icon(
                        iconAsset,
                        size: iconSize,
                        color: const Color(0xFF8B5CF6),
                      )
                    : iconAsset is String
                      ? Image.asset(
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
                          color: const Color(0xFF8B5CF6),
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
                        color: _themeService.isDarkMode 
                            ? Colors.white70
                            : Colors.black87,
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _themeService.isDarkMode 
                  ? Colors.white
                  : Colors.black87,
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
                    Icons.gavel,
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
                    Icons.balance,
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
              color: _themeService.isDarkMode 
                  ? Colors.white
                  : Colors.black87,
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
                  Icons.gavel,
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
                  Icons.balance,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _themeService.isDarkMode 
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _themeService.isDarkMode 
                ? const Color(0xFF555555)
                : const Color(0xFFE0E0E0),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _themeService.isDarkMode 
                    ? Colors.white
                    : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            
            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: _themeService.isDarkMode 
                    ? Colors.white60
                    : Colors.black54,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _themeService.isDarkMode 
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Icon with background
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
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
                color: _themeService.isDarkMode 
                    ? Colors.white
                    : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            
            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: _themeService.isDarkMode 
                    ? Colors.white60
                    : Colors.black54,
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

  void _showDebugOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🔧 Debug Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            DebugCoinInitializer.debugButton(context),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                DebugCoinInitializer.showAppwriteInstructions(context);
              },
              icon: const Icon(Icons.help_outline),
              label: const Text('📋 Appwrite Setup Guide'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }


}

