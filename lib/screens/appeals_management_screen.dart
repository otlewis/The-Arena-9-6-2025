import 'package:flutter/material.dart';
import '../services/appeal_service.dart';
import '../services/theme_service.dart';
import '../services/user_role_service.dart';
import '../core/logging/app_logger.dart';
import '../widgets/appeal_review_dialog.dart';

class AppealsManagementScreen extends StatefulWidget {
  const AppealsManagementScreen({super.key});

  @override
  State<AppealsManagementScreen> createState() => _AppealsManagementScreenState();
}

class _AppealsManagementScreenState extends State<AppealsManagementScreen> {
  final AppealService _appealService = AppealService();
  final ThemeService _themeService = ThemeService();
  final UserRoleService _roleService = UserRoleService();
  
  List<Map<String, dynamic>> _appeals = [];
  bool _isLoading = true;
  bool _isModerator = false;
  String _selectedTab = 'pending';

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
      
      setState(() => _isModerator = isModerator);

      if (isModerator) {
        _loadAppeals();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger().error('Failed to check moderator access: $e');
      setState(() {
        _isModerator = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAppeals() async {
    try {
      setState(() => _isLoading = true);
      
      List<Map<String, dynamic>> appeals;
      if (_selectedTab == 'pending') {
        appeals = await _appealService.getPendingAppeals();
      } else {
        appeals = await _appealService.getAllAppeals();
      }
      
      if (mounted) {
        setState(() {
          _appeals = appeals;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger().error('Failed to load appeals: $e');
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
          'Appeals Management',
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadAppeals,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentPurple))
          : !_isModerator
          ? _buildAccessDeniedScreen()
          : Column(
              children: [
                _buildTabBar(),
                Expanded(child: _buildAppealsList()),
              ],
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
              'You need moderator privileges to access appeals management.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white.withValues(alpha: 0.8),
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
      child: Row(
        children: [
          _buildTabButton('Pending', 'pending'),
          _buildTabButton('All Appeals', 'all'),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, String value) {
    final isSelected = _selectedTab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = value);
          _loadAppeals();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? accentPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : (_themeService.isDarkMode ? Colors.white70 : Colors.grey[600]),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppealsList() {
    if (_appeals.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _appeals.length,
      itemBuilder: (context, index) => _buildAppealCard(_appeals[index]),
    );
  }

  Widget _buildEmptyState() {
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
              Icons.assignment_turned_in,
              size: 48,
              color: _themeService.isDarkMode ? Colors.white24 : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _selectedTab == 'pending' ? 'No Pending Appeals' : 'No Appeals Found',
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

  Widget _buildAppealCard(Map<String, dynamic> appeal) {
    final appealType = appeal['appealType'] ?? 'unknown';
    final status = appeal['status'] ?? 'pending';
    final createdAt = DateTime.tryParse(appeal['createdAt'] ?? '') ?? DateTime.now();
    final userId = appeal['userId'] ?? '';
    
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
                _getAppealTypeIcon(appealType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatAppealType(appealType),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _themeService.isDarkMode ? Colors.white : deepPurple,
                        ),
                      ),
                      Text(
                        'Submitted ${_formatDate(createdAt)}',
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
                appeal['reason'] ?? 'No reason provided',
                style: TextStyle(
                  fontSize: 14,
                  color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'User: ${userId.substring(0, 8)}...',
                  style: TextStyle(
                    fontSize: 12,
                    color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[500],
                  ),
                ),
                const Spacer(),
                if (status == 'pending') ...[
                  _buildActionButton(
                    'Review',
                    Icons.visibility,
                    accentPurple,
                    () => _reviewAppeal(appeal),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getAppealTypeIcon(String appealType) {
    IconData icon;
    Color color;
    
    switch (appealType) {
      case 'ban_appeal':
        icon = Icons.block;
        color = Colors.red;
        break;
      case 'mute_appeal':
        icon = Icons.volume_off;
        color = Colors.orange;
        break;
      case 'kick_appeal':
        icon = Icons.exit_to_app;
        color = Colors.blue;
        break;
      case 'warning_appeal':
        icon = Icons.warning;
        color = Colors.yellow;
        break;
      default:
        icon = Icons.help;
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
      case 'approved':
        color = Colors.green;
        break;
      case 'denied':
        color = Colors.red;
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

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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

  String _formatAppealType(String appealType) {
    switch (appealType) {
      case 'ban_appeal':
        return 'Ban Appeal';
      case 'mute_appeal':
        return 'Mute Appeal';
      case 'kick_appeal':
        return 'Kick Appeal';
      case 'warning_appeal':
        return 'Warning Appeal';
      default:
        return appealType;
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

  Future<void> _reviewAppeal(Map<String, dynamic> appeal) async {
    await showDialog(
      context: context,
      builder: (context) => AppealReviewDialog(
        appeal: appeal,
        onDecisionMade: () {
          _loadAppeals();
        },
      ),
    );
  }
}