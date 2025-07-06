import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/agora_service.dart';
import '../services/appwrite_service.dart';
import '../models/user_profile.dart';
import '../models/gift.dart';
import '../widgets/animated_fade_in.dart';
import '../core/logging/app_logger.dart';

class DebatesDiscussionsScreen extends StatefulWidget {
  const DebatesDiscussionsScreen({super.key});

  @override
  State<DebatesDiscussionsScreen> createState() => _DebatesDiscussionsScreenState();
}

class _DebatesDiscussionsScreenState extends State<DebatesDiscussionsScreen> {
  final AgoraService _agoraService = AgoraService();
  List<UserProfile> _activeParticipants = [];
  List<UserProfile> _audienceMembers = [];
  Map<String, bool> _participantVideoStates = {};
  Map<String, bool> _participantMicStates = {};
  bool _isLoading = true;
  bool _isVideoEnabled = true;
  bool _isMicEnabled = true;
  bool _isJoined = false;

  @override
  void initState() {
    super.initState();
    _initializeRoom();
  }

  @override
  void dispose() {
    _leaveRoom();
    super.dispose();
  }

  Future<void> _initializeRoom() async {
    try {
      // Initialize and join the debates and discussions room
      await _agoraService.initialize();
      
      // Set up callbacks
      _agoraService.onUserJoined = (uid) {
        _onUserJoined(uid);
      };
      _agoraService.onUserLeft = (uid) {
        _onUserLeft(uid);
      };
      
      // Join the channel
      await _agoraService.joinChannel();

      // Initialize mock audience members
      _initializeAudienceMembers();

      setState(() {
        _isJoined = true;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger().error('Failed to initialize debates room: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeAudienceMembers() {
    final audienceNames = [
      'Selena', 'Billie', 'Dwayne', 'Lady', 'Taylor', 'Kim', 'Zayn', 'Miley',
      'Drake', 'Ariana', 'Justin', 'Rihanna', 'Kanye', 'Beyonce', 'Jay-Z', 'Adele'
    ];
    
    _audienceMembers = audienceNames.map((name) => UserProfile(
      id: 'audience_${name.toLowerCase()}',
      name: name,
      email: '${name.toLowerCase()}@example.com',
      avatar: null, // In real app, these would have actual profile pictures
      bio: 'Audience member',
      reputation: 0,
      totalWins: 0,
      totalDebates: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    )).toList();
  }

  Future<void> _leaveRoom() async {
    if (_isJoined) {
      await _agoraService.leaveChannel();
      setState(() {
        _isJoined = false;
      });
    }
  }

  void _onUserJoined(int uid) {
    // Add mock user for demonstration
    final mockUser = UserProfile(
      id: uid.toString(),
      name: 'User $uid',
      email: 'user$uid@example.com',
      avatar: null,
      bio: 'Debate enthusiast',
      reputation: 0,
      totalWins: 0,
      totalDebates: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _activeParticipants.add(mockUser);
    });
  }

  void _onUserLeft(int uid) {
    setState(() {
      _activeParticipants.removeWhere((user) => user.id == uid.toString());
    });
  }

  void _toggleVideo() {
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });
    // Video toggle not implemented in current AgoraService
    // _agoraService.toggleVideo(_isVideoEnabled);
  }

  void _toggleMic() {
    setState(() {
      _isMicEnabled = !_isMicEnabled;
    });
    _agoraService.muteLocalAudio(!_isMicEnabled);
  }

  bool _getParticipantVideoState(String participantId) {
    return _participantVideoStates[participantId] ?? true;
  }

  bool _getParticipantMicState(String participantId) {
    return _participantMicStates[participantId] ?? true;
  }

  void _toggleParticipantVideo(String participantId) {
    setState(() {
      _participantVideoStates[participantId] = !_getParticipantVideoState(participantId);
    });
    // In real implementation, this would control the specific participant's video
    AppLogger().debug('Toggled video for participant: $participantId');
  }

  void _toggleParticipantMic(String participantId) {
    setState(() {
      _participantMicStates[participantId] = !_getParticipantMicState(participantId);
    });
    // In real implementation, this would control the specific participant's mic
    AppLogger().debug('Toggled mic for participant: $participantId');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildVideoGrid(),
            ),
            _buildControlsBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                LucideIcons.arrowLeft,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Debates & Discussions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_activeParticipants.length + 1} participants',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    // Create a list including current user and participants
    final allParticipants = [
      // Current user (always first)
      UserProfile(
        id: 'current_user',
        name: 'You',
        email: 'current@user.com',
        avatar: null,
        bio: 'Current user',
        reputation: 0,
        totalWins: 0,
        totalDebates: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ..._activeParticipants,
    ];

    // Add mock participants to match the new layout (7 participants total: 3 + 3 + 1)
    while (allParticipants.length < 7) {
      final index = allParticipants.length;
      allParticipants.add(UserProfile(
        id: 'mock_$index',
        name: 'Participant $index',
        email: 'participant$index@example.com',
        avatar: null,
        bio: 'Mock participant',
        reputation: 0,
        totalWins: 0,
        totalDebates: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    // Calculate responsive dimensions based on screen size
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight - 200; // Account for header and controls
    final videoTileHeight = (availableHeight * 0.25).clamp(80.0, 110.0);
    final moderatorHeight = (availableHeight * 0.22).clamp(80.0, 100.0);
    final audienceHeight = (availableHeight * 0.28).clamp(80.0, 120.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      child: Column(
        children: [
          // Top row - 3 participants
          SizedBox(
            height: videoTileHeight,
            child: Row(
              children: [
                Expanded(
                  child: _buildVideoTile(allParticipants[0]),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildVideoTile(allParticipants[1]),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildVideoTile(allParticipants[2]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // Second row - 3 participants
          SizedBox(
            height: videoTileHeight,
            child: Row(
              children: [
                Expanded(
                  child: _buildVideoTile(allParticipants[3]),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildVideoTile(allParticipants[4]),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildVideoTile(allParticipants[5]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // Moderator row - 1 moderator (centered)
          SizedBox(
            height: moderatorHeight,
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: SizedBox(), // Empty space
                ),
                Expanded(
                  flex: 4,
                  child: _buildVideoTile(
                    allParticipants[6], 
                    isLarge: false, 
                    isModerator: true,
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: SizedBox(), // Empty space
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // Audience section
          SizedBox(
            height: audienceHeight,
            child: _buildAudienceSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoTile(UserProfile participant, {bool isLarge = false, bool isModerator = false}) {
    return AnimatedFadeIn(
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Video placeholder (would be actual video in real implementation)
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: participant.avatar != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        participant.avatar!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildAvatarPlaceholder(participant),
                      ),
                    )
                  : _buildAvatarPlaceholder(participant),
            ),
            // Name label at bottom
            Positioned(
              bottom: 2,
              left: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isModerator 
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.9)
                      : Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isModerator) ...[
                      const Icon(
                        LucideIcons.crown,
                        color: Colors.white,
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                    ],
                    Flexible(
                      child: Text(
                        isModerator ? '${participant.name} (Mod)' : participant.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Controls row at top
            Positioned(
              top: 2,
              left: 2,
              right: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Video control
                  GestureDetector(
                    onTap: () => _toggleParticipantVideo(participant.id),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _getParticipantVideoState(participant.id) 
                            ? Colors.green 
                            : Colors.red,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Icon(
                        _getParticipantVideoState(participant.id) 
                            ? LucideIcons.video 
                            : LucideIcons.videoOff,
                        color: Colors.white,
                        size: 8,
                      ),
                    ),
                  ),
                  // Mic control
                  GestureDetector(
                    onTap: () => _toggleParticipantMic(participant.id),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _getParticipantMicState(participant.id) 
                            ? Colors.green 
                            : Colors.red,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Icon(
                        _getParticipantMicState(participant.id) 
                            ? LucideIcons.mic 
                            : LucideIcons.micOff,
                        color: Colors.white,
                        size: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(UserProfile participant) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          participant.initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildControlsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: LucideIcons.messageCircle,
            isActive: false,
            onTap: () {
              // Open chat functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat feature coming soon!')),
              );
            },
          ),
          _buildGiftButton(),
          _buildControlButton(
            icon: LucideIcons.moreHorizontal,
            isActive: false,
            onTap: () {
              // Open more options
              _showMoreOptions();
            },
          ),
          _buildControlButton(
            icon: LucideIcons.phoneOff,
            isActive: false,
            isDestructive: true,
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red
              : isActive
                  ? const Color(0xFF8B5CF6)
                  : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
          border: isActive
              ? null
              : Border.all(color: Colors.grey[600]!, width: 1),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'More Options',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: LucideIcons.settings,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings coming soon!')),
                );
              },
            ),
            _buildOptionTile(
              icon: LucideIcons.userPlus,
              title: 'Invite Others',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite feature coming soon!')),
                );
              },
            ),
            _buildOptionTile(
              icon: LucideIcons.flag,
              title: 'Report Issue',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report feature coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: onTap,
    );
  }

  Widget _buildAudienceSection() {
    // Calculate responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 360 ? 3 : 4; // Fewer columns on very small screens
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Audience header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              const Icon(
                LucideIcons.users,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'Audience (${_audienceMembers.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // Audience members - responsive grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 4,
              mainAxisSpacing: 2,
              childAspectRatio: 0.85, // Slightly taller to accommodate text
            ),
            itemCount: _audienceMembers.length,
            itemBuilder: (context, index) {
              return _buildAudienceMember(_audienceMembers[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAudienceMember(UserProfile member) {
    // Calculate responsive avatar size
    final screenWidth = MediaQuery.of(context).size.width;
    final avatarSize = screenWidth < 360 ? 40.0 : 44.0;
    final fontSize = screenWidth < 360 ? 8.0 : 9.0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Profile picture
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.grey[600]!,
              width: 1.0,
            ),
          ),
          child: ClipOval(
            child: member.avatar != null
                ? Image.network(
                    member.avatar!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildAudienceAvatar(member, avatarSize),
                  )
                : _buildAudienceAvatar(member, avatarSize),
          ),
        ),
        const SizedBox(height: 1),
        // Name
        Text(
          member.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildAudienceAvatar(UserProfile member, [double? size]) {
    // Generate different colors for different users
    final colors = [
      const Color(0xFF8B5CF6),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFF6366F1),
      const Color(0xFF06B6D4),
    ];
    
    final colorIndex = member.name.hashCode % colors.length;
    final avatarSize = size ?? 44.0;
    final fontSize = avatarSize * 0.4; // Dynamic font size based on avatar size
    
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        color: colors[colorIndex],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          member.initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildGiftButton() {
    return GestureDetector(
      onTap: _showGiftModal,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey[600]!, width: 1),
        ),
        child: const Icon(
          LucideIcons.gift,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  void _showGiftModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 450,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.gift,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Gifts & Tips',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Balance: 100 coins',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Gift and Money buttons
            Row(
              children: [
                Expanded(
                  child: _buildOptionButton(
                    icon: LucideIcons.gift,
                    label: 'Send Gift',
                    onTap: () {
                      Navigator.pop(context);
                      _showGiftSelection();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOptionButton(
                    icon: LucideIcons.dollarSign,
                    label: 'Send Money',
                    onTap: () {
                      Navigator.pop(context);
                      _showMoneySelection();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftTile(Gift gift) {
    return GestureDetector(
      onTap: () => _selectGift(gift),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[700]!, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              gift.emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              gift.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${gift.cost} coins',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectGift(Gift gift) {
    Navigator.pop(context);
    _showRecipientSelection(gift);
  }

  void _showRecipientSelection(Gift gift) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  gift.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gift.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${gift.cost} coins',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Send to:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: 7, // All participants including moderator
                itemBuilder: (context, index) {
                  final participantName = index == 0 ? 'You' : 
                      index == 6 ? 'Participant 6 (Moderator)' : 
                      'Participant $index';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF8B5CF6),
                      child: Text(
                        index == 0 ? 'Y' : 'P$index',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      participantName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => _sendGift(gift, participantName),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendGift(Gift gift, String recipient) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sent ${gift.emoji} ${gift.name} to $recipient!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[700]!, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGiftSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.card_giftcard, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  const Text(
                    'Select a Gift',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '100 coins', // Balance
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(),
            
            // Gift categories
            Expanded(
              child: _buildGiftSelectionTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftSelectionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gift categories
          ...GiftCategory.values.map((category) => _buildGiftCategorySection(category)),
        ],
      ),
    );
  }

  Widget _buildGiftCategorySection(GiftCategory category) {
    final categoryGifts = GiftConstants.getGiftsByCategory(category);
    if (categoryGifts.isEmpty) return Container();

    String categoryTitle = '';
    IconData categoryIcon = Icons.card_giftcard;
    Color categoryColor = Colors.grey;

    switch (category) {
      case GiftCategory.intellectual:
        categoryTitle = 'Intellectual Achievement';
        categoryIcon = Icons.psychology;
        categoryColor = Colors.blue;
        break;
      case GiftCategory.supportive:
        categoryTitle = 'Supportive & Encouraging';
        categoryIcon = Icons.favorite;
        categoryColor = Colors.pink;
        break;
      case GiftCategory.fun:
        categoryTitle = 'Fun & Personality';
        categoryIcon = Icons.emoji_emotions;
        categoryColor = Colors.orange;
        break;
      case GiftCategory.recognition:
        categoryTitle = 'Recognition & Status';
        categoryIcon = Icons.star;
        categoryColor = Colors.amber;
        break;
      case GiftCategory.interactive:
        categoryTitle = 'Interactive & Engaging';
        categoryIcon = Icons.touch_app;
        categoryColor = Colors.green;
        break;
      case GiftCategory.premium:
        categoryTitle = 'Premium';
        categoryIcon = Icons.diamond;
        categoryColor = Colors.purple;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(
                categoryIcon,
                color: categoryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                categoryTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: categoryColor,
                ),
              ),
            ],
          ),
        ),
        
        // Gift grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.2,
          ),
          itemCount: categoryGifts.length,
          itemBuilder: (context, index) {
            final gift = categoryGifts[index];
            return _buildFullGiftCard(gift);
          },
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFullGiftCard(Gift gift) {
    final canAfford = 100 >= gift.cost; // Assuming 100 coin balance
    
    return GestureDetector(
      onTap: canAfford ? () => _selectGift(gift) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: canAfford ? Colors.white : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canAfford ? const Color(0xFF8B5CF6) : Colors.grey[300]!,
            width: 1,
          ),
          boxShadow: canAfford ? [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Gift emoji
            Text(
              gift.emoji,
              style: TextStyle(
                fontSize: 24,
                color: canAfford ? null : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            
            // Gift name
            Text(
              gift.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: canAfford ? Colors.black87 : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            
            // Cost
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: canAfford ? const Color(0xFF8B5CF6) : Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${gift.cost} coins',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoneySelection() {
    final TextEditingController amountController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          height: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              Row(
                children: [
                  const Icon(
                    LucideIcons.dollarSign,
                    color: Color(0xFF8B5CF6),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Send Money',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Balance: 100 coins',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Enter amount:',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              // Amount input field
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter coins amount',
                  prefixIcon: const Icon(
                    LucideIcons.dollarSign,
                    color: Color(0xFF8B5CF6),
                  ),
                  suffixText: 'coins',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                  ),
                ),
                autofocus: true,
              ),
              
              const SizedBox(height: 20),
              
              // Quick amount buttons
              const Text(
                'Quick amounts:',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              
              Wrap(
                spacing: 8,
                children: [1, 5, 10, 25, 50, 100].map((amount) => 
                  GestureDetector(
                    onTap: () {
                      amountController.text = amount.toString();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        '$amount',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ).toList(),
              ),
              
              const Spacer(),
              
              // Send button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final amount = int.tryParse(amountController.text);
                    if (amount != null && amount > 0) {
                      Navigator.pop(context);
                      _showRecipientSelectionForMoney(amount);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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


  void _showRecipientSelectionForMoney(int amount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.dollarSign,
                  color: Colors.green,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$amount coins',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Money tip',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Send to:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: 7, // All participants including moderator
                itemBuilder: (context, index) {
                  final participantName = index == 0 ? 'You' : 
                      index == 6 ? 'Participant 6 (Moderator)' : 
                      'Participant $index';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF8B5CF6),
                      child: Text(
                        index == 0 ? 'Y' : 'P$index',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      participantName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => _sendMoney(amount, participantName),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMoney(int amount, String recipient) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sent $amount coins to $recipient!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}