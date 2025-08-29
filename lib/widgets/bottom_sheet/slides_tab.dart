import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:file_selector/file_selector.dart';
import 'package:appwrite/appwrite.dart' as appwrite;
import '../../services/livekit_material_sync_service.dart';
import '../../services/appwrite_service.dart';
import '../../models/debate_source.dart';
import '../../core/logging/app_logger.dart';
import '../../constants/appwrite.dart';

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
  
  PdfController? _pdfController;
  bool _isLoading = false;
  String? _errorMessage;
  double _uploadProgress = 0.0;
  bool _isUploading = false;
  
  // Slide navigation
  int _currentPage = 1;
  int _totalPages = 0;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _initializePdf();
    _listenToSlideChanges();
    _loadPersistedSlideData();
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
  
  Future<void> _uploadPdf() async {
    if (!widget.isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only hosts can upload slides')),
      );
      return;
    }
    
    try {
      // Try to open file with proper type groups
      XFile? file;
      try {
        file = await openFile(
          acceptedTypeGroups: [
            const XTypeGroup(
              label: 'PDF Documents',
              extensions: ['pdf'],
              mimeTypes: ['application/pdf'],
              uniformTypeIdentifiers: ['com.adobe.pdf'],
            ),
          ],
        );
      } catch (e) {
        // Fallback for platforms that don't support full type groups
        file = await openFile();
      }
      
      if (file == null) return;
      
      // Validate file is PDF
      if (!file.name.toLowerCase().endsWith('.pdf')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a PDF file'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });
      
      final bytes = await file.readAsBytes();
      final storage = appwrite.Storage(widget.appwriteService.client);
      
      // Upload to Appwrite Storage - try debate_slides bucket first, fallback to profile_images
      String bucketId = AppwriteConstants.debateSlidesBucket;
      late final dynamic uploadedFile;
      
      try {
        uploadedFile = await storage.createFile(
          bucketId: bucketId,
          fileId: appwrite.ID.unique(),
          file: appwrite.InputFile.fromBytes(
            bytes: bytes,
            filename: file.name,
          ),
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress.progress / 100;
            });
          },
        );
      } catch (e) {
        // If debate_slides bucket doesn't exist, try profile_images as fallback
        _logger.warning('debate_slides bucket not found, using profile_images fallback: $e');
        bucketId = AppwriteConstants.profileImagesBucket;
        uploadedFile = await storage.createFile(
          bucketId: bucketId,
          fileId: appwrite.ID.unique(),
          file: appwrite.InputFile.fromBytes(
            bytes: bytes,
            filename: file.name,
          ),
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress.progress / 100;
            });
          },
        );
      }
      
      // Get page count
      final document = await PdfDocument.openData(bytes);
      final pageCount = document.pagesCount;
      
      // Notify other participants via LiveKit
      await widget.syncService.uploadPdf(
        uploadedFile.$id,
        file.name,
        pageCount,
        uploadedFile.$id,
      );
      
      // Load the PDF locally
      _pdfController = PdfController(document: PdfDocument.openData(bytes));
      
      setState(() {
        _isUploading = false;
        _totalPages = pageCount;
        _currentPage = 1;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF uploaded successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'Failed to upload PDF: $e';
      });
      _logger.error('Error uploading PDF: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Try Again',
              textColor: Colors.white,
              onPressed: _uploadPdf,
            ),
          ),
        );
      }
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(value: _uploadProgress),
            const SizedBox(height: 16),
            Text('Uploading... ${(_uploadProgress * 100).toInt()}%'),
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
                onPressed: _uploadPdf,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload PDF'),
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
                ? 'Upload a PDF to share slides'
                : 'Waiting for host to upload slides',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (widget.isHost) ...[
              ElevatedButton.icon(
                onPressed: _uploadPdf,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload PDF'),
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