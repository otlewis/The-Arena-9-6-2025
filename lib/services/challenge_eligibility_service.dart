import 'package:appwrite/appwrite.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

/// Service to determine who can challenge whom based on current room status and roles
class ChallengeEligibilityService {
  final AppwriteService _appwrite = AppwriteService();

  /// Check if a user can be challenged
  /// Returns null if challengeable, or an error message if not
  Future<String?> canUserBeChallenged(String userId) async {
    try {
      AppLogger().debug('🎯 Checking if user $userId can be challenged');

      // Check if user is in an arena room as debater, judge, or moderator
      final arenaStatus = await _getUserArenaStatus(userId);
      if (arenaStatus != null) {
        return arenaStatus; // User is in arena and cannot be challenged
      }

      // Check if user is in a debates_discussions room
      final debateStatus = await _getUserDebateDiscussionStatus(userId);
      if (debateStatus != null) {
        return debateStatus; // User is in formal debate or moderating
      }

      // User is challengeable (either not in any room, or in casual room as audience)
      AppLogger().info('✅ User $userId can be challenged');
      return null;
    } catch (e) {
      AppLogger().error('Error checking challenge eligibility: $e');
      // On error, allow the challenge (fail open)
      return null;
    }
  }

  /// Check if current user can issue challenges
  /// Returns null if can challenge, or an error message if not
  Future<String?> canCurrentUserIssueChallenge() async {
    try {
      final currentUser = await _appwrite.getCurrentUser();
      if (currentUser == null) {
        return 'You must be logged in to issue challenges';
      }

      AppLogger().debug('🎯 Checking if current user ${currentUser.$id} can issue challenges');

      // Check if user is in an arena room as debater, judge, or moderator
      final arenaStatus = await _getUserArenaStatus(currentUser.$id);
      if (arenaStatus != null) {
        // Arena participants can only challenge if they're audience
        return 'You cannot issue challenges while participating in an arena debate. Only audience members can challenge.';
      }

      // Check if user is moderating any room (moderators cannot issue challenges)
      final moderatingStatus = await _checkIfUserIsModeratingRoom(currentUser.$id);
      if (moderatingStatus != null) {
        return moderatingStatus;
      }

      // Check if user is a speaker in a formal Debate room (only Debate room speakers blocked)
      final speakerStatus = await _checkIfUserIsSpeakerInDebateRoom(currentUser.$id);
      if (speakerStatus != null) {
        return speakerStatus;
      }

      // User can issue challenges
      AppLogger().info('✅ Current user can issue challenges');
      return null;
    } catch (e) {
      AppLogger().error('Error checking if current user can issue challenge: $e');
      // On error, allow the challenge (fail open)
      return null;
    }
  }

  /// Get arena room status for a user
  /// Returns error message if user is active in arena, null if not
  Future<String?> _getUserArenaStatus(String userId) async {
    try {
      // Check if user is in any active arena room
      final arenaParticipants = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.equal('userId', userId),
          Query.equal('status', 'joined'),
          Query.limit(1),
        ],
      );

      if (arenaParticipants.documents.isNotEmpty) {
        final participant = arenaParticipants.documents.first;
        final role = participant.data['role'] ?? 'audience';

        // Check if they're actively participating (not just audience)
        if (role == 'debater1' || role == 'debater2' || role == 'judge' || role == 'moderator') {
          AppLogger().info('❌ User is $role in arena room - cannot be challenged');
          return 'This user is currently participating in an arena debate as $role';
        }

        // If they're audience in arena, they can be challenged
        AppLogger().debug('User is audience in arena - can be challenged');
      }

      return null; // Not in arena or only audience
    } catch (e) {
      AppLogger().error('Error checking arena status: $e');
      return null;
    }
  }

  /// Get debates & discussions room status for a user
  /// Returns error message if user is active in formal debate, null if not
  Future<String?> _getUserDebateDiscussionStatus(String userId) async {
    try {
      // Check if user is moderating any room
      final moderatingRooms = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'debate_discussion_rooms',
        queries: [
          Query.equal('moderatorId', userId),
          Query.equal('status', 'active'),
          Query.limit(1),
        ],
      );

      if (moderatingRooms.documents.isNotEmpty) {
        final room = moderatingRooms.documents.first;
        final debateStyle = room.data['debateStyle'] as String? ?? 'Discussion';
        AppLogger().info('❌ User is moderating a $debateStyle room - cannot be challenged');

        // Moderators cannot be challenged in any room type
        if (debateStyle == 'Debate') {
          return 'This user is currently moderating a formal debate';
        } else if (debateStyle == 'Take') {
          return 'This user is currently moderating a Take room';
        } else {
          return 'This user is currently moderating a Discussion room';
        }
      }

      // Check if user is participant in any room
      final participants = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'debate_discussion_participants',
        queries: [
          Query.equal('userId', userId),
          Query.equal('status', 'joined'),
          Query.limit(10), // Check up to 10 rooms
        ],
      );

      for (var participant in participants.documents) {
        final roomId = participant.data['roomId'] as String?;
        final role = participant.data['role'] as String?;

        if (roomId == null) continue;

        // Get room details to check debate style
        final roomDocs = await _appwrite.databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'debate_discussion_rooms',
          queries: [
            Query.equal('\$id', roomId),
            Query.equal('status', 'active'),
            Query.limit(1),
          ],
        );

        if (roomDocs.documents.isNotEmpty) {
          final room = roomDocs.documents.first;
          final debateStyle = room.data['debateStyle'] as String? ?? 'Discussion';

          // ONLY formal "Debate" rooms - speakers/moderators cannot be challenged
          if (debateStyle == 'Debate' && (role == 'speaker' || role == 'affirmative' || role == 'negative' || role == 'moderator')) {
            AppLogger().info('❌ User is $role in formal Debate room - cannot be challenged');
            return 'This user is currently participating in a formal debate';
          }

          // "Take" and "Discussion" rooms - speakers CAN be challenged, only moderators cannot
          // Moderator check is already handled above in moderatingRooms check
          // So speakers/audience in Take/Discussion rooms can be challenged
        }
      }

      return null; // User is not in any room, or only audience in casual rooms
    } catch (e) {
      AppLogger().error('Error checking debate discussion status: $e');
      return null;
    }
  }

  /// Check if user is moderating any room (for canCurrentUserIssueChallenge)
  /// Moderators cannot issue challenges in any room type
  Future<String?> _checkIfUserIsModeratingRoom(String userId) async {
    try {
      final moderatingRooms = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'debate_discussion_rooms',
        queries: [
          Query.equal('moderatorId', userId),
          Query.equal('status', 'active'),
          Query.limit(1),
        ],
      );

      if (moderatingRooms.documents.isNotEmpty) {
        final room = moderatingRooms.documents.first;
        final debateStyle = room.data['debateStyle'] as String? ?? 'Discussion';
        AppLogger().info('❌ User is moderating a $debateStyle room - cannot issue challenges');

        if (debateStyle == 'Debate') {
          return 'You cannot issue challenges while moderating a formal debate.';
        } else if (debateStyle == 'Take') {
          return 'You cannot issue challenges while moderating a Take room.';
        } else {
          return 'You cannot issue challenges while moderating a Discussion room.';
        }
      }

      return null;
    } catch (e) {
      AppLogger().error('Error checking moderator status: $e');
      return null;
    }
  }

  /// Check if user is a speaker in a formal Debate room (for canCurrentUserIssueChallenge)
  /// Only speakers in formal Debate rooms are blocked from issuing challenges
  /// Speakers in Take/Discussion rooms CAN issue challenges
  Future<String?> _checkIfUserIsSpeakerInDebateRoom(String userId) async {
    try {
      final participants = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'debate_discussion_participants',
        queries: [
          Query.equal('userId', userId),
          Query.equal('status', 'joined'),
          Query.limit(10),
        ],
      );

      for (var participant in participants.documents) {
        final roomId = participant.data['roomId'] as String?;
        final role = participant.data['role'] as String?;

        if (roomId == null) continue;

        // Get room details to check debate style
        final roomDocs = await _appwrite.databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'debate_discussion_rooms',
          queries: [
            Query.equal('\$id', roomId),
            Query.equal('status', 'active'),
            Query.limit(1),
          ],
        );

        if (roomDocs.documents.isNotEmpty) {
          final room = roomDocs.documents.first;
          final debateStyle = room.data['debateStyle'] as String? ?? 'Discussion';

          // ONLY block speakers in formal "Debate" rooms
          if (debateStyle == 'Debate' && (role == 'speaker' || role == 'affirmative' || role == 'negative')) {
            AppLogger().info('❌ User is $role in formal Debate room - cannot issue challenges');
            return 'You cannot issue challenges while actively participating in a formal debate.';
          }

          // Speakers in Take/Discussion rooms CAN issue challenges - no blocking
        }
      }

      return null;
    } catch (e) {
      AppLogger().error('Error checking speaker status: $e');
      return null;
    }
  }
}
