import 'package:flutter/material.dart';
import '../services/appwrite_service.dart';
import '../services/challenge_messaging_service.dart';
import '../screens/arena_screen.dart';
import '../main.dart' show getIt;
import '../core/logging/app_logger.dart';

class ArenaRoleNotificationModal extends StatefulWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onDismiss;

  const ArenaRoleNotificationModal({
    super.key,
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<ArenaRoleNotificationModal> createState() => _ArenaRoleNotificationModalState();
}

class _ArenaRoleNotificationModalState extends State<ArenaRoleNotificationModal>
    with TickerProviderStateMixin {
  final AppwriteService _appwrite = AppwriteService();
  late final ChallengeMessagingService _messagingService;
  late AnimationController _animationController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  bool _isResponding = false;

  // Colors
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void initState() {
    super.initState();
    
    // Get messaging service singleton
    _messagingService = getIt<ChallengeMessagingService>();
    
    // Add debug logging
    AppLogger().info('ArenaRoleNotificationModal created!');
    AppLogger().debug('🔔 Role: ${widget.notification['role']}');
    AppLogger().debug('🔔 Topic: ${widget.notification['topic']}');
    AppLogger().debug('🔔 Arena ID: ${widget.notification['arenaId']}');
    AppLogger().debug('🔔 User ID: ${widget.notification['userId']}');
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.notification['role'] ?? 'judge';
    final topic = widget.notification['topic'] ?? 'Debate Topic';

    return Material(
      color: Colors.black54,
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _getRoleColor().withValues(alpha: 0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: _getRoleColor().withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with role badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isJudgeRole(role) ? Colors.amber.shade100 : accentPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isJudgeRole(role) ? Colors.amber.shade700 : accentPurple,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isJudgeRole(role) ? Icons.balance : Icons.person_pin_circle,
                            color: _isJudgeRole(role) ? Colors.amber.shade700 : accentPurple,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_isJudgeRole(role) ? 'JUDGE' : role.toUpperCase()} INVITATION',
                            style: TextStyle(
                              color: _isJudgeRole(role) ? Colors.amber.shade700 : accentPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.close, color: Colors.grey),
                      iconSize: 20,
                    ),
                  ],
                ),
                _buildContent(topic, role),
                _buildActions(role),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildContent(String topic, String role) {
    final isModerator = role == 'moderator';
    final description = isModerator
        ? 'Help facilitate the debate and keep the discussion on track'
        : 'Evaluate the debate and provide fair scoring for both sides';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Role icon and description
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: (isModerator ? accentPurple : Colors.amber.shade700).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isModerator ? Icons.person_pin_circle : Icons.balance,
              size: 40,
              color: isModerator ? accentPurple : Colors.amber.shade700,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'You\'re invited to be a ${isModerator ? 'Moderator' : 'Judge'}!',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: deepPurple,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 20),
          
          // Debate topic
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Debate Topic:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: deepPurple,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  topic,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scarletRed,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Urgency indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer, size: 16, color: Colors.orange),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Response needed within 2 minutes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(String role) {
    final isModerator = role == 'moderator';
    final color = isModerator ? accentPurple : Colors.amber.shade700;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isResponding ? null : () => _respondToNotification('declined'),
                  icon: const Icon(Icons.close),
                  label: const Text('Decline'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isResponding ? null : () => _respondToNotification('accepted'),
                  icon: _isResponding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(isModerator ? Icons.gavel : Icons.balance),
                  label: Text(_isResponding ? 'Accepting...' : 'Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _dismiss,
            child: Text(
              'Maybe later',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _respondToNotification(String response) async {
    setState(() => _isResponding = true);

    try {
      final notificationId = widget.notification['id'];
      final role = widget.notification['role'];
      final arenaId = widget.notification['arenaId'];
      
      AppLogger().info('Arena role notification $response: $notificationId');
      
      // Use messaging service to respond to arena role invitation
      await _messagingService.respondToArenaRoleInvitation(
        invitationId: notificationId,
        accept: response == 'accepted',
      );

      if (response == 'accepted') {
        // Assign user to the arena role
        final currentUser = await _appwrite.getCurrentUser();
        if (currentUser != null) {
          AppLogger().info('Assigned $role to user ${currentUser.$id} in room $arenaId');
          
          await _appwrite.assignArenaRole(
            roomId: arenaId,
            userId: currentUser.$id,
            role: role,
          );
          
          // Navigate officials to the arena room they were assigned to
          AppLogger().info('Role accepted - navigating to arena room: $arenaId');
          
          // Navigate to the specific arena room
          if (mounted) {
            // First dismiss the modal
            _dismiss();
            
            // Navigate to the arena room - use arenaId directly as the roomId
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ArenaScreen(
                  roomId: arenaId, // Use the arenaId directly as it contains the full room ID
                  challengeId: widget.notification['challengeId'] ?? arenaId,
                  topic: widget.notification['topic'] ?? 'Debate Topic',
                  description: widget.notification['description'],
                  category: widget.notification['category'],
                  challengerId: widget.notification['challengerId'],
                  challengedId: widget.notification['challengedId'],
                ),
              ),
            );
            return; // Skip snackbar since we're navigating
          }
        }

        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ You are now the $role for this debate!'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            AppLogger().warning('Could not show snackbar: $e');
          }
        }
      } else {
        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ $role invitation declined'),
                backgroundColor: Colors.orange,
              ),
            );
          } catch (e) {
            AppLogger().warning('Could not show snackbar: $e');
          }
        }
      }

      // Only dismiss if not already dismissed (during navigation)
      if (mounted) {
        _dismiss();
      }
    } catch (e) {
      AppLogger().error('Error responding to arena notification: $e');
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error responding: $e')),
          );
        } catch (scaffoldError) {
          AppLogger().warning('Could not show error snackbar: $scaffoldError');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isResponding = false);
      }
    }
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  Color _getRoleColor() {
    final role = widget.notification['role'] ?? 'judge';
    if (_isJudgeRole(role)) {
      return Colors.amber.shade700;
    } else if (role == 'moderator') {
      return accentPurple;
    } else {
      return Colors.grey.shade700; // Default color for unknown roles
    }
  }

  bool _isJudgeRole(String role) {
    return role == 'judge' || role.startsWith('judge');
  }
} 