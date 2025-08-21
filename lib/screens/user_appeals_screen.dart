import 'package:flutter/material.dart';
import '../services/appeal_service.dart';
import '../services/appwrite_service.dart';
import '../services/theme_service.dart';
import '../core/logging/app_logger.dart';
import 'appeal_submission_screen.dart';

class UserAppealsScreen extends StatefulWidget {
  const UserAppealsScreen({super.key});

  @override
  State<UserAppealsScreen> createState() => _UserAppealsScreenState();
}

class _UserAppealsScreenState extends State<UserAppealsScreen> {
  final AppealService _appealService = AppealService();
  final AppwriteService _appwrite = AppwriteService();
  final ThemeService _themeService = ThemeService();
  
  List<Map<String, dynamic>> _appeals = [];
  List<Map<String, dynamic>> _moderationActions = [];
  bool _isLoading = true;

  static const Color scarletRed = Color(0xFFFF2400);
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
      
      final user = await _appwrite.getCurrentUser();
      if (user != null) {
        final appeals = await _appealService.getUserAppeals(user.$id);
        final actions = await _appealService.getUserModerationActions(user.$id);
        
        if (mounted) {
          setState(() {
            _appeals = appeals;
            _moderationActions = actions;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      AppLogger().error('Failed to load user data: $e');
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
          'My Appeals',
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
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AppealSubmissionScreen()),
            ).then((_) => _loadUserData()),
            tooltip: 'Submit New Appeal',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentPurple))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModerationActionsSection(),
                  const SizedBox(height: 24),
                  _buildAppealsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildModerationActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Moderation Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _themeService.isDarkMode ? Colors.white : deepPurple,
          ),
        ),
        const SizedBox(height: 12),
        if (_moderationActions.isEmpty)
          _buildEmptyCard('No active moderation actions', Icons.check_circle, Colors.green)
        else
          ..._moderationActions.map((action) => _buildModerationActionCard(action)),
      ],
    );
  }

  Widget _buildAppealsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'My Appeals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode ? Colors.white : deepPurple,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AppealSubmissionScreen()),
              ).then((_) => _loadUserData()),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Submit Appeal'),
              style: TextButton.styleFrom(
                foregroundColor: accentPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_appeals.isEmpty)
          _buildEmptyCard('No appeals submitted', Icons.assignment, Colors.grey)
        else
          ..._appeals.map((appeal) => _buildAppealCard(appeal)),
      ],
    );
  }

  Widget _buildEmptyCard(String message, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModerationActionCard(Map<String, dynamic> action) {
    final actionType = action['action'] ?? 'Unknown';
    final reason = action['reason'] ?? 'No reason provided';
    final createdAt = DateTime.tryParse(action['createdAt'] ?? '') ?? DateTime.now();
    final duration = action['duration'];
    final status = action['status'] ?? 'active';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getActionColor(actionType), width: 1),
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
                Icon(
                  _getActionIcon(actionType),
                  color: _getActionColor(actionType),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatActionType(actionType),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _themeService.isDarkMode ? Colors.white : deepPurple,
                        ),
                      ),
                      Text(
                        'Applied ${_formatDate(createdAt)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (duration != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${duration}h',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
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
                'Reason: $reason',
                style: TextStyle(
                  fontSize: 14,
                  color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildAppealButton(action),
          ],
        ),
      ),
    );
  }

  Widget _buildAppealCard(Map<String, dynamic> appeal) {
    final appealType = appeal['appealType'] ?? 'unknown';
    final status = appeal['status'] ?? 'pending';
    final createdAt = DateTime.tryParse(appeal['createdAt'] ?? '') ?? DateTime.now();
    final reviewedAt = appeal['reviewedAt'] != null 
        ? DateTime.tryParse(appeal['reviewedAt']) 
        : null;
    
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
                _buildAppealStatusChip(status),
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
            if (reviewedAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    status == 'approved' ? Icons.check_circle : Icons.cancel,
                    color: status == 'approved' ? Colors.green : scarletRed,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reviewed ${_formatDate(reviewedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
            if (appeal['moderatorNotes'] != null && appeal['moderatorNotes'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _themeService.isDarkMode 
                      ? const Color(0xFF2D2D2D).withValues(alpha: 0.5)
                      : const Color(0xFFE8E8E8).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _themeService.isDarkMode ? Colors.white12 : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Moderator Notes:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appeal['moderatorNotes'],
                      style: TextStyle(
                        fontSize: 12,
                        color: _themeService.isDarkMode ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppealButton(Map<String, dynamic> action) {
    return FutureBuilder<bool>(
      future: _canUserAppeal(action['id']),
      builder: (context, snapshot) {
        final canAppeal = snapshot.data ?? false;
        final hasExistingAppeal = _appeals.any((appeal) => 
          appeal['moderationActionId'] == action['id'] && appeal['status'] == 'pending');
        
        if (hasExistingAppeal) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pending, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Text(
                  'Appeal Pending',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }
        
        if (!canAppeal) {
          return const SizedBox.shrink();
        }
        
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppealSubmissionScreen(moderationActionId: action['id']),
              ),
            ).then((_) => _loadUserData()),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accentPurple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentPurple),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gavel, color: accentPurple, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Submit Appeal',
                    style: TextStyle(
                      color: accentPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _canUserAppeal(String moderationActionId) async {
    try {
      final user = await _appwrite.getCurrentUser();
      if (user == null) return false;
      
      return await _appealService.canUserAppeal(
        userId: user.$id,
        moderationActionId: moderationActionId,
      );
    } catch (e) {
      return false;
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'active':
        color = Colors.red;
        break;
      case 'expired':
        color = Colors.grey;
        break;
      case 'revoked':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
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

  Widget _buildAppealStatusChip(String status) {
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

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'ban':
        return Icons.block;
      case 'mute':
        return Icons.volume_off;
      case 'kick':
        return Icons.exit_to_app;
      case 'warning':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'ban':
        return Colors.red;
      case 'mute':
        return Colors.orange;
      case 'kick':
        return Colors.blue;
      case 'warning':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
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

  String _formatActionType(String action) {
    switch (action) {
      case 'ban':
        return 'Account Ban';
      case 'mute':
        return 'Voice/Chat Mute';
      case 'kick':
        return 'Room Kick';
      case 'warning':
        return 'Warning Issued';
      default:
        return action;
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
}