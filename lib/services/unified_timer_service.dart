import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
import '../models/timer_state.dart';
import '../core/logging/app_logger.dart';
import 'consolidated_audio_service.dart';

/// Unified timer service interface supporting multiple backends
/// Consolidates: timer_service, appwrite_timer_service, enhanced_timer_sync_service
abstract class ITimerBackend {
  Future<void> initialize();
  Stream<TimerState> getTimerStream(String roomId);
  Future<void> startTimer(String roomId, int seconds, String description);
  Future<void> pauseTimer(String roomId);
  Future<void> resumeTimer(String roomId);
  Future<void> stopTimer(String roomId);
  Future<void> dispose();
}

/// Unified timer service that can work with different backends
class UnifiedTimerService {
  static final UnifiedTimerService _instance = UnifiedTimerService._internal();
  factory UnifiedTimerService() => _instance;
  UnifiedTimerService._internal();

  final AppLogger _logger = AppLogger();
  final ConsolidatedAudioService _audioService = ConsolidatedAudioService();

  ITimerBackend? _backend;
  StreamSubscription<TimerState>? _timerSubscription;
  Timer? _localTimer;

  String? _currentRoomId;
  TimerState? _currentTimerState;
  int _localRemainingSeconds = 0;
  bool _hasPlayedWarning = false;
  bool _hasPlayedExpired = false;

  // Callbacks
  Function(TimerState)? onTimerUpdate;
  VoidCallback? onTimerWarning;
  VoidCallback? onTimerExpired;

  /// Initialize with a specific backend
  Future<void> initialize({required TimerBackend backend}) async {
    try {
      _logger.info('🕐 Initializing unified timer service with $backend');

      // Create backend instance
      switch (backend) {
        case TimerBackend.appwrite:
          _backend = AppwriteTimerBackend();
          break;
        case TimerBackend.firebase:
          _backend = FirebaseTimerBackend();
          break;
        case TimerBackend.local:
          _backend = LocalTimerBackend();
          break;
      }

      await _backend!.initialize();
      await _audioService.initialize();

      _logger.info('✅ Unified timer service initialized');
    } catch (e) {
      _logger.error('Failed to initialize timer service: $e');
      rethrow;
    }
  }

  /// Connect to a room's timer
  Future<void> connectToRoom(String roomId) async {
    if (_currentRoomId == roomId) return;

    try {
      _logger.info('Connecting to room timer: $roomId');

      // Clean up previous connection
      await _disconnectFromRoom();

      _currentRoomId = roomId;
      _hasPlayedWarning = false;
      _hasPlayedExpired = false;

      // Subscribe to timer updates
      _timerSubscription = _backend!.getTimerStream(roomId).listen(
        _handleTimerUpdate,
        onError: (error) {
          _logger.error('Timer stream error: $error');
        },
      );

      _logger.info('Connected to room timer: $roomId');
    } catch (e) {
      _logger.error('Failed to connect to room timer: $e');
      rethrow;
    }
  }

  /// Disconnect from current room
  Future<void> _disconnectFromRoom() async {
    _localTimer?.cancel();
    await _timerSubscription?.cancel();
    _currentRoomId = null;
    _currentTimerState = null;
    _localRemainingSeconds = 0;
  }

  /// Handle timer state updates
  void _handleTimerUpdate(TimerState state) {
    _currentTimerState = state;

    // Update local timer
    if (state.status == TimerStatus.running) {
      _startLocalTimer(state.remainingSeconds);
    } else {
      _stopLocalTimer();
    }

    // Notify listeners
    onTimerUpdate?.call(state);

    _logger.debug('Timer updated: ${state.remainingSeconds}s, status: ${state.status}');
  }

  /// Start local timer for smooth updates
  void _startLocalTimer(int initialSeconds) {
    _localTimer?.cancel();
    _localRemainingSeconds = initialSeconds;

    _localTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_localRemainingSeconds > 0) {
        _localRemainingSeconds--;

        // Check for warning (30 seconds)
        if (_localRemainingSeconds == 30 && !_hasPlayedWarning) {
          _playWarningSound();
        }

        // Check for expiration
        if (_localRemainingSeconds == 0 && !_hasPlayedExpired) {
          _playExpiredSound();
          timer.cancel();
        }

        // Update state
        if (_currentTimerState != null) {
          final updatedState = _currentTimerState!.copyWith(
            remainingSeconds: _localRemainingSeconds,
          );
          onTimerUpdate?.call(updatedState);
        }
      }
    });
  }

  /// Stop local timer
  void _stopLocalTimer() {
    _localTimer?.cancel();
    _localTimer = null;
  }

  /// Play warning sound
  void _playWarningSound() {
    _hasPlayedWarning = true;
    _audioService.playTimerWarning();
    onTimerWarning?.call();
    _logger.info('⚠️ Timer warning: 30 seconds remaining');
  }

  /// Play expired sound
  void _playExpiredSound() {
    _hasPlayedExpired = true;
    _audioService.playTimerExpired();
    onTimerExpired?.call();
    _logger.info('⏰ Timer expired');
  }

  /// Start a new timer
  Future<void> startTimer({
    required int seconds,
    String description = 'Timer',
  }) async {
    if (_currentRoomId == null) {
      throw Exception('Not connected to a room');
    }

    try {
      await _backend!.startTimer(_currentRoomId!, seconds, description);
      _hasPlayedWarning = false;
      _hasPlayedExpired = false;
      _logger.info('Started timer: ${seconds}s');
    } catch (e) {
      _logger.error('Failed to start timer: $e');
      rethrow;
    }
  }

  /// Pause the current timer
  Future<void> pauseTimer() async {
    if (_currentRoomId == null) {
      throw Exception('Not connected to a room');
    }

    try {
      await _backend!.pauseTimer(_currentRoomId!);
      _stopLocalTimer();
      _logger.info('Timer paused');
    } catch (e) {
      _logger.error('Failed to pause timer: $e');
      rethrow;
    }
  }

  /// Resume the current timer
  Future<void> resumeTimer() async {
    if (_currentRoomId == null) {
      throw Exception('Not connected to a room');
    }

    try {
      await _backend!.resumeTimer(_currentRoomId!);
      _logger.info('Timer resumed');
    } catch (e) {
      _logger.error('Failed to resume timer: $e');
      rethrow;
    }
  }

  /// Stop the current timer
  Future<void> stopTimer() async {
    if (_currentRoomId == null) {
      throw Exception('Not connected to a room');
    }

    try {
      await _backend!.stopTimer(_currentRoomId!);
      _stopLocalTimer();
      _hasPlayedWarning = false;
      _hasPlayedExpired = false;
      _logger.info('Timer stopped');
    } catch (e) {
      _logger.error('Failed to stop timer: $e');
      rethrow;
    }
  }

  /// Get current timer state
  TimerState? get currentTimerState => _currentTimerState;

  /// Get current remaining seconds (local)
  int get remainingSeconds => _localRemainingSeconds;

  /// Check if timer is running
  bool get isRunning => _currentTimerState?.status == TimerStatus.running;

  /// Dispose the service
  Future<void> dispose() async {
    await _disconnectFromRoom();
    await _backend?.dispose();
    _backend = null;
    _logger.info('Timer service disposed');
  }
}

/// Timer backend types
enum TimerBackend {
  appwrite,
  firebase,
  local, // Offline fallback
}

/// Appwrite timer backend implementation
class AppwriteTimerBackend implements ITimerBackend {
  // final AppwriteService _appwriteService = AppwriteService();
  final AppLogger _logger = AppLogger();

  @override
  Future<void> initialize() async {
    // Appwrite service is already initialized
    _logger.info('Appwrite timer backend initialized');
  }

  @override
  Stream<TimerState> getTimerStream(String roomId) {
    // Implementation would connect to Appwrite realtime
    return Stream.periodic(Duration(seconds: 1), (count) {
      return TimerState(
        id: 'timer_$roomId',
        roomId: roomId,
        roomType: RoomType.arena,
        timerType: TimerType.general,
        status: count < 300 ? TimerStatus.running : TimerStatus.stopped,
        durationSeconds: 300,
        remainingSeconds: 300 - count,
        createdBy: 'system',
        description: 'Timer',
        startTime: DateTime.now(),
      );
    });
  }

  @override
  Future<void> startTimer(String roomId, int seconds, String description) async {
    // Implementation would create timer document in Appwrite
    _logger.info('Starting Appwrite timer: $roomId, ${seconds}s');
  }

  @override
  Future<void> pauseTimer(String roomId) async {
    // Implementation would update timer document
    _logger.info('Pausing Appwrite timer: $roomId');
  }

  @override
  Future<void> resumeTimer(String roomId) async {
    // Implementation would update timer document
    _logger.info('Resuming Appwrite timer: $roomId');
  }

  @override
  Future<void> stopTimer(String roomId) async {
    // Implementation would update timer document
    _logger.info('Stopping Appwrite timer: $roomId');
  }

  @override
  Future<void> dispose() async {
    // Cleanup
  }
}

/// Firebase timer backend implementation
class FirebaseTimerBackend implements ITimerBackend {
  // DatabaseReference? _timerRef; // Field set but not used elsewhere
  final AppLogger _logger = AppLogger();

  @override
  Future<void> initialize() async {
    // Initialize Firebase if needed
    _logger.info('Firebase timer backend initialized');
  }

  @override
  Stream<TimerState> getTimerStream(String roomId) {
    // _timerRef = FirebaseDatabase.instance.ref('timers/$roomId');
    // Implementation would listen to Firebase realtime database
    return Stream.empty(); // Placeholder
  }

  @override
  Future<void> startTimer(String roomId, int seconds, String description) async {
    // Implementation would update Firebase
    _logger.info('Starting Firebase timer: $roomId, ${seconds}s');
  }

  @override
  Future<void> pauseTimer(String roomId) async {
    // Implementation would update Firebase
    _logger.info('Pausing Firebase timer: $roomId');
  }

  @override
  Future<void> resumeTimer(String roomId) async {
    // Implementation would update Firebase
    _logger.info('Resuming Firebase timer: $roomId');
  }

  @override
  Future<void> stopTimer(String roomId) async {
    // Implementation would update Firebase
    _logger.info('Stopping Firebase timer: $roomId');
  }

  @override
  Future<void> dispose() async {
    // Cleanup
  }
}

/// Local timer backend for offline mode
class LocalTimerBackend implements ITimerBackend {
  final StreamController<TimerState> _timerController = StreamController<TimerState>.broadcast();
  Timer? _timer;
  TimerState? _currentState;
  final AppLogger _logger = AppLogger();

  @override
  Future<void> initialize() async {
    _logger.info('Local timer backend initialized');
  }

  @override
  Stream<TimerState> getTimerStream(String roomId) {
    return _timerController.stream;
  }

  @override
  Future<void> startTimer(String roomId, int seconds, String description) async {
    _timer?.cancel();

    _currentState = TimerState(
      id: 'local_timer',
      roomId: roomId,
      roomType: RoomType.arena,
      timerType: TimerType.general,
      status: TimerStatus.running,
      durationSeconds: seconds,
      remainingSeconds: seconds,
      createdBy: 'system',
      description: description,
      startTime: DateTime.now(),
    );

    _timerController.add(_currentState!);

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_currentState!.remainingSeconds > 0) {
        _currentState = _currentState!.copyWith(
          remainingSeconds: _currentState!.remainingSeconds - 1,
        );
        _timerController.add(_currentState!);
      } else {
        timer.cancel();
        _currentState = _currentState!.copyWith(status: TimerStatus.stopped);
        _timerController.add(_currentState!);
      }
    });

    _logger.info('Started local timer: ${seconds}s');
  }

  @override
  Future<void> pauseTimer(String roomId) async {
    _timer?.cancel();
    if (_currentState != null) {
      _currentState = _currentState!.copyWith(status: TimerStatus.paused);
      _timerController.add(_currentState!);
    }
    _logger.info('Paused local timer');
  }

  @override
  Future<void> resumeTimer(String roomId) async {
    if (_currentState?.status == TimerStatus.paused) {
      _currentState = _currentState!.copyWith(status: TimerStatus.running);
      _timerController.add(_currentState!);

      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (_currentState!.remainingSeconds > 0) {
          _currentState = _currentState!.copyWith(
            remainingSeconds: _currentState!.remainingSeconds - 1,
          );
          _timerController.add(_currentState!);
        } else {
          timer.cancel();
          _currentState = _currentState!.copyWith(status: TimerStatus.stopped);
          _timerController.add(_currentState!);
        }
      });
    }
    _logger.info('Resumed local timer');
  }

  @override
  Future<void> stopTimer(String roomId) async {
    _timer?.cancel();
    _currentState = null;
    _logger.info('Stopped local timer');
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _timerController.close();
  }
}