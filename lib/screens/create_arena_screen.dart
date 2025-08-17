import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../features/arena/providers/arena_lobby_provider.dart';
import '../core/logging/app_logger.dart';
import '../widgets/challenge_bell.dart';
import '../models/moderator_judge.dart';
import '../constants/appwrite.dart';
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
  
  // Moderator/Judge selection
  DebateCategory _selectedCategory = DebateCategory.any;
  List<ModeratorProfile> _availableModerators = [];
  List<JudgeProfile> _availableJudges = [];
  bool _loadingModerators = false;
  
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
      _loadModeratorsAndJudges();
    }
  }

  Future<void> _loadModeratorsAndJudges() async {
    if (_loadingModerators) return;
    
    setState(() => _loadingModerators = true);
    
    try {
      // Load moderators
      final moderatorResponse = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.moderatorsCollection,
        queries: [
          Query.equal('isAvailable', true),
          Query.orderDesc('rating'),
          Query.limit(20),
        ],
      );

      final moderators = moderatorResponse.documents
          .map((doc) => ModeratorProfile.fromJson(doc.data))
          .toList();

      // Load judges
      final judgeResponse = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.judgesCollection,
        queries: [
          Query.equal('isAvailable', true),
          Query.orderDesc('rating'),
          Query.limit(20),
        ],
      );

      final judges = judgeResponse.documents
          .map((doc) => JudgeProfile.fromJson(doc.data))
          .toList();

      // Filter by category if not "Any"
      final filteredModerators = _selectedCategory == DebateCategory.any
          ? moderators
          : moderators.where((mod) => mod.categories.contains(_selectedCategory)).toList();

      final filteredJudges = _selectedCategory == DebateCategory.any
          ? judges
          : judges.where((judge) => judge.categories.contains(_selectedCategory)).toList();

      setState(() {
        _availableModerators = filteredModerators;
        _availableJudges = filteredJudges;
        _loadingModerators = false;
      });
    } catch (e) {
      debugPrint('Error loading moderators/judges: $e');
      setState(() => _loadingModerators = false);
    }
  }

  Future<void> _sendPingRequest(String roleType, String toUserId, String toUsername) async {
    if (_currentUserId == null) return;

    try {
      final topic = _topicController.text.trim();
      final description = _descriptionController.text.trim();
      
      if (topic.isEmpty) {
        _showError('Please enter a debate topic before pinging');
        return;
      }

      final user = await _appwrite.getCurrentUser();
      if (user == null) return;

      await _appwrite.databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.pingRequestsCollection,
        documentId: ID.unique(),
        data: {
          'fromUserId': _currentUserId!,
          'fromUsername': user.name,
          'toUserId': toUserId,
          'toUsername': toUsername,
          'roleType': roleType,
          'debateTitle': topic,
          'debateDescription': description.isNotEmpty ? description : 'No description provided',
          'category': _selectedCategory.displayName,
          'scheduledTime': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
          'status': 'pending',
          'message': 'Would you like to ${roleType == 'moderator' ? 'moderate' : 'judge'} this debate?',
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      _showSuccess('Ping sent to $toUsername! They will be notified.');
    } catch (e) {
      _showError('Failed to send ping: $e');
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
      await Future.delayed(const Duration(seconds: 2));
      
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
        duration: const Duration(seconds: 2),
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
        duration: const Duration(seconds: 4),
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
          const ChallengeBell(iconColor: Color(0xFF6B46C1)),
          const SizedBox(width: 8),
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
            const SizedBox(height: 20),
            _buildModeratorJudgeSection(),
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
        gradient: const LinearGradient(
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
      child: const Column(
        children: [
          Icon(Icons.stadium, color: Colors.white, size: 48),
          SizedBox(height: 12),
          Text(
            'Create Your Arena',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
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
                  borderSide: const BorderSide(color: accentPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: const Icon(Icons.topic, color: accentPurple),
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
                  borderSide: const BorderSide(color: accentPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 60),
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
            ? const Row(
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
                  SizedBox(width: 12),
                  Text(
                    'Creating Arena...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Create Arena',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildModeratorJudgeSection() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active, color: accentPurple, size: 24),
              SizedBox(width: 8),
              Text(
                'Request Moderator & Judge (Optional)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ping experienced moderators and judges to help with your debate',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          
          // Category Selection
          _buildCategorySelector(),
          const SizedBox(height: 20),
          
          // Moderator Selection
          _buildModeratorSelector(),
          const SizedBox(height: 16),
          
          // Judge Selection  
          _buildJudgeSelector(),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Debate Category',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: deepPurple,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: DebateCategory.values.length,
            itemBuilder: (context, index) {
              final category = DebateCategory.values[index];
              final isSelected = category == _selectedCategory;
              
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(category.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = category;
                    });
                    _loadModeratorsAndJudges();
                  },
                  selectedColor: accentPurple.withValues(alpha: 0.2),
                  checkmarkColor: accentPurple,
                  labelStyle: TextStyle(
                    color: isSelected ? accentPurple : Colors.grey[700],
                    fontSize: 12,
                  ),
                  backgroundColor: Colors.grey[100],
                  side: BorderSide(
                    color: isSelected ? accentPurple : Colors.grey[300]!,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModeratorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.gavel, color: Color(0xFF4CAF50), size: 20),
            SizedBox(width: 8),
            Text(
              'Request Moderator',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: deepPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingModerators)
          const Center(child: CircularProgressIndicator(color: accentPurple))
        else if (_availableModerators.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No moderators available for ${_selectedCategory.displayName}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          )
        else
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableModerators.length,
              itemBuilder: (context, index) {
                final moderator = _availableModerators[index];
                return _buildModeratorCard(moderator);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildJudgeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.balance, color: Color(0xFF2196F3), size: 20),
            SizedBox(width: 8),
            Text(
              'Request Judge',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: deepPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingModerators)
          const Center(child: CircularProgressIndicator(color: accentPurple))
        else if (_availableJudges.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No judges available for ${_selectedCategory.displayName}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          )
        else
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableJudges.length,
              itemBuilder: (context, index) {
                final judge = _availableJudges[index];
                return _buildJudgeCard(judge);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildModeratorCard(ModeratorProfile moderator) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFF4CAF50),
                backgroundImage: moderator.avatar != null 
                    ? NetworkImage(moderator.avatar!) 
                    : null,
                child: moderator.avatar == null
                    ? Text(
                        moderator.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moderator.displayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          moderator.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 24,
            child: ElevatedButton(
              onPressed: () => _sendPingRequest('moderator', moderator.userId, moderator.username),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(fontSize: 10),
              ),
              child: const Text('Ping'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJudgeCard(JudgeProfile judge) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFF2196F3),
                backgroundImage: judge.avatar != null 
                    ? NetworkImage(judge.avatar!) 
                    : null,
                child: judge.avatar == null
                    ? Text(
                        judge.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      judge.displayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          judge.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 24,
            child: ElevatedButton(
              onPressed: () => _sendPingRequest('judge', judge.userId, judge.username),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(fontSize: 10),
              ),
              child: const Text('Ping'),
            ),
          ),
        ],
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
            '• Ping system notifies selected moderators/judges\n'
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
              const Icon(Icons.live_tv, color: scarletRed, size: 24),
              const SizedBox(width: 12),
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
                decoration: const BoxDecoration(
                  color: scarletRed,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
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
    const maxParticipants = 1000; // Allow unlimited participants

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
                    style: const TextStyle(
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