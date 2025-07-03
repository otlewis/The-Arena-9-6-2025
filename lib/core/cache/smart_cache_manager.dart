import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../logging/app_logger.dart';
import '../../models/user_profile.dart';
import '../../services/appwrite_service.dart';
import '../providers/app_providers.dart';

/// Cache entry with expiry and type info
class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;
  final CacheStrategy strategy;

  CacheEntry(this.data, this.ttl, this.strategy) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

enum CacheStrategy {
  memory,       // In-memory only
  persistent,   // Persist across app sessions
  background,   // Background refresh
}

/// Smart cache manager for frequently accessed data
class SmartCacheManager {
  static final SmartCacheManager _instance = SmartCacheManager._internal();
  factory SmartCacheManager() => _instance;
  SmartCacheManager._internal();

  final Map<String, CacheEntry> _cache = {};
  final Map<String, Timer> _expiryTimers = {};
  final AppwriteService _appwrite = AppwriteService();
  final AppLogger _logger = AppLogger();

  /// Get cached data or load from source
  Future<T?> get<T>(
    String key,
    Future<T?> Function() loader, {
    Duration ttl = const Duration(minutes: 10),
    CacheStrategy strategy = CacheStrategy.memory,
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache first
      if (!forceRefresh && _cache.containsKey(key)) {
        final entry = _cache[key] as CacheEntry<T>?;
        if (entry != null && !entry.isExpired) {
          _logger.debug('🗄️ Cache hit for: $key');
          return entry.data;
        }
      }

      // Load fresh data
      _logger.debug('🔄 Loading fresh data for: $key');
      final data = await loader();
      
      // Only cache non-null data
      if (data != null) {
        await _set(key, data, ttl: ttl, strategy: strategy);
      }
      
      return data;
    } catch (e) {
      _logger.error('Cache get failed for $key: $e');
      return null;
    }
  }

  /// Set cache value
  Future<void> _set<T>(
    String key,
    T data, {
    Duration ttl = const Duration(minutes: 10),
    CacheStrategy strategy = CacheStrategy.memory,
  }) async {
    final entry = CacheEntry<T>(data, ttl, strategy);
    _cache[key] = entry;

    // Set up expiry timer
    _expiryTimers[key]?.cancel();
    _expiryTimers[key] = Timer(ttl, () => _remove(key));

    // Handle background refresh for critical data
    if (strategy == CacheStrategy.background && ttl.inMinutes > 5) {
      Timer(Duration(milliseconds: (ttl.inMilliseconds * 0.8).round()), () {
        _backgroundRefresh(key);
      });
    }

    _logger.debug('💾 Cached $key with TTL: ${ttl.inMinutes}min');
  }

  /// Background refresh before expiry
  void _backgroundRefresh(String key) {
    _logger.debug('🔄 Background refresh triggered for: $key');
    // This would trigger a refresh without blocking UI
    // Implementation depends on specific data type
  }

  /// Remove from cache
  void _remove(String key) {
    _cache.remove(key);
    _expiryTimers[key]?.cancel();
    _expiryTimers.remove(key);
  }

  /// Clear all cache
  void clearAll() {
    _cache.clear();
    for (final timer in _expiryTimers.values) {
      timer.cancel();
    }
    _expiryTimers.clear();
    _logger.debug('🗑️ Cache cleared');
  }

  /// Preload critical data
  Future<void> preloadCriticalData(String userId) async {
    _logger.debug('⚡ Preloading critical data for user: $userId');
    
    final futures = [
      // Preload user profile
      get(
        'user_profile_$userId',
        () => _appwrite.getUserProfile(userId),
        ttl: const Duration(hours: 1),
        strategy: CacheStrategy.background,
      ),
      
      // Preload user clubs/memberships
      get(
        'user_clubs_$userId',
        () => _appwrite.getUserMemberships(userId),
        ttl: const Duration(minutes: 30),
        strategy: CacheStrategy.background,
      ),
      
      // Preload arena rooms
      get(
        'arena_rooms',
        () => _appwrite.getRooms(),
        ttl: const Duration(minutes: 15),
        strategy: CacheStrategy.background,
      ),
    ];

    try {
      await Future.wait(futures);
      _logger.debug('✅ Critical data preloading completed');
    } catch (e) {
      _logger.warning('⚠️ Some preload operations failed: $e');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int expiredCount = 0;
    int totalSize = 0;

    for (final entry in _cache.values) {
      if (entry.isExpired) expiredCount++;
      totalSize++;
    }

    return {
      'total_entries': totalSize,
      'expired_entries': expiredCount,
      'active_entries': totalSize - expiredCount,
      'memory_usage_kb': (totalSize * 1024), // Rough estimate
    };
  }
}

/// Riverpod providers for cached data
final cacheManagerProvider = Provider<SmartCacheManager>((ref) {
  return SmartCacheManager();
});

/// Cached user profile provider
final cachedUserProfileProvider = FutureProvider.family<UserProfile?, String>((ref, userId) async {
  final cache = ref.read(cacheManagerProvider);
  final appwrite = ref.read(appwriteServiceProvider);
  
  return await cache.get(
    'user_profile_$userId',
    () => appwrite.getUserProfile(userId),
    ttl: const Duration(hours: 1),
    strategy: CacheStrategy.background,
  );
});

/// Cached current user provider  
final cachedCurrentUserProvider = FutureProvider<UserProfile?>((ref) async {
  final cache = ref.read(cacheManagerProvider);
  final appwrite = ref.read(appwriteServiceProvider);
  
  final currentUser = await appwrite.getCurrentUser();
  if (currentUser == null) return null;
  
  return await cache.get(
    'current_user_profile',
    () => appwrite.getUserProfile(currentUser.$id),
    ttl: const Duration(hours: 2),
    strategy: CacheStrategy.background,
  );
});

/// Cache warm-up provider
final cacheWarmupProvider = FutureProvider<void>((ref) async {
  final cache = ref.read(cacheManagerProvider);
  final appwrite = ref.read(appwriteServiceProvider);
  
  try {
    final currentUser = await appwrite.getCurrentUser();
    if (currentUser != null) {
      await cache.preloadCriticalData(currentUser.$id);
    }
  } catch (e) {
    AppLogger().warning('Cache warmup failed: $e');
  }
});