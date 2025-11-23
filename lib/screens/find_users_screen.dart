import '../core/logging/app_logger.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/appwrite_service.dart';
import '../services/theme_service.dart';
import '../services/challenge_messaging_service.dart';
import '../services/challenge_eligibility_service.dart';
import '../models/user_profile.dart';
import '../widgets/user_avatar.dart';
import '../widgets/challenge_bell.dart';
import '../widgets/report_user_dialog.dart';
import '../widgets/block_user_dialog.dart';
import '../screens/user_profile_screen.dart';
import '../services/tutorial_service.dart';
import '../config/tutorial_definitions.dart';

class FindUsersScreen extends StatefulWidget {
  const FindUsersScreen({super.key});

  @override
  State<FindUsersScreen> createState() => _FindUsersScreenState();
}

class _FindUsersScreenState extends State<FindUsersScreen> {
  final AppwriteService _appwrite = AppwriteService();
  final ThemeService _themeService = ThemeService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<UserProfile> _allUsers = [];
  List<UserProfile> _filteredUsers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreUsers = true;
  bool _currentUserIsPremium = false;
  String? _currentUserId;

  // Pagination constants
  static const int _pageSize = 20;
  int _currentOffset = 0;

  // GlobalKey for tutorial highlighting
  final GlobalKey _searchBarKey = GlobalKey();

  // Colors
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _checkCurrentUserPremiumStatus();
    _loadUsers();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreUsers();
    }
  }

  Future<void> _showTutorial() async {
    final tutorialService = TutorialService();
    await tutorialService.maybeShowTutorial(
      context: context,
      tutorialKey: tutorialService.findUsersKey,
      highlights: TutorialDefinitions.findUsers(
        searchKey: _searchBarKey,
        filterKey: null, // No filters in this screen currently
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _appwrite.getCurrentUser();
    if (user != null) {
      _currentUserId = user.$id;
    }
  }

  Future<void> _checkCurrentUserPremiumStatus() async {
    try {
      // BETA TESTING: Force all users to be premium during beta
      setState(() {
        _currentUserIsPremium = true;
      });
      AppLogger().info('🧪 BETA MODE: All users have premium access for challenges');

      /* TODO: Restore feature flag logic when beta testing is complete
      // Check if beta testing mode is enabled
      final isBetaTesting = await FeatureFlagService().isBetaTestingMode();

      if (isBetaTesting) {
        // In beta testing mode, all users are premium
        setState(() {
          _currentUserIsPremium = true;
        });
        AppLogger().info('🧪 Beta testing mode enabled - all users have premium access');
      } else {
        // Normal premium checking
        final currentUser = await _appwrite.getCurrentUser();
        if (currentUser != null) {
          final userProfile = await _appwrite.getUserProfile(currentUser.$id);
          setState(() {
            _currentUserIsPremium = userProfile?.isPremium ?? false;
          });
        }
      }
      */
    } catch (e) {
      AppLogger().debug('Error checking current user premium status: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _currentOffset = 0;
        _hasMoreUsers = true;
      });

      final result = await _appwrite.getAllUsersPaginated(
        limit: _pageSize,
        offset: 0,
      );

      if (!mounted) return;

      setState(() {
        _allUsers = result.users.where((user) => user.id != _currentUserId).toList();
        _filteredUsers = _searchController.text.isEmpty
            ? _allUsers
            : _allUsers.where((user) {
                return user.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                       user.email.toLowerCase().contains(_searchController.text.toLowerCase());
              }).toList();
        _hasMoreUsers = result.hasMore;
        _currentOffset = _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger().debug('❌ Error loading users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreUsers() async {
    // Don't load more if we're searching, already loading, or no more data
    if (_searchController.text.isNotEmpty || _isLoadingMore || !_hasMoreUsers) {
      return;
    }

    try {
      setState(() => _isLoadingMore = true);

      final result = await _appwrite.getAllUsersPaginated(
        limit: _pageSize,
        offset: _currentOffset,
      );

      if (!mounted) return;

      setState(() {
        final newUsers = result.users.where((user) => user.id != _currentUserId).toList();
        _allUsers.addAll(newUsers);
        _filteredUsers = _allUsers;
        _hasMoreUsers = result.hasMore;
        _currentOffset += _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      AppLogger().debug('❌ Error loading more users: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers.where((user) {
          return user.name.toLowerCase().contains(query.toLowerCase()) ||
                 user.email.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _themeService.isDarkMode
          ? Colors.black
          : const Color(0xFFE8E4F3),  // Light purple background
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Find Users',
            style: TextStyle(
              color: _themeService.isDarkMode
                  ? Colors.white
                  : const Color(0xFF4A4458),  // Dark purple text
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(
            color: _themeService.isDarkMode
                ? Colors.white
                : const Color(0xFF4A4458),  // Dark purple
          ),
          actions: [
            _buildNeumorphicAppBarIcon(
              ChallengeBell(
                iconColor: _themeService.isDarkMode
                    ? Colors.white
                    : const Color(0xFF8B5CF6),  // Purple icon
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            child: _buildNeumorphicSearchBar(),
          ),
          
          // Users list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: accentPurple,
                    ),
                  )
                : _filteredUsers.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        color: accentPurple,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredUsers.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _filteredUsers.length) {
                              // Loading indicator at the bottom
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: accentPurple,
                                  ),
                                ),
                              );
                            }
                            return _buildUserCard(_filteredUsers[index]);
                          },
                        ),
                      ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
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
                  offset: const Offset(-8, -8),
                  blurRadius: 16,
                ),
                BoxShadow(
                  color: _themeService.isDarkMode 
                      ? Colors.black.withOpacity(0.5)
                      : const Color(0xFFA3B1C6).withOpacity(0.5),
                  offset: const Offset(8, 8),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(
              Icons.people_outline,
              size: 60,
              color: _themeService.isDarkMode 
                  ? Colors.white24
                  : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchController.text.isEmpty
                ? 'No users found'
                : 'No users match your search',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _themeService.isDarkMode 
                  ? Colors.white70
                  : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? 'Check back later for new users'
                : 'Try a different search term',
            style: TextStyle(
              fontSize: 16,
              color: _themeService.isDarkMode 
                  ? Colors.white54
                  : Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNeumorphicAppBarIcon(Widget child) {
    return Container(
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
      child: Center(child: child),
    );
  }

  Widget _buildNeumorphicSearchBar() {
    return ClipRRect(
      key: _searchBarKey,
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: _themeService.isDarkMode
                ? const Color(0xFF2D2D2D)  // Dark background
                : const Color(0xFFE8E4F3),  // Light mode: light purple
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _themeService.isDarkMode
                  ? const Color(0xFF404040)  // Dark mode: subtle border
                  : Colors.transparent,  // Light mode: no border (neumorphic)
              width: 2,
            ),
            boxShadow: _themeService.isDarkMode
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
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
          child: TextField(
            controller: _searchController,
            onChanged: _filterUsers,
            style: TextStyle(
              color: _themeService.isDarkMode
                  ? Colors.white
                  : const Color(0xFF4A4458),  // Dark purple
            ),
            decoration: InputDecoration(
              hintText: 'Search users by name or email...',
              hintStyle: TextStyle(
                color: _themeService.isDarkMode
                    ? Colors.white.withValues(alpha: 0.6)
                    : const Color(0xFF6B5F7A).withValues(alpha: 0.6),  // Medium purple
              ),
              prefixIcon: Icon(
                Icons.search,
                color: _themeService.isDarkMode
                    ? Colors.white
                    : const Color(0xFF8B5CF6),  // Purple
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(UserProfile user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: _themeService.isDarkMode
                  ? const Color(0xFF2D2D2D)  // Dark background
                  : const Color(0xFFE8E4F3),  // Light mode: light purple
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _themeService.isDarkMode
                    ? const Color(0xFF404040)  // Dark mode: subtle border
                    : Colors.transparent,  // Light mode: no border (neumorphic)
                width: 2,
              ),
              boxShadow: _themeService.isDarkMode
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
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
            child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToUserProfile(user),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _themeService.isDarkMode 
                            ? Colors.black.withOpacity(0.4)
                            : const Color(0xFFA3B1C6).withOpacity(0.3),
                        offset: const Offset(3, 3),
                        blurRadius: 6,
                        spreadRadius: -2,
                      ),
                      BoxShadow(
                        color: _themeService.isDarkMode 
                            ? Colors.white.withOpacity(0.02)
                            : Colors.white.withOpacity(0.7),
                        offset: const Offset(-3, -3),
                        blurRadius: 6,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: UserAvatar(
                    avatarUrl: user.avatar,
                    initials: user.initials,
                    radius: 24,
                    backgroundColor: accentPurple.withOpacity(0.1),
                    textColor: accentPurple,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _themeService.isDarkMode 
                                    ? Colors.white
                                    : deepPurple,
                              ),
                            ),
                          ),
                          if (user.isVerified)
                            const Icon(
                              Icons.verified,
                              size: 16,
                              color: accentPurple,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: _themeService.isDarkMode 
                              ? Colors.white70
                              : Colors.grey[600],
                        ),
                      ),
                      if (user.location?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: _themeService.isDarkMode 
                                  ? Colors.white54
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.location!,
                              style: TextStyle(
                                fontSize: 12,
                                color: _themeService.isDarkMode 
                                    ? Colors.white54
                                    : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _themeService.isDarkMode 
                            ? const Color(0xFF2D2D2D)
                            : const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _themeService.isDarkMode 
                                ? Colors.black.withOpacity(0.6)
                                : const Color(0xFFA3B1C6).withOpacity(0.3),
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                            spreadRadius: -1,
                          ),
                          BoxShadow(
                            color: _themeService.isDarkMode 
                                ? Colors.white.withOpacity(0.02)
                                : Colors.white.withOpacity(0.8),
                            offset: const Offset(-2, -2),
                            blurRadius: 4,
                            spreadRadius: -1,
                          ),
                        ],
                      ),
                      child: Text(
                        '${user.formattedReputation} rep',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scarletRed,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user.totalDebates} debates',
                      style: TextStyle(
                        fontSize: 10,
                        color: _themeService.isDarkMode 
                            ? Colors.white54
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: _themeService.isDarkMode 
                        ? Colors.white54
                        : Colors.grey,
                  ),
                  onSelected: (value) => _handleUserAction(value, user),
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.person, color: accentPurple, size: 18),
                          SizedBox(width: 8),
                          Text('View Profile'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'challenge',
                      child: Row(
                        children: [
                          Icon(
                            Icons.gavel,
                            color: _currentUserIsPremium ? scarletRed : Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currentUserIsPremium ? 'Challenge' : 'Challenge (Premium)',
                            style: TextStyle(
                              color: _currentUserIsPremium ? null : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.report, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Report User'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(Icons.block, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Text('Block User'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
          ),
        ),
      ),
    );
  }

  void _navigateToUserProfile(UserProfile user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: user.id),
      ),
    );
  }

  Future<void> _handleUserAction(String action, UserProfile user) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to perform this action')),
      );
      return;
    }

    switch (action) {
      case 'view':
        _navigateToUserProfile(user);
        break;
      case 'challenge':
        if (_currentUserIsPremium) {
          await _showChallengeDialog(user);
        } else {
          _showPremiumPaywall();
        }
        break;
      case 'report':
        await _showReportDialog(user);
        break;
      case 'block':
        await _showBlockDialog(user);
        break;
    }
  }

  Future<void> _showReportDialog(UserProfile userToReport) async {
    await showDialog(
      context: context,
      builder: (context) => ReportUserDialog(
        reportedUser: userToReport,
        roomId: 'find_users', // Generic room ID for find users reports
        reporterId: _currentUserId!,
      ),
    );
  }

  Future<void> _showBlockDialog(UserProfile userToBlock) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => BlockUserDialog(
        userToBlock: userToBlock,
        currentUserId: _currentUserId!,
      ),
    );

    if (result == true && mounted) {
      // User was successfully blocked, refresh the user list to remove them
      await _loadUsers();
    }
  }

  Future<void> _showChallengeDialog(UserProfile user) async {
    final topicController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedPosition = 'affirmative';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Challenge ${user.displayName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Topic input
                TextField(
                  controller: topicController,
                  decoration: const InputDecoration(
                    labelText: 'Debate Topic *',
                    hintText: 'What should you debate about?',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Description input
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Add context or rules...',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Position selection
                const Text('Your Position:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => selectedPosition = 'affirmative'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedPosition == 'affirmative' ? Colors.green : Colors.grey,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedPosition == 'affirmative' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              const Text('For'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => selectedPosition = 'negative'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedPosition == 'negative' ? Colors.red : Colors.grey,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedPosition == 'negative' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              const Text('Against'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: topicController.text.isEmpty
                  ? null
                  : () => _sendChallenge(
                        user,
                        topicController.text,
                        descriptionController.text,
                        selectedPosition,
                      ),
              icon: const Icon(Icons.send),
              label: const Text('Send Challenge'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendChallenge(UserProfile user, String topic, String description, String position) async {
    try {
      // Check eligibility BEFORE sending challenge
      final eligibilityService = ChallengeEligibilityService();

      // Check if current user can issue challenges
      final canIssueChallenge = await eligibilityService.canCurrentUserIssueChallenge();
      if (canIssueChallenge != null) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(canIssueChallenge),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Check if target user can be challenged
      final canBeChallenged = await eligibilityService.canUserBeChallenged(user.id);
      if (canBeChallenged != null) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(canBeChallenged),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Both users are eligible - send the challenge
      await ChallengeMessagingService().sendChallenge(
        challengedUserId: user.id,
        topic: topic,
        description: description,
        position: position,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Challenge sent to ${user.displayName}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending challenge: $e')),
        );
      }
    }
  }

  void _showPremiumPaywall() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.diamond, color: Color(0xFF6B46C1)),
            SizedBox(width: 8),
            Text('Premium Feature'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instant Debate Challenges are available for Premium subscribers.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Unlimited challenges')),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Priority arena access')),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Advanced features')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/premium_store');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B46C1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }
}