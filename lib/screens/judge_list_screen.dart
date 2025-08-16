import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../constants/appwrite.dart';
import '../models/moderator_judge.dart';
import 'judge_registration_screen.dart';
import 'judge_agreement_screen.dart';

class JudgeListScreen extends StatefulWidget {
  final String? arenaRoomId;
  final String? debateTitle;
  final String? debateDescription;
  final String? category;

  const JudgeListScreen({
    super.key,
    this.arenaRoomId,
    this.debateTitle,
    this.debateDescription,
    this.category,
  });

  @override
  State<JudgeListScreen> createState() => _JudgeListScreenState();
}

class _JudgeListScreenState extends State<JudgeListScreen> {
  final AppwriteService _appwrite = AppwriteService();
  List<JudgeProfile> _judges = [];
  JudgeProfile? _currentUserJudge;
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
      await _loadJudges();
      await _checkCurrentUserJudge();
    } catch (e) {
      debugPrint('Error loading current user: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadJudges() async {
    try {
      setState(() => _isLoading = true);

      final response = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.judgesCollection,
        queries: [
          Query.equal('isAvailable', true),
          Query.orderDesc('rating'),
          Query.limit(50),
        ],
      );

      final judges = response.documents
          .map((doc) => JudgeProfile.fromJson(doc.data))
          .toList();

      // Remove duplicates based on userId
      final uniqueJudges = <String, JudgeProfile>{};
      for (final judge in judges) {
        uniqueJudges[judge.userId] = judge;
      }
      final deduplicatedJudges = uniqueJudges.values.toList();

      // Filter by category if not "Any"
      var filteredJudges = _selectedCategory == DebateCategory.any
          ? deduplicatedJudges
          : deduplicatedJudges.where((judge) => judge.categories.contains(_selectedCategory)).toList();

      // If we're in arena context, filter out users already in the arena
      if (widget.arenaRoomId != null) {
        final arenaParticipants = await _getArenaParticipants(widget.arenaRoomId!);
        final participantUserIds = arenaParticipants.map((p) => p['userId']).toSet();
        
        filteredJudges = filteredJudges
            .where((judge) => !participantUserIds.contains(judge.userId))
            .toList();
      }

      setState(() {
        _judges = filteredJudges;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading judges: $e');
      setState(() {
        _judges = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _checkCurrentUserJudge() async {
    if (_currentUserId == null) return;

    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.judgesCollection,
        queries: [
          Query.equal('userId', _currentUserId!),
        ],
      );

      if (response.documents.isNotEmpty) {
        setState(() {
          _currentUserJudge = JudgeProfile.fromJson(response.documents.first.data);
        });
      }
    } catch (e) {
      debugPrint('Error checking current user judge: $e');
    }
  }

  void _registerAsJudge() async {
    if (_currentUserJudge != null) {
      // User already has a profile, go directly to edit
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => JudgeRegistrationScreen(
            currentUserId: _currentUserId!,
            existingProfile: _currentUserJudge,
          ),
        ),
      );
      
      if (result == true) {
        _checkCurrentUserJudge();
        _loadJudges();
      }
    } else {
      // New user, show agreement screen first
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => JudgeAgreementScreen(
            currentUserId: _currentUserId!,
          ),
        ),
      );
      
      if (result == true) {
        _checkCurrentUserJudge();
        _loadJudges();
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
          'Judges',
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
          if (_currentUserJudge != null) _buildCurrentUserCard(),
          
          // Judges list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8B5CF6),
                    ),
                  )
                : _judges.isEmpty
                    ? _buildEmptyState()
                    : _buildJudgesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _registerAsJudge,
        backgroundColor: const Color(0xFFFFC107),
        icon: Icon(
          _currentUserJudge != null ? Icons.edit : Icons.add,
          color: Colors.white,
        ),
        label: Text(
          _currentUserJudge != null ? 'Edit Profile' : 'Become Judge',
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
                      _loadJudges();
                    },
                    selectedColor: const Color(0xFFFFC107).withValues(alpha: 0.3),
                    checkmarkColor: const Color(0xFFFFC107),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFFFFC107) : Colors.white70,
                      fontSize: 12,
                    ),
                    backgroundColor: const Color(0xFF1A1A1A),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFFFFC107) : Colors.white30,
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
    final profile = _currentUserJudge!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC107), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.balance,
            color: Color(0xFFFFC107),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You are a Judge',
                  style: TextStyle(
                    color: Color(0xFFFFC107),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rating: ${profile.rating.toStringAsFixed(1)} ⭐ • ${profile.totalJudged} debates judged',
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
            Icons.balance,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No judges found',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCategory == DebateCategory.any
                ? 'Be the first to become a judge!'
                : 'No judges for ${_selectedCategory.displayName}',
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

  Widget _buildJudgesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _judges.length,
      itemBuilder: (context, index) {
        final judge = _judges[index];
        return _buildJudgeCard(judge);
      },
    );
  }

  Widget _buildJudgeCard(JudgeProfile judge) {
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
                  backgroundColor: const Color(0xFFFFC107),
                  backgroundImage: judge.avatar != null 
                      ? NetworkImage(judge.avatar!) 
                      : null,
                  child: judge.avatar == null
                      ? Text(
                          judge.displayName[0].toUpperCase(),
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
                        judge.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '@${judge.username}',
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
                          judge.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${judge.totalJudged} debates',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            if (judge.bio?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                judge.bio!,
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
              children: judge.categories.map((category) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    category.displayName,
                    style: const TextStyle(
                      color: Color(0xFFFFC107),
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
            
            // Certifications
            if (judge.certifications.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: judge.certifications.map((cert) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      cert,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            
            // Show ping button if we're in arena context
            if (widget.arenaRoomId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _pingJudge(judge),
                  icon: const Icon(Icons.notifications_active, size: 18),
                  label: const Text('Invite to Arena'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
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

  void _pingJudge(JudgeProfile judge) async {
    try {
      final currentUser = await _appwrite.account.get();
      
      final pingId = await _appwrite.createPingRequest(
        fromUserId: currentUser.$id,
        fromUsername: currentUser.name,
        toUserId: judge.userId,
        toUsername: judge.username,
        roleType: 'judge',
        debateTitle: widget.debateTitle ?? 'Arena Debate',
        debateDescription: widget.debateDescription ?? '',
        category: widget.category ?? 'general',
        arenaRoomId: widget.arenaRoomId!,
        message: 'You are invited to judge this arena debate.',
      );

      if (pingId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent to ${judge.displayName}!'),
            backgroundColor: const Color(0xFFFFC107),
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
      debugPrint('Error pinging judge: $e');
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
      debugPrint('Error loading arena participants: $e');
      return [];
    }
  }

}