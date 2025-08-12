import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/logging/app_logger.dart';

/// Comprehensive offline data caching system with Hive for structured data
/// and SharedPreferences for simple key-value pairs
class OfflineDataCache {
  static final OfflineDataCache _instance = OfflineDataCache._internal();
  factory OfflineDataCache() => _instance;
  OfflineDataCache._internal();

  // Hive boxes for different data types
  late Box<Map> _userProfilesBox;
  late Box<Map> _roomsBox;
  late Box<Map> _messagesBox;
  late Box<Map> _participantsBox;
  late Box<Map> _metadataBox;
  
  // Cache validity durations
  static const Duration _userProfileCacheDuration = Duration(hours: 1);
  static const Duration _roomCacheDuration = Duration(minutes: 30);
  static const Duration _messageCacheDuration = Duration(minutes: 15);
  static const Duration _defaultCacheDuration = Duration(minutes: 30);
  
  bool _isInitialized = false;

  /// Initialize the offline cache system
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      AppLogger().info('📦 Initializing Offline Data Cache...');
      
      // Initialize Hive
      await Hive.initFlutter();
      
      // Open boxes for different data types
      _userProfilesBox = await Hive.openBox<Map>('userProfiles');
      _roomsBox = await Hive.openBox<Map>('rooms');
      _messagesBox = await Hive.openBox<Map>('messages');
      _participantsBox = await Hive.openBox<Map>('participants');
      _metadataBox = await Hive.openBox<Map>('metadata');
      
      _isInitialized = true;
      
      // Clean up old cache entries on startup
      await _cleanupExpiredCache();
      
      AppLogger().info('📦 Offline Data Cache initialized successfully');
    } catch (e) {
      AppLogger().error('📦 Failed to initialize Offline Data Cache: $e');
      throw Exception('Cache initialization failed: $e');
    }
  }
  
  /// Cache user profile data
  Future<void> cacheUserProfile(String userId, Map<String, dynamic> profileData) async {
    await _ensureInitialized();
    
    try {
      final cacheEntry = {
        'data': profileData,
        'timestamp': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(_userProfileCacheDuration).toIso8601String(),
      };
      
      await _userProfilesBox.put(userId, cacheEntry);
      AppLogger().debug('📦 Cached user profile for: $userId');
    } catch (e) {
      AppLogger().error('📦 Failed to cache user profile: $e');
    }
  }
  
  /// Get cached user profile
  Future<Map<String, dynamic>?> getCachedUserProfile(String userId) async {
    await _ensureInitialized();
    
    try {
      final cacheEntry = _userProfilesBox.get(userId);
      if (cacheEntry == null) return null;
      
      // Check if cache is expired
      final expiresAt = DateTime.parse(cacheEntry['expiresAt'] as String);
      if (DateTime.now().isAfter(expiresAt)) {
        await _userProfilesBox.delete(userId);
        AppLogger().debug('📦 User profile cache expired for: $userId');
        return null;
      }
      
      AppLogger().debug('📦 Retrieved cached user profile for: $userId');
      return Map<String, dynamic>.from(cacheEntry['data'] as Map);
    } catch (e) {
      AppLogger().error('📦 Failed to get cached user profile: $e');
      return null;
    }
  }
  
  /// Cache room data
  Future<void> cacheRoom(String roomId, Map<String, dynamic> roomData) async {
    await _ensureInitialized();
    
    try {
      final cacheEntry = {
        'data': roomData,
        'timestamp': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(_roomCacheDuration).toIso8601String(),
      };
      
      await _roomsBox.put(roomId, cacheEntry);
      AppLogger().debug('📦 Cached room: $roomId');
    } catch (e) {
      AppLogger().error('📦 Failed to cache room: $e');
    }
  }
  
  /// Get cached room data
  Future<Map<String, dynamic>?> getCachedRoom(String roomId) async {
    await _ensureInitialized();
    
    try {
      final cacheEntry = _roomsBox.get(roomId);
      if (cacheEntry == null) return null;
      
      // Check if cache is expired
      final expiresAt = DateTime.parse(cacheEntry['expiresAt'] as String);
      if (DateTime.now().isAfter(expiresAt)) {
        await _roomsBox.delete(roomId);
        AppLogger().debug('📦 Room cache expired for: $roomId');
        return null;
      }
      
      AppLogger().debug('📦 Retrieved cached room: $roomId');
      return Map<String, dynamic>.from(cacheEntry['data'] as Map);
    } catch (e) {
      AppLogger().error('📦 Failed to get cached room: $e');
      return null;
    }
  }
  
  /// Cache list of documents (e.g., room lists, participant lists)
  Future<void> cacheDocumentList(
    String key,
    List<Map<String, dynamic>> documents, {
    Duration? cacheDuration,
  }) async {
    await _ensureInitialized();
    
    try {
      final duration = cacheDuration ?? _defaultCacheDuration;
      final cacheEntry = {
        'data': documents,
        'timestamp': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(duration).toIso8601String(),
        'count': documents.length,
      };
      
      await _metadataBox.put(key, cacheEntry);
      AppLogger().debug('📦 Cached document list: $key (${documents.length} items)');
    } catch (e) {
      AppLogger().error('📦 Failed to cache document list: $e');
    }
  }
  
  /// Get cached document list
  Future<List<Map<String, dynamic>>?> getCachedDocumentList(String key) async {
    await _ensureInitialized();
    
    try {
      final cacheEntry = _metadataBox.get(key);
      if (cacheEntry == null) return null;
      
      // Check if cache is expired
      final expiresAt = DateTime.parse(cacheEntry['expiresAt'] as String);
      if (DateTime.now().isAfter(expiresAt)) {
        await _metadataBox.delete(key);
        AppLogger().debug('📦 Document list cache expired for: $key');
        return null;
      }
      
      final data = cacheEntry['data'] as List;
      final documents = data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      
      AppLogger().debug('📦 Retrieved cached document list: $key (${documents.length} items)');
      return documents;
    } catch (e) {
      AppLogger().error('📦 Failed to get cached document list: $e');
      return null;
    }
  }
  
  /// Cache messages for a room
  Future<void> cacheMessages(String roomId, List<Map<String, dynamic>> messages) async {
    await _ensureInitialized();
    
    try {
      final cacheEntry = {
        'data': messages,
        'timestamp': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(_messageCacheDuration).toIso8601String(),
        'count': messages.length,
      };
      
      await _messagesBox.put(roomId, cacheEntry);
      AppLogger().debug('📦 Cached messages for room: $roomId (${messages.length} messages)');
    } catch (e) {
      AppLogger().error('📦 Failed to cache messages: $e');
    }
  }
  
  /// Get cached messages for a room
  Future<List<Map<String, dynamic>>?> getCachedMessages(String roomId) async {
    await _ensureInitialized();
    
    try {
      final cacheEntry = _messagesBox.get(roomId);
      if (cacheEntry == null) return null;
      
      // Messages have shorter cache duration
      final expiresAt = DateTime.parse(cacheEntry['expiresAt'] as String);
      if (DateTime.now().isAfter(expiresAt)) {
        await _messagesBox.delete(roomId);
        AppLogger().debug('📦 Message cache expired for room: $roomId');
        return null;
      }
      
      final data = cacheEntry['data'] as List;
      final messages = data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      
      AppLogger().debug('📦 Retrieved cached messages for room: $roomId (${messages.length} messages)');
      return messages;
    } catch (e) {
      AppLogger().error('📦 Failed to get cached messages: $e');
      return null;
    }
  }
  
  /// Invalidate cache for a specific key
  Future<void> invalidateCache(String boxName, String key) async {
    await _ensureInitialized();
    
    try {
      Box<Map>? box;
      switch (boxName) {
        case 'userProfiles':
          box = _userProfilesBox;
          break;
        case 'rooms':
          box = _roomsBox;
          break;
        case 'messages':
          box = _messagesBox;
          break;
        case 'participants':
          box = _participantsBox;
          break;
        case 'metadata':
          box = _metadataBox;
          break;
      }
      
      if (box != null) {
        await box.delete(key);
        AppLogger().debug('📦 Invalidated cache: $boxName/$key');
      }
    } catch (e) {
      AppLogger().error('📦 Failed to invalidate cache: $e');
    }
  }
  
  /// Clear all cached data
  Future<void> clearAllCache() async {
    await _ensureInitialized();
    
    try {
      await _userProfilesBox.clear();
      await _roomsBox.clear();
      await _messagesBox.clear();
      await _participantsBox.clear();
      await _metadataBox.clear();
      
      AppLogger().info('📦 Cleared all cached data');
    } catch (e) {
      AppLogger().error('📦 Failed to clear cache: $e');
    }
  }
  
  /// Clean up expired cache entries
  Future<void> _cleanupExpiredCache() async {
    try {
      int removedCount = 0;
      
      // Clean up each box
      for (final box in [_userProfilesBox, _roomsBox, _messagesBox, _participantsBox, _metadataBox]) {
        final keysToRemove = <dynamic>[];
        
        for (final key in box.keys) {
          final entry = box.get(key);
          if (entry != null && entry['expiresAt'] != null) {
            final expiresAt = DateTime.parse(entry['expiresAt'] as String);
            if (DateTime.now().isAfter(expiresAt)) {
              keysToRemove.add(key);
            }
          }
        }
        
        for (final key in keysToRemove) {
          await box.delete(key);
          removedCount++;
        }
      }
      
      if (removedCount > 0) {
        AppLogger().info('📦 Cleaned up $removedCount expired cache entries');
      }
    } catch (e) {
      AppLogger().error('📦 Failed to cleanup expired cache: $e');
    }
  }
  
  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    await _ensureInitialized();
    
    return {
      'userProfiles': _userProfilesBox.length,
      'rooms': _roomsBox.length,
      'messages': _messagesBox.length,
      'participants': _participantsBox.length,
      'metadata': _metadataBox.length,
      'totalEntries': _userProfilesBox.length + 
                     _roomsBox.length + 
                     _messagesBox.length + 
                     _participantsBox.length + 
                     _metadataBox.length,
    };
  }
  
  /// Ensure cache is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    if (_isInitialized) {
      await _userProfilesBox.close();
      await _roomsBox.close();
      await _messagesBox.close();
      await _participantsBox.close();
      await _metadataBox.close();
      _isInitialized = false;
      
      AppLogger().info('📦 Offline Data Cache disposed');
    }
  }
}