import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';
import '../core/logging/app_logger.dart';
import '../services/appwrite_service.dart';
import 'debates_discussions_screen.dart';
import 'create_d_and_d_screen.dart';

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
              // Header with room type and category
              Row(
                children: [
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
                            Icon(
                              LucideIcons.user,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
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
                        Icon(
                          LucideIcons.user,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
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

  void _joinRoom(Map<String, dynamic> room) {
    AppLogger().info('Joining room: ${room['title']}');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DebatesDiscussionsScreen(),
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
        builder: (context) => const CreateDAndDScreen(),
      ),
    ).then((_) {
      // Refresh rooms list when user comes back from creating a room
      _loadRooms();
    });
  }

}