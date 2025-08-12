import 'dart:async';
import 'package:appwrite/appwrite.dart';
import '../core/logging/app_logger.dart';
import '../services/appwrite_service.dart';
import '../models/shared_link.dart';

class SharedLinksService {
  final AppwriteService _appwrite = AppwriteService();
  final Map<String, StreamSubscription<RealtimeMessage>> _subscriptions = {};
  
  static const String databaseId = 'arena_db';
  static const String collectionId = 'shared_links';
  
  // Callback for when shared links are updated
  Function(List<SharedLink>)? onSharedLinksUpdated;
  
  /// Share a link with all participants in the room
  Future<void> shareLink({
    required String roomId,
    required String url,
    String? title,
    String? description,
    String? type,
  }) async {
    try {
      AppLogger().info('📤 Sharing link in room $roomId: $url');
      
      final currentUser = await _appwrite.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      final userProfile = await _appwrite.getUserProfile(currentUser.$id);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }
      
      final sharedLink = SharedLink(
        id: ID.unique(),
        roomId: roomId,
        url: url,
        title: title ?? _generateTitleFromUrl(url),
        description: description,
        sharedBy: currentUser.$id,
        sharedByName: userProfile.name,
        sharedAt: DateTime.now(),
        type: type ?? _detectLinkType(url),
      );
      
      await _appwrite.databases.createDocument(
        databaseId: databaseId,
        collectionId: collectionId,
        documentId: sharedLink.id,
        data: {
          'roomId': sharedLink.roomId,
          'url': sharedLink.url,
          'title': sharedLink.title,
          'description': sharedLink.description,
          'sharedBy': sharedLink.sharedBy,
          'sharedByName': sharedLink.sharedByName,
          'sharedAt': sharedLink.sharedAt.toIso8601String(),
          'isActive': sharedLink.isActive,
          'type': sharedLink.type,
        },
        permissions: [
          Permission.read(Role.any()),
          Permission.update(Role.user(currentUser.$id)),
          Permission.delete(Role.user(currentUser.$id)),
        ],
      );
      
      AppLogger().info('✅ Link shared successfully');
      
    } catch (e) {
      AppLogger().error('❌ Failed to share link: $e');
      
      // If collection doesn't exist, provide helpful error message
      if (e.toString().contains('Collection with the requested ID could not be found')) {
        throw Exception('Shared links feature is not set up. Please create the shared_links collection in Appwrite.');
      }
      
      rethrow;
    }
  }
  
  /// Get all active shared links for a room
  Future<List<SharedLink>> getSharedLinks(String roomId) async {
    try {
      AppLogger().debug('📥 Fetching shared links for room: $roomId');
      
      final response = await _appwrite.databases.listDocuments(
        databaseId: databaseId,
        collectionId: collectionId,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('isActive', true),
          Query.orderDesc('sharedAt'),
          Query.limit(50), // Limit to most recent 50 links
        ],
      );
      
      final links = response.documents.map((doc) {
        return SharedLink.fromJson({
          'id': doc.$id,
          ...doc.data,
          'sharedAt': DateTime.parse(doc.data['sharedAt']),
        });
      }).toList();
      
      AppLogger().debug('📥 Found ${links.length} shared links');
      return links;
      
    } catch (e) {
      AppLogger().error('❌ Failed to fetch shared links: $e');
      
      // If collection doesn't exist, return empty list instead of crashing
      if (e.toString().contains('Collection with the requested ID could not be found') ||
          e.toString().contains('document_not_found')) {
        AppLogger().info('📝 Shared links collection not found - returning empty list');
        return [];
      }
      
      return [];
    }
  }
  
  /// Subscribe to real-time updates for shared links in a room
  void subscribeToSharedLinks(String roomId) {
    try {
      AppLogger().info('🔔 Subscribing to shared links for room: $roomId');
      
      // Cancel existing subscription if any
      unsubscribeFromSharedLinks(roomId);
      
      final subscription = _appwrite.realtime.subscribe([
        'databases.$databaseId.collections.$collectionId.documents'
      ]);
      
      _subscriptions[roomId] = subscription.stream.listen((event) {
        AppLogger().debug('📨 Received shared links update: ${event.events.join(", ")}');
        AppLogger().debug('📨 Event payload: ${event.payload}');
        
        // Refresh shared links for any database change to this collection
        // We'll filter by roomId when fetching the data
        _refreshSharedLinks(roomId);
      });
      
      // Initial load
      _refreshSharedLinks(roomId);
      
    } catch (e) {
      AppLogger().error('❌ Failed to subscribe to shared links: $e');
    }
  }
  
  /// Unsubscribe from shared links updates
  void unsubscribeFromSharedLinks(String roomId) {
    final subscription = _subscriptions[roomId];
    if (subscription != null) {
      subscription.cancel();
      _subscriptions.remove(roomId);
      AppLogger().info('🔕 Unsubscribed from shared links for room: $roomId');
    }
  }
  
  /// Refresh shared links and notify listeners
  Future<void> _refreshSharedLinks(String roomId) async {
    try {
      final links = await getSharedLinks(roomId);
      onSharedLinksUpdated?.call(links);
    } catch (e) {
      AppLogger().error('❌ Failed to refresh shared links: $e');
    }
  }
  
  /// Deactivate a shared link (remove it from the room)
  Future<void> deactivateLink(String linkId) async {
    try {
      AppLogger().info('🗑️ Deactivating shared link: $linkId');
      
      await _appwrite.databases.updateDocument(
        databaseId: databaseId,
        collectionId: collectionId,
        documentId: linkId,
        data: {'isActive': false},
      );
      
      AppLogger().info('✅ Link deactivated successfully');
      
    } catch (e) {
      AppLogger().error('❌ Failed to deactivate link: $e');
      rethrow;
    }
  }
  
  /// Generate a title from URL
  String _generateTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final domain = uri.host.replaceAll('www.', '');
      return domain.split('.').first.toUpperCase();
    } catch (e) {
      return 'Shared Link';
    }
  }
  
  /// Detect link type based on URL
  String _detectLinkType(String url) {
    final lowerUrl = url.toLowerCase();
    
    if (lowerUrl.contains('youtube.com') || 
        lowerUrl.contains('youtu.be') ||
        lowerUrl.contains('vimeo.com') ||
        lowerUrl.contains('video')) {
      return 'video';
    }
    
    if (lowerUrl.contains('docs.google.com') ||
        lowerUrl.contains('drive.google.com') ||
        lowerUrl.contains('notion.so') ||
        lowerUrl.contains('.pdf') ||
        lowerUrl.contains('docs.')) {
      return 'docs';
    }
    
    if (lowerUrl.contains('github.com') ||
        lowerUrl.contains('gitlab.com') ||
        lowerUrl.contains('codepen.io')) {
      return 'code';
    }
    
    if (lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.png') ||
        lowerUrl.contains('.gif') ||
        lowerUrl.contains('image')) {
      return 'image';
    }
    
    return 'link';
  }
  
  /// Dispose all subscriptions
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    AppLogger().info('🧹 Disposed shared links service');
  }
}