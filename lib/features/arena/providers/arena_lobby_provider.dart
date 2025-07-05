import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../services/appwrite_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/providers/app_providers.dart';

/// Arena room data model
class ArenaRoom {
  final String id;
  final String topic;
  final String status;
  final String? challengeId;
  final String? description;
  final DateTime createdAt;
  final int currentParticipants;
  final bool isManual;
  final String? moderatorId;

  const ArenaRoom({
    required this.id,
    required this.topic,
    required this.status,
    this.challengeId,
    this.description,
    required this.createdAt,
    required this.currentParticipants,
    required this.isManual,
    this.moderatorId,
  });

  factory ArenaRoom.fromMap(Map<String, dynamic> map) {
    return ArenaRoom(
      id: map['id'] ?? '',
      topic: map['topic'] ?? 'Debate Topic',
      status: map['status'] ?? 'waiting',
      challengeId: map['challengeId'],
      description: map['description'],
      createdAt: DateTime.parse(map['\$createdAt'] ?? DateTime.now().toIso8601String()),
      currentParticipants: map['currentParticipants'] ?? 0,
      isManual: (map['challengeId'] ?? '').isEmpty,
      moderatorId: map['moderatorId'],
    );
  }

  ArenaRoom copyWith({
    String? id,
    String? topic,
    String? status,
    String? challengeId,
    String? description,
    DateTime? createdAt,
    int? currentParticipants,
    bool? isManual,
    String? moderatorId,
  }) {
    return ArenaRoom(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      status: status ?? this.status,
      challengeId: challengeId ?? this.challengeId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      isManual: isManual ?? this.isManual,
      moderatorId: moderatorId ?? this.moderatorId,
    );
  }
}

/// Arena lobby state
class ArenaLobbyState {
  final List<ArenaRoom> rooms;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final DateTime? lastCleanupTime;

  const ArenaLobbyState({
    this.rooms = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.lastCleanupTime,
  });

  ArenaLobbyState copyWith({
    List<ArenaRoom>? rooms,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    DateTime? lastCleanupTime,
  }) {
    return ArenaLobbyState(
      rooms: rooms ?? this.rooms,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error ?? this.error,
      lastCleanupTime: lastCleanupTime ?? this.lastCleanupTime,
    );
  }
}

/// Arena lobby state notifier
class ArenaLobbyNotifier extends StateNotifier<ArenaLobbyState> {
  ArenaLobbyNotifier(this._appwrite, this._logger) : super(const ArenaLobbyState()) {
    _startPeriodicRefresh();
  }

  final AppwriteService _appwrite;
  final AppLogger _logger;
  Timer? _refreshTimer;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    // Refresh every 45 seconds to keep the arena list current
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (mounted) {
        loadActiveArenas(isBackgroundRefresh: true);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> loadActiveArenas({bool isBackgroundRefresh = false}) async {
    try {
      if (isBackgroundRefresh) {
        state = state.copyWith(isRefreshing: true);
      } else {
        state = state.copyWith(isLoading: true, error: null);
      }

      // Get all arena rooms that are active or waiting (both challenge-based and manual)
      final challengeArenas = await _appwrite.getActiveArenaRooms();
      final manualArenas = await _appwrite.getJoinableArenaRooms();

      // Ensure proper typing for web compatibility (fix JSArray issues)
      final List<Map<String, dynamic>> typedChallengeArenas = 
          challengeArenas.cast<Map<String, dynamic>>() ?? [];
      final List<Map<String, dynamic>> typedManualArenas = 
          manualArenas.cast<Map<String, dynamic>>() ?? [];
      
      _logger.debug('📈 ARENA FETCH: Challenge arenas: ${typedChallengeArenas.length}, Manual arenas: ${typedManualArenas.length}');
      
      // Enhanced logging for debugging room visibility issues
      _logger.debug('🔍 CHALLENGE ARENAS:');
      for (final arena in typedChallengeArenas) {
        final id = arena['id'] ?? 'no-id';
        final topic = arena['topic'] ?? 'no-topic';
        final status = arena['status'] ?? 'no-status';
        final challengeId = arena['challengeId'] ?? '';
        _logger.debug('   📋 $id: "$topic" [$status] ${challengeId.isEmpty ? "MANUAL" : "CHALLENGE"}');
      }
      
      _logger.debug('🔍 MANUAL ARENAS:');
      for (final arena in typedManualArenas) {
        final id = arena['id'] ?? 'no-id';
        final topic = arena['topic'] ?? 'no-topic';
        final status = arena['status'] ?? 'no-status';
        final challengeId = arena['challengeId'] ?? '';
        _logger.debug('   📋 $id: "$topic" [$status] ${challengeId.isEmpty ? "MANUAL" : "CHALLENGE"}');
      }

      // Combine both types of arenas and deduplicate by room ID
      final allArenas = [...typedChallengeArenas, ...typedManualArenas];
      
      // Deduplicate rooms by ID to prevent showing the same room multiple times
      final Map<String, Map<String, dynamic>> deduplicatedArenas = {};
      for (final arena in allArenas) {
        final roomId = arena['id'] ?? '';
        if (roomId.isNotEmpty && !deduplicatedArenas.containsKey(roomId)) {
          deduplicatedArenas[roomId] = arena;
        }
      }
      final uniqueArenas = deduplicatedArenas.values.toList();
      
      _logger.debug('🔍 Deduplicated from ${allArenas.length} to ${uniqueArenas.length} unique rooms');

      // Pre-filter rooms at the database level to reduce processing
      final preFilteredArenas = uniqueArenas.where((arena) {
        final status = arena['status'] ?? 'waiting';
        final roomAge = DateTime.now().difference(DateTime.parse(arena['\$createdAt']));
        final id = arena['id'] ?? 'no-id';
        final topic = arena['topic'] ?? 'no-topic';

        // Skip completed, closed, cleaning, or abandoned rooms
        if (['completed', 'abandoned', 'force_cleaned', 'force_closed', 'closing'].contains(status)) {
          _logger.debug('   ❌ FILTERED OUT ($id): Status "$status" is excluded');
          return false;
        }

        // Skip very old waiting rooms (older than 6 hours)
        if (status == 'waiting' && roomAge.inHours > 6) {
          _logger.debug('   ❌ FILTERED OUT ($id): Too old (${roomAge.inHours} hours)');
          return false;
        }

        _logger.debug('   ✅ KEPT ($id): "$topic" [$status] Age: ${roomAge.inMinutes}min');
        return true;
      }).toList();

      _logger.debug('🔍 Pre-filtered from ${uniqueArenas.length} to ${preFilteredArenas.length} rooms');

      // Batch process remaining rooms with participant data
      final activeRooms = await _batchProcessRooms(preFilteredArenas);

      state = state.copyWith(
        rooms: activeRooms,
        isLoading: false,
        isRefreshing: false,
        error: null,
      );

      _logger.debug('🔄 Arena lobby refreshed - ${activeRooms.length} active arenas');

      // Run cleanup in background after UI has loaded (non-blocking)
      if (!isBackgroundRefresh) {
        _runBackgroundCleanup();
      }
    } catch (e) {
      _logger.error('Error loading active arenas: $e');
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: e.toString(),
      );
    }
  }

  Future<List<ArenaRoom>> _batchProcessRooms(List<Map<String, dynamic>> rooms) async {
    final activeRooms = <ArenaRoom>[];
    final participantFutures = <Future<List<Map<String, dynamic>>>>[];
    final roomIds = <String>[];

    // Batch participant queries to reduce individual requests
    for (final arena in rooms) {
      final roomId = arena['id'] ?? '';
      if (roomId.isNotEmpty) {
        roomIds.add(roomId);
        participantFutures.add(_appwrite.getArenaParticipants(roomId));
      }
    }

    // Execute all participant queries in parallel
    List<List<Map<String, dynamic>>> allParticipants;
    try {
      allParticipants = await Future.wait(participantFutures);
    } catch (e) {
      _logger.warning('Error batch loading participants: $e');
      return activeRooms; // Return empty list if batch fails
    }

    // Process results
    for (int i = 0; i < rooms.length && i < allParticipants.length; i++) {
      final arena = rooms[i];
      final participants = allParticipants[i];
      final roomId = roomIds[i];
      final status = arena['status'] ?? 'waiting';

      try {
        final activeParticipants = participants.where((p) => p['isActive'] == true).length;
        final totalParticipants = participants.length;
        final roomAge = DateTime.now().difference(DateTime.parse(arena['\$createdAt']));

        _logger.debug('👥 PARTICIPANTS DEBUG: Room $roomId has $totalParticipants total, $activeParticipants active');
        
        // Debug participant details
        for (final p in participants) {
          _logger.debug('👥   - User ${p['userId']}: role=${p['role']}, isActive=${p['isActive']}');
        }

        // Update the participant count
        arena['currentParticipants'] = activeParticipants;

        // More permissive filtering logic - include most rooms to prevent users getting kicked
        bool shouldInclude = true; // Default to include

        _logger.debug('🔍 FILTER DEBUG: Room $roomId - status: $status, participants: $activeParticipants, age: ${roomAge.inMinutes}min');

        // Only exclude rooms that are definitely dead
        if (status == 'completed' || status == 'abandoned' || status == 'force_cleaned') {
          shouldInclude = false;
          _logger.debug('🔍 FILTER: Excluding completed/abandoned room');
        } else if (status == 'waiting' && roomAge.inHours > 12 && activeParticipants == 0) {
          // Only exclude very old waiting rooms with no participants (12+ hours)
          shouldInclude = false;
          _logger.debug('🔍 FILTER: Excluding very old empty room');
        } else {
          _logger.debug('🔍 FILTER: Including room - status: $status, participants: $activeParticipants, age: ${roomAge.inMinutes}min');
        }

        if (shouldInclude) {
          activeRooms.add(ArenaRoom.fromMap(arena));
          _logger.info('Including room: $roomId ($activeParticipants participants, $status, ${roomAge.inMinutes}min)');
        } else {
          _logger.error('Filtering out room: $roomId (empty/old)');
        }
      } catch (e) {
        _logger.warning('Error processing room $roomId: $e');
        // Skip problematic rooms instead of including them
        continue;
      }
    }

    return activeRooms;
  }

  /// Run cleanup in background without blocking UI
  void _runBackgroundCleanup() async {
    
    // Only run cleanup if it hasn't been done recently (within last 5 minutes)
    final now = DateTime.now();
    if (state.lastCleanupTime != null && 
        now.difference(state.lastCleanupTime!).inMinutes < 5) {
      _logger.debug('🧹 Skipping cleanup - ran ${now.difference(state.lastCleanupTime!).inMinutes} minutes ago');
      return;
    }

    _logger.debug('🧹 Running background cleanup...');
    state = state.copyWith(lastCleanupTime: now);

    try {
      // Run cleanup without blocking UI
      await _cleanupAbandonedRooms();
    } catch (e) {
      _logger.error('Background cleanup error: $e');
    }
  }

  Future<void> _cleanupAbandonedRooms() async {
    try {
      _logger.debug('🧹 Starting arena room cleanup...');
      
      // Get all arena rooms (including inactive ones)
      final allRooms = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
      );
      
      int cleanedCount = 0;
      
      for (final room in allRooms.documents) {
        final roomId = room.$id;
        final status = room.data['status'] ?? 'waiting';
        final moderatorId = room.data['moderatorId'];
        final createdAt = DateTime.parse(room.$createdAt);
        final roomAge = DateTime.now().difference(createdAt);
        
        bool shouldCleanup = false;
        String reason = '';
        
        // Check for rooms without moderator (but give new rooms 2 hours grace period)
        if (moderatorId == null || moderatorId.isEmpty) {
          if (roomAge.inHours >= 2) {
            shouldCleanup = true;
            reason = 'No moderator assigned after 2 hours';
          }
        }
        // Check for very old rooms (older than 6 hours)
        else if (roomAge.inHours > 6) {
          shouldCleanup = true;
          reason = 'Room too old (${roomAge.inHours} hours)';
        }
        // Check for rooms without participants for more than 2 hours
        else if (status == 'waiting' && roomAge.inHours > 2) {
          try {
            final participants = await _appwrite.getArenaParticipants(roomId);
            final activeParticipants = participants.where((p) => p['isActive'] == true).length;
            
            if (activeParticipants == 0) {
              shouldCleanup = true;
              reason = 'No active participants for 2+ hours';
            }
          } catch (e) {
            _logger.warning('Error checking participants for room $roomId: $e');
          }
        }
        // Check for very old waiting rooms (older than 6 hours) regardless of moderator
        else if (status == 'waiting' && roomAge.inHours > 6) {
          shouldCleanup = true;
          reason = 'Waiting room too old (${roomAge.inHours} hours)';
        }
        // Check for completed or already closed rooms
        else if (['completed', 'abandoned', 'force_closed', 'force_cleaned'].contains(status)) {
          shouldCleanup = true;
          reason = 'Room already closed (status: $status)';
        }
        
        if (shouldCleanup) {
          try {
            // Update room status to cleaned (only using existing schema fields)
            await _appwrite.databases.updateDocument(
              databaseId: 'arena_db',
              collectionId: 'arena_rooms',
              documentId: roomId,
              data: {
                'status': 'force_cleaned',
              },
            );
            
            // Remove all participants
            final participants = await _appwrite.getArenaParticipants(roomId);
            for (final participant in participants) {
              try {
                await _appwrite.databases.deleteDocument(
                  databaseId: 'arena_db',
                  collectionId: 'arena_participants',
                  documentId: participant['id'],
                );
              } catch (e) {
                _logger.warning('Error removing participant ${participant['id']}: $e');
              }
            }
            
            cleanedCount++;
            _logger.debug('🧹 Cleaned up room $roomId: $reason');
            
          } catch (e) {
            _logger.error('Error cleaning up room $roomId: $e');
          }
        }
      }
      
      if (cleanedCount > 0) {
        _logger.info('Cleanup complete: $cleanedCount rooms cleaned');
      } else {
        _logger.info('No rooms needed cleanup');
      }
    } catch (e) {
      _logger.error('Error during room cleanup: $e');
    }
  }

  Future<void> refreshArenas() async {
    await loadActiveArenas();
  }
}

/// Arena lobby provider
final arenaLobbyProvider = StateNotifierProvider<ArenaLobbyNotifier, ArenaLobbyState>((ref) {
  final appwrite = ref.read(appwriteServiceProvider);
  final logger = ref.read(loggerProvider);
  return ArenaLobbyNotifier(appwrite, logger);
});

/// Convenience providers for easier access
final arenaRoomsProvider = Provider<List<ArenaRoom>>((ref) {
  return ref.watch(arenaLobbyProvider).rooms;
});

final isArenaLobbyLoadingProvider = Provider<bool>((ref) {
  return ref.watch(arenaLobbyProvider).isLoading;
});

final isArenaLobbyRefreshingProvider = Provider<bool>((ref) {
  return ref.watch(arenaLobbyProvider).isRefreshing;
});

final arenaLobbyErrorProvider = Provider<String?>((ref) {
  return ref.watch(arenaLobbyProvider).error;
});