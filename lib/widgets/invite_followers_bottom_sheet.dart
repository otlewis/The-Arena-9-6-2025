import 'package:flutter/material.dart';
import '../core/logging/app_logger.dart';
import '../models/user_profile.dart';
import '../services/appwrite_service.dart';
import '../services/follower_invitation_service.dart';

class InviteFollowersBottomSheet extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String roomType;
  final String currentUserId;
  final String currentUserName;

  const InviteFollowersBottomSheet({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<InviteFollowersBottomSheet> createState() => _InviteFollowersBottomSheetState();
}

class _InviteFollowersBottomSheetState extends State<InviteFollowersBottomSheet> {
  final AppwriteService _appwrite = AppwriteService();
  final FollowerInvitationService _invitationService = FollowerInvitationService();

  List<UserProfile> _followers = [];
  Set<String> _selectedFollowerIds = {};
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final followers = await _appwrite.getUserFollowers(widget.currentUserId);

      if (mounted) {
        setState(() {
          _followers = followers;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger().error('Failed to load followers: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load followers';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleFollower(String followerId) {
    setState(() {
      if (_selectedFollowerIds.contains(followerId)) {
        _selectedFollowerIds.remove(followerId);
      } else {
        _selectedFollowerIds.add(followerId);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedFollowerIds.length == _followers.length) {
        _selectedFollowerIds.clear();
      } else {
        _selectedFollowerIds = _followers.map((f) => f.id).toSet();
      }
    });
  }

  Future<void> _sendInvitations() async {
    if (_selectedFollowerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one follower')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final result = await _invitationService.inviteFollowersToRoom(
        roomId: widget.roomId,
        roomName: widget.roomName,
        roomType: widget.roomType,
        inviterUserId: widget.currentUserId,
        inviterName: widget.currentUserName,
        followerIds: _selectedFollowerIds.toList(),
      );

      if (mounted) {
        setState(() => _isSending = false);

        if (result['success'] == true) {
          final successCount = result['successCount'] ?? 0;
          final failedCount = result['failedCount'] ?? 0;
          final rateLimitedCount = result['rateLimitedCount'] ?? 0;

          String message = 'Sent $successCount invitation${successCount == 1 ? '' : 's'}';
          if (failedCount > 0) {
            message += ', $failedCount failed';
          }
          if (rateLimitedCount > 0) {
            message += ' ($rateLimitedCount rate limited)';
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send invitations: ${result['error'] ?? 'Unknown error'}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      AppLogger().error('Error sending invitations: $e');
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _broadcastToAll() async {
    setState(() => _isSending = true);

    try {
      final result = await _invitationService.broadcastToAllFollowers(
        roomId: widget.roomId,
        roomName: widget.roomName,
        roomType: widget.roomType,
        inviterUserId: widget.currentUserId,
        inviterName: widget.currentUserName,
      );

      if (mounted) {
        setState(() => _isSending = false);

        if (result['success'] == true) {
          final successCount = result['successCount'] ?? 0;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Broadcast sent to $successCount follower${successCount == 1 ? '' : 's'}'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Failed to broadcast'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      AppLogger().error('Error broadcasting: $e');
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_add, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Invite Followers',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Invite your followers to join "${widget.roomName}"',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _followers.isEmpty ? null : _toggleSelectAll,
                    icon: Icon(
                      _selectedFollowerIds.length == _followers.length
                          ? Icons.deselect
                          : Icons.select_all,
                    ),
                    label: Text(
                      _selectedFollowerIds.length == _followers.length
                          ? 'Deselect All'
                          : 'Select All',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8B5CF6),
                      side: const BorderSide(color: Color(0xFF8B5CF6)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _followers.isEmpty || _isSending ? null : _broadcastToAll,
                    icon: const Icon(Icons.campaign),
                    label: const Text('Broadcast'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Selection count
          if (_selectedFollowerIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${_selectedFollowerIds.length} follower${_selectedFollowerIds.length == 1 ? '' : 's'} selected',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Followers list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_errorMessage!),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadFollowers,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _followers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'No followers yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _followers.length,
                            itemBuilder: (context, index) {
                              final follower = _followers[index];
                              final isSelected = _selectedFollowerIds.contains(follower.id);

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: follower.avatar != null && follower.avatar!.isNotEmpty
                                      ? NetworkImage(follower.avatar!)
                                      : null,
                                  child: follower.avatar == null || follower.avatar!.isEmpty
                                      ? Text(follower.name[0].toUpperCase())
                                      : null,
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        follower.name,
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: follower.isOnline ? Colors.green : Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: follower.email.isNotEmpty
                                    ? Text(follower.email)
                                    : null,
                                trailing: Checkbox(
                                  value: isSelected,
                                  onChanged: (value) => _toggleFollower(follower.id),
                                  activeColor: const Color(0xFF8B5CF6),
                                ),
                                onTap: () => _toggleFollower(follower.id),
                              );
                            },
                          ),
          ),

          // Send button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedFollowerIds.isEmpty || _isSending ? null : _sendInvitations,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isSending ? 'Sending...' : 'Send Invitations'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
