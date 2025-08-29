import '../core/logging/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../constants/appwrite.dart';
import '../models/moderator_judge.dart';
import 'moderator_registration_screen.dart';
import 'moderator_agreement_screen.dart';

class ModeratorListScreen extends StatefulWidget {
  final String? arenaRoomId;
  final String? debateTitle;
  final String? debateDescription;
  final String? category;

  const ModeratorListScreen({
    super.key,
    this.arenaRoomId,
    this.debateTitle,
    this.debateDescription,
    this.category,
  });

  @override
  State<ModeratorListScreen> createState() => _ModeratorListScreenState();
}

class _ModeratorListScreenState extends State<ModeratorListScreen> {
  final AppwriteService _appwrite = AppwriteService();
  List<ModeratorProfile> _moderators = [];
  ModeratorProfile? _currentUserModerator;
  bool _isLoading = true;
  String? _currentUserId;
  DebateCategory _selectedCategory = DebateCategory.any;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _appwrite.account.get();
      setState(() {
        _currentUserId = user.$id;
      });
      await _loadModerators();
      await _checkCurrentUserModerator();
    } catch (e) {
      AppLogger().debug('Error loading current user: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadModerators() async {
    try {
      setState(() => _isLoading = true);

      final response = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.moderatorsCollection,
        queries: [
          Query.equal('isAvailable', true),
          Query.orderDesc('rating'),
          Query.limit(50),
        ],
      );

      final moderators = response.documents
          .map((doc) => ModeratorProfile.fromJson(doc.data))
          .toList();

      // Remove duplicates based on userId
      final uniqueModerators = <String, ModeratorProfile>{};
      for (final moderator in moderators) {
        uniqueModerators[moderator.userId] = moderator;
      }
      final deduplicatedModerators = uniqueModerators.values.toList();

      // Filter by category if not "Any"
      var filteredModerators = _selectedCategory == DebateCategory.any
          ? deduplicatedModerators
          : deduplicatedModerators.where((mod) => mod.categories.contains(_selectedCategory)).toList();

      // If we're in arena context, filter out users already in the arena
      if (widget.arenaRoomId != null) {
        final arenaParticipants = await _getArenaParticipants(widget.arenaRoomId!);
        final participantUserIds = arenaParticipants.map((p) => p['userId']).toSet();
        
        filteredModerators = filteredModerators
            .where((mod) => !participantUserIds.contains(mod.userId))
            .toList();
      }

      setState(() {
        _moderators = filteredModerators;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger().debug('Error loading moderators: $e');
      setState(() {
        _moderators = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _checkCurrentUserModerator() async {
    if (_currentUserId == null) return;

    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.moderatorsCollection,
        queries: [
          Query.equal('userId', _currentUserId!),
        ],
      );

      if (response.documents.isNotEmpty) {
        setState(() {
          _currentUserModerator = ModeratorProfile.fromJson(response.documents.first.data);
        });
      }
    } catch (e) {
      AppLogger().debug('Error checking current user moderator: $e');
    }
  }

  void _registerAsModerator() async {
    if (_currentUserModerator != null) {
      // User already has a profile, go directly to edit
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ModeratorRegistrationScreen(
            currentUserId: _currentUserId!,
            existingProfile: _currentUserModerator,
          ),
        ),
      );
      
      if (result == true) {
        _checkCurrentUserModerator();
        _loadModerators();
      }
    } else {
      // New user, show agreement screen first
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ModeratorAgreementScreen(
            currentUserId: _currentUserId!,
          ),
        ),
      );
      
      if (result == true) {
        _checkCurrentUserModerator();
        _loadModerators();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text(
          'Moderators',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Category filter
          _buildCategoryFilter(),
          
          // Current user status
          if (_currentUserModerator != null) _buildCurrentUserCard(),
          
          // Moderators list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8B5CF6),
                    ),
                  )
                : _moderators.isEmpty
                    ? _buildEmptyState()
                    : _buildModeratorsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "moderator_register",
        onPressed: _registerAsModerator,
        backgroundColor: const Color(0xFF8B5CF6),
        icon: Icon(
          _currentUserModerator != null ? Icons.edit : Icons.add,
          color: Colors.white,
        ),
        label: Text(
          _currentUserModerator != null ? 'Edit Profile' : 'Become Moderator',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by Category',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
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
                      _loadModerators();
                    },
                    selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    checkmarkColor: const Color(0xFF8B5CF6),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF8B5CF6) : Colors.white70,
                      fontSize: 12,
                    ),
                    backgroundColor: const Color(0xFF1A1A1A),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF8B5CF6) : Colors.white30,
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

  Widget _buildCurrentUserCard() {
    final profile = _currentUserModerator!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B5CF6), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.gavel,
            color: Color(0xFF8B5CF6),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You are a Moderator',
                  style: TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rating: ${profile.rating.toStringAsFixed(1)} ⭐ • ${profile.totalModerated} debates moderated',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.gavel,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No moderators found',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCategory == DebateCategory.any
                ? 'Be the first to become a moderator!'
                : 'No moderators for ${_selectedCategory.displayName}',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModeratorsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _moderators.length,
      itemBuilder: (context, index) {
        final moderator = _moderators[index];
        return _buildModeratorCard(moderator);
      },
    );
  }

  Widget _buildModeratorCard(ModeratorProfile moderator) {
    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF8B5CF6),
                  backgroundImage: moderator.avatar != null 
                      ? NetworkImage(moderator.avatar!) 
                      : null,
                  child: moderator.avatar == null
                      ? Text(
                          moderator.displayName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moderator.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '@${moderator.username}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          moderator.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${moderator.totalModerated} debates',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            if (moderator.bio?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                moderator.bio!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Categories
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: moderator.categories.map((category) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    category.displayName,
                    style: const TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
            
            // Show ping button if we're in arena context
            if (widget.arenaRoomId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _pingModerator(moderator),
                  icon: const Icon(Icons.notifications_active, size: 18),
                  label: const Text('Invite to Arena'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _pingModerator(ModeratorProfile moderator) async {
    try {
      final currentUser = await _appwrite.account.get();
      
      final pingId = await _appwrite.createPingRequest(
        fromUserId: currentUser.$id,
        fromUsername: currentUser.name,
        toUserId: moderator.userId,
        toUsername: moderator.username,
        roleType: 'moderator',
        debateTitle: widget.debateTitle ?? 'Arena Debate',
        debateDescription: widget.debateDescription ?? '',
        category: widget.category ?? 'general',
        arenaRoomId: widget.arenaRoomId!,
        message: 'You are invited to moderate this arena debate.',
      );

      if (pingId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent to ${moderator.displayName}!'),
            backgroundColor: const Color(0xFF8B5CF6),
          ),
        );
        // Go back to arena
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send invitation. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      AppLogger().debug('Error pinging moderator: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getArenaParticipants(String roomId) async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.arenaParticipantsCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('isActive', true),
        ],
      );
      return response.documents.map((doc) => doc.data).toList();
    } catch (e) {
      AppLogger().debug('Error loading arena participants: $e');
      return [];
    }
  }

}