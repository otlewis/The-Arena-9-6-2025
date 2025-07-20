import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../screens/debate_clubs_screen.dart';
import '../screens/profile_screen.dart';
import 'create_open_screen.dart';
import '../models/user_profile.dart';
import '../screens/arena_lobby_screen.dart';
import '../screens/find_users_screen.dart';
import 'discussions_room_list_screen.dart';
import '../services/appwrite_service.dart';
import '../services/challenge_messaging_service.dart';
import '../services/theme_service.dart';
import '../widgets/arena_role_notification_modal.dart';
import '../widgets/animated_fade_in.dart';
import '../widgets/instant_message_bell.dart';
import 'package:get_it/get_it.dart';
import '../core/logging/app_logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AppwriteService _appwrite = AppwriteService();
  final ThemeService _themeService = ThemeService();
  late final ChallengeMessagingService _messagingService;
  UserProfile? _currentUserProfile;
  int _arenaRoleInvitations = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _messagingService = GetIt.instance<ChallengeMessagingService>();
    _loadCurrentUserProfile();
    _setupArenaRoleInvitationListener();
    _setupChallengeDeclinedListener();
  }

  @override
  void dispose() {
    super.dispose();
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
                  ],
                ),
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                        Text(
                          '@${_currentUserProfile?.name ?? 'User'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    AnimatedScaleIn(
                      delay: const Duration(milliseconds: 300),
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
                        child: const InstantMessageBell(
                          iconColor: Color(0xFFDC2626),
                          iconSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                    const SizedBox(width: 8),
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
                            'assets/images/logo.png',
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
    );
  }


  String _getGreeting() {
    final hour = DateTime.now().hour;
    final name = _currentUserProfile?.name ?? 'User';
    
    if (hour < 12) {
      return 'Good Morning\n$name';
    } else if (hour < 17) {
      return 'Good Afternoon\n$name';
    } else {
      return 'Good Evening\n$name';
    }
  }

  Widget _buildHeaderIcon(IconData icon, VoidCallback onTap, {Color? iconColor}) {
    final color = iconColor ?? const Color(0xFF8B5CF6);
    return GestureDetector(
      onTap: onTap,
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
        child: Icon(
          icon,
          color: color,
          size: 24,
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
                child: _buildFeatureCard('OpenDiscussions', 'Open Discussions', () => _navigateToCreateOpen()),
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
                delay: const Duration(milliseconds: 1700),
                child: _buildFeatureCard('DebateTakeDiscuss', 'Debate, Take, Discuss', () => _navigateToDebatesDiscussions()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 1800),
                child: _buildFeatureCard('DebateClubs', 'Debate Clubs', () => _navigateToDebateClubs()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 1900),
                child: _buildFeatureCard('Rankings', 'Rankings', () => _showComingSoon()),
              ),
            ),
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
      'OpenDiscussions': 'assets/icons/opendiscussions.png',
      'DebateTakeDiscuss': 'assets/icons/debatetakesdiscuss.png',
      'DebateClubs': 'assets/icons/debate clubs.png',
      'Rankings': 'assets/icons/rank1.png',
    };
    
    final iconAsset = iconMap[feature];
    
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
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
                child: iconAsset == Icons.gavel
                  ? const Icon(
                      Icons.gavel,
                      size: 32,
                      color: Color(0xFF8B5CF6),
                    )
                  : Image.asset(
                      iconAsset as String,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.category_rounded,
                          size: 32,
                          color: Color(0xFF8B5CF6),
                        );
                      },
                    ),
              ),
              const SizedBox(height: 12),
              if (title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _themeService.isDarkMode 
                          ? Colors.white70
                          : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
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

  void _navigateToCreateOpen() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateOpenScreen()));
  }

  // ignore: unused_element
  void _navigateToProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
  }

  void _navigateToDebateClubs() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const DebateClubsScreen()));
  }

  void _navigateToDebatesDiscussions() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const DiscussionsRoomListScreen()));
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming Soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

