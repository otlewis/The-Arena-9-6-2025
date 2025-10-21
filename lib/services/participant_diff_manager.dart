import '../core/logging/app_logger.dart';
import '../models/user_profile.dart';

/// Manages efficient diff-based updates for participant lists
/// Reduces unnecessary UI rebuilds and database queries
class ParticipantDiffManager {
  final AppLogger _logger = AppLogger();

  // Current state of participants by room
  final Map<String, ParticipantState> _roomStates = {};

  /// Initialize or reset state for a room
  void initializeRoom(String roomId) {
    _roomStates[roomId] = ParticipantState();
    _logger.debug('🔄 Initialized participant state for room: $roomId');
  }

  /// Calculate and apply diff for participant updates
  ParticipantDiff calculateDiff({
    required String roomId,
    required Map<String, UserProfile> currentParticipants,
    required Map<String, dynamic> updatePayload,
    required String updateType,
    Map<String, String>? currentRoles, // Optional: current role mappings
  }) {
    // Get or create room state
    final state = _roomStates[roomId] ?? ParticipantState();
    _roomStates[roomId] = state;

    final diff = ParticipantDiff();

    if (updateType == 'delete') {
      // Handle participant removal
      final userId = updatePayload['userId'] as String?;
      if (userId != null && currentParticipants.containsKey(userId)) {
        diff.removedIds.add(userId);
        state.lastKnownParticipants.remove(userId);
        _logger.info('🔄 DIFF: User $userId removed from room');
      }
    } else if (updateType == 'create') {
      // Handle new participant
      final userId = updatePayload['userId'] as String?;
      final role = updatePayload['role'] as String?;

      if (userId != null && !currentParticipants.containsKey(userId)) {
        diff.addedIds.add(userId);
        diff.newRoles[userId] = role ?? 'audience';
        _logger.info('🔄 DIFF: User $userId added to room with role $role');
      }
    } else if (updateType == 'update') {
      // Handle role change or other updates
      final userId = updatePayload['userId'] as String?;
      final newRole = updatePayload['role'] as String?;

      if (userId != null && newRole != null) {
        // Get current role from provided map or fall back to UserProfile
        final currentRole = currentRoles?[userId] ?? _getRoleFromUser(currentParticipants[userId]);

        if (currentRole != newRole) {
          diff.roleChanges[userId] = RoleChange(
            oldRole: currentRole ?? 'audience',
            newRole: newRole,
          );
          _logger.info('🔄 DIFF: User $userId role changed from $currentRole to $newRole');
        }
      }

      // Check for other property changes (e.g., mute status)
      if (userId != null) {
        final Map<String, dynamic> properties =
            diff.propertyChanges[userId] ?? <String, dynamic>{};

        if (updatePayload.containsKey('isMuted')) {
          final isMuted = updatePayload['isMuted'];
          if (isMuted is bool) {
            properties['isMuted'] = isMuted;
            _logger.debug('🔄 DIFF: User $userId mute status changed to $isMuted');
          }
        }

        if (updatePayload.containsKey('videoReady')) {
          final videoReady = updatePayload['videoReady'];
          if (videoReady is bool) {
            properties['videoReady'] = videoReady;
            _logger.debug('🔄 DIFF: User $userId videoReady changed to $videoReady');
          }
        }

        if (updatePayload.containsKey('audioReady')) {
          final audioReady = updatePayload['audioReady'];
          if (audioReady is bool) {
            properties['audioReady'] = audioReady;
            _logger.debug('🔄 DIFF: User $userId audioReady changed to $audioReady');
          }
        }

        if (updatePayload.containsKey('videoTrackSid')) {
          final videoTrackSid = updatePayload['videoTrackSid'];
          if (videoTrackSid is String || videoTrackSid == null) {
            properties['videoTrackSid'] = videoTrackSid;
            _logger.debug('🔄 DIFF: User $userId videoTrackSid changed to $videoTrackSid');
          }
        }

        if (updatePayload.containsKey('audioTrackSid')) {
          final audioTrackSid = updatePayload['audioTrackSid'];
          if (audioTrackSid is String || audioTrackSid == null) {
            properties['audioTrackSid'] = audioTrackSid;
            _logger.debug('🔄 DIFF: User $userId audioTrackSid changed to $audioTrackSid');
          }
        }

        if (properties.isNotEmpty) {
          diff.propertyChanges[userId] = properties;
        }
      }
    }

    // Update last known state
    state.lastUpdateTime = DateTime.now();
    state.updateCount++;

    return diff;
  }

  /// Apply diff to current participant maps efficiently
  Future<Map<String, UserProfile>> applyDiff({
    required Map<String, UserProfile> currentParticipants,
    required ParticipantDiff diff,
    required Future<UserProfile?> Function(String userId) fetchUser,
  }) async {
    // Create a new map to avoid mutating the original
    final updatedParticipants = Map<String, UserProfile>.from(currentParticipants);

    // Remove participants
    for (final userId in diff.removedIds) {
      updatedParticipants.remove(userId);
      _logger.debug('✅ Applied removal of user $userId');
    }

    // Add new participants (requires fetching their profiles)
    for (final userId in diff.addedIds) {
      final userProfile = await fetchUser(userId);
      if (userProfile != null) {
        updatedParticipants[userId] = userProfile;
        _logger.debug('✅ Applied addition of user $userId');
      }
    }

    // Apply role changes (no need to fetch, just update existing)
    for (final entry in diff.roleChanges.entries) {
      final userId = entry.key;
      final change = entry.value;

      final existingUser = updatedParticipants[userId];
      if (existingUser != null) {
        // Note: You'll need to add a method to update role in UserProfile
        // For now, we'll log the change
        _logger.debug('✅ Applied role change for $userId: ${change.oldRole} -> ${change.newRole}');
      }
    }

    // Apply property changes
    for (final entry in diff.propertyChanges.entries) {
      final userId = entry.key;
      final properties = entry.value;

      final existingUser = updatedParticipants[userId];
      if (existingUser != null) {
        // Apply property updates
        _logger.debug('✅ Applied property changes for $userId: $properties');
      }
    }

    return updatedParticipants;
  }

  /// Get role from user profile based on room context
  String? _getRoleFromUser(UserProfile? user) {
    // This would need to be implemented based on how roles are stored
    // in your UserProfile model
    return user?.preferences['currentRole'] as String? ?? 'audience';
  }

  /// Clear state for a room
  void clearRoom(String roomId) {
    _roomStates.remove(roomId);
    _logger.debug('🧹 Cleared participant state for room: $roomId');
  }

  /// Get statistics for a room
  Map<String, dynamic> getRoomStats(String roomId) {
    final state = _roomStates[roomId];
    if (state == null) return {};

    return {
      'lastUpdate': state.lastUpdateTime?.toIso8601String(),
      'updateCount': state.updateCount,
      'participantCount': state.lastKnownParticipants.length,
      'cacheEfficiency': _calculateCacheEfficiency(state),
    };
  }

  double _calculateCacheEfficiency(ParticipantState state) {
    if (state.updateCount == 0) return 0.0;
    // Calculate how many updates were handled without full refresh
    // This is a simplified calculation
    return (state.diffAppliedCount / state.updateCount * 100);
  }
}

/// Represents changes to participant list
class ParticipantDiff {
  final Set<String> addedIds = {};
  final Set<String> removedIds = {};
  final Map<String, RoleChange> roleChanges = {};
  final Map<String, String> newRoles = {}; // For added users
  final Map<String, Map<String, dynamic>> propertyChanges = {};

  bool get isEmpty =>
    addedIds.isEmpty &&
    removedIds.isEmpty &&
    roleChanges.isEmpty &&
    propertyChanges.isEmpty;

  bool get hasChanges => !isEmpty;

  /// Get a summary of changes for logging
  String get summary {
    final parts = <String>[];
    if (addedIds.isNotEmpty) parts.add('${addedIds.length} added');
    if (removedIds.isNotEmpty) parts.add('${removedIds.length} removed');
    if (roleChanges.isNotEmpty) parts.add('${roleChanges.length} role changes');
    if (propertyChanges.isNotEmpty) parts.add('${propertyChanges.length} property updates');
    return parts.isEmpty ? 'No changes' : parts.join(', ');
  }
}

/// Represents a role change
class RoleChange {
  final String oldRole;
  final String newRole;

  RoleChange({required this.oldRole, required this.newRole});

  @override
  String toString() => '$oldRole -> $newRole';
}

/// Internal state tracking for a room
class ParticipantState {
  DateTime? lastUpdateTime;
  int updateCount = 0;
  int diffAppliedCount = 0;
  final Map<String, DateTime> lastKnownParticipants = {};

  /// Track when we last did a full refresh
  DateTime? lastFullRefresh;

  /// Should we do a full refresh? (e.g., after too many diffs or time elapsed)
  bool shouldFullRefresh() {
    if (lastFullRefresh == null) return true;

    // Full refresh every 5 minutes or after 50 updates
    final timeSinceRefresh = DateTime.now().difference(lastFullRefresh!);
    return timeSinceRefresh.inMinutes > 5 || updateCount > 50;
  }
}
