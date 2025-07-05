import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/appwrite_service.dart';
import '../features/arena/providers/arena_lobby_provider.dart';
import 'arena_screen.dart';
import 'dart:async';
import '../core/logging/app_logger.dart';

class ArenaLobbyScreen extends ConsumerStatefulWidget {
  const ArenaLobbyScreen({super.key});

  @override
  ConsumerState<ArenaLobbyScreen> createState() => _ArenaLobbyScreenState();
}

class _ArenaLobbyScreenState extends ConsumerState<ArenaLobbyScreen> with WidgetsBindingObserver {
  final AppwriteService _appwrite = AppwriteService();
  String? _currentUserId;

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
      final isManualRoom = roomId.startsWith('manual_arena_');
      
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
      ref.read(arenaLobbyProvider.notifier).refreshArenas();
      
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

    // Show dialog to get room details
    final dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CreateArenaDialog(),
    );

    if (dialogResult != null) {
      try {
        final topic = dialogResult['topic'] as String;
        final description = dialogResult['description'] as String?;
        final affirmativeDebater = dialogResult['affirmativeDebater'] as Map<String, dynamic>?;
        final negativeDebater = dialogResult['negativeDebater'] as Map<String, dynamic>?;
        final judges = dialogResult['judges'] as List<dynamic>?;
        
        final roomId = await _appwrite.createManualArenaRoom(
          creatorId: _currentUserId!,
          topic: topic,
          description: description,
        );

        // Assign roles if selected
        if (affirmativeDebater != null) {
          await _appwrite.assignArenaRole(
            roomId: roomId,
            userId: affirmativeDebater['id'],
            role: 'affirmative',
          );
        }
        
        if (negativeDebater != null) {
          await _appwrite.assignArenaRole(
            roomId: roomId,
            userId: negativeDebater['id'],
            role: 'negative',
          );
        }
        
        if (judges != null && judges.isNotEmpty) {
          for (int i = 0; i < judges.length && i < 3; i++) {
            final judge = judges[i] as Map<String, dynamic>;
            await _appwrite.assignArenaRole(
              roomId: roomId,
              userId: judge['id'],
              role: 'judge${i + 1}',
            );
          }
        }

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

        // Show success message with role assignments
        final assignedRoles = <String>[];
        if (affirmativeDebater != null) assignedRoles.add('Affirmative');
        if (negativeDebater != null) assignedRoles.add('Negative');
        if (judges != null && judges.isNotEmpty) assignedRoles.add('${judges.length} Judge${judges.length > 1 ? 's' : ''}');
        
        final roleText = assignedRoles.isNotEmpty 
            ? ' with ${assignedRoles.join(', ')} assigned'
            : '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🏛️ Arena created! You are the moderator$roleText.'),
            backgroundColor: const Color(0xFF8B5CF6),
          ),
        );

        // Refresh the list again to ensure consistency
        ref.read(arenaLobbyProvider.notifier).refreshArenas();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating arena: $e')),
        );
      }
    }
  }

  Future<void> _createDemoArena() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create demo arena')),
      );
      return;
    }

    try {
      // Create a demo arena room
      final roomId = await _appwrite.createArenaRoom(
        challengeId: 'demo_${DateTime.now().millisecondsSinceEpoch}',
        challengerId: _currentUserId!,
        challengedId: 'demo_opponent',
        topic: 'Should AI replace human judges in debates?',
        description: 'Demo Arena - Experience The Arena interface',
      );

      // Assign current user as audience
      await _appwrite.assignArenaRole(
        roomId: roomId,
        userId: _currentUserId!,
        role: 'audience',
      );

      // Navigate to demo arena
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArenaScreen(
            roomId: roomId,
            challengeId: 'demo_challenge',
            topic: 'Should AI replace human judges in debates?',
            description: 'Demo Arena - Experience The Arena interface',
          ),
        ),
      );

      // Refresh the lobby when user returns from demo arena
      AppLogger().debug('🔄 User returned from demo arena - refreshing lobby');
      ref.read(arenaLobbyProvider.notifier).refreshArenas();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎭 Demo Arena created! This is how real debates look.'),
          backgroundColor: Color(0xFF8B5CF6),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating demo: $e')),
      );
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
            'Join live debates as an audience member or challenge someone to debate!',
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
        ...activeArenas.map((arena) => _buildArenaCard(arena.id, arena.topic, arena.status, arena.challengeId ?? '', arena.description ?? '', arena.currentParticipants, arena.isManual)),
      ],
    );
  }

  Widget _buildArenaCard(String roomId, String topic, String status, String challengeId, String description, int currentParticipants, bool isManual) {
    const maxParticipants = 8; // Default since field doesn't exist in schema

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.add_circle, color: accentPurple, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Create or Try Arena',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Create New Arena Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scarletRed.withValues(alpha: 0.2)),
          ),
          child: InkWell(
            onTap: _createManualArena,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scarletRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add, color: scarletRed, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create New Arena',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: deepPurple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Start your own debate room and invite participants',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: scarletRed, size: 16),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Demo Arena Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: accentPurple.withValues(alpha: 0.2)),
          ),
          child: InkWell(
            onTap: _createDemoArena,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accentPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.smart_toy, color: accentPurple, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Demo Arena',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: deepPurple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Experience The Arena interface with sample debate',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: accentPurple, size: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.help_outline, color: deepPurple, size: 20),
            const SizedBox(width: 8),
            const Text(
              'How to Start an Instant Debate',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStepItem(
                  '1',
                  'Visit User Profiles',
                  'Go to any user\'s profile page',
                  Icons.person,
                ),
                _buildStepItem(
                  '2',
                  'Send Challenge',
                  'Challenge them to a debate on any topic',
                  Icons.flash_on,
                ),
                _buildStepItem(
                  '3',
                  'Arena Opens',
                  'When accepted, you\'ll both enter The Arena',
                  Icons.stadium,
                ),
                _buildStepItem(
                  '4',
                  'Others Join',
                  'People can watch as audience members',
                  Icons.people,
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem(String number, String title, String description, IconData icon, {bool isLast = false}) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scarletRed,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, color: deepPurple, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: deepPurple,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.only(left: 16),
            width: 2,
            height: 16,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// Create Arena Dialog Widget
class CreateArenaDialog extends StatefulWidget {
  const CreateArenaDialog({super.key});

  @override
  State<CreateArenaDialog> createState() => _CreateArenaDialogState();
}

class _CreateArenaDialogState extends State<CreateArenaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Colors
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void dispose() {
    _topicController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.85, // Limit height to 85% of screen
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildForm(),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentPurple, deepPurple],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.add_circle, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Create New Arena',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Debate Topic',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _topicController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Enter the debate topic (e.g., "Should AI replace human teachers?")',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a debate topic';
                }
                if (value.trim().length < 10) {
                  return 'Topic should be at least 10 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Description (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add more context or rules for the debate...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: accentPurple, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'How it works:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: deepPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• You will be the moderator\n'
                    '• Others can join as audience\n'
                    '• Assign roles once people join\n'
                    '• Control the debate flow and timing',
                    style: TextStyle(
                      fontSize: 12,
                      color: deepPurple,
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

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _createArena,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Create Arena',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _createArena() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.pop(context, <String, dynamic>{
        'topic': _topicController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
      });
    }
  }
}