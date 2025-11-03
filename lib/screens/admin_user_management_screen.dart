import 'package:flutter/material.dart';
import '../services/admin_user_service.dart';
import '../models/user_profile.dart';
import '../core/logging/app_logger.dart';

/// Admin User Management Screen
/// Search, view, and manage users with moderation actions
class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final AdminUserService _userService = AdminUserService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  bool _isSearching = false;
  List<UserProfile> _users = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecentUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentUsers() async {
    setState(() => _isLoading = true);

    try {
      final users = await _userService.getRecentUsers(limit: 20);
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger().error('❌ ADMIN USER MGMT: Error loading users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final users = await _userService.searchUsers(query, limit: 20);
      if (mounted) {
        setState(() {
          _users = users;
          _isSearching = false;
        });
      }
    } catch (e) {
      AppLogger().error('❌ ADMIN USER MGMT: Error searching users: $e');
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _showUserDetailsModal(UserProfile user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _UserDetailsModal(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'User Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: const Color(0xFF1A1A1A),
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search users by name...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[500]),
                        onPressed: () {
                          _searchController.clear();
                          _loadRecentUsers();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                if (value.isEmpty) {
                  _loadRecentUsers();
                } else if (value.length >= 2) {
                  _searchUsers(value);
                }
              },
            ),
          ),

          // Users List
          Expanded(
            child: _isLoading || _isSearching
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : _users.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No users found'
                              : 'No results for "$_searchQuery"',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                        itemCount: _users.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return _buildUserCard(user, isSmallScreen);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserProfile user, bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: user.isBanned
              ? Colors.red.withOpacity(0.3)
              : Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isBanned
              ? Colors.red.withOpacity(0.2)
              : Colors.blue.withOpacity(0.2),
          backgroundImage:
              (user.avatar?.isNotEmpty ?? false) ? NetworkImage(user.avatar!) : null,
          child: (user.avatar?.isEmpty ?? true)
              ? Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: user.isBanned ? Colors.red : Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.isBanned) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red, width: 1),
                ),
                child: const Text(
                  'BANNED',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          'Coins: ${user.coinBalance} | Rep: ${user.reputation} | W: ${user.totalWins} | L: ${user.totalLosses}',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[500],
          size: 16,
        ),
        onTap: () => _showUserDetailsModal(user),
      ),
    );
  }
}

/// User Details Modal
/// Shows detailed user information and admin actions
class _UserDetailsModal extends StatefulWidget {
  final UserProfile user;

  const _UserDetailsModal({required this.user});

  @override
  State<_UserDetailsModal> createState() => _UserDetailsModalState();
}

class _UserDetailsModalState extends State<_UserDetailsModal> {
  final AdminUserService _userService = AdminUserService();
  final TextEditingController _coinsController = TextEditingController();
  final TextEditingController _reputationController = TextEditingController();
  final TextEditingController _banReasonController = TextEditingController();

  bool _isLoading = false;
  Map<String, dynamic> _userDetails = {};
  Map<String, dynamic> _activitySummary = {};

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _coinsController.text = widget.user.coinBalance.toString();
    _reputationController.text = widget.user.reputation.toString();
  }

  @override
  void dispose() {
    _coinsController.dispose();
    _reputationController.dispose();
    _banReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _userService.getUserDetails(widget.user.id),
        _userService.getUserActivitySummary(widget.user.id),
      ]);

      if (mounted) {
        setState(() {
          _userDetails = results[0];
          _activitySummary = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger().error('❌ Error loading user details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateCoins() async {
    final newBalance = int.tryParse(_coinsController.text);
    if (newBalance == null) {
      _showSnackBar('Invalid coin amount', Colors.red);
      return;
    }

    final confirmed = await _showConfirmDialog(
      'Update Coins',
      'Set ${widget.user.name}\'s coin balance to $newBalance?',
    );

    if (confirmed) {
      final success = await _userService.updateUserCoins(
        widget.user.id,
        newBalance,
      );
      if (success && mounted) {
        _showSnackBar('Coins updated successfully', Colors.green);
      }
    }
  }

  Future<void> _updateReputation() async {
    final newReputation = int.tryParse(_reputationController.text);
    if (newReputation == null) {
      _showSnackBar('Invalid reputation amount', Colors.red);
      return;
    }

    final confirmed = await _showConfirmDialog(
      'Update Reputation',
      'Set ${widget.user.name}\'s reputation to $newReputation?',
    );

    if (confirmed) {
      final success = await _userService.updateUserReputation(
        widget.user.id,
        newReputation,
      );
      if (success && mounted) {
        _showSnackBar('Reputation updated successfully', Colors.green);
      }
    }
  }

  Future<void> _banUser() async {
    if (_banReasonController.text.isEmpty) {
      _showSnackBar('Ban reason is required', Colors.red);
      return;
    }

    final confirmed = await _showConfirmDialog(
      'Ban User',
      'Are you sure you want to ban ${widget.user.name}?',
    );

    if (confirmed) {
      final success = await _userService.banUser(
        widget.user.id,
        _banReasonController.text,
      );
      if (success && mounted) {
        _showSnackBar('User banned successfully', Colors.green);
        Navigator.pop(context);
      }
    }
  }

  Future<void> _unbanUser() async {
    final confirmed = await _showConfirmDialog(
      'Unban User',
      'Are you sure you want to unban ${widget.user.name}?',
    );

    if (confirmed) {
      final success = await _userService.unbanUser(widget.user.id);
      if (success && mounted) {
        _showSnackBar('User unbanned successfully', Colors.green);
        Navigator.pop(context);
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Container(
      height: screenHeight * 0.8,
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        backgroundImage: (widget.user.avatar?.isNotEmpty ?? false)
                            ? NetworkImage(widget.user.avatar!)
                            : null,
                        child: (widget.user.avatar?.isEmpty ?? true)
                            ? Text(
                                widget.user.name.isNotEmpty
                                    ? widget.user.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'User ID: ${widget.user.id}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                            if (widget.user.isBanned)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red, width: 1),
                                ),
                                child: const Text(
                                  'BANNED',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Stats
                  _buildStatsSection(),
                  const SizedBox(height: 24),

                  // Activity Summary
                  _buildActivitySection(),
                  const SizedBox(height: 24),

                  // Admin Actions
                  _buildAdminActionsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsSection() {
    final debateCount = _userDetails['debateCount'] ?? 0;
    final challengesSent = _userDetails['challengesSent'] ?? 0;
    final challengesReceived = _userDetails['challengesReceived'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Debates', debateCount.toString(), Icons.gavel),
            _buildStatItem('Wins', widget.user.totalWins.toString(),
                Icons.emoji_events),
            _buildStatItem(
                'Losses', widget.user.totalLosses.toString(), Icons.trending_down),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
                'Challenges Sent', challengesSent.toString(), Icons.send),
            _buildStatItem('Challenges Rcvd', challengesReceived.toString(),
                Icons.inbox),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.orange, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySection() {
    final recentDebates = _activitySummary['recentDebates'] as List? ?? [];
    final totalDebates = _activitySummary['totalDebates'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity ($totalDebates total)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (recentDebates.isEmpty)
          Text(
            'No recent debates',
            style: TextStyle(color: Colors.grey[500]),
          )
        else
          ...recentDebates.take(5).map((debate) {
            final topic = debate['topic'] ?? 'Unknown Topic';
            final role = debate['role'] ?? 'unknown';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.fiber_manual_record,
                      size: 8, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      topic,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAdminActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Admin Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Update Coins
        TextField(
          controller: _coinsController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Coin Balance',
            labelStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.save, color: Colors.green),
              onPressed: _updateCoins,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Update Reputation
        TextField(
          controller: _reputationController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Reputation',
            labelStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.save, color: Colors.green),
              onPressed: _updateReputation,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Ban/Unban User
        if (!widget.user.isBanned) ...[
          TextField(
            controller: _banReasonController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Ban Reason',
              labelStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _banUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Ban User',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _unbanUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Unban User',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (widget.user.banReason?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              'Ban Reason: ${widget.user.banReason ?? ""}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
