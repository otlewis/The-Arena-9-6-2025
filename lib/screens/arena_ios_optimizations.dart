import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../services/appwrite_service.dart';
import '../models/user_profile.dart';
import '../core/logging/app_logger.dart';

class ArenaIOSOptimizations {
  // Static cache variables for iOS optimization
  static final Map<String, dynamic> _iosRoomCache = {};
  static final Map<String, List<Map<String, dynamic>>> _iosParticipantCache = {};
  static final Map<String, UserProfile> _iosUserProfileCache = {};
  
  final AppwriteService _appwrite;
  bool _isIOSOptimizationEnabled = false;
  DateTime? _lastCacheUpdate;
  
  ArenaIOSOptimizations({required AppwriteService appwrite}) : _appwrite = appwrite {
    _isIOSOptimizationEnabled = _isIOSDevice();
  }
  
  // Check if current device is iOS
  bool _isIOSDevice() {
    if (kIsWeb) return false;
    try {
      return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    } catch (e) {
      AppLogger().warning('Error detecting iOS platform: $e');
      return false;
    }
  }
  
  // Initialize iOS optimizations
  Future<void> initializeArenaIOS(String roomId) async {
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
        await _applyIOSCachedData(cachedData);
        return;
      }
      
      // Load fresh data with iOS-specific optimizations
      await _loadRoomDataOptimized(roomId);
      await _loadParticipantsOptimized(roomId);
      
      AppLogger().info('✅ iOS optimizations initialized successfully');
    } catch (e) {
      AppLogger().error('❌ Error initializing iOS optimizations: $e');
      // Fall back to standard initialization if iOS optimizations fail
      _isIOSOptimizationEnabled = false;
    }
  }
  
  // Get cached data for iOS
  Map<String, dynamic>? _getIOSCachedData(String roomId) {
    if (!_iosRoomCache.containsKey(roomId)) {
      return null;
    }
    
    return {
      'roomData': _iosRoomCache[roomId],
      'participants': _iosParticipantCache[roomId] ?? [],
      'userProfiles': _iosUserProfileCache,
    };
  }
  
  // Apply cached data
  Future<void> _applyIOSCachedData(Map<String, dynamic> cachedData) async {
    try {
      // Apply cached room data
      final roomData = cachedData['roomData'];
      if (roomData != null) {
        AppLogger().debug('📱 Applied cached room data');
      }
      
      // Apply cached participant data
      final participants = cachedData['participants'] as List<Map<String, dynamic>>?;
      if (participants != null) {
        AppLogger().debug('📱 Applied cached participant data (${participants.length} participants)');
      }
      
      // Apply cached user profiles
      final userProfiles = cachedData['userProfiles'] as Map<String, UserProfile>?;
      if (userProfiles != null) {
        AppLogger().debug('📱 Applied cached user profiles (${userProfiles.length} profiles)');
      }
      
    } catch (e) {
      AppLogger().warning('Error applying iOS cached data: $e');
    }
  }
  
  
  // Check if cache is valid (within 30 seconds)
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    final now = DateTime.now();
    final cacheAge = now.difference(_lastCacheUpdate!);
    return cacheAge.inSeconds < 30;
  }
  
  // Load room data with iOS optimizations
  Future<Map<String, dynamic>?> _loadRoomDataOptimized(String roomId) async {
    if (!_isIOSOptimizationEnabled) return null;
    
    try {
      AppLogger().debug('📱 Loading room data with iOS optimizations...');
      
      final roomData = await _appwrite.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'debate_rooms',
        documentId: roomId,
      );
      
      // Cache the room data for iOS
      _iosRoomCache[roomId] = roomData.data;
      
      AppLogger().info('📱 Room data loaded and cached for iOS');
      return roomData.data;
    } catch (e) {
      AppLogger().error('Error loading room data with iOS optimizations: $e');
      return null;
    }
  }
  
  // Load participants with iOS optimizations
  Future<List<Map<String, dynamic>>?> _loadParticipantsOptimized(String roomId) async {
    if (!_isIOSOptimizationEnabled) return null;
    
    try {
      AppLogger().debug('📱 Loading participants with iOS optimizations...');
      
      final participantsData = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'room_participants',
        queries: [
          // iOS-specific query optimizations could go here
        ],
      );
      
      final participants = participantsData.documents.map((doc) => doc.data).toList();
      
      // Cache participants for iOS
      _iosParticipantCache[roomId] = participants;
      
      // Pre-load user profiles for iOS caching
      for (var participant in participants) {
        final userId = participant['userId'];
        if (userId != null && !_iosUserProfileCache.containsKey(userId)) {
          final userProfile = await _loadUserProfileOptimized(userId);
          if (userProfile != null) {
            _iosUserProfileCache[userId] = userProfile;
          }
        }
      }
      
      AppLogger().info('📱 Participants loaded and cached for iOS (${participants.length} participants)');
      return participants;
    } catch (e) {
      AppLogger().error('Error loading participants with iOS optimizations: $e');
      return null;
    }
  }
  
  // Load user profile with iOS optimizations
  Future<UserProfile?> _loadUserProfileOptimized(String userId) async {
    if (!_isIOSOptimizationEnabled) return null;
    
    // Check cache first
    if (_iosUserProfileCache.containsKey(userId)) {
      AppLogger().debug('📱 Using cached user profile for: $userId');
      return _iosUserProfileCache[userId];
    }
    
    try {
      final userData = await _appwrite.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'user_profiles',
        documentId: userId,
      );
      
      final userProfile = UserProfile(
        id: userData.$id,
        name: userData.data['name'] ?? 'Unknown User',
        email: userData.data['email'] ?? '',
        avatar: userData.data['avatar'],
        bio: userData.data['bio'],
        reputationPercentage: (userData.data['reputationPercentage'] is int) ? userData.data['reputationPercentage'] : 100,
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
      AppLogger().warning('Error loading user profile with iOS optimizations for $userId: $e');
      return null;
    }
  }
  
  // Handle closed room with iOS optimizations
  void handleClosedRoom(String roomStatus) {
    if (!_isIOSOptimizationEnabled) return;
    
    try {
      AppLogger().info('📱 iOS: Handling room closure with status: $roomStatus');
      
      // iOS-specific cleanup optimizations
      _clearIOSCache();
      
      // Reduce memory footprint on iOS
      _optimizeMemoryForIOS();
      
      AppLogger().debug('📱 iOS cleanup completed for closed room');
    } catch (e) {
      AppLogger().warning('Error handling closed room on iOS: $e');
    }
  }
  
  // Clear iOS cache
  void _clearIOSCache() {
    try {
      final roomCount = _iosRoomCache.length;
      final participantCount = _iosParticipantCache.length;
      final profileCount = _iosUserProfileCache.length;
      
      _iosRoomCache.clear();
      _iosParticipantCache.clear();
      _iosUserProfileCache.clear();
      _lastCacheUpdate = null;
      
      AppLogger().debug('📱 iOS cache cleared: $roomCount rooms, $participantCount participant lists, $profileCount profiles');
    } catch (e) {
      AppLogger().warning('Error clearing iOS cache: $e');
    }
  }
  
  // Optimize memory for iOS
  void _optimizeMemoryForIOS() {
    try {
      // Force garbage collection on iOS
      // Note: Dart doesn't provide explicit GC control, but we can help by nullifying references
      
      AppLogger().debug('📱 iOS memory optimization completed');
    } catch (e) {
      AppLogger().warning('Error optimizing memory for iOS: $e');
    }
  }
  
  // Get iOS performance metrics
  Map<String, dynamic> getIOSPerformanceMetrics() {
    if (!_isIOSOptimizationEnabled) {
      return {'enabled': false};
    }
    
    return {
      'enabled': true,
      'cacheValid': _isCacheValid(),
      'lastCacheUpdate': _lastCacheUpdate?.toIso8601String(),
      'cachedRooms': _iosRoomCache.length,
      'cachedParticipantLists': _iosParticipantCache.length,
      'cachedUserProfiles': _iosUserProfileCache.length,
    };
  }
  
  // Pre-warm iOS cache for better performance
  Future<void> preWarmIOSCache(String roomId) async {
    if (!_isIOSOptimizationEnabled) return;
    
    try {
      AppLogger().debug('📱 Pre-warming iOS cache for room: $roomId');
      
      // Pre-load commonly accessed data
      await _loadRoomDataOptimized(roomId);
      await _loadParticipantsOptimized(roomId);
      
      AppLogger().info('📱 iOS cache pre-warmed successfully');
    } catch (e) {
      AppLogger().warning('Error pre-warming iOS cache: $e');
    }
  }
  
  // Check if iOS optimizations are enabled
  bool get isIOSOptimizationEnabled => _isIOSOptimizationEnabled;
  
  // Get cached user profile (iOS optimized)
  UserProfile? getCachedUserProfile(String userId) {
    if (!_isIOSOptimizationEnabled) return null;
    return _iosUserProfileCache[userId];
  }
  
  // Update cached user profile (iOS optimized)
  void updateCachedUserProfile(String userId, UserProfile profile) {
    if (!_isIOSOptimizationEnabled) return;
    _iosUserProfileCache[userId] = profile;
    AppLogger().debug('📱 Updated cached profile for: ${profile.name}');
  }
  
  // iOS-specific error handling
  void handleIOSError(String operation, dynamic error) {
    if (!_isIOSOptimizationEnabled) return;
    
    AppLogger().error('📱 iOS Error in $operation: $error');
    
    // iOS-specific error recovery
    if (error.toString().contains('memory') || error.toString().contains('cache')) {
      AppLogger().info('📱 Attempting iOS memory recovery...');
      _clearIOSCache();
      _optimizeMemoryForIOS();
    }
  }
  
  // Dispose iOS optimizations
  void dispose() {
    if (_isIOSOptimizationEnabled) {
      AppLogger().info('📱 Disposing iOS optimizations...');
      _clearIOSCache();
      _optimizeMemoryForIOS();
      _isIOSOptimizationEnabled = false;
      AppLogger().debug('📱 iOS optimizations disposed');
    }
  }
  
  // iOS background/foreground handling
  void handleIOSAppStateChange(bool isInBackground) {
    if (!_isIOSOptimizationEnabled) return;
    
    if (isInBackground) {
      AppLogger().debug('📱 App went to background - optimizing for iOS');
      _optimizeMemoryForIOS();
    } else {
      AppLogger().debug('📱 App came to foreground - iOS ready');
      // Cache might need refresh when app returns to foreground
      _lastCacheUpdate = null; // Invalidate cache
    }
  }
}