import 'dart:async';
import 'package:livekit_client/livekit_client.dart';
import '../core/logging/app_logger.dart';

/// Centralized LiveKit track management system
/// Handles track lifecycle, memory management, and resource cleanup
class LiveKitTrackManager {
  static final LiveKitTrackManager _instance = LiveKitTrackManager._internal();
  factory LiveKitTrackManager() => _instance;
  LiveKitTrackManager._internal();

  final AppLogger _logger = AppLogger();

  // Track registry for memory management
  final Map<String, TrackInfo> _localTracks = {};
  final Map<String, Map<String, TrackInfo>> _remoteTracks = {};
  final Map<String, RoomTrackState> _roomStates = {};

  // Disposal tracking
  final Set<String> _disposingTracks = {};
  final Set<String> _disposingRooms = {};

  // Performance monitoring
  int _totalTracksCreated = 0;
  int _totalTracksDisposed = 0;
  final Map<String, DateTime> _trackCreationTimes = {};

  /// Initialize track management for a room
  void initializeRoom(String roomId, String roomType) {
    if (_roomStates.containsKey(roomId)) {
      _logger.warning('🔄 Room $roomId already initialized, cleaning up first');
      cleanupRoom(roomId);
    }

    _roomStates[roomId] = RoomTrackState(
      roomId: roomId,
      roomType: roomType,
      createdAt: DateTime.now(),
    );

    _remoteTracks[roomId] = {};
    _logger.info('🎬 Initialized track management for $roomType room: $roomId');
  }

  /// Register a local track
  void registerLocalTrack({
    required String roomId,
    required String trackId,
    required TrackPublication publication,
    required TrackType kind,
    String? userId,
  }) {
    final trackInfo = TrackInfo(
      trackId: trackId,
      roomId: roomId,
      publication: publication,
      kind: kind,
      userId: userId,
      isLocal: true,
      createdAt: DateTime.now(),
    );

    _localTracks[trackId] = trackInfo;
    _trackCreationTimes[trackId] = DateTime.now();
    _totalTracksCreated++;

    _logger.info('🎤 Registered local ${kind.name} track: $trackId (room: $roomId)');
    _updateRoomStats(roomId);
  }

  /// Register a remote track
  void registerRemoteTrack({
    required String roomId,
    required String participantId,
    required String trackId,
    required TrackPublication publication,
    required TrackType kind,
  }) {
    _remoteTracks[roomId] ??= {};

    final trackInfo = TrackInfo(
      trackId: trackId,
      roomId: roomId,
      publication: publication,
      kind: kind,
      userId: participantId,
      isLocal: false,
      createdAt: DateTime.now(),
    );

    _remoteTracks[roomId]![trackId] = trackInfo;
    _trackCreationTimes[trackId] = DateTime.now();
    _totalTracksCreated++;

    _logger.info('🔊 Registered remote ${kind.name} track: $trackId from $participantId (room: $roomId)');
    _updateRoomStats(roomId);
  }

  /// Unregister and dispose a local track
  Future<void> unregisterLocalTrack(String trackId, {bool forceDispose = false}) async {
    final trackInfo = _localTracks[trackId];
    if (trackInfo == null) {
      _logger.warning('⚠️ Attempted to unregister unknown local track: $trackId');
      return;
    }

    if (_disposingTracks.contains(trackId) && !forceDispose) {
      _logger.debug('⏳ Track $trackId already being disposed');
      return;
    }

    _disposingTracks.add(trackId);

    try {
      await _disposeTrackSafely(trackInfo);
      _localTracks.remove(trackId);
      _trackCreationTimes.remove(trackId);
      _totalTracksDisposed++;

      _logger.info('✅ Unregistered local track: $trackId');
      _updateRoomStats(trackInfo.roomId);
    } catch (e) {
      _logger.error('❌ Error unregistering local track $trackId: $e');
    } finally {
      _disposingTracks.remove(trackId);
    }
  }

  /// Unregister and dispose a remote track
  Future<void> unregisterRemoteTrack(String roomId, String trackId, {bool forceDispose = false}) async {
    final roomTracks = _remoteTracks[roomId];
    if (roomTracks == null) {
      _logger.warning('⚠️ No tracks found for room: $roomId');
      return;
    }

    final trackInfo = roomTracks[trackId];
    if (trackInfo == null) {
      _logger.warning('⚠️ Attempted to unregister unknown remote track: $trackId');
      return;
    }

    if (_disposingTracks.contains(trackId) && !forceDispose) {
      _logger.debug('⏳ Track $trackId already being disposed');
      return;
    }

    _disposingTracks.add(trackId);

    try {
      await _disposeTrackSafely(trackInfo);
      roomTracks.remove(trackId);
      _trackCreationTimes.remove(trackId);
      _totalTracksDisposed++;

      _logger.info('✅ Unregistered remote track: $trackId from room: $roomId');
      _updateRoomStats(roomId);
    } catch (e) {
      _logger.error('❌ Error unregistering remote track $trackId: $e');
    } finally {
      _disposingTracks.remove(trackId);
    }
  }

  /// Cleanup all tracks for a participant
  Future<void> cleanupParticipantTracks(String roomId, String participantId) async {
    final roomTracks = _remoteTracks[roomId];
    if (roomTracks == null) return;

    final participantTracks = roomTracks.entries
        .where((entry) => entry.value.userId == participantId)
        .map((entry) => entry.key)
        .toList();

    _logger.info('🧹 Cleaning up ${participantTracks.length} tracks for participant: $participantId');

    final cleanupFutures = participantTracks.map((trackId) =>
        unregisterRemoteTrack(roomId, trackId));

    await Future.wait(cleanupFutures, eagerError: false);
  }

  /// Cleanup all tracks for a room
  Future<void> cleanupRoom(String roomId, {bool forceDispose = false}) async {
    if (_disposingRooms.contains(roomId) && !forceDispose) {
      _logger.debug('⏳ Room $roomId already being cleaned up');
      return;
    }

    _disposingRooms.add(roomId);

    try {
      _logger.info('🧹 Cleaning up all tracks for room: $roomId');

      // Cleanup local tracks for this room
      final localTracksToCleanup = _localTracks.entries
          .where((entry) => entry.value.roomId == roomId)
          .map((entry) => entry.key)
          .toList();

      // Cleanup remote tracks for this room
      final remoteTracks = _remoteTracks[roomId]?.keys.toList() ?? [];

      final totalTracks = localTracksToCleanup.length + remoteTracks.length;
      _logger.info('🧹 Found $totalTracks tracks to cleanup in room $roomId');

      // Cleanup local tracks
      final localCleanupFutures = localTracksToCleanup.map((trackId) =>
          unregisterLocalTrack(trackId, forceDispose: forceDispose));

      // Cleanup remote tracks
      final remoteCleanupFutures = remoteTracks.map((trackId) =>
          unregisterRemoteTrack(roomId, trackId, forceDispose: forceDispose));

      // Wait for all cleanup operations
      await Future.wait([
        ...localCleanupFutures,
        ...remoteCleanupFutures,
      ], eagerError: false);

      // Remove room state
      _remoteTracks.remove(roomId);
      _roomStates.remove(roomId);

      _logger.info('✅ Room cleanup completed: $roomId');
    } catch (e) {
      _logger.error('❌ Error during room cleanup $roomId: $e');
    } finally {
      _disposingRooms.remove(roomId);
    }
  }

  /// Get track statistics for a room
  Map<String, dynamic> getRoomStats(String roomId) {
    final roomState = _roomStates[roomId];
    if (roomState == null) return {};

    final localCount = _localTracks.values.where((t) => t.roomId == roomId).length;
    final remoteCount = _remoteTracks[roomId]?.length ?? 0;

    return {
      'roomId': roomId,
      'roomType': roomState.roomType,
      'localTracks': localCount,
      'remoteTracks': remoteCount,
      'totalTracks': localCount + remoteCount,
      'uptime': DateTime.now().difference(roomState.createdAt).inSeconds,
      'lastActivity': roomState.lastActivity?.toIso8601String(),
    };
  }

  /// Get global track statistics
  Map<String, dynamic> getGlobalStats() {
    final activeLocalTracks = _localTracks.length;
    final activeRemoteTracks = _remoteTracks.values
        .map((room) => room.length)
        .fold(0, (sum, count) => sum + count);

    return {
      'totalTracksCreated': _totalTracksCreated,
      'totalTracksDisposed': _totalTracksDisposed,
      'activeLocalTracks': activeLocalTracks,
      'activeRemoteTracks': activeRemoteTracks,
      'activeRooms': _roomStates.length,
      'disposingTracks': _disposingTracks.length,
      'disposingRooms': _disposingRooms.length,
      'memoryEfficiency': _calculateMemoryEfficiency(),
    };
  }

  /// Check for track leaks (tracks that have been active too long)
  List<String> detectTrackLeaks({Duration threshold = const Duration(hours: 1)}) {
    final now = DateTime.now();
    final leakedTracks = <String>[];

    for (final entry in _trackCreationTimes.entries) {
      final trackId = entry.key;
      final creationTime = entry.value;

      if (now.difference(creationTime) > threshold) {
        leakedTracks.add(trackId);
      }
    }

    if (leakedTracks.isNotEmpty) {
      _logger.warning('🚨 Detected ${leakedTracks.length} potential track leaks');
    }

    return leakedTracks;
  }

  /// Force cleanup of leaked tracks
  Future<void> cleanupLeakedTracks() async {
    final leakedTracks = detectTrackLeaks();
    if (leakedTracks.isEmpty) return;

    _logger.warning('🧹 Force cleaning ${leakedTracks.length} leaked tracks');

    for (final trackId in leakedTracks) {
      // Try to find and dispose the track
      if (_localTracks.containsKey(trackId)) {
        await unregisterLocalTrack(trackId, forceDispose: true);
      } else {
        // Search in remote tracks
        for (final roomTracks in _remoteTracks.values) {
          if (roomTracks.containsKey(trackId)) {
            final trackInfo = roomTracks[trackId]!;
            await unregisterRemoteTrack(trackInfo.roomId, trackId, forceDispose: true);
            break;
          }
        }
      }
    }
  }

  /// Safely dispose a track with error handling
  Future<void> _disposeTrackSafely(TrackInfo trackInfo) async {
    try {
      final track = trackInfo.publication.track;
      if (track != null) {
        await track.dispose();
        _logger.debug('🗑️ Disposed track: ${trackInfo.trackId}');
      }
    } catch (e) {
      _logger.error('❌ Error disposing track ${trackInfo.trackId}: $e');
      // Don't rethrow - we still want to remove from registry
    }
  }

  /// Update room activity timestamp
  void _updateRoomStats(String roomId) {
    final roomState = _roomStates[roomId];
    if (roomState != null) {
      roomState.lastActivity = DateTime.now();
    }
  }

  /// Calculate memory efficiency percentage
  double _calculateMemoryEfficiency() {
    if (_totalTracksCreated == 0) return 100.0;
    return (_totalTracksDisposed / _totalTracksCreated) * 100;
  }

  /// Dispose the entire track manager
  Future<void> dispose() async {
    _logger.info('💥 Disposing LiveKit track manager');

    // Force cleanup all rooms
    final roomIds = _roomStates.keys.toList();
    final cleanupFutures = roomIds.map((roomId) => cleanupRoom(roomId, forceDispose: true));
    await Future.wait(cleanupFutures, eagerError: false);

    // Clear all state
    _localTracks.clear();
    _remoteTracks.clear();
    _roomStates.clear();
    _disposingTracks.clear();
    _disposingRooms.clear();
    _trackCreationTimes.clear();

    _logger.info('✅ Track manager disposed');
  }
}

/// Information about a registered track
class TrackInfo {
  final String trackId;
  final String roomId;
  final TrackPublication publication;
  final TrackType kind;
  final String? userId;
  final bool isLocal;
  final DateTime createdAt;

  TrackInfo({
    required this.trackId,
    required this.roomId,
    required this.publication,
    required this.kind,
    this.userId,
    required this.isLocal,
    required this.createdAt,
  });

  @override
  String toString() => 'TrackInfo(id: $trackId, room: $roomId, kind: ${kind.name}, local: $isLocal, user: $userId)';
}

/// State tracking for a room's tracks
class RoomTrackState {
  final String roomId;
  final String roomType;
  final DateTime createdAt;
  DateTime? lastActivity;

  RoomTrackState({
    required this.roomId,
    required this.roomType,
    required this.createdAt,
  }) : lastActivity = createdAt;
}