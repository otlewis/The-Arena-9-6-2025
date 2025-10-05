import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/super_moderator_service.dart';
import '../services/appwrite_service.dart';
import '../models/user_profile.dart';
import '../models/super_moderator.dart';
import '../core/logging/app_logger.dart';

class SuperModManagementScreen extends StatefulWidget {
  const SuperModManagementScreen({super.key});

  @override
  State<SuperModManagementScreen> createState() => _SuperModManagementScreenState();
}

class _SuperModManagementScreenState extends State<SuperModManagementScreen> {
  final SuperModeratorService _superModService = SuperModeratorService();
  final AppwriteService _appwriteService = AppwriteService();
  final AppLogger _logger = AppLogger();
  final TextEditingController _searchController = TextEditingController();

  List<SuperModerator> _superMods = [];
  List<UserProfile> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final user = await _appwriteService.getCurrentUser();
      if (user != null) {
        _currentUserId = user.$id;

        // Check if user is a Super Moderator
        if (!_superModService.isSuperModerator(user.$id)) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Access denied: Super Moderator privileges required'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      await _loadSuperMods();
    } catch (e) {
      _logger.error('Failed to initialize Super Mod Management: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSuperMods() async {
    try {
      final mods = await _superModService.getAllSuperModerators();
      if (mounted) {
        setState(() {
          _superMods = mods;
        });
      }
    } catch (e) {
      _logger.error('Failed to load super moderators: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    _logger.debug('🔍 Starting user search for: "$query"');
    setState(() => _isSearching = true);

    try {
      // Search for users by name
      final users = await _appwriteService.searchUsersByUsername(query);
      _logger.debug('🔍 Found ${users.length} users from search');

      // Filter out existing super mods
      final filteredUsers = users.where((user) {
        final isSuperMod = _superModService.isSuperModerator(user.id);
        _logger.debug('🔍 User ${user.name} (${user.id}) - is super mod: $isSuperMod');
        return !isSuperMod;
      }).toList();

      _logger.debug('🔍 After filtering super mods: ${filteredUsers.length} users');

      if (mounted) {
        setState(() {
          _searchResults = filteredUsers;
        });
      }
    } catch (e) {
      _logger.error('Failed to search users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _grantSuperModStatus(UserProfile user) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Grant Super Moderator Status',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: user.avatar != null
                  ? NetworkImage(user.avatar!)
                  : null,
              child: user.avatar == null
                  ? Text(
                      user.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 32),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Grant Super Moderator status to ${user.name}?',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'This will give them full moderation powers across the entire platform.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Grant Access'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.purple),
      ),
    );

    try {
      // Grant super mod status with all permissions
      final superMod = await _superModService.grantSuperModeratorStatus(
        userId: user.id,
        username: user.name,
        grantedBy: _currentUserId!,
        profileImageUrl: user.avatar,
      );

      if (superMod != null) {
        await _loadSuperMods();

        // Clear search
        _searchController.clear();
        setState(() {
          _searchResults = [];
        });

        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${user.name} is now a Super Moderator!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to grant super mod status');
      }
    } catch (e) {
      _logger.error('Failed to grant super mod status: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to grant super mod status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _revokeSuperModStatus(SuperModerator superMod) async {
    // Don't allow revoking Kritik's status
    if (superMod.userId == '6843c3781d2c1c7154a0') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot revoke founder Super Moderator status'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Revoke Super Moderator Status',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Revoke Super Moderator status from ${superMod.username}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _superModService.revokeSuperModeratorStatus(superMod.userId, _currentUserId!);
      await _loadSuperMods();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Revoked Super Moderator status from ${superMod.username}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      _logger.error('Failed to revoke super mod status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revoke status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            const Icon(LucideIcons.shield, color: Colors.purple, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                MediaQuery.of(context).size.width < 400
                    ? 'Super Moderators'
                    : 'Super Moderator Management',
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.purple),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                // Add New Super Mod Section
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add New Super Moderator',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search by username...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          prefixIcon: const Icon(LucideIcons.search, color: Colors.grey),
                          suffixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.purple,
                                    ),
                                  ),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.purple.withValues(alpha: 0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.purple.withValues(alpha: 0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.purple),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.length >= 2) {
                            _searchUsers(value);
                          } else {
                            setState(() {
                              _searchResults = [];
                            });
                          }
                        },
                      ),
                      if (_searchResults.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundImage: user.avatar != null
                                      ? NetworkImage(user.avatar!)
                                      : null,
                                  child: user.avatar == null
                                      ? Text(user.name[0].toUpperCase())
                                      : null,
                                ),
                                title: Text(
                                  user.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  user.email,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    LucideIcons.userPlus,
                                    color: Colors.green,
                                  ),
                                  onPressed: () => _grantSuperModStatus(user),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Current Super Moderators List
                Container(
                  height: 400, // Fixed height to prevent overflow
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Current Super Moderators',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_superMods.length + 1}', // +1 for hardcoded Kritik
                                style: const TextStyle(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView(
                            children: [
                              // Hardcoded Kritik entry
                              _buildSuperModTile(
                                SuperModerator(
                                  id: 'founder',
                                  userId: '6843c3781d2c1c7154a0',
                                  username: 'Kritik',
                                  isActive: true,
                                  permissions: SuperModPermissions.allPermissions,
                                  grantedBy: 'System',
                                  grantedAt: DateTime(2024, 1, 1),
                                ),
                                isFounder: true,
                              ),
                              // Database entries
                              ..._superMods.map((mod) => _buildSuperModTile(mod)),
                              if (_superMods.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      children: [
                                        Icon(
                                          LucideIcons.userX,
                                          size: 48,
                                          color: Colors.grey[700],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No additional Super Moderators',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Use the search above to add new ones',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 100), // Extra bottom padding for scroll
              ],
            ),
          ),
    );
  }

  Widget _buildSuperModTile(SuperModerator mod, {bool isFounder = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFounder
              ? Colors.yellow.withValues(alpha: 0.3)
              : Colors.purple.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isFounder ? Colors.yellow : Colors.purple,
            backgroundImage: mod.profileImageUrl != null
                ? NetworkImage(mod.profileImageUrl!)
                : null,
            child: mod.profileImageUrl == null
                ? Text(
                    mod.username[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      mod.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isFounder) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.yellow.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'FOUNDER',
                          style: TextStyle(
                            color: Colors.yellow,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Granted by: ${mod.grantedBy}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Since: ${_formatDate(mod.grantedAt)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!isFounder)
            IconButton(
              icon: const Icon(
                LucideIcons.userMinus,
                color: Colors.red,
                size: 20,
              ),
              onPressed: () => _revokeSuperModStatus(mod),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()} months ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} days ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hours ago';
    } else {
      return 'Just now';
    }
  }
}