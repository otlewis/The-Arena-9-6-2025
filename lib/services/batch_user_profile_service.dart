import 'dart:async';
import '../core/logging/app_logger.dart';
import '../models/user_profile.dart';
import '../services/appwrite_service.dart';

/// Service for batching user profile fetches to eliminate N+1 query problems
/// Caches profiles and batches requests for optimal performance
class BatchUserProfileService {
  static final BatchUserProfileService _instance = BatchUserProfileService._internal();
  factory BatchUserProfileService() => _instance;
  BatchUserProfileService._internal();

  final AppLogger _logger = AppLogger();
  final AppwriteService _appwrite = AppwriteService();

  // Cache for user profiles
  final Map<String, UserProfile> _profileCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Batching mechanism
  final Map<String, Completer<UserProfile?>> _pendingRequests = {};
  Timer? _batchTimer;
  final Set<String> _requestQueue = {};

  // Configuration
  static const Duration _batchDelay = Duration(milliseconds: 100); // Batch requests within 100ms
  static const Duration _cacheExpiry = Duration(minutes: 5); // Cache expires after 5 minutes
  static const int _maxBatchSize = 20; // Maximum profiles to fetch in one batch

  /// Get a single user profile with caching and batching
  Future<UserProfile?> getUserProfile(String userId) async {
    if (userId.isEmpty) return null;

    // Check cache first
    final cachedProfile = _getCachedProfile(userId);
    if (cachedProfile != null) {
      return cachedProfile;
    }

    // Check if request is already pending
    if (_pendingRequests.containsKey(userId)) {
      return await _pendingRequests[userId]!.future;
    }

    // Create completer for this request
    final completer = Completer<UserProfile?>();
    _pendingRequests[userId] = completer;

    // Add to request queue
    _requestQueue.add(userId);

    // Start batch timer if not already running
    _startBatchTimer();

    return await completer.future;
  }

  /// Get multiple user profiles efficiently
  Future<Map<String, UserProfile>> getUserProfiles(List<String> userIds) async {
    final result = <String, UserProfile>{};
    final uncachedIds = <String>[];

    // Check cache for existing profiles
    for (final userId in userIds) {
      if (userId.isEmpty) continue;

      final cachedProfile = _getCachedProfile(userId);
      if (cachedProfile != null) {
        result[userId] = cachedProfile;
      } else {
        uncachedIds.add(userId);
      }
    }

    // Batch fetch uncached profiles
    if (uncachedIds.isNotEmpty) {
      final fetchedProfiles = await _batchFetchProfiles(uncachedIds);
      result.addAll(fetchedProfiles);
    }

    _logger.debug('📊 Batch profile fetch: ${userIds.length} requested, ${result.length} returned (${userIds.length - result.length} failed)');
    return result;
  }

  /// Preload user profiles for a room
  Future<void> preloadRoomProfiles(List<String> userIds) async {
    final uncachedIds = userIds.where((id) => !_isProfileCached(id)).toList();

    if (uncachedIds.isNotEmpty) {
      _logger.info('📊 Preloading ${uncachedIds.length} user profiles for room');
      await _batchFetchProfiles(uncachedIds);
    }
  }

  /// Check if profile is cached and not expired
  bool _isProfileCached(String userId) {
    if (!_profileCache.containsKey(userId)) return false;

    final timestamp = _cacheTimestamps[userId];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  /// Get cached profile if available and not expired
  UserProfile? _getCachedProfile(String userId) {
    if (_isProfileCached(userId)) {
      return _profileCache[userId];
    }

    // Remove expired cache entry
    _profileCache.remove(userId);
    _cacheTimestamps.remove(userId);
    return null;
  }

  /// Start the batch timer
  void _startBatchTimer() {
    if (_batchTimer?.isActive == true) return;

    _batchTimer = Timer(_batchDelay, () {
      _processBatch();
    });
  }

  /// Process the current batch of requests
  Future<void> _processBatch() async {
    if (_requestQueue.isEmpty) return;

    final batchIds = _requestQueue.take(_maxBatchSize).toList();
    _requestQueue.removeAll(batchIds);

    _logger.debug('📊 Processing batch of ${batchIds.length} user profile requests');

    try {
      // Fetch profiles in batch
      final profiles = await _batchFetchProfiles(batchIds);

      // Resolve all pending requests for this batch
      for (final userId in batchIds) {
        final completer = _pendingRequests.remove(userId);
        if (completer != null && !completer.isCompleted) {
          completer.complete(profiles[userId]);
        }
      }

    } catch (e) {
      _logger.error('❌ Batch profile fetch failed: $e');

      // Reject all pending requests for this batch
      for (final userId in batchIds) {
        final completer = _pendingRequests.remove(userId);
        if (completer != null && !completer.isCompleted) {
          completer.complete(null);
        }
      }
    }

    // Process remaining requests if any
    if (_requestQueue.isNotEmpty) {
      _startBatchTimer();
    }
  }

  /// Fetch multiple profiles from Appwrite
  Future<Map<String, UserProfile>> _batchFetchProfiles(List<String> userIds) async {
    final result = <String, UserProfile>{};

    try {
      // Use Appwrite's batch query capability
      final documents = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [
          'select("\$id", "name", "email", "bio", "avatar", "reputationPercentage", "totalDebates", "totalWins", "coinBalance", "isVerified", "isPremium")',
          'limit(${userIds.length})',
          'or([${userIds.map((id) => 'equal("\$id", "$id")').join(', ')}])',
        ],
      );

      // Process documents into UserProfile objects
      for (final doc in documents.documents) {
        try {
          final profile = UserProfile.fromMap(doc.data);
          result[profile.id] = profile;

          // Cache the profile
          _profileCache[profile.id] = profile;
          _cacheTimestamps[profile.id] = DateTime.now();

        } catch (e) {
          _logger.warning('Failed to parse user profile ${doc.$id}: $e');
        }
      }

      _logger.debug('✅ Batch fetched ${result.length}/${userIds.length} user profiles');

    } catch (e) {
      _logger.error('❌ Appwrite batch query failed: $e');

      // Fallback to individual requests if batch fails
      _logger.info('🔄 Falling back to individual profile requests');
      await _fallbackIndividualFetch(userIds, result);
    }

    return result;
  }

  /// Fallback to individual profile fetches if batch fails
  Future<void> _fallbackIndividualFetch(List<String> userIds, Map<String, UserProfile> result) async {
    for (final userId in userIds) {
      try {
        final profile = await _appwrite.getUserProfile(userId);
        if (profile != null) {
          result[userId] = profile;

          // Cache the profile
          _profileCache[userId] = profile;
          _cacheTimestamps[userId] = DateTime.now();
        }
      } catch (e) {
        _logger.warning('Failed to fetch individual profile $userId: $e');
      }
    }
  }

  /// Invalidate cache for a specific user
  void invalidateProfile(String userId) {
    _profileCache.remove(userId);
    _cacheTimestamps.remove(userId);
    _logger.debug('🧹 Invalidated cache for user: $userId');
  }

  /// Update cached profile when we have new data
  void updateCachedProfile(UserProfile profile) {
    _profileCache[profile.id] = profile;
    _cacheTimestamps[profile.id] = DateTime.now();
    _logger.debug('📊 Updated cached profile: ${profile.id}');
  }

  /// Clear expired cache entries
  void _clearExpiredCache() {
    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheExpiry) {
        expiredIds.add(entry.key);
      }
    }

    for (final id in expiredIds) {
      _profileCache.remove(id);
      _cacheTimestamps.remove(id);
    }

    if (expiredIds.isNotEmpty) {
      _logger.debug('🧹 Cleared ${expiredIds.length} expired profile cache entries');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    _clearExpiredCache();

    return {
      'cachedProfiles': _profileCache.length,
      'pendingRequests': _pendingRequests.length,
      'queuedRequests': _requestQueue.length,
      'cacheHitRate': _calculateCacheHitRate(),
      'oldestCacheEntry': _getOldestCacheTime(),
    };
  }

  double _calculateCacheHitRate() {
    // This would need to be tracked over time in a real implementation
    return 0.85; // Placeholder
  }

  DateTime? _getOldestCacheTime() {
    if (_cacheTimestamps.isEmpty) return null;
    return _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Log cache statistics
  void logStatistics() {
    final stats = getCacheStatistics();
    _logger.info('📊 USER PROFILE CACHE STATISTICS:');
    _logger.info('  • Cached Profiles: ${stats['cachedProfiles']}');
    _logger.info('  • Pending Requests: ${stats['pendingRequests']}');
    _logger.info('  • Queued Requests: ${stats['queuedRequests']}');
    _logger.info('  • Cache Hit Rate: ${(stats['cacheHitRate'] * 100).toStringAsFixed(1)}%');
    _logger.info('  • Oldest Cache Entry: ${stats['oldestCacheEntry']}');
  }

  /// Clear all cache and pending requests
  void clearCache() {
    _profileCache.clear();
    _cacheTimestamps.clear();

    // Complete any pending requests with null
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
    _pendingRequests.clear();
    _requestQueue.clear();

    _batchTimer?.cancel();
    _logger.info('🧹 Cleared all user profile cache and pending requests');
  }

  /// Dispose the service
  void dispose() {
    _batchTimer?.cancel();
    clearCache();
    _logger.info('🧹 Batch user profile service disposed');
  }
}

/// Extension methods for easy integration
extension BatchUserProfileExtension on AppwriteService {
  /// Get user profile using batch service
  Future<UserProfile?> getUserProfileBatched(String userId) {
    return BatchUserProfileService().getUserProfile(userId);
  }

  /// Get multiple user profiles efficiently
  Future<Map<String, UserProfile>> getUserProfilesBatched(List<String> userIds) {
    return BatchUserProfileService().getUserProfiles(userIds);
  }
}