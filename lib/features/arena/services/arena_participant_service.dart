import 'package:appwrite/appwrite.dart';
import '../../../services/appwrite_service.dart';
import '../../../models/user_profile.dart';
import '../models/participant_role.dart';
import '../utils/arena_constants.dart';
import '../../../core/logging/app_logger.dart';

/// Service for managing arena participants
class ArenaParticipantService {
  final AppwriteService _appwriteService;
  
  // Cache for better performance
  final Map<String, UserProfile> _userProfileCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);
  
  ArenaParticipantService({required AppwriteService appwriteService})
      : _appwriteService = appwriteService;
  
  /// Load all participants for a room
  Future<Map<String, UserProfile>> loadParticipants(String roomId) async {
    try {
      final participantsData = await _appwriteService.databases.listDocuments(
        databaseId: ArenaConstants.databaseId,
        collectionId: ArenaConstants.roomParticipantsCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.notEqual('role', 'audience'),
        ],
      );
      
      final participants = <String, UserProfile>{};
      
      for (final participantDoc in participantsData.documents) {
        final participantData = participantDoc.data;
        final userId = participantData['userId'];
        final role = participantData['role'];
        
        final userProfile = await _loadUserProfile(userId);
        if (userProfile != null) {
          participants[role] = userProfile;
          AppLogger().debug('Loaded participant: ${userProfile.name} as $role');
        }
      }
      
      AppLogger().info('Loaded ${participants.length} participants for room: $roomId');
      return participants;
    } catch (e) {
      AppLogger().error('Failed to load participants: $e');
      throw Exception('${ArenaConstants.errorLoadingParticipants}: $e');
    }
  }
  
  /// Load audience members for a room
  Future<List<UserProfile>> loadAudience(String roomId) async {
    try {
      final audienceResponse = await _appwriteService.databases.listDocuments(
        databaseId: ArenaConstants.databaseId,
        collectionId: ArenaConstants.roomParticipantsCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('role', 'audience'),
        ],
      );
      
      final audience = <UserProfile>[];
      
      for (final audienceDoc in audienceResponse.documents) {
        final audienceData = audienceDoc.data;
        final userId = audienceData['userId'];
        
        final userProfile = await _loadUserProfile(userId);
        if (userProfile != null) {
          audience.add(userProfile);
          AppLogger().debug('Loaded audience member: ${userProfile.name}');
        }
      }
      
      AppLogger().info('Loaded ${audience.length} audience members for room: $roomId');
      return audience;
    } catch (e) {
      AppLogger().error('Failed to load audience: $e');
      return []; // Return empty list instead of throwing for audience
    }
  }
  
  /// Load user profile with caching
  Future<UserProfile?> _loadUserProfile(String userId) async {
    // Check cache first
    if (_userProfileCache.containsKey(userId)) {
      final cacheTime = _cacheTimestamps[userId];
      if (cacheTime != null && DateTime.now().difference(cacheTime) < _cacheTimeout) {
        AppLogger().debug('Using cached profile for: $userId');
        return _userProfileCache[userId];
      }
    }
    
    try {
      final userData = await _appwriteService.databases.getDocument(
        databaseId: ArenaConstants.databaseId,
        collectionId: ArenaConstants.userProfilesCollection,
        documentId: userId,
      );
      
      final userProfile = UserProfile(
        id: userData.$id,
        name: userData.data['name'] ?? 'Unknown User',
        email: userData.data['email'] ?? '',
        avatar: userData.data['avatar'],
        bio: userData.data['bio'],
        reputation: userData.data['reputation'] ?? 0,
        totalWins: userData.data['totalWins'] ?? 0,
        totalDebates: userData.data['totalDebates'] ?? 0,
        createdAt: DateTime.parse(userData.$createdAt),
        updatedAt: DateTime.parse(userData.$updatedAt),
      );
      
      // Cache the profile
      _userProfileCache[userId] = userProfile;
      _cacheTimestamps[userId] = DateTime.now();
      
      AppLogger().debug('Loaded and cached profile: ${userProfile.name}');
      return userProfile;
    } catch (e) {
      AppLogger().warning('Failed to load user profile for $userId: $e');
      return null;
    }
  }
  
  /// Assign role to user
  Future<void> assignRole(String roomId, UserProfile user, ParticipantRole role) async {
    try {
      // Check if user already has a role in this room
      final existingParticipant = await _findExistingParticipant(roomId, user.id);
      
      if (existingParticipant != null) {
        // Update existing role
        await _appwriteService.databases.updateDocument(
          databaseId: ArenaConstants.databaseId,
          collectionId: ArenaConstants.roomParticipantsCollection,
          documentId: existingParticipant['\$id'],
          data: {
            'role': role.id,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );
        AppLogger().info('Updated role for ${user.name}: ${role.displayName}');
      } else {
        // Create new participant record
        await _appwriteService.databases.createDocument(
          databaseId: ArenaConstants.databaseId,
          collectionId: ArenaConstants.roomParticipantsCollection,
          documentId: '${roomId}_${user.id}_${role.id}',
          data: {
            'roomId': roomId,
            'userId': user.id,
            'role': role.id,
            'assignedAt': DateTime.now().toIso8601String(),
          },
        );
        AppLogger().info('Assigned role to ${user.name}: ${role.displayName}');
      }
    } catch (e) {
      AppLogger().error('Failed to assign role: $e');
      throw Exception('${ArenaConstants.errorAssigningRole}: $e');
    }
  }
  
  /// Find existing participant record
  Future<Map<String, dynamic>?> _findExistingParticipant(String roomId, String userId) async {
    try {
      final existingData = await _appwriteService.databases.listDocuments(
        databaseId: ArenaConstants.databaseId,
        collectionId: ArenaConstants.roomParticipantsCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
        ],
      );
      
      final documents = existingData.documents;
      return documents.isNotEmpty ? documents.first.data : null;
    } catch (e) {
      AppLogger().warning('Error finding existing participant: $e');
      return null;
    }
  }
  
  /// Remove participant from room
  Future<void> removeParticipant(String roomId, String userId) async {
    try {
      final existingParticipant = await _findExistingParticipant(roomId, userId);
      
      if (existingParticipant != null) {
        await _appwriteService.databases.deleteDocument(
          databaseId: ArenaConstants.databaseId,
          collectionId: ArenaConstants.roomParticipantsCollection,
          documentId: existingParticipant['\$id'],
        );
        
        AppLogger().info('Removed participant from room: $userId');
      }
    } catch (e) {
      AppLogger().error('Failed to remove participant: $e');
      throw Exception('Failed to remove participant: $e');
    }
  }
  
  /// Move user from audience to participant role
  Future<void> promoteFromAudience(String roomId, UserProfile user, ParticipantRole newRole) async {
    try {
      // Remove from audience (if exists)
      await removeParticipant(roomId, user.id);
      
      // Add as new role
      await assignRole(roomId, user, newRole);
      
      AppLogger().info('Promoted ${user.name} from audience to ${newRole.displayName}');
    } catch (e) {
      AppLogger().error('Failed to promote from audience: $e');
      throw Exception('Failed to promote from audience: $e');
    }
  }
  
  /// Get available judge slots
  Future<List<ParticipantRole>> getAvailableJudgeSlots(String roomId) async {
    try {
      final participants = await loadParticipants(roomId);
      final availableSlots = <ParticipantRole>[];
      
      for (final judgeRole in ParticipantRole.judgeRoles) {
        if (!participants.containsKey(judgeRole.id)) {
          availableSlots.add(judgeRole);
        }
      }
      
      return availableSlots;
    } catch (e) {
      AppLogger().error('Failed to get available judge slots: $e');
      return [];
    }
  }
  
  /// Check if role is available
  Future<bool> isRoleAvailable(String roomId, ParticipantRole role) async {
    try {
      final participants = await loadParticipants(roomId);
      return !participants.containsKey(role.id);
    } catch (e) {
      AppLogger().error('Failed to check role availability: $e');
      return false;
    }
  }
  
  /// Get participant count by role type
  Future<Map<String, int>> getParticipantCounts(String roomId) async {
    try {
      final participants = await loadParticipants(roomId);
      final audience = await loadAudience(roomId);
      
      int debaterCount = 0;
      int judgeCount = 0;
      int moderatorCount = 0;
      
      for (final roleId in participants.keys) {
        final role = ParticipantRole.fromId(roleId);
        if (role != null) {
          if (role.isDebater) {
            debaterCount++;
          } else if (role.isJudge) {
            judgeCount++;
          } else if (role == ParticipantRole.moderator) {
            moderatorCount++;
          }
        }
      }
      
      return {
        'debaters': debaterCount,
        'judges': judgeCount,
        'moderators': moderatorCount,
        'audience': audience.length,
        'total': participants.length + audience.length,
      };
    } catch (e) {
      AppLogger().error('Failed to get participant counts: $e');
      return {'debaters': 0, 'judges': 0, 'moderators': 0, 'audience': 0, 'total': 0};
    }
  }
  
  /// Clear user profile cache
  void clearCache() {
    _userProfileCache.clear();
    _cacheTimestamps.clear();
    AppLogger().debug('Participant service cache cleared');
  }
  
  /// Get cache info
  Map<String, dynamic> getCacheInfo() {
    return {
      'cachedProfiles': _userProfileCache.length,
      'cacheHits': _cacheTimestamps.length,
      'cacheTimeout': _cacheTimeout.inMinutes,
    };
  }
  
  /// Dispose resources
  void dispose() {
    clearCache();
    AppLogger().debug('Participant service disposed');
  }
}