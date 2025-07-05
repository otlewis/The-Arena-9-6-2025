import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/appwrite_service.dart';
import '../../../core/logging/app_logger.dart';
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
  
  // Colors
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  @override
  void dispose() {
    _topicController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

      _lastCreatedRoomId = roomId;
      AppLogger().info('Successfully created arena room: $roomId');

      _showSuccess('Arena created successfully! You are the moderator.', roomId);
      
      // Clear form
      _topicController.clear();
      _descriptionController.clear();

      // Refresh arena lobby
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
        duration: Duration(seconds: 3),
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
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
                  borderSide: BorderSide(color: accentPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: Icon(Icons.topic, color: accentPurple),
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
                  borderSide: BorderSide(color: accentPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: Icon(Icons.description, color: accentPurple),
              ),
              validator: (value) {
                if (value != null && value.trim().length > 300) {
                  return 'Description should be less than 300 characters';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            // Info Panel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentPurple.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: accentPurple, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'How Your Arena Works:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: deepPurple,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
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
                  ? Row(
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
                        const SizedBox(width: 8),
                        const Text('Creating...'),
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
}