import 'dart:async';
import '../models/debate_source.dart';
import '../services/appwrite_service.dart';
import '../constants/appwrite.dart';
import '../core/logging/app_logger.dart';
import 'package:appwrite/appwrite.dart';

class PinnedLinkService {
  final AppwriteService _appwrite;
  final String _roomId;
  final String _userId;
  static final _logger = AppLogger();

  final _pinnedLinkController = StreamController<DebateSource?>.broadcast();
  Stream<DebateSource?> get pinnedLinkStream => _pinnedLinkController.stream;
  
  final _linkSharedController = StreamController<DebateSource>.broadcast();
  Stream<DebateSource> get linkSharedStream => _linkSharedController.stream;

  DebateSource? _currentPinnedLink;
  DebateSource? get currentPinnedLink => _currentPinnedLink;

  PinnedLinkService({
    required AppwriteService appwrite,
    required String roomId,
    required String userId,
  })  : _appwrite = appwrite,
        _roomId = roomId,
        _userId = userId {
    _initializeService();
  }

  void _initializeService() {
    _logger.info('📌 Initializing PinnedLinkService for room: $_roomId');
    _loadCurrentPinnedLink();
    _setupRealtimeListener();
  }

  Future<void> _loadCurrentPinnedLink() async {
    try {
      _logger.info('📌 Loading current pinned link for room: $_roomId');
      
      final documents = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.sharedSourcesCollection,
        queries: [
          Query.equal('roomId', _roomId),
          Query.equal('isPinned', true),
          Query.orderDesc('\$createdAt'),
          Query.limit(1),
        ],
      );

      if (documents.documents.isNotEmpty) {
        final doc = documents.documents.first;
        _currentPinnedLink = DebateSource(
          id: doc.$id,
          url: doc.data['url'] ?? '',
          title: doc.data['title'] ?? 'Untitled',
          description: doc.data['description'],
          sharedAt: DateTime.parse(doc.data['sharedAt'] ?? DateTime.now().toIso8601String()),
          sharedBy: doc.data['sharedBy'] ?? '',
          sharedByName: doc.data['sharedByName'],
          isSecure: doc.data['url']?.toString().startsWith('https') ?? false,
          isPinned: true,
        );
        
        _logger.info('📌 Found pinned link: ${_currentPinnedLink!.title}');
        _pinnedLinkController.add(_currentPinnedLink);
      } else {
        _logger.info('📌 No pinned link found for room');
        _currentPinnedLink = null;
        _pinnedLinkController.add(null);
      }
    } catch (e) {
      _logger.error('📌 Error loading pinned link: $e');
      _currentPinnedLink = null;
      _pinnedLinkController.add(null);
    }
  }

  void _setupRealtimeListener() {
    try {
      // Listen for changes to pinned sources in this room
      final subscription = _appwrite.realtime.subscribe([
        'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.sharedSourcesCollection}.documents'
      ]);

      subscription.stream.listen((response) {
        _logger.info('📌 Realtime update received - Events: ${response.events}');
        _logger.info('📌 Realtime payload: ${response.payload}');
        
        if (response.payload.isNotEmpty) {
          final data = response.payload;
          final roomId = data['roomId'];
          final isPinned = data['isPinned'] ?? false;
          final sharedBy = data['sharedBy'];
          
          _logger.info('📌 Processing event for room: $roomId (our room: $_roomId)');
          _logger.info('📌 Event details - isPinned: $isPinned, sharedBy: $sharedBy');
          
          // Only process if it's for our room
          if (roomId == _roomId) {
            _logger.info('📌 ✅ Link update for our room - isPinned: $isPinned');
            
            // If a link was just pinned, notify all users via the stream
            if (isPinned) {
              final sharedLink = DebateSource(
                id: data['\$id'] ?? '',
                url: data['url'] ?? '',
                title: data['title'] ?? 'Untitled',
                description: data['description'],
                sharedAt: DateTime.parse(data['sharedAt'] ?? DateTime.now().toIso8601String()),
                sharedBy: sharedBy ?? '',
                sharedByName: data['sharedByName'],
                isSecure: data['url']?.toString().startsWith('https') ?? false,
                isPinned: isPinned,
              );
              
              _logger.info('📌 ✅ Broadcasting shared link to stream - sharedBy: $sharedBy, currentUser: $_userId');
              // The stream will be filtered in arena_screen to not show popup for the sharer
              _linkSharedController.add(sharedLink);
            }
            
            _loadCurrentPinnedLink(); // Reload to get latest
          } else {
            _logger.info('📌 ❌ Ignoring event for different room: $roomId');
          }
        } else {
          _logger.info('📌 ❌ Empty payload in realtime event');
        }
      });
    } catch (e) {
      _logger.error('📌 Error setting up realtime listener: $e');
    }
  }

  Future<void> pinLink(String url, String title, {String? description}) async {
    try {
      _logger.info('📌 Pinning link: $title -> $url');
      _logger.info('📌 Room ID: $_roomId, User ID: $_userId');
      
      // First, unpin any existing pinned link
      await _unpinAllLinks();
      
      // Create new pinned link
      _logger.info('📌 Creating database document...');
      final response = await _appwrite.databases.createDocument(
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
          'isPinned': true,
        },
      );
      _logger.info('📌 Database document created with ID: ${response.$id}');

      _currentPinnedLink = DebateSource(
        id: response.$id,
        url: url,
        title: title,
        description: description,
        sharedAt: DateTime.now(),
        sharedBy: _userId,
        sharedByName: null, // Will be resolved by UI if needed
        isSecure: url.startsWith('https'),
        isPinned: true,
      );

      _pinnedLinkController.add(_currentPinnedLink);
      _logger.info('📌 Successfully pinned link: $title');
      _logger.info('📌 Pinned link stream should trigger now...');
    } catch (e) {
      _logger.error('📌 Error pinning link: $e');
      rethrow;
    }
  }

  Future<void> unpinCurrentLink() async {
    if (_currentPinnedLink == null) return;
    
    try {
      _logger.info('📌 Unpinning current link: ${_currentPinnedLink!.title}');
      
      await _appwrite.databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.sharedSourcesCollection,
        documentId: _currentPinnedLink!.id,
        data: {
          'isPinned': false,
        },
      );

      _currentPinnedLink = null;
      _pinnedLinkController.add(null);
      _logger.info('📌 Successfully unpinned link');
    } catch (e) {
      _logger.error('📌 Error unpinning link: $e');
      rethrow;
    }
  }

  Future<void> _unpinAllLinks() async {
    try {
      // Get all pinned links for this room
      final documents = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.sharedSourcesCollection,
        queries: [
          Query.equal('roomId', _roomId),
          Query.equal('isPinned', true),
        ],
      );

      // Unpin them all
      for (final doc in documents.documents) {
        await _appwrite.databases.updateDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.sharedSourcesCollection,
          documentId: doc.$id,
          data: {
            'isPinned': false,
          },
        );
      }
    } catch (e) {
      _logger.error('📌 Error unpinning existing links: $e');
    }
  }

  void dispose() {
    _pinnedLinkController.close();
    _linkSharedController.close();
  }
}