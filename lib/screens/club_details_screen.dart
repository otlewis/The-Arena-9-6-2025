import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/appwrite_service.dart';
import '../models/user_profile.dart';
import '../screens/user_profile_screen.dart';
import '../core/logging/app_logger.dart';

class ClubDetailsScreen extends StatefulWidget {
  final String clubId;
  final String clubName;
  final String description;

  const ClubDetailsScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.description,
  });

  @override
  State<ClubDetailsScreen> createState() => _ClubDetailsScreenState();
}

class _ClubDetailsScreenState extends State<ClubDetailsScreen> {
  final AppwriteService _appwrite = AppwriteService();
  List<Map<String, dynamic>> _members = [];
  Map<String, UserProfile> _memberProfiles = {}; // Cache for member profiles
  bool _isLoading = true;
  String? _currentUserId;
  String? _clubCreatorId;

  // Colors matching app theme
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color lightScarlet = Color(0xFFFFF1F0);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      
      // Get current user
      final user = await _appwrite.getCurrentUser();
      _currentUserId = user?.$id;
      
      // Load members and their profiles
      await _loadMembers();
      
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

  Future<void> _loadMembers() async {
    try {
      final members = await _appwrite.getClubMembers(widget.clubId);
      Map<String, UserProfile> memberProfiles = {};
      
      // Load profile for each member
      for (final member in members) {
        final userId = member['userId']?.toString();
        if (userId != null && userId.isNotEmpty) {
          try {
            final profile = await _appwrite.getUserProfile(userId);
            if (profile != null) {
              memberProfiles[userId] = profile;
              
              // Check if this member is the president (club creator)
              if (member['role'] == 'president') {
                _clubCreatorId = userId;
              }
            }
          } catch (e) {
            AppLogger().error('Error loading profile for user $userId', e);
          }
        }
      }
      
      setState(() {
        _members = members;
        _memberProfiles = memberProfiles;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading members: $e')),
        );
      }
    }
  }

  bool _isCurrentUserPresident() {
    return _currentUserId != null && _currentUserId == _clubCreatorId;
  }

  Future<void> _transferPresidency(String newPresidentId) async {
    try {
      // Find current president's membership
      final currentPresident = _members.firstWhere(
        (m) => m['role'] == 'president',
        orElse: () => {},
      );
      
      // Find new president's membership
      final newPresident = _members.firstWhere(
        (m) => m['userId'] == newPresidentId,
        orElse: () => {},
      );
      
      if (currentPresident.isNotEmpty && newPresident.isNotEmpty) {
        // Update current president to member
        await _appwrite.updateMembershipRole(
          membershipId: currentPresident['id'],
          newRole: 'member',
        );
        
        // Update new member to president
        await _appwrite.updateMembershipRole(
          membershipId: newPresident['id'],
          newRole: 'president',
        );
        
        // Reload data
        await _loadMembers();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Presidency transferred to ${_memberProfiles[newPresidentId]?.name ?? 'member'}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error transferring presidency: $e')),
        );
      }
    }
  }

  void _showTransferPresidencyDialog() {
    final eligibleMembers = _members.where((m) => 
      m['role'] != 'president' && _memberProfiles.containsKey(m['userId'])
    ).toList();

    if (eligibleMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eligible members to transfer presidency to')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Presidency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a member to become the new president:'),
            const SizedBox(height: 16),
            ...eligibleMembers.map((member) {
              final profile = _memberProfiles[member['userId']];
              return ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  child: profile?.avatar != null && profile!.avatar!.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: profile.avatar!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Text(
                              (profile.name)[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          (profile?.name ?? '?')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
                title: Text(profile?.name ?? 'Unknown'),
                subtitle: Text(member['role'].toString().toUpperCase()),
                onTap: () {
                  Navigator.pop(context);
                  _transferPresidency(member['userId']);
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.clubName,
          style: const TextStyle(color: deepPurple),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: scarletRed),
        actions: [
          // Only show transfer presidency option for current president
          if (_isCurrentUserPresident())
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: scarletRed),
              onSelected: (value) {
                if (value == 'transfer') {
                  _showTransferPresidencyDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'transfer',
                  child: Row(
                    children: [
                      Icon(Icons.supervisor_account, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Transfer Presidency'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: lightScarlet.withValues(alpha: 0.3),
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
                  widget.description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Members',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: deepPurple,
                  ),
                ),
                Text(
                  '${_members.length} members',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _members.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final profile = _memberProfiles[member['userId']];
                      final isPresident = member['role'] == 'president';
                      
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isPresident 
                                ? Colors.orange.withValues(alpha: 0.3)
                                : scarletRed.withValues(alpha: 0.1)
                          ),
                        ),
                        child: ListTile(
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
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: isPresident 
                                ? Colors.orange.withValues(alpha: 0.2)
                                : lightScarlet,
                            child: profile?.avatar != null && profile!.avatar!.isNotEmpty
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: profile.avatar!,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                                      errorWidget: (context, url, error) => Text(
                                        (profile.name)[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isPresident ? Colors.orange : scarletRed,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    (profile?.name ?? '?')[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isPresident ? Colors.orange : scarletRed,
                                    ),
                                  ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  profile?.name ?? 'Unknown User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (isPresident)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.workspace_premium, size: 12, color: Colors.orange),
                                      SizedBox(width: 4),
                                      Text(
                                        'PRESIDENT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              if (!isPresident)
                                Text(
                                  member['role'].toString().toUpperCase(),
                                  style: TextStyle(
                                    color: accentPurple.withValues(alpha: 0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (member['joinedAt'] != null)
                                Text(
                                  'Joined ${_formatJoinDate(member['joinedAt'])}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          // No edit icon for regular members
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatJoinDate(String? dateString) {
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
        return 'just now';
      }
    } catch (e) {
      return '';
    }
  }
} 