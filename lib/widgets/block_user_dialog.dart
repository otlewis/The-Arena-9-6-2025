import 'package:flutter/material.dart';
import '../services/content_moderation_service.dart';
import '../services/theme_service.dart';
import '../models/user_profile.dart';
import '../core/logging/app_logger.dart';

class BlockUserDialog extends StatefulWidget {
  final UserProfile userToBlock;
  final String currentUserId;

  const BlockUserDialog({
    super.key,
    required this.userToBlock,
    required this.currentUserId,
  });

  @override
  State<BlockUserDialog> createState() => _BlockUserDialogState();
}

class _BlockUserDialogState extends State<BlockUserDialog> {
  final ContentModerationService _moderationService = ContentModerationService();
  final ThemeService _themeService = ThemeService();
  final TextEditingController _reasonController = TextEditingController();
  
  bool _isBlocking = false;

  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildUserInfo(),
              const SizedBox(height: 20),
              _buildWarningText(),
              const SizedBox(height: 16),
              _buildReasonField(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
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
            Icons.block,
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
                'Block User',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _themeService.isDarkMode ? Colors.white : deepPurple,
                ),
              ),
              Text(
                'This will hide their content from you',
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
            backgroundColor: scarletRed.withValues(alpha: 0.2),
            child: Text(
              widget.userToBlock.initials,
              style: const TextStyle(
                color: scarletRed,
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
                  widget.userToBlock.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _themeService.isDarkMode ? Colors.white : deepPurple,
                  ),
                ),
                Text(
                  'You are about to block this user',
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

  Widget _buildWarningText() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scarletRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scarletRed.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: scarletRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'What happens when you block someone:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _themeService.isDarkMode ? Colors.white : deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• You won\'t see their messages or content\n'
            '• They won\'t be able to challenge you to debates\n'
            '• They won\'t see when you\'re online\n'
            '• You can unblock them anytime in settings',
            style: TextStyle(
              fontSize: 13,
              color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reason (optional)',
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
            controller: _reasonController,
            maxLines: 2,
            maxLength: 200,
            style: TextStyle(
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Why are you blocking this user? (for your own reference)',
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
            onPressed: _isBlocking ? null : _blockUser,
            text: _isBlocking ? 'Blocking...' : 'Block User',
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
    final buttonColor = isPrimary ? scarletRed : accentPurple;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: isPrimary && !isDisabled 
                ? buttonColor
                : (_themeService.isDarkMode 
                    ? const Color(0xFF3A3A3A)
                    : const Color(0xFFF0F0F3)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDisabled ? null : [
              BoxShadow(
                color: isPrimary
                    ? buttonColor.withValues(alpha: 0.3)
                    : (_themeService.isDarkMode 
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.white.withValues(alpha: 0.7)),
                offset: const Offset(-6, -6),
                blurRadius: 12,
              ),
              BoxShadow(
                color: isPrimary
                    ? buttonColor.withValues(alpha: 0.5)
                    : (_themeService.isDarkMode 
                        ? Colors.black.withValues(alpha: 0.5)
                        : const Color(0xFFA3B1C6).withValues(alpha: 0.5)),
                offset: const Offset(6, 6),
                blurRadius: 12,
              ),
            ],
          ),
          child: Center(
            child: _isBlocking && isPrimary
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

  Future<void> _blockUser() async {
    if (_isBlocking) return;

    setState(() => _isBlocking = true);

    try {
      await _moderationService.blockUser(
        widget.currentUserId,
        widget.userToBlock.id,
        reason: _reasonController.text.trim().isEmpty 
            ? null 
            : _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.userToBlock.displayName} has been blocked'),
            backgroundColor: accentPurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppLogger().error('Failed to block user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to block user. Please try again.'),
            backgroundColor: scarletRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBlocking = false);
      }
    }
  }
}