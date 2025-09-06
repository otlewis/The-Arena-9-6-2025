import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

/// Legacy Reputation Service - DEPRECATED
/// 
/// This service is kept for backward compatibility only.
/// The new reputation system is percentage-based and controlled by moderators only.
/// Use ModeratorReputationService instead for reputation adjustments.
/// 
/// All methods in this class are now no-ops and will be removed in future versions.
class ReputationService {
  static final ReputationService _instance = ReputationService._internal();
  factory ReputationService() => _instance;
  ReputationService._internal();

  final AppwriteService _appwriteService = AppwriteService();

  /// Award reputation points for winning a debate - DEPRECATED
  /// Use ModeratorReputationService for reputation adjustments
  @deprecated
  Future<bool> awardDebateWin(String userId, {String? opponentId, int? judgeScore}) async {
    AppLogger().warning('⚠️ ReputationService.awardDebateWin is deprecated - use ModeratorReputationService');
    return true; // No-op for backward compatibility
  }

  /// Deduct reputation points for losing a debate - DEPRECATED
  /// Use ModeratorReputationService for reputation adjustments
  @deprecated
  Future<bool> awardDebateLoss(String userId, {String? opponentId, int? judgeScore}) async {
    AppLogger().warning('⚠️ ReputationService.awardDebateLoss is deprecated - use ModeratorReputationService');
    return true; // No-op for backward compatibility
  }

  /// Award reputation for participating in a debate - DEPRECATED
  /// Use ModeratorReputationService for reputation adjustments
  @deprecated
  Future<bool> awardDebateParticipation(String userId) async {
    AppLogger().warning('⚠️ ReputationService.awardDebateParticipation is deprecated - use ModeratorReputationService');
    return true; // No-op for backward compatibility
  }

  /// Award reputation for creating a room/debate - DEPRECATED
  /// Use ModeratorReputationService for reputation adjustments
  @deprecated
  Future<bool> awardRoomCreation(String userId) async {
    AppLogger().warning('⚠️ ReputationService.awardRoomCreation is deprecated - use ModeratorReputationService');
    return true; // No-op for backward compatibility
  }

  /// Award reputation for receiving gifts - DEPRECATED
  /// Use ModeratorReputationService for reputation adjustments
  @deprecated
  Future<bool> awardGiftReceived(String userId, int giftValue) async {
    AppLogger().warning('⚠️ ReputationService.awardGiftReceived is deprecated - use ModeratorReputationService');
    return true; // No-op for backward compatibility
  }

  /// Award reputation for sending gifts - DEPRECATED
  /// Use ModeratorReputationService for reputation adjustments
  @deprecated
  Future<bool> awardGiftSent(String userId, int giftValue) async {
    AppLogger().warning('⚠️ ReputationService.awardGiftSent is deprecated - use ModeratorReputationService');
    return true; // No-op for backward compatibility
  }

  /// Award reputation for good judge performance - DEPRECATED
  /// Use ModeratorReputationService for reputation adjustments
  @deprecated
  Future<bool> awardJudgePerformance(String userId, double rating) async {
    AppLogger().warning('⚠️ ReputationService.awardJudgePerformance is deprecated - use ModeratorReputationService');
    return true; // No-op for backward compatibility
  }

  /// Award reputation for good moderator performance - DEPRECATED
  /// Use ModeratorReputationService for reputation adjustments
  @deprecated
  Future<bool> awardModeratorPerformance(String userId, double rating) async {
    AppLogger().warning('⚠️ ReputationService.awardModeratorPerformance is deprecated - use ModeratorReputationService');
    return true; // No-op for backward compatibility
  }

  /// Penalize reputation for bad behavior - DEPRECATED
  /// Use ModeratorReputationService for reputation adjustments
  @deprecated
  Future<bool> penalizeBadBehavior(String userId, String reason) async {
    AppLogger().warning('⚠️ ReputationService.penalizeBadBehavior is deprecated - use ModeratorReputationService');
    return true; // No-op for backward compatibility
  }

  /// Award daily login bonus - DEPRECATED
  /// Use ModeratorReputationService for reputation adjustments
  @deprecated
  Future<bool> awardDailyLogin(String userId) async {
    AppLogger().warning('⚠️ ReputationService.awardDailyLogin is deprecated - use ModeratorReputationService');
    return true; // No-op for backward compatibility
  }

  /// Get user's reputation rank - DEPRECATED
  /// Reputation is now percentage-based, use ModeratorReputationService
  @deprecated
  Future<int> getUserRank(String userId) async {
    AppLogger().warning('⚠️ ReputationService.getUserRank is deprecated');
    return 0; // No-op for backward compatibility
  }


  /// Get reputation leaderboard - DEPRECATED
  /// Reputation is now percentage-based, use ModeratorReputationService
  @deprecated
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 100}) async {
    AppLogger().warning('⚠️ ReputationService.getLeaderboard is deprecated');
    return []; // No-op for backward compatibility
  }
}