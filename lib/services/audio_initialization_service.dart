import 'package:get_it/get_it.dart';
import '../core/logging/app_logger.dart';
import 'persistent_audio_service.dart';
import 'appwrite_service.dart';

/// Service responsible for initializing the persistent audio connection
/// when the user is authenticated and ready
class AudioInitializationService {
  static final AudioInitializationService _instance = AudioInitializationService._internal();
  factory AudioInitializationService() => _instance;
  AudioInitializationService._internal();

  bool _isInitialized = false;
  bool _isInitializing = false;

  /// Initialize audio service for authenticated user
  /// Call this after user authentication is confirmed
  Future<void> initializeForUser() async {
    if (_isInitialized || _isInitializing) {
      AppLogger().debug('🎵 AUDIO INIT: Audio already initialized or initializing, skipping');
      return;
    }

    _isInitializing = true;

    try {
      AppLogger().info('🎵 AUDIO INIT: Starting audio initialization for authenticated user');

      // Wait for AppwriteService to be ready (since it's registered as async)
      AppLogger().debug('🎵 AUDIO INIT: Waiting for AppwriteService to be ready...');
      await GetIt.instance.isReady<AppwriteService>();
      
      // Get current user from Appwrite
      final appwriteService = GetIt.instance<AppwriteService>();
      final currentUser = await appwriteService.getCurrentUser();

      if (currentUser == null) {
        AppLogger().warning('🎵 AUDIO INIT: No authenticated user found, cannot initialize audio');
        return;
      }

      final userId = currentUser.$id;
      AppLogger().info('🎵 AUDIO INIT: Initializing persistent audio for user: $userId');

      // Initialize persistent audio service with correct server URL
      final persistentAudioService = GetIt.instance<PersistentAudioService>();
      
      try {
        await persistentAudioService.initialize(
          userId: userId,
          serverUrl: 'ws://172.236.109.9:7880', // Use actual LiveKit server
        );

        _isInitialized = true;
        AppLogger().info('✅ AUDIO INIT: Persistent audio service initialized successfully for user: $userId');
        
      } catch (audioError) {
        AppLogger().error('❌ AUDIO INIT: Audio service initialization failed: $audioError');
        
        // Check if it's a network connectivity issue
        if (audioError.toString().contains('MediaConnectException') || 
            audioError.toString().contains('PeerConnection') ||
            audioError.toString().contains('timeout') ||
            audioError.toString().contains('network')) {
          AppLogger().warning('🌐 AUDIO INIT: Network connectivity issue detected - audio will retry automatically');
          // Don't mark as failed - the background health checker will retry
        } else {
          AppLogger().error('⚠️ AUDIO INIT: Non-network audio error: $audioError');
        }
        
        // Don't throw - allow app to continue with degraded audio
      }

    } catch (error) {
      AppLogger().error('❌ AUDIO INIT: Failed to initialize audio service: $error');
      // Don't throw - audio is not critical for app functionality
    } finally {
      _isInitializing = false;
    }
  }

  /// Check if audio is initialized
  bool get isInitialized => _isInitialized;

  /// Reset initialization state (for logout/login scenarios)
  void reset() {
    AppLogger().debug('🔄 AUDIO INIT: Resetting audio initialization state');
    _isInitialized = false;
    _isInitializing = false;
  }

  /// Dispose and cleanup
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      AppLogger().info('🧹 AUDIO INIT: Disposing audio initialization service');
      
      final persistentAudioService = GetIt.instance<PersistentAudioService>();
      await persistentAudioService.dispose();
      
      reset();
      
    } catch (error) {
      AppLogger().warning('⚠️ AUDIO INIT: Error during disposal: $error');
    }
  }
}