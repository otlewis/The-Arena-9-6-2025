import 'dart:async';
import '../core/logging/app_logger.dart';
import '../models/shared_link.dart';

/// Mock implementation of shared links service for testing
/// Use this when the Appwrite collection is not set up yet
class MockSharedLinksService {
  final Map<String, List<SharedLink>> _mockLinks = {};
  
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
      AppLogger().info('📤 [MOCK] Sharing link in room $roomId: $url');
      
      final sharedLink = SharedLink(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        url: url,
        title: title ?? _generateTitleFromUrl(url),
        description: description,
        sharedBy: 'current_user_id', // Mock user ID
        sharedByName: 'Test User', // Mock user name
        sharedAt: DateTime.now(),
        type: type ?? _detectLinkType(url),
      );
      
      // Add to mock storage
      if (!_mockLinks.containsKey(roomId)) {
        _mockLinks[roomId] = [];
      }
      _mockLinks[roomId]!.add(sharedLink);
      
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Notify listeners
      onSharedLinksUpdated?.call(_mockLinks[roomId] ?? []);
      
      AppLogger().info('✅ [MOCK] Link shared successfully');
      
    } catch (e) {
      AppLogger().error('❌ [MOCK] Failed to share link: $e');
      rethrow;
    }
  }
  
  /// Get all active shared links for a room
  Future<List<SharedLink>> getSharedLinks(String roomId) async {
    try {
      AppLogger().debug('📥 [MOCK] Fetching shared links for room: $roomId');
      
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 100));
      
      final links = _mockLinks[roomId] ?? [];
      AppLogger().debug('📥 [MOCK] Found ${links.length} shared links');
      return links;
      
    } catch (e) {
      AppLogger().error('❌ [MOCK] Failed to fetch shared links: $e');
      return [];
    }
  }
  
  /// Subscribe to real-time updates for shared links in a room
  void subscribeToSharedLinks(String roomId) {
    try {
      AppLogger().info('🔔 [MOCK] Subscribing to shared links for room: $roomId');
      
      // Initial load
      _refreshSharedLinks(roomId);
      
      // Simulate periodic updates for testing
      Timer.periodic(const Duration(seconds: 10), (timer) {
        if (onSharedLinksUpdated != null) {
          _refreshSharedLinks(roomId);
        } else {
          timer.cancel();
        }
      });
      
    } catch (e) {
      AppLogger().error('❌ [MOCK] Failed to subscribe to shared links: $e');
    }
  }
  
  /// Unsubscribe from shared links updates
  void unsubscribeFromSharedLinks(String roomId) {
    AppLogger().info('🔕 [MOCK] Unsubscribed from shared links for room: $roomId');
  }
  
  /// Refresh shared links and notify listeners
  Future<void> _refreshSharedLinks(String roomId) async {
    try {
      final links = await getSharedLinks(roomId);
      onSharedLinksUpdated?.call(links);
    } catch (e) {
      AppLogger().error('❌ [MOCK] Failed to refresh shared links: $e');
    }
  }
  
  /// Deactivate a shared link (remove it from the room)
  Future<void> deactivateLink(String linkId) async {
    try {
      AppLogger().info('🗑️ [MOCK] Deactivating shared link: $linkId');
      
      // Remove from all rooms
      for (final links in _mockLinks.values) {
        links.removeWhere((link) => link.id == linkId);
      }
      
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Notify all rooms (simplified)
      for (final entry in _mockLinks.entries) {
        onSharedLinksUpdated?.call(entry.value);
      }
      
      AppLogger().info('✅ [MOCK] Link deactivated successfully');
      
    } catch (e) {
      AppLogger().error('❌ [MOCK] Failed to deactivate link: $e');
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
  
  /// Add some test data for demonstration
  void addTestData(String roomId) {
    _mockLinks[roomId] = [
      SharedLink(
        id: 'test_1',
        roomId: roomId,
        url: 'https://docs.flutter.dev',
        title: 'Flutter Documentation',
        sharedBy: 'test_user_1',
        sharedByName: 'Alice',
        sharedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        type: 'docs',
      ),
      SharedLink(
        id: 'test_2',
        roomId: roomId,
        url: 'https://youtube.com/watch?v=example',
        title: 'Flutter Tutorial Video',
        sharedBy: 'test_user_2',
        sharedByName: 'Bob',
        sharedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        type: 'video',
      ),
    ];
    
    // Notify immediately
    AppLogger().info('🧪 [MOCK] Adding test data - ${_mockLinks[roomId]?.length ?? 0} links');
    onSharedLinksUpdated?.call(_mockLinks[roomId] ?? []);
    AppLogger().info('🧪 [MOCK] Callback called with ${_mockLinks[roomId]?.length ?? 0} test links');
  }
  
  /// Dispose all subscriptions
  void dispose() {
    _mockLinks.clear();
    AppLogger().info('🧹 [MOCK] Disposed shared links service');
  }
}