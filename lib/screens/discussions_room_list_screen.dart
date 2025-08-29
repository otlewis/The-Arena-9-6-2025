import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../widgets/challenge_bell.dart';
import 'create_discussion_room_screen.dart';
import 'debates_discussions_screen.dart';
import '../services/appwrite_service.dart';
import '../services/theme_service.dart';
import '../core/logging/app_logger.dart';
import '../constants/appwrite.dart';

class DiscussionsRoomListScreen extends StatefulWidget {
  final String? preSelectedFormat;
  
  const DiscussionsRoomListScreen({super.key, this.preSelectedFormat});

  @override
  State<DiscussionsRoomListScreen> createState() => _DiscussionsRoomListScreenState();
}

class _DiscussionsRoomListScreenState extends State<DiscussionsRoomListScreen> {
  // Purple theme colors
  static const Color primaryPurple = Color(0xFF8B5CF6);

  final AppwriteService _appwrite = AppwriteService();
  final ThemeService _themeService = ThemeService();
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
      AppLogger().debug('Loading discussion rooms...');
      final allRooms = await _appwrite.getDebateDiscussionRooms();
      AppLogger().debug('🔍 Raw rooms data: ${allRooms.toString()}');
      
      // Filter rooms by preSelectedFormat if provided
      List<Map<String, dynamic>> filteredRooms = allRooms;
      if (widget.preSelectedFormat != null) {
        filteredRooms = allRooms.where((room) {
          final roomDebateStyle = room['debateStyle'] as String?;
          return roomDebateStyle == widget.preSelectedFormat;
        }).toList();
        
        AppLogger().debug('🔍 Filtered ${filteredRooms.length} rooms for format: ${widget.preSelectedFormat}');
      }
      
      // Debug room IDs
      for (var room in filteredRooms) {
        AppLogger().debug('Room loaded: ${room['title']} with ID: ${room['id']}');
      }
      
      if (mounted) {
        setState(() {
          _rooms = filteredRooms;
          _isLoading = false;
        });
        AppLogger().debug('Loaded ${filteredRooms.length} discussion rooms');
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
        'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.debateDiscussionRoomsCollection}.documents'
      ]);

      _roomsSubscription?.stream.listen(
        (response) {
          AppLogger().debug('Real-time room update: ${response.events}');
          
          if (response.events.any((event) => event.contains('debate_discussion_rooms.documents'))) {
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
        builder: (context) => CreateDiscussionRoomScreen(preSelectedFormat: widget.preSelectedFormat),
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

  String _getFormattedTitle(String format) {
    switch (format) {
      case 'Debate':
        return 'Debate Rooms'; // Includes both regular and 2v2 debates
      case 'Take':
        return 'Take Rooms';
      case 'Discussion':
        return 'Discussion Rooms';
      default:
        return '$format Rooms';
    }
  }

  String _getDisplayDebateStyle(String? debateStyle) {
    switch (debateStyle) {
      case 'Debate':
        return 'DEBATE';
      case 'Take':
        return 'TAKE';
      case 'Discussion':
        return 'DISCUSSION';
      default:
        return debateStyle?.toUpperCase() ?? 'DISCUSSION';
    }
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.isDarkMode 
          ? const Color(0xFF2D2D2D)
          : const Color(0xFFE8E8E8),
      appBar: AppBar(
        backgroundColor: _themeService.isDarkMode 
            ? const Color(0xFF2D2D2D)
            : const Color(0xFFE8E8E8),
        elevation: 0,
        title: Text(
          widget.preSelectedFormat != null 
              ? _getFormattedTitle(widget.preSelectedFormat!)
              : 'Debates & Discussions',
          style: TextStyle(
            color: _themeService.isDarkMode ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(
          color: _themeService.isDarkMode ? Colors.white : Colors.black87,
        ),
        actions: [
          _buildNeumorphicAppBarIcon(
            const ChallengeBell(iconColor: Color(0xFF8B5CF6)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Header section with stats
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _themeService.isDarkMode 
                  ? const Color(0xFF3A3A3A)
                  : const Color(0xFFF0F0F3),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _themeService.isDarkMode 
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.white.withValues(alpha: 0.8),
                  offset: const Offset(-8, -8),
                  blurRadius: 16,
                ),
                BoxShadow(
                  color: _themeService.isDarkMode 
                      ? Colors.black.withValues(alpha: 0.5)
                      : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
                  offset: const Offset(8, 8),
                  blurRadius: 16,
                ),
              ],
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
                          color: primaryPurple,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_rooms.where((room) => room['status'] == 'active').length} active discussions',
                        style: TextStyle(
                          color: _themeService.isDarkMode 
                              ? Colors.white70
                              : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildNeumorphicButton(
                  onPressed: _navigateToCreateRoom,
                  icon: Icons.add,
                  label: 'Create Room',
                ),
              ],
            ),
          ),
          
          // Room list
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: primaryPurple),
                        const SizedBox(height: 16),
                        Text(
                          'Loading rooms...',
                          style: TextStyle(
                            fontSize: 16,
                            color: _themeService.isDarkMode 
                                ? Colors.white70
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : _rooms.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: primaryPurple,
                        onRefresh: _loadRooms,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: _rooms.length,
                          itemBuilder: (context, index) {
                            final room = _rooms[index];
                            final adaptedRoom = _adaptRoomData(room);
                            return _buildNeumorphicRoomCard(adaptedRoom);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeumorphicAppBarIcon(Widget child) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white.withValues(alpha: 0.7),
            offset: const Offset(-4, -4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.black.withValues(alpha: 0.5)
                : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
            offset: const Offset(4, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Center(child: child),
    );
  }

  Widget _buildNeumorphicButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _themeService.isDarkMode 
              ? const Color(0xFF2D2D2D)
              : const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _themeService.isDarkMode 
                  ? Colors.black.withValues(alpha: 0.6)
                  : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
              offset: const Offset(3, 3),
              blurRadius: 6,
              spreadRadius: -2,
            ),
            BoxShadow(
              color: _themeService.isDarkMode 
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.white.withValues(alpha: 0.8),
              offset: const Offset(-3, -3),
              blurRadius: 6,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: primaryPurple,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: primaryPurple,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _themeService.isDarkMode 
                  ? const Color(0xFF3A3A3A)
                  : const Color(0xFFF0F0F3),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _themeService.isDarkMode 
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.white.withValues(alpha: 0.7),
                  offset: const Offset(-8, -8),
                  blurRadius: 16,
                ),
                BoxShadow(
                  color: _themeService.isDarkMode 
                      ? Colors.black.withValues(alpha: 0.5)
                      : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
                  offset: const Offset(8, 8),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(
              Icons.forum_outlined,
              size: 60,
              color: _themeService.isDarkMode 
                  ? Colors.white24
                  : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No active rooms',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _themeService.isDarkMode 
                  ? Colors.white70
                  : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create the first room to get started!',
            style: TextStyle(
              fontSize: 16,
              color: _themeService.isDarkMode 
                  ? Colors.white54
                  : Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNeumorphicRoomCard(Map<String, dynamic> roomData) {
    final isScheduled = roomData['isScheduled'] as bool? ?? false;
    final isLive = roomData['isLive'] as bool? ?? false;
    final participants = roomData['participantCount'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode 
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white.withValues(alpha: 0.8),
            offset: const Offset(-6, -6),
            blurRadius: 12,
          ),
          BoxShadow(
            color: _themeService.isDarkMode 
                ? Colors.black.withValues(alpha: 0.5)
                : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
            offset: const Offset(6, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _joinRoom(roomData),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Room type indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryPurple.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _getDisplayDebateStyle(roomData['debateStyle']?.toString()),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: primaryPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _themeService.isDarkMode 
                            ? const Color(0xFF2D2D2D)
                            : const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _themeService.isDarkMode 
                                ? Colors.black.withValues(alpha: 0.6)
                                : const Color(0xFFA3B1C6).withValues(alpha: 0.3),
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                            spreadRadius: -1,
                          ),
                          BoxShadow(
                            color: _themeService.isDarkMode 
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.white.withValues(alpha: 0.8),
                            offset: const Offset(-2, -2),
                            blurRadius: 4,
                            spreadRadius: -1,
                          ),
                        ],
                      ),
                      child: Text(
                        isLive ? 'LIVE' : isScheduled ? 'SCHEDULED' : 'OPEN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isLive ? Colors.red : isScheduled ? Colors.orange : Colors.green,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Participant count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people,
                            size: 12,
                            color: primaryPurple,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$participants',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primaryPurple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  roomData['title'] ?? roomData['name'] ?? 'Untitled Room',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (roomData['description'] != null && roomData['description'].toString().isNotEmpty)
                  Text(
                    roomData['description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[600],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Moderator profile picture
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryPurple.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: ClipOval(
                        child: roomData['moderatorAvatar'] != null && roomData['moderatorAvatar'].toString().isNotEmpty
                          ? Image.network(
                              roomData['moderatorAvatar'],
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: primaryPurple.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    size: 14,
                                    color: primaryPurple,
                                  ),
                                );
                              },
                            )
                          : Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: primaryPurple.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 14,
                                color: primaryPurple,
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Moderator: ${roomData['moderator'] ?? 'Unknown'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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