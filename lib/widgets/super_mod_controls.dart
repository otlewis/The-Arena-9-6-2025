import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/super_moderator_service.dart';
import '../models/user_profile.dart';
import '../models/super_moderator.dart';
import '../core/logging/app_logger.dart';

class SuperModControls extends StatefulWidget {
  final String roomId;
  final String roomType;
  final String currentUserId;
  final List<UserProfile> participants;
  final VoidCallback? onRoomClosed;
  final Function(String userId)? onUserKicked;
  final Function(String userId)? onUserBanned;
  
  const SuperModControls({
    super.key,
    required this.roomId,
    required this.roomType,
    required this.currentUserId,
    required this.participants,
    this.onRoomClosed,
    this.onUserKicked,
    this.onUserBanned,
  });
  
  @override
  State<SuperModControls> createState() => _SuperModControlsState();
}

class _SuperModControlsState extends State<SuperModControls> {
  final SuperModeratorService _superModService = SuperModeratorService();
  final AppLogger _logger = AppLogger();
  
  bool _microphoneLocked = false;
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    // Check if current user is a Super Moderator
    if (!_superModService.isSuperModerator(widget.currentUserId)) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFD700),
            Color(0xFFFFA500),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Super Moderator Controls',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildControlButton(
                icon: _microphoneLocked ? LucideIcons.micOff : LucideIcons.mic,
                label: _microphoneLocked ? 'Unlock Mics' : 'Lock All Mics',
                onTap: _toggleMicrophoneLock,
                color: _microphoneLocked ? Colors.red : Colors.green,
              ),
              _buildControlButton(
                icon: LucideIcons.doorClosed,
                label: 'Close Room',
                onTap: _closeRoom,
                color: Colors.red,
              ),
              _buildControlButton(
                icon: LucideIcons.userX,
                label: 'Kick User',
                onTap: _showKickUserDialog,
                color: Colors.orange,
              ),
              _buildControlButton(
                icon: LucideIcons.ban,
                label: 'Ban User',
                onTap: _showBanUserDialog,
                color: Colors.red,
              ),
              _buildControlButton(
                icon: LucideIcons.shield,
                label: 'Promote SM',
                onTap: _showPromoteSuperModDialog,
                color: const Color(0xFFFFD700),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
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
  
  Future<void> _toggleMicrophoneLock() async {
    setState(() => _isLoading = true);
    
    try {
      await _superModService.setMicrophoneLock(
        superModId: widget.currentUserId,
        roomId: widget.roomId,
        locked: !_microphoneLocked,
        exemptUserIds: [widget.currentUserId], // Exempt self from mic lock
      );
      
      setState(() => _microphoneLocked = !_microphoneLocked);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_microphoneLocked 
                ? '🔇 All microphones locked' 
                : '🎤 Microphones unlocked'),
            backgroundColor: _microphoneLocked ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      _logger.error('Failed to toggle microphone lock: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _closeRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Room'),
        content: const Text(
          'Are you sure you want to close this room? '
          'This will end the session for all participants.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Close Room'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() => _isLoading = true);
      
      try {
        if (_superModService.hasPermission(widget.currentUserId, SuperModPermissions.closeRooms)) {
          // Close the room through Appwrite (method to be implemented)
          // await _appwriteService.endDebateDiscussionRoom(widget.roomId);
          widget.onRoomClosed?.call();
          
          _logger.info('🚪 Room closed by Super Moderator');
        }
      } catch (e) {
        _logger.error('Failed to close room: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _showKickUserDialog() async {
    final selectedUser = await showDialog<UserProfile>(
      context: context,
      builder: (context) => _UserSelectionDialog(
        title: 'Kick User',
        participants: widget.participants
            .where((p) => p.id != widget.currentUserId && 
                         !_superModService.isSuperModerator(p.id))
            .toList(),
        actionLabel: 'Kick',
        actionColor: Colors.orange,
      ),
    );
    
    if (selectedUser != null) {
      await _kickUser(selectedUser);
    }
  }
  
  Future<void> _kickUser(UserProfile user) async {
    setState(() => _isLoading = true);
    
    try {
      await _superModService.kickUserFromRoom(
        superModId: widget.currentUserId,
        targetUserId: user.id,
        roomId: widget.roomId,
        reason: 'Kicked by Super Moderator',
      );
      
      widget.onUserKicked?.call(user.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('👢 ${user.name} has been kicked from the room'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      _logger.error('Failed to kick user: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _showBanUserDialog() async {
    final selectedUser = await showDialog<UserProfile>(
      context: context,
      builder: (context) => _UserSelectionDialog(
        title: 'Ban User',
        participants: widget.participants
            .where((p) => p.id != widget.currentUserId && 
                         !_superModService.isSuperModerator(p.id))
            .toList(),
        actionLabel: 'Ban',
        actionColor: Colors.red,
      ),
    );
    
    if (selectedUser != null) {
      await _banUser(selectedUser);
    }
  }
  
  Future<void> _banUser(UserProfile user) async {
    setState(() => _isLoading = true);
    
    try {
      await _superModService.banUserFromRoom(
        superModId: widget.currentUserId,
        targetUserId: user.id,
        roomId: widget.roomId,
        roomType: widget.roomType,
        reason: 'Banned by Super Moderator',
        durationMinutes: 60, // 1 hour ban by default
      );
      
      widget.onUserBanned?.call(user.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔨 User has been banned from the room'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      _logger.error('Failed to ban user: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _showPromoteSuperModDialog() async {
    final selectedUser = await showDialog<UserProfile>(
      context: context,
      builder: (context) => _UserSelectionDialog(
        title: 'Promote to Super Moderator',
        participants: widget.participants
            .where((p) => p.id != widget.currentUserId && 
                         !_superModService.isSuperModerator(p.id))
            .toList(),
        actionLabel: 'Promote',
        actionColor: const Color(0xFFFFD700),
      ),
    );
    
    if (selectedUser != null) {
      await _promoteSuperMod(selectedUser);
    }
  }
  
  Future<void> _promoteSuperMod(UserProfile user) async {
    setState(() => _isLoading = true);
    
    try {
      await _superModService.grantSuperModeratorStatus(
        userId: user.id,
        username: user.name,
        grantedBy: widget.currentUserId,
        profileImageUrl: user.avatar,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎖️ ${user.name} is now a Super Moderator'),
            backgroundColor: const Color(0xFFFFD700),
          ),
        );
      }
    } catch (e) {
      _logger.error('Failed to promote user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to promote user'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class _UserSelectionDialog extends StatelessWidget {
  final String title;
  final List<UserProfile> participants;
  final String actionLabel;
  final Color actionColor;
  
  const _UserSelectionDialog({
    required this.title,
    required this.participants,
    required this.actionLabel,
    required this.actionColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: participants.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No eligible users'),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  final user = participants[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.avatar != null
                          ? NetworkImage(user.avatar!)
                          : null,
                      child: user.avatar == null
                          ? Text(user.name.substring(0, 1).toUpperCase())
                          : null,
                    ),
                    title: Text(user.name),
                    subtitle: user.bio != null && user.bio!.isNotEmpty
                        ? Text(
                            user.bio!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    onTap: () => Navigator.pop(context, user),
                    trailing: TextButton(
                      onPressed: () => Navigator.pop(context, user),
                      style: TextButton.styleFrom(foregroundColor: actionColor),
                      child: Text(actionLabel),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}