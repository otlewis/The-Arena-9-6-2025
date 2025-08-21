import 'package:flutter/material.dart';
import '../services/content_moderation_service.dart';
import '../services/appwrite_service.dart';
import '../services/theme_service.dart';
import '../core/logging/app_logger.dart';

class ModerationActionDialog extends StatefulWidget {
  final Map<String, dynamic> report;
  final VoidCallback onActionTaken;

  const ModerationActionDialog({
    super.key,
    required this.report,
    required this.onActionTaken,
  });

  @override
  State<ModerationActionDialog> createState() => _ModerationActionDialogState();
}

class _ModerationActionDialogState extends State<ModerationActionDialog> {
  final ContentModerationService _moderationService = ContentModerationService();
  final AppwriteService _appwrite = AppwriteService();
  final ThemeService _themeService = ThemeService();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  
  String _selectedAction = 'mute';
  bool _isProcessing = false;

  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);


  final Map<String, IconData> _actionIcons = {
    'mute': Icons.volume_off,
    'kick': Icons.exit_to_app,
    'ban': Icons.block,
    'permanent_ban': Icons.gavel,
  };

  final Map<String, Color> _actionColors = {
    'mute': Colors.orange,
    'kick': Colors.blue,
    'ban': Colors.red,
    'permanent_ban': Colors.red[900]!,
  };

  @override
  void dispose() {
    _reasonController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: _themeService.isDarkMode 
              ? const Color(0xFF2D2D2D)
              : const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _themeService.isDarkMode 
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white.withValues(alpha: 0.7),
              offset: const Offset(-12, -12),
              blurRadius: 24,
            ),
            BoxShadow(
              color: _themeService.isDarkMode 
                  ? Colors.black.withValues(alpha: 0.6)
                  : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
              offset: const Offset(12, 12),
              blurRadius: 24,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildReportInfo(),
                const SizedBox(height: 16),
                _buildActionSelector(),
                const SizedBox(height: 12),
                _buildReasonField(),
                if (_selectedAction == 'mute' || _selectedAction == 'ban') ...[
                  const SizedBox(height: 12),
                  _buildDurationField(),
                ],
                const SizedBox(height: 20),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
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
          child: const Icon(
            Icons.gavel,
            color: scarletRed,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Take Moderation Action',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _themeService.isDarkMode ? Colors.white : deepPurple,
                ),
              ),
              Text(
                'Choose appropriate action for this report',
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
          icon: Icon(
            Icons.close,
            color: _themeService.isDarkMode ? Colors.white54 : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildReportInfo() {
    final reportType = widget.report['reportType'] ?? 'unknown';
    final description = widget.report['description'] ?? 'No description provided';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.black.withValues(alpha: 0.6)
                : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
            offset: const Offset(4, 4),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.report,
                color: scarletRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Report Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _themeService.isDarkMode ? Colors.white : deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Type: ${_formatReportType(reportType)}',
            style: TextStyle(
              fontSize: 14,
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Description: $description',
            style: TextStyle(
              fontSize: 14,
              color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reported User: ${widget.report['reportedUserId']?.substring(0, 12)}...',
            style: TextStyle(
              fontSize: 12,
              color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Action',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _themeService.isDarkMode ? Colors.white : deepPurple,
          ),
        ),
        const SizedBox(height: 12),
        ...['mute', 'kick', 'ban', 'permanent_ban'].map((action) {
          final isSelected = _selectedAction == action;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedAction = action),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _actionColors[action]!.withValues(alpha: 0.1)
                        : (_themeService.isDarkMode 
                            ? const Color(0xFF3A3A3A)
                            : const Color(0xFFF0F0F3)),
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected
                        ? Border.all(color: _actionColors[action]!, width: 2)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _actionIcons[action]!,
                        color: isSelected 
                            ? _actionColors[action]! 
                            : (_themeService.isDarkMode ? Colors.white54 : Colors.grey[600]),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          action.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected 
                                ? _actionColors[action]! 
                                : (_themeService.isDarkMode ? Colors.white : Colors.grey[800]),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: _actionColors[action]!,
                          size: 18,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildReasonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reason for Action',
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
                    ? Colors.black.withValues(alpha: 0.6)
                    : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                offset: const Offset(4, 4),
                blurRadius: 8,
                spreadRadius: -2,
              ),
            ],
          ),
          child: TextField(
            controller: _reasonController,
            maxLines: 1,
            maxLength: 150,
            style: TextStyle(
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Explain why this action is being taken...',
              hintStyle: TextStyle(
                color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[500],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duration (minutes)',
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
                    ? Colors.black.withValues(alpha: 0.6)
                    : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                offset: const Offset(4, 4),
                blurRadius: 8,
                spreadRadius: -2,
              ),
            ],
          ),
          child: TextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Enter duration in minutes (e.g., 30, 60, 1440)',
              hintStyle: TextStyle(
                color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[500],
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
          child: _buildNeumorphicButton(
            onPressed: () => Navigator.of(context).pop(),
            text: 'Cancel',
            isPrimary: false,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildNeumorphicButton(
            onPressed: _isProcessing ? null : _executeAction,
            text: _isProcessing ? 'Processing...' : 'Take Action',
            isPrimary: true,
          ),
        ),
      ],
    );
  }

  Widget _buildNeumorphicButton({
    required VoidCallback? onPressed,
    required String text,
    required bool isPrimary,
  }) {
    final isDisabled = onPressed == null;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: isPrimary && !isDisabled 
                ? scarletRed
                : (_themeService.isDarkMode 
                    ? const Color(0xFF3A3A3A)
                    : const Color(0xFFF0F0F3)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDisabled ? null : [
              BoxShadow(
                color: isPrimary
                    ? scarletRed.withValues(alpha: 0.3)
                    : (_themeService.isDarkMode 
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.white.withValues(alpha: 0.7)),
                offset: const Offset(-6, -6),
                blurRadius: 12,
              ),
              BoxShadow(
                color: isPrimary
                    ? scarletRed.withValues(alpha: 0.5)
                    : (_themeService.isDarkMode 
                        ? Colors.black.withValues(alpha: 0.5)
                        : const Color(0xFFA3B1C6).withValues(alpha: 0.5)),
                offset: const Offset(6, 6),
                blurRadius: 12,
              ),
            ],
          ),
          child: Center(
            child: _isProcessing && isPrimary
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isPrimary && !isDisabled 
                          ? Colors.white
                          : (_themeService.isDarkMode ? Colors.white70 : deepPurple),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _executeAction() async {
    if (_isProcessing) return;
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for this action'),
          backgroundColor: scarletRed,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      int? duration;
      if ((_selectedAction == 'mute' || _selectedAction == 'ban') && 
          _durationController.text.isNotEmpty) {
        duration = int.tryParse(_durationController.text);
        if (duration == null || duration <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid duration in minutes'),
              backgroundColor: scarletRed,
            ),
          );
          setState(() => _isProcessing = false);
          return;
        }
      }

      await _moderationService.takeAction(
        moderatorId: 'current_moderator_id', // Replace with actual moderator ID
        targetUserId: widget.report['reportedUserId'],
        action: _selectedAction,
        reason: _reasonController.text.trim(),
        reportId: widget.report['\$id'],
        durationMinutes: duration,
      );

      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'user_reports',
        documentId: widget.report['\$id'],
        data: {
          'status': 'resolved',
          'resolution': '${_selectedAction.toUpperCase()} issued by moderator',
          'moderatorId': 'current_moderator_id',
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onActionTaken();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedAction.toUpperCase()} action taken successfully'),
            backgroundColor: accentPurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppLogger().error('Failed to execute moderation action: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to take action. Please try again.'),
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
}