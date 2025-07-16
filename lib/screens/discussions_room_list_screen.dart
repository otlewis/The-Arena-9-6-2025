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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateDiscussionRoomScreen(),
      ),
    );
    
    // Refresh the room list after returning from create screen
    _loadRooms();
  }


  void _joinRoom(Map<String, dynamic> roomData) async {
    // Debug room data
    AppLogger().debug('🏁 Starting room join process');
    AppLogger().debug('🏁 Room data: ${roomData.toString()}');
    AppLogger().debug('🏁 Room ID: ${roomData['id']}');
    AppLogger().debug('🏁 Room Name: ${roomData['name']}');
    
    // Get current user
    final currentUser = await _appwrite.getCurrentUser();
    if (currentUser == null) {
      _showSnackBar('Please log in to join rooms');
      return;
    }
    
    // Check if room is scheduled and its current status
    final isScheduled = roomData['isScheduled'] as bool? ?? false;
    final isLive = roomData['isLive'] as bool? ?? false;
    final scheduledDate = roomData['scheduledDate'];
    final moderatorId = roomData['moderatorId'] as String? ?? roomData['createdBy'] as String?;
    final isCurrentUserModerator = currentUser.$id == moderatorId;
    
    AppLogger().debug('🏁 Is room scheduled: $isScheduled');
    AppLogger().debug('🏁 Is room live: $isLive');
    AppLogger().debug('🏁 Scheduled date: $scheduledDate');
    AppLogger().debug('🏁 Current user ID: ${currentUser.$id}');
    AppLogger().debug('🏁 Moderator ID: $moderatorId');
    AppLogger().debug('🏁 Created by: ${roomData['createdBy']}');
    AppLogger().debug('🏁 Is current user moderator: $isCurrentUserModerator');
    
    // Handle scheduled room logic - show info but allow entry
    if (isScheduled && !isLive) {
      AppLogger().debug('🏁 Room is scheduled, showing schedule info and allowing entry');
      _showScheduledRoomInfoDialog(roomData);
      return;
    } else if (isScheduled && isLive) {
      AppLogger().debug('🏁 Room was scheduled but is now live - allowing all users to join');
    }
    
    // Check if room is private
    final isPrivate = roomData['isPrivate'] as bool? ?? false;
    AppLogger().debug('🏁 Is room private: $isPrivate');
    
    if (isPrivate) {
      AppLogger().debug('🏁 Showing password dialog for private room');
      _showPasswordDialog(roomData);
    } else {
      AppLogger().debug('🏁 Room is public, navigating directly');
      _navigateToRoom(roomData);
    }
  }

  void _showPasswordDialog(Map<String, dynamic> roomData) {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Private Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This room requires a password to enter.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _validateAndJoin(roomData, passwordController.text),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _validateAndJoin(roomData, passwordController.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _validateAndJoin(Map<String, dynamic> roomData, String enteredPassword) async {
    if (enteredPassword.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      AppLogger().debug('🔐 Validating password for room: ${roomData['id']}');
      AppLogger().debug('🔐 Entered password: ${enteredPassword.trim()}');
      
      final isValid = await _appwrite.validateDebateDiscussionRoomPassword(
        roomId: roomData['id'] ?? '',
        enteredPassword: enteredPassword.trim(),
      );

      AppLogger().debug('🔐 Password validation result: $isValid');

      if (!mounted) return;

      if (isValid) {
        AppLogger().debug('🔐 Password correct, navigating to room');
        Navigator.of(context).pop(); // Close password dialog
        _navigateToRoom(roomData);
      } else {
        AppLogger().debug('🔐 Password incorrect');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect password. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      AppLogger().error('🔐 Error validating password: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error validating password: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  void _showScheduledRoomInfoDialog(Map<String, dynamic> roomData) {
    final scheduledDate = roomData['scheduledDate'] as String?;
    DateTime? scheduleDateTime;
    
    if (scheduledDate != null) {
      try {
        scheduleDateTime = DateTime.parse(scheduledDate);
      } catch (e) {
        AppLogger().error('Error parsing scheduled date: $e');
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scheduled Debate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule,
              color: Colors.orange,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'This debate is scheduled to begin at:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (scheduleDateTime != null) ...[
              const SizedBox(height: 8),
              Text(
                '${scheduleDateTime.day}/${scheduleDateTime.month}/${scheduleDateTime.year} at ${scheduleDateTime.hour == 0 ? 12 : (scheduleDateTime.hour > 12 ? scheduleDateTime.hour - 12 : scheduleDateTime.hour)}:${scheduleDateTime.minute.toString().padLeft(2, '0')} ${scheduleDateTime.hour >= 12 ? 'PM' : 'AM'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'You can enter the room now and wait for the debate to begin.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToRoom(roomData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enter Room'),
          ),
        ],
      ),
    );
  }

  void _navigateToRoom(Map<String, dynamic> roomData) {
    AppLogger().debug('🚀 Navigating to room: ${roomData['name']}');
    AppLogger().debug('🚀 Room ID: ${roomData['id']}');
    AppLogger().debug('🚀 Room data: $roomData');
    
    if (!mounted) {
      AppLogger().debug('🚀 Widget not mounted, skipping navigation');
      return;
    }
    
    // Show joining message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚀 Joining "${roomData['name']}"...'),
        backgroundColor: primaryPurple,
        duration: const Duration(seconds: 1),
      ),
    );
    
    // Navigate immediately to the actual debates & discussions screen with room data
    AppLogger().debug('🚀 Pushing to DebatesDiscussionsScreen');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DebatesDiscussionsScreen(
          roomId: roomData['id'] ?? '',
          roomName: roomData['name'] ?? 'Debate Room',
          moderatorName: roomData['moderator'] ?? 'Unknown',
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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

    // Debug room data to see what we're getting
    AppLogger().debug('🏗️ Adapting room data: ${roomData.toString()}');
    AppLogger().debug('🏗️ isScheduled: ${roomData['isScheduled']}');
    AppLogger().debug('🏗️ scheduledDate: ${roomData['scheduledDate']}');
    AppLogger().debug('🏗️ moderatorId: ${roomData['moderatorId']}');
    AppLogger().debug('🏗️ createdBy: ${roomData['createdBy']}');

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
      'isScheduled': roomData['isScheduled'] ?? false,
      'scheduledDate': roomData['scheduledDate'],
      'moderatorId': roomData['moderatorId'],
      'createdBy': roomData['createdBy'],
      'createdAt': roomData['createdAt'],
    };
  }
}