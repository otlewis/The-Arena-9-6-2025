import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../logging/app_logger.dart';
import '../error/app_error.dart';
import '../cache/cache_service.dart';
import '../../services/appwrite_service.dart';

/// Optimized database service with caching and batch operations
class OptimizedDatabaseService {
  static final OptimizedDatabaseService _instance = OptimizedDatabaseService._internal();
  factory OptimizedDatabaseService() => _instance;
  OptimizedDatabaseService._internal();

  final AppLogger _logger = AppLogger();
  final CacheService _cache = CacheService();
  late final AppwriteService _appwrite;

  void initialize(AppwriteService appwrite) {
    _appwrite = appwrite;
  }

  /// Safely convert Appwrite document data to Map with proper null handling
  Map<String, dynamic> _safeDocumentToMap(models.Document doc, {Map<String, dynamic>? additionalData}) {
    try {
      final result = <String, dynamic>{};
      
      // Safely copy document data
      if (doc.data.isNotEmpty) {
        doc.data.forEach((key, value) {
          result[key] = value; // Let null values pass through naturally
        });
      }
      
      // Add standard document fields
      result['id'] = doc.$id;
      result['createdAt'] = doc.$createdAt;
      result['updatedAt'] = doc.$updatedAt;
      
      // Add any additional data
      if (additionalData != null) {
        additionalData.forEach((key, value) {
          result[key] = value;
        });
      }
      
      return result;
    } catch (e) {
      _logger.warning('Error safely converting document ${doc.$id}: $e');
      // Return minimal safe data
      return {
        'id': doc.$id,
        'createdAt': doc.$createdAt,
        'updatedAt': doc.$updatedAt,
        ...?additionalData,
      };
    }
  }

  /// Batch get users with caching
  Future<List<Map<String, dynamic>>> batchGetUsers(
    List<String> userIds, {
    Duration? cacheMaxAge,
  }) async {
    try {
      final results = <Map<String, dynamic>>[];
      final uncachedIds = <String>[];

      // Check cache first
      for (final userId in userIds) {
        final cached = _cache.getCachedUser(userId, maxAge: cacheMaxAge ?? const Duration(hours: 1));
        if (cached != null) {
          results.add(cached);
        } else {
          uncachedIds.add(userId);
        }
      }

      // Batch fetch uncached users
      if (uncachedIds.isNotEmpty) {
        final fetchedUsers = await _batchFetchUsers(uncachedIds);
        results.addAll(fetchedUsers);

        // Cache the fetched users
        final cacheData = <String, Map<String, dynamic>>{};
        for (final user in fetchedUsers) {
          cacheData[user['id']] = user;
        }
        await _cache.cacheUsers(cacheData);
      }

      _logger.info('Batch loaded ${results.length} users (${uncachedIds.length} from API, ${userIds.length - uncachedIds.length} from cache)');
      return results;
    } catch (e, stackTrace) {
      _logger.error('Failed to batch get users', e, stackTrace);
      throw DataError(message: 'Failed to load users: $e');
    }
  }

  /// Batch fetch users from API
  Future<List<Map<String, dynamic>>> _batchFetchUsers(List<String> userIds) async {
    const batchSize = 25; // Appwrite query limit
    final results = <Map<String, dynamic>>[];

    for (int i = 0; i < userIds.length; i += batchSize) {
      final batch = userIds.skip(i).take(batchSize).toList();
      
      try {
        final response = await _appwrite.databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'users',
          queries: [
            Query.equal('\$id', batch),
            Query.limit(batchSize),
          ],
        );

        for (final doc in response.documents) {
          results.add(_safeDocumentToMap(doc));
        }
      } catch (e) {
        _logger.error('Failed to fetch user batch: $batch', e);
        // Continue with other batches instead of failing completely
      }
    }

    return results;
  }

  /// Optimized room list with pagination and caching
  Future<List<Map<String, dynamic>>> getRoomsPaginated({
    required int page,
    required int pageSize,
    String? status,
    String? category,
    Duration? cacheMaxAge,
  }) async {
    try {
      final cacheKey = 'rooms_${page}_${pageSize}_${status ?? 'all'}_${category ?? 'all'}';
      
      // Check cache first
      final cached = _cache.getCachedRoom(cacheKey, maxAge: cacheMaxAge ?? const Duration(minutes: 5));
      if (cached != null) {
        return List<Map<String, dynamic>>.from(cached['rooms']);
      }

      // Build queries
      final queries = <String>[
        Query.orderDesc('\$createdAt'),
        Query.limit(pageSize),
        Query.offset(page * pageSize),
      ];

      if (status != null) {
        queries.add(Query.equal('status', status));
      }

      if (category != null) {
        queries.add(Query.equal('category', category));
      }

      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'discussion_rooms',
        queries: queries,
      );

      final rooms = response.documents.map((doc) => _safeDocumentToMap(doc)).toList();

      // Cache the results
      await _cache.cacheRoom(cacheKey, {'rooms': rooms});

      _logger.info('Loaded ${rooms.length} rooms for page $page');
      return rooms;
    } catch (e, stackTrace) {
      _logger.error('Failed to get rooms paginated', e, stackTrace);
      throw DataError(message: 'Failed to load rooms: $e');
    }
  }

  /// Batch update participant ready status
  Future<void> batchUpdateParticipants(
    String roomId,
    Map<String, bool> readyStates,
  ) async {
    try {
      final futures = <Future>[];

      for (final entry in readyStates.entries) {
        final userId = entry.key;
        final isReady = entry.value;

        // Find participant document
        final participantFuture = _appwrite.databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'room_participants',
          queries: [
            Query.equal('roomId', roomId),
            Query.equal('userId', userId),
            Query.limit(1),
          ],
        ).then((response) async {
          if (response.documents.isNotEmpty) {
            return await _appwrite.databases.updateDocument(
              databaseId: 'arena_db',
              collectionId: 'room_participants',
              documentId: response.documents.first.$id,
              data: {'isReady': isReady},
            );
          }
          return null;
        });

        futures.add(participantFuture);
      }

      await Future.wait(futures);
      _logger.info('Batch updated ${readyStates.length} participant ready states');
    } catch (e, stackTrace) {
      _logger.error('Failed to batch update participants', e, stackTrace);
      throw DataError(message: 'Failed to update participants: $e');
    }
  }

  /// Get room with participants in single optimized call
  Future<Map<String, dynamic>> getRoomWithParticipants(String roomId) async {
    try {
      // Check cache first
      final cached = _cache.getCachedRoom('room_details_$roomId');
      if (cached != null) {
        return cached;
      }

      // Fetch room and participants in parallel
      final futures = await Future.wait([
        _appwrite.databases.getDocument(
          databaseId: 'arena_db',
          collectionId: 'discussion_rooms',
          documentId: roomId,
        ),
        _appwrite.databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'room_participants',
          queries: [
            Query.equal('roomId', roomId),
            Query.limit(100),
          ],
        ),
      ]);

      final roomDoc = futures[0] as models.Document;
      final participantsResponse = futures[1] as models.DocumentList;

      final roomData = _safeDocumentToMap(roomDoc);

      final participants = participantsResponse.documents.map((doc) => _safeDocumentToMap(doc)).toList();

      final result = {
        'room': roomData,
        'participants': participants,
      };

      // Cache the result
      await _cache.cacheRoom('room_details_$roomId', result);

      _logger.info('Loaded room $roomId with ${participants.length} participants');
      return result;
    } catch (e, stackTrace) {
      _logger.error('Failed to get room with participants', e, stackTrace);
      throw DataError(message: 'Failed to load room details: $e');
    }
  }

  /// Search users with optimized queries and caching
  Future<List<Map<String, dynamic>>> searchUsers({
    required String query,
    int limit = 20,
    List<String>? excludeIds,
  }) async {
    try {
      if (query.length < 2) return [];

      final cacheKey = 'search_users_${query.toLowerCase()}_${limit}_${excludeIds?.join(',') ?? ''}';
      
      // Check cache for recent searches
      final cached = _cache.getCachedUser(cacheKey, maxAge: const Duration(minutes: 5));
      if (cached != null) {
        return List<Map<String, dynamic>>.from(cached['users']);
      }

      final queries = <String>[
        Query.search('name', query),
        Query.limit(limit),
      ];

      if (excludeIds?.isNotEmpty == true) {
        queries.add(Query.notEqual('\$id', excludeIds!));
      }

      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: queries,
      );

      final users = response.documents.map((doc) => _safeDocumentToMap(doc)).toList();

      // Cache the search results
      await _cache.cacheUser(cacheKey, {'users': users});

      _logger.info('Found ${users.length} users for query: $query');
      return users;
    } catch (e, stackTrace) {
      _logger.error('Failed to search users', e, stackTrace);
      throw DataError(message: 'Failed to search users: $e');
    }
  }

  /// Optimized challenge loading with batch user fetching
  Future<List<Map<String, dynamic>>> getChallengesWithUsers(
    String userId,
    {int limit = 20}
  ) async {
    try {
      // Get challenges
      final challengesResponse = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'challenge_messages',
        queries: [
          Query.equal('challengedId', userId),
          Query.orderDesc('\$createdAt'),
          Query.limit(limit),
        ],
      );

      final challenges = challengesResponse.documents.map((doc) => _safeDocumentToMap(doc)).toList();

      if (challenges.isEmpty) return challenges;

      // Extract unique challenger IDs
      final challengerIds = challenges
          .map((c) => c['challengerId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet()
          .toList();

      // Batch fetch challenger details
      final challengerData = await batchGetUsers(challengerIds);
      final challengerMap = <String, Map<String, dynamic>>{};
      for (final user in challengerData) {
        challengerMap[user['id']] = user;
      }

      // Enhance challenges with user data
      for (final challenge in challenges) {
        final challengerId = challenge['challengerId'] as String?;
        if (challengerId != null && challengerMap.containsKey(challengerId)) {
          challenge['challengerData'] = challengerMap[challengerId];
        }
      }

      _logger.info('Loaded ${challenges.length} challenges with user data');
      return challenges;
    } catch (e, stackTrace) {
      _logger.error('Failed to get challenges with users', e, stackTrace);
      throw DataError(message: 'Failed to load challenges: $e');
    }
  }

  /// Clear specific cache entries
  Future<void> invalidateCache({
    String? roomId,
    String? userId,
    bool clearAll = false,
  }) async {
    try {
      if (clearAll) {
        await _cache.clearAllCache();
      } else {
        if (roomId != null) {
          await _cache.clearRoomCache();
        }
        if (userId != null) {
          await _cache.clearUserCache();
        }
      }
      _logger.info('Cache invalidated');
    } catch (e, stackTrace) {
      _logger.error('Failed to invalidate cache', e, stackTrace);
    }
  }
}