import 'package:get_it/get_it.dart';
import '../core/logging/app_logger.dart';
import 'persistent_audio_service.dart';
import 'livekit_service.dart';

/// Adapter service that provides a compatibility layer between existing room screens
/// and the new persistent audio service. This allows gradual migration while maintaining
/// backward compatibility with the old LiveKitService interface.
class RoomAudioAdapter {
  static final RoomAudioAdapter _instance = RoomAudioAdapter._internal();
  factory RoomAudioAdapter() => _instance;
  RoomAudioAdapter._internal();

  PersistentAudioService get _persistentAudio => GetIt.instance<PersistentAudioService>();
  
  /// Connect to a room using persistent audio (replaces LiveKitService.connect)
  /// This method maintains the same interface as LiveKitService.connect but uses
  /// the persistent connection underneath
  Future<void> connectToRoom({
    required String serverUrl,
    required String roomName,
    required String token,
    required String userId,
    required String userRole,
    required String roomType,
  }) async {
    try {
      AppLogger().info('🔄 ROOM ADAPTER: Connecting to room $roomName via persistent audio');
      AppLogger().debug('🔄 ROOM ADAPTER: Room type: $roomType, Role: $userRole');
      
      // Debug persistent audio state
      AppLogger().debug('🔍 ROOM ADAPTER: Persistent audio initialized: ${_persistentAudio.isInitialized}');
      AppLogger().debug('🔍 ROOM ADAPTER: Persistent audio connected: ${_persistentAudio.isConnected}');
      AppLogger().debug('🔍 ROOM ADAPTER: Current room: ${_persistentAudio.currentRoomId}');
      AppLogger().debug('🔍 ROOM ADAPTER: Current user: ${_persistentAudio.currentUserId}');
      
      // Check if persistent audio is initialized, if not initialize it now
      if (!_persistentAudio.isInitialized) {
        AppLogger().info('🚀 ROOM ADAPTER: Persistent audio not initialized, initializing now for instant future connections...');
        try {
          await _persistentAudio.initialize(userId: userId, serverUrl: serverUrl);
          AppLogger().info('✅ ROOM ADAPTER: Persistent audio initialized successfully');
        } catch (e) {
          AppLogger().warning('⚠️ ROOM ADAPTER: Persistent audio initialization failed, falling back to legacy service: $e');
          // Fall back to old LiveKitService
          final legacyService = GetIt.instance<LiveKitService>();
          await legacyService.connect(
            serverUrl: serverUrl,
            roomName: roomName,
            token: token,
            userId: userId,
            userRole: userRole,
            roomType: roomType,
          );
          return;
        }
      }
      
      // Use persistent audio service for instant room switching - no disposal needed!
      AppLogger().info('🚀 ROOM ADAPTER: Using PERSISTENT AUDIO for instant room switching to $roomName');
      await _persistentAudio.switchToRoom(
        roomId: roomName,
        roomType: roomType,
        userRole: userRole,
        metadata: {
          'userId': userId,
          'serverUrl': serverUrl,
        },
      );
      
      AppLogger().info('✅ ROOM ADAPTER: INSTANT SWITCH COMPLETE - Connected to room $roomName via persistent audio');
      
    } catch (error) {
      AppLogger().error('❌ ROOM ADAPTER: Failed to connect to room $roomName: $error');
      rethrow;
    }
  }
  
  /// Disconnect from current room but keep persistent connection (replaces LiveKitService.disconnect)
  Future<void> disconnectFromRoom() async {
    try {
      AppLogger().debug('🔄 ROOM ADAPTER: Disconnecting from current room');
      
      if (!_persistentAudio.isInitialized) {
        AppLogger().debug('🔄 ROOM ADAPTER: Using legacy disconnect');
        final legacyService = GetIt.instance<LiveKitService>();
        await legacyService.disconnect();
        return;
      }
      
      // Switch to lobby instead of full disconnect
      await _persistentAudio.switchToLobby();
      
      AppLogger().debug('✅ ROOM ADAPTER: Switched to lobby, persistent connection maintained');
      
    } catch (error) {
      AppLogger().warning('⚠️ ROOM ADAPTER: Error during room disconnect: $error');
    }
  }
  
  /// Get the appropriate service (persistent or legacy) for other operations
  dynamic getAudioService() {
    if (_persistentAudio.isInitialized) {
      return _persistentAudio;
    } else {
      AppLogger().debug('🔄 ROOM ADAPTER: Using legacy audio service');
      return GetIt.instance<LiveKitService>();
    }
  }
  
  /// Check if we're using persistent audio
  bool get usingPersistentAudio => _persistentAudio.isInitialized;
  
  /// Check if connection is healthy
  bool get isConnectionHealthy {
    if (_persistentAudio.isInitialized) {
      return _persistentAudio.isConnectionHealthy;
    } else {
      final legacyService = GetIt.instance<LiveKitService>();
      return legacyService.isConnected;
    }
  }
  
  /// Mute/unmute methods (compatible with both services)
  Future<void> enableAudio() async {
    final service = getAudioService();
    await service.enableAudio();
  }
  
  Future<void> disableAudio() async {
    final service = getAudioService();
    await service.disableAudio();
  }
  
  Future<void> toggleMute() async {
    final service = getAudioService();
    await service.toggleMute();
  }
  
  /// Moderator controls (compatible with both services)
  Future<void> muteParticipant(String participantIdentity) async {
    final service = getAudioService();
    await service.muteParticipant(participantIdentity);
  }
  
  Future<void> unmuteParticipant(String participantIdentity) async {
    final service = getAudioService();
    await service.unmuteParticipant(participantIdentity);
  }
  
  Future<void> muteAllParticipants() async {
    final service = getAudioService();
    await service.muteAllParticipants();
  }
  
  /// State getters (compatible with both services)
  bool get isConnected {
    final service = getAudioService();
    return service.isConnected;
  }
  
  bool get isMuted {
    final service = getAudioService();
    return service.isMuted;
  }
  
  String? get currentUserRole {
    final service = getAudioService();
    if (service is PersistentAudioService) {
      return service.currentUserRole;
    } else if (service is LiveKitService) {
      return service.userRole;
    }
    return null;
  }
  
  String? get currentRoomId {
    final service = getAudioService();
    if (service is PersistentAudioService) {
      return service.currentRoomId;
    } else if (service is LiveKitService) {
      return service.currentRoom;
    }
    return null;
  }
  
  List<dynamic> get remoteParticipants {
    final service = getAudioService();
    return service.remoteParticipants;
  }
  
  int get connectedPeersCount {
    final service = getAudioService();
    return service.connectedPeersCount;
  }
  
  /// Callback setters (compatible with both services)
  void setCallbacks({
    Function(dynamic)? onParticipantConnected,
    Function(dynamic)? onParticipantDisconnected,
    Function(dynamic, dynamic)? onTrackSubscribed,
    Function(dynamic, dynamic)? onTrackUnsubscribed,
    Function(String)? onError,
    Function()? onConnected,
    Function()? onDisconnected,
    Function(String, Map<String, dynamic>)? onMetadataChanged,
    Function(String, bool)? onSpeakingChanged,
    Function(String, double)? onAudioLevelChanged,
  }) {
    final service = getAudioService();
    
    if (onParticipantConnected != null) {
      service.onParticipantConnected = onParticipantConnected;
    }
    if (onParticipantDisconnected != null) {
      service.onParticipantDisconnected = onParticipantDisconnected;
    }
    if (onTrackSubscribed != null) {
      service.onTrackSubscribed = onTrackSubscribed;
    }
    if (onTrackUnsubscribed != null) {
      service.onTrackUnsubscribed = onTrackUnsubscribed;
    }
    if (onError != null) {
      service.onError = onError;
    }
    if (onConnected != null) {
      service.onConnected = onConnected;
    }
    if (onDisconnected != null) {
      service.onDisconnected = onDisconnected;
    }
    if (onMetadataChanged != null) {
      service.onMetadataChanged = onMetadataChanged;
    }
    if (onSpeakingChanged != null) {
      service.onSpeakingChanged = onSpeakingChanged;
    }
    if (onAudioLevelChanged != null) {
      service.onAudioLevelChanged = onAudioLevelChanged;
    }
  }
  
  /// Speaking detection methods
  bool isUserSpeaking(String userId) {
    final service = getAudioService();
    return service.isUserSpeaking(userId);
  }
  
  double getUserAudioLevel(String userId) {
    final service = getAudioService();
    return service.getUserAudioLevel(userId);
  }
  
  Map<String, bool> get allSpeakingStates {
    final service = getAudioService();
    return service.allSpeakingStates;
  }
  
  List<String> get currentSpeakers {
    final service = getAudioService();
    return service.currentSpeakers;
  }
  
  /// Force update role (compatible with both services)
  void forceUpdateRole(String newRole, String roomType) {
    final service = getAudioService();
    if (service is PersistentAudioService) {
      // For persistent audio, we can switch room with new role
      if (service.currentRoomId != null) {
        service.switchToRoom(
          roomId: service.currentRoomId!,
          roomType: roomType,
          userRole: newRole,
        );
      }
    } else if (service is LiveKitService) {
      service.forceUpdateRole(newRole, roomType);
    }
  }
  
  /// Force setup audio for specific roles
  Future<void> forceSetupJudgeAudio() async {
    final service = getAudioService();
    if (service is PersistentAudioService) {
      // With persistent audio, judge audio should already be ready
      await service.enableAudio();
    } else if (service is LiveKitService) {
      await service.forceSetupJudgeAudio();
    }
  }
  
  /// Check if a specific participant is muted
  bool isParticipantMuted(dynamic participant) {
    final service = getAudioService();
    if (service is LiveKitService) {
      return service.isParticipantMuted(participant);
    }
    // For persistent audio, we'd need to implement participant tracking
    return false; // Default assumption
  }
  
  /// Get room object (for legacy compatibility)
  dynamic get room {
    final service = getAudioService();
    if (service is PersistentAudioService) {
      return service.room;
    } else if (service is LiveKitService) {
      return service.room;
    }
    return null;
  }
}