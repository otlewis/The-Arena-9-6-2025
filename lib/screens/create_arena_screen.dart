import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/appwrite_service.dart';
import '../features/arena/providers/arena_lobby_provider.dart';
import '../core/logging/app_logger.dart';
import 'arena_screen.dart';

class CreateArenaScreen extends ConsumerStatefulWidget {
  const CreateArenaScreen({super.key});

  @override
  ConsumerState<CreateArenaScreen> createState() => _CreateArenaScreenState();
}

class _CreateArenaScreenState extends ConsumerState<CreateArenaScreen> {
  final AppwriteService _appwrite = AppwriteService();
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _currentUserId;
  bool _isCreating = false;
  DateTime? _lastCreateAttempt;
  
  // Colors
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    // Load existing rooms
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(arenaLobbyProvider.notifier).loadActiveArenas();
    });
  }

  @override
  void dispose() {
    _topicController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _appwrite.getCurrentUser();
    if (user != null) {
      setState(() {
        _currentUserId = user.$id;
      });
    }
  }

  Future<void> _createArenaRoom() async {
    if (_currentUserId == null) {
      _showError('Please log in to create an arena');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Prevent rapid successive calls
    final now = DateTime.now();
    if (_lastCreateAttempt != null && 
        now.difference(_lastCreateAttempt!).inSeconds < 5) {
      _showError('Please wait ${5 - now.difference(_lastCreateAttempt!).inSeconds} seconds before creating another arena');
      return;
    }

    if (_isCreating) {
      AppLogger().warning('🚫 DUPLICATE PREVENTION: Room creation already in progress, blocking duplicate attempt');
      return;
    }

    _lastCreateAttempt = now;
    setState(() => _isCreating = true);

    try {
      final topic = _topicController.text.trim();
      final description = _descriptionController.text.trim();

      AppLogger().info('Creating arena room: "$topic"');

      // Simple room creation with lock-based duplicate prevention
      final roomId = await _appwrite.createSimpleArenaRoom(
        creatorId: _currentUserId!,
        topic: topic,
        description: description.isNotEmpty ? description : null,
      );

      AppLogger().info('Successfully created arena room: $roomId');

      _showSuccess('Arena created successfully! You are the moderator.');
      
      // Clear form
      _topicController.clear();
      _descriptionController.clear();

      // Refresh arena list to show the new room
      ref.read(arenaLobbyProvider.notifier).refreshArenas();

      // Wait for room setup to complete before navigation
      AppLogger().info('Waiting for room setup to stabilize before navigation...');
      await Future.delayed(Duration(seconds: 2));
      
      // Verify room exists and is properly set up before navigating
      final roomData = await _appwrite.getArenaRoom(roomId);
      if (roomData == null) {
        throw Exception('Room was not properly created or was deleted');
      }
      
      AppLogger().info('Room verified, proceeding with navigation to: $roomId');
      
      // Navigate to the arena room
      if (mounted) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ArenaScreen(
              roomId: roomId,
              challengeId: roomId,
              topic: topic,
              description: description.isNotEmpty ? description : null,
            ),
          ),
        );
      }

      // Reset flag only after everything succeeds
      if (mounted) {
        setState(() => _isCreating = false);
      }

    } catch (e) {
      AppLogger().error('Failed to create arena room: $e');
      
      String errorMessage = 'Failed to create arena';
      if (e.toString().contains('Invalid `documentId`')) {
        errorMessage = 'Room name too long. Please use a shorter topic.';
      } else if (e.toString().contains('document_already_exists')) {
        errorMessage = 'A room with this configuration already exists';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection and try again.';
      }
      
      _showError(errorMessage);
      
      // Reset flag on error
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
    // No finally block that resets the flag prematurely!
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _joinArenaAsAudience(String roomId, String challengeId, String topic) async {
    if (_currentUserId == null) {
      _showError('Please log in to join The Arena');
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

      // Navigate to Arena
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArenaScreen(
              roomId: roomId,
              challengeId: challengeId.isNotEmpty ? challengeId : roomId,
              topic: topic,
            ),
          ),
        );
      }
      
    } catch (e) {
      _showError('Error joining arena: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lobbyState = ref.watch(arenaLobbyProvider);
    final activeArenas = lobbyState.rooms;
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
          icon: const Icon(Icons.arrow_back, color: scarletRed),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: deepPurple),
            onPressed: () => ref.read(arenaLobbyProvider.notifier).refreshArenas(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Existing Rooms Section
            if (activeArenas.isNotEmpty) ...[
              _buildActiveArenasList(activeArenas),
              const SizedBox(height: 30),
              const Divider(thickness: 2),
              const SizedBox(height: 20),
            ],
            
            // Create New Room Section
            _buildHeader(),
            const SizedBox(height: 30),
            _buildForm(),
            const SizedBox(height: 30),
            _buildCreateButton(),
            const SizedBox(height: 20),
            _buildInfoPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentPurple, deepPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accentPurple.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.stadium, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Create Your Arena',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set up a new debate room and become the moderator',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topic Input
            const Text(
              'Debate Topic',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _topicController,
              maxLines: 2,
              enabled: !_isCreating,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'What should people debate about?',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: Icon(Icons.topic, color: accentPurple),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a debate topic';
                }
                if (value.trim().length < 10) {
                  return 'Topic should be at least 10 characters';
                }
                if (value.trim().length > 120) {
                  return 'Topic should be less than 120 characters';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Description Input
            const Text(
              'Description (Optional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              enabled: !_isCreating,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Add context, rules, or background information...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.description, color: accentPurple),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value != null && value.trim().length > 500) {
                  return 'Description should be less than 500 characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: accentPurple.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (_isCreating || (_lastCreateAttempt != null && DateTime.now().difference(_lastCreateAttempt!).inSeconds < 5)) ? null : _createArenaRoom,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isCreating ? Colors.grey[400] : accentPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isCreating
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Creating Arena...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Create Arena',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.blue[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'How Your Arena Works',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• You become the moderator with full control\n'
            '• Others can join as audience members\n'
            '• Assign participant roles (debaters, judges)\n'
            '• Control debate phases and timing\n'
            '• Everyone sees real-time updates',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveArenasList(List<ArenaRoom> activeArenas) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.live_tv, color: scarletRed, size: 24),
              const SizedBox(width: 12),
              Text(
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
      ),
    );
  }

  Widget _buildArenaCard(String roomId, String topic, String status, String challengeId, String description, int currentParticipants, bool isManual) {
    const maxParticipants = 8;

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
}