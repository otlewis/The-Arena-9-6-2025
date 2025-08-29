import 'package:flutter/material.dart';
import '../services/content_moderation_service.dart';
import '../services/theme_service.dart';
import '../models/user_profile.dart';
import '../core/logging/app_logger.dart';

class ReportUserDialog extends StatefulWidget {
  final UserProfile reportedUser;
  final String roomId;
  final String reporterId;
  final String? messageId;

  const ReportUserDialog({
    super.key,
    required this.reportedUser,
    required this.roomId,
    required this.reporterId,
    this.messageId,
  });

  @override
  State<ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<ReportUserDialog> {
  final ContentModerationService _moderationService = ContentModerationService();
  final ThemeService _themeService = ThemeService();
  final TextEditingController _descriptionController = TextEditingController();
  
  String _selectedReportType = 'harassment';
  bool _isSubmitting = false;

  final Map<String, String> _reportTypes = {
    'harassment': 'Harassment or bullying',
    'spam': 'Spam or unwanted content',
    'hate_speech': 'Hate speech or discrimination',
    'inappropriate': 'Inappropriate content',
    'threat': 'Threats or violence',
    'doxxing': 'Sharing private information',
    'other': 'Other violation',
  };

  final Map<String, IconData> _reportTypeIcons = {
    'harassment': Icons.person_off,
    'spam': Icons.block,
    'hate_speech': Icons.report_problem,
    'inappropriate': Icons.warning,
    'threat': Icons.dangerous,
    'doxxing': Icons.privacy_tip,
    'other': Icons.more_horiz,
  };

  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400, 
          maxHeight: MediaQuery.of(context).size.height * 0.85,
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
              const SizedBox(height: 20),
              _buildUserInfo(),
              const SizedBox(height: 20),
              _buildReportTypeSelector(),
              const SizedBox(height: 16),
              _buildDescriptionField(),
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
            Icons.report,
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
                'Report User',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _themeService.isDarkMode ? Colors.white : deepPurple,
                ),
              ),
              Text(
                'Help us keep Arena safe for everyone',
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

  Widget _buildUserInfo() {
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
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.white.withValues(alpha: 0.8),
            offset: const Offset(-4, -4),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: accentPurple.withValues(alpha: 0.2),
            child: Text(
              widget.reportedUser.initials,
              style: const TextStyle(
                color: accentPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.reportedUser.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _themeService.isDarkMode ? Colors.white : deepPurple,
                  ),
                ),
                Text(
                  'Reporting this user',
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
    );
  }

  Widget _buildReportTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reason for report',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _themeService.isDarkMode ? Colors.white : deepPurple,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            itemCount: _reportTypes.length,
            itemBuilder: (context, index) {
              final reportType = _reportTypes.keys.elementAt(index);
              final isSelected = _selectedReportType == reportType;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _selectedReportType = reportType),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentPurple.withValues(alpha: 0.1)
                            : (_themeService.isDarkMode 
                                ? const Color(0xFF3A3A3A)
                                : const Color(0xFFF0F0F3)),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: accentPurple, width: 2)
                            : null,
                        boxShadow: isSelected ? null : [
                          BoxShadow(
                            color: _themeService.isDarkMode 
                                ? Colors.black.withValues(alpha: 0.4)
                                : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                            spreadRadius: -1,
                          ),
                          BoxShadow(
                            color: _themeService.isDarkMode 
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.white.withValues(alpha: 0.7),
                            offset: const Offset(-2, -2),
                            blurRadius: 4,
                            spreadRadius: -1,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _reportTypeIcons[reportType]!,
                            color: isSelected ? accentPurple : (
                              _themeService.isDarkMode ? Colors.white54 : Colors.grey[600]
                            ),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _reportTypes[reportType]!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? accentPurple : (
                                  _themeService.isDarkMode ? Colors.white : Colors.grey[800]
                                ),
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: accentPurple,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional details (optional)',
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
              BoxShadow(
                color: _themeService.isDarkMode 
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.white.withValues(alpha: 0.8),
                offset: const Offset(-4, -4),
                blurRadius: 8,
                spreadRadius: -2,
              ),
            ],
          ),
          child: TextField(
            controller: _descriptionController,
            maxLines: 2,
            maxLength: 300,
            style: TextStyle(
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Provide more context about this report...',
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
            onPressed: _isSubmitting ? null : _submitReport,
            text: _isSubmitting ? 'Submitting...' : 'Submit Report',
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
                ? accentPurple
                : (_themeService.isDarkMode 
                    ? const Color(0xFF3A3A3A)
                    : const Color(0xFFF0F0F3)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDisabled ? null : [
              BoxShadow(
                color: isPrimary
                    ? accentPurple.withValues(alpha: 0.3)
                    : (_themeService.isDarkMode 
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.white.withValues(alpha: 0.7)),
                offset: const Offset(-6, -6),
                blurRadius: 12,
              ),
              BoxShadow(
                color: isPrimary
                    ? accentPurple.withValues(alpha: 0.5)
                    : (_themeService.isDarkMode 
                        ? Colors.black.withValues(alpha: 0.5)
                        : const Color(0xFFA3B1C6).withValues(alpha: 0.5)),
                offset: const Offset(6, 6),
                blurRadius: 12,
              ),
            ],
          ),
          child: Center(
            child: _isSubmitting && isPrimary
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

  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await _moderationService.reportUser(
        reporterId: widget.reporterId,
        reportedUserId: widget.reportedUser.id,
        roomId: widget.roomId,
        reportType: _selectedReportType,
        description: _descriptionController.text.trim().isEmpty 
            ? 'No additional details provided' 
            : _descriptionController.text.trim(),
        messageId: widget.messageId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully'),
            backgroundColor: accentPurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppLogger().error('Failed to submit report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit report. Please try again.'),
            backgroundColor: scarletRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}