import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/appwrite_service.dart';
import '../screens/user_profile_screen.dart';
import 'club_details_screen.dart';
import 'package:appwrite/models.dart' as models;
import '../core/logging/app_logger.dart';

class DebateClub {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final Map<String, Map<String, String>> members;

  DebateClub({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.members,
  });
}

const String clubStructure = '''
Key roles within a debate club:

1. President: Oversees the club, represents officially, organizes events.
2. Vice President: Assists President, manages specific aspects.
3. Secretary: Handles admin tasks, records, scheduling.
4. Treasurer: Manages finances, budgeting.
5. Debate Coach/Advisor: Provides guidance, training, mentorship.
6. Captain: Leads debates, organizes practice, motivates team.
7. Chairperson: Presides over debates, maintains order.
8. Director of Debates: Organizes events, selects topics, manages logistics.
9. Public Relations Officer: Handles publicity, manages social media.
10. Moderator: Facilitates debates, ensures fair speaking opportunities.
''';

class DebateClubsScreen extends StatefulWidget {
  const DebateClubsScreen({super.key});

  @override
  State<DebateClubsScreen> createState() => _DebateClubsScreenState();
}

class _DebateClubsScreenState extends State<DebateClubsScreen> {
  final AppwriteService _appwrite = AppwriteService();
  List<Map<String, dynamic>> _clubs = [];
  List<Map<String, dynamic>> _userMemberships = [];
  Map<String, String> _presidentNames = {}; // Cache for president names
  Map<String, List<Map<String, dynamic>>> _clubMembers = {}; // Cache for club members
  bool _isLoading = true;
  String? _currentUserId;

  // Colors matching home screen
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      
      // Get current user (handle guest users gracefully)
      models.User? user;
      try {
        user = await _appwrite.getCurrentUser();
      } catch (e) {
        if (e.toString().contains('general_unauthorized_scope') || e.toString().contains('missing scope')) {
          // User is not logged in - this is normal, continue as guest
          AppLogger().info('User not authenticated - loading clubs as guest');
          user = null;
        } else {
          rethrow; // Re-throw unexpected errors
        }
      }
      
      _currentUserId = user?.$id;
      
      if (_currentUserId != null) {
        // Load clubs and user memberships in parallel
        final results = await Future.wait([
          _appwrite.getDebateClubs(),
          _appwrite.getUserMemberships(_currentUserId!),
        ]);
        
        setState(() {
          _clubs = results[0];
          _userMemberships = results[1];
        });
      } else {
        // Just load clubs if no user is logged in
        final clubs = await _appwrite.getDebateClubs();
        setState(() {
          _clubs = clubs;
        });
      }
      
      // Load president names for all clubs
      await _loadPresidentNames();
      
      // Load club members for all clubs
      await _loadClubMembers();
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _loadPresidentNames() async {
    final Map<String, String> presidentNames = {};
    
    for (final club in _clubs) {
      final createdBy = club['createdBy'];
      if (createdBy != null && createdBy.isNotEmpty) {
        try {
          AppLogger().debug('Loading president name for user: $createdBy');
          final profile = await _appwrite.getUserProfile(createdBy);
          final presidentName = profile?.name ?? 'Unknown User';
          presidentNames[createdBy] = presidentName;
          AppLogger().debug('Loaded president name: $presidentName for user: $createdBy');
        } catch (e) {
          AppLogger().debug('Error loading president name for $createdBy: $e');
          presidentNames[createdBy] = 'Unknown User';
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _presidentNames = presidentNames;
      });
    }
  }

  Future<void> _loadClubMembers() async {
    final Map<String, List<Map<String, dynamic>>> clubMembers = {};
    
    for (final club in _clubs) {
      final clubId = club['id']?.toString();
      if (clubId != null && clubId.isNotEmpty) {
        try {
          AppLogger().debug('Loading members for club: ${club['name']} (ID: $clubId)');
          
          // Get members for this club
          final members = await _appwrite.getClubMembers(clubId);
          AppLogger().debug('Raw members data: $members');
          
          // Get profile data for each member
          List<Map<String, dynamic>> memberProfiles = [];
          for (final member in members) {
            final userId = member['userId']?.toString();
            if (userId != null && userId.isNotEmpty) {
              try {
                AppLogger().debug('Loading profile for user: $userId (role: ${member['role']})');
                final profile = await _appwrite.getUserProfile(userId);
                if (profile != null) {
                  final memberProfile = {
                    'userId': userId,
                    'name': profile.name,
                    'avatar': profile.avatar,
                    'role': member['role'] ?? 'member',
                  };
                  memberProfiles.add(memberProfile);
                  AppLogger().debug('Added member profile: ${profile.name} (${member['role']}) - Avatar: ${profile.avatar != null ? 'Yes' : 'No'}');
                }
              } catch (e) {
                AppLogger().debug('Error loading member profile for $userId: $e');
              }
            }
          }
          
          clubMembers[clubId] = memberProfiles;
          AppLogger().debug('Loaded ${memberProfiles.length} member profiles for club: ${club['name']}');
        } catch (e) {
          AppLogger().debug('Error loading members for club $clubId: $e');
          clubMembers[clubId] = [];
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _clubMembers = clubMembers;
      });
    }
  }

  bool _isUserMember(String clubId) {
    return _userMemberships.any((membership) => membership['clubId'] == clubId);
  }

  String? _getUserMembershipId(String clubId) {
    final membership = _userMemberships.firstWhere(
      (m) => m['clubId'] == clubId,
      orElse: () => {},
    );
    return membership['id'];
  }

  Future<void> _joinClub(String clubId) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to join clubs')),
      );
      return;
    }

    try {
      await _appwrite.createMembership(
        userId: _currentUserId!,
        clubId: clubId,
      );
      _loadData(); // Refresh the data
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining club: $e')),
        );
      }
    }
  }

  Future<void> _leaveClub(String clubId) async {
    final membershipId = _getUserMembershipId(clubId);
    if (membershipId == null) return;

    try {
      await _appwrite.deleteMembership(membershipId);
      _loadData(); // Refresh the data
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error leaving club: $e')),
        );
      }
    }
  }

  Future<void> _createClub() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to create clubs')),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty || _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      await _appwrite.createDebateClub(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        createdBy: _currentUserId!,
      );
      
      // Clear form and refresh data
      _nameController.clear();
      _descriptionController.clear();
      if (!mounted) return;
      Navigator.pop(context); // Close the create modal
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating club: $e')),
        );
      }
    }
  }

  void _showCreateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create Debate Club',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Club Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createClub,
              style: ElevatedButton.styleFrom(
                backgroundColor: scarletRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Create Club'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPresidentOptions(String clubId, String clubName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Club Options: $clubName',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 20),
            
            // Transfer Leadership
            ListTile(
              leading: const Icon(Icons.supervisor_account, color: Colors.orange),
              title: const Text('Transfer Leadership'),
              subtitle: const Text('Appoint a new president'),
              onTap: () {
                Navigator.pop(context);
                _showTransferLeadership(clubId, clubName);
              },
            ),
            
            const Divider(),
            
            // Delete Club
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete Club'),
              subtitle: const Text('Permanently delete this club'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteClubConfirmation(clubId, clubName);
              },
            ),
            
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showTransferLeadership(String clubId, String clubName) {
    // Navigate to club details where transfer functionality is implemented
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClubDetailsScreen(
          clubId: clubId,
          clubName: clubName,
          description: 'Club details', // We could pass the actual description here
        ),
      ),
    ).then((_) {
      // Refresh data when returning from club details
      _loadData();
    });
  }

  void _showDeleteClubConfirmation(String clubId, String clubName) {
    final memberCount = _clubMembers[clubId]?.length ?? 0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Club'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete "$clubName"?',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text('This will:'),
            const SizedBox(height: 8),
            const Text('• Remove the club permanently'),
            Text('• Delete all $memberCount memberships'),
            const Text('• Remove access for all members'),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteClub(clubId);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete Club'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClub(String clubId) async {
    try {
      await _appwrite.deleteDebateClub(clubId);
      _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Club deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting club: $e')),
        );
      }
    }
  }

  Widget _buildClubItem(Map<String, dynamic> club) {
    if (club.isEmpty) {
      return const SizedBox.shrink(); // Return empty widget for invalid clubs
    }
    
    final String clubId = club['id']?.toString() ?? '';
    final bool isMember = clubId.isNotEmpty ? _isUserMember(clubId) : false;
    final bool isPresident = clubId.isNotEmpty ? _isUserClubPresident(clubId) : false;
    final memberCount = club['memberCount'] ?? 0;
    final createdBy = club['createdBy']?.toString() ?? '';
    final presidentName = createdBy.isNotEmpty ? (_presidentNames[createdBy] ?? 'Loading...') : 'Unknown';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: () {
          if (clubId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ClubDetailsScreen(
                  clubId: clubId,
                  clubName: club['name']?.toString() ?? 'Unnamed Club',
                  description: club['description']?.toString() ?? 'No description available',
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Club Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          club['name'] ?? 'Unnamed Club',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: deepPurple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.people, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '$memberCount members',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Member avatars
                        _buildMemberAvatars(clubId),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isPresident ? Icons.workspace_premium : Icons.star, 
                              size: 14, 
                              color: isPresident ? Colors.orange : Colors.amber
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                isPresident ? 'You are the President' : 'President: $presidentName',
                                style: TextStyle(
                                  color: isPresident ? Colors.orange : Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: isPresident ? FontWeight.w600 : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_currentUserId != null)
                    Column(
                      children: [
                        // Only show edit for presidents
                        if (isPresident)
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            color: deepPurple,
                            onPressed: () {
                              // TODO: Navigate to edit club screen
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Edit club functionality coming soon!')),
                              );
                            },
                          ),
                        
                        // Join/Member/Leave button
                        if (!isPresident)
                          Container(
                            decoration: BoxDecoration(
                              color: isMember ? Colors.orange.withValues(alpha: 0.1) : scarletRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextButton.icon(
                              onPressed: () => isMember 
                                ? _leaveClub(clubId)
                                : _joinClub(clubId),
                              icon: Icon(
                                isMember ? Icons.exit_to_app : Icons.person_add,
                                color: isMember ? Colors.orange : scarletRed,
                                size: 16,
                              ),
                              label: Text(
                                isMember ? 'Leave' : 'Join',
                                style: TextStyle(
                                  color: isMember ? Colors.orange : scarletRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        else
                          // President options
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'President',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.more_vert, size: 16),
                                color: Colors.grey[600],
                                onPressed: () => _showPresidentOptions(clubId, club['name']?.toString() ?? 'Club'),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                      ],
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Club Description
              Text(
                club['description'] ?? 'No description available',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 12),
              
              // Club Category and Status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      club['category'] ?? 'General',
                      style: const TextStyle(
                        color: accentPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (club['isPublic'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Public',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              
              // Created date on separate line
              if (club['createdAt'] != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Created ${_formatDate(club['createdAt'])}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} months ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildDebateRulesSection() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withValues(alpha: 0.1)),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.gavel, color: scarletRed),
        title: const Text(
          'Debate Club Structure & Rules',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: deepPurple,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Key roles within a debate club:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: deepPurple,
                  ),
                ),
                const SizedBox(height: 12),
                _buildRoleItem('President', 'Oversees the club, represents officially, organizes events'),
                _buildRoleItem('Vice President', 'Assists President, manages specific aspects'),
                _buildRoleItem('Secretary', 'Handles admin tasks, records, scheduling'),
                _buildRoleItem('Treasurer', 'Manages finances, budgeting'),
                _buildRoleItem('Debate Coach/Advisor', 'Provides guidance, training, mentorship'),
                _buildRoleItem('Captain', 'Leads debates, organizes practice, motivates team'),
                _buildRoleItem('Chairperson', 'Presides over debates, maintains order'),
                _buildRoleItem('Director of Debates', 'Organizes events, selects topics, manages logistics'),
                _buildRoleItem('Public Relations Officer', 'Handles publicity, manages social media'),
                _buildRoleItem('Moderator', 'Facilitates debates, ensures fair speaking opportunities'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleItem(String role, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: const BoxDecoration(
              color: scarletRed,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$role: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: deepPurple,
                    ),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isUserClubPresident(String clubId) {
    if (_currentUserId == null || clubId.isEmpty) return false;
    try {
      final club = _clubs.firstWhere(
        (club) => club['id'] == clubId,
        orElse: () => <String, dynamic>{},
      );
      return club.isNotEmpty && club['createdBy'] == _currentUserId;
    } catch (e) {
      AppLogger().debug('Error checking club president status: $e');
      return false;
    }
  }

  Widget _buildMemberAvatars(String clubId) {
    final members = _clubMembers[clubId] ?? [];
    if (members.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show up to 5 member avatars
    final displayMembers = members.take(5).toList();
    final extraCount = members.length > 5 ? members.length - 5 : 0;

    return Row(
      children: [
        // Member avatars
        ...displayMembers.map((member) => GestureDetector(
          onTap: () {
            // Navigate to user profile
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(
                  userId: member['userId'],
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.grey[300],
              child: member['avatar'] != null && member['avatar'].isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: member['avatar'],
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: Center(
                              child: SizedBox(
                                width: 8,
                                height: 8,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: Text(
                            (member['name'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Text(
                      (member['name'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        )),
        
        // Extra count indicator
        if (extraCount > 0)
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '+$extraCount',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Debate Clubs',
          style: TextStyle(color: deepPurple),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentUserId != null)
            IconButton(
              icon: const Icon(Icons.add, color: scarletRed),
              onPressed: _showCreateModal,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Debate Rules Section
                _buildDebateRulesSection(),
                
                // Clubs Header
                const Text(
                  'Available Clubs',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: deepPurple,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Clubs List
                if (_clubs.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        Icon(
                          Icons.group_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No clubs yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to create a debate club!',
                          style: TextStyle(
                            color: Colors.grey[500],
                          ),
                        ),
                        if (_currentUserId != null) ...[
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _showCreateModal,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Club'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: scarletRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  ...(_clubs.map((club) => _buildClubItem(club)).toList()),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
} 