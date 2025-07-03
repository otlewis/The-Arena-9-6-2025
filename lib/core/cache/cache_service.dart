import 'package:hive_flutter/hive_flutter.dart';
import '../logging/app_logger.dart';

/// Centralized caching service using Hive
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final AppLogger _logger = AppLogger();
  
  static const String _userCacheBox = 'user_cache';
  static const String _roomCacheBox = 'room_cache';
  static const String _challengeCacheBox = 'challenge_cache';
  static const String _settingsBox = 'settings';

  Box<dynamic>? _userCache;
  Box<dynamic>? _roomCache;
  Box<dynamic>? _challengeCache;
  Box<dynamic>? _settings;

  Future<void> initialize() async {
    try {
      await Hive.initFlutter();
      
      _userCache = await Hive.openBox(_userCacheBox);
      _roomCache = await Hive.openBox(_roomCacheBox);
      _challengeCache = await Hive.openBox(_challengeCacheBox);
      _settings = await Hive.openBox(_settingsBox);
      
      _logger.info('Cache service initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize cache service', e, stackTrace);
    }
  }

  // User cache methods
  Future<void> cacheUser(String userId, Map<String, dynamic> userData) async {
    try {
      await _userCache?.put(userId, {
        'data': userData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      _logger.error('Failed to cache user data for $userId', e);
    }
  }

  Map<String, dynamic>? getCachedUser(String userId, {Duration maxAge = const Duration(hours: 1)}) {
    try {
      final cached = _userCache?.get(userId);
      if (cached != null) {
        final timestamp = cached['timestamp'] as int;
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        
        if (DateTime.now().difference(cacheTime) < maxAge) {
          return Map<String, dynamic>.from(cached['data']);
        } else {
          _userCache?.delete(userId); // Remove expired cache
        }
      }
    } catch (e) {
      _logger.error('Failed to get cached user data for $userId', e);
    }
    return null;
  }

  // Room cache methods
  Future<void> cacheRoom(String roomId, Map<String, dynamic> roomData) async {
    try {
      await _roomCache?.put(roomId, {
        'data': roomData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      _logger.error('Failed to cache room data for $roomId', e);
    }
  }

  Map<String, dynamic>? getCachedRoom(String roomId, {Duration maxAge = const Duration(minutes: 30)}) {
    try {
      final cached = _roomCache?.get(roomId);
      if (cached != null) {
        final timestamp = cached['timestamp'] as int;
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        
        if (DateTime.now().difference(cacheTime) < maxAge) {
          return Map<String, dynamic>.from(cached['data']);
        } else {
          _roomCache?.delete(roomId);
        }
      }
    } catch (e) {
      _logger.error('Failed to get cached room data for $roomId', e);
    }
    return null;
  }

  // Challenge cache methods
  Future<void> cacheChallenge(String challengeId, Map<String, dynamic> challengeData) async {
    try {
      await _challengeCache?.put(challengeId, {
        'data': challengeData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      _logger.error('Failed to cache challenge data for $challengeId', e);
    }
  }

  Map<String, dynamic>? getCachedChallenge(String challengeId, {Duration maxAge = const Duration(hours: 24)}) {
    try {
      final cached = _challengeCache?.get(challengeId);
      if (cached != null) {
        final timestamp = cached['timestamp'] as int;
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        
        if (DateTime.now().difference(cacheTime) < maxAge) {
          return Map<String, dynamic>.from(cached['data']);
        } else {
          _challengeCache?.delete(challengeId);
        }
      }
    } catch (e) {
      _logger.error('Failed to get cached challenge data for $challengeId', e);
    }
    return null;
  }

  // Settings methods
  Future<void> saveSetting(String key, dynamic value) async {
    try {
      await _settings?.put(key, value);
    } catch (e) {
      _logger.error('Failed to save setting $key', e);
    }
  }

  T? getSetting<T>(String key, [T? defaultValue]) {
    try {
      return _settings?.get(key, defaultValue: defaultValue);
    } catch (e) {
      _logger.error('Failed to get setting $key', e);
      return defaultValue;
    }
  }

  // Batch operations
  Future<void> cacheUsers(Map<String, Map<String, dynamic>> usersData) async {
    try {
      final batch = <String, Map<String, dynamic>>{};
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      for (final entry in usersData.entries) {
        batch[entry.key] = {
          'data': entry.value,
          'timestamp': timestamp,
        };
      }
      
      await _userCache?.putAll(batch);
    } catch (e) {
      _logger.error('Failed to batch cache users', e);
    }
  }

  // Cache management
  Future<void> clearUserCache() async {
    try {
      await _userCache?.clear();
      _logger.info('User cache cleared');
    } catch (e) {
      _logger.error('Failed to clear user cache', e);
    }
  }

  Future<void> clearRoomCache() async {
    try {
      await _roomCache?.clear();
      _logger.info('Room cache cleared');
    } catch (e) {
      _logger.error('Failed to clear room cache', e);
    }
  }

  Future<void> clearAllCache() async {
    try {
      await Future.wait([
        _userCache?.clear() ?? Future.value(),
        _roomCache?.clear() ?? Future.value(),
        _challengeCache?.clear() ?? Future.value(),
      ]);
      _logger.info('All cache cleared');
    } catch (e) {
      _logger.error('Failed to clear all cache', e);
    }
  }

  Future<void> dispose() async {
    try {
      await Future.wait([
        _userCache?.close() ?? Future.value(),
        _roomCache?.close() ?? Future.value(),
        _challengeCache?.close() ?? Future.value(),
        _settings?.close() ?? Future.value(),
      ]);
    } catch (e) {
      _logger.error('Failed to dispose cache service', e);
    }
  }
}