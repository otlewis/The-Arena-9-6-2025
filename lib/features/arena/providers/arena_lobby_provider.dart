import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';
import 'dart:async';
import '../../../services/supabase_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/providers/app_providers.dart';

/// Arena room data model
class ArenaRoom {
  final String id;
  final String topic;
  final String status;
  final String? challengeId;
  final String? description;
  final String? category;
  final int teamSize;
  final DateTime createdAt;
  final int currentParticipants;
  final bool isManual;
  final String? moderatorId;
  final Map<String, dynamic>? moderatorProfile;
  final Map<String, dynamic>? affirmativeDebater;
  final Map<String, dynamic>? negativeDebater;
  final Map<String, dynamic>? affirmative2Debater;
  final Map<String, dynamic>? negative2Debater;
  final Map<String, dynamic>? judge1Profile;
  final Map<String, dynamic>? judge2Profile;
  final Map<String, dynamic>? judge3Profile;
  final bool enablePlayback;

  const ArenaRoom({
    required this.id,
    required this.topic,
    required this.status,
    this.challengeId,
    this.description,
    this.category,
    required this.teamSize,
    required this.createdAt,
    required this.currentParticipants,
    required this.isManual,
    this.moderatorId,
    this.moderatorProfile,
    this.affirmativeDebater,
    this.negativeDebater,
    this.affirmative2Debater,
    this.negative2Debater,
    this.judge1Profile,
    this.judge2Profile,
    this.judge3Profile,
    this.enablePlayback = false,
  });

  factory ArenaRoom.fromMap(Map<String, dynamic> map) {
    return ArenaRoom(
      id: map['id'] ?? '',
      topic: map['topic'] ?? 'Debate Topic',
      status: map['status'] ?? 'waiting',
      challengeId: map['challenge_id'],
      description: map['description'],
      category: map['category'],
      teamSize: map['team_size'] ?? 1, // Default to 1v1 for backwards compatibility
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      currentParticipants: map['current_participants'] ?? 0,
      isManual: (map['challenge_id'] ?? '').isEmpty,
      moderatorId: map['moderator_id'],
      moderatorProfile: map['moderatorProfile'] as Map<String, dynamic>?,
      affirmativeDebater: map['affirmativeDebater'] as Map<String, dynamic>?,
      negativeDebater: map['negativeDebater'] as Map<String, dynamic>?,
      affirmative2Debater: map['affirmative2Debater'] as Map<String, dynamic>?,
      negative2Debater: map['negative2Debater'] as Map<String, dynamic>?,
      judge1Profile: map['judge1Profile'] as Map<String, dynamic>?,
      judge2Profile: map['judge2Profile'] as Map<String, dynamic>?,
      judge3Profile: map['judge3Profile'] as Map<String, dynamic>?,
      enablePlayback: map['enablePlayback'] ?? false,
    );
  }

  ArenaRoom copyWith({
    String? id,
    String? topic,
    String? status,
    String? challengeId,
    String? description,
    String? category,
    int? teamSize,
    DateTime? createdAt,
    int? currentParticipants,
    bool? isManual,
    String? moderatorId,
    Map<String, dynamic>? moderatorProfile,
    Map<String, dynamic>? affirmativeDebater,
    Map<String, dynamic>? negativeDebater,
    Map<String, dynamic>? affirmative2Debater,
    Map<String, dynamic>? negative2Debater,
    Map<String, dynamic>? judge1Profile,
    Map<String, dynamic>? judge2Profile,
    Map<String, dynamic>? judge3Profile,
    bool? enablePlayback,
  }) {
    return ArenaRoom(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      status: status ?? this.status,
      challengeId: challengeId ?? this.challengeId,
      description: description ?? this.description,
      category: category ?? this.category,
      teamSize: teamSize ?? this.teamSize,
      createdAt: createdAt ?? this.createdAt,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      isManual: isManual ?? this.isManual,
      moderatorId: moderatorId ?? this.moderatorId,
      moderatorProfile: moderatorProfile ?? this.moderatorProfile,
      affirmativeDebater: affirmativeDebater ?? this.affirmativeDebater,
      negativeDebater: negativeDebater ?? this.negativeDebater,
      affirmative2Debater: affirmative2Debater ?? this.affirmative2Debater,
      negative2Debater: negative2Debater ?? this.negative2Debater,
      judge1Profile: judge1Profile ?? this.judge1Profile,
      judge2Profile: judge2Profile ?? this.judge2Profile,
      judge3Profile: judge3Profile ?? this.judge3Profile,
      enablePlayback: enablePlayback ?? this.enablePlayback,
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
  ArenaLobbyNotifier(this._supabase, this._logger) : super(const ArenaLobbyState()) {
    _startPeriodicRefresh();
    _startRealtimeSubscription();
  }

  final SupabaseService _supabase;
  final AppLogger _logger;
  Timer? _refreshTimer;
  RealtimeChannel? _roomSubscription;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (_roomSubscription != null) {
      _supabase.client.removeChannel(_roomSubscription!);
    }
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

  /// Start real-time subscription for arena room status changes
  void _startRealtimeSubscription() {
    try {
      _logger.info('🔔 Starting real-time arena lobby subscription');

      // Clean up existing subscription
      if (_roomSubscription != null) {
        _supabase.client.removeChannel(_roomSubscription!);
      }

      _roomSubscription = _supabase.client
          .channel('arena_lobby_rooms')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'arena_rooms',
            callback: (payload) {
              if (!mounted) return;

              try {
                _logger.debug('🔔 Arena lobby real-time event: ${payload.eventType}');

                // Refresh lobby for any arena room changes
                _logger.debug('🔄 Arena room changed - refreshing lobby');
                loadActiveArenas(isBackgroundRefresh: true);
              } catch (e) {
                _logger.warning('⚠️ Error processing real-time event: $e');
              }
            },
          )
          .subscribe();

      _logger.info('✅ Arena lobby real-time subscription established');
    } catch (e) {
      _logger.error('❌ Failed to start arena lobby real-time subscription: $e');
      // Try to reconnect after a delay
      Timer(const Duration(seconds: 10), () {
        if (mounted) {
          _startRealtimeSubscription();
        }
      });
    }
  }

  Future<void> loadActiveArenas({bool isBackgroundRefresh = false}) async {
    try {
      if (isBackgroundRefresh) {
        state = state.copyWith(isRefreshing: true);
      } else {
        state = state.copyWith(isLoading: true, error: null);
      }

      // Get all arena rooms that are active or waiting (both challenge-based and manual)
      final challengeArenas = await _supabase.getActiveArenaRooms();
      final manualArenas = await _supabase.getJoinableArenaRooms();

      // Ensure proper typing for web compatibility (fix JSArray issues)
      final List<Map<String, dynamic>> typedChallengeArenas = 
          challengeArenas.cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> typedManualArenas = 
          manualArenas.cast<Map<String, dynamic>>();
      
      _logger.debug('📈 ARENA FETCH: Challenge arenas: ${typedChallengeArenas.length}, Manual arenas: ${typedManualArenas.length}');
      
      // Enhanced logging for debugging room visibility issues
      _logger.debug('🔍 CHALLENGE ARENAS:');
      for (final arena in typedChallengeArenas) {
        final id = arena['id'] ?? 'no-id';
        final topic = arena['topic'] ?? 'no-topic';
        final status = arena['status'] ?? 'no-status';
        final challengeId = arena['challenge_id'] ?? '';
        _logger.debug('   📋 $id: "$topic" [$status] ${challengeId.isEmpty ? "MANUAL" : "CHALLENGE"}');
      }
      
      _logger.debug('🔍 MANUAL ARENAS:');
      for (final arena in typedManualArenas) {
        final id = arena['id'] ?? 'no-id';
        final topic = arena['topic'] ?? 'no-topic';
        final status = arena['status'] ?? 'no-status';
        final challengeId = arena['challenge_id'] ?? '';
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
        final roomAge = DateTime.now().difference(DateTime.parse(arena['created_at'] ?? DateTime.now().toIso8601String()));
        final id = arena['id'] ?? 'no-id';
        final topic = arena['topic'] ?? 'no-topic';

        // Skip completed, closed, cleaning, or abandoned rooms UNLESS they have playback enabled
        if (['completed', 'abandoned', 'force_cleaned', 'force_closed', 'closing'].contains(status)) {
          final hasPlayback = arena['enablePlayback'] ?? false;
          _logger.info('🎬 LOBBY FILTER - Room $id: status="$status", enablePlayback=$hasPlayback');
          if (!hasPlayback) {
            _logger.info('   ❌ FILTERED OUT ($id): Status "$status" is excluded (no playback)');
            return false;
          } else {
            _logger.info('   ✅ KEPT ($id): Status "$status" but has playback enabled');
          }
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
    final moderatorFutures = <Future<dynamic>>[];
    final roomIds = <String>[];

    // Batch participant queries and moderator profile queries to reduce individual requests
    for (final arena in rooms) {
      final roomId = arena['id'] ?? '';
      final moderatorId = arena['moderator_id'] ?? arena['created_by'];
      if (roomId.isNotEmpty) {
        roomIds.add(roomId);
        participantFutures.add(_supabase.getArenaParticipants(roomId));
        
        // Fetch moderator profile if we have a moderator ID
        if (moderatorId != null && moderatorId.toString().isNotEmpty) {
          moderatorFutures.add(_supabase.getUserProfile(moderatorId.toString()));
        } else {
          moderatorFutures.add(Future.value(null));
        }
      }
    }

    // Execute all queries in parallel
    List<List<Map<String, dynamic>>> allParticipants;
    List<dynamic> allModerators;
    try {
      final results = await Future.wait([
        Future.wait(participantFutures),
        Future.wait(moderatorFutures),
      ]);
      allParticipants = results[0] as List<List<Map<String, dynamic>>>;
      allModerators = results[1];
    } catch (e) {
      _logger.warning('Error batch loading participants and moderators: $e');
      return activeRooms; // Return empty list if batch fails
    }

    // Process results
    for (int i = 0; i < rooms.length && i < allParticipants.length; i++) {
      final arena = rooms[i];
      final participants = allParticipants[i];
      final moderatorProfile = i < allModerators.length ? allModerators[i] : null;
      final roomId = roomIds[i];
      final status = arena['status'] ?? 'waiting';

      try {
        // Count participants - check for is_active being true or truthy (handles bool and string)
        final activeParticipants = participants.where((p) {
          final isActive = p['is_active'];
          return isActive == true || isActive == 'true' || isActive == 1;
        }).length;
        final totalParticipants = participants.length;
        final roomAge = DateTime.now().difference(DateTime.parse(arena['created_at'] ?? DateTime.now().toIso8601String()));

        _logger.debug('👥 PARTICIPANTS DEBUG: Room $roomId has $totalParticipants total, $activeParticipants active');

        // Debug participant details
        for (final p in participants) {
          _logger.debug('👥   - User ${p['user_id']}: role=${p['role']}, is_active=${p['is_active']}');
        }

        // Update the participant count - use total if active count is 0 (is_active might not be set)
        arena['current_participants'] = activeParticipants > 0 ? activeParticipants : totalParticipants;
        
        // Add moderator profile data
        if (moderatorProfile != null) {
          arena['moderatorProfile'] = {
            'name': moderatorProfile.name,
            'avatar': moderatorProfile.avatar,
            'email': moderatorProfile.email,
          };
          _logger.debug('👤 MODERATOR: Added profile for ${moderatorProfile.name} to room $roomId');
        } else {
          _logger.debug('👤 MODERATOR: No profile found for room $roomId');
        }

        // Extract debater profiles from participants
        for (final p in participants) {
          final role = p['role'] as String?;
          final userProfile = p['userProfile'] as Map<String, dynamic>?;

          if (userProfile != null) {
            final profileData = {
              'name': userProfile['name'] ?? userProfile['username'] ?? 'Unknown',
              'avatar': userProfile['avatar'],
              'id': p['user_id'],
            };

            if (role == 'affirmative') {
              arena['affirmativeDebater'] = profileData;
              _logger.debug('🎯 DEBATER: Added affirmative ${profileData['name']} to room $roomId');
            } else if (role == 'negative') {
              arena['negativeDebater'] = profileData;
              _logger.debug('🎯 DEBATER: Added negative ${profileData['name']} to room $roomId');
            } else if (role == 'affirmative2') {
              arena['affirmative2Debater'] = profileData;
              _logger.debug('🎯 DEBATER: Added affirmative2 ${profileData['name']} to room $roomId');
            } else if (role == 'negative2') {
              arena['negative2Debater'] = profileData;
              _logger.debug('🎯 DEBATER: Added negative2 ${profileData['name']} to room $roomId');
            } else if (role == 'judge1') {
              arena['judge1Profile'] = profileData;
              _logger.debug('⚖️ JUDGE: Added judge1 ${profileData['name']} to room $roomId');
            } else if (role == 'judge2') {
              arena['judge2Profile'] = profileData;
              _logger.debug('⚖️ JUDGE: Added judge2 ${profileData['name']} to room $roomId');
            } else if (role == 'judge3') {
              arena['judge3Profile'] = profileData;
              _logger.debug('⚖️ JUDGE: Added judge3 ${profileData['name']} to room $roomId');
            } else if (role == 'moderator') {
              // If moderator profile wasn't fetched via getUserProfile, use participant data
              if (arena['moderatorProfile'] == null) {
                arena['moderatorProfile'] = profileData;
                _logger.debug('👤 MODERATOR: Added moderator ${profileData['name']} from participants to room $roomId');
              }
            }
          }
        }

        // More permissive filtering logic - include most rooms to prevent users getting kicked
        bool shouldInclude = true; // Default to include

        _logger.debug('🔍 FILTER DEBUG: Room $roomId - status: $status, participants: $activeParticipants, age: ${roomAge.inMinutes}min');

        // Only exclude rooms that are definitely dead UNLESS they have playback enabled
        if (status == 'completed' || status == 'abandoned' || status == 'force_cleaned') {
          final hasPlayback = arena['enablePlayback'] ?? false;
          _logger.info('🎬 FINAL FILTER - Room $roomId: status="$status", enablePlayback=$hasPlayback');
          if (!hasPlayback) {
            shouldInclude = false;
            _logger.info('🔍 FILTER: Excluding completed/abandoned room (no playback)');
          } else {
            _logger.info('🔍 FILTER: Keeping completed room - has playback enabled');
          }
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
      final allRooms = await _supabase.client.from('arena_rooms').select();
      
      int cleanedCount = 0;
      
      for (final room in (allRooms as List)) {
        final roomId = room['id'];
        final status = room['status'] ?? 'waiting';
        final moderatorId = room['moderator_id'];
        final createdAt = DateTime.parse(room['created_at']);
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
            final participants = await _supabase.getArenaParticipants(roomId);
            final activeParticipants = participants.where((p) => p['is_active'] == true).length;
            
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
        // Check for completed or already closed rooms (but preserve playback-enabled ones)
        else if (['completed', 'abandoned', 'force_closed', 'force_cleaned'].contains(status)) {
          final hasPlayback = room['enablePlayback'] ?? false;
          if (!hasPlayback) {
            shouldCleanup = true;
            reason = 'Room already closed (status: $status, no playback)';
          }
        }
        
        if (shouldCleanup) {
          try {
            // Update room status to cleaned (only using existing schema fields)
            await _supabase.client.from('arena_rooms').update({
                'status': 'force_cleaned',
              },
            );
            
            // Remove all participants
            final participants = await _supabase.getArenaParticipants(roomId);
            for (final participant in participants) {
              try {
                await _supabase.client.from('arena_participants').delete().eq('id', participant['id'],
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