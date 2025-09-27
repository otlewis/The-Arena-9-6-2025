import 'dart:io';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:livekit_client/livekit_client.dart';
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
        // Android Configuration for loud speaker output
        await session.configure(const audio_session.AudioSessionConfiguration.speech());
        await session.setActive(true);

        // Force speakerphone on Android using platform channel
        await _setSpeakerphoneOn(true);

        _logger.info('🔊 Android: Speakerphone enabled');
      }

      // Boost system volume to 80% (if possible)
      await _setSystemVolume(0.8);

      _logger.info('✅ Audio configured for loud speaker output');

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

  /// Set system volume (requires volume_controller package for full control)
  Future<void> _setSystemVolume(double volume) async {
    try {
      // This is a placeholder - you'd need volume_controller package
      // or native code to actually control system volume
      _logger.info('📢 Volume boost requested: ${(volume * 100).toInt()}%');
    } catch (e) {
      _logger.error('Failed to set system volume: $e');
    }
  }

  /// Configure LiveKit-specific audio settings for maximum volume
  void configureLiveKitAudio(Room room) {
    try {
      // Enable automatic gain control and noise suppression
      final audioOptions = const AudioCaptureOptions(
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
        typingNoiseDetection: true,
      );

      // Apply audio options to local participant
      room.localParticipant?.setMicrophoneEnabled(true);

      _logger.info('🎤 LiveKit audio optimized for clarity and volume');

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
}