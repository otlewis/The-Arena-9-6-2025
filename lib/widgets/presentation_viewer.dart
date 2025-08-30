import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import '../models/debate_source.dart';
import '../services/livekit_material_sync_service.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import '../constants/appwrite.dart';
import 'package:appwrite/appwrite.dart' as appwrite;
import 'dart:async';

class PresentationViewer extends StatefulWidget {
  final SlideData slideData;
  final LiveKitMaterialSyncService syncService;
  final AppwriteService appwriteService;
  final bool isPresenter;

  const PresentationViewer({
    super.key,
    required this.slideData,
    required this.syncService,
    required this.appwriteService,
    this.isPresenter = false,
  });

  @override
  State<PresentationViewer> createState() => _PresentationViewerState();
}

class _PresentationViewerState extends State<PresentationViewer> {
  static final _logger = AppLogger();
  
  PdfController? _pdfController;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Presentation state
  int _currentPage = 1;
  int _totalPages = 0;
  String _presenterName = '';
  
  StreamSubscription<SlideData>? _slideSubscription;

  @override
  void initState() {
    super.initState();
    _logger.info('📊 PresentationViewer initState called');
    _logger.info('📊 Initial slideData: fileId="${widget.slideData.fileId}", fileName="${widget.slideData.fileName}", pdfUrl="${widget.slideData.pdfUrl}"');
    _logger.info('📊 Initial slideData: currentSlide=${widget.slideData.currentSlide}, totalSlides=${widget.slideData.totalSlides}');
    _logger.info('📊 Initial slideData: uploadedBy="${widget.slideData.uploadedBy}", uploadedByName="${widget.slideData.uploadedByName}"');
    
    _currentPage = widget.slideData.currentSlide;
    _totalPages = widget.slideData.totalSlides;
    _presenterName = widget.slideData.uploadedByName ?? 'Presenter';
    
    _logger.info('📊 Initialized state: currentPage=$_currentPage, totalPages=$_totalPages, presenterName="$_presenterName"');
    _logger.info('📊 isPresenter: ${widget.isPresenter}');
    
    // Enable landscape orientation for presentation mode
    _enableLandscapeMode();
    
    _loadPresentationPdf();
    _setupSlideSync();
  }

  void _setupSlideSync() {
    // Listen for slide changes from the presenter
    _slideSubscription = widget.syncService.slideChanges.listen((slideData) {
      if (mounted && !widget.isPresenter) {
        // Only sync if we're not the presenter (view-only mode)
        if (slideData.fileId == widget.slideData.fileId) {
          _logger.info('📊 Syncing to slide ${slideData.currentSlide} from presenter');
          
          // Jump to the presenter's current slide
          if (_pdfController != null) {
            try {
              _pdfController!.jumpToPage(slideData.currentSlide - 1);
              _logger.info('📊 Successfully synced to slide ${slideData.currentSlide}');
            } catch (e) {
              _logger.warning('📊 Failed to sync to slide: $e');
            }
          }
          
          setState(() {
            _currentPage = slideData.currentSlide;
            _totalPages = slideData.totalSlides;
          });
        }
      }
    });
  }

  Future<void> _loadPresentationPdf() async {
    if (widget.slideData.pdfUrl == null) {
      setState(() {
        _errorMessage = 'No PDF URL available';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      _logger.info('📊 Loading presentation PDF: ${widget.slideData.fileName}');
      
      final pdfData = await _fetchPdfData(widget.slideData.pdfUrl ?? '');
      _logger.info('📊 PDF data fetched successfully, size: ${pdfData.length} bytes');
      
      _logger.info('📊 Creating PdfController...');
      _pdfController = PdfController(
        document: PdfDocument.openData(pdfData),
      );
      _logger.info('📊 PdfController created successfully');
      
      // Safely get document info
      _logger.info('📊 Accessing PDF document...');
      final document = await _pdfController?.document;
      _logger.info('📊 Document access result: ${document != null ? "success" : "null"}');
      
      if (document == null) {
        _logger.error('📊 Document is null, throwing exception');
        throw Exception('Failed to load PDF document');
      }
      
      _logger.info('📊 Getting page count...');
      final pageCount = document.pagesCount;
      _logger.info('📊 Page count: $pageCount');
      
      setState(() {
        _totalPages = pageCount;
        _isLoading = false;
      });
      _logger.info('📊 State updated with totalPages: $_totalPages');
      
      // Jump to current slide
      if (_currentPage > 0 && _currentPage <= _totalPages && _pdfController != null) {
        _logger.info('📊 Jumping to page: ${_currentPage - 1}');
        try {
          _pdfController!.jumpToPage(_currentPage - 1);
          _logger.info('📊 Successfully jumped to page: ${_currentPage - 1}');
        } catch (e) {
          _logger.warning('📊 Failed to jump to page: $e');
          // Don't treat this as fatal - the PDF can still be viewed
        }
      }
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load presentation: $e';
        _isLoading = false;
      });
      _logger.error('Error loading presentation PDF: $e');
    }
  }

  Future<Uint8List> _fetchPdfData(String url) async {
    try {
      _logger.info('📊 _fetchPdfData called with url: "$url"');
      _logger.info('📊 widget.appwriteService: ${widget.appwriteService}');
      _logger.info('📊 widget.appwriteService.client: ${widget.appwriteService.client}');
      
      final storage = appwrite.Storage(widget.appwriteService.client);
      _logger.info('📊 Storage client created successfully');
      
      String fileId = '';
      
      _logger.info('📊 URL provided: "$url"');
      _logger.info('📊 SlideData fileId: "${widget.slideData.fileId}"');
      _logger.info('📊 SlideData pdfUrl: "${widget.slideData.pdfUrl}"');
      _logger.info('📊 SlideData fileName: "${widget.slideData.fileName}"');
      _logger.info('📊 SlideData totalSlides: ${widget.slideData.totalSlides}');
      
      // If url is provided, extract fileId from it, otherwise use widget.slideData.fileId
      if (url.isNotEmpty) {
        _logger.info('📊 URL is not empty, processing...');
        // If url looks like a fileId (no slashes), use it directly
        if (url.contains('/')) {
          // Extract fileId from Appwrite storage URL format
          // URL format: https://cloud.appwrite.io/v1/storage/buckets/debate_slides/files/{fileId}/view?project=...
          final urlParts = url.split('/');
          for (int i = 0; i < urlParts.length; i++) {
            if (urlParts[i] == 'files' && i + 1 < urlParts.length) {
              fileId = urlParts[i + 1];
              break;
            }
          }
          // If we couldn't find 'files' segment, fallback to using slideData.fileId
          if (fileId.isEmpty) {
            fileId = widget.slideData.fileId;
          }
          _logger.info('📊 URL contains slash, extracted fileId: "$fileId"');
        } else {
          fileId = url; // url is actually just the fileId
          _logger.info('📊 URL is direct fileId: "$fileId"');
        }
      } else {
        fileId = widget.slideData.fileId;
        _logger.info('📊 URL empty, using slideData fileId: "$fileId"');
      }
      
      if (fileId.isEmpty) {
        _logger.error('📊 FileId is empty, throwing exception');
        throw Exception('No file ID available for PDF');
      }
      
      _logger.info('📊 Using fileId for PDF fetch: $fileId');
      
      // Try debate_slides bucket first, then profile_images as fallback
      try {
        _logger.info('📊 Attempting to fetch from debate_slides bucket...');
        final bytes = await storage.getFileDownload(
          bucketId: AppwriteConstants.debateSlidesBucket,
          fileId: fileId,
        );
        _logger.info('📊 Successfully fetched ${bytes.length} bytes from debate_slides bucket');
        return bytes;
      } catch (e) {
        _logger.warning('Failed to fetch from debate_slides bucket, trying profile_images: $e');
        try {
          final bytes = await storage.getFileDownload(
            bucketId: AppwriteConstants.profileImagesBucket,
            fileId: fileId,
          );
          _logger.info('📊 Successfully fetched ${bytes.length} bytes from profile_images bucket as fallback');
          return bytes;
        } catch (fallbackError) {
          _logger.error('Failed to fetch from both buckets. Original error: $e, Fallback error: $fallbackError');
          throw Exception('Unable to fetch PDF file from any storage bucket');
        }
      }
    } catch (e) {
      _logger.error('Error fetching PDF data: $e');
      rethrow;
    }
  }

  /// Enable landscape orientation for presentation mode
  void _enableLandscapeMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _logger.info('📊 Enabled landscape orientation for presentation mode');
  }

  /// Restore portrait-only orientation for the rest of the app
  void _restorePortraitMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _logger.info('📊 Restored portrait-only orientation');
  }

  @override
  void dispose() {
    _slideSubscription?.cancel();
    _pdfController?.dispose();
    
    // Restore portrait-only orientation when exiting presentation
    _restorePortraitMode();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _logger.info('📊 PresentationViewer build method called');
    _logger.info('📊 Build state: _isLoading=$_isLoading, _errorMessage=$_errorMessage, _pdfController=${_pdfController != null ? "not null" : "null"}');
    
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    _logger.info('📊 Current orientation: ${isLandscape ? "landscape" : "portrait"}');
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isLandscape ? null : AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.slideData.fileName,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Presented by $_presenterName',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isPresenter ? Colors.green : Colors.blue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              widget.isPresenter ? 'PRESENTING' : 'VIEW ONLY',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // Presentation area
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: _buildPresentationContent(),
          ),
        ),
        
        // Bottom controls
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[900],
          child: widget.isPresenter 
              ? _buildPresenterControls()
              : _buildViewerControls(),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Stack(
      children: [
        // Full-screen presentation
        Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: _buildPresentationContent(),
        ),
        
        // Floating close button (top-left)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.6),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ),
        
        // Floating presenter info (top-right) - only for presenters  
        if (widget.isPresenter)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'PRESENTING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _presenterName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // Left navigation button - only for presenters
        if (widget.isPresenter)
          Positioned(
            left: 8,
            top: MediaQuery.of(context).size.height / 2 - 30,
            child: _buildSideNavigationButton(
              icon: Icons.skip_previous,
              onPressed: _currentPage > 1 ? _previousSlide : null,
              enabled: _currentPage > 1,
            ),
          ),
          
        // Right navigation button - only for presenters  
        if (widget.isPresenter)
          Positioned(
            right: 8,
            top: MediaQuery.of(context).size.height / 2 - 30,
            child: _buildSideNavigationButton(
              icon: Icons.skip_next,
              onPressed: _currentPage < _totalPages ? _nextSlide : null,
              enabled: _currentPage < _totalPages,
            ),
          ),
          
        // Slide counter (bottom center, smaller) - only for presenters
        if (widget.isPresenter)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        
        // Viewer status in top-right (smaller and less intrusive)
        if (!widget.isPresenter)
          Positioned(
            top: MediaQuery.of(context).padding.top + 50, // Below the close button
            right: 8,
            child: SafeArea(
              child: _buildLandscapeViewerStatus(),
            ),
          ),
      ],
    );
  }

  Widget _buildPresentationContent() {
    try {
      _logger.info('📊 _buildPresentationContent called');
      _logger.info('📊 State check: _isLoading=$_isLoading, _errorMessage=$_errorMessage, _pdfController=${_pdfController != null ? "not null" : "null"}');
      
      if (_isLoading) {
        _logger.info('📊 Returning loading widget');
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Loading presentation...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      }
      
      if (_errorMessage != null) {
        _logger.info('📊 Returning error widget: $_errorMessage');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
      
      if (_pdfController == null) {
        _logger.info('📊 Returning no presentation widget');
        return const Center(
          child: Text(
            'No presentation available',
            style: TextStyle(color: Colors.white),
          ),
        );
      }
      
      _logger.info('📊 Attempting to create PdfView widget');
      _logger.info('📊 _pdfController is not null, creating presentation view');
      _logger.info('📊 widget.isPresenter: ${widget.isPresenter}');
      
      return Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: PdfView(
              controller: _pdfController!,
              scrollDirection: Axis.horizontal,
              onPageChanged: widget.isPresenter ? (page) {
                _logger.info('📊 Page changed to: $page');
                try {
                  // Update current page when presenter swipes
                  final newPage = page + 1; // Convert 0-based to 1-based
                  _updateSlidePosition(newPage);
                } catch (e) {
                  _logger.error('📊 Error in onPageChanged: $e');
                }
              } : null,
              physics: widget.isPresenter 
                  ? const PageScrollPhysics() 
                  : const NeverScrollableScrollPhysics(),
            ),
          ),
        ),
      );
    } catch (e, stackTrace) {
      _logger.error('📊 CRITICAL ERROR in _buildPresentationContent: $e');
      _logger.error('📊 Stack trace: $stackTrace');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Critical error in presentation: $e',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSideNavigationButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool enabled,
  }) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: enabled ? 0.7 : 0.3),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: enabled ? 0.3 : 0.1),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Colors.white.withValues(alpha: enabled ? 1.0 : 0.3),
          size: 28,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildLandscapePresenterControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[600]!, width: 1),
      ),
      child: Row(
        children: [
          // Previous slide button
          IconButton(
            onPressed: _currentPage > 1 ? _previousSlide : null,
            icon: const Icon(Icons.skip_previous, size: 24, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: _currentPage > 1 ? Colors.grey[700] : Colors.grey[800],
              padding: const EdgeInsets.all(12),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Slide counter
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Slide $_currentPage of $_totalPages',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Next slide button
          IconButton(
            onPressed: _currentPage < _totalPages ? _nextSlide : null,
            icon: const Icon(Icons.skip_next, size: 24, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: _currentPage < _totalPages ? Colors.grey[700] : Colors.grey[800],
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeViewerStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[400]!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility,
            color: Colors.blue[400],
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            '$_currentPage/$_totalPages',
            style: TextStyle(
              color: Colors.blue[400],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPresenterControls() {
    return Row(
      children: [
        // Previous slide button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _currentPage > 1 ? _previousSlide : null,
            icon: const Icon(Icons.navigate_before, size: 20),
            label: const Text('Previous'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Slide counter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Slide $_currentPage',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'of $_totalPages',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Next slide button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _currentPage < _totalPages ? _nextSlide : null,
            icon: const Icon(Icons.navigate_next, size: 20),
            label: const Text('Next'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewerControls() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.visibility,
                color: Colors.blue[400],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Following $_presenterName\'s presentation',
                style: TextStyle(
                  color: Colors.blue[400],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Slide $_currentPage of $_totalPages',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'View-only mode • Slides sync automatically',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _previousSlide() {
    if (_currentPage > 1 && _pdfController != null) {
      final newPage = _currentPage - 1;
      try {
        _pdfController!.jumpToPage(newPage - 1);
        _updateSlidePosition(newPage);
      } catch (e) {
        _logger.warning('📊 Failed to go to previous slide: $e');
      }
    }
  }

  void _nextSlide() {
    if (_currentPage < _totalPages && _pdfController != null) {
      final newPage = _currentPage + 1;
      try {
        _pdfController!.jumpToPage(newPage - 1);
        _updateSlidePosition(newPage);
      } catch (e) {
        _logger.warning('📊 Failed to go to next slide: $e');
      }
    }
  }

  void _updateSlidePosition(int newPage) {
    try {
      _logger.info('📊 _updateSlidePosition called with newPage: $newPage');
      _logger.info('📊 widget.slideData: ${widget.slideData}');
      _logger.info('📊 widget.slideData.fileId: ${widget.slideData.fileId}');
      _logger.info('📊 widget.slideData.fileName: ${widget.slideData.fileName}');
      _logger.info('📊 widget.slideData.pdfUrl: ${widget.slideData.pdfUrl}');
      _logger.info('📊 widget.slideData.uploadedBy: ${widget.slideData.uploadedBy}');
      _logger.info('📊 widget.slideData.uploadedByName: ${widget.slideData.uploadedByName}');
      _logger.info('📊 widget.slideData.uploadedAt: ${widget.slideData.uploadedAt}');
      _logger.info('📊 _totalPages: $_totalPages');
      
      setState(() {
        _currentPage = newPage;
      });
      _logger.info('📊 setState completed successfully');

      // Sync with other participants
      if (widget.isPresenter) {
        _logger.info('📊 Creating updated slide data for presenter sync');
        final updatedSlideData = SlideData(
          fileId: widget.slideData.fileId,
          fileName: widget.slideData.fileName,
          pdfUrl: widget.slideData.pdfUrl,
          uploadedBy: widget.slideData.uploadedBy,
          uploadedByName: widget.slideData.uploadedByName,
          uploadedAt: widget.slideData.uploadedAt,
          currentSlide: newPage,
          totalSlides: _totalPages,
        );
        _logger.info('📊 SlideData created successfully');

        _logger.info('📊 Presenter updating slide position to $newPage');
        widget.syncService.shareSlideChange(updatedSlideData);
        _logger.info('📊 shareSlideChange completed successfully');
      }
    } catch (e, stackTrace) {
      _logger.error('📊 CRITICAL ERROR in _updateSlidePosition: $e');
      _logger.error('📊 Stack trace: $stackTrace');
    }
  }
}