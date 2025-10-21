import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../core/logging/app_logger.dart';

/// Vote options for debates
enum VoteSide {
  affirmative,
  negative,
}

extension VoteSideExtension on VoteSide {
  String get value {
    switch (this) {
      case VoteSide.affirmative:
        return 'affirmative';
      case VoteSide.negative:
        return 'negative';
    }
  }

  static VoteSide fromString(String value) {
    switch (value) {
      case 'affirmative':
        return VoteSide.affirmative;
      case 'negative':
        return VoteSide.negative;
      default:
        return VoteSide.affirmative;
    }
  }
}

/// Voting session status
enum VotingStatus {
  open,
  closed,
  completed,
}

extension VotingStatusExtension on VotingStatus {
  String get value {
    switch (this) {
      case VotingStatus.open:
        return 'open';
      case VotingStatus.closed:
        return 'closed';
      case VotingStatus.completed:
        return 'completed';
    }
  }

  static VotingStatus fromString(String value) {
    switch (value) {
      case 'open':
        return VotingStatus.open;
      case 'closed':
        return VotingStatus.closed;
      case 'completed':
        return VotingStatus.completed;
      default:
        return VotingStatus.open;
    }
  }
}

/// Voting session model
class VotingSession {
  final String id;
  final String roomId;
  final VotingStatus status;
  final String openedBy;
  final DateTime openedAt;
  final DateTime? closedAt;

  VotingSession({
    required this.id,
    required this.roomId,
    required this.status,
    required this.openedBy,
    required this.openedAt,
    this.closedAt,
  });

  factory VotingSession.fromDocument(models.Document doc) {
    return VotingSession(
      id: doc.$id,
      roomId: doc.data['roomId'] ?? '',
      status: VotingStatusExtension.fromString(doc.data['status'] ?? 'open'),
      openedBy: doc.data['openedBy'] ?? '',
      openedAt: DateTime.parse(doc.data['openedAt'] ?? DateTime.now().toIso8601String()),
      closedAt: doc.data['closedAt'] != null ? DateTime.parse(doc.data['closedAt']) : null,
    );
  }
}

/// Vote results
class VoteResults {
  final int affirmativeVotes;
  final int negativeVotes;
  final int totalVotes;
  final VoteSide? winner;
  final double affirmativePercentage;
  final double negativePercentage;

  VoteResults({
    required this.affirmativeVotes,
    required this.negativeVotes,
    required this.totalVotes,
    this.winner,
    required this.affirmativePercentage,
    required this.negativePercentage,
  });
}

/// Service for managing debate audience voting
class DebateVotingService {
  final Databases _databases;
  final Realtime _realtime;
  final String _databaseId = 'arena_db';
  final String _sessionsCollectionId = 'debate_voting_sessions';
  final String _votesCollectionId = 'debate_votes';

  DebateVotingService({
    required Databases databases,
    required Realtime realtime,
  })  : _databases = databases,
        _realtime = realtime;

  /// Open a new voting session for a room
  Future<VotingSession?> openVoting({
    required String roomId,
    required String moderatorId,
  }) async {
    try {
      AppLogger().info('🗳️ Opening voting session for room: $roomId');

      // Check if there's already an active session
      final existingSessions = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _sessionsCollectionId,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('status', 'open'),
          Query.limit(1),
        ],
      );

      if (existingSessions.documents.isNotEmpty) {
        AppLogger().warning('⚠️ Voting session already open for room: $roomId');
        return VotingSession.fromDocument(existingSessions.documents.first);
      }

      // Create new session
      final session = await _databases.createDocument(
        databaseId: _databaseId,
        collectionId: _sessionsCollectionId,
        documentId: ID.unique(),
        data: {
          'roomId': roomId,
          'status': VotingStatus.open.value,
          'openedBy': moderatorId,
          'openedAt': DateTime.now().toIso8601String(),
        },
      );

      AppLogger().info('✅ Voting session opened: ${session.$id}');
      return VotingSession.fromDocument(session);
    } catch (e) {
      AppLogger().error('❌ Error opening voting session: $e');
      return null;
    }
  }

  /// Close the voting session (no more votes allowed)
  Future<bool> closeVoting({
    required String roomId,
  }) async {
    try {
      AppLogger().info('🔒 Closing voting for room: $roomId');

      // Find active session
      final sessions = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _sessionsCollectionId,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('status', 'open'),
          Query.limit(1),
        ],
      );

      if (sessions.documents.isEmpty) {
        AppLogger().warning('⚠️ No open voting session found for room: $roomId');
        return false;
      }

      // Update status to closed
      await _databases.updateDocument(
        databaseId: _databaseId,
        collectionId: _sessionsCollectionId,
        documentId: sessions.documents.first.$id,
        data: {
          'status': VotingStatus.closed.value,
          'closedAt': DateTime.now().toIso8601String(),
        },
      );

      AppLogger().info('✅ Voting session closed');
      return true;
    } catch (e) {
      AppLogger().error('❌ Error closing voting session: $e');
      return false;
    }
  }

  /// Mark voting as completed (results shown)
  Future<bool> completeVoting({
    required String roomId,
  }) async {
    try {
      // Find closed session
      final sessions = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _sessionsCollectionId,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('status', 'closed'),
          Query.limit(1),
        ],
      );

      if (sessions.documents.isEmpty) {
        AppLogger().warning('⚠️ No closed voting session found for room: $roomId');
        return false;
      }

      // Update status to completed
      await _databases.updateDocument(
        databaseId: _databaseId,
        collectionId: _sessionsCollectionId,
        documentId: sessions.documents.first.$id,
        data: {
          'status': VotingStatus.completed.value,
        },
      );

      AppLogger().info('✅ Voting session marked as completed');
      return true;
    } catch (e) {
      AppLogger().error('❌ Error completing voting session: $e');
      return false;
    }
  }

  /// Submit or update a vote
  Future<bool> submitVote({
    required String roomId,
    required String userId,
    required VoteSide vote,
  }) async {
    try {
      AppLogger().info('📝 Submitting vote: $userId → ${vote.value}');

      // Find active session
      final sessions = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _sessionsCollectionId,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('status', 'open'),
          Query.limit(1),
        ],
      );

      if (sessions.documents.isEmpty) {
        AppLogger().warning('⚠️ No open voting session found');
        return false;
      }

      final sessionId = sessions.documents.first.$id;

      // Check if user already voted
      final existingVotes = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _votesCollectionId,
        queries: [
          Query.equal('sessionId', sessionId),
          Query.equal('userId', userId),
          Query.limit(1),
        ],
      );

      if (existingVotes.documents.isNotEmpty) {
        // Update existing vote
        await _databases.updateDocument(
          databaseId: _databaseId,
          collectionId: _votesCollectionId,
          documentId: existingVotes.documents.first.$id,
          data: {
            'vote': vote.value,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );
        AppLogger().info('✅ Vote updated');
      } else {
        // Create new vote
        await _databases.createDocument(
          databaseId: _databaseId,
          collectionId: _votesCollectionId,
          documentId: ID.unique(),
          data: {
            'sessionId': sessionId,
            'roomId': roomId,
            'userId': userId,
            'vote': vote.value,
            'votedAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );
        AppLogger().info('✅ Vote submitted');
      }

      return true;
    } catch (e) {
      AppLogger().error('❌ Error submitting vote: $e');
      return false;
    }
  }

  /// Get current vote count for a room
  Future<int> getVoteCount({required String roomId}) async {
    try {
      // Find active or closed session
      final sessions = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _sessionsCollectionId,
        queries: [
          Query.equal('roomId', roomId),
          Query.limit(1),
          Query.orderDesc('\$createdAt'),
        ],
      );

      if (sessions.documents.isEmpty) {
        return 0;
      }

      final sessionId = sessions.documents.first.$id;

      // Count votes
      final votes = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _votesCollectionId,
        queries: [
          Query.equal('sessionId', sessionId),
        ],
      );

      return votes.documents.length;
    } catch (e) {
      AppLogger().error('❌ Error getting vote count: $e');
      return 0;
    }
  }

  /// Get voting results
  Future<VoteResults?> getResults({required String roomId}) async {
    try {
      AppLogger().info('📊 Getting voting results for room: $roomId');

      // Find latest session
      final sessions = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _sessionsCollectionId,
        queries: [
          Query.equal('roomId', roomId),
          Query.limit(1),
          Query.orderDesc('\$createdAt'),
        ],
      );

      if (sessions.documents.isEmpty) {
        AppLogger().warning('⚠️ No voting session found for room: $roomId');
        return null;
      }

      final sessionId = sessions.documents.first.$id;

      // Get all votes
      final votes = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _votesCollectionId,
        queries: [
          Query.equal('sessionId', sessionId),
        ],
      );

      // Count votes by side
      int affirmativeVotes = 0;
      int negativeVotes = 0;

      for (final vote in votes.documents) {
        final voteValue = vote.data['vote'] as String;
        if (voteValue == 'affirmative') {
          affirmativeVotes++;
        } else if (voteValue == 'negative') {
          negativeVotes++;
        }
      }

      final totalVotes = affirmativeVotes + negativeVotes;

      // Calculate percentages
      final affirmativePercentage = totalVotes > 0
          ? (affirmativeVotes / totalVotes) * 100
          : 0.0;
      final negativePercentage = totalVotes > 0
          ? (negativeVotes / totalVotes) * 100
          : 0.0;

      // Determine winner
      VoteSide? winner;
      if (affirmativeVotes > negativeVotes) {
        winner = VoteSide.affirmative;
      } else if (negativeVotes > affirmativeVotes) {
        winner = VoteSide.negative;
      }
      // If tied, winner is null

      final results = VoteResults(
        affirmativeVotes: affirmativeVotes,
        negativeVotes: negativeVotes,
        totalVotes: totalVotes,
        winner: winner,
        affirmativePercentage: affirmativePercentage,
        negativePercentage: negativePercentage,
      );

      AppLogger().info('📊 Results: Affirmative: $affirmativeVotes, Negative: $negativeVotes');
      return results;
    } catch (e) {
      AppLogger().error('❌ Error getting results: $e');
      return null;
    }
  }

  /// Get current voting session for a room
  Future<VotingSession?> getCurrentSession({required String roomId}) async {
    try {
      final sessions = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _sessionsCollectionId,
        queries: [
          Query.equal('roomId', roomId),
          Query.limit(1),
          Query.orderDesc('\$createdAt'),
        ],
      );

      if (sessions.documents.isEmpty) {
        return null;
      }

      return VotingSession.fromDocument(sessions.documents.first);
    } catch (e) {
      AppLogger().error('❌ Error getting current session: $e');
      return null;
    }
  }

  /// Get user's current vote
  Future<VoteSide?> getUserVote({
    required String roomId,
    required String userId,
  }) async {
    try {
      // Find latest session
      final sessions = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _sessionsCollectionId,
        queries: [
          Query.equal('roomId', roomId),
          Query.limit(1),
          Query.orderDesc('\$createdAt'),
        ],
      );

      if (sessions.documents.isEmpty) {
        return null;
      }

      final sessionId = sessions.documents.first.$id;

      // Find user's vote
      final votes = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _votesCollectionId,
        queries: [
          Query.equal('sessionId', sessionId),
          Query.equal('userId', userId),
          Query.limit(1),
        ],
      );

      if (votes.documents.isEmpty) {
        return null;
      }

      final voteValue = votes.documents.first.data['vote'] as String;
      return VoteSideExtension.fromString(voteValue);
    } catch (e) {
      AppLogger().error('❌ Error getting user vote: $e');
      return null;
    }
  }

  /// Subscribe to voting session changes
  Stream<VotingSession> subscribeToSession(String roomId) {
    AppLogger().info('🔔 Subscribing to voting session updates for room: $roomId');

    final subscription = _realtime.subscribe([
      'databases.$_databaseId.collections.$_sessionsCollectionId.documents',
    ]);

    return subscription.stream
        .where((response) {
          final payload = response.payload;
          return payload['roomId'] == roomId;
        })
        .map((response) {
          final doc = models.Document.fromMap(response.payload);
          return VotingSession.fromDocument(doc);
        });
  }

  /// Subscribe to vote count updates
  Stream<int> subscribeToVoteCount(String roomId) async* {
    AppLogger().info('🔔 Subscribing to vote count updates for room: $roomId');

    // Get current session
    final session = await getCurrentSession(roomId: roomId);
    if (session == null) {
      yield 0;
      return;
    }

    final subscription = _realtime.subscribe([
      'databases.$_databaseId.collections.$_votesCollectionId.documents',
    ]);

    await for (final response in subscription.stream) {
      final payload = response.payload;
      if (payload['sessionId'] == session.id) {
        // Recalculate vote count
        final count = await getVoteCount(roomId: roomId);
        yield count;
      }
    }
  }
}
