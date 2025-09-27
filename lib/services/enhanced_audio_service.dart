import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logging/app_logger.dart';

/// Enhanced audio service with all recommended improvements
/// Consolidates all audio functionality with focus management, ducking,
/// permissions, haptics, and intelligent caching
class EnhancedAudioService {
  static final EnhancedAudioService _instance = EnhancedAudioService._internal();
  factory EnhancedAudioService() => _instance;
  EnhancedAudioService._internal();

  final AppLogger _logger = AppLogger();
  final Map<String, AudioPlayer> _players = {};
  final Map<String, Uint8List> _audioCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, StreamController<double>> _volumeControllers = {};

  // Volume controls
  double _masterVolume = 1.0;
  double _effectsVolume = 1.0;
  double _voiceVolume = 1.0;
  double _notificationVolume = 0.8;
  bool _isMuted = false;

  // Audio focus management (Android)
  static const MethodChannel _audioFocusChannel = MethodChannel('arena/audio_focus');
  bool _hasAudioFocus = false;

  // Ducking state
  bool _isDucking = false;
  double _duckingLevel = 0.3; // Reduce to 30% volume when ducking
  Timer? _duckingTimer;

  // Haptic feedback settings
  bool _hapticsEnabled = true;

  // Cache settings
  static const Duration _cacheExpiration = Duration(hours: 1);
  static const int _maxCacheSize = 50 * 1024 * 1024; // 50MB
  int _currentCacheSize = 0;

  // Permission state
  bool _hasAudioPermission = false;
  bool _hasVibrationPermission = false;

  // Audio file paths
  static const Map<String, String> audioFiles = {
    'timer_warning': 'audio/30sec.mp3',
    'timer_expired': 'audio/arenazero.mp3',
    'challenge': 'audio/challenge.mp3',
    'denied': 'audio/denied.mp3',
    'notification': 'audio/ding.mp3',
    'message': 'audio/instantmessage.mp3',
    'email': 'audio/email.mp3',
    'applause': 'audio/applause.mp3',
    'join': 'audio/ding.mp3',
    'leave': 'audio/ding.mp3',
  };

  // Critical sounds to always preload
  static const List<String> criticalSounds = [
    'timer_warning',
    'timer_expired',
    'notification',
    'message',
  ];

  /// Initialize the enhanced audio service
  Future<void> initialize() async {
    try {
      _logger.info('🎵 Initializing Enhanced Audio Service');

      // Check and request permissions
      await _checkPermissions();

      // Load user preferences
      await _loadUserPreferences();

      // Setup audio focus listener for Android
      if (Platform.isAndroid) {
        await _setupAudioFocusListener();
      }

      // Preload critical sounds
      await _preloadCriticalSounds();

      // Clean expired cache entries
      _cleanExpiredCache();

      _logger.info('✅ Enhanced Audio Service initialized successfully');
    } catch (e) {
      _logger.error('Failed to initialize Enhanced Audio Service: $e');
    }
  }

  /// Check and request necessary permissions
  Future<void> _checkPermissions() async {
    try {
      // Check microphone permission for voice features
      if (await Permission.microphone.isGranted) {
        _hasAudioPermission = true;
      } else {
        final status = await Permission.microphone.request();
        _hasAudioPermission = status.isGranted;
      }

      // Check vibration capability
      _hasVibrationPermission = await Vibration.hasVibrator();

      _logger.debug('Permissions - Audio: $_hasAudioPermission, Vibration: $_hasVibrationPermission');
    } catch (e) {
      _logger.error('Error checking permissions: $e');
    }
  }

  /// Load user preferences from storage
  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _masterVolume = prefs.getDouble('audio_master_volume') ?? 1.0;
      _effectsVolume = prefs.getDouble('audio_effects_volume') ?? 1.0;
      _voiceVolume = prefs.getDouble('audio_voice_volume') ?? 1.0;
      _notificationVolume = prefs.getDouble('audio_notification_volume') ?? 0.8;
      _hapticsEnabled = prefs.getBool('haptics_enabled') ?? true;
      _isMuted = prefs.getBool('audio_muted') ?? false;
    } catch (e) {
      _logger.error('Error loading audio preferences: $e');
    }
  }

  /// Save user preferences to storage
  Future<void> _saveUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('audio_master_volume', _masterVolume);
      await prefs.setDouble('audio_effects_volume', _effectsVolume);
      await prefs.setDouble('audio_voice_volume', _voiceVolume);
      await prefs.setDouble('audio_notification_volume', _notificationVolume);
      await prefs.setBool('haptics_enabled', _hapticsEnabled);
      await prefs.setBool('audio_muted', _isMuted);
    } catch (e) {
      _logger.error('Error saving audio preferences: $e');
    }
  }

  /// Setup audio focus listener for Android
  Future<void> _setupAudioFocusListener() async {
    if (!Platform.isAndroid) return;

    try {
      _audioFocusChannel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onAudioFocusGain':
            _handleAudioFocusGain();
            break;
          case 'onAudioFocusLoss':
            _handleAudioFocusLoss();
            break;
          case 'onAudioFocusLossTransient':
            _handleAudioFocusLossTransient();
            break;
          case 'onAudioFocusLossTransientCanDuck':
            _handleAudioFocusLossTransientCanDuck();
            break;
        }
      });

      // Request initial audio focus
      await _requestAudioFocus();
    } catch (e) {
      _logger.error('Error setting up audio focus: $e');
    }
  }

  /// Request audio focus on Android
  Future<void> _requestAudioFocus() async {
    if (!Platform.isAndroid) return;

    try {
      final result = await _audioFocusChannel.invokeMethod('requestAudioFocus');
      _hasAudioFocus = result == true;
      _logger.debug('Audio focus requested: $_hasAudioFocus');
    } catch (e) {
      _logger.error('Error requesting audio focus: $e');
    }
  }

  /// Abandon audio focus on Android
  Future<void> _abandonAudioFocus() async {
    if (!Platform.isAndroid) return;

    try {
      await _audioFocusChannel.invokeMethod('abandonAudioFocus');
      _hasAudioFocus = false;
      _logger.debug('Audio focus abandoned');
    } catch (e) {
      _logger.error('Error abandoning audio focus: $e');
    }
  }

  /// Handle audio focus gain
  void _handleAudioFocusGain() {
    _hasAudioFocus = true;
    _isDucking = false;
    _restoreVolume();
    _logger.debug('Audio focus gained');
  }

  /// Handle permanent audio focus loss
  void _handleAudioFocusLoss() {
    _hasAudioFocus = false;
    stopAllSounds();
    _logger.debug('Audio focus lost');
  }

  /// Handle transient audio focus loss
  void _handleAudioFocusLossTransient() {
    _hasAudioFocus = false;
    pauseAllSounds();
    _logger.debug('Audio focus lost transiently');
  }

  /// Handle audio focus loss with ducking
  void _handleAudioFocusLossTransientCanDuck() {
    _startDucking();
    _logger.debug('Audio focus lost - ducking');
  }

  /// Start audio ducking
  void _startDucking() {
    _isDucking = true;
    _applyDucking();

    // Auto-restore after 3 seconds if no other audio
    _duckingTimer?.cancel();
    _duckingTimer = Timer(const Duration(seconds: 3), () {
      if (_isDucking) {
        _stopDucking();
      }
    });
  }

  /// Stop audio ducking
  void _stopDucking() {
    _isDucking = false;
    _duckingTimer?.cancel();
    _restoreVolume();
  }

  /// Apply ducking to all active players
  void _applyDucking() {
    for (final entry in _players.entries) {
      final volume = _getVolumeForPlayer(entry.key) * _duckingLevel;
      entry.value.setVolume(volume);
    }
  }

  /// Restore normal volume to all players
  void _restoreVolume() {
    for (final entry in _players.entries) {
      final volume = _getVolumeForPlayer(entry.key);
      entry.value.setVolume(volume);
    }
  }

  /// Get appropriate volume for a player based on its type
  double _getVolumeForPlayer(String playerId) {
    double typeVolume = _effectsVolume;

    if (playerId.contains('voice') || playerId.contains('livekit')) {
      typeVolume = _voiceVolume;
    } else if (playerId.contains('notification') || playerId.contains('message')) {
      typeVolume = _notificationVolume;
    }

    final volume = _masterVolume * typeVolume;
    return _isDucking ? volume * _duckingLevel : volume;
  }

  /// Preload critical sounds
  Future<void> _preloadCriticalSounds() async {
    for (final soundKey in criticalSounds) {
      final path = audioFiles[soundKey];
      if (path != null) {
        await _cacheAudio(soundKey, 'assets/$path');
      }
    }
  }

  /// Cache audio file in memory
  Future<void> _cacheAudio(String key, String assetPath) async {
    try {
      // Check cache size limit
      if (_currentCacheSize >= _maxCacheSize) {
        _cleanOldestCacheEntries();
      }

      // Load audio data
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();

      // Update cache
      _audioCache[key] = bytes;
      _cacheTimestamps[key] = DateTime.now();
      _currentCacheSize += bytes.length;

      _logger.debug('Cached audio: $key (${bytes.length} bytes)');
    } catch (e) {
      _logger.error('Failed to cache audio $key: $e');
    }
  }

  /// Clean expired cache entries
  void _cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    _cacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) > _cacheExpiration) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      final bytes = _audioCache.remove(key);
      if (bytes != null) {
        _currentCacheSize -= bytes.length;
      }
      _cacheTimestamps.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      _logger.debug('Cleaned ${expiredKeys.length} expired cache entries');
    }
  }

  /// Clean oldest cache entries when size limit reached
  void _cleanOldestCacheEntries() {
    final sortedEntries = _cacheTimestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Remove oldest 20% of cache
    final removeCount = (sortedEntries.length * 0.2).ceil();
    for (int i = 0; i < removeCount && i < sortedEntries.length; i++) {
      final key = sortedEntries[i].key;
      final bytes = _audioCache.remove(key);
      if (bytes != null) {
        _currentCacheSize -= bytes.length;
      }
      _cacheTimestamps.remove(key);
    }

    _logger.debug('Cleaned $removeCount old cache entries');
  }

  /// Play a sound with all enhancements
  Future<void> playSound(
    String soundKey, {
    double? volume,
    bool loop = false,
    bool isDuckable = true,
    bool withHaptics = false,
    HapticType hapticType = HapticType.light,
    String? playerId,
  }) async {
    if (_isMuted) return;

    try {
      // Check permission for voice-related sounds
      if (soundKey.contains('voice') && !_hasAudioPermission) {
        _logger.warning('No audio permission for voice playback');
        return;
      }

      // Apply ducking to other sounds if this is a notification
      if (soundKey.contains('notification') || soundKey.contains('message')) {
        _startDucking();
        Timer(const Duration(milliseconds: 500), _stopDucking);
      }

      // Get or create player
      final id = playerId ?? soundKey;
      final player = _getOrCreatePlayer(id);

      // Determine volume
      final finalVolume = volume ?? _getVolumeForPlayer(id);

      // Play from cache or asset
      if (_audioCache.containsKey(soundKey)) {
        final source = BytesSource(_audioCache[soundKey]!);
        await player.play(source, volume: finalVolume);
      } else {
        final path = audioFiles[soundKey] ?? soundKey;
        await player.play(AssetSource(path), volume: finalVolume);

        // Cache for future use if not critical
        if (!criticalSounds.contains(soundKey)) {
          _cacheAudio(soundKey, 'assets/$path');
        }
      }

      // Set loop mode
      await player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);

      // Trigger haptic feedback
      if (withHaptics && _hapticsEnabled && _hasVibrationPermission) {
        _triggerHaptics(hapticType);
      }

      _logger.debug('Playing sound: $soundKey (volume: $finalVolume)');
    } catch (e) {
      _logger.error('Failed to play sound $soundKey: $e');
    }
  }

  /// Trigger haptic feedback
  void _triggerHaptics(HapticType type) {
    if (!_hapticsEnabled || !_hasVibrationPermission) return;

    try {
      switch (type) {
        case HapticType.light:
          HapticFeedback.lightImpact();
          break;
        case HapticType.medium:
          HapticFeedback.mediumImpact();
          break;
        case HapticType.heavy:
          HapticFeedback.heavyImpact();
          break;
        case HapticType.selection:
          HapticFeedback.selectionClick();
          break;
        case HapticType.vibrate:
          Vibration.vibrate(duration: 50);
          break;
      }
    } catch (e) {
      _logger.error('Failed to trigger haptics: $e');
    }
  }

  /// Stop a specific sound
  Future<void> stopSound(String playerId) async {
    try {
      final player = _players[playerId];
      if (player != null) {
        await player.stop();
        _logger.debug('Stopped sound: $playerId');
      }
    } catch (e) {
      _logger.error('Failed to stop sound $playerId: $e');
    }
  }

  /// Pause all sounds
  Future<void> pauseAllSounds() async {
    for (final player in _players.values) {
      await player.pause();
    }
    _logger.debug('Paused all sounds');
  }

  /// Resume all sounds
  Future<void> resumeAllSounds() async {
    for (final player in _players.values) {
      await player.resume();
    }
    _logger.debug('Resumed all sounds');
  }

  /// Stop all sounds
  Future<void> stopAllSounds() async {
    for (final player in _players.values) {
      await player.stop();
    }
    _logger.debug('Stopped all sounds');
  }

  /// Set master volume
  Future<void> setMasterVolume(double volume) async {
    _masterVolume = volume.clamp(0.0, 1.0);
    _restoreVolume();
    await _saveUserPreferences();
    _logger.debug('Master volume set to: $_masterVolume');
  }

  /// Set effects volume
  Future<void> setEffectsVolume(double volume) async {
    _effectsVolume = volume.clamp(0.0, 1.0);
    _restoreVolume();
    await _saveUserPreferences();
    _logger.debug('Effects volume set to: $_effectsVolume');
  }

  /// Set voice volume
  Future<void> setVoiceVolume(double volume) async {
    _voiceVolume = volume.clamp(0.0, 1.0);
    _restoreVolume();
    await _saveUserPreferences();
    _logger.debug('Voice volume set to: $_voiceVolume');
  }

  /// Set notification volume
  Future<void> setNotificationVolume(double volume) async {
    _notificationVolume = volume.clamp(0.0, 1.0);
    _restoreVolume();
    await _saveUserPreferences();
    _logger.debug('Notification volume set to: $_notificationVolume');
  }

  /// Set mute state
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    if (_isMuted) {
      await stopAllSounds();
    }
    await _saveUserPreferences();
    _logger.debug('Audio muted: $_isMuted');
  }

  /// Set haptics enabled
  Future<void> setHapticsEnabled(bool enabled) async {
    _hapticsEnabled = enabled;
    await _saveUserPreferences();
    _logger.debug('Haptics enabled: $_hapticsEnabled');
  }

  /// Play timer warning sound
  Future<void> playTimerWarning() async {
    await playSound('timer_warning',
      withHaptics: true,
      hapticType: HapticType.medium,
      isDuckable: false,
    );
  }

  /// Play timer expired sound
  Future<void> playTimerExpired() async {
    await playSound('timer_expired',
      withHaptics: true,
      hapticType: HapticType.heavy,
      isDuckable: false,
    );
  }

  /// Play notification sound
  Future<void> playNotification() async {
    await playSound('notification',
      withHaptics: true,
      hapticType: HapticType.light,
    );
  }

  /// Play message received sound
  Future<void> playMessageReceived() async {
    await playSound('message',
      withHaptics: true,
      hapticType: HapticType.selection,
    );
  }

  /// Play challenge sound
  Future<void> playChallenge() async {
    await playSound('challenge',
      withHaptics: true,
      hapticType: HapticType.medium,
    );
  }

  /// Play applause sound
  Future<void> playApplause() async {
    await playSound('applause',
      withHaptics: true,
      hapticType: HapticType.heavy,
    );
  }

  /// Get or create an audio player
  AudioPlayer _getOrCreatePlayer(String playerId) {
    if (!_players.containsKey(playerId)) {
      _players[playerId] = AudioPlayer();
      _players[playerId]!.setPlayerMode(PlayerMode.lowLatency);
    }
    return _players[playerId]!;
  }

  /// Get audio statistics
  Map<String, dynamic> getStatistics() {
    return {
      'activePlayers': _players.length,
      'cachedSounds': _audioCache.length,
      'cacheSize': '${(_currentCacheSize / 1024 / 1024).toStringAsFixed(2)} MB',
      'masterVolume': _masterVolume,
      'effectsVolume': _effectsVolume,
      'voiceVolume': _voiceVolume,
      'notificationVolume': _notificationVolume,
      'isMuted': _isMuted,
      'hapticsEnabled': _hapticsEnabled,
      'hasAudioFocus': _hasAudioFocus,
      'isDucking': _isDucking,
      'permissions': {
        'audio': _hasAudioPermission,
        'vibration': _hasVibrationPermission,
      },
    };
  }

  /// Clean up a specific player
  Future<void> disposePlayer(String playerId) async {
    final player = _players.remove(playerId);
    if (player != null) {
      await player.dispose();
    }

    final controller = _volumeControllers.remove(playerId);
    await controller?.close();
  }

  /// Dispose of the service
  Future<void> dispose() async {
    try {
      // Stop all sounds
      await stopAllSounds();

      // Abandon audio focus
      if (Platform.isAndroid) {
        await _abandonAudioFocus();
      }

      // Cancel timers
      _duckingTimer?.cancel();

      // Dispose all players
      for (final player in _players.values) {
        await player.dispose();
      }
      _players.clear();

      // Close all controllers
      for (final controller in _volumeControllers.values) {
        await controller.close();
      }
      _volumeControllers.clear();

      // Clear cache
      _audioCache.clear();
      _cacheTimestamps.clear();
      _currentCacheSize = 0;

      _logger.info('Enhanced Audio Service disposed');
    } catch (e) {
      _logger.error('Error disposing Enhanced Audio Service: $e');
    }
  }
}

/// Haptic feedback types
enum HapticType {
  light,
  medium,
  heavy,
  selection,
  vibrate,
}