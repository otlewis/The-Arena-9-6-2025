import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../../../services/appwrite_service.dart';
import '../../../models/user_profile.dart';
import '../utils/arena_constants.dart';
import '../../../core/logging/app_logger.dart';

/// Service for iOS-specific optimizations in the arena
class ArenaIOSOptimizationService {
  final AppwriteService _appwriteService;
  
  // Static cache for iOS optimization
  static final Map<String, dynamic> _iosRoomCache = {};
  static final Map<String, List<Map<String, dynamic>>> _iosParticipantCache = {};
  static final Map<String, UserProfile> _iosUserProfileCache = {};
  static DateTime? _lastCacheUpdate;
  
  bool _isIOSOptimizationEnabled = false;
  
  ArenaIOSOptimizationService({required AppwriteService appwriteService})
      : _appwriteService = appwriteService {
    _isIOSOptimizationEnabled = _isIOSDevice();
  }
  
  /// Check if current device is iOS
  bool _isIOSDevice() {
    if (kIsWeb) return false;
    try {
      return defaultTargetPlatform == TargetPlatform.iOS;
    } catch (e) {
      AppLogger().warning('Error detecting iOS platform: $e');
      return false;
    }
  }
  
  /// Initialize iOS optimizations
  Future<void> initialize(String roomId) async {
    if (!_isIOSOptimizationEnabled) {
      AppLogger().debug('iOS optimizations disabled - not an iOS device');
      return;
    }
    
    try {
      AppLogger().info('🍎 Initializing iOS-specific optimizations for Arena...');
      
      // Check for cached data first
      final cachedData = _getIOSCachedData(roomId);
      if (cachedData != null && _isCacheValid()) {
        AppLogger().info('📱 Using cached iOS data for faster initialization');
        return;
      }
      
      // Pre-warm cache with room data
      await _preWarmIOSCache(roomId);
      
      AppLogger().info('✅ iOS optimizations initialized successfully');
    } catch (e) {
      AppLogger().error('❌ Error initializing iOS optimizations: $e');
      _isIOSOptimizationEnabled = false;
    }
  }
  
  /// Get cached data for iOS
  Map<String, dynamic>? _getIOSCachedData(String roomId) {
    if (!_iosRoomCache.containsKey(roomId)) {
      return null;
    }
    
    return {
      'roomData': _iosRoomCache[roomId],
      'participants': _iosParticipantCache[roomId] ?? [],
      'userProfiles': _iosUserProfileCache,
      'lastUpdate': _lastCacheUpdate,
    };
  }
  
  /// Check if cache is valid
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    final now = DateTime.now();
    final cacheAge = now.difference(_lastCacheUpdate!);
    return cacheAge < ArenaConstants.iosCacheValidDuration;
  }
  
  /// Pre-warm iOS cache
  Future<void> _preWarmIOSCache(String roomId) async {
    if (!_isIOSOptimizationEnabled) return;
    
    try {
      AppLogger().debug('📱 Pre-warming iOS cache for room: $roomId');
      
      // Load and cache room data
      await _loadAndCacheRoomData(roomId);
      
      // Load and cache participants
      await _loadAndCacheParticipants(roomId);
      
      _lastCacheUpdate = DateTime.now();
      AppLogger().info('📱 iOS cache pre-warmed successfully');
    } catch (e) {
      AppLogger().warning('Error pre-warming iOS cache: $e');
    }
  }
  
  /// Load and cache room data
  Future<void> _loadAndCacheRoomData(String roomId) async {
    try {
      final roomData = await _appwriteService.databases.getDocument(
        databaseId: ArenaConstants.databaseId,
        collectionId: ArenaConstants.debateRoomsCollection,
        documentId: roomId,
      );
      
      _iosRoomCache[roomId] = roomData.data;
      AppLogger().debug('📱 Room data cached for iOS: $roomId');
    } catch (e) {
      AppLogger().warning('Error caching room data for iOS: $e');
    }
  }
  
  /// Load and cache participants
  Future<void> _loadAndCacheParticipants(String roomId) async {
    try {
      final participantsData = await _appwriteService.databases.listDocuments(
        databaseId: ArenaConstants.databaseId,
        collectionId: ArenaConstants.roomParticipantsCollection,
        queries: [],
      );
      
      final participants = participantsData.documents.map((doc) => doc.data).toList();
      _iosParticipantCache[roomId] = participants;
      
      // Pre-load user profiles
      for (final participant in participants) {
        final userId = participant['userId'];
        if (userId != null) {
          await _loadAndCacheUserProfile(userId);
        }
      }
      
      AppLogger().debug('📱 Participants cached for iOS: ${participants.length}');
    } catch (e) {
      AppLogger().warning('Error caching participants for iOS: $e');
    }
  }
  
  /// Load and cache user profile
  Future<UserProfile?> _loadAndCacheUserProfile(String userId) async {
    // Check cache first
    if (_iosUserProfileCache.containsKey(userId)) {
      AppLogger().debug('📱 Using cached user profile for: $userId');
      return _iosUserProfileCache[userId];
    }
    
    try {
      final userData = await _appwriteService.databases.getDocument(
        databaseId: ArenaConstants.databaseId,
        collectionId: ArenaConstants.userProfilesCollection,
        documentId: userId,
      );
      
      final userProfile = UserProfile(
        id: userData.$id,
        name: userData.data['name'] ?? 'Unknown User',
        email: userData.data['email'] ?? '',
        avatar: userData.data['avatar'],
        bio: userData.data['bio'],
        reputation: userData.data['reputation'] ?? 0,
        totalWins: userData.data['totalWins'] ?? 0,
        totalDebates: userData.data['totalDebates'] ?? 0,
        createdAt: DateTime.parse(userData.$createdAt),
        updatedAt: DateTime.parse(userData.$updatedAt),
      );
      
      // Cache for future use
      _iosUserProfileCache[userId] = userProfile;
      
      AppLogger().debug('📱 User profile loaded and cached: ${userProfile.name}');
      return userProfile;
    } catch (e) {
      AppLogger().warning('Error loading user profile for iOS ($userId): $e');
      return null;
    }
  }
  
  /// Get cached room data
  Map<String, dynamic>? getCachedRoomData(String roomId) {
    if (!_isIOSOptimizationEnabled) return null;
    return _iosRoomCache[roomId];
  }
  
  /// Get cached participants
  List<Map<String, dynamic>>? getCachedParticipants(String roomId) {
    if (!_isIOSOptimizationEnabled) return null;
    return _iosParticipantCache[roomId];
  }
  
  /// Get cached user profile
  UserProfile? getCachedUserProfile(String userId) {
    if (!_isIOSOptimizationEnabled) return null;
    return _iosUserProfileCache[userId];
  }
  
  /// Update cached user profile
  void updateCachedUserProfile(String userId, UserProfile profile) {
    if (!_isIOSOptimizationEnabled) return;
    
    _iosUserProfileCache[userId] = profile;
    AppLogger().debug('📱 Updated cached profile for: ${profile.name}');
  }
  
  /// Clear iOS cache
  void clearCache() {
    if (!_isIOSOptimizationEnabled) return;
    
    final roomCount = _iosRoomCache.length;
    final participantCount = _iosParticipantCache.length;
    final profileCount = _iosUserProfileCache.length;
    
    _iosRoomCache.clear();
    _iosParticipantCache.clear();
    _iosUserProfileCache.clear();
    _lastCacheUpdate = null;
    
    AppLogger().debug('📱 iOS cache cleared: $roomCount rooms, $participantCount participant lists, $profileCount profiles');
  }
  
  /// Optimize memory for iOS
  void optimizeMemoryForIOS() {
    if (!_isIOSOptimizationEnabled) return;
    
    try {
      // Remove old cache entries if we have too many
      if (_iosUserProfileCache.length > ArenaConstants.iosMaxCachedProfiles) {
        // Keep only the most recently used profiles
        final entries = _iosUserProfileCache.entries.toList();
        _iosUserProfileCache.clear();
        
        // Keep the last half
        const keepCount = ArenaConstants.iosMaxCachedProfiles ~/ 2;
        for (int i = entries.length - keepCount; i < entries.length; i++) {
          _iosUserProfileCache[entries[i].key] = entries[i].value;
        }
        
        AppLogger().debug('📱 iOS memory optimized: kept $keepCount profiles');
      }
      
      // Remove old room caches
      if (_iosRoomCache.length > ArenaConstants.iosMaxCachedRooms) {
        final roomIds = _iosRoomCache.keys.toList();
        final removeCount = _iosRoomCache.length - ArenaConstants.iosMaxCachedRooms;
        
        for (int i = 0; i < removeCount; i++) {
          final roomId = roomIds[i];
          _iosRoomCache.remove(roomId);
          _iosParticipantCache.remove(roomId);
        }
        
        AppLogger().debug('📱 iOS memory optimized: removed $removeCount old room caches');
      }
      
      AppLogger().debug('📱 iOS memory optimization completed');
    } catch (e) {
      AppLogger().warning('Error optimizing memory for iOS: $e');
    }
  }
  
  /// Handle iOS app state changes
  void handleIOSAppStateChange(bool isInBackground) {
    if (!_isIOSOptimizationEnabled) return;
    
    if (isInBackground) {
      AppLogger().debug('📱 App went to background - optimizing for iOS');
      optimizeMemoryForIOS();
    } else {
      AppLogger().debug('📱 App came to foreground - iOS ready');
      // Invalidate cache to ensure fresh data
      _lastCacheUpdate = null;
    }
  }
  
  /// Get iOS performance metrics
  Map<String, dynamic> getIOSPerformanceMetrics() {
    return {
      'enabled': _isIOSOptimizationEnabled,
      'cacheValid': _isCacheValid(),
      'lastCacheUpdate': _lastCacheUpdate?.toIso8601String(),
      'cachedRooms': _iosRoomCache.length,
      'cachedParticipantLists': _iosParticipantCache.length,
      'cachedUserProfiles': _iosUserProfileCache.length,
      'cacheTimeoutMinutes': ArenaConstants.iosCacheValidDuration.inMinutes,
      'maxCachedProfiles': ArenaConstants.iosMaxCachedProfiles,
      'maxCachedRooms': ArenaConstants.iosMaxCachedRooms,
    };
  }
  
  /// iOS-specific error handling
  void handleIOSError(String operation, dynamic error) {
    if (!_isIOSOptimizationEnabled) return;
    
    AppLogger().error('📱 iOS Error in $operation: $error');
    
    // iOS-specific error recovery
    if (error.toString().contains('memory') || error.toString().contains('cache')) {
      AppLogger().info('📱 Attempting iOS memory recovery...');
      clearCache();
      optimizeMemoryForIOS();
    }
  }
  
  /// Check if iOS optimizations are enabled
  bool get isEnabled => _isIOSOptimizationEnabled;
  
  /// Force enable/disable iOS optimizations (for testing)
  void setEnabled(bool enabled) {
    _isIOSOptimizationEnabled = enabled;
    if (!enabled) {
      clearCache();
    }
    AppLogger().info('📱 iOS optimizations ${enabled ? 'enabled' : 'disabled'}');
  }
  
  /// Dispose iOS optimizations
  void dispose() {
    if (_isIOSOptimizationEnabled) {
      AppLogger().info('📱 Disposing iOS optimizations...');
      clearCache();
      optimizeMemoryForIOS();
      _isIOSOptimizationEnabled = false;
      AppLogger().debug('📱 iOS optimizations disposed');
    }
  }
}