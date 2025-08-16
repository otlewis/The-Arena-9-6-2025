import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';
import '../core/logging/app_logger.dart';
import '../services/appwrite_service.dart';
import 'debates_discussions_screen.dart';
import 'create_discussion_room_screen.dart';

class DAndDRoomListScreen extends StatefulWidget {
  const DAndDRoomListScreen({super.key});

  @override
  State<DAndDRoomListScreen> createState() => _DAndDRoomListScreenState();
}

class _DAndDRoomListScreenState extends State<DAndDRoomListScreen> {
  final AppwriteService _appwriteService = AppwriteService();
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = false;

  // Colors
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color darkGray = Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      AppLogger().info('Loading rooms from Appwrite...');
      final rooms = await _appwriteService.getRooms();
      
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _isLoading = false;
        });
        AppLogger().info('Loaded ${_rooms.length} rooms from Appwrite');
        for (var room in _rooms) {
          AppLogger().info('Room: ${room['title']} - Status: ${room['status']}');
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        title: const Text(
          'Debates & Discussions',
          style: TextStyle(
            color: darkGray,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: scarletRed),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: scarletRed),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: accentPurple),
            onPressed: _isLoading ? null : () {
              _loadRooms();
              AppLogger().info('Manual refresh triggered');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildRoomList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewRoom,
        backgroundColor: accentPurple,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Create Room'),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                const Icon(Icons.people, color: accentPurple, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Active Rooms (${_rooms.where((room) => room['status'] == 'active').length}) | Total: ${_rooms.length}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkGray,
                  ),
                ),
                if (_isLoading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 8),
          const Text(
            'Join live debates, discussions, and takes from the community',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList() {
    if (_isLoading && _rooms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading rooms...'),
          ],
        ),
      );
    }
    
    final activeRooms = _rooms.where((room) => room['status'] == 'active').toList();
    
    if (activeRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.messageSquare,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No active rooms yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to create a room!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: activeRooms.length,
        itemBuilder: (context, index) {
          final room = activeRooms[index];
          return _buildRoomCard(room);
        },
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    // Check if room is scheduled and live status
    final isScheduled = room['isScheduled'] as bool? ?? false;
    final isLive = room['status'] == 'active';
    final scheduledDate = room['scheduledDate'];
    
    // Format scheduled date for display
    String? formattedScheduledDate;
    if (isScheduled && scheduledDate != null) {
      try {
        final dateTime = DateTime.parse(scheduledDate);
        
        // Format to 12-hour time
        final hour12 = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
        final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
        formattedScheduledDate = '${dateTime.day}/${dateTime.month}/${dateTime.year} $hour12:${dateTime.minute.toString().padLeft(2, '0')} $amPm';
      } catch (e) {
        AppLogger().error('Error parsing scheduled date: $e');
      }
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => _joinRoom(room),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with room type, category, and live/scheduled status
              Row(
                children: [
                  if (isLive) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 8),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (isScheduled) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedScheduledDate ?? 'SCHEDULED',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: _buildRoomTypeBadge(room['tags']?.isNotEmpty == true ? room['tags'][0] : 'Discussion'),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _buildCategoryBadge(room['tags']?.length > 1 ? room['tags'][1] : 'General'),
                  ),
                  const Spacer(),
                  if (room['isPrivate'] == true)
                    Icon(
                      LucideIcons.lock,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Room title
              Text(
                room['title'] ?? 'Untitled Room',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkGray,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              if (room['description'] != null && room['description'].isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  room['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Footer with host and participants
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrowScreen = constraints.maxWidth < 300;
                  final creatorName = room['moderatorProfile']?['name'] ?? 
                                    _getDisplayName(room['createdBy']) ?? 
                                    'Unknown';
                  
                  if (isNarrowScreen) {
                    // Stack vertically on narrow screens
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Moderator profile picture
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: accentPurple.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: ClipOval(
                                child: room['moderatorProfile']?['avatar'] != null && room['moderatorProfile']['avatar'].toString().isNotEmpty
                                  ? Image.network(
                                      room['moderatorProfile']['avatar'],
                                      width: 20,
                                      height: 20,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: accentPurple.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            LucideIcons.user,
                                            size: 12,
                                            color: accentPurple,
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: accentPurple.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        LucideIcons.user,
                                        size: 12,
                                        color: accentPurple,
                                      ),
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'by $creatorName',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              LucideIcons.users,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${room['participantCount'] ?? 0} joined',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _getTimeAgo(DateTime.parse(room['createdAt'])),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  } else {
                    // Single row on wider screens
                    return Row(
                      children: [
                        // Moderator profile picture
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accentPurple.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: ClipOval(
                            child: room['moderatorProfile']?['avatar'] != null && room['moderatorProfile']['avatar'].toString().isNotEmpty
                              ? Image.network(
                                  room['moderatorProfile']['avatar'],
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: accentPurple.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        LucideIcons.user,
                                        size: 12,
                                        color: accentPurple,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: accentPurple.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    LucideIcons.user,
                                    size: 12,
                                    color: accentPurple,
                                  ),
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'by $creatorName',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          LucideIcons.users,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${room['participantCount'] ?? 0} joined',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _getTimeAgo(DateTime.parse(room['createdAt'])),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomTypeBadge(String roomType) {
    Color color;
    switch (roomType) {
      case 'Debate':
        color = scarletRed;
        break;
      case 'Take':
        color = accentPurple;
        break;
      case 'Discussion':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        roomType.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  String? _getDisplayName(dynamic createdBy) {
    if (createdBy == null) return null;
    
    final createdByStr = createdBy.toString();
    if (createdByStr.length > 15) {
      return '${createdByStr.substring(0, 12)}...';
    }
    return createdByStr;
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _joinRoom(Map<String, dynamic> room) async {
    AppLogger().info('Joining room: ${room['title']}');
    
    // Get current user
    final currentUser = await _appwriteService.getCurrentUser();
    if (currentUser == null) {
      _showSnackBar('Please log in to join rooms');
      return;
    }
    
    // Check if room is scheduled and its current status
    final isScheduled = room['isScheduled'] as bool? ?? false;
    final isLive = room['status'] == 'active';
    final scheduledDate = room['scheduledDate'];
    final moderatorId = room['moderatorId'] as String? ?? room['createdBy'] as String?;
    final isCurrentUserModerator = currentUser.$id == moderatorId;
    
    AppLogger().debug('🏁 Is room scheduled: $isScheduled');
    AppLogger().debug('🏁 Is room live: $isLive');
    AppLogger().debug('🏁 Room status: ${room['status']}');
    AppLogger().debug('🏁 Scheduled date: $scheduledDate');
    AppLogger().debug('🏁 Current user ID: ${currentUser.$id}');
    AppLogger().debug('🏁 Moderator ID: $moderatorId');
    AppLogger().debug('🏁 Created by: ${room['createdBy']}');
    AppLogger().debug('🏁 Is current user moderator: $isCurrentUserModerator');
    
    // Handle scheduled room logic - show info but allow entry
    if (isScheduled && !isLive) {
      AppLogger().debug('🏁 Room is scheduled, showing schedule info and allowing entry');
      _showScheduledRoomInfoDialog(room);
      return;
    } else if (isScheduled && isLive) {
      AppLogger().debug('🏁 Room was scheduled but is now live - allowing all users to join');
    }
    
    // Check if room is private
    final isPrivate = room['isPrivate'] as bool? ?? false;
    
    if (isPrivate) {
      _showPasswordDialog(room);
    } else {
      _navigateToRoom(room);
    }
  }

  void _showPasswordDialog(Map<String, dynamic> room) {
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
              onSubmitted: (_) => _validateAndJoin(room, passwordController.text),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _validateAndJoin(room, passwordController.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _validateAndJoin(Map<String, dynamic> room, String enteredPassword) async {
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
      final isValid = await _appwriteService.validateDebateDiscussionRoomPassword(
        roomId: room['id'] ?? '',
        enteredPassword: enteredPassword.trim(),
      );

      if (!mounted) return;

      if (isValid) {
        Navigator.of(context).pop(); // Close password dialog
        _navigateToRoom(room);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect password. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error validating password. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToRoom(Map<String, dynamic> room) {
    if (!mounted) {
      AppLogger().debug('🚀 Widget not mounted, skipping navigation');
      return;
    }
    
    AppLogger().debug('🚀 Navigating to room: ${room['title']}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DebatesDiscussionsScreen(
          roomId: room['id'] ?? '',
          roomName: room['title'],
          moderatorName: room['moderatorProfile']?['name'],
        ),
      ),
    ).then((_) {
      // Refresh rooms list when user comes back
      _loadRooms();
    });
  }

  void _createNewRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateDiscussionRoomScreen(),
      ),
    ).then((_) {
      // Refresh rooms list when user comes back from creating a room
      _loadRooms();
    });
  }


  void _showScheduledRoomInfoDialog(Map<String, dynamic> room) {
    final scheduledDate = room['scheduledDate'] as String?;
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
              _navigateToRoom(room);
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

}