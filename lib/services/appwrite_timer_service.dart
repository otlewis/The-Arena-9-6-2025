import 'dart:async';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../models/timer_state.dart';
import '../config/timer_presets.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

/// Appwrite-based timer service for server-controlled synchronized timers
/// 
/// This service handles all timer operations through Appwrite Functions
/// and provides real-time updates via Appwrite Realtime subscriptions.
class AppwriteTimerService {
  static final AppwriteTimerService _instance = AppwriteTimerService._internal();
  factory AppwriteTimerService() => _instance;
  AppwriteTimerService._internal();

  final AppwriteService _appwriteService = AppwriteService();
  final Map<String, RealtimeSubscription> _activeSubscriptions = {};
  final Map<String, StreamController<List<TimerState>>> _roomStreamControllers = {};
  final Map<String, StreamController<TimerState?>> _timerStreamControllers = {};
  
  static const String _timersCollectionId = 'timers';
  static const String _eventsCollectionId = 'timer_events';
  static const String _timerControllerFunctionId = 'timer-controller';

  bool _isInitialized = false;

  /// Initialize the timer service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      AppLogger().info('🕐 AppwriteTimerService: Initializing...');
      _isInitialized = true;
      AppLogger().info('🕐 AppwriteTimerService: Initialized successfully');
    } catch (e) {
      AppLogger().error('🕐 AppwriteTimerService: Initialization failed: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Create a new timer
  Future<String> createTimer({
    required String roomId,
    required RoomType roomType,
    required TimerType timerType,
    required int durationSeconds,
    required String createdBy,
    String? currentSpeaker,
    String? title,
    Map<String, dynamic>? config,
  }) async {
    await _ensureInitialized();
    
    try {
      AppLogger().debug('🕐 Creating timer for room: $roomId');
      
      final response = await _appwriteService.functions.createExecution(
        functionId: _timerControllerFunctionId,
        body: jsonEncode({
          'action': 'create',
          'data': {
            'roomId': roomId,
            'roomType': roomType.name,
            'timerType': timerType.name,
            'durationSeconds': durationSeconds,
            'createdBy': createdBy,
            'currentSpeaker': currentSpeaker,
            'title': title,
            'config': config ?? _getDefaultConfig(roomType, timerType),
          }
        }),
        xasync: false,
      );

      final result = jsonDecode(response.responseBody);
      if (result['success'] == true) {
        final timerId = result['timer']['\$id'] as String;
        AppLogger().info('🕐 Timer created successfully: $timerId');
        return timerId;
      } else {
        throw Exception(result['error'] ?? 'Failed to create timer');
      }
    } catch (e) {
      AppLogger().error('🕐 Error creating timer: $e');
      rethrow;
    }
  }

  /// Start a timer
  Future<void> startTimer(String timerId, String userId) async {
    await _executeTimerAction('start', {
      'timerId': timerId,
      'userId': userId,
    });
  }

  /// Pause a timer
  Future<void> pauseTimer(String timerId, String userId) async {
    await _executeTimerAction('pause', {
      'timerId': timerId,
      'userId': userId,
    });
  }

  /// Stop a timer
  Future<void> stopTimer(String timerId, String userId) async {
    await _executeTimerAction('stop', {
      'timerId': timerId,
      'userId': userId,
    });
  }

  /// Reset a timer
  Future<void> resetTimer(String timerId, String userId) async {
    await _executeTimerAction('reset', {
      'timerId': timerId,
      'userId': userId,
    });
  }

  /// Add time to a timer
  Future<void> addTime(String timerId, int additionalSeconds, String userId) async {
    await _executeTimerAction('addTime', {
      'timerId': timerId,
      'additionalSeconds': additionalSeconds,
      'userId': userId,
    });
  }

  /// Execute a timer action via Appwrite Function
  Future<void> _executeTimerAction(String action, Map<String, dynamic> data) async {
    await _ensureInitialized();
    
    try {
      AppLogger().debug('🕐 Executing timer action: $action');
      
      final response = await _appwriteService.functions.createExecution(
        functionId: _timerControllerFunctionId,
        body: jsonEncode({
          'action': action,
          'data': data,
        }),
        xasync: false,
      );

      final result = jsonDecode(response.responseBody);
      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Timer action failed');
      }
      
      AppLogger().debug('🕐 Timer action completed: $action');
    } catch (e) {
      AppLogger().error('🕐 Error executing timer action $action: $e');
      rethrow;
    }
  }

  /// Get a stream of timer state for a specific timer
  Stream<TimerState?> getTimerStream(String timerId) {
    final key = 'timer_$timerId';
    
    if (_timerStreamControllers.containsKey(key)) {
      return _timerStreamControllers[key]!.stream;
    }

    final controller = StreamController<TimerState?>.broadcast();
    _timerStreamControllers[key] = controller;

    _subscribeToTimer(timerId, controller);
    
    return controller.stream;
  }

  /// Get a stream of all timers for a room
  Stream<List<TimerState>> getRoomTimersStream(String roomId) {
    final key = 'room_$roomId';
    
    if (_roomStreamControllers.containsKey(key)) {
      return _roomStreamControllers[key]!.stream;
    }

    final controller = StreamController<List<TimerState>>.broadcast();
    _roomStreamControllers[key] = controller;

    _subscribeToRoomTimers(roomId, controller);
    
    return controller.stream;
  }

  /// Subscribe to a specific timer's updates
  void _subscribeToTimer(String timerId, StreamController<TimerState?> controller) {
    final channel = 'databases.arena_db.collections.$_timersCollectionId.documents.$timerId';
    
    try {
      final subscription = _appwriteService.realtime.subscribe([channel]);
      
      subscription.stream.listen((response) {
        try {
          if (response.events.contains('databases.*.collections.*.documents.*.update') ||
              response.events.contains('databases.*.collections.*.documents.*.create')) {
            
            final timerData = response.payload;
            final timer = _mapToTimerState(timerData);
            controller.add(timer);
            
            AppLogger().debug('🕐 Timer updated: $timerId - ${timer.status.name}');
          } else if (response.events.contains('databases.*.collections.*.documents.*.delete')) {
            controller.add(null);
            AppLogger().debug('🕐 Timer deleted: $timerId');
          }
        } catch (e) {
          AppLogger().error('🕐 Error processing timer update: $e');
          controller.addError(e);
        }
      }, onError: (error) {
        AppLogger().error('🕐 Timer subscription error: $error');
        controller.addError(error);
      });

      _activeSubscriptions['timer_$timerId'] = subscription;
      
      // Load initial timer state
      _loadInitialTimerState(timerId, controller);
      
    } catch (e) {
      AppLogger().error('🕐 Failed to subscribe to timer $timerId: $e');
      controller.addError(e);
    }
  }

  /// Subscribe to all timers in a room
  void _subscribeToRoomTimers(String roomId, StreamController<List<TimerState>> controller) {
    const channel = 'databases.arena_db.collections.timers.documents';
    
    try {
      final subscription = _appwriteService.realtime.subscribe([channel]);
      
      subscription.stream.listen((response) {
        try {
          // Reload room timers when any timer changes
          _loadRoomTimers(roomId, controller);
        } catch (e) {
          AppLogger().error('🕐 Error processing room timers update: $e');
          controller.addError(e);
        }
      }, onError: (error) {
        AppLogger().error('🕐 Room timers subscription error: $error');
        controller.addError(error);
      });

      _activeSubscriptions['room_$roomId'] = subscription;
      
      // Load initial room timers
      _loadRoomTimers(roomId, controller);
      
    } catch (e) {
      AppLogger().error('🕐 Failed to subscribe to room timers $roomId: $e');
      controller.addError(e);
    }
  }

  /// Load initial timer state
  Future<void> _loadInitialTimerState(String timerId, StreamController<TimerState?> controller) async {
    try {
      final document = await _appwriteService.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: _timersCollectionId,
        documentId: timerId,
      );
      
      final timer = _mapToTimerState(document.data);
      controller.add(timer);
    } catch (e) {
      AppLogger().error('🕐 Failed to load initial timer state: $e');
      controller.add(null);
    }
  }

  /// Load all timers for a room
  Future<void> _loadRoomTimers(String roomId, StreamController<List<TimerState>> controller) async {
    try {
      final response = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: _timersCollectionId,
        queries: [
          Query.equal('roomId', roomId),
          Query.orderDesc('\$createdAt'),
          Query.limit(50),
        ],
      );
      
      final timers = response.documents
          .map((doc) => _mapToTimerState(doc.data))
          .toList();
      
      controller.add(timers);
    } catch (e) {
      AppLogger().error('🕐 Failed to load room timers: $e');
      controller.addError(e);
    }
  }

  /// Get active timers for a room
  Future<List<TimerState>> getActiveTimersForRoom(String roomId) async {
    try {
      final response = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: _timersCollectionId,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('isActive', true),
        ],
      );
      
      return response.documents
          .map((doc) => _mapToTimerState(doc.data))
          .toList();
    } catch (e) {
      AppLogger().error('🕐 Failed to get active timers: $e');
      return [];
    }
  }

  /// Delete a timer
  Future<void> deleteTimer(String timerId, String userId) async {
    try {
      await _appwriteService.databases.deleteDocument(
        databaseId: 'arena_db',
        collectionId: _timersCollectionId,
        documentId: timerId,
      );
      
      AppLogger().info('🕐 Timer deleted: $timerId');
    } catch (e) {
      AppLogger().error('🕐 Failed to delete timer: $e');
      rethrow;
    }
  }

  /// Get timer events/history
  Stream<List<Map<String, dynamic>>> getTimerEventsStream(String timerId) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    
    const channel = 'databases.arena_db.collections.timer_events.documents';
    
    try {
      final subscription = _appwriteService.realtime.subscribe([channel]);
      
      subscription.stream.listen((response) {
        _loadTimerEvents(timerId, controller);
      }, onError: (error) {
        controller.addError(error);
      });

      _loadTimerEvents(timerId, controller);
      
    } catch (e) {
      controller.addError(e);
    }
    
    return controller.stream;
  }

  /// Load timer events
  Future<void> _loadTimerEvents(String timerId, StreamController<List<Map<String, dynamic>>> controller) async {
    try {
      final response = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: _eventsCollectionId,
        queries: [
          Query.equal('timerId', timerId),
          Query.orderDesc('timestamp'),
          Query.limit(50),
        ],
      );
      
      final events = response.documents.map((doc) => doc.data).toList();
      controller.add(events);
    } catch (e) {
      controller.addError(e);
    }
  }

  /// Map Appwrite document to TimerState
  TimerState _mapToTimerState(Map<String, dynamic> data) {
    return TimerState(
      id: data['\$id'] ?? '',
      roomId: data['roomId'] ?? '',
      roomType: RoomType.values.firstWhere(
        (e) => e.name == data['roomType'],
        orElse: () => RoomType.openDiscussion,
      ),
      timerType: TimerType.values.firstWhere(
        (e) => e.name == data['timerType'],
        orElse: () => TimerType.general,
      ),
      status: TimerStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => TimerStatus.stopped,
      ),
      durationSeconds: data['durationSeconds'] ?? 0,
      remainingSeconds: data['remainingSeconds'] ?? 0,
      startTime: data['startTime'] != null ? DateTime.parse(data['startTime']) : null,
      pausedAt: data['pausedAt'] != null ? DateTime.parse(data['pausedAt']) : null,
      createdAt: data['\$createdAt'] != null ? DateTime.parse(data['\$createdAt']) : null,
      createdBy: data['createdBy'] ?? '',
      currentSpeaker: data['currentSpeaker'],
      description: data['title'],
      hasExpired: data['status'] == 'completed',
      soundEnabled: true,
      vibrationEnabled: true,
      metadata: data['config'],
    );
  }

  /// Get default configuration for timer type
  Map<String, dynamic> _getDefaultConfig(RoomType roomType, TimerType timerType) {
    final config = TimerPresets.getTimerConfig(roomType, timerType);
    if (config == null) return {};
    
    return {
      'allowPause': config.allowPause,
      'allowAddTime': config.allowAddTime,
      'warningThreshold': config.warningThresholdSeconds,
      'colors': {
        'primary': config.primaryColor,
        'warning': config.warningColor,
        'expired': config.expiredColor,
      },
    };
  }

  /// Check if user can control timers
  bool canControlTimer(TimerState timer, String userId, bool isModerator) {
    // Creator can always control their timer
    if (timer.createdBy == userId) return true;
    
    // Check room-specific moderator requirements
    final roomPreset = TimerPresets.getPresetForRoom(timer.roomType);
    if (roomPreset.moderatorOnly) {
      return isModerator;
    }

    return true;
  }

  /// Calculate precise remaining time for a running timer
  int calculateRemainingTime(TimerState timer) {
    // Always use the server's remainingSeconds as the source of truth
    // This eliminates calculation conflicts and timing issues
    return timer.remainingSeconds;
  }

  /// Ensure service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Dispose all subscriptions and streams
  void dispose() {
    AppLogger().info('🕐 AppwriteTimerService: Disposing...');
    
    for (final subscription in _activeSubscriptions.values) {
      subscription.close();
    }
    _activeSubscriptions.clear();

    for (final controller in _roomStreamControllers.values) {
      controller.close();
    }
    _roomStreamControllers.clear();

    for (final controller in _timerStreamControllers.values) {
      controller.close();
    }
    _timerStreamControllers.clear();
  }
}