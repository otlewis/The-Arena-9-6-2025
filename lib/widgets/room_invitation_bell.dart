import 'dart:async';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../services/follower_invitation_service.dart';
import '../services/sound_service.dart';
import '../core/logging/app_logger.dart';
import '../screens/debates_discussions_screen.dart';

/// Bell widget that shows pending room invitations with badge count
class RoomInvitationBell extends StatefulWidget {
  final String userId;

  const RoomInvitationBell({
    super.key,
    required this.userId,
  });

  @override
  State<RoomInvitationBell> createState() => _RoomInvitationBellState();
}

class _RoomInvitationBellState extends State<RoomInvitationBell> with SingleTickerProviderStateMixin {
  final AppwriteService _appwrite = AppwriteService();
  final FollowerInvitationService _invitationService = FollowerInvitationService();
  final SoundService _soundService = SoundService();

  List<Map<String, dynamic>> _pendingInvitations = [];
  RealtimeSubscription? _invitationSubscription;
  late AnimationController _animationController;
  late Animation<double> _shakeAnimation;
  bool _isShaking = false;

  @override
  void initState() {
    super.initState();
    _setupShakeAnimation();
    _loadPendingInvitations();
    _subscribeToInvitations();
  }

  void _setupShakeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticIn,
    ));
  }

  Future<void> _loadPendingInvitations() async {
    try {
      final invitations = await _invitationService.getPendingInvitations(widget.userId);
      if (mounted) {
        setState(() {
          _pendingInvitations = invitations;
        });
      }
    } catch (e) {
      AppLogger().error('Failed to load pending invitations: $e');
    }
  }

  void _subscribeToInvitations() {
    try {
      final realtime = _appwrite.realtime;

      _invitationSubscription = realtime.subscribe([
        'databases.arena_db.collections.room_invitations.documents'
      ]);

      _invitationSubscription!.stream.listen((response) {
        if (!mounted) return;

        final payload = response.payload;

        // Check if this invitation is for current user
        if (payload['inviteeId'] == widget.userId && payload['status'] == 'pending') {
          // Reload invitations
          _loadPendingInvitations();

          // Play ping sound
          _soundService.playPing();

          // Shake bell to draw attention
          _shakeBell();

          AppLogger().info('📨 New room invitation received!');
        }
      });

      AppLogger().info('📨 Subscribed to room invitations for user ${widget.userId}');
    } catch (e) {
      AppLogger().error('Failed to subscribe to room invitations: $e');
    }
  }

  void _shakeBell() {
    if (!_isShaking) {
      setState(() => _isShaking = true);
      _animationController.forward(from: 0).then((_) {
        if (mounted) {
          setState(() => _isShaking = false);
        }
      });
    }
  }

  void _showInvitations() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildInvitationsBottomSheet(),
    );
  }

  Widget _buildInvitationsBottomSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: Color(0xFF8B5CF6), size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Room Invitations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Invitations list
          Expanded(
            child: _pendingInvitations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No pending invitations',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingInvitations.length,
                    itemBuilder: (context, index) {
                      final invitation = _pendingInvitations[index];
                      return _buildInvitationCard(invitation);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(Map<String, dynamic> invitation) {
    final roomName = invitation['roomName'] ?? 'Unknown Room';
    final roomType = invitation['roomType'] ?? 'Discussion';
    final inviterName = invitation['inviterName'] ?? 'Someone';
    final createdAt = DateTime.tryParse(invitation['createdAt'] ?? '');
    final timeAgo = createdAt != null ? _formatTimeAgo(createdAt) : 'just now';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    roomType,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              roomName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '$inviterName invited you',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptInvitation(invitation),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Join Room'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _declineInvitation(invitation),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                  ),
                  child: const Text('Decline'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _acceptInvitation(Map<String, dynamic> invitation) async {
    try {
      final invitationId = invitation['\$id'];
      final roomId = invitation['roomId'];
      final roomName = invitation['roomName'];
      final inviterName = invitation['inviterName'];

      // Mark as accepted
      await _invitationService.acceptInvitation(invitationId);

      // Navigate to room
      if (mounted) {
        Navigator.pop(context); // Close bottom sheet

        // Navigate to debates & discussions screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DebatesDiscussionsScreen(
              roomId: roomId,
              roomName: roomName,
              moderatorName: inviterName,
            ),
          ),
        );
      }

      // Reload invitations
      _loadPendingInvitations();
    } catch (e) {
      AppLogger().error('Failed to accept invitation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _declineInvitation(Map<String, dynamic> invitation) async {
    try {
      final invitationId = invitation['\$id'];

      // Mark as declined
      await _invitationService.declineInvitation(invitationId);

      // Reload invitations
      _loadPendingInvitations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation declined'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      AppLogger().error('Failed to decline invitation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _invitationSubscription?.close();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _shakeAnimation.value,
          child: child,
        );
      },
      child: Stack(
        children: [
          IconButton(
            icon: const Icon(Icons.notifications, size: 28),
            onPressed: _showInvitations,
            tooltip: 'Room Invitations',
          ),
          if (_pendingInvitations.isNotEmpty)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  '${_pendingInvitations.length}',
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
    );
  }
}
