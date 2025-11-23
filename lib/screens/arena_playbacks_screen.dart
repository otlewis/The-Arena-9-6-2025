import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import 'arena_playback_screen.dart';

class ArenaPlaybacksScreen extends ConsumerStatefulWidget {
  const ArenaPlaybacksScreen({super.key});

  @override
  ConsumerState<ArenaPlaybacksScreen> createState() => _ArenaPlaybacksScreenState();
}

class _ArenaPlaybacksScreenState extends ConsumerState<ArenaPlaybacksScreen>
    with SingleTickerProviderStateMixin {
  final AppwriteService _appwriteService = GetIt.instance<AppwriteService>();
  final ScrollController _allPlaybacksScrollController = ScrollController();
  final ScrollController _myPlaybacksScrollController = ScrollController();

  late TabController _tabController;
  List<Map<String, dynamic>> _allPlaybacks = [];
  List<Map<String, dynamic>> _myPlaybacks = [];
  bool _isLoading = true;
  bool _isLoadingMoreAll = false;
  bool _isLoadingMoreMy = false;
  bool _hasMoreAll = true;
  bool _hasMoreMy = true;
  bool _hasError = false;
  String? _errorMessage;
  String _searchQuery = '';

  // Pagination constants
  static const int _pageSize = 20;
  int _allPlaybacksOffset = 0;
  int _myPlaybacksOffset = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPlaybacks();
    _allPlaybacksScrollController.addListener(_onAllPlaybacksScroll);
    _myPlaybacksScrollController.addListener(_onMyPlaybacksScroll);
  }

  void _onAllPlaybacksScroll() {
    if (_allPlaybacksScrollController.position.pixels >=
        _allPlaybacksScrollController.position.maxScrollExtent - 200) {
      _loadMoreAllPlaybacks();
    }
  }

  void _onMyPlaybacksScroll() {
    if (_myPlaybacksScrollController.position.pixels >=
        _myPlaybacksScrollController.position.maxScrollExtent - 200) {
      _loadMoreMyPlaybacks();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _allPlaybacksScrollController.removeListener(_onAllPlaybacksScroll);
    _allPlaybacksScrollController.dispose();
    _myPlaybacksScrollController.removeListener(_onMyPlaybacksScroll);
    _myPlaybacksScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaybacks() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _allPlaybacksOffset = 0;
        _myPlaybacksOffset = 0;
        _hasMoreAll = true;
        _hasMoreMy = true;
      });

      final currentUser = await _appwriteService.getCurrentUser();
      final currentUserId = currentUser?.$id;

      final [allPlaybacks, myPlaybacks] = await Future.wait([
        _appwriteService.getAvailablePlaybacks(limit: _pageSize, offset: 0),
        if (currentUserId != null)
          _appwriteService.getAvailablePlaybacks(userId: currentUserId, limit: _pageSize, offset: 0)
        else
          Future.value(<Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;

      setState(() {
        _allPlaybacks = allPlaybacks;
        _myPlaybacks = myPlaybacks;
        _hasMoreAll = allPlaybacks.length == _pageSize;
        _hasMoreMy = myPlaybacks.length == _pageSize;
        _allPlaybacksOffset = _pageSize;
        _myPlaybacksOffset = _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger().error('Error loading playbacks: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreAllPlaybacks() async {
    if (_searchQuery.isNotEmpty || _isLoadingMoreAll || !_hasMoreAll) return;

    try {
      setState(() => _isLoadingMoreAll = true);

      final morePlaybacks = await _appwriteService.getAvailablePlaybacks(
        limit: _pageSize,
        offset: _allPlaybacksOffset,
      );

      if (!mounted) return;

      setState(() {
        _allPlaybacks.addAll(morePlaybacks);
        _hasMoreAll = morePlaybacks.length == _pageSize;
        _allPlaybacksOffset += _pageSize;
        _isLoadingMoreAll = false;
      });
    } catch (e) {
      AppLogger().error('Error loading more playbacks: $e');
      if (mounted) {
        setState(() => _isLoadingMoreAll = false);
      }
    }
  }

  Future<void> _loadMoreMyPlaybacks() async {
    if (_searchQuery.isNotEmpty || _isLoadingMoreMy || !_hasMoreMy) return;

    try {
      setState(() => _isLoadingMoreMy = true);

      final currentUser = await _appwriteService.getCurrentUser();
      if (currentUser == null) {
        setState(() => _isLoadingMoreMy = false);
        return;
      }

      final morePlaybacks = await _appwriteService.getAvailablePlaybacks(
        userId: currentUser.$id,
        limit: _pageSize,
        offset: _myPlaybacksOffset,
      );

      if (!mounted) return;

      setState(() {
        _myPlaybacks.addAll(morePlaybacks);
        _hasMoreMy = morePlaybacks.length == _pageSize;
        _myPlaybacksOffset += _pageSize;
        _isLoadingMoreMy = false;
      });
    } catch (e) {
      AppLogger().error('Error loading more my playbacks: $e');
      if (mounted) {
        setState(() => _isLoadingMoreMy = false);
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredPlaybacks(List<Map<String, dynamic>> playbacks) {
    if (_searchQuery.isEmpty) return playbacks;

    return playbacks.where((playback) {
      final title = (playback['title'] ?? '').toString().toLowerCase();
      final topic = (playback['topic'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      return title.contains(query) || topic.contains(query);
    }).toList();
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '0:00';

    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString()}:${secs.toString().padLeft(2, '0')}';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';

    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search playbacks...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(Icons.clear, color: Colors.grey),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildPlaybackCard(Map<String, dynamic> playback) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _openPlayback(playback),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      playback['title'] ?? 'Untitled Debate',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDuration(playback['duration']),
                      style: TextStyle(
                        color: Colors.deepPurple.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                playback['topic'] ?? '',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${playback['viewCount'] ?? 0} views',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(playback['recordedAt']),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  if (playback['winnerSide'] != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: playback['winnerSide'] == 'affirmative'
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${playback['winnerSide']}'.toUpperCase(),
                        style: TextStyle(
                          color: playback['winnerSide'] == 'affirmative'
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              if (playback['description'] != null && playback['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  playback['description'],
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybacksList(List<Map<String, dynamic>> playbacks, {required bool isAllTab}) {
    final filteredPlaybacks = _getFilteredPlaybacks(playbacks);
    final isLoadingMore = isAllTab ? _isLoadingMoreAll : _isLoadingMoreMy;
    final scrollController = isAllTab ? _allPlaybacksScrollController : _myPlaybacksScrollController;

    if (filteredPlaybacks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No playbacks found' : 'No playbacks available',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search terms',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPlaybacks,
      child: ListView.builder(
        controller: scrollController,
        itemCount: filteredPlaybacks.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredPlaybacks.length) {
            // Loading indicator at the bottom
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _buildPlaybackCard(filteredPlaybacks[index]);
        },
      ),
    );
  }

  void _openPlayback(Map<String, dynamic> playback) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ArenaPlaybackScreen(
          playbackId: playback['\$id'] ?? '',
          initialTitle: playback['title'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Arena Playbacks',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'All Playbacks'),
            Tab(text: 'My Playbacks'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading playbacks...'),
                ],
              ),
            )
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Error loading playbacks',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage ?? 'Unknown error',
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadPlaybacks,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildSearchBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPlaybacksList(_allPlaybacks, isAllTab: true),
                          _buildPlaybacksList(_myPlaybacks, isAllTab: false),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}