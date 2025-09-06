import 'package:flutter/material.dart';
import '../services/appwrite_service.dart';
import '../models/user_profile.dart';
import '../widgets/user_avatar.dart';
import 'edit_profile_screen.dart';
import 'club_details_screen.dart';
import 'language_settings_screen.dart';
import 'package:appwrite/models.dart' as models;
import '../core/logging/app_logger.dart';
import '../services/theme_service.dart';
import '../widgets/gift_bell.dart';
import '../services/revenue_cat_service.dart';
import 'package:get_it/get_it.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  
  const ProfileScreen({super.key, this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AppwriteService _appwrite = AppwriteService();
  final ThemeService _themeService = ThemeService();
  final RevenueCatService _revenueCatService = GetIt.instance<RevenueCatService>();
  List<Map<String, dynamic>> _memberships = [];
  bool _isLoading = true;
  UserProfile? _userProfile;
  models.User? _currentUser;
  int _followerCount = 0;
  int _followingCount = 0;
  CustomerInfo? _customerInfo;

  // Colors matching home screen
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color lightScarlet = Color(0xFFFFF1F0);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSubscriptionInfo();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);
      final models.User? user = await _appwrite.getCurrentUser();
      
      if (user != null) {
        _currentUser = user;
        
        // Try to get extended profile data
        final userProfile = await _appwrite.getUserProfile(user.$id);
        
        if (userProfile != null) {
          _userProfile = userProfile;
        } else {
          // Create a basic profile if it doesn't exist
          await _appwrite.createUserProfile(
            userId: user.$id,
            name: user.name,
            email: user.email,
          );
          _userProfile = await _appwrite.getUserProfile(user.$id);
        }

        // Get memberships
        try {
        final memberships = await _appwrite.getUserMemberships(user.$id);
          _memberships = await _loadMembershipsWithClubNames(memberships);
        } catch (e) {
          AppLogger().error('Error loading memberships', e);
          _memberships = [];
        }

        // Load follow counts
        try {
          final followerCount = await _appwrite.getFollowerCount(user.$id);
          final followingCount = await _appwrite.getFollowingCount(user.$id);
        setState(() {
            _followerCount = followerCount;
            _followingCount = followingCount;
          });
        } catch (e) {
          AppLogger().error('Error loading follow counts', e);
        }


        setState(() => _isLoading = false);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      // Handle the case where user is not authenticated (guest)
      if (e.toString().contains('general_unauthorized_scope') || 
          e.toString().contains('missing scope')) {
        AppLogger().warning('User not authenticated - showing guest profile');
        return;
      }
      // Only show error for unexpected errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user data: $e')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadMembershipsWithClubNames(List<Map<String, dynamic>> memberships) async {
    List<Map<String, dynamic>> enhancedMemberships = [];
    
    for (final membership in memberships) {
      final clubId = membership['clubId'];
      if (clubId != null) {
        try {
          // Get all clubs and find the one with matching ID
          final clubs = await _appwrite.getDebateClubs();
          final club = clubs.firstWhere(
            (c) => c['id'] == clubId,
            orElse: () => <String, dynamic>{},
          );
          
          final enhancedMembership = Map<String, dynamic>.from(membership);
          enhancedMembership['clubName'] = club['name'] ?? 'Unknown Club';
          enhancedMemberships.add(enhancedMembership);
        } catch (e) {
          AppLogger().error('Error loading club name for $clubId', e);
          // Add membership without club name if there's an error
          final enhancedMembership = Map<String, dynamic>.from(membership);
          enhancedMembership['clubName'] = 'Unknown Club';
          enhancedMemberships.add(enhancedMembership);
        }
      }
    }
    
    return enhancedMemberships;
  }

  Future<void> _logout() async {
    try {
      // Always clear local state first
      setState(() {
        _currentUser = null;
        _userProfile = null;
        _memberships = [];
        _followerCount = 0;
        _followingCount = 0;
      });
      
      // Attempt to sign out from Appwrite
      await _appwrite.signOut();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Logged out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Trigger logout callback to refresh authentication state
      if (widget.onLogout != null) {
        widget.onLogout!();
      }
      
    } catch (e) {
      AppLogger().debug('⚠️ Logout error handled gracefully: $e');
      
      // Even if there's an error, we've already cleared local state
      // Show success message since the user is effectively logged out
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Logged out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Still trigger logout callback
      if (widget.onLogout != null) {
        widget.onLogout!();
      }
    }
  }

  Future<void> _loadSubscriptionInfo() async {
    try {
      final customerInfo = await _revenueCatService.getCustomerInfo();
      if (mounted) {
        setState(() {
          _customerInfo = customerInfo;
        });
      }
    } catch (e) {
      AppLogger().error('Error loading subscription info: $e');
    }
  }

  bool get _hasPremiumSubscription {
    // Use profile data for premium status (works on web)
    final isPremium = _userProfile?.isPremium == true;
    AppLogger().debug('🏆 Premium status check: isPremium=$isPremium, profile=${_userProfile?.isPremium}, revenueCat=${_customerInfo?.entitlements.active.containsKey(RevenueCatService.premiumEntitlement)}');
    if (isPremium) {
      return true;
    }
    // Fall back to RevenueCat for native platforms
    return _customerInfo?.entitlements.active.containsKey(RevenueCatService.premiumEntitlement) ?? false;
  }

  Future<void> _editProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(profile: _userProfile),
      ),
    );

    if (result == true) {
      // Refresh profile data
      _loadUserData();
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.isDarkMode 
          ? const Color(0xFF2D2D2D)
          : const Color(0xFFE8E8E8),
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _themeService.isDarkMode ? Colors.white : deepPurple,
          ),
        ),
        backgroundColor: _themeService.isDarkMode 
            ? const Color(0xFF2D2D2D)
            : const Color(0xFFE8E8E8),
        elevation: 0,
        iconTheme: IconThemeData(
          color: _themeService.isDarkMode ? Colors.white70 : scarletRed,
        ),
        actions: [
          if (_currentUser != null) ...[
            GiftBell(
              iconColor: _themeService.isDarkMode ? Colors.white70 : const Color(0xFF8B5CF6),
              iconSize: 20,
            ),
            const SizedBox(width: 12),
            _buildNeumorphicIcon(
              icon: Icons.edit,
              onTap: _editProfile,
            ),
          ],
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 24),
                  _buildStatsCard(),
                  const SizedBox(height: 24),
                  if (_userProfile?.bio != null && _userProfile!.bio!.isNotEmpty)
                    _buildBioCard(),
                  if (_userProfile?.interests.isNotEmpty == true)
                    _buildInterestsCard(),
                  if (_userProfile != null && _hasAnyLinks())
                    _buildSocialLinksCard(),
                  if (_currentUser != null) ...[
                    const SizedBox(height: 24),
                    const SizedBox(height: 24),
                    _buildCommunityRolesCard(),
                    _buildMyClubsSection(),
                    const SizedBox(height: 24),
                  ],
                  _buildActionButtons(context),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    final profile = _userProfile;
    final isGuest = _currentUser == null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scarletRed.withValues(alpha: 0.2),
          width: 1.5,
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
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
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
                child: ClipOval(
                  child: UserAvatar(
                    avatarUrl: profile?.avatar,
                    initials: profile?.initials,
                    radius: 60,
                    backgroundColor: lightScarlet,
                    textColor: scarletRed,
                  ),
                ),
              ),
              if (!isGuest && _hasPremiumSubscription)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _themeService.isDarkMode 
                            ? const Color(0xFF2D2D2D)
                            : const Color(0xFFE8E8E8),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isGuest ? 'Guest User' : (profile?.displayName ?? 'Unknown User'),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _themeService.isDarkMode ? Colors.white : deepPurple,
                ),
              ),
              if (!isGuest && _hasPremiumSubscription) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Premium',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (profile?.location != null && profile!.location!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  profile.location!,
                  style: TextStyle(
                    color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
          if (profile?.isVerified == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _themeService.isDarkMode 
                    ? const Color(0xFF2D2D2D)
                    : lightScarlet,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scarletRed.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 16, color: scarletRed),
                  SizedBox(width: 4),
                  Text(
                    'Verified',
                    style: TextStyle(
                      color: scarletRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isGuest) ...[
            const SizedBox(height: 8),
            const Text(
              'Sign in to access all features',
              style: TextStyle(color: scarletRed),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final profile = _userProfile;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scarletRed.withValues(alpha: 0.2),
          width: 1.5,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(
                profile?.formattedReputation ?? '0',
                'Reputation',
                icon: Icons.star,
              ),
              _buildStat(
                profile?.totalDebates.toString() ?? '0',
                'Debates',
                icon: Icons.forum,
              ),
              _buildStat(
                _memberships.length.toString(),
                'Clubs',
                icon: Icons.group,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(
                _followerCount.toString(),
                'Followers',
                icon: Icons.people,
                color: accentPurple,
              ),
              _buildStat(
                _followingCount.toString(),
                'Following',
                icon: Icons.person_add,
                color: accentPurple,
              ),
              _buildStat(
                profile?.totalWins.toString() ?? '0',
                'Wins',
                icon: Icons.emoji_events,
                color: Colors.green,
              ),
            ],
          ),
          if (profile != null && profile.totalDebates > 0) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  '${(profile.winPercentage * 100).toStringAsFixed(1)}%',
                  'Win Rate',
                  icon: Icons.trending_up,
                  color: profile.winPercentage >= 0.6 ? Colors.green : Colors.orange,
                ),
                _buildStat(
                  profile.totalRoomsCreated.toString(),
                  'Rooms Created',
                  icon: Icons.add_circle,
                ),
                _buildStat(
                  profile.totalRoomsJoined.toString(),
                  'Rooms Joined',
                  icon: Icons.login,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label, {IconData? icon, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF2D2D2D)
            : const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(12),
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
          if (icon != null) ...[
            Icon(
              icon,
              color: color ?? (_themeService.isDarkMode ? Colors.white70 : deepPurple),
              size: 20,
            ),
            const SizedBox(height: 4),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color ?? (_themeService.isDarkMode ? Colors.white : deepPurple),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scarletRed.withValues(alpha: 0.2),
          width: 1.5,
        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _themeService.isDarkMode ? Colors.white : deepPurple,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _userProfile!.bio!,
            style: TextStyle(
              fontSize: 14, 
              height: 1.4,
              color: _themeService.isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scarletRed.withValues(alpha: 0.2),
          width: 1.5,
        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _themeService.isDarkMode ? Colors.white : deepPurple,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _userProfile!.interests.map((interest) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _themeService.isDarkMode 
                      ? const Color(0xFF2D2D2D)
                      : lightScarlet,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scarletRed.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  interest,
                  style: const TextStyle(
                    color: scarletRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  bool _hasAnyLinks() {
    final profile = _userProfile!;
    return (profile.website?.isNotEmpty == true) ||
           (profile.xHandle?.isNotEmpty == true) ||
           (profile.linkedinHandle?.isNotEmpty == true) ||
           (profile.youtubeHandle?.isNotEmpty == true) ||
           (profile.facebookHandle?.isNotEmpty == true) ||
           (profile.instagramHandle?.isNotEmpty == true);
  }

  Widget _buildSocialLinksCard() {
    final profile = _userProfile!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scarletRed.withValues(alpha: 0.2),
          width: 1.5,
        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Links',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _themeService.isDarkMode ? Colors.white : deepPurple,
            ),
          ),
          const SizedBox(height: 12),
          if (profile.website?.isNotEmpty == true)
            _buildLinkTile(Icons.language, 'Website', profile.website!),
          if (profile.xHandle?.isNotEmpty == true)
            _buildLinkTile(Icons.alternate_email, 'X', '@${profile.xHandle!}'),
          if (profile.linkedinHandle?.isNotEmpty == true)
            _buildLinkTile(Icons.business, 'LinkedIn', profile.linkedinHandle!),
          if (profile.youtubeHandle?.isNotEmpty == true)
            _buildLinkTile(Icons.play_circle, 'YouTube', profile.youtubeHandle!),
          if (profile.facebookHandle?.isNotEmpty == true)
            _buildLinkTile(Icons.facebook, 'Facebook', profile.facebookHandle!),
          if (profile.instagramHandle?.isNotEmpty == true)
            _buildLinkTile(Icons.camera_alt, 'Instagram', profile.instagramHandle!),
        ],
      ),
    );
  }

  Widget _buildLinkTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon, 
            size: 16, 
            color: _themeService.isDarkMode ? Colors.white70 : scarletRed,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyClubsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                  Text(
                    'My Clubs',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _themeService.isDarkMode ? Colors.white : deepPurple,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_memberships.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _themeService.isDarkMode 
                            ? const Color(0xFF3A3A3A)
                            : const Color(0xFFF0F0F3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: scarletRed.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
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
                      child: Text(
                        'You haven\'t joined any clubs yet. Join a club to start debating!',
                        style: TextStyle(
                          color: _themeService.isDarkMode ? Colors.white54 : Colors.grey,
                        ),
                      ),
                    )
                  else
          Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _themeService.isDarkMode 
                            ? const Color(0xFF3A3A3A)
                            : const Color(0xFFF0F0F3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: scarletRed.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  if (_memberships.length <= 3)
                    // Show clubs in a simple list if 3 or fewer
                    ...(_memberships.map((membership) => _buildClubChip(membership)))
                  else
                    // Show in a horizontal scrollable list if more than 3
                    Column(
                      children: [
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _memberships.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildClubChip(_memberships[index]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildClubChip(Map<String, dynamic> membership) {
    final clubName = membership['clubName'] ?? membership['clubId'] ?? 'Unknown Club';
    final isPresident = membership['role'] == 'president';
    
    return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClubDetailsScreen(
                                clubId: membership['clubId'],
              clubName: clubName,
              description: '',
                              ),
                            ),
                          );
                        },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPresident ? Colors.orange.withValues(alpha: 0.1) : accentPurple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPresident ? Colors.orange.withValues(alpha: 0.3) : accentPurple.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPresident) ...[
              const Icon(
                Icons.workspace_premium,
                size: 16,
                color: Colors.orange,
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                clubName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isPresident ? Colors.orange : accentPurple,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scarletRed.withValues(alpha: 0.2),
          width: 1.5,
        ),
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
      child: Column(
        children: [
          if (_currentUser != null) ...[
            _buildNeumorphicListTile(
              icon: Icons.logout,
              title: 'Logout',
              onTap: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Logout', style: TextStyle(color: scarletRed)),
                      ),
                    ],
                  ),
                );
                
                if (shouldLogout == true) {
                  _logout();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
          _buildNeumorphicListTile(
            icon: Icons.history,
            title: 'Debate History',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Debate history coming soon!')),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildNeumorphicListTile(
            icon: Icons.bookmark,
            title: 'Saved Debates',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved debates coming soon!')),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildNeumorphicListTile(
            icon: Icons.notifications,
            title: 'Notifications',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon!')),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildNeumorphicListTile(
            icon: Icons.language,
            title: 'Language & Accessibility',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LanguageSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildNeumorphicListTile(
            icon: Icons.help,
            title: 'Help & Support',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & support coming soon!')),
              );
            },
          ),
          // Admin/Dev option for database optimization
          if (_currentUser?.email != null && _currentUser!.email.contains('admin')) ...[
          ],
        ],
      ),
    );
  }

  Widget _buildNeumorphicListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _themeService.isDarkMode 
              ? const Color(0xFF2D2D2D)
              : const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(12),
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
        child: Row(
          children: [
            Icon(
              icon,
              color: _themeService.isDarkMode ? Colors.white70 : scarletRed,
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _themeService.isDarkMode ? Colors.white : deepPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCommunityRolesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentPurple.withValues(alpha: 0.2),
          width: 1.5,
        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium,
                color: _themeService.isDarkMode ? Colors.white70 : accentPurple,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Community Roles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _themeService.isDarkMode ? Colors.white : deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Join the Arena community as a certified moderator or judge',
            style: TextStyle(
              color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Navigation to Home for signup
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                // Show a simple message since navigation to specific tabs
                // requires a different approach in this context
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please go to the Home tab to sign up as Moderator or Judge'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              icon: const Icon(Icons.home, size: 18),
              label: const Text('Go to Home to Sign Up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildNeumorphicIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
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
              offset: const Offset(-3, -3),
              blurRadius: 6,
            ),
            BoxShadow(
              color: _themeService.isDarkMode 
                  ? Colors.black.withValues(alpha: 0.5)
                  : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
              offset: const Offset(3, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: _themeService.isDarkMode ? Colors.white70 : scarletRed,
        ),
      ),
    );
  }
}