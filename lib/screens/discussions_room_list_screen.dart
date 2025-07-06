import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../widgets/discussion_room_card.dart';
import 'create_discussion_room_screen.dart';
import 'debates_discussions_screen.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

class DiscussionsRoomListScreen extends StatefulWidget {
  const DiscussionsRoomListScreen({super.key});

  @override
  State<DiscussionsRoomListScreen> createState() => _DiscussionsRoomListScreenState();
}

class _DiscussionsRoomListScreenState extends State<DiscussionsRoomListScreen> {
  // Purple theme colors
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);
  static const Color lightPurple = Color(0xFFF3F4F6);

  final AppwriteService _appwrite = AppwriteService();
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;
  RealtimeSubscription? _roomsSubscription;

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _setupRealTimeUpdates();
  }

  @override
  void dispose() {
    _roomsSubscription?.close();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    try {
      AppLogger().debug('Loading debate discussion rooms...');
      final rooms = await _appwrite.getDebateDiscussionRooms();
      
      // Debug room IDs
      for (var room in rooms) {
        AppLogger().debug('Room loaded: ${room['name']} with ID: ${room['id']}');
      }
      
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _isLoading = false;
        });
        AppLogger().debug('Loaded ${rooms.length} debate discussion rooms');
      }
    } catch (e) {
      AppLogger().error('Error loading rooms: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading rooms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _setupRealTimeUpdates() {
    try {
      _roomsSubscription = _appwrite.realtimeInstance.subscribe([
        'databases.arena_db.collections.debate_discussion_rooms.documents'
      ]);

      _roomsSubscription?.stream.listen(
        (response) {
          AppLogger().debug('Real-time room update: ${response.events}');
          
          if (response.events.contains('databases.arena_db.collections.debate_discussion_rooms.documents.*.create') ||
              response.events.contains('databases.arena_db.collections.debate_discussion_rooms.documents.*.update') ||
              response.events.contains('databases.arena_db.collections.debate_discussion_rooms.documents.*.delete')) {
            // Reload rooms when there are changes
            _loadRooms();
          }
        },
        onError: (error) {
          AppLogger().error('Real-time subscription error: $error');
        },
      );
    } catch (e) {
      AppLogger().error('Error setting up real-time updates: $e');
    }
  }

  void _navigateToCreateRoom() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => const CreateDiscussionRoomScreen(),
      ),
    );
    
    if (result != null) {
      await _createRoomInDatabase(result);
    }
  }

  Future<void> _createRoomInDatabase(Map<String, dynamic> roomData) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚀 Creating room...'),
            backgroundColor: primaryPurple,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Get current user
      final currentUser = await _appwrite.getCurrentUser();
      if (currentUser == null) {
        throw Exception('Not authenticated');
      }

      // Create room in database
      final roomId = await _appwrite.createDebateDiscussionRoom(
        name: roomData['name'] ?? 'Untitled Room',
        description: roomData['description'] ?? '',
        category: roomData['category'] ?? 'General',
        debateStyle: roomData['debateStyle'] ?? 'Discussion',
        createdBy: currentUser.$id,
        isPrivate: roomData['isPrivate'] ?? false,
        isScheduled: roomData['isScheduled'] ?? false,
        scheduledDate: roomData['isScheduled'] == true ? roomData['scheduledDate'] : null,
      );

      AppLogger().debug('Created room with ID: $roomId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Room created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // If it's a live room (not scheduled), navigate to it
        if (!(roomData['isScheduled'] ?? false)) {
          // Create properly structured room data for joining
          final joinRoomData = {
            'id': roomId,
            'name': roomData['name'] ?? 'Untitled Room',
            'moderator': currentUser.name,
            'description': roomData['description'] ?? '',
            'category': roomData['category'] ?? 'General',
            'debateStyle': roomData['debateStyle'] ?? 'Discussion',
          };
          
          // Small delay to show success message and ensure room is created
          Future.delayed(const Duration(milliseconds: 1500), () {
            _joinRoom(joinRoomData);
          });
        }
      }

      // Real-time will automatically refresh the list
    } catch (e) {
      AppLogger().error('Error creating room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error creating room: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _joinRoom(Map<String, dynamic> roomData) {
    // Debug room data
    AppLogger().debug('Joining room with data: ${roomData.toString()}');
    AppLogger().debug('Room ID: ${roomData['id']}');
    AppLogger().debug('Room Name: ${roomData['name']}');
    
    // Show joining message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚀 Joining "${roomData['name']}"...'),
        backgroundColor: primaryPurple,
        duration: const Duration(seconds: 1),
      ),
    );
    
    // Navigate to the actual debates & discussions screen with room data
    Future.delayed(const Duration(milliseconds: 800), () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DebatesDiscussionsScreen(
            roomId: roomData['id'] ?? '',
            roomName: roomData['name'] ?? 'Debate Room',
            moderatorName: roomData['moderator'] ?? 'Unknown',
          ),
        ),
      );
    });
  }
  
  void _showRoomDetailsModal(Map<String, dynamic> roomData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          roomData['name'],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryPurple,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Style: ${roomData['debateStyle']}'),
            Text('Category: ${roomData['category']}'),
            Text('Moderator: ${roomData['moderator']}'),
            if (roomData['description']?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(roomData['description']),
            ],
            const SizedBox(height: 16),
            const Text(
              '🚧 Room functionality coming soon!\nThis would connect you to the live debate room.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightPurple,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Debates & Discussions',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header section with stats
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryPurple, deepPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Rooms',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_rooms.where((room) => room['status'] == 'active').length} active discussions',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _navigateToCreateRoom,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create Room'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Room list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: primaryPurple),
                        SizedBox(height: 16),
                        Text(
                          'Loading rooms...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : _rooms.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No active rooms',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Create the first room to get started!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: primaryPurple,
                        onRefresh: _loadRooms,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: _rooms.length,
                          itemBuilder: (context, index) {
                            final room = _rooms[index];
                            final adaptedRoom = _adaptRoomData(room);
                            return DiscussionRoomCard(
                              roomData: adaptedRoom,
                              onTap: () => _joinRoom(adaptedRoom),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _adaptRoomData(Map<String, dynamic> roomData) {
    // Extract moderator info
    final moderatorProfile = roomData['moderatorProfile'] as Map<String, dynamic>?;
    final moderatorName = moderatorProfile?['name'] ?? 'Unknown Moderator';
    final moderatorAvatar = moderatorProfile?['avatar'];

    return {
      'id': roomData['id'],
      'name': roomData['name'] ?? 'Untitled Room',
      'description': roomData['description'] ?? '',
      'category': roomData['category'] ?? 'General',
      'debateStyle': roomData['debateStyle'] ?? 'Discussion',
      'moderator': moderatorName,
      'moderatorAvatar': moderatorAvatar,
      'participantCount': roomData['participantCount'] ?? 0,
      'isLive': roomData['status'] == 'active',
      'isPrivate': roomData['isPrivate'] ?? false,
      'createdAt': roomData['createdAt'],
    };
  }
}