import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:appwrite/appwrite.dart';
import '../services/super_moderator_service.dart';
import '../services/appwrite_service.dart';
import '../models/user_profile.dart';
import '../models/super_moderator.dart';
import '../widgets/super_mod_badge.dart';
import '../core/logging/app_logger.dart';

class SuperModDashboard extends StatefulWidget {
  const SuperModDashboard({super.key});
  
  @override
  State<SuperModDashboard> createState() => _SuperModDashboardState();
}

class _SuperModDashboardState extends State<SuperModDashboard> 
    with SingleTickerProviderStateMixin {
  final SuperModeratorService _superModService = SuperModeratorService();
  final AppwriteService _appwriteService = AppwriteService();
  final AppLogger _logger = AppLogger();
  
  late TabController _tabController;
  UserProfile? _currentUser;
  bool _isLoading = true;
  
  // Reports data
  List<Map<String, dynamic>> _pendingReports = [];
  List<Map<String, dynamic>> _resolvedReports = [];
  
  // Super Moderators list
  List<SuperModerator> _superMods = [];
  
  // Stats
  int _totalActionsToday = 0;
  int _totalBans = 0;
  int _totalKicks = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initialize();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _initialize() async {
    try {
      final user = await _appwriteService.getCurrentUser();
      if (user != null) {
        _currentUser = await _appwriteService.getUserProfile(user.$id);
        
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
      
      await _loadData();
    } catch (e) {
      _logger.error('Failed to initialize Super Mod Dashboard: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _loadData() async {
    await Future.wait([
      _loadReports(),
      _loadSuperMods(),
      _loadStats(),
    ]);
  }
  
  Future<void> _loadReports() async {
    try {
      // Load pending reports
      final pendingResponse = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'user_reports',
        queries: [
          Query.equal('status', 'pending'),
          Query.orderDesc('createdAt'),
        ],
      );
      
      // Load resolved reports
      final resolvedResponse = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'user_reports',
        queries: [
          Query.notEqual('status', 'pending'),
          Query.orderDesc('updatedAt'),
          Query.limit(50),
        ],
      );
      
      if (mounted) {
        setState(() {
          _pendingReports = pendingResponse.documents
              .map((doc) => doc.data)
              .toList();
          _resolvedReports = resolvedResponse.documents
              .map((doc) => doc.data)
              .toList();
        });
      }
    } catch (e) {
      _logger.error('Failed to load reports: $e');
    }
  }
  
  Future<void> _loadSuperMods() async {
    try {
      _superMods = _superModService.allSuperMods;
      if (mounted) setState(() {});
    } catch (e) {
      _logger.error('Failed to load super mods: $e');
    }
  }
  
  Future<void> _loadStats() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      // Load today's moderation actions
      final actionsResponse = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'moderation_actions',
        queries: [
          Query.greaterThanEqual('createdAt', startOfDay.toIso8601String()),
        ],
      );
      
      _totalActionsToday = actionsResponse.total;
      
      // Count bans and kicks
      for (final doc in actionsResponse.documents) {
        final action = doc.data['action'] as String?;
        if (action == 'ban') _totalBans++;
        if (action == 'kick') _totalKicks++;
      }
      
      if (mounted) setState(() {});
    } catch (e) {
      _logger.error('Failed to load stats: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.shield, color: Color(0xFFFFD700)),
            const SizedBox(width: 8),
            const Text('Super Moderator Dashboard'),
            const SizedBox(width: 12),
            SuperModBadge(
              userId: _currentUser?.id ?? '',
              size: 16,
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2D2D2D),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD700),
          tabs: const [
            Tab(text: 'Reports', icon: Icon(LucideIcons.alertTriangle)),
            Tab(text: 'Actions', icon: Icon(LucideIcons.gavel)),
            Tab(text: 'Super Mods', icon: Icon(LucideIcons.shield)),
            Tab(text: 'Stats', icon: Icon(LucideIcons.barChart)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportsTab(),
          _buildActionsTab(),
          _buildSuperModsTab(),
          _buildStatsTab(),
        ],
      ),
    );
  }
  
  Widget _buildReportsTab() {
    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Pending Reports', _pendingReports.length),
          if (_pendingReports.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text('No pending reports'),
                ),
              ),
            )
          else
            ..._pendingReports.map((report) => _buildReportCard(report, true)),
          
          const SizedBox(height: 24),
          
          _buildSectionHeader('Resolved Reports', _resolvedReports.length),
          if (_resolvedReports.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text('No resolved reports'),
                ),
              ),
            )
          else
            ..._resolvedReports.map((report) => _buildReportCard(report, false)),
        ],
      ),
    );
  }
  
  Widget _buildReportCard(Map<String, dynamic> report, bool isPending) {
    final reportType = report['reportType'] ?? 'Unknown';
    final description = report['description'] ?? '';
    final reportedUserId = report['reportedUserId'] ?? '';
    final createdAt = report['createdAt'] ?? '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isPending ? const Color(0xFF2D2D2D) : const Color(0xFF1F1F1F),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getReportTypeColor(reportType),
          child: Icon(
            _getReportTypeIcon(reportType),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          reportType,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: const TextStyle(color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'User: $reportedUserId • ${_formatDate(createdAt)}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: isPending
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.check, color: Colors.green),
                    onPressed: () => _resolveReport(report, 'resolved'),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.ban, color: Colors.red),
                    onPressed: () => _takeAction(report, 'ban'),
                  ),
                ],
              )
            : Chip(
                label: Text(
                  report['status'] ?? 'resolved',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: _getStatusColor(report['status']),
              ),
      ),
    );
  }
  
  Widget _buildActionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildQuickActionCard(
          'Ban User',
          'Temporarily or permanently ban a user',
          LucideIcons.ban,
          Colors.red,
          () => _showBanDialog(),
        ),
        _buildQuickActionCard(
          'Kick User',
          'Remove a user from current room',
          LucideIcons.userX,
          Colors.orange,
          () => _showKickDialog(),
        ),
        _buildQuickActionCard(
          'Lock Microphones',
          'Lock all mics in active rooms',
          LucideIcons.micOff,
          Colors.purple,
          () => _showMicLockDialog(),
        ),
        _buildQuickActionCard(
          'Close Room',
          'Force close an active room',
          LucideIcons.doorClosed,
          Colors.blue,
          () => _showCloseRoomDialog(),
        ),
        _buildQuickActionCard(
          'Promote Super Mod',
          'Grant Super Moderator privileges',
          LucideIcons.shield,
          const Color(0xFFFFD700),
          () => _showPromoteDialog(),
        ),
      ],
    );
  }
  
  Widget _buildSuperModsTab() {
    return RefreshIndicator(
      onRefresh: _loadSuperMods,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _superMods.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildSectionHeader('Active Super Moderators', _superMods.length),
            );
          }
          
          final superMod = _superMods[index - 1];
          return Card(
            color: const Color(0xFF2D2D2D),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    backgroundImage: superMod.profileImageUrl != null
                        ? NetworkImage(superMod.profileImageUrl!)
                        : null,
                    child: superMod.profileImageUrl == null
                        ? Text(superMod.username.substring(0, 1).toUpperCase())
                        : null,
                  ),
                  const Positioned(
                    right: -2,
                    top: -2,
                    child: Icon(
                      Icons.shield,
                      color: Color(0xFFFFD700),
                      size: 16,
                    ),
                  ),
                ],
              ),
              title: Text(
                superMod.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Granted: ${_formatDate(superMod.grantedAt.toIso8601String())}',
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: superMod.userId != _currentUser?.id
                  ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (value) {
                        if (value == 'revoke') {
                          _revokeSuperMod(superMod);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'revoke',
                          child: Text('Revoke Status'),
                        ),
                      ],
                    )
                  : const Chip(
                      label: Text('You'),
                      backgroundColor: Color(0xFFFFD700),
                    ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildStatsTab() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatCard(
            'Today\'s Actions',
            _totalActionsToday.toString(),
            LucideIcons.activity,
            Colors.blue,
          ),
          _buildStatCard(
            'Total Bans',
            _totalBans.toString(),
            LucideIcons.ban,
            Colors.red,
          ),
          _buildStatCard(
            'Total Kicks',
            _totalKicks.toString(),
            LucideIcons.userX,
            Colors.orange,
          ),
          _buildStatCard(
            'Active Super Mods',
            _superMods.length.toString(),
            LucideIcons.shield,
            const Color(0xFFFFD700),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      color: const Color(0xFF2D2D2D),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: const Icon(
          LucideIcons.chevronRight,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      color: const Color(0xFF2D2D2D),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getReportTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'harassment':
        return Colors.red;
      case 'spam':
        return Colors.orange;
      case 'inappropriate':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getReportTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'harassment':
        return LucideIcons.alertTriangle;
      case 'spam':
        return LucideIcons.messageSquare;
      case 'inappropriate':
        return LucideIcons.xOctagon;
      default:
        return LucideIcons.flag;
    }
  }
  
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'banned':
        return Colors.red;
      case 'warned':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
  
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
  
  // Action methods
  Future<void> _resolveReport(Map<String, dynamic> report, String action) async {
    // Implementation for resolving reports
    _logger.info('Resolving report with action: $action');
    await _loadReports();
  }
  
  Future<void> _takeAction(Map<String, dynamic> report, String action) async {
    // Implementation for taking action on reports
    _logger.info('Taking action on report: $action');
    await _loadReports();
  }
  
  Future<void> _revokeSuperMod(SuperModerator superMod) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Super Moderator'),
        content: Text('Remove Super Moderator status from ${superMod.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _superModService.revokeSuperModeratorStatus(
        superMod.userId,
        _currentUser?.id ?? 'system',
      );
      await _loadSuperMods();
    }
  }
  
  // Dialog methods
  void _showBanDialog() {
    // Implementation
  }
  
  void _showKickDialog() {
    // Implementation
  }
  
  void _showMicLockDialog() {
    // Implementation
  }
  
  void _showCloseRoomDialog() {
    // Implementation
  }
  
  void _showPromoteDialog() {
    // Implementation
  }
}