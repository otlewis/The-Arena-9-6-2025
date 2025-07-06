import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/arena_state.dart';
import '../providers/arena_provider.dart';
import '../../../core/providers/app_providers.dart';
import '../../../services/firebase_gift_service.dart';
import '../../../models/gift.dart';
import '../../../services/appwrite_service.dart';
import 'arena_waiting_room.dart';

class ArenaDebateControls extends ConsumerStatefulWidget {
  const ArenaDebateControls({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<ArenaDebateControls> createState() => _ArenaDebateControlsState();
}

class _ArenaDebateControlsState extends ConsumerState<ArenaDebateControls> {
  final FirebaseGiftService _giftService = FirebaseGiftService();
  final AppwriteService _appwriteService = AppwriteService();
  
  int _currentUserCoinBalance = 0;
  Gift? _selectedGift;
  List<Gift> _availableGifts = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadGifts();
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = await _appwriteService.getCurrentUser();
      if (currentUser != null) {
        final balance = await _giftService.getUserCoinBalance(currentUser.$id);
        if (mounted) {
          setState(() {
            _currentUserCoinBalance = balance;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadGifts() async {
    try {
      final gifts = await _giftService.getAvailableGifts();
      if (mounted) {
        setState(() {
          _availableGifts = gifts;
        });
      }
    } catch (e) {
      debugPrint('Error loading gifts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final arenaState = ref.watch(arenaProvider(widget.roomId));

    if (arenaState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (arenaState.error != null) {
      return _buildErrorState(context, arenaState.error!);
    }
    
    return _buildControls(context, ref, arenaState);
  }

  Widget _buildControls(BuildContext context, WidgetRef ref, ArenaState state) {
    // Show waiting room if debate hasn't started
    if (state.status == ArenaStatus.waiting) {
      return Column(
        children: [
          ArenaWaitingRoom(roomId: widget.roomId),
          _buildBottomNavigationBar(context, ref, state),
        ],
      );
    }

    // Show debate controls during active debate
    final canUserSpeak = state.canUserSpeak(ref.read(currentUserIdProvider) ?? '');
    final isCurrentUser = state.currentSpeaker == ref.read(currentUserIdProvider);

    return Column(
      children: [
        // Main controls card
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhaseInfo(state),
                const SizedBox(height: 16),
                _buildSpeakingControls(context, ref, state, canUserSpeak, isCurrentUser),
                const SizedBox(height: 16),
                _buildSpeakerBottomSheet(context, ref, state),
              ],
            ),
          ),
        ),
        
        // Bottom navigation bar with controls
        _buildBottomNavigationBar(context, ref, state),
      ],
    );
  }

  Widget _buildPhaseInfo(ArenaState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Phase',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _getPhaseDisplayName(state.currentPhase),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_getPhaseDescription(state.currentPhase).isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _getPhaseDescription(state.currentPhase),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSpeakingControls(
    BuildContext context,
    WidgetRef ref,
    ArenaState state,
    bool canUserSpeak,
    bool isCurrentUser,
  ) {
    if (!canUserSpeak) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.mic_off, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            const Text(
              'Listening mode',
              style: TextStyle(color: Color(0xFF757575)),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isCurrentUser ? null : () => _requestToSpeak(ref),
            icon: Icon(isCurrentUser ? Icons.mic : Icons.mic_none),
            label: Text(isCurrentUser ? 'You are speaking' : 'Request to speak'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentUser ? Colors.green : null,
              foregroundColor: isCurrentUser ? Colors.white : null,
            ),
          ),
        ),
        if (isCurrentUser) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _stopSpeaking(ref),
            icon: const Icon(Icons.stop),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSpeakerBottomSheet(BuildContext context, WidgetRef ref, ArenaState state) {
    final currentUserId = ref.read(currentUserIdProvider);
    final isModerator = state.participants.values.any(
      (p) => p.userId == currentUserId && p.role == ArenaRole.moderator,
    );

    if (!isModerator) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.purple.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.purple),
              SizedBox(width: 8),
              Text(
                'Moderator Controls',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModeratorButton(
                  icon: Icons.mic,
                  label: 'Manage Speaker',
                  onTap: () => _showSpeakerControls(context, ref, state),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModeratorButton(
                  icon: Icons.timer,
                  label: 'Timer Controls',
                  onTap: () => _showTimerControls(context, ref, state),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeratorButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.purple, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.purple,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeakerControls(BuildContext context, WidgetRef ref, ArenaState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.mic, color: Colors.purple, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Speaker Controls',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Current speaker info
            if (state.currentSpeaker != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic, color: Colors.green),
                    const SizedBox(width: 12),
                    Text(
                      'Current Speaker: ${_getSpeakerName(state)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Available speakers
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _buildSpeakerList(context, ref, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTimerControls(BuildContext context, WidgetRef ref, ArenaState state) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Timer Controls',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(
                state.isTimerRunning ? Icons.pause : Icons.play_arrow,
                color: state.isTimerRunning ? Colors.orange : Colors.green,
              ),
              title: Text(state.isTimerRunning ? 'Pause Timer' : 'Start Timer'),
              onTap: () {
                Navigator.pop(context);
                if (state.isTimerRunning) {
                  ref.read(arenaProvider(widget.roomId).notifier).pauseTimer();
                } else {
                  ref.read(arenaProvider(widget.roomId).notifier).resumeTimer();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.skip_next, color: Colors.blue),
              title: const Text('Next Phase'),
              onTap: () {
                Navigator.pop(context);
                ref.read(arenaProvider(widget.roomId).notifier).nextPhase();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add, color: Colors.purple),
              title: const Text('Add 30 Seconds'),
              onTap: () {
                Navigator.pop(context);
                ref.read(arenaProvider(widget.roomId).notifier).addTime(30);
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSpeakerList(BuildContext context, WidgetRef ref, ArenaState state) {
    final debaters = [
      ...state.getParticipantsByRole(ArenaRole.affirmative),
      ...state.getParticipantsByRole(ArenaRole.negative),
    ];

    return debaters.map((participant) {
      final isCurrent = state.currentSpeaker == participant.userId;
      final roleColor = participant.role == ArenaRole.affirmative 
        ? Colors.blue 
        : Colors.red;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              border: Border.all(
                color: isCurrent ? Colors.green : roleColor,
                width: isCurrent ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                _getInitials(participant.name),
                style: TextStyle(
                  color: isCurrent ? Colors.green : roleColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          title: Text(
            participant.name,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          subtitle: Text(
            participant.role == ArenaRole.affirmative 
              ? 'Affirmative' 
              : 'Negative',
            style: TextStyle(color: roleColor),
          ),
          trailing: isCurrent 
            ? const Icon(Icons.mic, color: Colors.green)
            : IconButton(
                icon: const Icon(Icons.record_voice_over),
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(arenaProvider(widget.roomId).notifier)
                    .assignSpeaker(participant.userId);
                },
              ),
        ),
      );
    }).toList();
  }

  String _getSpeakerName(ArenaState state) {
    final speaker = state.participants[state.currentSpeaker];
    return speaker?.name ?? 'Unknown';
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to load debate controls',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _retry(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _requestToSpeak(WidgetRef ref) {
    ref.read(arenaProvider(widget.roomId).notifier).requestToSpeak();
  }

  void _stopSpeaking(WidgetRef ref) {
    ref.read(arenaProvider(widget.roomId).notifier).stopSpeaking();
  }


  void _retry() {
    // Handle retry logic
  }

  Widget _buildBottomNavigationBar(BuildContext context, WidgetRef ref, ArenaState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Gift button
            _buildControlButton(
              icon: Icons.card_giftcard,
              label: 'Gift',
              color: Colors.amber,
              onTap: _showGiftModal,
            ),
            
            // Moderator controls (if user is moderator)
            if (_isUserModerator(ref, state))
              _buildControlButton(
                icon: Icons.admin_panel_settings,
                label: 'Moderate',
                color: Colors.purple,
                onTap: () => _showModeratorControls(context, ref, state),
              ),
            
            // Leave arena
            _buildControlButton(
              icon: Icons.exit_to_app,
              label: 'Leave',
              color: Colors.red.shade400,
              onTap: () => _confirmLeaveArena(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  bool _isUserModerator(WidgetRef ref, ArenaState state) {
    final currentUserId = ref.read(currentUserIdProvider);
    return state.participants.values.any(
      (participant) => 
        participant.userId == currentUserId && 
        participant.role == ArenaRole.moderator,
    );
  }

  Future<void> _showGiftModal() async {
    // Check if user has premium subscription for gifting
    final currentUser = await _appwriteService.getCurrentUser();
    if (currentUser != null) {
      await _appwriteService.getUserProfile(currentUser.$id);
      const isPremium = false; // TODO: Add isPremium property to UserProfile
      
      if (!isPremium) {
        _showPremiumRequiredDialog();
        return;
      }
    }

    // Check if user has eligible recipients (debaters, moderators)
    final arenaState = ref.read(arenaProvider(widget.roomId));
    final eligibleParticipants = arenaState.participants.values.where((p) => 
      p.role == ArenaRole.affirmative || 
      p.role == ArenaRole.negative || 
      p.role == ArenaRole.moderator ||
      p.role == ArenaRole.judge1 ||
      p.role == ArenaRole.judge2 ||
      p.role == ArenaRole.judge3
    ).toList();

    if (eligibleParticipants.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No debaters, moderators, or judges to send gifts to'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildGiftModal(eligibleParticipants),
      );
    }
  }

  void _showPremiumRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Text('Premium Feature'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gift sending is a premium feature. Upgrade to Arena Pro to send gifts to debaters and show your appreciation!',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.check, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('Send unlimited gifts'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('Support your favorite debaters'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('Exclusive premium gift collection'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToPremiumScreen();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  void _navigateToPremiumScreen() {
    Navigator.of(context).pushNamed('/premium');
  }

  Widget _buildGiftModal(List<ArenaParticipant> eligibleParticipants) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard, color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Send Gift',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$_currentUserCoinBalance',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Recipients
          _buildRecipientSelector(eligibleParticipants),
          
          // Gift categories
          Expanded(
            child: _buildGiftCategories(),
          ),
          
          // Send button
          _buildSendGiftButton(),
        ],
      ),
    );
  }

  Widget _buildRecipientSelector(List<ArenaParticipant> eligibleParticipants) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send to:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: eligibleParticipants.length,
              itemBuilder: (context, index) {
                final participant = eligibleParticipants[index];
                final roleColor = _getRoleColor(participant.role);
                
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          border: Border.all(color: roleColor),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(participant.name),
                            style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: Text(
                          participant.name,
                          style: const TextStyle(fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftCategories() {
    // Simplified gift categories for arena
    final categories = [
      {'name': 'Recognition', 'icon': Icons.star, 'gifts': _availableGifts.where((g) => g.category == GiftCategory.intellectual).toList()},
      {'name': 'Support', 'icon': Icons.favorite, 'gifts': _availableGifts.where((g) => g.category == GiftCategory.recognition).toList()},
    ];

    return DefaultTabController(
      length: categories.length,
      child: Column(
        children: [
          TabBar(
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.amber,
            tabs: categories.map((category) => Tab(
              icon: Icon(category['icon'] as IconData),
              text: category['name'] as String,
            )).toList(),
          ),
          Expanded(
            child: TabBarView(
              children: categories.map((category) {
                final gifts = category['gifts'] as List<Gift>;
                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: gifts.length,
                  itemBuilder: (context, index) {
                    final gift = gifts[index];
                    return _buildGiftCard(gift);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftCard(Gift gift) {
    final canAfford = _currentUserCoinBalance >= gift.cost;
    final isSelected = _selectedGift?.id == gift.id;

    return GestureDetector(
      onTap: canAfford ? () => _selectGift(gift) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
            ? Colors.amber.withValues(alpha: 0.1)
            : (canAfford ? Colors.white : Colors.grey.shade100),
          border: Border.all(
            color: isSelected 
              ? Colors.amber 
              : (canAfford ? Colors.grey.shade300 : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              gift.emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              gift.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: canAfford ? Colors.black87 : Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.monetization_on,
                  size: 14,
                  color: canAfford ? Colors.amber : Colors.grey,
                ),
                const SizedBox(width: 2),
                Text(
                  '${gift.cost}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: canAfford ? Colors.amber : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendGiftButton() {
    final hasSelectedGift = _selectedGift != null;
    final canAfford = hasSelectedGift && _currentUserCoinBalance >= _selectedGift!.cost;

    return Container(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: hasSelectedGift && canAfford ? _sendGift : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            hasSelectedGift 
              ? 'Send ${_selectedGift!.name} (${_selectedGift!.cost} coins)'
              : 'Select a gift',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _selectGift(Gift gift) {
    setState(() {
      _selectedGift = gift;
    });
  }

  Future<void> _sendGift() async {
    if (_selectedGift == null) return;

    try {
      final currentUser = await _appwriteService.getCurrentUser();
      if (currentUser == null) return;

      // For now, send to the first eligible participant (in real implementation, let user select)
      final arenaState = ref.read(arenaProvider(widget.roomId));
      final eligibleParticipants = arenaState.participants.values.where((p) => 
        p.role == ArenaRole.affirmative || 
        p.role == ArenaRole.negative || 
        p.role == ArenaRole.moderator ||
        p.role == ArenaRole.judge1 ||
        p.role == ArenaRole.judge2 ||
        p.role == ArenaRole.judge3
      ).toList();

      if (eligibleParticipants.isNotEmpty) {
        await _giftService.sendGift(
          giftId: _selectedGift!.id,
          senderId: currentUser.$id,
          recipientId: eligibleParticipants.first.userId,
          roomId: widget.roomId,
          cost: _selectedGift!.cost,
        );

        // Update local balance
        await _loadUserData();

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sent ${_selectedGift!.name} to ${eligibleParticipants.first.name}!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send gift: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getRoleColor(ArenaRole role) {
    switch (role) {
      case ArenaRole.affirmative:
        return Colors.blue;
      case ArenaRole.negative:
        return Colors.red;
      case ArenaRole.moderator:
        return Colors.purple;
      case ArenaRole.judge1:
      case ArenaRole.judge2:
      case ArenaRole.judge3:
        return Colors.orange;
      case ArenaRole.audience:
        return Colors.grey;
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    
    return name[0].toUpperCase();
  }

  void _showModeratorControls(BuildContext context, WidgetRef ref, ArenaState state) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Moderator Controls',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.play_arrow, color: Colors.green),
              title: const Text('Start Next Phase'),
              onTap: () {
                Navigator.pop(context);
                ref.read(arenaProvider(widget.roomId).notifier).nextPhase();
              },
            ),
            ListTile(
              leading: const Icon(Icons.pause, color: Colors.orange),
              title: const Text('Pause Timer'),
              onTap: () {
                Navigator.pop(context);
                ref.read(arenaProvider(widget.roomId).notifier).pauseTimer();
              },
            ),
            ListTile(
              leading: const Icon(Icons.stop, color: Colors.red),
              title: const Text('End Debate'),
              onTap: () {
                Navigator.pop(context);
                _confirmEndDebate(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLeaveArena(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Arena'),
        content: const Text('Are you sure you want to leave this debate arena?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (shouldLeave == true && mounted) {
      await ref.read(arenaProvider(widget.roomId).notifier).leaveArena();
      if (mounted) {
        navigator.pop();
      }
    }
  }

  Future<void> _confirmEndDebate(BuildContext context, WidgetRef ref) async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Debate'),
        content: const Text('Are you sure you want to end this debate? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Debate'),
          ),
        ],
      ),
    );

    if (shouldEnd == true) {
      ref.read(arenaProvider(widget.roomId).notifier).endDebate();
    }
  }

  String _getPhaseDisplayName(DebatePhase phase) {
    return phase.displayName;
  }

  String _getPhaseDescription(DebatePhase phase) {
    return phase.description;
  }
}

// Provider for current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).currentUser?.$id;
});