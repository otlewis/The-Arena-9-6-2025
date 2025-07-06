import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../screens/debate_clubs_screen.dart';
import '../screens/profile_screen.dart';
import 'create_open_screen.dart';
import '../models/user_profile.dart';
import '../screens/arena_lobby_screen.dart';
import '../screens/find_users_screen.dart';
import '../screens/debates_discussions_screen.dart';
import '../services/appwrite_service.dart';
import '../services/challenge_messaging_service.dart';
import '../services/theme_service.dart';
import '../widgets/arena_role_notification_modal.dart';
import '../widgets/animated_fade_in.dart';
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
      color: Colors.grey[50],
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
                      child: _buildHeaderIcon(LucideIcons.bell, () {}),
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
                            shape: BoxShape.circle,
                            color: Colors.black,
                            border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
                          ),
                          child: _currentUserProfile?.avatar != null
                              ? ClipOval(
                                  child: Image.network(
                                    _currentUserProfile!.avatar!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildProfileInitials(),
                                  ),
                                )
                              : _buildProfileInitials(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Welcome card
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 600),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFF2400).withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Judge's gavel icon
                      const AnimatedScaleIn(
                        delay: Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        child: Icon(
                          Icons.gavel,
                          size: 48,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const AnimatedFadeIn(
                        delay: Duration(milliseconds: 1000),
                        child: Text(
                          'Welcome to The Arena',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B5CF6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const AnimatedFadeIn(
                        delay: Duration(milliseconds: 1100),
                        child: Text(
                          'Where Debate is Royalty',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFFFF2400),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
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

  Widget _buildHeaderIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
          color: Colors.white,
        ),
        child: Icon(
          icon,
          color: const Color(0xFF8B5CF6),
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
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B5CF6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
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
                child: _buildFeatureCard('assets/icons/TheArena.jpg', '', () => _navigateToArena()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 1500),
                child: _buildFeatureCard('assets/icons/FindUsers.png', '', () => _navigateToFindUsers()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 1600),
                child: _buildFeatureCard('assets/icons/OpenDiscussons.png', '', () => _navigateToCreateOpen()),
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
                child: _buildFeatureCard('assets/icons/Debates&Discussions.png', '', () => _navigateToDebatesDiscussions()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 1800),
                child: _buildFeatureCard('assets/icons/DebateClubs.png', '', () => _navigateToDebateClubs()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedScaleIn(
                delay: const Duration(milliseconds: 1900),
                child: _buildFeatureCard('assets/icons/Rankings.png', '', () => _showComingSoon()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(String imagePath, String title, VoidCallback onTap) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                // Background image
                Positioned.fill(
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF8B5CF6),
                      child: const Icon(
                        LucideIcons.image,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Title overlay at bottom
                if (title.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
    Navigator.push(context, MaterialPageRoute(builder: (context) => const DebatesDiscussionsScreen()));
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