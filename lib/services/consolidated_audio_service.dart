import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../core/logging/app_logger.dart';

/// Consolidated audio service combining all audio-related functionality
/// Merges: audio_clip_service, audio_preloader_service, audio_volume_service,
/// background_audio_service, persistent_audio_service, sound_service
class ConsolidatedAudioService {
  static final ConsolidatedAudioService _instance = ConsolidatedAudioService._internal();
  factory ConsolidatedAudioService() => _instance;
  ConsolidatedAudioService._internal();

  final AppLogger _logger = AppLogger();
  final Map<String, AudioPlayer> _players = {};
  final Map<String, Uint8List> _preloadedAudio = {};
  final Map<String, StreamController<double>> _volumeControllers = {};

  bool _initialized = false;
  double _masterVolume = 1.0;
  bool _isMuted = false;

  // Audio file paths
  static const String timerWarningSound = 'sounds/30sec.mp3';
  static const String timerExpiredSound = 'sounds/arenazero.mp3';
  static const String notificationSound = 'sounds/notification.mp3';
  static const String messageSound = 'sounds/message.mp3';
  static const String joinSound = 'sounds/join.mp3';
  static const String leaveSound = 'sounds/leave.mp3';

  /// Initialize the audio service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _logger.info('🔊 Initializing consolidated audio service');

      // Preload critical sounds
      await _preloadCriticalSounds();

      _initialized = true;
      _logger.info('✅ Audio service initialized');
    } catch (e) {
      _logger.error('Failed to initialize audio service: $e');
    }
  }

  /// Preload critical audio files
  Future<void> _preloadCriticalSounds() async {
    final criticalSounds = [
      timerWarningSound,
      timerExpiredSound,
      notificationSound,
      messageSound,
    ];

    for (final sound in criticalSounds) {
      await preloadAudio(sound);
    }
  }

  /// Preload an audio file into memory
  Future<void> preloadAudio(String assetPath) async {
    try {
      if (_preloadedAudio.containsKey(assetPath)) return;

      final data = await rootBundle.load('assets/$assetPath');
      _preloadedAudio[assetPath] = data.buffer.asUint8List();
      _logger.debug('Preloaded audio: $assetPath');
    } catch (e) {
      _logger.error('Failed to preload audio $assetPath: $e');
    }
  }

  /// Play an audio clip
  Future<void> playSound(
    String assetPath, {
    double volume = 1.0,
    bool loop = false,
    String? playerId,
  }) async {
    if (_isMuted) return;

    try {
      final player = _getOrCreatePlayer(playerId ?? assetPath);

      // Use preloaded data if available
      if (_preloadedAudio.containsKey(assetPath)) {
        final source = BytesSource(_preloadedAudio[assetPath]!);
        await player.play(source, volume: volume * _masterVolume);
      } else {
        await player.play(AssetSource(assetPath), volume: volume * _masterVolume);
      }

      if (loop) {
        await player.setReleaseMode(ReleaseMode.loop);
      } else {
        await player.setReleaseMode(ReleaseMode.release);
      }

      _logger.debug('Playing sound: $assetPath');
    } catch (e) {
      _logger.error('Failed to play sound $assetPath: $e');
    }
  }

  /// Stop a specific audio player
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

  /// Stop all sounds
  Future<void> stopAllSounds() async {
    for (final player in _players.values) {
      await player.stop();
    }
    _logger.debug('Stopped all sounds');
  }

  /// Set the master volume (0.0 to 1.0)
  Future<void> setMasterVolume(double volume) async {
    _masterVolume = volume.clamp(0.0, 1.0);

    // Update volume for all active players
    for (final player in _players.values) {
      await player.setVolume(_masterVolume);
    }

    _logger.debug('Master volume set to: $_masterVolume');
  }

  /// Get the master volume
  double get masterVolume => _masterVolume;

  /// Mute/unmute all sounds
  void setMuted(bool muted) {
    _isMuted = muted;

    if (_isMuted) {
      stopAllSounds();
    }

    _logger.debug('Audio muted: $_isMuted');
  }

  /// Check if audio is muted
  bool get isMuted => _isMuted;

  /// Play timer warning sound (30 seconds remaining)
  Future<void> playTimerWarning() async {
    await playSound(timerWarningSound, playerId: 'timer_warning');
  }

  /// Play timer expired sound
  Future<void> playTimerExpired() async {
    await playSound(timerExpiredSound, playerId: 'timer_expired');
  }

  /// Play notification sound
  Future<void> playNotification() async {
    await playSound(notificationSound, playerId: 'notification');
  }

  /// Play message received sound
  Future<void> playMessageReceived() async {
    await playSound(messageSound, playerId: 'message');
  }

  /// Play user joined sound
  Future<void> playUserJoined() async {
    await playSound(joinSound, playerId: 'user_join');
  }

  /// Play user left sound
  Future<void> playUserLeft() async {
    await playSound(leaveSound, playerId: 'user_leave');
  }

  /// Create a volume stream for a specific player
  Stream<double> getVolumeStream(String playerId) {
    if (!_volumeControllers.containsKey(playerId)) {
      _volumeControllers[playerId] = StreamController<double>.broadcast();
    }
    return _volumeControllers[playerId]!.stream;
  }

  /// Set volume for a specific player
  Future<void> setPlayerVolume(String playerId, double volume) async {
    final player = _players[playerId];
    if (player != null) {
      final adjustedVolume = (volume * _masterVolume).clamp(0.0, 1.0);
      await player.setVolume(adjustedVolume);
      _volumeControllers[playerId]?.add(adjustedVolume);
    }
  }

  /// Get or create an audio player
  AudioPlayer _getOrCreatePlayer(String playerId) {
    if (!_players.containsKey(playerId)) {
      _players[playerId] = AudioPlayer();
      _players[playerId]!.setPlayerMode(PlayerMode.lowLatency);
    }
    return _players[playerId]!;
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

  /// Clean up all resources
  Future<void> dispose() async {
    try {
      // Stop all sounds
      await stopAllSounds();

      // Dispose all players
      for (final player in _players.values) {
        await player.dispose();
      }
      _players.clear();

      // Close all volume controllers
      for (final controller in _volumeControllers.values) {
        await controller.close();
      }
      _volumeControllers.clear();

      // Clear preloaded audio
      _preloadedAudio.clear();

      _initialized = false;
      _logger.info('Audio service disposed');
    } catch (e) {
      _logger.error('Error disposing audio service: $e');
    }
  }

  /// Get service statistics
  Map<String, dynamic> getStatistics() {
    return {
      'initialized': _initialized,
      'activePlayers': _players.length,
      'preloadedSounds': _preloadedAudio.length,
      'masterVolume': _masterVolume,
      'isMuted': _isMuted,
      'volumeControllers': _volumeControllers.length,
    };
  }
}