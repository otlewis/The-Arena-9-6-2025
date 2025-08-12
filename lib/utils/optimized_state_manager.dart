import 'dart:async';
import 'package:flutter/material.dart';
import '../core/logging/app_logger.dart';

/// High-performance state manager for Arena screens
class OptimizedStateManager {
  static final Map<String, Timer?> _updateTimers = {};
  static final Map<String, dynamic> _lastStates = {};
  
  /// Batch state updates to prevent excessive rebuilds
  static void batchedSetState(
    String key,
    VoidCallback setState,
    dynamic currentState, {
    Duration delay = const Duration(milliseconds: 16), // 60fps
  }) {
    // Check if state actually changed
    if (_lastStates[key] != null && _statesEqual(_lastStates[key], currentState)) {
      return; // Skip unnecessary rebuilds
    }
    
    // Cancel existing timer
    _updateTimers[key]?.cancel();
    
    // Store the new state
    _lastStates[key] = currentState;
    
    // Schedule batched update
    _updateTimers[key] = Timer(delay, () {
      try {
        setState();
        _updateTimers.remove(key);
      } catch (e) {
        AppLogger().warning('Batched setState error for key $key: $e');
      }
    });
  }
  
  /// Check if two states are equal (shallow comparison)
  static bool _statesEqual(dynamic state1, dynamic state2) {
    if (state1 is List && state2 is List) {
      if (state1.length != state2.length) return false;
      for (int i = 0; i < state1.length; i++) {
        if (state1[i] != state2[i]) return false;
      }
      return true;
    }
    return state1 == state2;
  }
  
  /// Immediate setState for critical updates
  static void immediateSetState(VoidCallback setState) {
    try {
      setState();
    } catch (e) {
      AppLogger().warning('Immediate setState error: $e');
    }
  }
  
  /// Clear all timers for a specific key
  static void clearKey(String key) {
    _updateTimers[key]?.cancel();
    _updateTimers.remove(key);
    _lastStates.remove(key);
  }
  
  /// Clear all timers (call on dispose)
  static void clearAll() {
    for (var timer in _updateTimers.values) {
      timer?.cancel();
    }
    _updateTimers.clear();
    _lastStates.clear();
  }
}

/// Performance-optimized participant list manager
class OptimizedParticipantManager {
  static final Map<String, List<Map<String, dynamic>>> _cachedParticipants = {};
  static final Map<String, Set<String>> _participantIds = {};
  
  /// Check if participant list needs updating
  static bool shouldUpdateParticipants(
    String key,
    List<Map<String, dynamic>> newParticipants,
  ) {
    // Quick size check
    final cached = _cachedParticipants[key];
    if (cached == null || cached.length != newParticipants.length) {
      _updateCache(key, newParticipants);
      return true;
    }
    
    // Check participant IDs
    final newIds = newParticipants.map((p) => p['userId'] ?? p['id'] ?? '').toSet();
    final cachedIds = _participantIds[key];
    
    if (cachedIds == null || !cachedIds.containsAll(newIds) || !newIds.containsAll(cachedIds)) {
      _updateCache(key, newParticipants);
      return true;
    }
    
    return false; // No update needed
  }
  
  static void _updateCache(String key, List<Map<String, dynamic>> participants) {
    _cachedParticipants[key] = List.from(participants);
    _participantIds[key] = participants.map((p) => p['userId']?.toString() ?? p['id']?.toString() ?? '').toSet();
  }
  
  /// Clear cache for a specific key
  static void clearKey(String key) {
    _cachedParticipants.remove(key);
    _participantIds.remove(key);
  }
  
  /// Clear all caches
  static void clearAll() {
    _cachedParticipants.clear();
    _participantIds.clear();
  }
}

/// High-performance image cache manager
class OptimizedImageCache {
  static const int maxCacheSize = 100;
  static final Map<String, Widget> _widgetCache = {};
  static final List<String> _cacheOrder = [];
  
  /// Get or create cached avatar widget
  static Widget getCachedAvatar({
    required String userId,
    required String avatarUrl,
    required double size,
  }) {
    final key = '${userId}_${size.toInt()}';
    
    if (_widgetCache.containsKey(key)) {
      // Move to front of LRU
      _cacheOrder.remove(key);
      _cacheOrder.insert(0, key);
      return _widgetCache[key]!;
    }
    
    // Create new avatar widget
    final avatar = _createAvatarWidget(avatarUrl, size);
    
    // Add to cache
    _widgetCache[key] = avatar;
    _cacheOrder.insert(0, key);
    
    // Maintain cache size
    if (_cacheOrder.length > maxCacheSize) {
      final oldestKey = _cacheOrder.removeLast();
      _widgetCache.remove(oldestKey);
    }
    
    return avatar;
  }
  
  static Widget _createAvatarWidget(String avatarUrl, double size) {
    if (avatarUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: size * 0.6,
        ),
      );
    }
    
    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).round(),
        cacheHeight: (size * 2).round(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            color: Colors.grey[300],
            child: SizedBox(
              width: size * 0.4,
              height: size * 0.4,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person, 
              color: Colors.white, 
              size: size * 0.6,
            ),
          );
        },
      ),
    );
  }
  
  /// Clear all cached images
  static void clearAll() {
    _widgetCache.clear();
    _cacheOrder.clear();
  }
}

/// Performance utility functions
class PerformanceUtils {
  /// Throttle function calls
  static final Map<String, Timer?> _throttleTimers = {};
  
  static void throttle(String key, VoidCallback callback, Duration duration) {
    if (_throttleTimers[key]?.isActive ?? false) {
      return; // Skip this call
    }
    
    callback();
    _throttleTimers[key] = Timer(duration, () {
      _throttleTimers.remove(key);
    });
  }
  
  /// Debounce function calls
  static final Map<String, Timer?> _debounceTimers = {};
  
  static void debounce(String key, VoidCallback callback, Duration duration) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(duration, callback);
  }
  
  /// Clear all timers
  static void clearAll() {
    for (var timer in _throttleTimers.values) {
      timer?.cancel();
    }
    for (var timer in _debounceTimers.values) {
      timer?.cancel();
    }
    _throttleTimers.clear();
    _debounceTimers.clear();
  }
}