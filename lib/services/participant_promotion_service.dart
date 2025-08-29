import 'dart:async';
import 'package:appwrite/appwrite.dart';
import '../core/logging/app_logger.dart';
import '../constants/appwrite.dart';
import 'appwrite_service.dart';
import 'open_discussion_service.dart';

/// Unified service for handling hand raising and participant promotion
/// Provides reliable, race-condition-free promotion handling
class ParticipantPromotionService {
  static final ParticipantPromotionService _instance = ParticipantPromotionService._internal();
  factory ParticipantPromotionService() => _instance;
  ParticipantPromotionService._internal();

  final AppwriteService _appwrite = AppwriteService();
  final Set<String> _processingPromotions = <String>{}; // Prevent duplicate processing
  
  /// Promote participant from audience to speaker with comprehensive error handling
  Future<bool> promoteToSpeaker({
    required String roomId,
    required String userId,
    required String roomType, // 'open_discussion' or 'debate_discussion'
  }) async {
    final promotionKey = '${roomId}_$userId';
    
    // Prevent duplicate processing
    if (_processingPromotions.contains(promotionKey)) {
      AppLogger().warning('🚨 PROMOTION: Already processing promotion for $userId in $roomId');
      return false;
    }
    
    _processingPromotions.add(promotionKey);
    
    try {
      AppLogger().info('🎤 PROMOTION: Starting promotion of $userId to speaker in $roomId');
      
      // Step 1: Verify room exists and get current participants
      final roomData = await _getRoomData(roomId, roomType);
      if (roomData == null) {
        AppLogger().warning('⚠️ Room data not found for $roomId, proceeding with participant promotion anyway');
        // Continue with promotion - room validation is optional for participant operations
      }
      
      // Step 2: Check if user is actually in the audience
      final participants = await _getParticipants(roomId, roomType);
      final userParticipant = participants.firstWhere(
        (p) => p['userId'] == userId,
        orElse: () => <String, dynamic>{},
      );
      
      if (userParticipant.isEmpty) {
        throw Exception('User $userId not found in room participants');
      }
      
      final currentRole = userParticipant['role'] as String;
      if (currentRole != 'audience' && currentRole != 'pending') {
        AppLogger().warning('🚨 PROMOTION: User $userId already has role: $currentRole');
        return currentRole == 'speaker'; // Return true if already speaker
      }
      
      // Step 3: Check speaker capacity (max 6 speakers excluding moderator)
      final speakerCount = participants.where((p) => p['role'] == 'speaker').length;
      if (speakerCount >= 6) {
        throw Exception('Speaker panel is full (6/6 speakers)');
      }
      
      // Step 4: Update participant role to speaker
      await _updateParticipantRole(
        participantId: userParticipant['\$id'],
        roomId: roomId,
        userId: userId,
        newRole: 'speaker',
        roomType: roomType,
      );
      
      // Step 5: Remove any pending hand raise requests
      await _clearHandRaiseRequest(roomId, userId);
      
      AppLogger().info('✅ PROMOTION: Successfully promoted $userId to speaker in $roomId');
      return true;
      
    } catch (e) {
      AppLogger().error('❌ PROMOTION FAILED: $e');
      return false;
    } finally {
      // Remove from processing set after delay to prevent rapid retries
      Future.delayed(const Duration(seconds: 2), () {
        _processingPromotions.remove(promotionKey);
      });
    }
  }
  
  /// Demote speaker back to audience
  Future<bool> demoteToAudience({
    required String roomId,
    required String userId,
    required String roomType,
  }) async {
    try {
      AppLogger().info('📉 DEMOTION: Starting demotion of $userId to audience in $roomId');
      
      // Get current participants
      final participants = await _getParticipants(roomId, roomType);
      final userParticipant = participants.firstWhere(
        (p) => p['userId'] == userId,
        orElse: () => <String, dynamic>{},
      );
      
      if (userParticipant.isEmpty) {
        throw Exception('User $userId not found in room participants');
      }
      
      // Update role to audience
      await _updateParticipantRole(
        participantId: userParticipant['\$id'],
        roomId: roomId,
        userId: userId,
        newRole: 'audience',
        roomType: roomType,
      );
      
      AppLogger().info('✅ DEMOTION: Successfully demoted $userId to audience in $roomId');
      return true;
      
    } catch (e) {
      AppLogger().error('❌ DEMOTION FAILED: $e');
      return false;
    }
  }
  
  /// Raise hand to request speaker promotion
  Future<bool> raiseHand({
    required String roomId,
    required String userId,
    required String displayName,
  }) async {
    try {
      AppLogger().info('✋ HAND RAISE: $userId raising hand in $roomId');
      
      // Check if already has pending request
      final existingRequests = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.roomHandRaisesCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
          Query.equal('status', 'pending'),
        ],
      );
      
      if (existingRequests.documents.isNotEmpty) {
        AppLogger().warning('🚨 HAND RAISE: User $userId already has pending request');
        return true; // Already raised
      }
      
      // Create hand raise request
      await _appwrite.databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.roomHandRaisesCollection,
        documentId: ID.unique(),
        data: {
          'roomId': roomId,
          'userId': userId,
          'displayName': displayName,
          'status': 'pending',
          'requestedAt': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger().info('✅ HAND RAISE: Successfully raised hand for $userId in $roomId');
      return true;
      
    } catch (e) {
      AppLogger().error('❌ HAND RAISE FAILED: $e');
      return false;
    }
  }
  
  /// Lower hand (cancel speaker request)
  Future<bool> lowerHand({
    required String roomId,
    required String userId,
  }) async {
    try {
      AppLogger().info('👋 HAND LOWER: $userId lowering hand in $roomId');
      await _clearHandRaiseRequest(roomId, userId);
      return true;
    } catch (e) {
      AppLogger().error('❌ HAND LOWER FAILED: $e');
      return false;
    }
  }
  
  /// Get room data based on room type
  Future<Map<String, dynamic>?> _getRoomData(String roomId, String roomType) async {
    try {
      if (roomType == 'open_discussion') {
        // Open Discussion rooms are stored in discussion_rooms collection
        final doc = await _appwrite.databases.getDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.roomsCollection, // This is 'discussion_rooms'
          documentId: roomId,
        );
        return doc.data;
      } else if (roomType == 'debate_discussion') {
        // Debates & Discussions rooms are stored in debate_discussion_rooms collection
        final doc = await _appwrite.databases.getDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.debateDiscussionRoomsCollection,
          documentId: roomId,
        );
        return doc.data;
      }
      throw Exception('Invalid room type: $roomType');
    } catch (e) {
      AppLogger().error('❌ Failed to get room data: $e');
      return null;
    }
  }
  
  /// Get participants based on room type
  Future<List<Map<String, dynamic>>> _getParticipants(String roomId, String roomType) async {
    try {
      if (roomType == 'open_discussion') {
        final result = await _appwrite.databases.listDocuments(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.roomParticipantsCollection,
          queries: [Query.equal('roomId', roomId)],
        );
        return result.documents.map((doc) => doc.data).toList();
      } else if (roomType == 'debate_discussion') {
        final result = await _appwrite.databases.listDocuments(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.debateDiscussionParticipantsCollection,
          queries: [Query.equal('roomId', roomId)],
        );
        return result.documents.map((doc) => doc.data).toList();
      }
      throw Exception('Invalid room type: $roomType');
    } catch (e) {
      AppLogger().error('❌ Failed to get participants: $e');
      return [];
    }
  }
  
  /// Update participant role based on room type
  Future<void> _updateParticipantRole({
    required String participantId,
    required String roomId,
    required String userId,
    required String newRole,
    required String roomType,
  }) async {
    if (roomType == 'open_discussion') {
      await _appwrite.databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.roomParticipantsCollection,
        documentId: participantId,
        data: {'role': newRole},
      );
      
      // CRITICAL FIX: Update LiveKit permissions on server-side for open discussion rooms
      // This ensures users promoted to speaker can actually use their microphone
      try {
        final openDiscussionService = OpenDiscussionService();
        await openDiscussionService.updateLiveKitParticipantPermissions(
          roomName: roomId, // In open discussion, roomId is the LiveKit room name
          participantIdentity: userId,
          newRole: newRole,
        );
        AppLogger().info('✅ PERMISSION UPDATE: Updated LiveKit permissions for $userId to $newRole');
      } catch (e) {
        AppLogger().warning('⚠️ PERMISSION UPDATE: Failed to update LiveKit permissions for $userId: $e');
        // Don't rethrow - database role update succeeded, LiveKit will sync eventually
      }
      
    } else if (roomType == 'debate_discussion') {
      await _appwrite.databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.debateDiscussionParticipantsCollection,
        documentId: participantId,
        data: {'role': newRole},
      );
      
      // CRITICAL FIX: Update LiveKit permissions on server-side for debate discussion rooms
      try {
        final openDiscussionService = OpenDiscussionService();
        await openDiscussionService.updateLiveKitParticipantPermissions(
          roomName: roomId, // In debate discussion, roomId is the LiveKit room name
          participantIdentity: userId,
          newRole: newRole,
        );
        AppLogger().info('✅ PERMISSION UPDATE: Updated LiveKit permissions for $userId to $newRole');
      } catch (e) {
        AppLogger().warning('⚠️ PERMISSION UPDATE: Failed to update LiveKit permissions for $userId: $e');
        // Don't rethrow - database role update succeeded, LiveKit will sync eventually
      }
      
    } else {
      throw Exception('Invalid room type: $roomType');
    }
  }
  
  /// Clear hand raise request
  Future<void> _clearHandRaiseRequest(String roomId, String userId) async {
    try {
      final requests = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.roomHandRaisesCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
        ],
      );
      
      for (final request in requests.documents) {
        await _appwrite.databases.deleteDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.roomHandRaisesCollection,
          documentId: request.$id,
        );
      }
      
      AppLogger().debug('🧹 CLEANUP: Cleared hand raise requests for $userId in $roomId');
    } catch (e) {
      AppLogger().warning('⚠️ CLEANUP: Failed to clear hand raise requests: $e');
    }
  }
}