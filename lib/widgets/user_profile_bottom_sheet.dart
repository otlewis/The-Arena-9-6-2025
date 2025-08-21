import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_profile.dart';
import '../services/challenge_messaging_service.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import '../widgets/report_user_dialog.dart';

/// Beautiful user profile bottom sheet modal
class UserProfileBottomSheet extends StatefulWidget {
  final UserProfile user;
  final VoidCallback? onFollow;
  final VoidCallback? onChallenge;
  final VoidCallback? onEmail;
  final VoidCallback? onClose;

  const UserProfileBottomSheet({
    super.key,
    required this.user,
    this.onFollow,
    this.onChallenge,
    this.onEmail,
    this.onClose,
  });

  @override
  State<UserProfileBottomSheet> createState() => _UserProfileBottomSheetState();
}

class _UserProfileBottomSheetState extends State<UserProfileBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _isFollowing = false; // TODO: Get actual follow status

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _close() {
    _animationController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onClose?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 300),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF8B5CF6), // Purple gradient top
                  Color(0xFF6B46C1), // Darker purple bottom
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Header with profile pic, name, and close button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Profile picture with white circle
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: widget.user.avatar?.isNotEmpty == true
                              ? Image.network(
                                  widget.user.avatar!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    width: 80,
                                    height: 80,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        widget.user.name.isNotEmpty 
                                          ? widget.user.name[0].toUpperCase()
                                          : 'A',
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 80,
                                  height: 80,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      widget.user.name.isNotEmpty 
                                        ? widget.user.name[0].toUpperCase()
                                        : 'A',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${widget.user.name.toLowerCase()}@arena.dtd',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Close button
                      GestureDetector(
                        onTap: _close,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Stats section with dark background
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('${widget.user.totalWins}', 'Wins'),
                      _buildStatColumn('${widget.user.totalDebates}', 'Debates'),
                      _buildStatColumn('${widget.user.reputation}', 'Reputation'),
                      _buildStatColumn(
                        widget.user.totalDebates > 0 
                          ? '${((widget.user.totalWins / widget.user.totalDebates) * 100).toStringAsFixed(1)}%'
                          : '0.0%', 
                        'Win Rate'
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action buttons - Email button on top, Follow and Challenge below
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Email button (full width)
                      GestureDetector(
                        onTap: () async {
                          // Close first, then navigate
                          final navigator = Navigator.of(context);
                          _animationController.reverse();
                          await Future.delayed(const Duration(milliseconds: 150));
                          if (mounted) {
                            navigator.pop();
                            // Give a small delay for the modal to fully close
                            await Future.delayed(const Duration(milliseconds: 100));
                            widget.onEmail?.call();
                            widget.onClose?.call();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.mail,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Send Email',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Follow and Challenge buttons (side by side)
                      Row(
                        children: [
                          // Follow button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isFollowing = !_isFollowing;
                                });
                                widget.onFollow?.call();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isFollowing ? Icons.check : Icons.person_add,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isFollowing ? 'Following' : 'Follow',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Challenge button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                // Show challenge dialog directly without closing the sheet
                                HapticFeedback.lightImpact();
                                _showChallengeDialog();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.gavel,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Challenge',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Report button (full width)
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          
                          // Get current user ID for reporting
                          final appwrite = AppwriteService();
                          final currentUser = await appwrite.getCurrentUser();
                          
                          // Check mounted state before using context
                          if (!mounted) return;
                          
                          // Safe to use context here because mounted check ensures widget is still active
                          // ignore: use_build_context_synchronously
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          
                          if (currentUser == null) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Please sign in to report users'),
                                backgroundColor: Color(0xFFFF2400),
                              ),
                            );
                            return;
                          }

                          // ignore: use_build_context_synchronously
                          showDialog(
                            // ignore: use_build_context_synchronously
                            context: context,
                            builder: (context) => ReportUserDialog(
                              reportedUser: widget.user,
                              reporterId: currentUser.$id,
                              roomId: 'room_interaction', // Default room ID for room interactions
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2400),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF2400).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.report_problem,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Report User',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Show challenge dialog to send a challenge to this user
  void _showChallengeDialog() {
    final topicController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedPosition = 'affirmative';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Challenge ${widget.user.displayName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Topic input
                TextField(
                  controller: topicController,
                  decoration: const InputDecoration(
                    labelText: 'Debate Topic',
                    hintText: 'What should you debate about?',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                
                // Description input
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Add context or rules...',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                
                // Position selection
                const Text('Your Position:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => selectedPosition = 'affirmative'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedPosition == 'affirmative' ? Colors.green : Colors.grey,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedPosition == 'affirmative' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              const Text('For'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => selectedPosition = 'negative'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedPosition == 'negative' ? Colors.red : Colors.grey,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedPosition == 'negative' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              const Text('Against'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (topicController.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  await _sendChallengeToUser(
                    topicController.text.trim(),
                    descriptionController.text.trim(),
                    selectedPosition,
                  );
                }
              },
              child: const Text('Send Challenge'),
            ),
          ],
        ),
      ),
    );
  }

  /// Send a challenge to the user
  Future<void> _sendChallengeToUser(String topic, String description, String position) async {
    try {
      AppLogger().info('Sending challenge to ${widget.user.id}: $topic');
      
      // Get the challenge messaging service
      final challengeService = ChallengeMessagingService();
      
      await challengeService.sendChallenge(
        challengedUserId: widget.user.id,
        topic: topic,
        description: description,
        position: position,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Challenge sent to ${widget.user.displayName}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      AppLogger().error('Failed to send challenge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error sending challenge. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Static method to show the bottom sheet
  // ignore: unused_element
  static Future<void> show(
    BuildContext context,
    UserProfile user, {
    VoidCallback? onFollow,
    VoidCallback? onChallenge,
    VoidCallback? onEmail,
    VoidCallback? onClose,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => UserProfileBottomSheet(
        user: user,
        onFollow: onFollow,
        onChallenge: onChallenge,
        onEmail: onEmail,
        onClose: onClose,
      ),
    );
  }
}