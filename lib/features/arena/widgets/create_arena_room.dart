import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import '../../../services/appwrite_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../models/moderator_judge.dart';
import '../../../constants/appwrite.dart';
import '../providers/arena_lobby_provider.dart';

class CreateArenaRoom extends ConsumerStatefulWidget {
  final String? currentUserId;
  final VoidCallback? onRoomCreated;

  const CreateArenaRoom({
    super.key,
    this.currentUserId,
    this.onRoomCreated,
  });

  @override
  ConsumerState<CreateArenaRoom> createState() => _CreateArenaRoomState();
}

class _CreateArenaRoomState extends ConsumerState<CreateArenaRoom> {
  final AppwriteService _appwrite = AppwriteService();
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isCreating = false;
  DateTime? _lastCreateAttempt;
  
  // Moderator/Judge selection
  DebateCategory _selectedCategory = DebateCategory.any;
  List<ModeratorProfile> _availableModerators = [];
  List<JudgeProfile> _availableJudges = [];
  bool _loadingModerators = false;
  
  // Colors
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void initState() {
    super.initState();
    if (widget.currentUserId != null) {
      _loadModeratorsAndJudges();
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
          Query.limit(10),
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
          Query.limit(10),
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
    if (widget.currentUserId == null) return;

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
          'fromUserId': widget.currentUserId!,
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

      _showSuccess('Ping sent to $toUsername! They will be notified.', null);
    } catch (e) {
      _showError('Failed to send ping: $e');
    }
  }

  Future<void> _createRoom() async {
    if (widget.currentUserId == null) {
      _showError('Please log in to create an arena');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Enhanced debounce protection
    final now = DateTime.now();
    if (_lastCreateAttempt != null && 
        now.difference(_lastCreateAttempt!).inSeconds < 5) {
      _showError('Please wait ${5 - now.difference(_lastCreateAttempt!).inSeconds} seconds before creating another room');
      return;
    }

    if (_isCreating) {
      AppLogger().warning('🚫 DUPLICATE PREVENTION: Room creation already in progress, ignoring duplicate request');
      return;
    }

    _lastCreateAttempt = now;
    setState(() => _isCreating = true);

    try {
      final topic = _topicController.text.trim();
      final description = _descriptionController.text.trim();

      AppLogger().info('Creating arena room: "$topic"');

      // Check for very recent rooms with same topic by this user
      final recentRooms = await _checkForRecentDuplicates(topic);
      if (recentRooms.isNotEmpty) {
        final existingRoomId = recentRooms.first;
        AppLogger().info('Found recent duplicate room: $existingRoomId');
        _showSuccess('Using your recent room with the same topic', existingRoomId);
        _navigateToRoom(existingRoomId, topic, description);
        return;
      }

      // Create new room with lock-based duplicate prevention
      final roomId = await _appwrite.createSimpleArenaRoom(
        creatorId: widget.currentUserId!,
        topic: topic,
        description: description.isNotEmpty ? description : null,
      );

      AppLogger().info('Successfully created arena room: $roomId');

      _showSuccess('Arena created successfully! You are the moderator.', roomId);
      
      // Clear form
      _topicController.clear();
      _descriptionController.clear();

      // Refresh arena lobby
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

      // Navigate to room
      _navigateToRoom(roomId, topic, description);

      // Notify parent
      widget.onRoomCreated?.call();

      // Reset flag only after everything succeeds
      if (mounted) {
        setState(() => _isCreating = false);
      }

    } catch (e) {
      AppLogger().error('Failed to create arena room: $e');
      
      // Handle specific error types
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

  Future<List<String>> _checkForRecentDuplicates(String topic) async {
    try {
      // Check for rooms created by this user in the last 2 minutes with same topic
      final twoMinutesAgo = DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String();
      
      final recentParticipations = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          'userId=${widget.currentUserId}',
          'role=moderator',
          '\$createdAt>$twoMinutesAgo',
        ],
      );

      final duplicateRoomIds = <String>[];
      
      for (final participation in recentParticipations.documents) {
        final roomId = participation.data['roomId'];
        
        try {
          final room = await _appwrite.databases.getDocument(
            databaseId: 'arena_db',
            collectionId: 'arena_rooms',
            documentId: roomId,
          );
          
          if (room.data['status'] == 'waiting' && 
              room.data['challengeId'] == '' &&
              room.data['topic'].toString().toLowerCase() == topic.toLowerCase()) {
            duplicateRoomIds.add(roomId);
          }
        } catch (e) {
          // Room might have been deleted
          AppLogger().debug('Room $roomId not found during duplicate check: $e');
        }
      }
      
      return duplicateRoomIds;
    } catch (e) {
      AppLogger().warning('Error checking for recent duplicates: $e');
      return [];
    }
  }

  void _navigateToRoom(String roomId, String topic, String? description) {
    // This will be handled by the parent widget
    Navigator.pop(context, {
      'roomId': roomId,
      'topic': topic,
      'description': description,
    });
  }

  void _showSuccess(String message, String? roomId) {
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
        duration: const Duration(seconds: 3),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
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
                child: _buildForm(),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [accentPurple, deepPurple],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.only(
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
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topic Input
            const Text(
              'Debate Topic',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _topicController,
              maxLines: 2,
              enabled: !_isCreating,
              decoration: InputDecoration(
                hintText: 'Enter the debate topic (e.g., "Should AI replace human teachers?")',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accentPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: const Icon(Icons.topic, color: accentPurple),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a debate topic';
                }
                if (value.trim().length < 10) {
                  return 'Topic should be at least 10 characters';
                }
                if (value.trim().length > 100) {
                  return 'Topic should be less than 100 characters';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            // Description Input
            const Text(
              'Description (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              enabled: !_isCreating,
              decoration: InputDecoration(
                hintText: 'Add more context, rules, or background information...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accentPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: const Icon(Icons.description, color: accentPurple),
              ),
              validator: (value) {
                if (value != null && value.trim().length > 300) {
                  return 'Description should be less than 300 characters';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            // Ping Section
            _buildPingSection(),
            
            const SizedBox(height: 20),
            
            // Info Panel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentPurple.withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: accentPurple, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'How Your Arena Works:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: deepPurple,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• You will be the moderator with timer controls\n'
                    '• Others can join as audience members\n'
                    '• Assign roles to participants (debaters, judges)\n'
                    '• Control debate phases and timing\n'
                    '• All participants see real-time updates',
                    style: TextStyle(
                      fontSize: 12,
                      color: deepPurple,
                      height: 1.4,
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _isCreating ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
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
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: (_isCreating || (_lastCreateAttempt != null && DateTime.now().difference(_lastCreateAttempt!).inSeconds < 5)) ? null : _createRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCreating ? Colors.grey : accentPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isCreating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Creating...'),
                      ],
                    )
                  : const Text(
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

  Widget _buildPingSection() {
    if (_availableModerators.isEmpty && _availableJudges.isEmpty && !_loadingModerators) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active, color: accentPurple, size: 18),
              SizedBox(width: 8),
              Text(
                'Ping Moderators & Judges',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Request experienced moderators and judges for your debate',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          
          // Category selector
          _buildCategorySelector(),
          
          const SizedBox(height: 12),
          
          // Moderators
          if (_availableModerators.isNotEmpty) ...[
            const Text(
              'Moderators',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _availableModerators.length,
                itemBuilder: (context, index) {
                  final moderator = _availableModerators[index];
                  return _buildModeratorCard(moderator);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          // Judges
          if (_availableJudges.isNotEmpty) ...[
            const Text(
              'Judges',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: deepPurple,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 60,
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
          
          if (_loadingModerators)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: accentPurple, strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return SizedBox(
      height: 30,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: DebateCategory.values.take(5).length, // Show first 5 categories
        itemBuilder: (context, index) {
          final category = DebateCategory.values[index];
          final isSelected = category == _selectedCategory;
          
          return Padding(
            padding: const EdgeInsets.only(right: 6),
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
                fontSize: 10,
              ),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected ? accentPurple : Colors.grey[300]!,
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeratorCard(ModeratorProfile moderator) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: const Color(0xFF4CAF50),
                backgroundImage: moderator.avatar != null 
                    ? NetworkImage(moderator.avatar!) 
                    : null,
                child: moderator.avatar == null
                    ? Text(
                        moderator.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moderator.displayName,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 8),
                        const SizedBox(width: 2),
                        Text(
                          moderator.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 20,
            child: ElevatedButton(
              onPressed: () => _sendPingRequest('moderator', moderator.userId, moderator.username),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: const TextStyle(fontSize: 9),
                minimumSize: const Size(0, 20),
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
      width: 140,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: const Color(0xFF2196F3),
                backgroundImage: judge.avatar != null 
                    ? NetworkImage(judge.avatar!) 
                    : null,
                child: judge.avatar == null
                    ? Text(
                        judge.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      judge.displayName,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 8),
                        const SizedBox(width: 2),
                        Text(
                          judge.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 20,
            child: ElevatedButton(
              onPressed: () => _sendPingRequest('judge', judge.userId, judge.username),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: const TextStyle(fontSize: 9),
                minimumSize: const Size(0, 20),
              ),
              child: const Text('Ping'),
            ),
          ),
        ],
      ),
    );
  }
}