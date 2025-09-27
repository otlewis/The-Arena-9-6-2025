import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/logging/app_logger.dart';

/// Service for preloading critical audio assets at app startup
/// Ensures zero-delay audio playback during debates and discussions
class AudioPreloaderService {
  static final AudioPreloaderService _instance = AudioPreloaderService._internal();
  factory AudioPreloaderService() => _instance;
  AudioPreloaderService._internal();

  final AppLogger _logger = AppLogger();

  // Audio players for preloaded assets
  final Map<String, AudioPlayer> _preloadedPlayers = {};
  final Map<String, Uint8List> _audioBuffers = {};

  // Preload status tracking
  final Map<String, bool> _preloadStatus = {};
  final Map<String, DateTime> _preloadTimes = {};
  bool _isInitialized = false;

  // Critical audio assets for Arena app
  static const Map<String, String> _criticalAudioAssets = {
    // Timer sounds
    'timer_30_second_warning': 'assets/audio/30sec.mp3',
    'timer_zero': 'assets/audio/arenazero.mp3',

    // UI feedback sounds
    'button_click': 'assets/audio/button_click.mp3',
    'notification_sound': 'assets/audio/notification.mp3',
    'success_sound': 'assets/audio/success.mp3',
    'error_sound': 'assets/audio/error.mp3',

    // Arena-specific sounds
    'debate_start': 'assets/audio/debate_start.mp3',
    'debate_end': 'assets/audio/debate_end.mp3',
    'hand_raise': 'assets/audio/hand_raise.mp3',
    'speaker_joined': 'assets/audio/speaker_joined.mp3',
    'speaker_left': 'assets/audio/speaker_left.mp3',

    // Award and achievement sounds
    'coin_earned': 'assets/audio/coin_earned.mp3',
    'gift_received': 'assets/audio/gift_received.mp3',
    'level_up': 'assets/audio/level_up.mp3',

    // Communication sounds
    'message_received': 'assets/audio/message_received.mp3',
    'challenge_received': 'assets/audio/challenge_received.mp3',
    'room_joined': 'assets/audio/room_joined.mp3',
  };

  /// Initialize and preload all critical audio assets
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.debug('🔊 Audio preloader already initialized');
      return;
    }

    _logger.info('🔊 Starting audio asset preloading...');
    final startTime = DateTime.now();

    try {
      // Preload all critical audio assets in parallel
      final preloadFutures = _criticalAudioAssets.entries.map((entry) =>
          _preloadAudioAsset(entry.key, entry.value)
      ).toList();

      await Future.wait(preloadFutures);

      final duration = DateTime.now().difference(startTime);
      final successCount = _preloadStatus.values.where((status) => status).length;

      _logger.info('🔊 Audio preloading completed in ${duration.inMilliseconds}ms');
      _logger.info('🔊 Successfully preloaded $successCount/${_criticalAudioAssets.length} audio assets');

      _isInitialized = true;
      _logPreloadStatistics();

    } catch (e) {
      _logger.error('❌ Audio preloading failed: $e');
      _isInitialized = false;
    }
  }

  /// Preload a single audio asset
  Future<void> _preloadAudioAsset(String key, String assetPath) async {
    try {
      final startTime = DateTime.now();

      // Check if asset exists first
      if (!await _assetExists(assetPath)) {
        _logger.warning('⚠️ Audio asset not found: $assetPath');
        _preloadStatus[key] = false;
        return;
      }

      // Note: Using asset source for LOW_LATENCY compatibility on Android

      // Create and configure audio player
      final player = AudioPlayer();

      // Configure player - use asset source instead of bytes for LOW_LATENCY compatibility
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setVolume(1.0);

      // Preload the audio file using asset source (Android LOW_LATENCY compatible)
      await player.setSourceAsset(assetPath);

      _preloadedPlayers[key] = player;
      _preloadStatus[key] = true;
      _preloadTimes[key] = DateTime.now();

      final duration = DateTime.now().difference(startTime);
      _logger.debug('✅ Preloaded audio: $key (${duration.inMilliseconds}ms)');

    } catch (e) {
      _logger.error('❌ Failed to preload audio $key: $e');
      _preloadStatus[key] = false;
    }
  }

  /// Check if an asset exists in the bundle
  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Play a preloaded audio asset
  Future<void> playAudio(String key, {double volume = 1.0}) async {
    try {
      final player = _preloadedPlayers[key];
      if (player == null) {
        _logger.warning('⚠️ Audio asset not preloaded: $key');
        return;
      }

      // Set volume and play
      await player.setVolume(volume);
      await player.resume(); // Use resume for preloaded audio

      _logger.debug('🔊 Playing preloaded audio: $key (volume: $volume)');

    } catch (e) {
      _logger.error('❌ Failed to play audio $key: $e');
    }
  }

  /// Play audio with specific configuration
  Future<void> playAudioWithConfig(String key, {
    double volume = 1.0,
    bool loop = false,
    double playbackRate = 1.0,
  }) async {
    try {
      final player = _preloadedPlayers[key];
      if (player == null) {
        _logger.warning('⚠️ Audio asset not preloaded: $key');
        return;
      }

      // Configure playback
      await player.setVolume(volume);
      await player.setPlaybackRate(playbackRate);

      if (loop) {
        await player.setReleaseMode(ReleaseMode.loop);
      } else {
        await player.setReleaseMode(ReleaseMode.release);
      }

      await player.resume();

      _logger.debug('🔊 Playing audio $key (volume: $volume, loop: $loop, rate: $playbackRate)');

    } catch (e) {
      _logger.error('❌ Failed to play audio $key with config: $e');
    }
  }

  /// Stop a specific audio
  Future<void> stopAudio(String key) async {
    try {
      final player = _preloadedPlayers[key];
      if (player != null) {
        await player.stop();
        _logger.debug('⏹️ Stopped audio: $key');
      }
    } catch (e) {
      _logger.error('❌ Failed to stop audio $key: $e');
    }
  }

  /// Stop all playing audio
  Future<void> stopAllAudio() async {
    try {
      final stopFutures = _preloadedPlayers.values.map((player) => player.stop());
      await Future.wait(stopFutures);
      _logger.debug('⏹️ Stopped all audio');
    } catch (e) {
      _logger.error('❌ Failed to stop all audio: $e');
    }
  }

  /// Check if an audio asset is preloaded and ready
  bool isAudioReady(String key) {
    return _preloadStatus[key] == true && _preloadedPlayers.containsKey(key);
  }

  /// Get preload status for all assets
  Map<String, bool> getPreloadStatus() {
    return Map.from(_preloadStatus);
  }

  /// Get preloading statistics
  Map<String, dynamic> getStatistics() {
    final successCount = _preloadStatus.values.where((status) => status).length;
    final totalAssets = _criticalAudioAssets.length;
    final successRate = totalAssets > 0 ? (successCount / totalAssets) : 0.0;

    return {
      'isInitialized': _isInitialized,
      'totalAssets': totalAssets,
      'successfullyPreloaded': successCount,
      'failedToPreload': totalAssets - successCount,
      'successRate': successRate,
      'memoryUsage': _calculateMemoryUsage(),
      'preloadTimes': Map.from(_preloadTimes),
    };
  }

  /// Calculate approximate memory usage of preloaded audio
  int _calculateMemoryUsage() {
    int totalBytes = 0;
    for (final buffer in _audioBuffers.values) {
      totalBytes += buffer.length;
    }
    return totalBytes;
  }

  /// Log detailed preload statistics
  void _logPreloadStatistics() {
    final stats = getStatistics();
    _logger.info('🔊 AUDIO PRELOADER STATISTICS:');
    _logger.info('  • Total Assets: ${stats['totalAssets']}');
    _logger.info('  • Successfully Preloaded: ${stats['successfullyPreloaded']}');
    _logger.info('  • Failed to Preload: ${stats['failedToPreload']}');
    _logger.info('  • Success Rate: ${(stats['successRate'] * 100).toStringAsFixed(1)}%');
    _logger.info('  • Memory Usage: ${(stats['memoryUsage'] / 1024 / 1024).toStringAsFixed(2)} MB');
    _logger.info('  • Initialization Status: ${stats['isInitialized']}');
  }

  /// Reload a specific audio asset
  Future<void> reloadAudio(String key) async {
    final assetPath = _criticalAudioAssets[key];
    if (assetPath == null) {
      _logger.warning('⚠️ Unknown audio key: $key');
      return;
    }

    // Dispose existing player if any
    final existingPlayer = _preloadedPlayers.remove(key);
    await existingPlayer?.dispose();

    // Remove from buffers and status
    _audioBuffers.remove(key);
    _preloadStatus.remove(key);
    _preloadTimes.remove(key);

    // Reload the asset
    await _preloadAudioAsset(key, assetPath);
    _logger.info('🔄 Reloaded audio asset: $key');
  }

  /// Validate all preloaded audio assets
  Future<Map<String, bool>> validatePreloadedAssets() async {
    final validationResults = <String, bool>{};

    for (final key in _preloadedPlayers.keys) {
      try {
        final player = _preloadedPlayers[key];
        if (player != null) {
          // Test if the player can play (at very low volume)
          await player.setVolume(0.01);
          await player.resume();
          await Future.delayed(const Duration(milliseconds: 50));
          await player.stop();

          validationResults[key] = true;
          _logger.debug('✅ Validated audio: $key');
        } else {
          validationResults[key] = false;
        }
      } catch (e) {
        validationResults[key] = false;
        _logger.warning('⚠️ Validation failed for audio $key: $e');
      }
    }

    final validCount = validationResults.values.where((valid) => valid).length;
    _logger.info('🔍 Audio validation: $validCount/${validationResults.length} assets valid');

    return validationResults;
  }

  /// Dispose all resources
  Future<void> dispose() async {
    try {
      // Stop all playing audio
      await stopAllAudio();

      // Dispose all audio players
      final disposeFutures = _preloadedPlayers.values.map((player) => player.dispose());
      await Future.wait(disposeFutures);

      // Clear all data structures
      _preloadedPlayers.clear();
      _audioBuffers.clear();
      _preloadStatus.clear();
      _preloadTimes.clear();

      _isInitialized = false;
      _logger.info('🧹 Audio preloader service disposed');

    } catch (e) {
      _logger.error('❌ Error disposing audio preloader: $e');
    }
  }
}

/// Helper extension for easy access to common audio functions
extension AudioPreloaderExtension on AudioPreloaderService {
  // Timer-specific sounds
  Future<void> playTimerWarning() => playAudio('timer_30_second_warning', volume: 0.8);
  Future<void> playTimerZero() => playAudio('timer_zero', volume: 1.0);

  // UI feedback sounds
  Future<void> playButtonClick() => playAudio('button_click', volume: 0.5);
  Future<void> playNotification() => playAudio('notification_sound', volume: 0.7);
  Future<void> playSuccess() => playAudio('success_sound', volume: 0.6);
  Future<void> playError() => playAudio('error_sound', volume: 0.7);

  // Arena event sounds
  Future<void> playDebateStart() => playAudio('debate_start', volume: 0.8);
  Future<void> playDebateEnd() => playAudio('debate_end', volume: 0.8);
  Future<void> playHandRaise() => playAudio('hand_raise', volume: 0.6);
  Future<void> playSpeakerJoined() => playAudio('speaker_joined', volume: 0.5);
  Future<void> playSpeakerLeft() => playAudio('speaker_left', volume: 0.5);

  // Communication sounds
  Future<void> playMessageReceived() => playAudio('message_received', volume: 0.4);
  Future<void> playChallengeReceived() => playAudio('challenge_received', volume: 0.8);
  Future<void> playRoomJoined() => playAudio('room_joined', volume: 0.6);

  // Achievement sounds
  Future<void> playCoinEarned() => playAudio('coin_earned', volume: 0.7);
  Future<void> playGiftReceived() => playAudio('gift_received', volume: 0.8);
  Future<void> playLevelUp() => playAudio('level_up', volume: 0.9);
}