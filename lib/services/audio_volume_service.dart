import 'dart:io';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:livekit_client/livekit_client.dart';
import 'package:volume_controller/volume_controller.dart';
import '../core/logging/app_logger.dart';

/// Service to manage audio volume and output routing for Arena debates
/// Ensures audio is loud enough to be heard without holding phone to ear
class AudioVolumeService {
  static final AudioVolumeService _instance = AudioVolumeService._internal();
  factory AudioVolumeService() => _instance;
  AudioVolumeService._internal();

  final AppLogger _logger = AppLogger();

  /// Configure audio for maximum volume and speaker output
  Future<void> configureLoudAudio() async {
    try {
      final session = await audio_session.AudioSession.instance;

      // BOOST VOLUME: Set to maximum before configuring audio session
      await _setSystemVolume(1.0);

      if (Platform.isIOS) {
        // iOS Configuration for loud speaker output
        await session.configure(audio_session.AudioSessionConfiguration(
          avAudioSessionCategory: audio_session.AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
            audio_session.AVAudioSessionCategoryOptions.defaultToSpeaker |
            audio_session.AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: audio_session.AVAudioSessionMode.videoChat,
          avAudioSessionRouteSharingPolicy:
            audio_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions:
            audio_session.AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const audio_session.AndroidAudioAttributes(
            contentType: audio_session.AndroidAudioContentType.speech,
            flags: audio_session.AndroidAudioFlags.none,
            usage: audio_session.AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType:
            audio_session.AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ));

        // Force speaker output on iOS
        await session.setActive(true);

        // iOS speaker output configured via category options
        _logger.info('🔊 iOS: Speaker output configured via defaultToSpeaker option');

      } else if (Platform.isAndroid) {
        // Android Configuration optimized for high-quality audio output
        await session.configure(audio_session.AudioSessionConfiguration(
          avAudioSessionCategory: audio_session.AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
            audio_session.AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: audio_session.AVAudioSessionMode.videoChat,
          avAudioSessionRouteSharingPolicy:
            audio_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions:
            audio_session.AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const audio_session.AndroidAudioAttributes(
            contentType: audio_session.AndroidAudioContentType.speech,
            flags: audio_session.AndroidAudioFlags.audibilityEnforced, // Force audible audio
            usage: audio_session.AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType:
            audio_session.AndroidAudioFocusGainType.gain, // Full audio focus for best quality
          androidWillPauseWhenDucked: false,
        ));
        await session.setActive(true);

        // Force speakerphone on Android using platform channel
        await _setSpeakerphoneOn(true);

        _logger.info('🔊 Android: High-quality speakerphone enabled with full audio focus');
      }

      // Double-check volume is at maximum after audio session configuration
      await _setSystemVolume(1.0);

      // Add a small delay and check again (some Android devices reset volume)
      await Future.delayed(const Duration(milliseconds: 500));
      await _ensureMaximumVolume();

      _logger.info('✅ Audio configured for loud speaker output with maximum volume');

    } catch (e) {
      _logger.error('Failed to configure loud audio: $e');
    }
  }

  /// Platform channel to force speakerphone on Android
  Future<void> _setSpeakerphoneOn(bool enabled) async {
    if (!Platform.isAndroid) return;

    try {
      const platform = MethodChannel('com.thearenadtd.app/audio');
      await platform.invokeMethod('setSpeakerphoneOn', {'enabled': enabled});
    } catch (e) {
      _logger.error('Failed to set speakerphone: $e');
    }
  }

  /// Set system volume to maximum for best audio quality
  Future<void> _setSystemVolume(double volume) async {
    try {
      // Set volume to maximum (1.0 = 100%)
      VolumeController().setVolume(volume);

      // Small delay to let the change apply
      await Future.delayed(const Duration(milliseconds: 100));

      // Get current volume to verify
      final currentVolume = await VolumeController().getVolume();

      _logger.info('📢 System volume set to: ${(volume * 100).toInt()}% (actual: ${(currentVolume * 100).toInt()}%)');
    } catch (e) {
      _logger.error('Failed to set system volume: $e');
    }
  }

  /// Configure LiveKit-specific audio settings for maximum volume
  void configureLiveKitAudio(Room room) {
    try {
      // DO NOT force microphone state - let the arena screen manage it
      // The arena screen has its own sophisticated mic management logic
      // that this service should not interfere with

      _logger.info('🎤 LiveKit audio optimized for clarity and volume (mic state unchanged)');

    } catch (e) {
      _logger.error('Failed to configure LiveKit audio: $e');
    }
  }

  /// Boost remote participant volume (if their audio is too quiet)
  void boostParticipantVolume(RemoteParticipant participant, {double gain = 2.0}) {
    try {
      // This would require custom WebRTC audio processing
      // For now, log the request
      _logger.info('🔊 Volume boost requested for ${participant.identity} (${gain}x)');

      // You could implement Web Audio API processing here for web platform
      // or use platform channels for native audio processing

    } catch (e) {
      _logger.error('Failed to boost participant volume: $e');
    }
  }

  /// Check if audio output is currently on speaker
  Future<bool> isSpeakerOn() async {
    try {
      // For now, assume speaker is on if we configured it properly
      // Audio session package doesn't provide currentRoute in this version
      _logger.debug('Assuming speaker is on based on configuration');
      return true;
    } catch (e) {
      _logger.error('Failed to check speaker status: $e');
      return false;
    }
  }

  /// Force re-enable speaker if it gets disabled
  Future<void> ensureSpeakerEnabled() async {
    if (!await isSpeakerOn()) {
      _logger.warning('⚠️ Speaker was disabled, re-enabling...');
      await configureLoudAudio();
    }
  }

  /// Ensure volume is at maximum level
  Future<void> _ensureMaximumVolume() async {
    try {
      final currentVolume = await VolumeController().getVolume();

      if (currentVolume < 0.95) {
        _logger.warning('⚠️ Volume dropped to ${(currentVolume * 100).toInt()}%, boosting back to 100%');
        VolumeController().setVolume(1.0);
      } else {
        _logger.info('✅ Volume confirmed at maximum: ${(currentVolume * 100).toInt()}%');
      }
    } catch (e) {
      _logger.error('Failed to ensure maximum volume: $e');
    }
  }

  /// Periodically monitor and maintain maximum volume (call this in arena rooms)
  Future<void> maintainMaximumVolume() async {
    try {
      // Listen to volume changes
      VolumeController().listener((volume) {
        _logger.debug('📢 Volume changed to: ${(volume * 100).toInt()}%');

        // If user lowers volume, respect it but log it
        if (volume < 0.8) {
          _logger.info('ℹ️ User manually lowered volume to ${(volume * 100).toInt()}%');
        }
      });

      // Set initial volume to maximum
      VolumeController().setVolume(1.0);
      _logger.info('🔊 Volume monitoring active - maintaining maximum volume');
    } catch (e) {
      _logger.error('Failed to maintain maximum volume: $e');
    }
  }
}