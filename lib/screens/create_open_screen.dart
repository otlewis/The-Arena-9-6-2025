import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../models/models.dart';
import '../services/appwrite_service.dart';
import '../constants/appwrite.dart';
import 'open_discussion_room_screen.dart';
import '../widgets/challenge_bell.dart';
import '../core/logging/app_logger.dart';

class CreateOpenScreen extends StatefulWidget {
  const CreateOpenScreen({super.key});

  @override
  State<CreateOpenScreen> createState() => _CreateOpenScreenState();
}

class _CreateOpenScreenState extends State<CreateOpenScreen> {
  final AppwriteService _appwriteService = AppwriteService();
  
  bool _showCreateForm = false;
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _createFormSelectedCategory = ''; // Separate state for create form
  
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _roomTitleController = TextEditingController();
  final TextEditingController _roomDescriptionController = TextEditingController();
  
  List<Map<String, dynamic>> _availableRooms = [];
  String? _currentUserId;
  bool _isCreating = false;

  // Scarlet and Purple theme colors (matching app theme)
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color lightScarlet = Color(0xFFFFF1F0);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);

  final List<String> _categories = [
    'All',
    'Technology',
    'Science',
    'Politics',
    'Sports',
    'Business & Finance',
    'Health & Wellness',
    'Education',
    'Entertainment',
    'Travel',
    'Food & Cooking',
    'Music',
    'Movies & TV',
    'Books & Literature',
    'Current Events',
    'Philosophy',
    'Religion',
    'Custom'
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadRooms(); // Load real rooms from Appwrite
    
    // Add listeners to text controllers for real-time button state updates
    _roomTitleController.addListener(() => setState(() {}));
    _roomDescriptionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _roomTitleController.dispose();
    _roomDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    try {
      final user = await _appwriteService.getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUserId = user.$id;
        });
      }
    } catch (e) {
      AppLogger().debug('Error getting current user: $e');
    }
  }

  Future<void> _loadRooms() async {
    try {
      setState(() => _isLoading = true);
      
      // First, clean up any abandoned rooms automatically
      await _performAutomaticCleanup();
      
      // Then load active rooms
      final rooms = await _appwriteService.getRooms();
      // Note: getRooms() is guaranteed to return a non-null List
      setState(() {
        _availableRooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger().debug('Error loading rooms: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performAutomaticCleanup() async {
    try {
      AppLogger().debug('🧹 Performing automatic room cleanup...');
      
      // Get all active discussion rooms
      final allRooms = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomsCollection,
        queries: [
          Query.equal('type', 'discussion'),
          Query.equal('status', 'active'),
          Query.limit(100),
        ],
      );

      int cleanedRooms = 0;

      for (final room in allRooms.documents) {
        final roomId = room.$id;
        final createdAt = DateTime.parse(room.$createdAt);
        final roomAge = DateTime.now().difference(createdAt);
        
        // Get participants for this room
        final participants = await _appwriteService.databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'room_participants',
          queries: [
            Query.equal('roomId', roomId),
            Query.equal('status', 'joined'),
          ],
        );

        final participantCount = participants.documents.length;
        
        // Check if room should be cleaned up (more aggressive for automatic cleanup)
        bool shouldCleanup = false;
        String reason = '';
        
        if (roomAge.inHours >= 12) {
          shouldCleanup = true;
          reason = 'older than 12 hours';
        } else if (roomAge.inHours >= 2 && participantCount == 0) {
          shouldCleanup = true;
          reason = 'older than 2 hours with no participants';
        } else if (roomAge.inMinutes >= 15 && participantCount == 0) {
          shouldCleanup = true;
          reason = 'empty for 15+ minutes';
        }

        if (shouldCleanup) {
          AppLogger().debug('🧹 Auto-cleaning room $roomId: $reason');
          
          // Mark all participants as left
          for (final participant in participants.documents) {
            await _appwriteService.databases.updateDocument(
              databaseId: 'arena_db',
              collectionId: 'room_participants',
              documentId: participant.$id,
              data: {
                'status': 'left',
                'leftAt': DateTime.now().toIso8601String(),
              },
            );
          }
          
          // Mark room as ended
          await _appwriteService.databases.updateDocument(
            databaseId: 'arena_db',
            collectionId: AppwriteConstants.roomsCollection,
            documentId: roomId,
            data: {
              'status': 'auto_cleaned',
              'endedAt': DateTime.now().toIso8601String(),
            },
          );
          
          cleanedRooms++;
        }
      }
      
      if (cleanedRooms > 0) {
        AppLogger().info('Auto-cleanup completed: $cleanedRooms rooms cleaned');
      }
    } catch (e) {
      AppLogger().error('Error during automatic cleanup: $e');
      // Don't rethrow - continue with normal room loading
    }
  }

  List<Map<String, dynamic>> get _filteredRooms {
    List<Map<String, dynamic>> filtered = _availableRooms;
    
    // Filter by category
    if (_selectedCategory != 'All') {
      filtered = filtered.where((room) => 
        (room['tags'] as List<dynamic>?)?.contains(_selectedCategory) ?? false
      ).toList();
    }
    
    // Filter by search
    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((room) =>
        room['title'].toString().toLowerCase().contains(_searchController.text.toLowerCase()) ||
        room['description'].toString().toLowerCase().contains(_searchController.text.toLowerCase())
      ).toList();
    }
    
    return filtered;
  }

  Future<void> _createRoom() async {
    if (_roomTitleController.text.trim().isEmpty || 
        _roomDescriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in both title and description'),
          backgroundColor: scarletRed,
        ),
      );
      return;
    }

    // Check if category is selected and not 'All' or 'Custom'
    if (_createFormSelectedCategory.isEmpty || 
        _createFormSelectedCategory == 'All' || 
        _createFormSelectedCategory == 'Custom') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a specific category for your room'),
          backgroundColor: scarletRed,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }


    setState(() => _isCreating = true);
    
    try {
      // Get current user
      final user = await _appwriteService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create room in Appwrite
      final roomId = await _appwriteService.createDiscussionRoom(
        title: _roomTitleController.text.trim(),
        description: _roomDescriptionController.text.trim(),
        createdBy: user.$id,
        tags: [_createFormSelectedCategory],
        maxParticipants: 50,
        status: 'active',
        isPrivate: false,
      );

      // Get the created room data
      final roomData = await _appwriteService.getRoom(roomId);
      if (roomData == null) {
        throw Exception('Failed to retrieve created room');
      }

      // Create Room object from Appwrite data
      final room = Room.fromMap(roomData);

      setState(() => _isCreating = false);

      // Clear form
      _roomTitleController.clear();
      _roomDescriptionController.clear();
      setState(() {
        _showCreateForm = false;
        _selectedCategory = 'All';
        _createFormSelectedCategory = ''; // Reset create form category
      });

      // Navigate to room screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OpenDiscussionRoomScreen(room: room),
          ),
        );
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating room: $e'),
            backgroundColor: scarletRed,
          ),
        );
      }
    }
  }

  Future<void> _joinRoom(Map<String, dynamic> roomData) async {
    if (_currentUserId == null) return;

    try {
      // Check for metadata in room description for private/scheduled rooms
      final description = roomData['description'] as String? ?? '';
      if (description.contains('[METADATA]')) {
        final metadataStart = description.indexOf('[METADATA]');
        final metadataStr = description.substring(metadataStart + '[METADATA]'.length);
        
        // Check if room is private
        if (metadataStr.contains('isPrivate: true')) {
          // Check if user is the moderator (moderators don't need password)
          final isCreator = roomData['createdBy'] == _currentUserId;
          
          if (!isCreator) {
            // User is not creator, validate password
            final passwordValid = await _validateRoomPassword(metadataStr);
            if (!passwordValid) {
              return; // Password validation failed or user cancelled
            }
          }
        }
        
        // Check if room is scheduled
        if (metadataStr.contains('isScheduled: true')) {
          // Extract scheduled time from metadata
          final scheduledTimeMatch = RegExp(r'scheduledTime: ([^,}]+)').firstMatch(metadataStr);
          if (scheduledTimeMatch != null) {
            final scheduledTimeStr = scheduledTimeMatch.group(1)?.trim().replaceAll("'", "");
            if (scheduledTimeStr != null) {
              final scheduledTime = DateTime.parse(scheduledTimeStr);
              final now = DateTime.now();
              
              if (now.isBefore(scheduledTime)) {
                final isCreator = roomData['createdBy'] == _currentUserId;
                
                if (!isCreator) {
                  // Show warning that room is scheduled for later
                  if (mounted) {
                    await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.schedule, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Scheduled Room'),
                          ],
                        ),
                        content: Text(
                          'This room is scheduled to start at ${_formatDateTime(scheduledTime)}. Only the moderator can enter early.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                  return;
                } else {
                  // Creator can choose to start early or enter
                  if (!mounted) return;
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Scheduled Room'),
                      content: Text('This room is scheduled for ${_formatDateTime(scheduledTime)}. What would you like to do?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'cancel'),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'enter'),
                          child: const Text('Enter Now'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, 'start'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Start Room Early'),
                        ),
                      ],
                    ),
                  );
                  
                  if (result == 'start') {
                    // Start room early by removing scheduled metadata
                    await _startRoomEarly(roomData['id']);
                    // Refresh rooms to show updated status
                    await _loadRooms();
                  } else if (result != 'enter') {
                    return; // User cancelled
                  }
                }
              }
            }
          }
        }
      }

      // Create Room object for navigation (clean description without metadata)
      String cleanDescription = description;
      if (description.contains('[METADATA]')) {
        cleanDescription = description.substring(0, description.indexOf('[METADATA]')).trim();
      }
      
      final room = Room(
        id: roomData['id'],
        title: roomData['title'],
        description: cleanDescription,
        type: RoomType.discussion,
        createdBy: roomData['createdBy'],
        createdAt: DateTime.parse(roomData['createdAt']),
        status: RoomStatus.active,
        participantIds: List<String>.from(roomData['participants'] ?? []),
        maxParticipants: roomData['maxParticipants'] ?? 999999,
        tags: List<String>.from(roomData['tags'] ?? []),
      );

      // Navigate to the room
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OpenDiscussionRoomScreen(room: room),
          ),
        );
      }

    } catch (e) {
      AppLogger().debug('Error joining room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining room: $e'),
            backgroundColor: scarletRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              scarletRed.withValues(alpha: 0.05),
              accentPurple.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _showCreateForm ? _buildCreateForm() : _buildMainContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: scarletRed.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: scarletRed.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: scarletRed,
                  size: 20,
                ),
              ),
              const ChallengeBell(iconColor: Color(0xFFFF2400)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _showCreateForm ? 'Create Room' : 'Open Discussions',
                  style: const TextStyle(
                    color: deepPurple,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_showCreateForm)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showCreateForm = true;
                    });
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scarletRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              if (_showCreateForm)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showCreateForm = false;
                      _roomTitleController.clear();
                      _roomDescriptionController.clear();
                      _createFormSelectedCategory = ''; // Reset create form category
                    });
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: scarletRed),
                  ),
                ),
            ],
          ),
          if (!_showCreateForm) ...[
            const SizedBox(height: 15),
            _buildSearchBar(),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: lightScarlet,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scarletRed.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() {}),
        style: const TextStyle(color: deepPurple),
        decoration: InputDecoration(
          hintText: 'Search rooms...',
          hintStyle: TextStyle(
            color: deepPurple.withValues(alpha: 0.6),
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: scarletRed,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoriesSection(),
          _buildRoomsSection(),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Categories',
            style: TextStyle(
              color: deepPurple,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected 
                          ? scarletRed 
                          : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? scarletRed : scarletRed.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scarletRed.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? Colors.white : deepPurple,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Active Rooms',
                style: TextStyle(
                  color: deepPurple,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scarletRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_filteredRooms.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(
                  color: scarletRed,
                ),
              ),
            )
          else if (_filteredRooms.isEmpty)
            _buildEmptyState()
          else
            ..._filteredRooms.map((room) => _buildRoomCard(room)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: deepPurple.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No rooms found',
            style: TextStyle(
              color: deepPurple.withValues(alpha: 0.8),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or category filter',
            style: TextStyle(
              color: deepPurple.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> roomData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scarletRed.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: scarletRed.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          _joinRoom(roomData);
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Moderator profile picture
                if (roomData['moderatorProfile']?['avatar'] != null)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scarletRed.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        roomData['moderatorProfile']['avatar'],
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentPurple.withValues(alpha: 0.2),
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 16,
                              color: accentPurple,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (roomData['moderatorProfile']?['avatar'] == null)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentPurple.withValues(alpha: 0.2),
                      border: Border.all(
                        color: scarletRed.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 16,
                      color: accentPurple,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomData['title'],
                        style: const TextStyle(
                          color: deepPurple,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (roomData['moderatorProfile']?['name'] != null)
                        Text(
                          'by ${roomData['moderatorProfile']['name']}',
                          style: TextStyle(
                            color: deepPurple.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildRoomStatusBadges(roomData),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getCleanDescription(roomData['description']),
              style: TextStyle(
                color: deepPurple.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.people,
                  size: 16,
                  color: accentPurple,
                ),
                const SizedBox(width: 6),
                Text(
                  '${roomData['participants'].length} ${roomData['participants'].length == 1 ? 'user' : 'users'}',
                  style: TextStyle(
                    color: deepPurple.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: accentPurple,
                ),
                const SizedBox(width: 6),
                Text(
                  _getTimeAgo(DateTime.parse(roomData['createdAt'])),
                  style: TextStyle(
                    color: deepPurple.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (roomData['tags']?.isNotEmpty ?? false)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: lightScarlet,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: scarletRed.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      roomData['tags'].first,
                      style: const TextStyle(
                        color: scarletRed,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Room Details',
            style: TextStyle(
              color: deepPurple,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          
          // Category Selection
          const Text(
            'Category *',
            style: TextStyle(
              color: deepPurple,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _buildCategorySelector(),
          
          const SizedBox(height: 20),
          
          // Room Title
          const Text(
            'Room Title *',
            style: TextStyle(
              color: deepPurple,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _roomTitleController,
            style: const TextStyle(color: deepPurple),
            decoration: InputDecoration(
              hintText: 'Enter room title...',
              hintStyle: TextStyle(
                color: deepPurple.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: lightScarlet,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: scarletRed.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: scarletRed.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: scarletRed,
                  width: 2,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Room Description
          const Text(
            'Description *',
            style: TextStyle(
              color: deepPurple,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _roomDescriptionController,
            style: const TextStyle(color: deepPurple),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Describe what your room is about...',
              hintStyle: TextStyle(
                color: deepPurple.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: lightScarlet,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: scarletRed.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: scarletRed.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: scarletRed,
                  width: 2,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Create Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isCreating || 
                         _roomTitleController.text.trim().isEmpty ||
                         _roomDescriptionController.text.trim().isEmpty ||
                         _createFormSelectedCategory.isEmpty ||
                         _createFormSelectedCategory == 'All' ||
                         _createFormSelectedCategory == 'Custom') 
                ? null 
                : _createRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: scarletRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: scarletRed.withValues(alpha: 0.3),
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
                        'Creating Room...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Create Room',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    // Filter out 'All' and 'Custom' for the create form
    final availableCategories = _categories
        .where((category) => category != 'All' && category != 'Custom')
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightScarlet,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _createFormSelectedCategory.isEmpty 
            ? Colors.red.withValues(alpha: 0.3)
            : scarletRed.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _createFormSelectedCategory.isEmpty 
                  ? 'Select a category for your room'
                  : 'Selected: $_createFormSelectedCategory',
                style: TextStyle(
                  color: _createFormSelectedCategory.isEmpty 
                    ? Colors.red.withValues(alpha: 0.7)
                    : deepPurple,
                  fontSize: 14,
                  fontWeight: _createFormSelectedCategory.isEmpty 
                    ? FontWeight.normal 
                    : FontWeight.w500,
                ),
              ),
              if (_createFormSelectedCategory.isNotEmpty) ...[
                const Spacer(),
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableCategories.map((category) {
              final isSelected = _createFormSelectedCategory == category;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _createFormSelectedCategory = category;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? scarletRed : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? scarletRed : scarletRed.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scarletRed.withValues(alpha: 0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isSelected ? Colors.white : deepPurple,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_createFormSelectedCategory.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Please select a category to help others find your room',
                style: TextStyle(
                  color: Colors.red.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String dateStr;
    if (dateToCheck == today) {
      dateStr = 'Today';
    } else if (dateToCheck == tomorrow) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
    
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$dateStr at $hour:$minute $amPm';
  }

  // Removed unused _buildRoomSettings method
  /*
  Widget _buildRoomSettings() {
    return const SizedBox.shrink(); // Removed room settings functionality
    // Original implementation removed - keeping method to prevent compilation errors
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightScarlet,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scarletRed.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Room Settings',
            style: TextStyle(
              color: deepPurple,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Private Room Setting
          Row(
            children: [
              Icon(
                _isPrivate ? Icons.lock : Icons.lock_open,
                color: _isPrivate ? scarletRed : deepPurple.withValues(alpha: 0.6),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Private Room',
                      style: TextStyle(
                        color: deepPurple,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Require password to join',
                      style: TextStyle(
                        color: deepPurple.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isPrivate,
                onChanged: (value) {
                  setState(() {
                    _isPrivate = value;
                    if (!value) {
                      _passwordController.clear();
                    }
                  });
                  // Debug print
                  debugPrint('Private room toggled: $_isPrivate');
                },
                activeColor: scarletRed,
                activeTrackColor: scarletRed.withValues(alpha: 0.3),
              ),
            ],
          ),
          
          // Debug: Show current state
          Text('Debug: _isPrivate = $_isPrivate', style: TextStyle(color: Colors.red, fontSize: 12)),
          
          // Password Field (only show if private)
          if (_isPrivate) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: deepPurple),
              decoration: InputDecoration(
                hintText: 'Enter room password...',
                hintStyle: TextStyle(
                  color: deepPurple.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.key, color: scarletRed, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: scarletRed.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: scarletRed.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: scarletRed,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Schedule for Later Setting
          Row(
            children: [
              Icon(
                _isScheduled ? Icons.schedule : Icons.schedule_outlined,
                color: _isScheduled ? scarletRed : deepPurple.withValues(alpha: 0.6),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Schedule for Later',
                      style: TextStyle(
                        color: deepPurple,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Set a specific start time',
                      style: TextStyle(
                        color: deepPurple.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isScheduled,
                onChanged: (value) {
                  setState(() {
                    _isScheduled = value;
                    if (!value) {
                      _scheduledTime = null;
                    }
                  });
                },
                activeColor: scarletRed,
                activeTrackColor: scarletRed.withValues(alpha: 0.3),
              ),
            ],
          ),
          
          // Date/Time Picker (only show if scheduled)
          if (_isScheduled) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _showDateTimePicker,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: scarletRed.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: scarletRed, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _scheduledTime != null
                            ? 'Scheduled for ${_formatDateTime(_scheduledTime!)}'
                            : 'Tap to select date and time',
                        style: TextStyle(
                          color: _scheduledTime != null
                              ? deepPurple
                              : deepPurple.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_right, color: scarletRed),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
    */

  Widget _buildRoomStatusBadges(Map<String, dynamic> roomData) {
    List<Widget> badges = [];
    
    // Check room status
    final status = roomData['status'] as String? ?? 'active';
    final description = roomData['description'] as String? ?? '';
    
    // Check for private room
    bool isPrivate = false;
    bool isScheduled = false;
    DateTime? scheduledTime;
    
    if (description.contains('[METADATA]')) {
      final metadataStart = description.indexOf('[METADATA]');
      final metadataStr = description.substring(metadataStart + '[METADATA]'.length);
      
      isPrivate = metadataStr.contains('isPrivate: true');
      isScheduled = metadataStr.contains('isScheduled: true');
      
      if (isScheduled) {
        final scheduledTimeMatch = RegExp(r'scheduledTime: ([^,}]+)').firstMatch(metadataStr);
        if (scheduledTimeMatch != null) {
          final scheduledTimeStr = scheduledTimeMatch.group(1)?.trim().replaceAll("'", "");
          if (scheduledTimeStr != null) {
            try {
              scheduledTime = DateTime.parse(scheduledTimeStr);
            } catch (e) {
              // Ignore parsing errors
            }
          }
        }
      }
    }
    
    // Main status badge
    if (status == 'scheduled' || isScheduled) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, size: 12, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              scheduledTime != null && scheduledTime.isAfter(DateTime.now())
                  ? 'SCHEDULED'
                  : 'LIVE',
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ));
    } else {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: lightScarlet,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scarletRed.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: const Text(
          'LIVE',
          style: TextStyle(
            color: scarletRed,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ));
    }
    
    // Private badge
    if (isPrivate) {
      badges.add(const SizedBox(width: 6));
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: deepPurple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: deepPurple.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 10, color: deepPurple),
            SizedBox(width: 2),
            Text(
              'PRIVATE',
              style: TextStyle(
                color: deepPurple,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ));
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: badges,
    );
  }

  String _getCleanDescription(String? description) {
    if (description == null) return '';
    if (description.contains('[METADATA]')) {
      return description.substring(0, description.indexOf('[METADATA]')).trim();
    }
    return description;
  }

  Future<bool> _validateRoomPassword(String metadataStr) async {
    // Password validation removed - all rooms are now public
    return true;
  }

  Future<void> _startRoomEarly(String roomId) async {
    try {
      // Get the current room data
      final roomDoc = await _appwriteService.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomsCollection,
        documentId: roomId,
      );

      // Remove scheduling metadata from description
      String description = roomDoc.data['description'] as String? ?? '';
      if (description.contains('[METADATA]')) {
        final metadataStart = description.indexOf('[METADATA]');
        final originalDescription = description.substring(0, metadataStart).trim();
        final metadataStr = description.substring(metadataStart + '[METADATA]'.length);
        
        // Parse metadata and remove scheduling
        final isPrivateMatch = RegExp(r'isPrivate: (true|false)').firstMatch(metadataStr);
        final passwordMatch = RegExp(r'password: ([^,}]+)').firstMatch(metadataStr);
        
        String newDescription = originalDescription;
        if (isPrivateMatch != null && isPrivateMatch.group(1) == 'true') {
          // Keep private settings but remove scheduling
          final metadata = {
            'isPrivate': true,
            'password': passwordMatch?.group(1)?.trim().replaceAll("'", "") ?? '',
          };
          newDescription += ' [METADATA]${metadata.toString()}';
        }
        
        // Update the room with new description (no scheduling)
        await _appwriteService.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: AppwriteConstants.roomsCollection,
          documentId: roomId,
          data: {
            'description': newDescription,
          },
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room started! Users can now join.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger().debug('Error starting room early: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting room: $e'),
            backgroundColor: scarletRed,
          ),
        );
      }
    }
  }

  // Removed unused _showDateTimePicker method
  /*
  Future<void> _showDateTimePicker() async {
    // Method stubbed out - room scheduling functionality removed
    return;
    
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      
      if (time != null && mounted) {
        setState(() {
          _scheduledTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      } else if (mounted) {
        setState(() {
          _isScheduled = false;
        });
      }
    } else if (mounted) {
      setState(() {
        _isScheduled = false;
      });
    }
  }
  */

// End of _CreateOpenScreenState class
}

// Password validation dialog removed - no longer needed