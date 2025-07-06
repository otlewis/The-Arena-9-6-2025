import 'package:flutter/material.dart';
import '../services/appwrite_service.dart';
import '../models/user_profile.dart';
import '../widgets/user_avatar.dart';
import 'edit_profile_screen.dart';
import 'club_details_screen.dart';
import 'package:appwrite/models.dart' as models;
import '../core/logging/app_logger.dart';
class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  
  const ProfileScreen({super.key, this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AppwriteService _appwrite = AppwriteService();
  List<Map<String, dynamic>> _memberships = [];
  bool _isLoading = true;
  UserProfile? _userProfile;
  models.User? _currentUser;
  int _followerCount = 0;
  int _followingCount = 0;

  // Colors matching home screen
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color lightScarlet = Color(0xFFFFF1F0);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
      debugPrint('⚠️ Logout error handled gracefully: $e');
      
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

  Future<void> _updateAvailability({bool? moderator, bool? judge}) async {
    if (_currentUser == null || _userProfile == null) return;
    
    try {
      await _appwrite.updateUserProfile(
        userId: _currentUser!.$id,
        isAvailableAsModerator: moderator,
        isAvailableAsJudge: judge,
      );
      
      // Update local state
      setState(() {
        _userProfile = _userProfile!.copyWith(
          isAvailableAsModerator: moderator,
          isAvailableAsJudge: judge,
        );
      });
      
      // Show success message
      if (mounted) {
        final String message = moderator != null 
            ? 'Moderator availability ${moderator ? 'enabled' : 'disabled'}'
            : 'Judge availability ${judge! ? 'enabled' : 'disabled'}';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $message'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error updating availability: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: scarletRed),
        titleTextStyle: const TextStyle(
          color: deepPurple,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          if (_currentUser != null)
            IconButton(
              icon: const Icon(Icons.edit, color: scarletRed),
              onPressed: _editProfile,
            ),
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
                    _buildAvailabilitySettingsCard(),
                    _buildMyClubsSection(),
                    const SizedBox(height: 24),
                  ],
                  _buildActionButtons(context),
                  const SizedBox(height: 16),
                  

                  
                  // Sign Out
                  ListTile(
                    leading: const Icon(Icons.logout, color: scarletRed),
                    title: const Text('Logout', style: TextStyle(color: deepPurple)),
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
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    final profile = _userProfile;
    final isGuest = _currentUser == null;

    return Column(
  children: [
    UserAvatar(
      avatarUrl: profile?.avatar, // This should work if UserAvatar expects 'avatarUrl'
      initials: profile?.initials,
      radius: 60,
      backgroundColor: lightScarlet,
      textColor: scarletRed,
    ),
    const SizedBox(height: 16),
        Text(
          isGuest ? 'Guest User' : (profile?.displayName ?? 'Unknown User'),
                    style: const TextStyle(
            fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: deepPurple,
                    ),
                  ),
        if (profile?.location != null && profile!.location!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                profile.location!,
                style: TextStyle(
                  color: Colors.grey[600],
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
              color: lightScarlet,
              borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildStatsCard() {
    final profile = _userProfile;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
      ),
    );
  }

  Widget _buildStat(String value, String label, {IconData? icon, Color? color}) {
    return Column(
      children: [
        if (icon != null) ...[
          Icon(icon, color: color ?? deepPurple, size: 20),
          const SizedBox(height: 4),
        ],
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color ?? deepPurple,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBioCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _userProfile!.bio!,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Interests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _userProfile!.interests.map((interest) {
                return Chip(
                  label: Text(interest),
                  backgroundColor: lightScarlet,
                  labelStyle: const TextStyle(color: scarletRed, fontSize: 12),
                );
              }).toList(),
            ),
          ],
        ),
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
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Links',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deepPurple,
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
      ),
    );
  }

  Widget _buildLinkTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scarletRed),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
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
                  const Text(
                    'My Clubs',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: deepPurple,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_memberships.isEmpty)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: scarletRed.withValues(alpha: 0.1)),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'You haven\'t joined any clubs yet. Join a club to start debating!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
          Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: scarletRed.withValues(alpha: 0.1)),
                      ),
            child: Padding(
              padding: const EdgeInsets.all(16),
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
    return Column(
      children: [
        if (_currentUser != null) ...[
          ListTile(
            leading: const Icon(Icons.logout, color: scarletRed),
            title: const Text('Logout', style: TextStyle(color: deepPurple)),
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
          const Divider(),
        ],
        ListTile(
          leading: const Icon(Icons.history, color: scarletRed),
          title: const Text('Debate History', style: TextStyle(color: deepPurple)),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Debate history coming soon!')),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.bookmark, color: scarletRed),
          title: const Text('Saved Debates', style: TextStyle(color: deepPurple)),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saved debates coming soon!')),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.notifications, color: scarletRed),
          title: const Text('Notifications', style: TextStyle(color: deepPurple)),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications coming soon!')),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.help, color: scarletRed),
          title: const Text('Help & Support', style: TextStyle(color: deepPurple)),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Help & support coming soon!')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAvailabilitySettingsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gavel, color: accentPurple, size: 20),
                SizedBox(width: 8),
                Text(
                  'Arena Availability',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Get notified when debates need moderators or judges',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            
            // Moderator availability toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentPurple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentPurple.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_pin_circle, color: accentPurple, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available as Moderator',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Help facilitate debates and keep discussions on track',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _userProfile?.isAvailableAsModerator ?? false,
                    onChanged: (value) => _updateAvailability(moderator: value),
                    activeColor: accentPurple,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Judge availability toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.balance, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available as Judge',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Evaluate debates and provide fair scoring',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _userProfile?.isAvailableAsJudge ?? false,
                    onChanged: (value) => _updateAvailability(judge: value),
                    activeColor: Colors.amber.shade700,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}