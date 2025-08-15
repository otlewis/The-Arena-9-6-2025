import 'dart:async';
import 'package:flutter/foundation.dart';
import 'livekit_service.dart';
import '../main.dart' show getIt;

/// Service to manage speaking detection across all room types
/// Integrates with LiveKit service and provides unified speaking state management
class SpeakingDetectionService extends ChangeNotifier {
  static final SpeakingDetectionService _instance = SpeakingDetectionService._internal();
  factory SpeakingDetectionService() => _instance;
  SpeakingDetectionService._internal();

  final Map<String, bool> _speakingStates = {};
  final Map<String, double> _audioLevels = {};
  late LiveKitService _liveKitService;
  StreamSubscription? _liveKitSubscription;

  // Getters
  Map<String, bool> get allSpeakingStates => Map.from(_speakingStates);
  bool isUserSpeaking(String userId) => _speakingStates[userId] ?? false;
  double getUserAudioLevel(String userId) => _audioLevels[userId] ?? 0.0;
  List<String> get currentSpeakers => _speakingStates.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toList();

  /// Initialize the service and connect to LiveKit service
  void initialize() {
    _liveKitService = getIt<LiveKitService>();
    
    // Set up LiveKit speaking detection callbacks
    _liveKitService.onSpeakingChanged = _handleSpeakingChanged;
    _liveKitService.onAudioLevelChanged = _handleAudioLevelChanged;
    
    debugPrint('🗣️ Speaking detection service initialized');
  }

  /// Handle speaking state changes from LiveKit
  void _handleSpeakingChanged(String userId, bool isSpeaking) {
    final wasSpokening = _speakingStates[userId] ?? false;
    
    if (isSpeaking != wasSpokening) {
      _speakingStates[userId] = isSpeaking;
      
      debugPrint('🗣️ Speaking state changed: $userId = $isSpeaking');
      notifyListeners();
    }
  }

  /// Handle audio level changes from LiveKit
  void _handleAudioLevelChanged(String userId, double audioLevel) {
    _audioLevels[userId] = audioLevel;
    // Don't notify listeners for audio level changes to avoid too many rebuilds
  }

  /// Update speaking state for a specific user (for manual control or testing)
  void updateSpeakingState(String userId, bool isSpeaking) {
    _handleSpeakingChanged(userId, isSpeaking);
  }

  /// Clear speaking state for a user (when they leave)
  void clearUserState(String userId) {
    final wasRemoved = _speakingStates.remove(userId) != null;
    _audioLevels.remove(userId);
    
    if (wasRemoved) {
      debugPrint('🧹 Cleared speaking state for $userId');
      notifyListeners();
    }
  }

  /// Clear all speaking states (when leaving a room)
  void clearAllStates() {
    if (_speakingStates.isNotEmpty || _audioLevels.isNotEmpty) {
      _speakingStates.clear();
      _audioLevels.clear();
      debugPrint('🧹 Cleared all speaking states');
      notifyListeners();
    }
  }

  /// Get speaking users by role (for room-specific filtering)
  List<String> getSpeakingUsersByRole(List<String> allowedUsers) {
    return currentSpeakers.where((userId) => allowedUsers.contains(userId)).toList();
  }

  /// Simulate speaking for testing purposes
  void simulateSpeaking(String userId, bool isSpeaking) {
    debugPrint('🧪 Simulating speaking for $userId: $isSpeaking');
    _liveKitService.simulateSpeaking(userId, isSpeaking);
  }

  @override
  void dispose() {
    _liveKitSubscription?.cancel();
    clearAllStates();
    super.dispose();
  }
}

/// Extension to get speaking detection service easily
extension SpeakingDetectionExtension on Object {
  SpeakingDetectionService get speakingService => SpeakingDetectionService();
}