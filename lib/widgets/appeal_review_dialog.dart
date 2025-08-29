import 'package:flutter/material.dart';
import '../services/appeal_service.dart';
import '../services/appwrite_service.dart';
import '../services/theme_service.dart';
import '../core/logging/app_logger.dart';

class AppealReviewDialog extends StatefulWidget {
  final Map<String, dynamic> appeal;
  final VoidCallback onDecisionMade;

  const AppealReviewDialog({
    super.key,
    required this.appeal,
    required this.onDecisionMade,
  });

  @override
  State<AppealReviewDialog> createState() => _AppealReviewDialogState();
}

class _AppealReviewDialogState extends State<AppealReviewDialog> {
  final AppealService _appealService = AppealService();
  final AppwriteService _appwrite = AppwriteService();
  final ThemeService _themeService = ThemeService();
  
  final TextEditingController _notesController = TextEditingController();
  Map<String, dynamic>? _moderationAction;
  bool _isLoading = true;
  bool _isProcessing = false;

  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void initState() {
    super.initState();
    _loadModerationAction();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadModerationAction() async {
    try {
      final action = await _appealService.getModerationAction(widget.appeal['moderationActionId']);
      if (mounted) {
        setState(() {
          _moderationAction = action;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger().error('Failed to load moderation action: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildAppealInfo(),
                const SizedBox(height: 20),
                if (!_isLoading) _buildModerationActionInfo(),
                const SizedBox(height: 20),
                _buildNotesSection(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentPurple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.gavel,
              color: accentPurple,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appeal Review',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode ? Colors.white : deepPurple,
                  ),
                ),
                Text(
                  'Review and make a decision on this appeal',
                  style: TextStyle(
                    fontSize: 14,
                    color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: scarletRed),
          ),
        ],
      ),
    );
  }

  Widget _buildAppealInfo() {
    final appealType = widget.appeal['appealType'] ?? 'unknown';
    final createdAt = DateTime.tryParse(widget.appeal['createdAt'] ?? '') ?? DateTime.now();
    final userId = widget.appeal['userId'] ?? '';
    
    return Container(
      padding: const EdgeInsets.all(16),
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
                      'User: ${userId.substring(0, 8)}... • ${_formatDate(createdAt)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Appeal Reason:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _themeService.isDarkMode ? Colors.white : deepPurple,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _themeService.isDarkMode 
                  ? const Color(0xFF2D2D2D)
                  : const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.appeal['reason'] ?? 'No reason provided',
              style: TextStyle(
                fontSize: 14,
                color: _themeService.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModerationActionInfo() {
    if (_moderationAction == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _themeService.isDarkMode 
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFF0F0F3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Unable to load moderation action details'),
      );
    }

    final action = _moderationAction!['action'] ?? 'Unknown';
    final reason = _moderationAction!['reason'] ?? 'No reason provided';
    final createdAt = DateTime.tryParse(_moderationAction!['createdAt'] ?? '') ?? DateTime.now();
    final duration = _moderationAction!['duration'];
    
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Original Moderation Action:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _themeService.isDarkMode ? Colors.white : deepPurple,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                _getActionIcon(action),
                color: _getActionColor(action),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _formatActionType(action),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              if (duration != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Applied ${_formatDate(createdAt)}',
            style: TextStyle(
              fontSize: 12,
              color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Reason: $reason',
            style: TextStyle(
              fontSize: 14,
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Moderator Notes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _themeService.isDarkMode ? Colors.white : deepPurple,
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
          child: TextField(
            controller: _notesController,
            maxLines: 4,
            style: TextStyle(
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Add notes about your decision (optional)...',
              hintStyle: TextStyle(
                color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Deny Appeal',
            Icons.close,
            scarletRed,
            () => _processAppeal('denied'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'Approve Appeal',
            Icons.check,
            Colors.green,
            () => _processAppeal('approved'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isProcessing ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _isProcessing ? Colors.grey.withValues(alpha: 0.3) : color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (_isProcessing ? Colors.grey : color).withValues(alpha: 0.3),
                offset: const Offset(0, 4),
                blurRadius: 8,
              ),
            ],
          ),
          child: _isProcessing
              ? const Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _processAppeal(String decision) async {
    try {
      setState(() => _isProcessing = true);

      final user = await _appwrite.getCurrentUser();
      if (user == null) {
        throw Exception('Moderator not authenticated');
      }

      final success = await _appealService.processAppeal(
        appealId: widget.appeal['id'],
        moderatorId: user.$id,
        decision: decision,
        moderatorNotes: _notesController.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Appeal ${decision == 'approved' ? 'approved' : 'denied'} successfully'),
              backgroundColor: decision == 'approved' ? Colors.green : scarletRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
          widget.onDecisionMade();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to process appeal. Please try again.'),
              backgroundColor: scarletRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger().error('Failed to process appeal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred. Please try again.'),
            backgroundColor: scarletRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
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