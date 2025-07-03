import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/appwrite_service.dart';
import '../features/arena/providers/arena_lobby_provider.dart';
import 'arena_screen.dart';
import 'dart:async';
import '../core/logging/app_logger.dart';
import '../services/firebase_test_service.dart';

class ArenaLobbyScreen extends ConsumerStatefulWidget {
  const ArenaLobbyScreen({super.key});

  @override
  ConsumerState<ArenaLobbyScreen> createState() => _ArenaLobbyScreenState();
}

class _ArenaLobbyScreenState extends ConsumerState<ArenaLobbyScreen> with WidgetsBindingObserver {
  final AppwriteService _appwrite = AppwriteService();
  String? _currentUserId;
  bool _isCreatingRoom = false;

  // Colors
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentUser();
    // Trigger initial load of arenas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(arenaLobbyProvider.notifier).loadActiveArenas();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh when app becomes active (user returns from arena)
    if (state == AppLifecycleState.resumed) {
      AppLogger().debug('🔄 App resumed - refreshing arena lobby');
      ref.read(arenaLobbyProvider.notifier).loadActiveArenas(isBackgroundRefresh: true);
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await _appwrite.getCurrentUser();
    if (user != null) {
      _currentUserId = user.$id;
    }
  }

  Future<void> _joinArenaAsAudience(String roomId, String challengeId, String topic) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to join The Arena')),
      );
      return;
    }

    try {
      // For manual rooms, use the joinArenaRoom method, for challenge rooms use assignArenaRole
      final isManualRoom = roomId.startsWith('manual_arena_') || roomId.startsWith('arena_');
      
      if (isManualRoom) {
        await _appwrite.joinArenaRoom(
          roomId: roomId,
          userId: _currentUserId!,
        );
      } else {
        // Assign user as audience member for challenge-based rooms
        await _appwrite.assignArenaRole(
          roomId: roomId,
          userId: _currentUserId!,
          role: 'audience',
        );
      }

      // Navigate to Arena and refresh lobby when returning
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArenaScreen(
            roomId: roomId,
            challengeId: challengeId.isNotEmpty ? challengeId : roomId,
            topic: topic,
          ),
        ),
      );
      
      // Refresh the lobby when user returns from arena
      AppLogger().debug('🔄 User returned from arena - refreshing lobby');
      ref.read(arenaLobbyProvider.notifier).loadActiveArenas(isBackgroundRefresh: true);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining arena: $e')),
      );
    }
  }

  Future<void> _createManualArena() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create an arena')),
      );
      return;
    }
    
    if (_isCreatingRoom) {
      AppLogger().warning('🚫 DUPLICATE PREVENTION: Room creation already in progress, blocking request');
      return; // Prevent double-clicks
    }
    
    AppLogger().info('🔒 DUPLICATE PREVENTION: Setting _isCreatingRoom = true');
    setState(() {
      _isCreatingRoom = true;
    });

    // Show simplified dialog to get room details
    final dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CreateArenaDialog(),
    );

    if (dialogResult != null) {
      try {
        final topic = dialogResult['topic'] as String;
        final description = dialogResult['description'] as String?;
        
        // Simple room creation like discussion rooms - no complex duplicate logic
        final roomId = await _appwrite.createSimpleArenaRoom(
          creatorId: _currentUserId!,
          topic: topic,
          description: description,
        );

        // Navigate to the created arena
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArenaScreen(
              roomId: roomId,
              challengeId: roomId,
              topic: topic,
              description: description,
            ),
          ),
        );

        // Refresh the lobby when user returns from created arena
        AppLogger().debug('🔄 User returned from created arena - refreshing lobby');
        ref.read(arenaLobbyProvider.notifier).refreshArenas();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🏛️ Arena created! You are the moderator.'),
            backgroundColor: Color(0xFF8B5CF6),
          ),
        );

        // Reset flag only after everything succeeds
        AppLogger().info('🔓 DUPLICATE PREVENTION: Resetting _isCreatingRoom = false (success)');
        if (mounted) {
          setState(() {
            _isCreatingRoom = false;
          });
        }

      } catch (e) {
        // Reset flag on error
        AppLogger().info('🔓 DUPLICATE PREVENTION: Resetting _isCreatingRoom = false (error)');
        if (mounted) {
          setState(() {
            _isCreatingRoom = false;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating arena: $e')),
        );
      }
      // No finally block that resets the flag prematurely!
    } else {
      // Dialog was cancelled - reset flag
      AppLogger().info('🔓 DUPLICATE PREVENTION: Resetting _isCreatingRoom = false (cancelled)');
      if (mounted) {
        setState(() {
          _isCreatingRoom = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lobbyState = ref.watch(arenaLobbyProvider);
    final activeArenas = lobbyState.rooms;
    final isLoading = lobbyState.isLoading;
    final isRefreshing = lobbyState.isRefreshing;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'The Arena',
          style: TextStyle(
            color: deepPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: scarletRed),
        leading: IconButton(
          icon: const Icon(Icons.home_outlined, color: scarletRed),
          onPressed: () {
            // Navigate back to home screen (preserve bottom nav)
            Navigator.pop(context);
          },
          tooltip: 'Back to Home',
        ),
        actions: [
          if (isRefreshing)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(deepPurple),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: deepPurple),
              onPressed: () => ref.read(arenaLobbyProvider.notifier).refreshArenas(),
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(arenaLobbyProvider.notifier).refreshArenas(),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildArenaHeader(),
                  const SizedBox(height: 24),
                  if (activeArenas.isNotEmpty) ...[
                    _buildActiveArenasList(activeArenas),
                    const SizedBox(height: 24),
                  ],
                  _buildDemoSection(),
                  const SizedBox(height: 24),
                  _buildHowItWorksSection(),
                ],
              ),
      ),
    );
  }

  Widget _buildArenaHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentPurple, deepPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stadium, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Welcome to The Arena',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Join live debates as an audience member or create your own arena!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveArenasList(List<ArenaRoom> activeArenas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.live_tv, color: scarletRed, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Live Debates',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scarletRed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${activeArenas.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...activeArenas.map((arena) => _buildArenaCard(
          arena.id, 
          arena.topic, 
          arena.status, 
          arena.challengeId ?? '', 
          arena.description ?? '', 
          arena.currentParticipants, 
          arena.isManual
        )),
      ],
    );
  }

  Widget _buildArenaCard(String roomId, String topic, String status, String challengeId, String description, int currentParticipants, bool isManual) {
    final maxParticipants = 8; // Default since field doesn't exist in schema

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scarletRed.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: () => _joinArenaAsAudience(roomId, challengeId, topic),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: status == 'active' ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status == 'active' ? 'LIVE' : 'WAITING',
                    style: TextStyle(
                      color: status == 'active' ? Colors.green : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isManual ? accentPurple : deepPurple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isManual ? 'OPEN' : 'CHALLENGE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '$currentParticipants/$maxParticipants',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                topic,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: deepPurple,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (description.isNotEmpty) ...[ 
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isManual ? Icons.person_add : Icons.visibility, 
                    size: 16, 
                    color: accentPurple
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isManual ? 'Tap to join room' : 'Tap to watch debate',
                    style: TextStyle(
                      color: accentPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDemoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentPurple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_outline, color: accentPurple, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Quick Start',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isCreatingRoom ? null : _createManualArena,
            icon: _isCreatingRoom 
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.add_circle_outline, size: 20),
            label: Text(_isCreatingRoom ? 'Creating...' : 'Create New Arena'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentPurple,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How The Arena Works',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: deepPurple,
            ),
          ),
          const SizedBox(height: 16),
          _buildHowItWorksStep(
            '1',
            'Create or Join',
            'Start your own debate room or join an existing one',
            Icons.stadium,
          ),
          _buildHowItWorksStep(
            '2',
            'Assign Roles',
            'Become moderator, debater, judge, or audience member',
            Icons.groups,
          ),
          _buildHowItWorksStep(
            '3',
            'Real-time Sync',
            'All participants see the same timer and debate phases',
            Icons.sync,
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep(String number, String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accentPurple,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Icon(icon, color: accentPurple, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: deepPurple,
                    fontSize: 16,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CreateArenaDialog extends StatefulWidget {
  const CreateArenaDialog({super.key});

  @override
  State<CreateArenaDialog> createState() => _CreateArenaDialogState();
}

class _CreateArenaDialogState extends State<CreateArenaDialog> {
  final _topicController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _topicController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Arena'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _topicController,
            decoration: const InputDecoration(
              labelText: 'Debate Topic',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final topic = _topicController.text.trim();
            final description = _descriptionController.text.trim();
            
            if (topic.isNotEmpty) {
              Navigator.pop(context, {
                'topic': topic,
                'description': description.isNotEmpty ? description : null,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}