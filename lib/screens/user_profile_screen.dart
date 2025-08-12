import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../models/gift.dart';
import '../widgets/user_avatar.dart';
import '../widgets/challenge_bell.dart';
import '../widgets/gift_bell.dart';
import '../services/gift_service.dart';
import '../services/coin_service.dart';
import '../services/appwrite_service.dart';
import '../features/user/providers/user_profile_provider.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  
  const UserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {

  // Colors matching app theme
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color lightScarlet = Color(0xFFFFF1F0);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  // Gift service and data
  final GiftService _giftService = GiftService();
  final CoinService _coinService = CoinService();
  
  Future<int> _getCurrentUserCoins() async {
    try {
      final appwriteService = AppwriteService();
      final currentUser = await appwriteService.getCurrentUser();
      print('🪙 DEBUG: Current user: ${currentUser?.$id}');
      
      if (currentUser != null) {
        final userProfile = await appwriteService.getUserProfile(currentUser.$id);
        print('🪙 DEBUG: User profile found: ${userProfile != null}');
        print('🪙 DEBUG: Current reputation: ${userProfile?.reputation}');
        
        final coins = await _coinService.getUserCoins(currentUser.$id);
        print('🪙 DEBUG: Coin service returned: $coins');
        return coins;
      }
    } catch (e) {
      // If error getting current user, still try to get coins with fallback
      print('🪙 ERROR: Error getting current user for coins: $e');
    }
    // Return 500 as fallback for testing (same as coin service)
    print('🪙 DEBUG: Returning fallback 500 coins');
    return 500;
  }

  // Debug method to manually initialize coins
  Future<void> _debugInitializeCoins() async {
    try {
      final appwriteService = AppwriteService();
      final currentUser = await appwriteService.getCurrentUser();
      
      if (currentUser != null) {
        print('🔧 DEBUG: Manually initializing coins for ${currentUser.$id}');
        
        // Try to update the user profile with starting coins
        await appwriteService.updateUserProfile(
          userId: currentUser.$id,
          reputation: 500,
          coinBalance: 1000,
        );
        
        print('🔧 DEBUG: Successfully updated user profile with coins');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debug: Initialized coins! Check your balance now.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('🔧 ERROR: Failed to initialize coins: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  Map<String, int> _giftStats = {};
  List<MapEntry<Gift, int>> _topGifts = [];
  bool _loadingGifts = true;

  @override
  void initState() {
    super.initState();
    // Trigger initial load of user profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileProvider(widget.userId).notifier).refresh();
      _loadGiftData();
    });
  }

  Future<void> _loadGiftData() async {
    try {
      setState(() => _loadingGifts = true);
      
      final stats = await _giftService.getGiftStats(widget.userId);
      final topGifts = await _giftService.getMostReceivedGifts(widget.userId, limit: 3);
      
      if (mounted) {
        setState(() {
          _giftStats = stats;
          _topGifts = topGifts;
          _loadingGifts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingGifts = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    final notifier = ref.read(userProfileProvider(widget.userId).notifier);
    final success = await notifier.toggleFollow();
    
    if (mounted) {
      final state = ref.read(userProfileProvider(widget.userId));
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.isFollowing ? '✅ Following ${state.userProfile?.name}' : 'Unfollowed ${state.userProfile?.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!)),
        );
      }
    }
  }

  Future<void> _showChallengeModal() async {
    final notifier = ref.read(userProfileProvider(widget.userId).notifier);
    if (!notifier.canInteract) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send challenges')),
      );
      return;
    }

    final topicController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedPosition = 'affirmative'; // Default position

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flash_on, color: scarletRed, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Challenge ${ref.read(userProfileProvider(widget.userId)).userProfile?.name}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: deepPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: topicController,
                  decoration: const InputDecoration(
                    labelText: 'Debate Topic',
                    hintText: 'What should we debate about?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Details (Optional)',
                    hintText: 'Any specific rules or context...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                
                // Position Selection
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Position in the Debate:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: deepPurple,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('For (Affirmative)'),
                              subtitle: const Text('You argue in favor'),
                              value: 'affirmative',
                              groupValue: selectedPosition,
                              onChanged: (value) {
                                setState(() {
                                  selectedPosition = value!;
                                });
                              },
                              activeColor: Colors.green,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Against (Negative)'),
                              subtitle: const Text('You argue against'),
                              value: 'negative',
                              groupValue: selectedPosition,
                              onChanged: (value) {
                                setState(() {
                                  selectedPosition = value!;
                                });
                              },
                              activeColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _sendChallenge(
                    topicController.text, 
                    descriptionController.text,
                    selectedPosition,
                  ),
                  icon: const Icon(Icons.send),
                  label: const Text('Send Challenge'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scarletRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendChallenge(String topic, String description, String position) async {
    Navigator.pop(context); // Close modal

    final notifier = ref.read(userProfileProvider(widget.userId).notifier);
    final success = await notifier.sendChallenge(topic, description, position);

    if (mounted) {
      final state = ref.read(userProfileProvider(widget.userId));
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Challenge sent to ${state.userProfile?.name}!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error!),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userProfileProvider(widget.userId));
    final userProfile = profileState.userProfile;
    final isLoading = profileState.isLoading;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(userProfile?.name ?? 'User Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: scarletRed),
        titleTextStyle: const TextStyle(
          color: deepPurple,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        actions: const [
          ChallengeBell(iconColor: Color(0xFF6B46C1)),
          SizedBox(width: 12),
          GiftBell(iconColor: Color(0xFF8B5CF6)),
          SizedBox(width: 16),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userProfile == null
              ? const Center(
                  child: Text(
                    'User profile not found',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 24),
                    _buildStatsCard(userProfile),
                    const SizedBox(height: 24),
                    _buildGiftsSection(userProfile),
                    const SizedBox(height: 24),
                    if (userProfile.bio?.isNotEmpty == true)
                      _buildBioCard(userProfile),
                    if (userProfile.interests.isNotEmpty)
                      _buildInterestsCard(userProfile),
                    if (_hasAnyLinks(userProfile))
                      _buildSocialLinksCard(userProfile),
                  ],
                ),
    );
  }

  Widget _buildProfileHeader() {
    final profileState = ref.watch(userProfileProvider(widget.userId));
    final userProfile = profileState.userProfile!;
    final notifier = ref.read(userProfileProvider(widget.userId).notifier);
    final canInteract = notifier.canInteract;
    
    return Column(
      children: [
        UserAvatar(
          avatarUrl: userProfile.avatar,
          initials: userProfile.initials,
          radius: 60,
          backgroundColor: lightScarlet,
          textColor: scarletRed,
        ),
        const SizedBox(height: 16),
        Text(
          userProfile.displayName,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: deepPurple,
          ),
        ),
        if (userProfile.location?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                userProfile.location!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
        
        // Follower/Following counts
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFollowStat('Followers', profileState.followerCount),
            const SizedBox(width: 32),
            _buildFollowStat('Following', profileState.followingCount),
          ],
        ),
        
        // Action buttons (only show if not own profile and user is logged in)
        if (canInteract) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: profileState.isLoadingAction ? null : _toggleFollow,
                  icon: profileState.isLoadingAction 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(profileState.isFollowing ? Icons.person_remove : Icons.person_add),
                  label: Text(profileState.isFollowing ? 'Following' : 'Follow'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: profileState.isFollowing ? Colors.grey : accentPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showChallengeModal,
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Challenge'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scarletRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSendGiftModal(userProfile),
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('Send Gift'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFollowStat(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: deepPurple,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(UserProfile userProfile) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stats',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatItem('Reputation', userProfile.reputation.toString())),
                Expanded(child: _buildStatItem('Debates', userProfile.totalDebates.toString())),
                Expanded(child: _buildStatItem('Wins', userProfile.totalWins.toString())),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatItem('Win Rate', '${(userProfile.winPercentage * 100).toStringAsFixed(1)}%')),
                Expanded(child: _buildStatItem('Clubs', userProfile.totalRoomsCreated.toString())),
                Expanded(child: _buildStatItem('Joined', userProfile.totalRoomsJoined.toString())),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: scarletRed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildBioCard(UserProfile userProfile) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              userProfile.bio!,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestsCard(UserProfile userProfile) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Interests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: userProfile.interests.map((interest) => Chip(
                label: Text(
                  interest,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: accentPurple.withValues(alpha: 0.1),
                side: BorderSide.none,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinksCard(UserProfile userProfile) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Social Links',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            if (userProfile.website?.isNotEmpty == true)
              _buildLinkTile(Icons.language, 'Website', userProfile.website!),
            if (userProfile.xHandle?.isNotEmpty == true)
              _buildLinkTile(Icons.alternate_email, 'X (Twitter)', userProfile.xHandle!),
            if (userProfile.linkedinHandle?.isNotEmpty == true)
              _buildLinkTile(Icons.business, 'LinkedIn', userProfile.linkedinHandle!),
            if (userProfile.youtubeHandle?.isNotEmpty == true)
              _buildLinkTile(Icons.play_circle, 'YouTube', userProfile.youtubeHandle!),
            if (userProfile.facebookHandle?.isNotEmpty == true)
              _buildLinkTile(Icons.facebook, 'Facebook', userProfile.facebookHandle!),
            if (userProfile.instagramHandle?.isNotEmpty == true)
              _buildLinkTile(Icons.camera_alt, 'Instagram', userProfile.instagramHandle!),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkTile(IconData icon, String platform, String handle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accentPurple),
          const SizedBox(width: 12),
          Text(
            platform,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: deepPurple,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              (platform == 'X (Twitter)' || platform == 'Instagram') 
                  ? '@$handle' 
                  : handle,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasAnyLinks(UserProfile userProfile) {
    return (userProfile.website?.isNotEmpty == true) ||
           (userProfile.xHandle?.isNotEmpty == true) ||
           (userProfile.linkedinHandle?.isNotEmpty == true) ||
           (userProfile.youtubeHandle?.isNotEmpty == true) ||
           (userProfile.facebookHandle?.isNotEmpty == true) ||
           (userProfile.instagramHandle?.isNotEmpty == true);
  }

  Widget _buildGiftsSection(UserProfile userProfile) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_giftcard, size: 20, color: accentPurple),
                const SizedBox(width: 8),
                const Text(
                  'Gifts Received',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: deepPurple,
                  ),
                ),
                const Spacer(),
                if (!_loadingGifts && _giftStats['totalGifts'] != null && _giftStats['totalGifts']! > 0)
                  GestureDetector(
                    onTap: () => _showAllGifts(userProfile),
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: accentPurple,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_loadingGifts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: accentPurple),
                ),
              )
            else if (_giftStats['totalGifts'] == 0)
              _buildNoGiftsState()
            else
              Column(
                children: [
                  // Gift stats row
                  Row(
                    children: [
                      Expanded(
                        child: _buildGiftStat(
                          '${_giftStats['totalGifts'] ?? 0}',
                          'Total Gifts',
                          Icons.card_giftcard,
                          accentPurple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGiftStat(
                          '${_giftStats['totalValue'] ?? 0}',
                          'Gift Value',
                          Icons.diamond,
                          Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGiftStat(
                          '${_giftStats['uniqueGifts'] ?? 0}',
                          'Unique Gifts',
                          Icons.auto_awesome,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  
                  if (_topGifts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Most Received Gifts',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: deepPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _topGifts.map((entry) => _buildTopGift(entry.key, entry.value)).toList(),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoGiftsState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.card_giftcard_outlined,
            size: 40,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'No gifts received yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gifts from other users will appear here',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGiftStat(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTopGift(Gift gift, int count) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: accentPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: accentPurple.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              gift.emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          gift.name,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '×$count',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showAllGifts(UserProfile userProfile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              // Header
              Row(
                children: [
                  const Icon(Icons.card_giftcard, color: accentPurple),
                  const SizedBox(width: 8),
                  Text(
                    '${userProfile.name}\'s Gifts',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: deepPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Gift history (placeholder for now)
              Expanded(
                child: Center(
                  child: Text(
                    'Gift history coming soon!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSendGiftModal(UserProfile userProfile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        minChildSize: 0.6,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              // Header
              Row(
                children: [
                  const Icon(Icons.card_giftcard, color: accentPurple),
                  const SizedBox(width: 8),
                  Text(
                    'Send Gift to ${userProfile.name}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: deepPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Coin balance display
              FutureBuilder<int>(
                future: _getCurrentUserCoins(),
                builder: (context, snapshot) {
                  final coins = snapshot.data ?? 0;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: Color(0xFF8B5CF6),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Your Balance: $coins coins',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B46C1),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              
              // Gift categories
              Expanded(
                child: DefaultTabController(
                  length: GiftCategory.values.length,
                  child: Column(
                    children: [
                      TabBar(
                        isScrollable: true,
                        labelColor: accentPurple,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: accentPurple,
                        tabs: GiftCategory.values.map((category) => Tab(
                          text: category.name.replaceAllMapped(
                            RegExp(r'([A-Z])'),
                            (match) => ' ${match.group(1)}',
                          ).trim().split(' ').map((word) => 
                            word[0].toUpperCase() + word.substring(1).toLowerCase()
                          ).join(' '),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                      
                      Expanded(
                        child: TabBarView(
                          children: GiftCategory.values.map((category) => 
                            _buildGiftCategoryGrid(category, userProfile)
                          ).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiftCategoryGrid(GiftCategory category, UserProfile userProfile) {
    final categoryGifts = GiftConstants.allGifts.where((gift) => gift.category == category).toList();
    
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: categoryGifts.length,
      itemBuilder: (context, index) {
        final gift = categoryGifts[index];
        return _buildGiftCard(gift, userProfile);
      },
    );
  }

  Widget _buildGiftCard(Gift gift, UserProfile userProfile) {
    return FutureBuilder<int>(
      future: _getCurrentUserCoins(),
      builder: (context, snapshot) {
        final userCoins = snapshot.data ?? 0;
        final canAfford = userCoins >= gift.cost;
        
        return GestureDetector(
          onTap: canAfford ? () => _sendGift(gift, userProfile) : null,
          child: Container(
            decoration: BoxDecoration(
              color: canAfford 
                ? accentPurple.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: canAfford 
                  ? accentPurple.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.3)
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  gift.emoji,
                  style: TextStyle(
                    fontSize: 32,
                    color: canAfford ? null : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  gift.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: canAfford ? null : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${gift.cost} coins',
                  style: TextStyle(
                    fontSize: 10,
                    color: canAfford ? Colors.grey[600] : Colors.red,
                    fontWeight: canAfford ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
                if (!canAfford) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Insufficient funds',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendGift(Gift gift, UserProfile userProfile) async {
    Navigator.pop(context); // Close gift modal
    
    // Show confirmation dialog
    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(gift.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text('Send ${gift.name}?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To: ${userProfile.name}'),
            Text('Cost: ${gift.cost} coins'),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Optional message',
                hintText: 'Add a personal message...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (value) {
                // Store message for sending
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: accentPurple),
            child: const Text('Send Gift'),
          ),
        ],
      ),
    );

    if (shouldSend == true) {
      try {
        // Send the gift
        final success = await _giftService.sendGift(
          giftId: gift.id,
          receiverId: widget.userId,
          receiverName: userProfile.name,
          message: '', // Get from dialog if needed
        );

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Text(gift.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text('${gift.name} sent to ${userProfile.name}!'),
                  ],
                ),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to send gift. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = 'Failed to send gift. Please try again.';
          if (e.toString().contains('Insufficient coins')) {
            errorMessage = 'Insufficient coins. You need ${gift.cost} coins to send this gift.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}