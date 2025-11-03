import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:appwrite/appwrite.dart';
import '../models/user_profile.dart';
import '../services/challenge_messaging_service.dart';
import '../services/challenge_eligibility_service.dart';
import '../services/appwrite_service.dart';
import '../services/super_moderator_service.dart';
import '../services/user_timeout_service.dart';
import '../services/user_kick_service.dart';
import '../services/user_ban_service.dart';
import '../services/room_audio_adapter.dart';
import '../core/logging/app_logger.dart';
import '../widgets/report_user_dialog.dart';
import '../widgets/premium_badge.dart';
import '../widgets/invite_followers_bottom_sheet.dart';

/// Beautiful user profile bottom sheet modal
class UserProfileBottomSheet extends StatefulWidget {
  final UserProfile user;
  final VoidCallback? onFollow;
  final VoidCallback? onChallenge;
  final VoidCallback? onEmail;
  final VoidCallback? onClose;
  final String? roomId;
  final String? roomType;
  final bool isCurrentUserModerator;

  const UserProfileBottomSheet({
    super.key,
    required this.user,
    this.onFollow,
    this.onChallenge,
    this.onEmail,
    this.onClose,
    this.roomId,
    this.roomType,
    this.isCurrentUserModerator = false,
  });

  @override
  State<UserProfileBottomSheet> createState() => _UserProfileBottomSheetState();
}

class _UserProfileBottomSheetState extends State<UserProfileBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _isFollowing = false; // TODO: Get actual follow status
  bool _currentUserIsPremium = false;
  bool _isCurrentUserSuperMod = false;
  String? _currentUserId;
  int? _globalRank;
  String _tier = 'Bronze';
  String? _userRoleInRoom; // Track the user's role in the current room

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
    _checkCurrentUserPremiumStatus();
    _fetchUserRanking();
    _checkSuperModStatus();
    _checkFollowStatus();
    _fetchUserRoleInRoom();
  }

  Future<void> _fetchUserRanking() async {
    try {
      final appwrite = AppwriteService();
      final currentMonth = _getCurrentMonthKey();

      final response = await appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'monthly_rankings',
      );

      // Find this user's ranking for current month
      for (final doc in response.documents) {
        if (doc.data['userId'] == widget.user.id && doc.data['monthKey'] == currentMonth) {
          if (mounted) {
            setState(() {
              _globalRank = doc.data['globalRank'] ?? 0;
              _tier = doc.data['tier'] ?? 'Bronze';
            });
          }
          break;
        }
      }
    } catch (e) {
      AppLogger().error('Failed to fetch user ranking: $e');
    }
  }

  String _getCurrentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> _checkCurrentUserPremiumStatus() async {
    try {
      // BETA TESTING: Force all users to be premium during beta
      setState(() {
        _currentUserIsPremium = true;
      });
      AppLogger().info('🧪 BETA MODE: All users have premium access for challenges');

      /* TODO: Restore feature flag logic when beta testing is complete
      // Check if beta testing mode is enabled
      final isBetaTesting = await FeatureFlagService().isBetaTestingMode();

      if (isBetaTesting) {
        // In beta testing mode, all users are premium
        setState(() {
          _currentUserIsPremium = true;
        });
        AppLogger().info('🧪 Beta testing mode enabled - all users have premium access');
      } else {
        // Normal premium checking
        final appwriteService = AppwriteService();
        final currentUser = await appwriteService.getCurrentUser();
        if (currentUser != null) {
          final userProfile = await appwriteService.getUserProfile(currentUser.$id);
          setState(() {
            _currentUserIsPremium = userProfile?.isPremium ?? false;
          });
        }
      }
      */
    } catch (e) {
      AppLogger().error('Error checking current user premium status: $e');
    }
  }

  Future<void> _checkSuperModStatus() async {
    try {
      AppLogger().info('🔍 Checking super mod status...');
      final appwrite = AppwriteService();
      final currentUser = await appwrite.getCurrentUser();

      if (currentUser != null) {
        final superModService = SuperModeratorService();
        if (mounted) {
          setState(() {
            _currentUserId = currentUser.$id;
            _isCurrentUserSuperMod = superModService.isSuperModerator(currentUser.$id);
          });
        }
        AppLogger().info('✅ Super mod status set - userId: $_currentUserId, isSuperMod: $_isCurrentUserSuperMod');
      } else {
        AppLogger().error('❌ getCurrentUser returned null');
      }
    } catch (e) {
      AppLogger().error('❌ Error checking super mod status: $e');
    }
  }

  Future<void> _checkFollowStatus() async {
    try {
      final appwrite = AppwriteService();
      final currentUser = await appwrite.getCurrentUser();

      if (currentUser != null && widget.user.id != currentUser.$id) {
        final isFollowing = await appwrite.isFollowing(
          followerId: currentUser.$id,
          followingId: widget.user.id,
        );

        if (mounted) {
          setState(() {
            _isFollowing = isFollowing;
          });
        }
      }
    } catch (e) {
      AppLogger().error('Error checking follow status: $e');
    }
  }

  /// Fetch the user's role in the current room (if in a room)
  Future<void> _fetchUserRoleInRoom() async {
    if (widget.roomId == null || widget.roomType == null) {
      return; // Not in a room context
    }

    try {
      final appwrite = AppwriteService();
      final roomType = widget.roomType!.toLowerCase();

      // Determine which participant collection to query based on room type
      String participantCollection;
      if (roomType.contains('arena') || roomType.contains('debate')) {
        participantCollection = 'arena_participants';
      } else if (roomType.contains('discussion')) {
        participantCollection = 'room_participants';
      } else {
        return; // Unknown room type
      }

      // Query for the user's participant record in this room
      final participants = await appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: participantCollection,
        queries: [
          Query.equal('roomId', widget.roomId!),
          Query.equal('userId', widget.user.id),
        ],
      );

      if (participants.documents.isNotEmpty && mounted) {
        setState(() {
          _userRoleInRoom = participants.documents.first.data['role'];
        });
        AppLogger().info('✅ User ${widget.user.name} has role $_userRoleInRoom in room ${widget.roomId}');
      }
    } catch (e) {
      AppLogger().error('Error fetching user role in room: $e');
    }
  }

  /// Check if the user is restricted from being challenged
  /// Returns true if user is a moderator, active debater, or judge
  /// Returns false for audience members (they can ALWAYS be challenged, even super mods)
  /// Speakers in Discussion/Take rooms CAN be challenged (except moderators)
  bool _isUserChallengeRestricted() {
    // Check current role FIRST - audience members can ALWAYS be challenged
    if (_userRoleInRoom != null) {
      final role = _userRoleInRoom!.toLowerCase();

      // Audience members can ALWAYS be challenged (even super moderators in audience)
      if (role == 'audience') {
        return false;
      }

      // Room moderators cannot be challenged
      if (role == 'moderator') {
        return true;
      }

      // Judges cannot be challenged
      if (role == 'judge' || role == 'judge1' || role == 'judge2' || role == 'judge3') {
        return true;
      }

      // Active debaters cannot be challenged
      if (role == 'affirmative' || role == 'negative' ||
          role == 'affirmative2' || role == 'negative2') {
        return true;
      }

      // Speakers in Discussion/Take rooms CAN be challenged
      if (role == 'speaker') {
        return false; // Speakers are allowed to be challenged
      }
    }

    // If no role in room, check if they're a registered moderator
    // (Only block if they're not in a room or have no role)
    if (widget.user.isAvailableAsModerator) {
      return true;
    }

    return false;
  }

  /// Get the reason why the user cannot be challenged
  String _getChallengeRestrictionReason() {
    if (widget.user.isAvailableAsModerator) {
      return 'Moderators cannot be challenged';
    }

    if (_userRoleInRoom != null) {
      final role = _userRoleInRoom!.toLowerCase();
      if (role == 'moderator') {
        return 'Room moderators cannot be challenged';
      }
      if (role == 'judge' || role.startsWith('judge')) {
        return 'Judges cannot be challenged';
      }
      if (role.contains('affirmative') || role.contains('negative')) {
        return 'Active debaters cannot be challenged';
      }
    }

    return 'User is currently unavailable for challenges';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getTierEmoji(String tier) {
    switch (tier.toLowerCase()) {
      case 'bronze':
        return '🥉';
      case 'silver':
        return '🥈';
      case 'gold':
        return '🥇';
      case 'platinum':
        return '💎';
      case 'diamond':
        return '💠';
      default:
        return '🥉';
    }
  }

  void _close() {
    _animationController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onClose?.call();
      }
    });
  }

  Future<void> _shareProfile() async {
    try {
      final userName = widget.user.name;
      final userHandle = '${widget.user.name.toLowerCase()}@arena.dtd';
      final tier = _tier;
      final rank = _globalRank != null ? '#$_globalRank' : 'Unranked';

      // Build share text
      final shareText = '''
Check out $userName on Arena DTD! 🎤

$userHandle
🏆 Tier: $tier
📊 Rank: $rank

Join Arena DTD to connect with debaters and participate in live discussions!
''';

      // Share using native share dialog
      await Share.share(
        shareText,
        subject: 'Check out $userName on Arena DTD',
      );

      AppLogger().info('Profile shared: ${widget.user.id}');
    } catch (e) {
      AppLogger().error('Error sharing profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share profile'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 300),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                // Neumorphic outer shadow (dark)
                BoxShadow(
                  color: Colors.grey.shade400,
                  offset: const Offset(8, 8),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
                // Neumorphic inner highlight (light)
                const BoxShadow(
                  color: Colors.white,
                  offset: Offset(-8, -8),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ],
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Header with profile pic, name, and close button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Profile picture with neumorphic circle
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF8B5CF6),
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.user.name,
                                    style: const TextStyle(
                                      color: Color(0xFF2D3748),
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (widget.user.isPremium) ...[
                                  const SizedBox(width: 8),
                                  GlowingPremiumBadge(
                                    user: widget.user, 
                                    size: 18,
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '${widget.user.name.toLowerCase()}@arena.dtd',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Share button
                      GestureDetector(
                        onTap: _shareProfile,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.share,
                            color: const Color(0xFF8B5CF6),
                            size: 20,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Close button
                      GestureDetector(
                        onTap: _close,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.grey.shade700,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Stats section with neumorphic card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      // Neumorphic shadow
                      BoxShadow(
                        color: Colors.grey.shade300,
                        offset: const Offset(4, 4),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                      const BoxShadow(
                        color: Colors.white,
                        offset: Offset(-4, -4),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('${widget.user.totalWins}', 'Wins'),
                      _buildStatColumn('${widget.user.totalDebates}', 'Debates'),
                      _buildStatColumn('${widget.user.reputationPercentage}%', 'Reputation'),
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
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF8B5CF6),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade300,
                                offset: const Offset(4, 4),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                              const BoxShadow(
                                color: Colors.white,
                                offset: Offset(-4, -4),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.mail,
                                color: Color(0xFF8B5CF6),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Send Email',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Ping Followers button (full width, only show if in a room)
                      if (widget.roomId != null)
                        GestureDetector(
                          onTap: () async {
                            HapticFeedback.lightImpact();

                            try {
                              final appwrite = AppwriteService();
                              final currentUser = await appwrite.getCurrentUser();

                              if (currentUser == null) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please log in to invite followers')),
                                  );
                                }
                                return;
                              }

                              // Get room name from database
                              String roomName = 'Room';
                              String roomType = widget.roomType ?? 'Discussion';

                              try {
                                // Try to get room details from appropriate collection
                                if (widget.roomType?.toLowerCase() == 'arena') {
                                  // Arena room - check arena_rooms collection
                                  final roomDoc = await appwrite.databases.getDocument(
                                    databaseId: 'arena_db',
                                    collectionId: 'arena_rooms',
                                    documentId: widget.roomId!,
                                  );
                                  roomName = roomDoc.data['topic'] ?? roomDoc.data['title'] ?? 'Arena';
                                  roomType = 'arena';
                                } else {
                                  // Debates & Discussions room
                                  final roomDoc = await appwrite.databases.getDocument(
                                    databaseId: 'arena_db',
                                    collectionId: 'debate_discussion_rooms',
                                    documentId: widget.roomId!,
                                  );
                                  roomName = roomDoc.data['title'] ?? 'Room';
                                  roomType = roomDoc.data['debateStyle'] ?? 'Discussion';
                                }
                              } catch (e) {
                                AppLogger().error('Failed to get room details: $e');
                                // Use defaults
                              }

                              if (mounted) {
                                // Close current bottom sheet first
                                Navigator.pop(context);

                                // Show invite followers bottom sheet
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => InviteFollowersBottomSheet(
                                    roomId: widget.roomId!,
                                    roomName: roomName,
                                    roomType: roomType,
                                    currentUserId: currentUser.$id,
                                    currentUserName: currentUser.name,
                                  ),
                                );
                              }
                            } catch (e) {
                              AppLogger().error('Error showing invite followers: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF8B5CF6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade300,
                                  offset: const Offset(4, 4),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                                const BoxShadow(
                                  color: Colors.white,
                                  offset: Offset(-4, -4),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.campaign,
                                  color: Color(0xFF8B5CF6),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ping Followers',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (widget.roomId != null)
                        const SizedBox(height: 12),

                      // Follow and Challenge buttons (side by side)
                      Row(
                        children: [
                          // Follow button
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                // Call the callback first
                                widget.onFollow?.call();
                                // Wait a moment for the action to complete, then re-check status
                                await Future.delayed(const Duration(milliseconds: 500));
                                await _checkFollowStatus();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF10B981),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.shade300,
                                      offset: const Offset(4, 4),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                    ),
                                    const BoxShadow(
                                      color: Colors.white,
                                      offset: Offset(-4, -4),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isFollowing ? Icons.check : Icons.person_add,
                                      color: const Color(0xFF10B981),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isFollowing ? 'Following' : 'Follow',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
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
                              onTap: _isUserChallengeRestricted()
                                  ? () {
                                      // Show why they can't be challenged
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(_getChallengeRestrictionReason()),
                                          backgroundColor: Colors.orange,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  : () async {
                                      HapticFeedback.lightImpact();
                                      if (_currentUserIsPremium) {
                                        // Check eligibility before showing challenge dialog
                                        await _checkAndShowChallenge();
                                      } else {
                                        // Show premium paywall for non-premium users
                                        _showPremiumPaywall();
                                      }
                                    },
                              child: Opacity(
                                opacity: _isUserChallengeRestricted() ? 0.4 : 1.0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: _isUserChallengeRestricted()
                                        ? Colors.grey.shade300 // Grayed out for restricted users
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _isUserChallengeRestricted()
                                          ? Colors.grey.shade400
                                          : (_currentUserIsPremium
                                              ? const Color(0xFFDC2626)
                                              : Colors.grey.shade400),
                                      width: 2,
                                    ),
                                    boxShadow: _isUserChallengeRestricted()
                                        ? [] // No shadow for disabled state
                                        : [
                                            BoxShadow(
                                              color: Colors.grey.shade300,
                                              offset: const Offset(4, 4),
                                              blurRadius: 8,
                                              spreadRadius: 0,
                                            ),
                                            const BoxShadow(
                                              color: Colors.white,
                                              offset: Offset(-4, -4),
                                              blurRadius: 8,
                                              spreadRadius: 0,
                                            ),
                                          ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isUserChallengeRestricted()
                                            ? Icons.block // Blocked icon for restricted users
                                            : (_currentUserIsPremium ? Icons.gavel : Icons.lock),
                                        color: _isUserChallengeRestricted()
                                            ? Colors.grey.shade600
                                            : (_currentUserIsPremium
                                                ? const Color(0xFFDC2626)
                                                : Colors.grey.shade600),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isUserChallengeRestricted()
                                            ? 'Unavailable'
                                            : (_currentUserIsPremium ? 'Challenge' : 'Premium'),
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),

                      // Global Ranking display (full width)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF8B5CF6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade300,
                              offset: const Offset(4, 4),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                            const BoxShadow(
                              color: Colors.white,
                              offset: Offset(-4, -4),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getTierEmoji(_tier),
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _globalRank != null && _globalRank! > 0
                                  ? 'Rank #$_globalRank • $_tier'
                                  : 'Unranked',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Moderator Actions: Ban and Kick (visible for both moderators and super mods, only if viewing another user)
                      if ((widget.isCurrentUserModerator || _isCurrentUserSuperMod) &&
                          widget.roomId != null &&
                          widget.roomType != null &&
                          widget.user.id != _currentUserId) ...[
                        Row(
                          children: [
                            // Ban User button
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    AppLogger().info('🔨 Ban button tapped - userId: ${widget.user.id}, currentUserId: $_currentUserId, roomId: ${widget.roomId}, roomType: ${widget.roomType}');
                                    HapticFeedback.lightImpact();
                                    _showBanDialog();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6B35).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFFF6B35),
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.block,
                                          color: Color(0xFFFF6B35),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Ban',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Kick User button
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    AppLogger().info('👢 Kick button tapped - userId: ${widget.user.id}, currentUserId: $_currentUserId, roomId: ${widget.roomId}');
                                    HapticFeedback.lightImpact();
                                    _showKickDialog();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFA500).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFFFA500),
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.exit_to_app,
                                          color: Color(0xFFFFA500),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Kick',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                      ],


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
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFF2400),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade300,
                                offset: const Offset(4, 4),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                              const BoxShadow(
                                color: Colors.white,
                                offset: Offset(-4, -4),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.report_problem,
                                color: Color(0xFFFF2400),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Report User',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
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
            color: Color(0xFF2D3748),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Check challenge eligibility and show dialog or error message
  Future<void> _checkAndShowChallenge() async {
    final eligibilityService = ChallengeEligibilityService();

    // Check if current user can issue challenges
    final canIssueChallenge = await eligibilityService.canCurrentUserIssueChallenge();
    if (canIssueChallenge != null) {
      if (mounted) {
        _showChallengeBlockedDialog('Cannot Issue Challenge', canIssueChallenge);
      }
      return;
    }

    // Check if target user can be challenged
    final canBeChallenge = await eligibilityService.canUserBeChallenged(widget.user.id);
    if (canBeChallenge != null) {
      if (mounted) {
        _showChallengeBlockedDialog('Cannot Challenge This User', canBeChallenge);
      }
      return;
    }

    // Both checks passed - show challenge dialog
    _showChallengeDialog();
  }

  /// Show dialog when challenge is blocked
  void _showChallengeBlockedDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
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

  /// Show premium paywall for non-premium users
  void _showPremiumPaywall() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.diamond, color: Color(0xFF6B46C1)),
            SizedBox(width: 8),
            Text('Premium Feature'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Challenge users to debates with Premium!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text('Premium members get:'),
            SizedBox(height: 8),
            Text('• Unlimited debate challenges'),
            Text('• Premium badge'),
            Text('• Priority support'),
            Text('• 1,000 bonus coins'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to premium/paywall screen
              Navigator.pushNamed(context, '/paywall');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B46C1),
            ),
            child: const Text(
              'Get Premium',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
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

  /// Show ban user dialog
  void _showBanDialog() {
    AppLogger().info('🔨 Show ban dialog - currentUserId: $_currentUserId, roomId: ${widget.roomId}, roomType: ${widget.roomType}, isSuperMod: $_isCurrentUserSuperMod');

    final reasonController = TextEditingController();
    int? durationMinutes;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('🛡️ Ban ${widget.user.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'Why are you banning this user?',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  value: durationMinutes,
                  decoration: const InputDecoration(labelText: 'Duration'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Permanent')),
                    DropdownMenuItem(value: 30, child: Text('30 minutes')),
                    DropdownMenuItem(value: 60, child: Text('1 hour')),
                    DropdownMenuItem(value: 1440, child: Text('24 hours')),
                    DropdownMenuItem(value: 10080, child: Text('7 days')),
                  ],
                  onChanged: (value) => setState(() => durationMinutes = value),
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
                Navigator.pop(context);
                await _banUser(
                  reasonController.text.trim(),
                  durationMinutes,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
              ),
              child: const Text('Ban User'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show kick user dialog
  void _showKickDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('👢 Kick ${widget.user.name}'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Why are you kicking this user?',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _kickUser(reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFA500),
            ),
            child: const Text('Kick User'),
          ),
        ],
      ),
    );
  }

  /// Ban user from room
  Future<void> _banUser(String reason, int? durationMinutes) async {
    AppLogger().info('🔨 Attempting to ban user: ${widget.user.id}, currentUserId: $_currentUserId, roomId: ${widget.roomId}, roomType: ${widget.roomType}');

    if (_currentUserId == null) {
      AppLogger().error('Ban failed: currentUserId is null - still loading');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏳ Still loading user info, please wait a moment and try again'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (widget.roomId == null || widget.roomType == null) {
      AppLogger().error('Ban failed: roomId or roomType is null');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Room information missing'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Check if target user is a super moderator (super mods are immune to ban)
    final superModService = SuperModeratorService();
    bool isTargetSuperMod = superModService.isSuperModerator(widget.user.id);

    // Database fallback if not in cache
    if (!isTargetSuperMod) {
      try {
        final allSuperMods = await superModService.getAllSuperModerators();
        isTargetSuperMod = allSuperMods.any((sm) => sm.userId == widget.user.id && sm.isActive);
      } catch (e) {
        AppLogger().error('Ban check: Database fallback failed: $e');
      }
    }

    if (isTargetSuperMod) {
      _showSuperModImmunityDialog('ban');
      return;
    }

    try {
      // Get current user profile for moderator name
      final appwrite = AppwriteService();
      final currentUser = await appwrite.getCurrentUser();
      if (currentUser == null) return;

      final userProfile = await appwrite.getUserProfile(currentUser.$id);
      if (userProfile == null) return;

      // Use UserBanService (calls ban-user Appwrite Function)
      final banService = UserBanService();
      final success = await banService.banUser(
        userId: widget.user.id,
        roomId: widget.roomId!,
        roomType: widget.roomType ?? 'unknown',
        moderatorId: _currentUserId!,
        moderatorName: userProfile.name,
        reason: reason.isNotEmpty ? reason : null,
        durationMinutes: durationMinutes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '🔨 ${widget.user.name} has been banned'
                  : '❌ Failed to ban user',
            ),
            backgroundColor: success ? const Color(0xFFFF6B35) : Colors.red,
          ),
        );
        if (success) {
          _close();
        }
      }
    } catch (e) {
      AppLogger().error('Failed to ban user: $e');
      if (mounted) {
        final errorMessage = e.toString();

        // Check if error is about trying to ban a super moderator
        if (errorMessage.contains('Cannot ban super moderators')) {
          _showSuperModImmunityDialog('ban');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Kick user from room
  Future<void> _kickUser(String reason) async {
    AppLogger().info('👢 Attempting to kick user: ${widget.user.id}, currentUserId: $_currentUserId, roomId: ${widget.roomId}');

    if (_currentUserId == null) {
      AppLogger().error('Kick failed: currentUserId is null');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏳ Still loading user info, please wait and try again'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (widget.roomId == null) {
      AppLogger().error('Kick failed: roomId is null');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Room information missing'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Check if target user is a super moderator (super mods are immune to kick)
    final superModService = SuperModeratorService();
    bool isTargetSuperMod = superModService.isSuperModerator(widget.user.id);

    // Database fallback if not in cache
    if (!isTargetSuperMod) {
      try {
        final allSuperMods = await superModService.getAllSuperModerators();
        isTargetSuperMod = allSuperMods.any((sm) => sm.userId == widget.user.id && sm.isActive);
      } catch (e) {
        AppLogger().error('Kick check: Database fallback failed: $e');
      }
    }

    if (isTargetSuperMod) {
      _showSuperModImmunityDialog('kick');
      return;
    }

    try {
      // Get current user profile for moderator name
      final appwrite = AppwriteService();
      final currentUser = await appwrite.getCurrentUser();
      if (currentUser == null) return;

      final userProfile = await appwrite.getUserProfile(currentUser.$id);
      if (userProfile == null) return;

      // Use UserKickService (calls kick-user Appwrite Function)
      final kickService = UserKickService();
      final success = await kickService.kickUser(
        userId: widget.user.id,
        roomId: widget.roomId!,
        moderatorId: _currentUserId!,
        moderatorName: userProfile.name,
        reason: reason.isNotEmpty ? reason : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '👢 ${widget.user.name} has been kicked'
                  : '❌ Failed to kick user',
            ),
            backgroundColor: success ? const Color(0xFFFFA500) : Colors.red,
          ),
        );
        if (success) {
          _close();
        }
      }
    } catch (e) {
      AppLogger().error('Failed to kick user: $e');
      if (mounted) {
        final errorMessage = e.toString();

        // Check if error is about trying to kick a super moderator
        if (errorMessage.contains('Cannot kick super moderators')) {
          _showSuperModImmunityDialog('kick');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Show super moderator immunity dialog
  void _showSuperModImmunityDialog(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.shield, color: Color(0xFF6B46C1), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Super Moderator',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You cannot $action ${widget.user.name}.',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6B46C1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF6B46C1).withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Color(0xFF6B46C1),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This user is a Super Moderator and is immune to all moderation actions.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B46C1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  /// Show mute user dialog
  void _showMuteUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🔇 Mute ${widget.user.name}'),
        content: const Text('Mute this user\'s microphone? They will need to unmute themselves.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _muteUser();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
            ),
            child: const Text('Mute User'),
          ),
        ],
      ),
    );
  }

  /// Mute this specific user's microphone
  Future<void> _muteUser() async {
    if (_currentUserId == null || widget.roomId == null) {
      return;
    }

    // Check if target user is a super moderator (super mods are immune to mute)
    final superModService = SuperModeratorService();
    bool isTargetSuperMod = superModService.isSuperModerator(widget.user.id);

    // Database fallback if not in cache
    if (!isTargetSuperMod) {
      try {
        final allSuperMods = await superModService.getAllSuperModerators();
        isTargetSuperMod = allSuperMods.any((sm) => sm.userId == widget.user.id && sm.isActive);
      } catch (e) {
        AppLogger().error('Mute check: Database fallback failed: $e');
      }
    }

    if (isTargetSuperMod) {
      _showSuperModImmunityDialog('mute');
      return;
    }

    try {
      AppLogger().info('🔇 Muting user ${widget.user.id} (${widget.user.name})');

      // Use RoomAudioAdapter to mute the specific participant
      final audioAdapter = RoomAudioAdapter();
      await audioAdapter.muteParticipant(widget.user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔇 ${widget.user.name} has been muted'),
            backgroundColor: const Color(0xFF8B5CF6),
          ),
        );
        _close();
      }
    } catch (e) {
      AppLogger().error('Failed to mute user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show timeout dialog (moderator only)
  void _showTimeoutDialog() {
    AppLogger().info('⏰ _showTimeoutDialog called - showing dialog');
    AppLogger().info('⏰ Widget mounted: $mounted');

    if (!mounted) {
      AppLogger().error('⏰ Cannot show dialog - widget not mounted');
      return;
    }

    final reasonController = TextEditingController();
    int selectedDuration = 2; // Default to 2 minutes

    showDialog(
      context: context,
      builder: (context) {
        AppLogger().info('⏰ Dialog builder called');
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('⏰ Timeout ${widget.user.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'User will not be able to speak or send messages during timeout.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedDuration,
                    decoration: const InputDecoration(labelText: 'Duration'),
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('2 minutes')),
                      DropdownMenuItem(value: 5, child: Text('5 minutes')),
                      DropdownMenuItem(value: 10, child: Text('10 minutes')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedDuration = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      hintText: 'Why timeout this user?',
                    ),
                    maxLines: 2,
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
                  Navigator.pop(context);
                  await _timeoutUser(
                    selectedDuration,
                    reasonController.text.trim(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFA500),
                ),
                child: const Text('Timeout'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Timeout user (moderator only)
  Future<void> _timeoutUser(int durationMinutes, String reason) async {
    AppLogger().info('⏰ _timeoutUser called - duration: $durationMinutes, reason: "$reason"');
    AppLogger().info('⏰ Current user ID: $_currentUserId, Room ID: ${widget.roomId}, Target user ID: ${widget.user.id}');

    if (_currentUserId == null || widget.roomId == null) {
      AppLogger().error('⏰ FAILED: Missing currentUserId or roomId');
      return;
    }

    // CRITICAL: Pre-check if target is a Super Moderator (prevents authorization errors)
    final superModService = SuperModeratorService();
    bool isTargetSuperMod = superModService.isSuperModerator(widget.user.id);

    // Database fallback if not in cache
    if (!isTargetSuperMod) {
      try {
        final allSuperMods = await superModService.getAllSuperModerators();
        isTargetSuperMod = allSuperMods.any((sm) => sm.userId == widget.user.id && sm.isActive);
      } catch (e) {
        AppLogger().error('⏰ Pre-check database fallback failed: $e');
      }
    }

    if (isTargetSuperMod) {
      AppLogger().info('⏰ CLIENT PRE-CHECK: Blocked timeout attempt on super moderator');
      _showSuperModImmunityDialog('timeout');
      return;
    }

    try {
      final appwrite = AppwriteService();
      final currentUser = await appwrite.getCurrentUser();
      if (currentUser == null) return;

      final userProfile = await appwrite.getUserProfile(currentUser.$id);
      if (userProfile == null) return;

      // FIRST: Mute the user's microphone BEFORE starting timeout
      try {
        final audioAdapter = RoomAudioAdapter();
        await audioAdapter.muteParticipant(widget.user.id);
        AppLogger().info('🔇 Muted user ${widget.user.id} before timeout');
      } catch (e) {
        AppLogger().error('Failed to mute user before timeout: $e');
        // Continue with timeout even if mute fails
      }

      // THEN: Issue the timeout
      final timeoutService = UserTimeoutService();
      final success = await timeoutService.timeoutUser(
        userId: widget.user.id,
        roomId: widget.roomId!,
        moderatorId: _currentUserId!,
        moderatorName: userProfile.name,
        durationMinutes: durationMinutes,
        reason: reason.isNotEmpty ? reason : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '⏰ ${widget.user.name} timed out for $durationMinutes minutes'
                  : '❌ Failed to timeout user',
            ),
            backgroundColor: success ? const Color(0xFFFFA500) : Colors.red,
          ),
        );
        if (success) {
          _close();
        }
      }
    } catch (e) {
      AppLogger().error('Failed to timeout user: $e');
      if (mounted) {
        final errorMessage = e.toString().toLowerCase();

        // Check if error is specifically about trying to timeout a super moderator
        // Only show immunity dialog if the error explicitly mentions super moderator immunity
        if (errorMessage.contains('cannot timeout super moderator') ||
            (errorMessage.contains('super moderator') && errorMessage.contains('immune'))) {
          _showSuperModImmunityDialog('timeout');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
    String? roomId,
    String? roomType,
    bool isCurrentUserModerator = false,
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
        roomId: roomId,
        roomType: roomType,
        isCurrentUserModerator: isCurrentUserModerator,
      ),
    );
  }
}