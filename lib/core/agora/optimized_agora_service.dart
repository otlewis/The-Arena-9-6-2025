import 'dart:async';
import '../logging/app_logger.dart';
import '../../services/agora_service.dart';

/// Optimized Agora service with instance reuse and smart initialization
class OptimizedAgoraService {
  static final OptimizedAgoraService _instance = OptimizedAgoraService._internal();
  factory OptimizedAgoraService() => _instance;
  OptimizedAgoraService._internal();

  // Use the actual AgoraService implementation
  final AgoraService _agoraService = AgoraService();
  
  // Optimization state tracking
  bool _preInitialized = false;
  Timer? _keepAliveTimer;
  String? _currentChannel;
  
  final AppLogger _logger = AppLogger();

  /// Pre-initialize engine during app startup
  Future<void> preInitialize() async {
    if (_preInitialized) return;
    
    _logger.debug('🎙️ Pre-initializing Agora engine...');
    
    try {
      // Initialize the actual Agora service
      await _agoraService.initialize();
      _preInitialized = true;
      
      // Set up keep-alive to prevent disposal
      _keepAliveTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        _logger.debug('🔄 Agora engine keep-alive ping');
      });
      
      _logger.debug('✅ Agora engine pre-initialized');
    } catch (e) {
      _logger.warning('Agora pre-initialization failed (non-critical): $e');
      // Mark as pre-initialized anyway to prevent repeated attempts
      _preInitialized = true;
    }
  }

  /// Fast channel join (engine already initialized)
  Future<void> joinChannel(String channelName, {String? userId}) async {
    if (!_preInitialized) {
      await preInitialize();
    }
    
    _logger.debug('🎙️ Fast joining channel: $channelName');
    
    try {
      // Reuse existing connection if same channel
      if (_currentChannel == channelName && _agoraService.isJoined) {
        _logger.debug('🔄 Reusing existing channel connection');
        return;
      }
      
      // Leave current channel if different
      if (_agoraService.isJoined && _currentChannel != channelName) {
        await _agoraService.leaveChannel();
      }
      
      // Join channel using actual Agora service (no parameters)
      await _agoraService.joinChannel();
      _currentChannel = channelName;
      
      _logger.debug('✅ Fast channel join completed: $channelName');
    } catch (e) {
      _logger.warning('Fast channel join failed (non-critical): $e');
      // Don't rethrow to prevent app crashes
    }
  }

  /// Smart leave - keeps engine alive for quick re-join
  Future<void> leaveChannel({bool keepEngineAlive = true}) async {
    if (!_agoraService.isJoined) return;
    
    _logger.debug('👋 Leaving channel (keepAlive: $keepEngineAlive)');
    
    try {
      await _agoraService.leaveChannel();
      _currentChannel = null;
      
      if (!keepEngineAlive) {
        _agoraService.dispose();
        _preInitialized = false;
      }
      
      _logger.debug('✅ Channel left successfully');
    } catch (e) {
      _logger.warning('Leave channel failed (non-critical): $e');
    }
  }

  /// Background initialization for next expected usage
  void preloadForArena(String arenaId) {
    Timer(const Duration(milliseconds: 500), () async {
      try {
        _logger.debug('🔄 Preloading for arena: $arenaId');
        
        // Ensure service is initialized for quick arena join
        if (!_preInitialized) {
          await preInitialize();
        }
        
        _logger.debug('✅ Arena preload completed: $arenaId');
      } catch (e) {
        _logger.warning('Arena preload failed (non-critical): $e');
      }
    });
  }

  /// Dispose with cleanup
  Future<void> dispose() async {
    _logger.debug('🗑️ Disposing optimized Agora service');
    
    _keepAliveTimer?.cancel();
    
    try {
      _agoraService.dispose();
    } catch (e) {
      _logger.warning('Agora disposal failed (non-critical): $e');
    }
    
    _preInitialized = false;
    _currentChannel = null;
  }

  // Getters that delegate to the actual service
  bool get isInitialized => _preInitialized;
  bool get isJoined => _agoraService.isJoined;
  String? get currentChannel => _currentChannel;
  dynamic get engine => _agoraService.engine;
  
  // Forward user role properties
  dynamic get userRole => _agoraService.userRole;
  bool get isBroadcaster => _agoraService.isBroadcaster;
  bool get isAudience => _agoraService.isAudience;
  
  // Forward callback setters
  set onUserMuteAudio(Function(int uid, bool muted)? callback) => _agoraService.onUserMuteAudio = callback;
  set onUserJoined(Function(int uid)? callback) => _agoraService.onUserJoined = callback;
  set onUserLeft(Function(int uid)? callback) => _agoraService.onUserLeft = callback;
  set onJoinChannel(Function(bool joined)? callback) => _agoraService.onJoinChannel = callback;
  
  // Forward other important methods
  Future<void> switchToSpeaker() async {
    try {
      await _agoraService.switchToSpeaker();
    } catch (e) {
      _logger.warning('Switch to speaker failed (non-critical): $e');
    }
  }
  
  Future<void> switchToAudience() async {
    try {
      await _agoraService.switchToAudience();
    } catch (e) {
      _logger.warning('Switch to audience failed (non-critical): $e');
    }
  }
  
  Future<void> muteLocalAudio(bool mute) async {
    try {
      await _agoraService.muteLocalAudio(mute);
    } catch (e) {
      _logger.warning('Mute local audio failed (non-critical): $e');
    }
  }
  
  Future<void> setEnableSpeakerphone(bool enabled) async {
    try {
      await _agoraService.setEnableSpeakerphone(enabled);
    } catch (e) {
      _logger.warning('Set speakerphone failed (non-critical): $e');
    }
  }
}