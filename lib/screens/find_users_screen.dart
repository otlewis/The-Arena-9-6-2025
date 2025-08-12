import 'package:flutter/material.dart';
import '../services/appwrite_service.dart';
import '../services/theme_service.dart';
import '../models/user_profile.dart';
import '../widgets/user_avatar.dart';
import '../widgets/challenge_bell.dart';
import '../screens/user_profile_screen.dart';

class FindUsersScreen extends StatefulWidget {
  const FindUsersScreen({super.key});

  @override
  State<FindUsersScreen> createState() => _FindUsersScreenState();
}

class _FindUsersScreenState extends State<FindUsersScreen> {
  final AppwriteService _appwrite = AppwriteService();
  final ThemeService _themeService = ThemeService();
  final TextEditingController _searchController = TextEditingController();
  
  List<UserProfile> _allUsers = [];
  List<UserProfile> _filteredUsers = [];
  bool _isLoading = true;
  String? _currentUserId;

  // Colors
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _appwrite.getCurrentUser();
    if (user != null) {
      _currentUserId = user.$id;
    }
  }

  Future<void> _loadUsers() async {
    try {
      setState(() => _isLoading = true);
      
      final users = await _appwrite.getAllUsers();
      
      setState(() {
        _allUsers = users.where((user) => user.id != _currentUserId).toList();
        _filteredUsers = _allUsers;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading users: $e');
      setState(() => _isLoading = false);
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
    return Scaffold(
      backgroundColor: _themeService.isDarkMode 
          ? const Color(0xFF2D2D2D)
          : const Color(0xFFE8E8E8),
      appBar: AppBar(
        title: Text(
          'Find Users',
          style: TextStyle(
            color: _themeService.isDarkMode ? Colors.white : deepPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _themeService.isDarkMode 
            ? const Color(0xFF2D2D2D)
            : const Color(0xFFE8E8E8),
        elevation: 0,
        iconTheme: IconThemeData(
          color: _themeService.isDarkMode ? Colors.white : scarletRed,
        ),
        actions: [
          _buildNeumorphicAppBarIcon(
            const ChallengeBell(iconColor: Color(0xFF6B46C1)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            return _buildUserCard(_filteredUsers[index]);
                          },
                        ),
                      ),
          ),
        ],
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
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.white.withValues(alpha: 0.7),
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
      child: Center(child: child),
    );
  }

  Widget _buildNeumorphicSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.black.withValues(alpha: 0.6)
                : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
            offset: const Offset(4, 4),
            blurRadius: 8,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.white.withValues(alpha: 0.8),
            offset: const Offset(-4, -4),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterUsers,
        style: TextStyle(
          color: _themeService.isDarkMode ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'Search users by name or email...',
          hintStyle: TextStyle(
            color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[500],
          ),
          prefixIcon: const Icon(
            Icons.search, 
            color: accentPurple,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildUserCard(UserProfile user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white.withValues(alpha: 0.8),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToUserProfile(user),
          borderRadius: BorderRadius.circular(20),
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
                            ? Colors.black.withValues(alpha: 0.4)
                            : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                        offset: const Offset(3, 3),
                        blurRadius: 6,
                        spreadRadius: -2,
                      ),
                      BoxShadow(
                        color: _themeService.isDarkMode 
                            ? Colors.white.withValues(alpha: 0.02)
                            : Colors.white.withValues(alpha: 0.7),
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
                    backgroundColor: accentPurple.withValues(alpha: 0.1),
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
                                ? Colors.black.withValues(alpha: 0.6)
                                : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                            spreadRadius: -1,
                          ),
                          BoxShadow(
                            color: _themeService.isDarkMode 
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.white.withValues(alpha: 0.8),
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
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: _themeService.isDarkMode 
                      ? Colors.white54
                      : Colors.grey,
                ),
              ],
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
}