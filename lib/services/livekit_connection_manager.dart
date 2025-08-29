import 'dart:async';
import 'dart:io' show Platform;
import 'package:livekit_client/livekit_client.dart' as lk;
import '../core/logging/app_logger.dart';
import 'livekit_config_service.dart';
import 'open_discussion_service.dart';

/// Connection status for the LiveKit room
enum LiveKitConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed
}

/// Connection quality indicators
enum LiveKitConnectionQuality {
  excellent,
  good,
  poor,
  unknown
}

/// Centralized LiveKit connection management
/// Handles all connection lifecycle, health monitoring, and recovery
class LiveKitConnectionManager {
  final LiveKitConfigService _configService = LiveKitConfigService.instance;
  final OpenDiscussionService _openDiscussionService = OpenDiscussionService();
  
  lk.Room? _room;
  lk.LocalParticipant? _localParticipant;
  Timer? _healthCheckTimer;
  Timer? _reconnectTimer;
  
  LiveKitConnectionStatus _status = LiveKitConnectionStatus.disconnected;
  LiveKitConnectionQuality _quality = LiveKitConnectionQuality.unknown;
  
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  
  // Stream controllers for reactive updates
  final StreamController<LiveKitConnectionStatus> _statusController = 
      StreamController<LiveKitConnectionStatus>.broadcast();
  final StreamController<LiveKitConnectionQuality> _qualityController = 
      StreamController<LiveKitConnectionQuality>.broadcast();
  final StreamController<List<lk.Participant>> _participantsController = 
      StreamController<List<lk.Participant>>.broadcast();
  final StreamController<String> _errorController = 
      StreamController<String>.broadcast();

  // Getters
  lk.Room? get room => _room;
  lk.LocalParticipant? get localParticipant => _localParticipant;
  LiveKitConnectionStatus get status => _status;
  LiveKitConnectionQuality get quality => _quality;
  bool get isConnected => _status == LiveKitConnectionStatus.connected;
  
  // Streams
  Stream<LiveKitConnectionStatus> get statusStream => _statusController.stream;
  Stream<LiveKitConnectionQuality> get qualityStream => _qualityController.stream;
  Stream<List<lk.Participant>> get participantsStream => _participantsController.stream;
  Stream<String> get errorStream => _errorController.stream;

  /// Connect to LiveKit room
  Future<bool> connect({
    required String roomName,
    required String userId,
    required String displayName,
    required String userRole,
  }) async {
    if (_status == LiveKitConnectionStatus.connecting || isConnected) {
      AppLogger().warning('⚠️ Connection already in progress or established');
      return isConnected;
    }

    try {
      _updateStatus(LiveKitConnectionStatus.connecting);
      AppLogger().info('🔗 Connecting to LiveKit room: $roomName');

      // Get token from unified Appwrite Function
      final joinResult = await _openDiscussionService.joinRoom(
        roomName: roomName,
        userId: userId,
        userRole: userRole,
      );
      final token = joinResult['token'] as String;

      // Token generation from OpenDiscussionService always returns a string

      // Create and configure room
      _room = lk.Room();
      _setupRoomListeners();

      // ANDROID FIX: Optimize connection parameters for better performance
      final connectionTimeout = Platform.isAndroid 
          ? const Duration(seconds: 15)  // Shorter timeout for Android
          : const Duration(seconds: 30); // Standard timeout for iOS
      
      // Connect to room using proper server URL
      await _room!.connect(
        _configService.serverUrl,
        token,
      ).timeout(
        connectionTimeout,
        onTimeout: () {
          AppLogger().error('❌ Open Discussion connection timeout after ${connectionTimeout.inSeconds} seconds (Android optimized)');
          throw Exception('Open discussion connection timeout. Please check your network connection.');
        },
      );

      _localParticipant = _room!.localParticipant;
      
      // ANDROID FIX: Add stabilization period to prevent immediate disconnection
      if (Platform.isAndroid) {
        AppLogger().debug('🔧 ANDROID: Connection stabilization period starting...');
        await Future.delayed(const Duration(milliseconds: 800)); // Stabilization for open discussions
        AppLogger().debug('🔧 ANDROID: Connection stabilization completed');
      }
      
      // Enable microphone for speakers/moderators
      if (userRole == 'speaker' || userRole == 'moderator') {
        await _localParticipant!.setMicrophoneEnabled(true);
      }

      _updateStatus(LiveKitConnectionStatus.connected);
      _resetReconnectAttempts();
      _startHealthMonitoring();
      
      AppLogger().info('✅ Successfully connected to LiveKit room: $roomName');
      return true;

    } catch (e) {
      AppLogger().error('❌ Failed to connect to LiveKit: $e');
      _updateStatus(LiveKitConnectionStatus.failed);
      _notifyError('Connection failed: ${e.toString()}');
      
      // Attempt reconnection for certain errors
      if (_shouldAttemptReconnect(e)) {
        _scheduleReconnect(roomName, userId, displayName, userRole);
      }
      
      return false;
    }
  }

  /// Disconnect from LiveKit room
  Future<void> disconnect() async {
    if (!isConnected && _room == null) return;

    try {
      _updateStatus(LiveKitConnectionStatus.disconnected);
      _stopHealthMonitoring();
      _cancelReconnectTimer();

      if (_room != null) {
        // Stop all audio tracks to prevent audio bleeding
        try {
          AppLogger().info('🔇 Stopping all audio tracks to prevent bleeding');
          
          // Stop local participant's audio tracks
          if (_localParticipant != null) {
            await _localParticipant!.setMicrophoneEnabled(false);
            
            // ANDROID FIX: Additional cleanup delay for Android
            if (Platform.isAndroid) {
              await Future.delayed(const Duration(milliseconds: 150));
              AppLogger().debug('🔧 ANDROID: Audio track cleanup delay completed');
            }
            
            final audioTracks = _localParticipant!.audioTrackPublications;
            for (final track in audioTracks) {
              if (track.track != null) {
                await track.track!.stop();
                track.track!.dispose();
              }
            }
          }
          
          // Stop all remote participants' audio tracks
          for (final participant in _room!.remoteParticipants.values) {
            final audioTracks = participant.audioTrackPublications;
            for (final track in audioTracks) {
              if (track.track != null) {
                await track.track!.stop();
                track.track!.dispose();
              }
            }
          }
          
        } catch (e) {
          AppLogger().error('❌ Error stopping audio tracks: $e');
        }
        
        // Disconnect with retry logic
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            await _room!.disconnect().timeout(const Duration(seconds: 5));
            _room!.removeListener(_onRoomUpdate);
            break;
          } catch (e) {
            if (attempt == 3) {
              AppLogger().error('Failed to disconnect from LiveKit after 3 attempts: $e');
            } else {
              await Future.delayed(Duration(milliseconds: 500 * attempt));
            }
          }
        }
        
        _room = null;
      }

      _localParticipant = null;
      _resetReconnectAttempts();
      
      AppLogger().info('📴 Disconnected from LiveKit');

    } catch (e) {
      AppLogger().error('❌ Error during LiveKit disconnect: $e');
    }
  }

  /// Toggle microphone
  Future<void> toggleMicrophone() async {
    if (_localParticipant == null) return;

    try {
      final isEnabled = _localParticipant!.isMicrophoneEnabled();
      final wantToEnable = !isEnabled;
      
      // Check permissions before trying to enable
      if (wantToEnable) {
        final canPublish = _localParticipant!.permissions.canPublish;
        if (!canPublish) {
          AppLogger().warning('⚠️ Cannot enable microphone: participant lacks publish permissions');
          _notifyError('Cannot enable microphone: You need speaker permissions. Ask the moderator to promote you first.');
          return;
        }
      }

      await _localParticipant!.setMicrophoneEnabled(wantToEnable);
      AppLogger().debug('🎤 Microphone ${wantToEnable ? 'enabled' : 'disabled'}');
    } catch (e) {
      AppLogger().error('❌ Failed to toggle microphone: $e');
      
      // Provide specific error messages for common issues
      if (e.toString().contains('TrackPublishException')) {
        _notifyError('Cannot publish audio: You need speaker permissions. Ask the moderator to promote you.');
      } else if (e.toString().contains('permissions')) {
        _notifyError('Audio permissions required. Please ask the moderator to promote you to speaker.');
      } else {
        _notifyError('Failed to toggle microphone: ${e.toString()}');
      }
    }
  }

  /// Set microphone state
  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (_localParticipant == null) return;

    try {
      // Check if participant has publish permissions before attempting to enable microphone
      final canPublish = _localParticipant!.permissions.canPublish;
      if (enabled && !canPublish) {
        AppLogger().warning('⚠️ Cannot enable microphone: participant lacks publish permissions');
        _notifyError('Cannot enable microphone: insufficient permissions. Please ask the moderator to promote you to speaker first.');
        return;
      }

      await _localParticipant!.setMicrophoneEnabled(enabled);
      AppLogger().debug('🎤 Microphone ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      AppLogger().error('❌ Failed to set microphone state: $e');
      
      // Provide more specific error messages
      if (e.toString().contains('TrackPublishException')) {
        _notifyError('Cannot publish audio: You need speaker permissions. Ask the moderator to promote you.');
      } else if (e.toString().contains('permissions')) {
        _notifyError('Audio permissions required. Please ask the moderator to promote you to speaker.');
      } else {
        _notifyError('Failed to control microphone: ${e.toString()}');
      }
    }
  }

  /// Get all participants (local + remote)
  List<lk.Participant> getAllParticipants() {
    if (_room == null) return [];
    
    return [
      if (_localParticipant != null) _localParticipant!,
      ..._room!.remoteParticipants.values,
    ];
  }

  /// Check if participant is speaking
  bool isParticipantSpeaking(lk.Participant participant) {
    final audioTracks = participant.audioTrackPublications;
    return audioTracks.any((track) => 
        track.track != null && !track.track!.muted);
  }

  /// Setup room event listeners
  void _setupRoomListeners() {
    if (_room == null) return;

    _room!.addListener(_onRoomUpdate);
    
    final listener = _room!.createListener();
    
    listener
      ..on<lk.ParticipantConnectedEvent>((event) {
        AppLogger().debug('👤 Participant connected: ${event.participant.identity}');
        _notifyParticipantsChanged();
      })
      ..on<lk.ParticipantDisconnectedEvent>((event) {
        AppLogger().debug('👤 Participant disconnected: ${event.participant.identity}');
        _notifyParticipantsChanged();
      })
      ..on<lk.TrackSubscribedEvent>((event) {
        AppLogger().debug('🎵 Track subscribed: ${event.track.kind}');
        _notifyParticipantsChanged();
      })
      ..on<lk.TrackUnsubscribedEvent>((event) {
        AppLogger().debug('🎵 Track unsubscribed: ${event.track.kind}');
        _notifyParticipantsChanged();
      })
      ..on<lk.TrackMutedEvent>((event) {
        AppLogger().debug('🔇 Track muted: ${event.publication.track?.kind ?? "unknown"}');
        _notifyParticipantsChanged();
      })
      ..on<lk.TrackUnmutedEvent>((event) {
        AppLogger().debug('🔊 Track unmuted: ${event.publication.track?.kind ?? "unknown"}');
        _notifyParticipantsChanged();
      });
  }

  /// Room update handler
  void _onRoomUpdate() {
    _assessConnectionQuality();
    _notifyParticipantsChanged();
  }

  /// Assess connection quality
  void _assessConnectionQuality() {
    if (_room?.connectionState != lk.ConnectionState.connected) {
      _updateQuality(LiveKitConnectionQuality.unknown);
      return;
    }

    // Simple heuristic based on connection state and participant count
    final participantCount = _room!.remoteParticipants.length + 1;
    
    if (participantCount > 10) {
      _updateQuality(LiveKitConnectionQuality.good);
    } else if (participantCount > 5) {
      _updateQuality(LiveKitConnectionQuality.good);
    } else {
      _updateQuality(LiveKitConnectionQuality.excellent);
    }
  }

  /// Start health monitoring with Android optimization
  void _startHealthMonitoring() {
    _stopHealthMonitoring();
    
    // ANDROID FIX: More frequent monitoring for Android to catch issues early
    final monitoringInterval = Platform.isAndroid 
        ? const Duration(seconds: 20)  // More frequent for Android
        : const Duration(seconds: 30); // Standard for iOS
    
    _healthCheckTimer = Timer.periodic(monitoringInterval, (_) {
      _performHealthCheck();
    });
    
    AppLogger().debug('🔍 Started open discussion health monitoring (${monitoringInterval.inSeconds}s intervals - Android optimized)');
  }

  /// Stop health monitoring
  void _stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// Perform connection health check
  void _performHealthCheck() {
    if (_room == null) return;

    final connectionState = _room!.connectionState;
    
    if (connectionState != lk.ConnectionState.connected) {
      AppLogger().warning('⚠️ Connection health check failed: $connectionState');
      
      if (connectionState == lk.ConnectionState.disconnected) {
        _updateStatus(LiveKitConnectionStatus.failed);
        // Reconnection logic would be triggered by the status change
      }
    } else {
      AppLogger().debug('💓 Connection health check passed');
    }
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect(String roomName, String userId, String displayName, String userRole) {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      AppLogger().error('❌ Max reconnection attempts reached');
      _notifyError('Connection failed after $maxReconnectAttempts attempts');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: 2 * _reconnectAttempts);
    
    AppLogger().info('🔄 Scheduling reconnection attempt $_reconnectAttempts in ${delay.inSeconds}s');
    
    _reconnectTimer = Timer(delay, () {
      _updateStatus(LiveKitConnectionStatus.reconnecting);
      connect(
        roomName: roomName,
        userId: userId,
        displayName: displayName,
        userRole: userRole,
      );
    });
  }

  /// Cancel reconnection timer
  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Reset reconnection attempts
  void _resetReconnectAttempts() {
    _reconnectAttempts = 0;
  }

  /// Check if should attempt reconnection for this error
  bool _shouldAttemptReconnect(dynamic error) {
    // Add logic to determine if error is recoverable
    return _reconnectAttempts < maxReconnectAttempts;
  }

  /// Update connection status
  void _updateStatus(LiveKitConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(_status);
      AppLogger().debug('🔗 Connection status changed to: $_status');
    }
  }

  /// Update connection quality
  void _updateQuality(LiveKitConnectionQuality newQuality) {
    if (_quality != newQuality) {
      _quality = newQuality;
      _qualityController.add(_quality);
    }
  }

  /// Notify participants changed
  void _notifyParticipantsChanged() {
    if (!_participantsController.isClosed) {
      _participantsController.add(getAllParticipants());
    }
  }

  /// Notify error
  void _notifyError(String error) {
    if (!_errorController.isClosed) {
      _errorController.add(error);
    }
  }

  /// Dispose resources
  void dispose() {
    _stopHealthMonitoring();
    _cancelReconnectTimer();
    
    _statusController.close();
    _qualityController.close();
    _participantsController.close();
    _errorController.close();
    
    disconnect();
    
    AppLogger().debug('🗑️ LiveKitConnectionManager disposed');
  }
}