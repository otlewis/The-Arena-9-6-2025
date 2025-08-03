import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_profile.dart';
import '../core/logging/app_logger.dart';
import '../services/challenge_messaging_service.dart';

/// Modal that displays user profile information when clicking on users in rooms
class UserProfileModal extends StatefulWidget {
  final UserProfile userProfile;
  final String? userRole; // e.g., 'moderator', 'speaker', 'judge', 'audience'
  final UserProfile? currentUser;
  final VoidCallback? onStartChat;
  final VoidCallback? onClose;

  const UserProfileModal({
    super.key,
    required this.userProfile,
    this.userRole,
    this.currentUser,
    this.onStartChat,
    this.onClose,
  });

  @override
  State<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends State<UserProfileModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  // Services for future use
  // final AppwriteService _appwriteService = AppwriteService();
  // final InstantMessagingService _imService = InstantMessagingService();
  
  bool _isCurrentUser = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkIfCurrentUser();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      // Faster animation for Android performance
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.9,  // Start closer to final size
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,  // Simpler curve
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  void _checkIfCurrentUser() {
    _isCurrentUser = widget.currentUser?.id == widget.userProfile.id;
  }

  /// Check if user role restricts them from being challenged (optimized)
  bool _isRoleRestrictedFromChallenges() {
    final role = widget.userRole?.toLowerCase();
    
    if (role == null || role.isEmpty) {
      return false;
    }
    
    const restrictedRoles = {
      'moderator',
      'judge',
      'judge1', 
      'judge2',
      'judge3',
      'affirmative',
      'negative',
      'affirmative2',
      'negative2',
      'speaker', // For discussion rooms
    };
    
    return restrictedRoles.contains(role);
  }

  /// Get user-friendly restriction message based on role
  String _getRestrictionMessage() {
    final userName = widget.userProfile.displayName;
    final role = widget.userRole?.toLowerCase();
    
    switch (role) {
      case 'moderator':
        return '$userName is a moderator and can\'t be challenged at this time';
      case 'judge':
      case 'judge1':
      case 'judge2': 
      case 'judge3':
        return '$userName is currently judging and can\'t be challenged';
      case 'affirmative':
      case 'negative':
      case 'affirmative2':
      case 'negative2':
        return '$userName is actively debating and can\'t be challenged right now';
      case 'speaker':
        return '$userName is currently speaking and can\'t be challenged';
      default:
        return '$userName is currently unavailable for challenges';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closeModal,
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping the modal content
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: _buildModalContent(),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalContent() {
    return RepaintBoundary(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(maxWidth: 400),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getRoleColor(widget.userRole).withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(child: _buildHeader()),
            RepaintBoundary(child: _buildProfileInfo()),
            RepaintBoundary(child: _buildStats()),
            _buildActions(), // Already has RepaintBoundary
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getRoleColor(widget.userRole).withValues(alpha: 0.8),
            _getRoleColor(widget.userRole).withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              image: widget.userProfile.hasAvatar
                  ? DecorationImage(
                      image: NetworkImage(widget.userProfile.avatar!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: !widget.userProfile.hasAvatar
                ? Center(
                    child: Text(
                      widget.userProfile.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          // Name and role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userProfile.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (widget.userRole != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getRoleDisplayName(widget.userRole!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
                if (widget.userProfile.isVerified) ...[
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.verified, color: Colors.blue, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: TextStyle(
                          color: Colors.blue, 
                          fontSize: 12,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Close button
          IconButton(
            onPressed: _closeModal,
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.userProfile.bio != null && widget.userProfile.bio!.isNotEmpty) ...[
            const Text(
              'About',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.userProfile.bio!,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
                height: 1.4,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (widget.userProfile.location != null && widget.userProfile.location!.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey[400], size: 16),
                const SizedBox(width: 8),
                Text(
                  widget.userProfile.location!,
                  style: TextStyle(
                    color: Colors.grey[300], 
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (widget.userProfile.interests.isNotEmpty) ...[
            const Text(
              'Interests',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.userProfile.interests.map((interest) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    interest,
                    style: const TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Wins', widget.userProfile.totalWins.toString()),
          _buildStatItem('Debates', widget.userProfile.totalDebates.toString()),
          _buildStatItem('Reputation', widget.userProfile.formattedReputation),
          _buildStatItem('Win Rate', '${(widget.userProfile.winPercentage * 100).toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    final isRestricted = _isRoleRestrictedFromChallenges();
    
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            if (!_isCurrentUser) ...[
              // Follow button - always available
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    AppLogger().info('👥 Follow button tapped for ${widget.userProfile.name}');
                    _followUser();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Follow',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Challenge button - isolated gesture detection
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    AppLogger().info('⚡ Challenge button tapped for ${widget.userProfile.name}');
                    if (isRestricted) {
                      _showChallengeRestriction();
                    } else {
                      _sendChallenge();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isRestricted ? Colors.grey : const Color(0xFFFF2400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flash_on, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Challenge',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              // View own profile button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _viewOwnProfile,
                  icon: const Icon(Icons.person, size: 18),
                  label: const Text('View Full Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A5568),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'moderator':
        return const Color(0xFFFF6B6B);
      case 'judge':
        return const Color(0xFFFFD93D);
      case 'speaker':
        return const Color(0xFF6BCF7F);
      case 'participant':
      case 'audience':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'moderator':
        return 'Moderator';
      case 'judge':
        return 'Judge';
      case 'speaker':
        return 'Speaker';
      case 'participant':
        return 'Participant';
      case 'audience':
        return 'Audience';
      default:
        return role;
    }
  }

  void _followUser() {
    try {
      AppLogger().info('👥 Following user: ${widget.userProfile.name}');
      HapticFeedback.lightImpact();
      
      if (widget.currentUser == null) {
        AppLogger().error('No current user available');
        return;
      }

      // TODO: Implement follow user functionality with AppwriteService
      // For now, show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started following ${widget.userProfile.name}!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      AppLogger().error('Failed to follow user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to follow user: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showChallengeRestriction() {
    HapticFeedback.lightImpact();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getRestrictionMessage()),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _sendChallenge() {
    try {
      AppLogger().info('⚡ Starting challenge to ${widget.userProfile.name}');
      HapticFeedback.lightImpact();
      
      // Double-check restrictions (shouldn't happen, but safety first)
      if (_isRoleRestrictedFromChallenges()) {
        _showChallengeRestriction();
        return;
      }
      
      // Show challenge creation dialog
      if (mounted) {
        _showChallengeDialog();
      }
      
    } catch (e) {
      AppLogger().error('Failed to send challenge: $e');
    }
  }

  void _showChallengeDialog() {
    final topicController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedPosition = 'affirmative';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Challenge ${widget.userProfile.displayName}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: topicController,
                  decoration: const InputDecoration(
                    labelText: 'Debate Topic *',
                    hintText: 'e.g., Climate change requires immediate action',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Additional context or rules...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Your position: '),
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedPosition,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'affirmative', child: Text('Affirmative (Pro)')),
                          DropdownMenuItem(value: 'negative', child: Text('Negative (Con)')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedPosition = value;
                            });
                          }
                        },
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
                if (topicController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a debate topic')),
                  );
                  return;
                }
                
                Navigator.pop(context);
                await _sendChallengeToUser(
                  topicController.text.trim(),
                  descriptionController.text.trim(),
                  selectedPosition,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2400),
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Challenge'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendChallengeToUser(String topic, String description, String position) async {
    try {
      AppLogger().info('Sending challenge to ${widget.userProfile.id}: $topic');
      
      // Get the challenge messaging service
      final challengeService = ChallengeMessagingService();
      
      await challengeService.sendChallenge(
        challengedUserId: widget.userProfile.id,
        topic: topic,
        description: description,
        position: position,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Challenge sent to ${widget.userProfile.displayName}!'),
            backgroundColor: Colors.green,
          ),
        );
        // Close the profile modal after successful challenge
        _closeModal();
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

  void _viewOwnProfile() {
    _closeModal();
    
    // TODO: Navigate to full profile screen
    AppLogger().info('Viewing own profile');
  }

  void _closeModal() {
    _animationController.reverse().then((_) {
      if (mounted) {
        widget.onClose?.call();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

