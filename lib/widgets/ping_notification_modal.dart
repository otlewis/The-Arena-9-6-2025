import 'package:flutter/material.dart';
import '../models/moderator_judge.dart';
import '../services/appwrite_service.dart';
import '../screens/arena_screen.dart';
import '../core/logging/app_logger.dart';
import '../constants/appwrite.dart';
import 'dart:async';

class PingNotificationModal extends StatefulWidget {
  final PingRequest pingRequest;
  final VoidCallback onDismiss;

  const PingNotificationModal({
    super.key,
    required this.pingRequest,
    required this.onDismiss,
  });

  @override
  State<PingNotificationModal> createState() => _PingNotificationModalState();
}

class _PingNotificationModalState extends State<PingNotificationModal>
    with TickerProviderStateMixin {
  final AppwriteService _appwrite = AppwriteService();
  late AnimationController _animationController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isResponding = false;
  int _timeLeft = 60; // 60 seconds to respond
  Timer? _countdownTimer;

  // Colors based on role
  Color get _primaryColor => widget.pingRequest.roleType == 'moderator' 
      ? const Color(0xFF8B5CF6) // Purple for moderators
      : const Color(0xFFFFC107); // Yellow for judges

  Color get _darkColor => widget.pingRequest.roleType == 'moderator'
      ? const Color(0xFF7C3AED)
      : const Color(0xFFF57C00);

  @override
  void initState() {
    super.initState();
    
    AppLogger().info('PingNotificationModal created for ${widget.pingRequest.roleType}');
    
    // Animation setup
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _animationController.forward();
    _shimmerController.repeat();
    
    // Start countdown
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        timer.cancel();
        _autoDecline();
      }
    });
  }

  void _autoDecline() async {
    if (!_isResponding) {
      AppLogger().info('Auto-declining ping request due to timeout');
      await _respondToPing('declined', 'Request timed out');
    }
  }

  Future<void> _respondToPing(String response, String? message) async {
    if (_isResponding) return;
    
    setState(() {
      _isResponding = true;
    });

    try {
      // Update ping request status
      await _appwrite.databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.pingRequestsCollection,
        documentId: widget.pingRequest.id,
        data: {
          'status': response,
          'response': message,
          'respondedAt': DateTime.now().toIso8601String(),
        },
      );

      AppLogger().info('Ping request $response: ${widget.pingRequest.id}');

      // If accepted, add user to arena with appropriate role and navigate
      if (response == 'accepted' && widget.pingRequest.arenaRoomId != null) {
        // Get current user
        final currentUser = await _appwrite.account.get();
        
        // Use the proper assignArenaRole method to add/update participant
        try {
          await _appwrite.assignArenaRole(
            roomId: widget.pingRequest.arenaRoomId!,
            userId: currentUser.$id,
            role: widget.pingRequest.roleType, // 'moderator' or 'judge' (will be converted to judge1/2/3 if judge)
          );
          AppLogger().info('Successfully assigned ${widget.pingRequest.roleType} role to user');
        } catch (e) {
          AppLogger().error('Error assigning role in arena: $e');
        }

        // Navigate to arena
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ArenaScreen(
                roomId: widget.pingRequest.arenaRoomId!,
                challengeId: widget.pingRequest.id, // Use ping request ID as challengeId
                topic: widget.pingRequest.debateTitle,
              ),
            ),
          );
        }
      } else {
        // Close modal
        _dismissModal();
      }

    } catch (e) {
      AppLogger().error('Error responding to ping: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error responding to ping: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isResponding = false;
      });
    }
  }


  void _dismissModal() {
    _countdownTimer?.cancel();
    _animationController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animationController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with role icon and title
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.pingRequest.roleType == 'moderator' 
                              ? Icons.gavel 
                              : Icons.balance,
                          color: _primaryColor,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.pingRequest.roleType == 'moderator' ? 'Moderator' : 'Judge'} Request',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _darkColor,
                              ),
                            ),
                            Text(
                              'From @${widget.pingRequest.fromUsername}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Countdown timer
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _timeLeft <= 10 ? Colors.red : _primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$_timeLeft',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Debate details
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Debate Topic',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.pingRequest.debateTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.pingRequest.debateDescription.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.pingRequest.debateDescription,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.category,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.pingRequest.category.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Now',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isResponding ? null : () => _respondToPing('declined', 'Declined by user'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isResponding
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'Decline',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isResponding ? null : () => _respondToPing('accepted', 'Accepted by user'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isResponding
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Accept',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}