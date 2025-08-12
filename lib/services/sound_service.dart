import 'package:audioplayers/audioplayers.dart';
import '../core/logging/app_logger.dart';

/// Service for managing app sound effects
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _soundEnabled = true;

  /// Initialize the sound service
  Future<void> initialize() async {
    try {
      // Set audio context for better performance and compatibility
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _audioPlayer.setVolume(1.0);
      
      AppLogger().debug('🔊 SoundService initialized with MediaPlayer mode');
    } catch (e) {
      AppLogger().error('Error initializing SoundService: $e');
    }
  }

  /// Enable or disable sound effects
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    AppLogger().debug('🔊 Sound ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Check if sound is enabled
  bool get isSoundEnabled => _soundEnabled;

  /// Play challenge received sound
  Future<void> playChallengeSound() async {
    await _playSound('challenge.mp3', 'challenge received');
  }

  /// Play 30-second warning sound
  Future<void> play30SecWarningSound() async {
    if (!_soundEnabled) return;
    
    try {
      AppLogger().debug('🔊 Playing 30-second warning sound');
      await _audioPlayer.play(AssetSource('audio/30sec.mp3'));
    } catch (e) {
      AppLogger().error('Error playing 30-second warning sound: $e');
    }
  }

  /// Play arena timer zero sound
  Future<void> playArenaZeroSound() async {
    if (!_soundEnabled) return;
    
    try {
      AppLogger().debug('🔊 Playing arena timer zero sound');
      await _audioPlayer.play(AssetSource('audio/arenazero.mp3'));
    } catch (e) {
      AppLogger().error('Error playing arena timer zero sound: $e');
    }
  }

  /// Play applause sound for winner celebration
  Future<void> playApplauseSound() async {
    if (!_soundEnabled) return;
    
    try {
      AppLogger().debug('🔊 Playing applause sound for winner celebration');
      await _audioPlayer.play(AssetSource('audio/applause.mp3'));
    } catch (e) {
      AppLogger().error('Error playing applause sound: $e');
    }
  }

  /// Play denied sound when challenge is declined
  Future<void> playDeniedSound() async {
    await _playSound('denied.mp3', 'denied sound for declined challenge');
  }

  /// Play instant message notification sound
  Future<void> playInstantMessageSound() async {
    await _playSound('instantmessage.mp3', 'instant message notification');
  }
  
  /// Play email notification sound
  Future<void> playEmailSound() async {
    await _playSound('email.mp3', 'email notification');
  }

  /// Play a custom sound file
  Future<void> playCustomSound(String fileName) async {
    if (!_soundEnabled) return;
    
    try {
      AppLogger().debug('🔊 Playing custom sound: $fileName');
      await _audioPlayer.play(AssetSource('audio/$fileName'));
    } catch (e) {
      AppLogger().error('Error playing custom sound $fileName: $e');
    }
  }

  /// Stop any currently playing sound
  Future<void> stopSound() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      AppLogger().error('Error stopping sound: $e');
    }
  }

  /// Common method to play any sound file
  Future<void> _playSound(String fileName, String description) async {
    AppLogger().debug('🔊 _playSound called for $description - soundEnabled: $_soundEnabled');
    
    if (!_soundEnabled) {
      AppLogger().debug('🔊 Sound disabled, not playing $description');
      return;
    }
    
    try {
      // Stop any currently playing sound to avoid conflicts
      await _audioPlayer.stop();
      
      AppLogger().debug('🔊 Playing $description ($fileName)');
      await _audioPlayer.play(AssetSource('audio/$fileName'));
      AppLogger().debug('🔊 Sound play command sent successfully for $description');
    } catch (e) {
      AppLogger().error('Error playing $description: $e');
    }
  }

  /// Test method to play a simple sound
  Future<void> testSound() async {
    await _playSound('ding.mp3', 'test sound');
  }

  /// Dispose of the audio player
  void dispose() {
    _audioPlayer.dispose();
    AppLogger().debug('🔊 SoundService disposed');
  }
}