import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:appwrite/appwrite.dart';
import '../services/super_moderator_service.dart';
import '../services/appwrite_service.dart';
import '../models/user_profile.dart';
import '../models/super_moderator.dart';
import '../widgets/super_mod_badge.dart';
import '../core/logging/app_logger.dart';
import 'super_mod_management_screen.dart';

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
      _superMods = await _superModService.getAllSuperModerators();
      if (mounted) {
        setState(() {
          // Update UI with loaded super moderators
        });
      }
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
        if (action == 'ban') {
          _totalBans++;
        }
        if (action == 'kick') {
          _totalKicks++;
        }
      }

      if (mounted) {
        setState(() {
          // Update UI with loaded moderation statistics
        });
      }
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
            const Icon(Icons.shield, color: Color(0xFFFFD700), size: 20),
            const SizedBox(width: 6),
            const Flexible(
              child: Text(
                'Super Mod Dashboard',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 8),
            SuperModBadge(
              userId: _currentUser?.id ?? '',
              size: 14,
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
        itemCount: _superMods.length + (_superMods.isEmpty ? 2 : 1), // +1 for header, +1 for empty state if needed
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                _buildSectionHeader('Active Super Moderators', _superMods.length),
                const SizedBox(height: 16),
                // Add Manage Super Moderators button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SuperModManagementScreen(),
                      ),
                    ).then((_) {
                      // Refresh the list when returning
                      _loadSuperMods();
                    });
                  },
                  icon: const Icon(LucideIcons.userPlus, color: Colors.white),
                  label: const Text(
                    'Manage Super Moderators',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          }

          // Show empty state if no super mods
          if (_superMods.isEmpty && index == 1) {
            return Card(
              color: const Color(0xFF2D2D2D),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.shieldOff,
                      size: 48,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Super Moderators',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use the button above to add super moderators',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
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
                        ? Text(superMod.username.isNotEmpty
                            ? superMod.username.substring(0, 1).toUpperCase()
                            : '?')
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
          backgroundColor: color.withOpacity(0.2),
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
              backgroundColor: color.withOpacity(0.2),
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
    try {
      final reportId = report['\$id'] ?? report['id'];
      if (reportId == null) {
        throw Exception('Report ID not found');
      }

      final currentUser = await _appwriteService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Update report status
      await _appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'user_reports',
        documentId: reportId,
        data: {
          'status': action,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report has been $action'),
          backgroundColor: Colors.green,
        ),
      );

      _logger.info('📋 Report $reportId resolved with action: $action');
      await _loadReports();
    } catch (e) {
      _logger.error('Failed to resolve report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resolve report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takeAction(Map<String, dynamic> report, String action) async {
    try {
      final reportedUserId = report['reportedUserId'];
      final reportType = report['reportType'] ?? 'Unknown';

      if (reportedUserId == null) {
        throw Exception('Reported user ID not found');
      }

      switch (action) {
        case 'ban':
          // Show ban dialog with pre-filled information
          await _showBanDialogForReport(reportedUserId, reportType, report);
          break;
        case 'kick':
          // Show kick dialog with pre-filled information
          await _showKickDialogForReport(reportedUserId, reportType, report);
          break;
        case 'warn':
          await _sendWarningToUser(reportedUserId, reportType, report);
          break;
        default:
          throw Exception('Unknown action: $action');
      }

      // After taking action, resolve the report
      await _resolveReport(report, 'action_taken');
    } catch (e) {
      _logger.error('Failed to take action on report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to take action: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showBanDialogForReport(String userId, String reportType, Map<String, dynamic> report) async {
    final reasonController = TextEditingController(
      text: 'Reported for: $reportType - ${report['description'] ?? ''}',
    );
    String banType = 'temporary';
    int banDuration = 24;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Ban Reported User', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'User: $userId',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Ban reason',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.purple)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.purple)),
                  ),
                ),
                const SizedBox(height: 16),
                RadioListTile<String>(
                  title: const Text('Temporary', style: TextStyle(color: Colors.white)),
                  value: 'temporary',
                  groupValue: banType,
                  activeColor: Colors.purple,
                  onChanged: (value) => setState(() => banType = value!),
                ),
                RadioListTile<String>(
                  title: const Text('Permanent', style: TextStyle(color: Colors.white)),
                  value: 'permanent',
                  groupValue: banType,
                  activeColor: Colors.purple,
                  onChanged: (value) => setState(() => banType = value!),
                ),
                if (banType == 'temporary') ...[
                  Text('Duration: $banDuration hours', style: const TextStyle(color: Colors.white)),
                  Slider(
                    value: banDuration.toDouble(),
                    min: 1, max: 168,
                    divisions: 20,
                    activeColor: Colors.purple,
                    onChanged: (value) => setState(() => banDuration = value.round()),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Ban User', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _executeBan(userId, reasonController.text, banType, banDuration);
    }
  }

  Future<void> _showKickDialogForReport(String userId, String reportType, Map<String, dynamic> report) async {
    final rooms = await _loadActiveRooms();
    String? selectedRoomId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Kick Reported User', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('User: $userId', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Report: $reportType', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRoomId,
                  decoration: const InputDecoration(
                    labelText: 'Select Room',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.purple)),
                  ),
                  dropdownColor: const Color(0xFF2D2D2D),
                  style: const TextStyle(color: Colors.white),
                  items: rooms.map((room) => DropdownMenuItem<String>(
                    value: room['id'],
                    child: Text('${room['title']} (${room['type']})'),
                  )).toList(),
                  onChanged: (value) => setState(() => selectedRoomId = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: selectedRoomId != null ? () => Navigator.pop(context, true) : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Kick User', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedRoomId != null) {
      await _executeKick(userId, selectedRoomId!, 'Reported for: $reportType');
    }
  }

  Future<void> _sendWarningToUser(String userId, String reportType, Map<String, dynamic> report) async {
    try {
      // Send a warning notification/message to the user
      await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'user_warnings',
        documentId: 'unique()',
        data: {
          'userId': userId,
          'warningType': reportType,
          'reason': 'Reported for: $reportType - ${report['description'] ?? ''}',
          'issuedBy': 'Super Moderator',
          'issuedAt': DateTime.now().toIso8601String(),
          'status': 'active',
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Warning sent to user $userId'),
          backgroundColor: Colors.orange,
        ),
      );
      _logger.info('⚠️ Warning sent to user: $userId for: $reportType');
    } catch (e) {
      _logger.error('Failed to send warning: $e');
      rethrow;
    }
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
    final userController = TextEditingController();
    final reasonController = TextEditingController();
    String banType = 'temporary'; // 'temporary' or 'permanent'
    int banDuration = 24; // hours
    List<UserProfile> searchResults = [];
    UserProfile? selectedUser;
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Ban User',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 350,
            height: MediaQuery.of(context).size.height * 0.6, // Use 60% of screen height
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // User search
                TextField(
                  controller: userController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Search username',
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple),
                    ),
                    suffixIcon: isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(LucideIcons.search, color: Colors.grey),
                  ),
                  onChanged: (value) async {
                    if (value.trim().length >= 2) {
                      setState(() => isSearching = true);
                      try {
                        final results = await _appwriteService.searchUsersByUsername(value.trim());
                        setState(() {
                          searchResults = results;
                          isSearching = false;
                        });
                      } catch (e) {
                        setState(() => isSearching = false);
                      }
                    } else {
                      setState(() {
                        searchResults = [];
                        selectedUser = null;
                      });
                    }
                  },
                ),

                // Selected user display
                if (selectedUser != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: selectedUser!.avatar != null
                              ? NetworkImage(selectedUser!.avatar!)
                              : null,
                          child: selectedUser!.avatar == null
                              ? Text(selectedUser!.name.substring(0, 1).toUpperCase())
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedUser!.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'ID: ${selectedUser!.id}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: Colors.red, size: 16),
                          onPressed: () => setState(() {
                            selectedUser = null;
                            userController.clear();
                            searchResults = [];
                          }),
                        ),
                      ],
                    ),
                  ),
                ],

                // Search results
                if (searchResults.isNotEmpty && selectedUser == null) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade700),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final user = searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundImage: user.avatar != null
                                ? NetworkImage(user.avatar!)
                                : null,
                            child: user.avatar == null
                                ? Text(user.name.substring(0, 1).toUpperCase())
                                : null,
                          ),
                          title: Text(
                            user.name,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          subtitle: Text(
                            'ID: ${user.id}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          onTap: () => setState(() {
                            selectedUser = user;
                            userController.text = user.name;
                            searchResults = [];
                          }),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason for ban',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ban Type:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                RadioListTile<String>(
                  title: const Text('Temporary', style: TextStyle(color: Colors.white)),
                  value: 'temporary',
                  groupValue: banType,
                  activeColor: Colors.purple,
                  onChanged: (value) => setState(() => banType = value!),
                ),
                RadioListTile<String>(
                  title: const Text('Permanent', style: TextStyle(color: Colors.white)),
                  value: 'permanent',
                  groupValue: banType,
                  activeColor: Colors.purple,
                  onChanged: (value) => setState(() => banType = value!),
                ),
                if (banType == 'temporary') ...[
                  const SizedBox(height: 8),
                  Text(
                    'Duration: $banDuration hours',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Slider(
                    value: banDuration.toDouble(),
                    min: 1,
                    max: 168, // 7 days
                    divisions: 20,
                    activeColor: Colors.purple,
                    onChanged: (value) => setState(() => banDuration = value.round()),
                  ),
                ],
              ],
                ),
              ),
            ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a user to ban')),
                  );
                  return;
                }

                Navigator.pop(context);
                await _executeBan(
                  selectedUser!.id, // Use the actual user ID
                  reasonController.text.trim().isEmpty
                      ? 'Banned by Super Moderator'
                      : reasonController.text.trim(),
                  banType,
                  banType == 'temporary' ? banDuration : null,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Ban User', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showKickDialog() {
    final userController = TextEditingController();
    final reasonController = TextEditingController();
    String? selectedRoomId;
    List<Map<String, dynamic>> activeRooms = [];
    List<UserProfile> searchResults = [];
    UserProfile? selectedUser;
    bool isSearching = false;

    // Load active rooms
    _loadActiveRooms().then((rooms) {
      activeRooms = rooms;
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Kick User from Room',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User search
                TextField(
                  controller: userController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Search username',
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple),
                    ),
                    suffixIcon: isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(LucideIcons.search, color: Colors.grey),
                  ),
                  onChanged: (value) async {
                    if (value.trim().length >= 2) {
                      setState(() => isSearching = true);
                      try {
                        final results = await _appwriteService.searchUsersByUsername(value.trim());
                        setState(() {
                          searchResults = results;
                          isSearching = false;
                        });
                      } catch (e) {
                        setState(() => isSearching = false);
                      }
                    } else {
                      setState(() {
                        searchResults = [];
                        selectedUser = null;
                      });
                    }
                  },
                ),

                // Selected user display
                if (selectedUser != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: selectedUser!.avatar != null
                              ? NetworkImage(selectedUser!.avatar!)
                              : null,
                          child: selectedUser!.avatar == null
                              ? Text(selectedUser!.name.substring(0, 1).toUpperCase())
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedUser!.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'ID: ${selectedUser!.id}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: Colors.red, size: 16),
                          onPressed: () => setState(() {
                            selectedUser = null;
                            userController.clear();
                            searchResults = [];
                          }),
                        ),
                      ],
                    ),
                  ),
                ],

                // Search results
                if (searchResults.isNotEmpty && selectedUser == null) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade700),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final user = searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundImage: user.avatar != null
                                ? NetworkImage(user.avatar!)
                                : null,
                            child: user.avatar == null
                                ? Text(user.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 12))
                                : null,
                          ),
                          title: Text(
                            user.name,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          onTap: () => setState(() {
                            selectedUser = user;
                            userController.text = user.name;
                            searchResults = [];
                          }),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Select Room:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.purple),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedRoomId,
                      hint: const Text('Select a room...', style: TextStyle(color: Colors.grey)),
                      dropdownColor: const Color(0xFF2D2D2D),
                      style: const TextStyle(color: Colors.white),
                      isExpanded: true,
                      items: activeRooms.map((room) => DropdownMenuItem<String>(
                        value: room['id'],
                        child: Text(
                          '${room['title']} (${room['type']})',
                          style: const TextStyle(color: Colors.white),
                        ),
                      )).toList(),
                      onChanged: (value) => setState(() => selectedRoomId = value),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a user to kick')),
                  );
                  return;
                }
                if (selectedRoomId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a room')),
                  );
                  return;
                }

                Navigator.pop(context);
                await _executeKick(
                  selectedUser!.id, // Use the actual user ID
                  selectedRoomId!,
                  reasonController.text.trim().isEmpty
                      ? 'Kicked by Super Moderator'
                      : reasonController.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Kick User', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showMicLockDialog() {
    String? selectedRoomId;
    List<Map<String, dynamic>> activeRooms = [];
    bool lockMics = true;
    List<String> exemptUsers = [];
    final exemptUserController = TextEditingController();

    // Load active rooms
    _loadActiveRooms().then((rooms) {
      activeRooms = rooms;
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Lock/Unlock Microphones',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 350,
            height: MediaQuery.of(context).size.height * 0.55, // Use 55% of screen height
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Text(
                  'Select Room:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.purple),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedRoomId,
                      hint: const Text('Select a room...', style: TextStyle(color: Colors.grey)),
                      dropdownColor: const Color(0xFF2D2D2D),
                      style: const TextStyle(color: Colors.white),
                      isExpanded: true,
                      items: activeRooms.map((room) => DropdownMenuItem<String>(
                        value: room['id'],
                        child: Text(
                          '${room['title']} (${room['type']})',
                          style: const TextStyle(color: Colors.white),
                        ),
                      )).toList(),
                      onChanged: (value) => setState(() => selectedRoomId = value),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Action:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                RadioListTile<bool>(
                  title: const Text('Lock microphones', style: TextStyle(color: Colors.white)),
                  value: true,
                  groupValue: lockMics,
                  activeColor: Colors.purple,
                  onChanged: (value) => setState(() => lockMics = value!),
                ),
                RadioListTile<bool>(
                  title: const Text('Unlock microphones', style: TextStyle(color: Colors.white)),
                  value: false,
                  groupValue: lockMics,
                  activeColor: Colors.purple,
                  onChanged: (value) => setState(() => lockMics = value!),
                ),
                if (lockMics) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Exempt Users (optional):',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: exemptUserController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Add username...',
                            hintStyle: TextStyle(color: Colors.grey),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.purple),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.purple),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          final username = exemptUserController.text.trim();
                          if (username.isNotEmpty && !exemptUsers.contains(username)) {
                            setState(() {
                              exemptUsers.add(username);
                              exemptUserController.clear();
                            });
                          }
                        },
                        icon: const Icon(LucideIcons.plus, color: Colors.purple),
                      ),
                    ],
                  ),
                  if (exemptUsers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: exemptUsers.map((user) => Chip(
                        label: Text(user, style: const TextStyle(color: Colors.white)),
                        backgroundColor: Colors.purple.withOpacity(0.3),
                        deleteIcon: const Icon(LucideIcons.x, size: 16, color: Colors.white),
                        onDeleted: () => setState(() => exemptUsers.remove(user)),
                      )).toList(),
                    ),
                  ],
                ],
              ],
                ),
              ),
            ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedRoomId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a room')),
                  );
                  return;
                }

                Navigator.pop(context);
                await _executeMicLock(selectedRoomId!, lockMics, exemptUsers);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: lockMics ? Colors.purple : Colors.green,
              ),
              child: Text(
                lockMics ? 'Lock Mics' : 'Unlock Mics',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showCloseRoomDialog() {
    String? selectedRoomId;
    List<Map<String, dynamic>> activeRooms = [];
    final reasonController = TextEditingController();

    // Load active rooms
    _loadActiveRooms().then((rooms) {
      activeRooms = rooms;
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Close Room',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 300,
            height: MediaQuery.of(context).size.height * 0.5, // Use 50% of screen height
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Text(
                  'Select Room to Close:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.purple),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedRoomId,
                      hint: const Text('Select a room...', style: TextStyle(color: Colors.grey)),
                      dropdownColor: const Color(0xFF2D2D2D),
                      style: const TextStyle(color: Colors.white),
                      isExpanded: true,
                      items: activeRooms.map((room) => DropdownMenuItem<String>(
                        value: room['id'],
                        child: Text(
                          '${room['title']} (${room['type']}) - ${room['participants']} users',
                          style: const TextStyle(color: Colors.white),
                        ),
                      )).toList(),
                      onChanged: (value) => setState(() => selectedRoomId = value),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason for closing (optional)',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: const Row(
                    children: [
                      Icon(LucideIcons.alertTriangle, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will immediately close the room and remove all participants.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
                ),
              ),
            ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedRoomId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a room')),
                  );
                  return;
                }

                Navigator.pop(context);
                await _executeCloseRoom(
                  selectedRoomId!,
                  reasonController.text.trim().isEmpty
                      ? 'Room closed by Super Moderator'
                      : reasonController.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Close Room', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPromoteDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SuperModManagementScreen(),
      ),
    );
  }

  // Helper methods
  Future<List<Map<String, dynamic>>> _loadActiveRooms() async {
    try {
      final rooms = <Map<String, dynamic>>[];

      // Load Arena rooms
      final arenaResponse = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        queries: [
          Query.equal('status', 'active'),
          Query.limit(50),
        ],
      );

      for (final doc in arenaResponse.documents) {
        rooms.add({
          'id': doc.$id,
          'title': doc.data['roomName'] ?? 'Unknown Room',
          'type': 'Arena',
          'participants': doc.data['participantCount'] ?? 0,
        });
      }

      // Load Discussion rooms
      final discussionResponse = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'discussion_rooms',
        queries: [
          Query.equal('status', 'active'),
          Query.limit(50),
        ],
      );

      for (final doc in discussionResponse.documents) {
        rooms.add({
          'id': doc.$id,
          'title': doc.data['title'] ?? 'Unknown Room',
          'type': 'Discussion',
          'participants': doc.data['participantCount'] ?? 0,
        });
      }

      // Load Debate & Discussion rooms
      final debateResponse = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'debate_discussion_rooms',
        queries: [
          Query.equal('status', 'active'),
          Query.limit(50),
        ],
      );

      for (final doc in debateResponse.documents) {
        rooms.add({
          'id': doc.$id,
          'title': doc.data['title'] ?? 'Unknown Room',
          'type': 'Debate & Discussion',
          'participants': doc.data['participantCount'] ?? 0,
        });
      }

      return rooms;
    } catch (e) {
      _logger.error('Failed to load active rooms: $e');
      return [];
    }
  }

  // Execution methods
  Future<void> _executeBan(String userIdentifier, String reason, String banType, int? durationHours) async {
    try {
      final currentUser = await _appwriteService.getCurrentUser();
      if (currentUser == null) return;

      // Use SuperModeratorService ban method
      final success = await _superModService.banUserFromRoom(
        superModId: currentUser.$id,
        targetUserId: userIdentifier, // This should be resolved to actual user ID
        roomId: 'global', // Global ban affects all rooms
        roomType: 'all',
        reason: reason,
        durationMinutes: banType == 'temporary' ? (durationHours! * 60) : null,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User $userIdentifier has been ${banType == 'permanent' ? 'permanently' : 'temporarily'} banned'),
            backgroundColor: Colors.green,
          ),
        );
        _logger.info('🔨 Successfully banned user: $userIdentifier');
      } else {
        throw Exception('Ban operation failed');
      }
    } catch (e) {
      _logger.error('Failed to ban user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ban user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _executeKick(String userIdentifier, String roomId, String reason) async {
    try {
      final currentUser = await _appwriteService.getCurrentUser();
      if (currentUser == null) return;

      // Use SuperModeratorService kick method
      final success = await _superModService.kickUserFromRoom(
        superModId: currentUser.$id,
        targetUserId: userIdentifier, // This should be resolved to actual user ID
        roomId: roomId,
        reason: reason,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User $userIdentifier has been kicked from the room'),
            backgroundColor: Colors.green,
          ),
        );
        _logger.info('👢 Successfully kicked user: $userIdentifier from room: $roomId');
      } else {
        throw Exception('Kick operation failed');
      }
    } catch (e) {
      _logger.error('Failed to kick user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to kick user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _executeMicLock(String roomId, bool lock, List<String> exemptUsers) async {
    try {
      final currentUser = await _appwriteService.getCurrentUser();
      if (currentUser == null) return;

      // Use SuperModeratorService mic lock method
      final success = await _superModService.setMicrophoneLock(
        superModId: currentUser.$id,
        roomId: roomId,
        locked: lock,
        exemptUserIds: exemptUsers,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Microphones ${lock ? 'locked' : 'unlocked'} in room'),
            backgroundColor: Colors.green,
          ),
        );
        _logger.info('🔇 Successfully ${lock ? 'locked' : 'unlocked'} mics in room: $roomId');
      } else {
        throw Exception('Mic lock operation failed');
      }
    } catch (e) {
      _logger.error('Failed to ${lock ? 'lock' : 'unlock'} mics: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${lock ? 'lock' : 'unlock'} microphones: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _executeCloseRoom(String roomId, String reason) async {
    try {
      // Find the room and close it
      final rooms = await _loadActiveRooms();
      final room = rooms.firstWhere((r) => r['id'] == roomId, orElse: () => {});

      if (room.isEmpty) {
        throw Exception('Room not found');
      }

      String collectionId;
      switch (room['type']) {
        case 'Arena':
          collectionId = 'arena_rooms';
          break;
        case 'Discussion':
          collectionId = 'discussion_rooms';
          break;
        case 'Debate & Discussion':
          collectionId = 'debate_discussion_rooms';
          break;
        default:
          throw Exception('Unknown room type');
      }

      // Update room status to closed
      await _appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: collectionId,
        documentId: roomId,
        data: {
          'status': 'closed',
          'closedBy': 'Super Moderator',
          'closedReason': reason,
          'closedAt': DateTime.now().toIso8601String(),
        },
      );

      // Create room event to notify participants
      await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'room_events',
        documentId: 'unique()',
        data: {
          'type': 'room_closed',
          'roomId': roomId,
          'reason': reason,
          'closedBy': 'Super Moderator',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Room "${room['title']}" has been closed'),
          backgroundColor: Colors.green,
        ),
      );
      _logger.info('🚪 Successfully closed room: $roomId');
    } catch (e) {
      _logger.error('Failed to close room: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to close room: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}