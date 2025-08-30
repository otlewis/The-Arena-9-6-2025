import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:appwrite/appwrite.dart' as appwrite;
import '../../services/livekit_material_sync_service.dart';
import '../../services/appwrite_service.dart';
import '../../services/slide_library_service.dart';
import '../../models/debate_source.dart';
import '../../core/logging/app_logger.dart';
import '../../constants/appwrite.dart';
import '../presentation_viewer.dart';

class SlidesTab extends StatefulWidget {
  final String roomId;
  final String userId;
  final bool isHost;
  final LiveKitMaterialSyncService syncService;
  final AppwriteService appwriteService;
  final SlideData? currentSlideData;
  
  const SlidesTab({
    super.key,
    required this.roomId,
    required this.userId,
    required this.isHost,
    required this.syncService,
    required this.appwriteService,
    this.currentSlideData,
  });

  @override
  State<SlidesTab> createState() => _SlidesTabState();
}

class _SlidesTabState extends State<SlidesTab> with AutomaticKeepAliveClientMixin {
  static final _logger = AppLogger();
  final SlideLibraryService _slideLibraryService = SlideLibraryService();
  
  PdfController? _pdfController;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isUploading = false;
  
  // Slide navigation
  int _currentPage = 1;
  int _totalPages = 0;
  
  // Slide library
  List<UserSlideLibrary> _userSlides = [];
  bool _loadingUserSlides = false;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _initializePdf();
    _listenToSlideChanges();
    _loadPersistedSlideData();
    _loadUserSlides();
  }
  
  void _listenToSlideChanges() {
    widget.syncService.slideChanges.listen((slideData) {
      if (mounted && _pdfController != null && slideData.currentSlide != _currentPage) {
        _pdfController!.jumpToPage(slideData.currentSlide - 1);
        setState(() {
          _currentPage = slideData.currentSlide;
        });
      }
    });
  }
  
  Future<void> _initializePdf() async {
    if (widget.currentSlideData != null && widget.currentSlideData!.pdfUrl != null) {
      await _loadPdfFromUrl(widget.currentSlideData!.pdfUrl!);
    }
  }

  Future<void> _loadPersistedSlideData() async {
    try {
      final persistedData = await widget.syncService.loadPersistedSlideData();
      if (persistedData != null && persistedData.pdfUrl != null && mounted) {
        await _loadPdfFromUrl(persistedData.pdfUrl!);
        setState(() {
          _currentPage = persistedData.currentSlide;
          _totalPages = persistedData.totalSlides;
        });
      }
    } catch (e) {
      _logger.warning('Failed to load persisted slide data: $e');
    }
  }

  Future<void> _loadUserSlides() async {
    if (!widget.isHost) return; // Only hosts can see slide library
    
    setState(() => _loadingUserSlides = true);
    
    try {
      final slides = await _slideLibraryService.getUserSlides();
      if (mounted) {
        setState(() {
          _userSlides = slides;
          _loadingUserSlides = false;
        });
      }
    } catch (e) {
      _logger.warning('Failed to load user slides: $e');
      if (mounted) {
        setState(() => _loadingUserSlides = false);
      }
    }
  }
  
  Future<void> _loadPdfFromUrl(String url) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      _pdfController = PdfController(
        document: PdfDocument.openData(
          await _fetchPdfData(url),
        ),
      );
      
      final document = await _pdfController!.document;
      setState(() {
        _totalPages = document.pagesCount;
        _currentPage = 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load PDF: $e';
        _isLoading = false;
      });
      _logger.error('Error loading PDF: $e');
    }
  }
  
  Future<Uint8List> _fetchPdfData(String url) async {
    try {
      final storage = appwrite.Storage(widget.appwriteService.client);
      final fileId = url.split('/').last;
      
      // Try debate_slides bucket first, then profile_images as fallback
      try {
        final bytes = await storage.getFileDownload(
          bucketId: AppwriteConstants.debateSlidesBucket,
          fileId: fileId,
        );
        return bytes;
      } catch (e) {
        _logger.warning('Failed to fetch from debate_slides bucket, trying profile_images: $e');
        final bytes = await storage.getFileDownload(
          bucketId: AppwriteConstants.profileImagesBucket,
          fileId: fileId,
        );
        return bytes;
      }
    } catch (e) {
      _logger.error('Error fetching PDF data: $e');
      rethrow;
    }
  }
  
  Future<void> _selectFromLibrary() async {
    if (!widget.isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only hosts can select slides')),
      );
      return;
    }

    if (_userSlides.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No slides in your library. Add slides from the home screen first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Show slide selection bottom sheet
    final selectedSlide = await showModalBottomSheet<UserSlideLibrary>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SlideSelectionSheet(slides: _userSlides),
    );

    if (selectedSlide == null) return;

    try {
      setState(() => _isUploading = true);

      // Load PDF from Appwrite storage using the selected slide's fileId
      final pdfUrl = selectedSlide.fileId; // Use fileId as URL
      await _loadPdfFromFileId(selectedSlide.fileId, selectedSlide.fileName, selectedSlide.totalSlides);

      // Notify other participants via LiveKit
      await widget.syncService.uploadPdf(
        selectedSlide.fileId,
        selectedSlide.fileName,
        selectedSlide.totalSlides,
        selectedSlide.fileId,
      );

      // Mark as recently used
      await _slideLibraryService.shareSlideInRoom(selectedSlide.id, widget.roomId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully loaded: ${selectedSlide.title}')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'Failed to load slides: $e';
      });
      _logger.error('Error loading slides from library: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load slides: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Try Again',
              textColor: Colors.white,
              onPressed: _selectFromLibrary,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadPdfFromFileId(String fileId, String fileName, int totalSlides) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final pdfData = await _fetchPdfDataByFileId(fileId);
      
      _pdfController = PdfController(
        document: PdfDocument.openData(pdfData),
      );
      
      final document = await _pdfController!.document;
      setState(() {
        _totalPages = document.pagesCount;
        _currentPage = 1;
        _isLoading = false;
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load PDF: $e';
        _isLoading = false;
        _isUploading = false;
      });
      _logger.error('Error loading PDF from fileId: $e');
    }
  }

  Future<Uint8List> _fetchPdfDataByFileId(String fileId) async {
    try {
      final storage = appwrite.Storage(widget.appwriteService.client);
      
      // Try debate_slides bucket first, then profile_images as fallback
      try {
        final bytes = await storage.getFileDownload(
          bucketId: AppwriteConstants.debateSlidesBucket,
          fileId: fileId,
        );
        return bytes;
      } catch (e) {
        _logger.warning('Failed to fetch from debate_slides bucket, trying profile_images: $e');
        final bytes = await storage.getFileDownload(
          bucketId: AppwriteConstants.profileImagesBucket,
          fileId: fileId,
        );
        return bytes;
      }
    } catch (e) {
      _logger.error('Error fetching PDF data by fileId: $e');
      rethrow;
    }
  }
  
  void _previousSlide() {
    if (_currentPage > 1) {
      _changeSlide(_currentPage - 1);
    }
  }
  
  void _nextSlide() {
    if (_currentPage < _totalPages) {
      _changeSlide(_currentPage + 1);
    }
  }
  
  void _changeSlide(int page) {
    if (!widget.isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only hosts can control slides')),
      );
      return;
    }
    
    HapticFeedback.lightImpact();
    _pdfController?.jumpToPage(page - 1);
    setState(() {
      _currentPage = page;
    });
    widget.syncService.changeSlide(page);
  }
  
  void _openFullscreen() {
    if (_pdfController == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullscreenPdfViewer(
          controller: _pdfController!,
          currentPage: _currentPage,
          totalPages: _totalPages,
          isHost: widget.isHost,
          onPageChanged: (page) {
            if (widget.isHost) {
              widget.syncService.changeSlide(page);
            }
          },
        ),
      ),
    );
  }

  void _openPresentationMode() async {
    if (_pdfController == null) return;
    
    try {
      // Get current slide data from the sync service
      final persistedSlideData = await widget.syncService.loadPersistedSlideData();
      
      if (persistedSlideData != null) {
        // Use persisted data with current page
        final slideData = SlideData(
          fileId: persistedSlideData.fileId,
          fileName: persistedSlideData.fileName,
          currentSlide: _currentPage,
          totalSlides: _totalPages > 0 ? _totalPages : persistedSlideData.totalSlides,
          pdfUrl: persistedSlideData.pdfUrl,
          uploadedBy: persistedSlideData.uploadedBy,
          uploadedByName: persistedSlideData.uploadedByName,
          uploadedAt: persistedSlideData.uploadedAt,
        );
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PresentationViewer(
                slideData: slideData,
                syncService: widget.syncService,
                appwriteService: widget.appwriteService,
                isPresenter: widget.isHost,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open presentation mode')),
          );
        }
      }
    } catch (e) {
      _logger.error('Error opening presentation mode: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening presentation mode')),
        );
      }
    }
  }

  Future<void> _removeSlides() async {
    if (!widget.isHost) return;

    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Slides'),
          content: const Text('Are you sure you want to remove the current slides? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        // Clear local state
        setState(() {
          _pdfController?.dispose();
          _pdfController = null;
          _currentPage = 1;
          _totalPages = 0;
          _isLoading = false;
          _errorMessage = null;
        });

        // Clear persisted data
        await widget.syncService.clearPersistedSlideData();

        // TODO: Notify other participants via LiveKit when slides are removed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Slides removed successfully')),
          );
        }
      } catch (e) {
        _logger.error('Error removing slides: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove slides: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_isUploading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading slides from library...'),
          ],
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            if (widget.isHost)
              ElevatedButton.icon(
                onPressed: _selectFromLibrary,
                icon: const Icon(Icons.library_books),
                label: const Text('Select from Library'),
              ),
          ],
        ),
      );
    }
    
    if (_pdfController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 48,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No slides uploaded',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              widget.isHost 
                ? 'Select slides from your library'
                : 'Waiting for host to select slides',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (widget.isHost) ...[
              ElevatedButton.icon(
                onPressed: _selectFromLibrary,
                icon: const Icon(Icons.library_books),
                label: const Text('Select from Library'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _removeSlides,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove Slides'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ],
        ),
      );
    }
    
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              PdfView(
                controller: _pdfController!,
                scrollDirection: Axis.horizontal,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page + 1;
                  });
                  if (widget.isHost) {
                    widget.syncService.changeSlide(page + 1);
                  }
                },
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isHost)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _removeSlides,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.8),
                          foregroundColor: Colors.white,
                        ),
                        tooltip: 'Remove Slides',
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.present_to_all),
                      onPressed: _openPresentationMode,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.withValues(alpha: 0.8),
                        foregroundColor: Colors.white,
                      ),
                      tooltip: 'Present Slides',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.fullscreen),
                      onPressed: _openFullscreen,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                      tooltip: 'Fullscreen',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _currentPage > 1 ? _previousSlide : null,
                icon: const Icon(Icons.chevron_left),
                iconSize: 32,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Slide $_currentPage of $_totalPages',
                    style: theme.textTheme.titleMedium,
                  ),
                  if (!widget.isHost)
                    Text(
                      'Host controls slides',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
              IconButton(
                onPressed: _currentPage < _totalPages ? _nextSlide : null,
                icon: const Icon(Icons.chevron_right),
                iconSize: 32,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullscreenPdfViewer extends StatelessWidget {
  final PdfController controller;
  final int currentPage;
  final int totalPages;
  final bool isHost;
  final Function(int) onPageChanged;
  
  const _FullscreenPdfViewer({
    required this.controller,
    required this.currentPage,
    required this.totalPages,
    required this.isHost,
    required this.onPageChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Slide $currentPage of $totalPages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: PdfView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        onPageChanged: (page) => onPageChanged(page + 1),
      ),
    );
  }
}

class _SlideSelectionSheet extends StatelessWidget {
  final List<UserSlideLibrary> slides;

  const _SlideSelectionSheet({required this.slides});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.library_books, color: Colors.deepPurple),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Select Slides from Library',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Slides list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: slides.length,
              itemBuilder: (context, index) {
                final slide = slides[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.deepPurple[100]!, Colors.deepPurple[50]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.slideshow,
                            color: Colors.deepPurple[400],
                            size: 24,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${slide.totalSlides}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.deepPurple[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    title: Text(
                      slide.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slide.fileName,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(slide.uploadedAt),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.deepPurple,
                    ),
                    onTap: () => Navigator.pop(context, slide),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${date.month}/${date.day}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else {
      return 'Just now';
    }
  }
}