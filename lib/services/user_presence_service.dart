import 'dart:async';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

/// Service for tracking user online/offline presence
/// Updates lastSeen timestamp periodically while app is active
class UserPresenceService {
  static final UserPresenceService _instance = UserPresenceService._internal();
  factory UserPresenceService() => _instance;
  UserPresenceService._internal();

  final AppwriteService _appwrite = AppwriteService();
  Timer? _presenceTimer;
  String? _currentUserId;
  bool _isActive = false;

  /// Start tracking user presence
  /// Updates lastSeen every 2 minutes while app is active
  void startTracking(String userId) {
    if (_currentUserId == userId && _isActive) {
      return; // Already tracking this user
    }

    stopTracking(); // Stop any existing tracking

    _currentUserId = userId;
    _isActive = true;

    // Update immediately
    _updatePresence();

    // Update every 2 minutes
    _presenceTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _updatePresence(),
    );

    AppLogger().info('👤 Started presence tracking for user: $userId');
  }

  /// Stop tracking user presence
  void stopTracking() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    _isActive = false;

    // Update one last time when going offline
    if (_currentUserId != null) {
      _updatePresence();
      AppLogger().info('👤 Stopped presence tracking for user: $_currentUserId');
    }

    _currentUserId = null;
  }

  /// Update the user's lastSeen timestamp
  Future<void> _updatePresence() async {
    if (_currentUserId == null) return;

    try {
      AppLogger().info('👤 Updating presence for user: $_currentUserId');
      await _appwrite.updateLastSeen(_currentUserId!);
      AppLogger().info('👤 Presence updated successfully');
    } catch (e) {
      AppLogger().error('Failed to update presence: $e');
      // Don't rethrow - presence updates should be silent
    }
  }

  /// Manually trigger a presence update
  Future<void> updateNow() async {
    await _updatePresence();
  }

  /// Check if currently tracking
  bool get isTracking => _isActive && _currentUserId != null;

  /// Get current tracked user ID
  String? get currentUserId => _currentUserId;

  /// Dispose resources
  void dispose() {
    stopTracking();
  }
}
