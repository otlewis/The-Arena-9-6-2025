import 'package:flutter/material.dart';
import '../services/appeal_service.dart';
import '../services/appwrite_service.dart';
import '../services/theme_service.dart';
import '../core/logging/app_logger.dart';

class AppealSubmissionScreen extends StatefulWidget {
  final String? moderationActionId;
  
  const AppealSubmissionScreen({
    super.key,
    this.moderationActionId,
  });

  @override
  State<AppealSubmissionScreen> createState() => _AppealSubmissionScreenState();
}

class _AppealSubmissionScreenState extends State<AppealSubmissionScreen> {
  final AppealService _appealService = AppealService();
  final AppwriteService _appwrite = AppwriteService();
  final ThemeService _themeService = ThemeService();
  
  final TextEditingController _reasonController = TextEditingController();
  String _selectedAppealType = 'ban_appeal';
  List<Map<String, dynamic>> _userModerationActions = [];
  String? _selectedActionId;
  bool _isLoading = false;
  bool _isSubmitting = false;

  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  final List<Map<String, String>> _appealTypes = [
    {'value': 'ban_appeal', 'label': 'Appeal Ban', 'description': 'Request removal of account ban'},
    {'value': 'mute_appeal', 'label': 'Appeal Mute', 'description': 'Request removal of voice/chat restrictions'},
    {'value': 'kick_appeal', 'label': 'Appeal Kick', 'description': 'Appeal removal from room or platform'},
    {'value': 'warning_appeal', 'label': 'Appeal Warning', 'description': 'Contest issued warning'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserModerationActions();
    if (widget.moderationActionId != null) {
      _selectedActionId = widget.moderationActionId;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadUserModerationActions() async {
    try {
      setState(() => _isLoading = true);
      
      final user = await _appwrite.getCurrentUser();
      if (user != null) {
        final actions = await _appealService.getUserModerationActions(user.$id);
        if (mounted) {
          setState(() {
            _userModerationActions = actions;
            if (actions.isNotEmpty && _selectedActionId == null) {
              _selectedActionId = actions.first['id'];
            }
          });
        }
      }
    } catch (e) {
      AppLogger().error('Failed to load user moderation actions: $e');
    } finally {
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
          'Submit Appeal',
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentPurple))
          : _userModerationActions.isEmpty
          ? _buildNoActionsState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  _buildModerationActionSelector(),
                  const SizedBox(height: 24),
                  _buildAppealTypeSelector(),
                  const SizedBox(height: 24),
                  _buildReasonSection(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildNoActionsState() {
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
                Icons.check_circle,
                size: 60,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Active Actions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode ? Colors.white : deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You don\'t have any active moderation actions to appeal.',
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

  Widget _buildInfoCard() {
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
          const Icon(Icons.info, color: accentPurple, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appeal Process',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _themeService.isDarkMode ? Colors.white : deepPurple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submit an appeal to request review of a moderation action. Appeals are reviewed by moderators within 48 hours.',
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

  Widget _buildModerationActionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Moderation Action',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _themeService.isDarkMode ? Colors.white : deepPurple,
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
          child: DropdownButtonFormField<String>(
            initialValue: _selectedActionId,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            dropdownColor: _themeService.isDarkMode 
                ? const Color(0xFF3A3A3A)
                : const Color(0xFFF0F0F3),
            style: TextStyle(
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
            ),
            items: _userModerationActions.map((action) {
              final actionType = action['action'] ?? 'Unknown';
              final createdAt = DateTime.tryParse(action['createdAt'] ?? '') ?? DateTime.now();
              final reason = action['reason'] ?? 'No reason provided';
              
              return DropdownMenuItem<String>(
                value: action['id'],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatActionType(actionType),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Applied ${_formatDate(createdAt)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      reason.length > 50 ? '${reason.substring(0, 50)}...' : reason,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedActionId = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAppealTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Appeal Type',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _themeService.isDarkMode ? Colors.white : deepPurple,
          ),
        ),
        const SizedBox(height: 12),
        ..._appealTypes.map((type) => _buildAppealTypeOption(type)),
      ],
    );
  }

  Widget _buildAppealTypeOption(Map<String, String> type) {
    final isSelected = _selectedAppealType == type['value'];
    
    return GestureDetector(
      onTap: () => setState(() => _selectedAppealType = type['value']!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _themeService.isDarkMode 
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFF0F0F3),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: accentPurple, width: 2) : null,
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
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? accentPurple : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type['label']!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _themeService.isDarkMode ? Colors.white : deepPurple,
                    ),
                  ),
                  Text(
                    type['description']!,
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
      ),
    );
  }

  Widget _buildReasonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reason for Appeal *',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _themeService.isDarkMode ? Colors.white : deepPurple,
          ),
        ),
        const SizedBox(height: 12),
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
            controller: _reasonController,
            maxLines: 6,
            style: TextStyle(
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Explain why you believe this moderation action was incorrect or unfair...',
              hintStyle: TextStyle(
                color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Be specific and provide any relevant context. Appeals with detailed explanations are more likely to be approved.',
          style: TextStyle(
            fontSize: 12,
            color: _themeService.isDarkMode ? Colors.white54 : Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting || _reasonController.text.trim().isEmpty || _selectedActionId == null
            ? null
            : _submitAppeal,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Submit Appeal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _submitAppeal() async {
    if (_selectedActionId == null || _reasonController.text.trim().isEmpty) {
      return;
    }

    try {
      setState(() => _isSubmitting = true);

      final user = await _appwrite.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if user can submit appeal for this action
      final canAppeal = await _appealService.canUserAppeal(
        userId: user.$id,
        moderationActionId: _selectedActionId!,
      );

      if (!canAppeal) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have a pending appeal for this action'),
              backgroundColor: scarletRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final success = await _appealService.submitAppeal(
        userId: user.$id,
        moderationActionId: _selectedActionId!,
        reason: _reasonController.text.trim(),
        appealType: _selectedAppealType,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appeal submitted successfully! You will be notified of the decision.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to submit appeal. Please try again.'),
              backgroundColor: scarletRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger().error('Failed to submit appeal: $e');
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatActionType(String actionType) {
    switch (actionType) {
      case 'ban':
        return 'Account Ban';
      case 'mute':
        return 'Voice/Chat Mute';
      case 'kick':
        return 'Room Kick';
      case 'warning':
        return 'Warning Issued';
      default:
        return actionType;
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