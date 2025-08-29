import 'package:flutter/material.dart';
import '../screens/moderation_dashboard_screen.dart';
import '../services/theme_service.dart';
import '../services/user_role_service.dart';

class ModerationAccessIcon extends StatefulWidget {
  final bool showBadge;
  final int reportCount;
  
  const ModerationAccessIcon({
    super.key,
    this.showBadge = false,
    this.reportCount = 0,
  });

  @override
  State<ModerationAccessIcon> createState() => _ModerationAccessIconState();
}

class _ModerationAccessIconState extends State<ModerationAccessIcon> {
  final UserRoleService _roleService = UserRoleService();
  bool _isModerator = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkModeratorStatus();
  }

  Future<void> _checkModeratorStatus() async {
    try {
      final isModerator = await _roleService.isCurrentUserModerator();
      if (mounted) {
        setState(() {
          _isModerator = isModerator;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isModerator = false;
          _isLoading = false;
        });
      }
    }
  }

  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color scarletRed = Color(0xFFFF2400);

  @override
  Widget build(BuildContext context) {
    // Don't show anything while loading or if user is not a moderator
    if (_isLoading || !_isModerator) {
      return const SizedBox.shrink();
    }

    final ThemeService themeService = ThemeService();
    
    return IconButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ModerationDashboardScreen(),
          ),
        );
      },
      icon: Stack(
        children: [
          Icon(
            Icons.gavel,
            color: themeService.isDarkMode ? Colors.white : accentPurple,
          ),
          if (widget.showBadge && widget.reportCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: scarletRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  widget.reportCount > 99 ? '99+' : widget.reportCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      tooltip: 'Moderation Dashboard${widget.showBadge && widget.reportCount > 0 ? ' (${widget.reportCount} new)' : ''}',
    );
  }
}