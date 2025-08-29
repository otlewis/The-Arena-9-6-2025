import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../services/content_moderation_service.dart';
import '../services/appwrite_service.dart';
import '../services/theme_service.dart';
import '../services/user_role_service.dart';
import '../core/logging/app_logger.dart';
import '../widgets/moderation_action_dialog.dart';
import 'appeals_management_screen.dart';

class ModerationDashboardScreen extends StatefulWidget {
  const ModerationDashboardScreen({super.key});

  @override
  State<ModerationDashboardScreen> createState() => _ModerationDashboardScreenState();
}

class _ModerationDashboardScreenState extends State<ModerationDashboardScreen> {
  final ContentModerationService _moderationService = ContentModerationService();
  final AppwriteService _appwrite = AppwriteService();
  final ThemeService _themeService = ThemeService();
  final UserRoleService _roleService = UserRoleService();
  
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _queueItems = [];
  bool _isLoading = true;
  bool _hasAccess = false;

  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final isModerator = await _roleService.isCurrentUserModerator();
      
      setState(() {
        _hasAccess = isModerator; // For now, only moderators have access
      });

      if (_hasAccess) {
        _loadModerationData();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger().error('Failed to check moderation access: $e');
      setState(() {
        _hasAccess = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadModerationData() async {
    try {
      setState(() => _isLoading = true);
      
      // Load user reports
      final reportsResponse = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'user_reports',
        queries: [
          Query.orderDesc('createdAt'),
          Query.limit(50),
        ],
      );
      
      // Load moderation queue
      final queueResponse = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'moderation_queue',
        queries: [
          Query.orderDesc('createdAt'),
          Query.limit(50),
        ],
      );
      
      if (mounted) {
        setState(() {
          _reports = reportsResponse.documents.map((doc) => doc.data).toList();
          _queueItems = queueResponse.documents.map((doc) => doc.data).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger().error('Failed to load moderation data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.isDarkMode 
          ? const Color(0xFF2D2D2D)
          : const Color(0xFFE8E8E8),
      appBar: AppBar(
        title: const Text(
          'Moderation Dashboard',
          style: TextStyle(
            color: deepPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _themeService.isDarkMode 
            ? const Color(0xFF2D2D2D)
            : const Color(0xFFE8E8E8),
        elevation: 0,
        iconTheme: const IconThemeData(color: scarletRed),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_turned_in),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AppealsManagementScreen()),
            ),
            tooltip: 'Appeals Management',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadModerationData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentPurple))
          : !_hasAccess
          ? _buildAccessDeniedScreen()
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: _themeService.isDarkMode ? Colors.white : deepPurple,
                    unselectedLabelColor: _themeService.isDarkMode ? Colors.white54 : Colors.grey,
                    indicatorColor: accentPurple,
                    tabs: [
                      Tab(text: 'Reports (${_reports.length})'),
                      Tab(text: 'Queue (${_queueItems.length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildReportsTab(),
                        _buildQueueTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAccessDeniedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              child: const Icon(
                Icons.security,
                size: 60,
                color: scarletRed,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Access Denied',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode ? Colors.white : deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You need moderator privileges to access the moderation dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    if (_reports.isEmpty) {
      return _buildEmptyState('No reports found', Icons.report_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (context, index) => _buildReportCard(_reports[index]),
    );
  }

  Widget _buildQueueTab() {
    if (_queueItems.isEmpty) {
      return _buildEmptyState('Moderation queue is empty', Icons.checklist);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _queueItems.length,
      itemBuilder: (context, index) => _buildQueueCard(_queueItems[index]),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
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
              icon,
              size: 48,
              color: _themeService.isDarkMode ? Colors.white24 : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final reportType = report['reportType'] ?? 'unknown';
    final status = report['status'] ?? 'pending';
    final createdAt = DateTime.tryParse(report['createdAt'] ?? '') ?? DateTime.now();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getReportIcon(reportType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatReportType(reportType),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _themeService.isDarkMode ? Colors.white : deepPurple,
                        ),
                      ),
                      Text(
                        'Reported ${_formatDate(createdAt)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            if (report['description'] != null && report['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _themeService.isDarkMode 
                      ? const Color(0xFF2D2D2D)
                      : const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  report['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Reporter: ${report['reporterId']?.substring(0, 8)}...',
                  style: TextStyle(
                    fontSize: 12,
                    color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[500],
                  ),
                ),
                const Spacer(),
                Text(
                  'Target: ${report['reportedUserId']?.substring(0, 8)}...',
                  style: TextStyle(
                    fontSize: 12,
                    color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[500],
                  ),
                ),
              ],
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      text: 'Dismiss',
                      icon: Icons.close,
                      color: Colors.grey,
                      onPressed: () => _dismissReport(report),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      text: 'Warning',
                      icon: Icons.warning,
                      color: Colors.orange,
                      onPressed: () => _takeAction(report, 'warning'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      text: 'Actions',
                      icon: Icons.gavel,
                      color: scarletRed,
                      onPressed: () => _showModerationActions(report),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQueueCard(Map<String, dynamic> queueItem) {
    final itemType = queueItem['itemType'] ?? 'unknown';
    final priority = queueItem['priority'] ?? 'medium';
    final createdAt = DateTime.tryParse(queueItem['createdAt'] ?? '') ?? DateTime.now();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(16),
        border: _getPriorityBorder(priority),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getPriorityIcon(priority),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatItemType(itemType),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _themeService.isDarkMode ? Colors.white : deepPurple,
                        ),
                      ),
                      Text(
                        'Added ${_formatDate(createdAt)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildPriorityChip(priority),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              queueItem['reason'] ?? 'No reason provided',
              style: TextStyle(
                fontSize: 14,
                color: _themeService.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getReportIcon(String reportType) {
    IconData icon;
    Color color;
    
    switch (reportType) {
      case 'harassment':
        icon = Icons.person_off;
        color = Colors.red;
        break;
      case 'spam':
        icon = Icons.block;
        color = Colors.orange;
        break;
      case 'hate_speech':
        icon = Icons.report_problem;
        color = Colors.red[700]!;
        break;
      case 'threat':
        icon = Icons.dangerous;
        color = Colors.red[900]!;
        break;
      case 'doxxing':
        icon = Icons.privacy_tip;
        color = Colors.purple;
        break;
      default:
        icon = Icons.flag;
        color = Colors.grey;
    }
    
    return Icon(icon, color: color, size: 24);
  }

  Widget _getPriorityIcon(String priority) {
    IconData icon;
    Color color;
    
    switch (priority) {
      case 'urgent':
        icon = Icons.priority_high;
        color = Colors.red;
        break;
      case 'high':
        icon = Icons.warning;
        color = Colors.orange;
        break;
      case 'medium':
        icon = Icons.info;
        color = Colors.blue;
        break;
      default:
        icon = Icons.low_priority;
        color = Colors.grey;
    }
    
    return Icon(icon, color: color, size: 24);
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'reviewing':
        color = Colors.blue;
        break;
      case 'resolved':
        color = Colors.green;
        break;
      case 'dismissed':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color color;
    switch (priority) {
      case 'urgent':
        color = Colors.red;
        break;
      case 'high':
        color = Colors.orange;
        break;
      case 'medium':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Border? _getPriorityBorder(String priority) {
    switch (priority) {
      case 'urgent':
        return Border.all(color: Colors.red, width: 2);
      case 'high':
        return Border.all(color: Colors.orange, width: 1);
      default:
        return null;
    }
  }

  String _formatReportType(String reportType) {
    switch (reportType) {
      case 'harassment':
        return 'Harassment or Bullying';
      case 'spam':
        return 'Spam or Unwanted Content';
      case 'hate_speech':
        return 'Hate Speech';
      case 'inappropriate':
        return 'Inappropriate Content';
      case 'threat':
        return 'Threats or Violence';
      case 'doxxing':
        return 'Sharing Private Information';
      case 'other':
        return 'Other Violation';
      default:
        return reportType;
    }
  }

  String _formatItemType(String itemType) {
    switch (itemType) {
      case 'user':
        return 'User Report';
      case 'message':
        return 'Message Content';
      case 'room':
        return 'Room Content';
      default:
        return itemType;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _dismissReport(Map<String, dynamic> report) async {
    try {
      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'user_reports',
        documentId: report['\$id'],
        data: {
          'status': 'dismissed',
          'resolution': 'Report dismissed by moderator',
          'moderatorId': 'current_moderator_id', // Replace with actual moderator ID
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      
      _loadModerationData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report dismissed'),
            backgroundColor: accentPurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppLogger().error('Failed to dismiss report: $e');
    }
  }

  Future<void> _takeAction(Map<String, dynamic> report, String action) async {
    try {
      await _moderationService.takeAction(
        moderatorId: 'current_moderator_id', // Replace with actual moderator ID
        targetUserId: report['reportedUserId'],
        action: action,
        reason: 'Action taken based on report: ${report['reportType']}',
        reportId: report['\$id'],
      );

      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'user_reports',
        documentId: report['\$id'],
        data: {
          'status': 'resolved',
          'resolution': '$action issued by moderator',
          'moderatorId': 'current_moderator_id',
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      
      _loadModerationData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${action.toUpperCase()} issued to user'),
            backgroundColor: accentPurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppLogger().error('Failed to take action: $e');
    }
  }

  Future<void> _showModerationActions(Map<String, dynamic> report) async {
    await showDialog(
      context: context,
      builder: (context) => ModerationActionDialog(
        report: report,
        onActionTaken: () {
          _loadModerationData();
        },
      ),
    );
  }
}