import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../core/logging/app_logger.dart';
import '../models/user_profile.dart';

/// Firebase Realtime Database service for instant participant synchronization
/// This service provides real-time participant sync that's more reliable than Appwrite
class FirebaseParticipantSyncService {
  static FirebaseParticipantSyncService? _instance;
  static FirebaseParticipantSyncService get instance {
    _instance ??= FirebaseParticipantSyncService._internal();
    return _instance!;
  }
  
  factory FirebaseParticipantSyncService() => instance;
  FirebaseParticipantSyncService._internal();

  late final FirebaseDatabase _database;
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  
  /// Initialize Firebase Realtime Database
  Future<void> initialize() async {
    try {
      _database = FirebaseDatabase.instance;
      
      // Enable offline persistence for better reliability
      _database.setPersistenceEnabled(true);
      
      AppLogger().info('🔥 Firebase Participant Sync Service initialized');
    } catch (e) {
      AppLogger().error('Failed to initialize Firebase Participant Sync: $e');
      rethrow;
    }
  }

  /// Update participant in Firebase for real-time sync
  Future<void> updateParticipant({
    required String roomId,
    required String userId,
    required String role,
    String? name,
    String? avatar,
    int? position,
  }) async {
    try {
      final participantData = {
        'userId': userId,
        'role': role,
        'name': name,
        'avatar': avatar,
        'position': position,
        'timestamp': ServerValue.timestamp,
        'lastUpdate': DateTime.now().millisecondsSinceEpoch,
      };

      await _database
          .ref('rooms/$roomId/participants/$userId')
          .set(participantData);
      
      AppLogger().debug('🔥 Firebase: Updated participant $userId role to $role in room $roomId');
    } catch (e) {
      AppLogger().error('Failed to update participant in Firebase: $e');
      // Don't rethrow - Firebase sync is supplementary to Appwrite
    }
  }

  /// Remove participant from Firebase
  Future<void> removeParticipant({
    required String roomId,
    required String userId,
  }) async {
    try {
      await _database
          .ref('rooms/$roomId/participants/$userId')
          .remove();
      
      AppLogger().debug('🔥 Firebase: Removed participant $userId from room $roomId');
    } catch (e) {
      AppLogger().error('Failed to remove participant from Firebase: $e');
    }
  }

  /// Listen to real-time participant changes for a room
  StreamSubscription<DatabaseEvent> listenToParticipants({
    required String roomId,
    required Function(Map<String, ParticipantSync>) onParticipantsChanged,
    required Function(String error) onError,
  }) {
    final subscription = _database
        .ref('rooms/$roomId/participants')
        .onValue
        .listen(
      (event) {
        try {
          if (event.snapshot.exists) {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data != null) {
              final participants = <String, ParticipantSync>{};
              
              data.forEach((key, value) {
                if (value is Map<dynamic, dynamic>) {
                  participants[key.toString()] = ParticipantSync.fromMap(
                    Map<String, dynamic>.from(value)
                  );
                }
              });
              
              AppLogger().debug('🔥 Firebase: Received ${participants.length} participants for room $roomId');
              onParticipantsChanged(participants);
            } else {
              onParticipantsChanged({});
            }
          } else {
            onParticipantsChanged({});
          }
        } catch (e) {
          AppLogger().error('Error processing Firebase participant data: $e');
          onError(e.toString());
        }
      },
      onError: (error) {
        AppLogger().error('Firebase participant subscription error: $error');
        onError(error.toString());
      },
    );

    // Store subscription for cleanup
    _activeSubscriptions[roomId] = subscription;
    AppLogger().info('🔥 Firebase: Started listening to participants for room $roomId');
    
    return subscription;
  }

  /// Stop listening to participants for a room
  void stopListening(String roomId) {
    final subscription = _activeSubscriptions.remove(roomId);
    subscription?.cancel();
    AppLogger().info('🔥 Firebase: Stopped listening to participants for room $roomId');
  }

  /// Clean up all subscriptions
  void dispose() {
    for (final subscription in _activeSubscriptions.values) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();
    AppLogger().info('🔥 Firebase: Disposed all participant subscriptions');
  }

  /// Sync multiple participants at once (for initial load)
  Future<void> syncParticipants({
    required String roomId,
    required List<UserProfile> participants,
    required Map<String, String> participantRoles,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      for (int i = 0; i < participants.length; i++) {
        final participant = participants[i];
        final role = participantRoles[participant.id] ?? 'audience';
        
        updates['rooms/$roomId/participants/${participant.id}'] = {
          'userId': participant.id,
          'role': role,
          'name': participant.name,
          'avatar': participant.avatar,
          'position': i,
          'timestamp': ServerValue.timestamp,
          'lastUpdate': DateTime.now().millisecondsSinceEpoch,
        };
      }
      
      await _database.ref().update(updates);
      AppLogger().info('🔥 Firebase: Synced ${participants.length} participants for room $roomId');
    } catch (e) {
      AppLogger().error('Failed to sync participants to Firebase: $e');
    }
  }

  /// Clear all participants for a room (when room ends)
  Future<void> clearRoom(String roomId) async {
    try {
      await _database.ref('rooms/$roomId').remove();
      AppLogger().info('🔥 Firebase: Cleared room $roomId');
    } catch (e) {
      AppLogger().error('Failed to clear Firebase room: $e');
    }
  }
}

/// Lightweight participant data structure for Firebase sync
class ParticipantSync {
  final String userId;
  final String role;
  final String? name;
  final String? avatar;
  final int? position;
  final int? timestamp;
  final int lastUpdate;

  ParticipantSync({
    required this.userId,
    required this.role,
    this.name,
    this.avatar,
    this.position,
    this.timestamp,
    required this.lastUpdate,
  });

  factory ParticipantSync.fromMap(Map<String, dynamic> map) {
    return ParticipantSync(
      userId: map['userId'] ?? '',
      role: map['role'] ?? 'audience',
      name: map['name'],
      avatar: map['avatar'],
      position: map['position'],
      timestamp: map['timestamp'],
      lastUpdate: map['lastUpdate'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'role': role,
      'name': name,
      'avatar': avatar,
      'position': position,
      'timestamp': timestamp,
      'lastUpdate': lastUpdate,
    };
  }
}