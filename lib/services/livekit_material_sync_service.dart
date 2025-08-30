import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:livekit_client/livekit_client.dart';
import 'package:appwrite/appwrite.dart';
import '../models/debate_source.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';
import '../constants/appwrite.dart';

class LiveKitMaterialSyncService {
  final AppwriteService _appwrite;
  final Room? _room;
  final String _roomId;
  final String _userId;
  
  final _materialUpdateController = StreamController<DebateMaterialSync>.broadcast();
  Stream<DebateMaterialSync> get materialUpdates => _materialUpdateController.stream;
  
  final _sourceAddedController = StreamController<DebateSource>.broadcast();
  Stream<DebateSource> get sourceAdded => _sourceAddedController.stream;
  
  final _slideChangeController = StreamController<SlideData>.broadcast();
  Stream<SlideData> get slideChanges => _slideChangeController.stream;
  
  bool _isHost = false;
  String? _currentSlideFileId;
  String? _currentSlideFileName;
  String? _currentSlidePdfUrl;
  int _currentSlideNumber = 1;
  int _totalSlides = 0;
  
  static final _logger = AppLogger();

  LiveKitMaterialSyncService({
    required AppwriteService appwrite,
    required Room? room,
    required String roomId,
    required String userId,
    bool isHost = false,
  })  : _appwrite = appwrite,
        _room = room,
        _roomId = roomId,
        _userId = userId,
        _isHost = isHost {
    _initializeListeners();
  }

  void _initializeListeners() {
    if (_room == null) {
      _logger.warning('LiveKit room is null, material sync disabled');
      return;
    }

    // Create event listener for room events
    final roomListener = _room!.createListener();
    
    // Register data message listener for receiving messages from other participants
    roomListener.on<DataReceivedEvent>((event) {
      _logger.info('📌 Received data message from participant: ${event.participant?.identity}');
      _handleDataMessage(Uint8List.fromList(event.data));
    });
    
    _logger.info('📌 LiveKit data message listener registered');
  }

  void _handleDataMessage(Uint8List data) {
    try {
      final jsonStr = utf8.decode(data);
      final message = json.decode(jsonStr);
      
      if (message['type'] == null) return;
      
      final sync = DebateMaterialSync(
        type: message['type'],
        slideFileId: message['slideFileId'],
        currentSlide: message['currentSlide'],
        totalSlides: message['totalSlides'],
        sourceUrl: message['sourceUrl'],
        sourceTitle: message['sourceTitle'],
        userId: message['userId'],
        userName: message['userName'],
        timestamp: DateTime.now(),
      );
      
      _materialUpdateController.add(sync);
      
      switch (message['type']) {
        case 'slide_change':
          _handleSlideChange(message);
          break;
        case 'source_share':
          _handleSourceShare(message);
          break;
        case 'pdf_upload':
          _handlePdfUpload(message);
          break;
      }
    } catch (e) {
      _logger.error('Error handling material sync message: $e');
    }
  }

  void _handleSlideChange(Map<String, dynamic> message) {
    if (message['slideFileId'] != null && message['currentSlide'] != null) {
      _currentSlideFileId = message['slideFileId'];
      _currentSlideNumber = message['currentSlide'];
      _totalSlides = message['totalSlides'] ?? 0;
      
      final slideData = SlideData(
        fileId: message['slideFileId'],
        fileName: message['fileName'] ?? 'Presentation',
        currentSlide: message['currentSlide'],
        totalSlides: message['totalSlides'] ?? 0,
        pdfUrl: message['pdfUrl'],
        uploadedBy: message['userId'] ?? '',
        uploadedByName: message['userName'],
        uploadedAt: DateTime.now(),
      );
      
      _slideChangeController.add(slideData);
    }
  }

  void _handleSourceShare(Map<String, dynamic> message) {
    if (message['sourceUrl'] != null && message['sourceTitle'] != null) {
      final source = DebateSource(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: message['sourceUrl'],
        title: message['sourceTitle'],
        description: message['description'],
        faviconUrl: message['faviconUrl'],
        sharedAt: DateTime.now(),
        sharedBy: message['userId'] ?? '',
        sharedByName: message['userName'],
        isSecure: message['sourceUrl'].toString().startsWith('https'),
        type: 'web',
      );
      
      _sourceAddedController.add(source);
    }
  }

  void _handlePdfUpload(Map<String, dynamic> message) {
    if (message['slideFileId'] != null) {
      _currentSlideFileId = message['slideFileId'];
      _currentSlideNumber = 1;
      _totalSlides = message['totalSlides'] ?? 0;
      
      final slideData = SlideData(
        fileId: message['slideFileId'],
        fileName: message['fileName'] ?? 'Presentation',
        currentSlide: 1,
        totalSlides: message['totalSlides'] ?? 0,
        pdfUrl: message['pdfUrl'],
        uploadedBy: message['userId'] ?? '',
        uploadedByName: message['userName'],
        uploadedAt: DateTime.now(),
      );
      
      _slideChangeController.add(slideData);
    }
  }

  Future<void> changeSlide(int slideNumber) async {
    if (!_isHost || _currentSlideFileId == null) return;
    
    try {
      final message = {
        'type': 'slide_change',
        'slideFileId': _currentSlideFileId,
        'currentSlide': slideNumber,
        'totalSlides': _totalSlides,
        'userId': _userId,
      };
      
      await _sendDataMessage(message);
      _currentSlideNumber = slideNumber;
      
      // Update persisted slide position
      await _persistSlideDataToAppwrite();
    } catch (e) {
      _logger.error('Error changing slide: $e');
    }
  }

  Future<void> shareSource(String url, String title, {String? description}) async {
    try {
      final message = {
        'type': 'source_share',
        'sourceUrl': url,
        'sourceTitle': title,
        'description': description,
        'userId': _userId,
      };
      
      await _sendDataMessage(message);
      _logger.info('📌 Source shared via LiveKit successfully to other participants');
      
      // Try to save to Appwrite for persistence and real-time sync
      try {
        await _appwrite.databases.createDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.sharedSourcesCollection,
          documentId: ID.unique(),
          data: {
            'roomId': _roomId,
            'url': url,
            'title': title,
            'description': description,
            'sharedBy': _userId,
            'sharedAt': DateTime.now().toIso8601String(),
            'isPinned': true, // Mark as pinned to trigger popup for all users via real-time subscription
          },
        );
        _logger.info('📌 Source saved to database - will trigger real-time updates for all participants');
      } catch (dbError) {
        _logger.warning('📌 Could not save to database (will work without persistence): $dbError');
        // Continue without database save - LiveKit messaging works fine
      }
      
      // IMPORTANT: Still handle the source locally so it appears in the sharer's materials panel
      // The popup filtering happens in arena_screen based on sharedBy field
      _handleSourceShare(message);
      _logger.info('📌 Source added to local materials panel for sharer');
      
    } catch (e) {
      _logger.error('Error sharing source: $e');
      rethrow;
    }
  }

  Future<void> uploadPdf(String fileId, String fileName, int totalPages, String? pdfUrl) async {
    if (!_isHost) return;
    
    try {
      _currentSlideFileId = fileId;
      _currentSlideFileName = fileName;
      _currentSlidePdfUrl = pdfUrl;
      _currentSlideNumber = 1;
      _totalSlides = totalPages;
      
      // Persist to Appwrite for room session
      await _persistSlideDataToAppwrite();
      
      final message = {
        'type': 'pdf_upload',
        'slideFileId': fileId,
        'fileName': fileName,
        'totalSlides': totalPages,
        'pdfUrl': pdfUrl,
        'userId': _userId,
      };
      
      await _sendDataMessage(message);
    } catch (e) {
      _logger.error('Error uploading PDF: $e');
    }
  }

  Future<void> _sendDataMessage(Map<String, dynamic> message) async {
    if (_room == null) {
      _logger.warning('Cannot send data message: room is null');
      return;
    }
    
    try {
      final jsonStr = json.encode(message);
      final data = Uint8List.fromList(utf8.encode(jsonStr));
      
      await _room!.localParticipant?.publishData(
        data,
        reliable: true,
      );
    } catch (e) {
      _logger.error('Error sending data message: $e');
    }
  }

  void setHostStatus(bool isHost) {
    _isHost = isHost;
  }

  bool get isHost => _isHost;
  String? get currentSlideFileId => _currentSlideFileId;
  int get currentSlideNumber => _currentSlideNumber;
  int get totalSlides => _totalSlides;

  // Persist current slide data to Appwrite for room session
  Future<void> _persistSlideDataToAppwrite() async {
    if (_currentSlideFileId == null) return;
    
    try {
      // Store in room_slide_state collection with roomId as document ID
      await _appwrite.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomSlideStateCollection,
        documentId: _roomId, // Use roomId as document ID for uniqueness
        data: {
          'roomId': _roomId,
          'slideFileId': _currentSlideFileId,
          'fileName': _currentSlideFileName ?? 'Presentation',
          'pdfUrl': _currentSlidePdfUrl,
          'currentSlide': _currentSlideNumber,
          'totalSlides': _totalSlides,
          'uploadedBy': _userId,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      // If document exists, update it instead
      try {
        await _appwrite.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: AppwriteConstants.roomSlideStateCollection,
          documentId: _roomId,
          data: {
            'slideFileId': _currentSlideFileId,
            'fileName': _currentSlideFileName ?? 'Presentation',
            'pdfUrl': _currentSlidePdfUrl,
            'currentSlide': _currentSlideNumber,
            'totalSlides': _totalSlides,
            'uploadedBy': _userId,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );
      } catch (updateError) {
        _logger.error('Error persisting slide data: $updateError');
      }
    }
  }

  // Load persisted slide data from Appwrite when initializing
  Future<SlideData?> loadPersistedSlideData() async {
    try {
      final document = await _appwrite.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomSlideStateCollection,
        documentId: _roomId,
      );

      _currentSlideFileId = document.data['slideFileId'];
      _currentSlideFileName = document.data['fileName'];
      _currentSlidePdfUrl = document.data['pdfUrl'];
      _currentSlideNumber = document.data['currentSlide'] ?? 1;
      _totalSlides = document.data['totalSlides'] ?? 0;

      return SlideData(
        fileId: _currentSlideFileId!,
        fileName: _currentSlideFileName ?? 'Presentation',
        currentSlide: _currentSlideNumber,
        totalSlides: _totalSlides,
        pdfUrl: _currentSlidePdfUrl,
        uploadedBy: document.data['uploadedBy'] ?? '',
        uploadedByName: null,
        uploadedAt: DateTime.now(),
      );
    } catch (e) {
      _logger.info('No persisted slide data found for room $_roomId: $e');
      return null;
    }
  }

  // Clear persisted slide data (for when host removes slides)
  Future<void> clearPersistedSlideData() async {
    try {
      await _appwrite.databases.deleteDocument(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomSlideStateCollection,
        documentId: _roomId,
      );
      
      _currentSlideFileId = null;
      _currentSlideFileName = null;
      _currentSlidePdfUrl = null;
      _currentSlideNumber = 1;
      _totalSlides = 0;
    } catch (e) {
      _logger.warning('Error clearing persisted slide data: $e');
    }
  }

  void dispose() {
    _materialUpdateController.close();
    _sourceAddedController.close();
    _slideChangeController.close();
  }
}