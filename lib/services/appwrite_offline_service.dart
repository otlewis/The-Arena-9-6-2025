import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/timer_state.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_timer_service.dart';

/// Offline handling service for Appwrite Timer System
/// 
/// Provides:
/// - Connection status monitoring
/// - Offline state caching
/// - Automatic sync when reconnected
/// - Optimistic updates with conflict resolution
class AppwriteOfflineService {
  static final AppwriteOfflineService _instance = AppwriteOfflineService._internal();
  factory AppwriteOfflineService() => _instance;
  AppwriteOfflineService._internal();

  final Connectivity _connectivity = Connectivity();
  final AppwriteTimerService _timerService = AppwriteTimerService();
  
  StreamController<bool>? _connectionStatusController;
  StreamController<OfflineStatus>? _offlineStatusController;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  bool _isConnected = true;
  bool _hasPendingActions = false;
  List<PendingTimerAction> _pendingActions = [];
  Map<String, TimerState> _offlineTimerCache = {};
  
  static const String _pendingActionsKey = 'pending_timer_actions';
  static const String _offlineTimerCacheKey = 'offline_timer_cache';

  /// Get connection status stream
  Stream<bool> get connectionStatus {
    _connectionStatusController ??= StreamController<bool>.broadcast();
    return _connectionStatusController!.stream;
  }

  /// Get offline status stream
  Stream<OfflineStatus> get offlineStatus {
    _offlineStatusController ??= StreamController<OfflineStatus>.broadcast();
    return _offlineStatusController!.stream;
  }

  /// Current connection state
  bool get isConnected => _isConnected;
  
  /// Has pending offline actions
  bool get hasPendingActions => _hasPendingActions;

  /// Initialize offline service
  Future<void> initialize() async {
    try {
      AppLogger().info('🔌 AppwriteOfflineService: Initializing...');
      
      // Load cached data
      await _loadCachedData();
      
      // Setup connectivity monitoring
      _setupConnectivityMonitoring();
      
      // Check initial connection status
      await _checkInitialConnection();
      
      AppLogger().info('🔌 AppwriteOfflineService: Initialized successfully');
    } catch (e) {
      AppLogger().error('🔌 AppwriteOfflineService: Initialization failed: $e');
      rethrow;
    }
  }

  /// Setup connectivity monitoring
  void _setupConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        _handleConnectivityChange([result]);
      },
      onError: (error) {
        AppLogger().error('🔌 Connectivity monitoring error: $error');
      },
    );
  }

  /// Check initial connection status
  Future<void> _checkInitialConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      _handleConnectivityChange([connectivityResult]);
    } catch (e) {
      AppLogger().error('🔌 Failed to check initial connection: $e');
      _updateConnectionStatus(false);
    }
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isConnected = results.any((result) => 
      result == ConnectivityResult.mobile || 
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet
    );
    
    AppLogger().debug('🔌 Connectivity changed: $isConnected');
    
    if (isConnected && !_isConnected) {
      // Reconnected - sync pending actions
      _onReconnected();
    } else if (!isConnected && _isConnected) {
      // Disconnected
      _onDisconnected();
    }
    
    _updateConnectionStatus(isConnected);
  }

  /// Update connection status
  void _updateConnectionStatus(bool isConnected) {
    _isConnected = isConnected;
    _connectionStatusController?.add(isConnected);
    
    _updateOfflineStatus();
  }

  /// Update offline status
  void _updateOfflineStatus() {
    final status = OfflineStatus(
      isConnected: _isConnected,
      hasPendingActions: _hasPendingActions,
      pendingActionsCount: _pendingActions.length,
      lastSyncTime: DateTime.now(),
    );
    
    _offlineStatusController?.add(status);
  }

  /// Handle disconnection
  void _onDisconnected() {
    AppLogger().info('🔌 Device disconnected - entering offline mode');
    // Any cleanup needed when going offline
  }

  /// Handle reconnection
  void _onReconnected() {
    AppLogger().info('🔌 Device reconnected - syncing pending actions');
    _syncPendingActions();
  }

  /// Queue an action for offline execution
  Future<void> queueTimerAction({
    required String action,
    required Map<String, dynamic> data,
    String? optimisticTimerId,
  }) async {
    final pendingAction = PendingTimerAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      action: action,
      data: data,
      timestamp: DateTime.now(),
      optimisticTimerId: optimisticTimerId,
    );
    
    _pendingActions.add(pendingAction);
    _hasPendingActions = true;
    
    await _savePendingActions();
    _updateOfflineStatus();
    
    AppLogger().debug('🔌 Queued offline action: $action');
    
    // Apply optimistic update if possible
    if (optimisticTimerId != null) {
      _applyOptimisticUpdate(pendingAction);
    }
  }

  /// Apply optimistic update to local cache
  void _applyOptimisticUpdate(PendingTimerAction action) {
    try {
      final timerId = action.optimisticTimerId;
      if (timerId == null || !_offlineTimerCache.containsKey(timerId)) return;
      
      final timer = _offlineTimerCache[timerId]!;
      TimerState updatedTimer;
      
      switch (action.action) {
        case 'start':
          updatedTimer = timer.copyWith(
            status: TimerStatus.running,
            startTime: DateTime.now(),
          );
          break;
          
        case 'pause':
          updatedTimer = timer.copyWith(
            status: TimerStatus.paused,
            pausedAt: DateTime.now(),
          );
          break;
          
        case 'stop':
          updatedTimer = timer.copyWith(
            status: TimerStatus.stopped,
            startTime: null,
            pausedAt: null,
          );
          break;
          
        case 'reset':
          updatedTimer = timer.copyWith(
            status: TimerStatus.stopped,
            remainingSeconds: timer.durationSeconds,
            startTime: null,
            pausedAt: null,
          );
          break;
          
        default:
          return; // No optimistic update for this action
      }
      
      _offlineTimerCache[timerId] = updatedTimer;
      _saveCachedTimers();
      
      AppLogger().debug('🔌 Applied optimistic update: ${action.action} for timer $timerId');
    } catch (e) {
      AppLogger().error('🔌 Failed to apply optimistic update: $e');
    }
  }

  /// Sync pending actions when reconnected
  Future<void> _syncPendingActions() async {
    if (_pendingActions.isEmpty) return;
    
    AppLogger().info('🔌 Syncing ${_pendingActions.length} pending actions...');
    
    final actionsToSync = List<PendingTimerAction>.from(_pendingActions);
    int successCount = 0;
    int failureCount = 0;
    
    for (final action in actionsToSync) {
      try {
        await _executePendingAction(action);
        _pendingActions.removeWhere((a) => a.id == action.id);
        successCount++;
        
        AppLogger().debug('🔌 Synced action: ${action.action}');
      } catch (e) {
        failureCount++;
        AppLogger().error('🔌 Failed to sync action ${action.action}: $e');
        
        // If action is too old (> 1 hour), remove it
        if (DateTime.now().difference(action.timestamp).inHours > 1) {
          _pendingActions.removeWhere((a) => a.id == action.id);
          AppLogger().info('🔌 Removed expired action: ${action.action}');
        }
      }
    }
    
    _hasPendingActions = _pendingActions.isNotEmpty;
    await _savePendingActions();
    _updateOfflineStatus();
    
    AppLogger().info('🔌 Sync completed: $successCount successful, $failureCount failed');
  }

  /// Execute a pending action
  Future<void> _executePendingAction(PendingTimerAction action) async {
    switch (action.action) {
      case 'create':
        await _timerService.createTimer(
          roomId: action.data['roomId'],
          roomType: RoomType.values.firstWhere((e) => e.name == action.data['roomType']),
          timerType: TimerType.values.firstWhere((e) => e.name == action.data['timerType']),
          durationSeconds: action.data['durationSeconds'],
          createdBy: action.data['createdBy'],
          currentSpeaker: action.data['currentSpeaker'],
          title: action.data['title'],
          config: action.data['config'],
        );
        break;
        
      case 'start':
        await _timerService.startTimer(action.data['timerId'], action.data['userId']);
        break;
        
      case 'pause':
        await _timerService.pauseTimer(action.data['timerId'], action.data['userId']);
        break;
        
      case 'stop':
        await _timerService.stopTimer(action.data['timerId'], action.data['userId']);
        break;
        
      case 'reset':
        await _timerService.resetTimer(action.data['timerId'], action.data['userId']);
        break;
        
      case 'addTime':
        await _timerService.addTime(
          action.data['timerId'],
          action.data['additionalSeconds'],
          action.data['userId'],
        );
        break;
        
      default:
        throw Exception('Unknown action: ${action.action}');
    }
  }

  /// Cache timer state for offline access
  Future<void> cacheTimerState(String timerId, TimerState timer) async {
    _offlineTimerCache[timerId] = timer;
    await _saveCachedTimers();
  }

  /// Get cached timer state
  TimerState? getCachedTimerState(String timerId) {
    return _offlineTimerCache[timerId];
  }

  /// Get all cached timers for a room
  List<TimerState> getCachedRoomTimers(String roomId) {
    return _offlineTimerCache.values
        .where((timer) => timer.roomId == roomId)
        .toList();
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    _offlineTimerCache.clear();
    _pendingActions.clear();
    _hasPendingActions = false;
    
    await _saveCachedTimers();
    await _savePendingActions();
    _updateOfflineStatus();
    
    AppLogger().info('🔌 Offline cache cleared');
  }

  /// Force sync now (if connected)
  Future<void> forceSyncNow() async {
    if (!_isConnected) {
      throw Exception('Cannot sync while offline');
    }
    
    await _syncPendingActions();
  }

  /// Save pending actions to storage
  Future<void> _savePendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final actionsJson = _pendingActions.map((a) => a.toJson()).toList();
      await prefs.setString(_pendingActionsKey, jsonEncode(actionsJson));
    } catch (e) {
      AppLogger().error('🔌 Failed to save pending actions: $e');
    }
  }

  /// Save cached timers to storage
  Future<void> _saveCachedTimers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timersJson = _offlineTimerCache.map(
        (key, timer) => MapEntry(key, timer.toJson()),
      );
      await prefs.setString(_offlineTimerCacheKey, jsonEncode(timersJson));
    } catch (e) {
      AppLogger().error('🔌 Failed to save cached timers: $e');
    }
  }

  /// Load cached data from storage
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load pending actions
      final actionsJson = prefs.getString(_pendingActionsKey);
      if (actionsJson != null) {
        final actionsList = jsonDecode(actionsJson) as List;
        _pendingActions = actionsList
            .map((json) => PendingTimerAction.fromJson(json))
            .toList();
        _hasPendingActions = _pendingActions.isNotEmpty;
      }
      
      // Load cached timers
      final timersJson = prefs.getString(_offlineTimerCacheKey);
      if (timersJson != null) {
        final timersMap = jsonDecode(timersJson) as Map<String, dynamic>;
        _offlineTimerCache = timersMap.map(
          (key, value) => MapEntry(key, TimerState.fromJson(value)),
        );
      }
      
      AppLogger().debug('🔌 Loaded cached data: ${_pendingActions.length} actions, ${_offlineTimerCache.length} timers');
    } catch (e) {
      AppLogger().error('🔌 Failed to load cached data: $e');
    }
  }

  /// Dispose the service
  void dispose() {
    AppLogger().info('🔌 AppwriteOfflineService: Disposing...');
    
    _connectivitySubscription?.cancel();
    _connectionStatusController?.close();
    _offlineStatusController?.close();
    
    _connectionStatusController = null;
    _offlineStatusController = null;
  }
}

/// Represents the current offline status
class OfflineStatus {
  final bool isConnected;
  final bool hasPendingActions;
  final int pendingActionsCount;
  final DateTime lastSyncTime;

  const OfflineStatus({
    required this.isConnected,
    required this.hasPendingActions,
    required this.pendingActionsCount,
    required this.lastSyncTime,
  });

  @override
  String toString() {
    return 'OfflineStatus(connected: $isConnected, pending: $pendingActionsCount)';
  }
}

/// Represents a pending timer action to be executed when reconnected
class PendingTimerAction {
  final String id;
  final String action;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? optimisticTimerId;

  PendingTimerAction({
    required this.id,
    required this.action,
    required this.data,
    required this.timestamp,
    this.optimisticTimerId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'optimisticTimerId': optimisticTimerId,
    };
  }

  factory PendingTimerAction.fromJson(Map<String, dynamic> json) {
    return PendingTimerAction(
      id: json['id'],
      action: json['action'],
      data: Map<String, dynamic>.from(json['data']),
      timestamp: DateTime.parse(json['timestamp']),
      optimisticTimerId: json['optimisticTimerId'],
    );
  }
}