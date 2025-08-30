import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'slides_tab.dart';
import 'sources_tab.dart';
import '../../services/livekit_material_sync_service.dart';
import '../../services/appwrite_service.dart';
import '../../models/debate_source.dart';
import '../../constants/appwrite.dart';
import '../../core/logging/app_logger.dart';

class DebateBottomSheet extends StatefulWidget {
  final String roomId;
  final String userId;
  final bool isHost;
  final LiveKitMaterialSyncService syncService;
  final AppwriteService appwriteService;
  final VoidCallback? onClose;
  
  const DebateBottomSheet({
    super.key,
    required this.roomId,
    required this.userId,
    required this.isHost,
    required this.syncService,
    required this.appwriteService,
    this.onClose,
  });

  @override
  State<DebateBottomSheet> createState() => _DebateBottomSheetState();
}

class _DebateBottomSheetState extends State<DebateBottomSheet> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Sheet snap points - start higher to avoid overflow
  static const double _peekHeight = 0.6; // Increased for keyboard support
  static const double _halfHeight = 0.8;   
  static const double _fullHeight = 0.95;
  
  // Shared sources and slides
  final List<DebateSource> _sources = [];
  SlideData? _currentSlideData;
  static final _logger = AppLogger();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeSyncListeners();
    _loadExistingSources();
  }
  
  void _initializeSyncListeners() {
    widget.syncService.sourceAdded.listen((source) {
      if (mounted) {
        setState(() {
          _sources.add(source);
        });
      }
    });
    
    widget.syncService.slideChanges.listen((slideData) {
      if (mounted) {
        setState(() {
          _currentSlideData = slideData;
        });
      }
    });
  }
  
  Future<void> _loadExistingSources() async {
    _logger.info('📋 Loading existing sources for room: ${widget.roomId}');
    try {
      final documents = await widget.appwriteService.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.sharedSourcesCollection,
        queries: [
          Query.equal('roomId', widget.roomId),
          Query.orderDesc('\$createdAt'),
        ],
      );
      
      _logger.info('📋 Found ${documents.documents.length} sources in database');
      
      if (mounted) {
        setState(() {
          _sources.clear();
          for (final doc in documents.documents) {
            final source = DebateSource(
              id: doc.$id,
              url: doc.data['url'] ?? '',
              title: doc.data['title'] ?? 'Untitled',
              description: doc.data['description'],
              sharedAt: DateTime.parse(doc.data['sharedAt'] ?? DateTime.now().toIso8601String()),
              sharedBy: doc.data['sharedBy'] ?? '',
              sharedByName: doc.data['sharedByName'],
              isSecure: doc.data['url']?.toString().startsWith('https') ?? false,
              isPinned: doc.data['isPinned'] ?? false,
            );
            _sources.add(source);
            _logger.debug('📋 Loaded source: ${source.title} -> ${source.url}');
          }
        });
        _logger.info('📋 Sources list updated. Total sources: ${_sources.length}');
      }
    } catch (e) {
      _logger.error('❌ Error loading sources: $e');
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          widget.onClose?.call();
        }
      },
      child: DraggableScrollableSheet(
      initialChildSize: _peekHeight,
      minChildSize: 0.4, // Minimum size to prevent overflow 
      maxChildSize: _fullHeight,
      snapSizes: const [0.4, _peekHeight, _halfHeight, _fullHeight],
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1a1a2e) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDragHandle(),
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: ClipRect(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(), // Prevent tab scroll conflicts
                    children: [
                      SlidesTab(
                        roomId: widget.roomId,
                        userId: widget.userId,
                        isHost: widget.isHost,
                        syncService: widget.syncService,
                        appwriteService: widget.appwriteService,
                        currentSlideData: _currentSlideData,
                        onClose: _closeBottomSheet,
                      ),
                      SourcesTab(
                        roomId: widget.roomId,
                        userId: widget.userId,
                        sources: _sources,
                        syncService: widget.syncService,
                        appwriteService: widget.appwriteService,
                        onSourceAdded: _loadExistingSources,
                        isHost: widget.isHost,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      ),
    );
  }
  
  Widget _buildDragHandle() {
    return GestureDetector(
      onTap: () {
        // Add visual feedback when tapped
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💡 Drag me up or down to resize!'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12), // Reduced padding
        child: Center(
          child: Column(
            children: [
              Container(
                width: 50, // Wider handle
                height: 5,  // Thicker handle
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.6), // More visible
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '⬆️ Drag to expand ⬇️',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💡 Swipe up to expand the materials panel'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
        children: [
          Icon(
            Icons.present_to_all,
            color: theme.primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Debate Materials',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_currentSlideData != null)
                  Text(
                    'Slide ${_currentSlideData!.currentSlide}/${_currentSlideData!.totalSlides}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          if (widget.syncService.isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sync,
                    size: 14,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SYNCED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _closeBottomSheet,
            icon: const Icon(Icons.close),
            tooltip: 'Close Materials',
          ),
        ],
        ),
      ),
    );
  }
  
  void _closeBottomSheet() {
    widget.onClose?.call();
  }
  
  Widget _buildTabBar() {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: theme.primaryColor,
        unselectedLabelColor: Colors.grey,
        indicatorColor: theme.primaryColor,
        indicatorWeight: 3,
        tabs: const [
          Tab(
            icon: Icon(Icons.slideshow, size: 18),
            text: 'Slides',
            height: 48,
          ),
          Tab(
            icon: Icon(Icons.link, size: 18),
            text: 'Sources',
            height: 48,
          ),
        ],
      ),
    );
  }
  
}