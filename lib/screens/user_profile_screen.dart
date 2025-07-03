import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../widgets/user_avatar.dart';
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

  @override
  void initState() {
    super.initState();
    // Trigger initial load of user profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileProvider(widget.userId).notifier).refresh();
    });
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
              const SizedBox(width: 12),
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
}