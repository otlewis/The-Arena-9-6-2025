import 'dart:async';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

/// Participant data model - immutable state representation
class ParticipantData {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String role;
  final bool isHandRaised;
  final bool isSpeaking;
  final bool isMuted;
  final lk.Participant? liveKitParticipant;
  final bool isLocal;

  const ParticipantData({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    required this.isHandRaised,
    required this.isSpeaking,
    required this.isMuted,
    this.liveKitParticipant,
    required this.isLocal,
  });

  ParticipantData copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    String? role,
    bool? isHandRaised,
    bool? isSpeaking,
    bool? isMuted,
    lk.Participant? liveKitParticipant,
    bool? isLocal,
  }) {
    return ParticipantData(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isMuted: isMuted ?? this.isMuted,
      liveKitParticipant: liveKitParticipant ?? this.liveKitParticipant,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParticipantData &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ParticipantData(id: $id, displayName: $displayName, role: $role)';
}

/// Centralized participant management service
/// Handles all participant state, role management, and data synchronization
class ParticipantService {
  final AppwriteService _appwriteService;
  final Map<String, ParticipantData> _participants = {};
  final StreamController<List<ParticipantData>> _participantsController = 
      StreamController<List<ParticipantData>>.broadcast();

  ParticipantService(this._appwriteService);

  /// Stream of all participants for reactive UI updates
  Stream<List<ParticipantData>> get participantsStream => _participantsController.stream;

  /// Get all participants
  List<ParticipantData> get all => _participants.values.toList();

  /// Get participants by role
  List<ParticipantData> get speakers => 
      all.where((p) => p.role == 'speaker' || p.role == 'moderator').toList();
  
  List<ParticipantData> get audience => 
      all.where((p) => p.role == 'audience').toList();
  
  List<ParticipantData> get pendingRequests => 
      all.where((p) => p.role == 'pending').toList();

  /// Get specific participant
  ParticipantData? getParticipant(String userId) => _participants[userId];
  
  /// Get moderator participant
  ParticipantData? getModeratorParticipant() {
    try {
      return _participants.values.firstWhere((p) => p.role == 'moderator');
    } catch (e) {
      return null; // No moderator found
    }
  }

  /// Check if participant exists
  bool hasParticipant(String userId) => _participants.containsKey(userId);

  /// Get participant count by role
  int get speakerCount => speakers.length;
  int get audienceCount => audience.length;
  int get pendingCount => pendingRequests.length;
  int get totalCount => _participants.length;

  /// Add or update participant
  Future<void> updateParticipant({
    required String userId,
    String? displayName,
    String? avatarUrl,
    String? role,
    bool? isHandRaised,
    bool? isSpeaking,
    bool? isMuted,
    lk.Participant? liveKitParticipant,
    bool? isLocal,
  }) async {
    try {
      final existing = _participants[userId];
      final updated = existing?.copyWith(
        displayName: displayName,
        avatarUrl: avatarUrl,
        role: role,
        isHandRaised: isHandRaised,
        isSpeaking: isSpeaking,
        isMuted: isMuted,
        liveKitParticipant: liveKitParticipant,
        isLocal: isLocal,
      ) ?? ParticipantData(
        id: userId,
        displayName: displayName ?? userId,
        avatarUrl: avatarUrl,
        role: role ?? 'audience',
        isHandRaised: isHandRaised ?? false,
        isSpeaking: isSpeaking ?? false,
        isMuted: isMuted ?? true,
        liveKitParticipant: liveKitParticipant,
        isLocal: isLocal ?? false,
      );

      _participants[userId] = updated;
      _notifyParticipantsChanged();
      
      AppLogger().debug('👤 Updated participant: $userId (${updated.displayName}, ${updated.role})');
    } catch (e) {
      AppLogger().error('❌ Failed to update participant $userId: $e');
    }
  }

  /// Remove participant
  Future<void> removeParticipant(String userId) async {
    try {
      final removed = _participants.remove(userId);
      if (removed != null) {
        _notifyParticipantsChanged();
        AppLogger().debug('👤 Removed participant: $userId (${removed.displayName})');
      }
    } catch (e) {
      AppLogger().error('❌ Failed to remove participant $userId: $e');
    }
  }

  /// Sync with LiveKit participants
  Future<void> syncWithLiveKit(List<lk.Participant> liveKitParticipants) async {
    try {
      for (final lkParticipant in liveKitParticipants) {
        final userId = lkParticipant.identity;
        final existing = _participants[userId];
        
        // Determine audio state
        final isSpeaking = _isParticipantSpeaking(lkParticipant);
        final isMuted = lkParticipant is lk.LocalParticipant 
            ? false // We'll get this from the UI state
            : !lkParticipant.audioTrackPublications.any((track) =>
                track.track != null && !track.track!.muted);

        await updateParticipant(
          userId: userId,
          displayName: existing?.displayName ?? userId,
          avatarUrl: existing?.avatarUrl,
          role: existing?.role ?? 'audience',
          isHandRaised: existing?.isHandRaised ?? false,
          isSpeaking: isSpeaking,
          isMuted: isMuted,
          liveKitParticipant: lkParticipant,
          isLocal: lkParticipant is lk.LocalParticipant,
        );
      }

      // Remove participants who are no longer in LiveKit
      final liveKitIds = liveKitParticipants.map((p) => p.identity).toSet();
      final toRemove = _participants.keys.where((id) => !liveKitIds.contains(id)).toList();
      
      for (final id in toRemove) {
        await removeParticipant(id);
      }
    } catch (e) {
      AppLogger().error('❌ Failed to sync with LiveKit participants: $e');
    }
  }

  /// Load participant profile from Appwrite
  Future<void> loadParticipantProfile(String userId) async {
    try {
      final profile = await _appwriteService.getUserProfile(userId);
      if (profile != null) {
        await updateParticipant(
          userId: userId,
          displayName: profile.displayName,
          avatarUrl: profile.avatar,
        );
        AppLogger().debug('📸 Profile loaded for $userId: ${profile.displayName}');
      }
    } catch (e) {
      AppLogger().warning('⚠️ Could not load profile for $userId: $e');
    }
  }

  /// Update participant role
  Future<void> updateRole(String userId, String newRole) async {
    await updateParticipant(userId: userId, role: newRole);
  }

  /// Update hand raise status
  Future<void> updateHandRaise(String userId, bool isRaised) async {
    await updateParticipant(userId: userId, isHandRaised: isRaised);
  }

  /// Update speaking status
  Future<void> updateSpeaking(String userId, bool isSpeaking) async {
    await updateParticipant(userId: userId, isSpeaking: isSpeaking);
  }

  /// Update mute status
  Future<void> updateMuted(String userId, bool isMuted) async {
    await updateParticipant(userId: userId, isMuted: isMuted);
  }

  /// Clear all participants
  Future<void> clear() async {
    _participants.clear();
    _notifyParticipantsChanged();
    AppLogger().debug('👥 Cleared all participants');
  }

  /// Get participants as LiveKit participant list (for compatibility)
  List<lk.Participant> getLiveKitParticipants() {
    return _participants.values
        .where((p) => p.liveKitParticipant != null)
        .map((p) => p.liveKitParticipant!)
        .toList();
  }

  /// Check if participant is speaking based on audio tracks
  bool _isParticipantSpeaking(lk.Participant participant) {
    final audioTracks = participant.audioTrackPublications;
    return audioTracks.any((track) => 
        track.track != null && !track.track!.muted);
  }

  /// Notify listeners of participant changes
  void _notifyParticipantsChanged() {
    if (!_participantsController.isClosed) {
      _participantsController.add(all);
    }
  }

  /// Dispose resources
  void dispose() {
    _participantsController.close();
    _participants.clear();
    AppLogger().debug('🗑️ ParticipantService disposed');
  }
}