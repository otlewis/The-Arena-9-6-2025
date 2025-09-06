import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

/// Service for moderator-controlled reputation percentage system
/// Only moderators can modify user reputation percentages
class ModeratorReputationService {
  static final ModeratorReputationService _instance = ModeratorReputationService._internal();
  factory ModeratorReputationService() => _instance;
  ModeratorReputationService._internal();

  final AppwriteService _appwriteService = AppwriteService();

  /// Common reputation percentage penalties
  static const int MINOR_VIOLATION_PENALTY = 5; // -5%
  static const int MODERATE_VIOLATION_PENALTY = 10; // -10%
  static const int SERIOUS_VIOLATION_PENALTY = 20; // -20%
  static const int SEVERE_VIOLATION_PENALTY = 35; // -35%
  static const int MAJOR_VIOLATION_PENALTY = 50; // -50%

  /// Common reputation percentage bonuses (rare, for exceptional behavior)
  static const int EXCEPTIONAL_BEHAVIOR_BONUS = 5; // +5%
  static const int COMMUNITY_CONTRIBUTION_BONUS = 10; // +10%

  /// Adjust user reputation percentage (moderators only)
  Future<bool> adjustUserReputation({
    required String userId,
    required String moderatorId,
    required int percentageChange, // Can be positive or negative
    required String reason,
  }) async {
    try {
      AppLogger().info('🛡️ Moderator reputation adjustment: $userId by $moderatorId (${percentageChange > 0 ? '+' : ''}$percentageChange%)');
      
      // Verify moderator permissions
      final canModerate = await _verifyModeratorPermissions(moderatorId);
      if (!canModerate) {
        AppLogger().error('❌ User $moderatorId is not authorized to modify reputation');
        return false;
      }
      
      // Get current user profile
      final profile = await _appwriteService.getUserProfile(userId);
      if (profile == null) {
        AppLogger().error('❌ User profile not found: $userId');
        return false;
      }
      
      // Calculate new reputation percentage (clamp between 0 and 100)
      final newReputation = (profile.reputationPercentage + percentageChange).clamp(0, 100);
      
      // Update user's reputation percentage
      await _appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
          'reputationPercentage': newReputation,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      
      // Log the reputation change for audit trail
      await _logReputationChange(
        userId: userId,
        moderatorId: moderatorId,
        oldPercentage: profile.reputationPercentage,
        newPercentage: newReputation,
        change: percentageChange,
        reason: reason,
      );
      
      AppLogger().info('✅ Reputation updated: $userId from ${profile.reputationPercentage}% to $newReputation% - $reason');
      return true;
      
    } catch (e) {
      AppLogger().error('❌ Failed to adjust user reputation: $e');
      return false;
    }
  }

  /// Apply predefined penalty for common violations
  Future<bool> applyViolationPenalty({
    required String userId,
    required String moderatorId,
    required ViolationType violationType,
    String? customReason,
  }) async {
    int penalty;
    String reason;
    
    switch (violationType) {
      case ViolationType.minorViolation:
        penalty = -MINOR_VIOLATION_PENALTY;
        reason = customReason ?? 'Minor community guideline violation';
        break;
      case ViolationType.moderateViolation:
        penalty = -MODERATE_VIOLATION_PENALTY;
        reason = customReason ?? 'Moderate community guideline violation';
        break;
      case ViolationType.seriousViolation:
        penalty = -SERIOUS_VIOLATION_PENALTY;
        reason = customReason ?? 'Serious community guideline violation';
        break;
      case ViolationType.severeViolation:
        penalty = -SEVERE_VIOLATION_PENALTY;
        reason = customReason ?? 'Severe community guideline violation';
        break;
      case ViolationType.majorViolation:
        penalty = -MAJOR_VIOLATION_PENALTY;
        reason = customReason ?? 'Major community guideline violation';
        break;
      case ViolationType.spamming:
        penalty = -MINOR_VIOLATION_PENALTY;
        reason = customReason ?? 'Spamming in discussions';
        break;
      case ViolationType.harassment:
        penalty = -SERIOUS_VIOLATION_PENALTY;
        reason = customReason ?? 'Harassment of other users';
        break;
      case ViolationType.hateSpeech:
        penalty = -SEVERE_VIOLATION_PENALTY;
        reason = customReason ?? 'Hate speech or discriminatory language';
        break;
      case ViolationType.disruptiveBehavior:
        penalty = -MODERATE_VIOLATION_PENALTY;
        reason = customReason ?? 'Disruptive behavior in debates';
        break;
    }
    
    return await adjustUserReputation(
      userId: userId,
      moderatorId: moderatorId,
      percentageChange: penalty,
      reason: reason,
    );
  }

  /// Apply positive reputation bonus for exceptional behavior
  Future<bool> applyReputationBonus({
    required String userId,
    required String moderatorId,
    required BonusType bonusType,
    String? customReason,
  }) async {
    int bonus;
    String reason;
    
    switch (bonusType) {
      case BonusType.exceptionalBehavior:
        bonus = EXCEPTIONAL_BEHAVIOR_BONUS;
        reason = customReason ?? 'Exceptional positive behavior in community';
        break;
      case BonusType.communityContribution:
        bonus = COMMUNITY_CONTRIBUTION_BONUS;
        reason = customReason ?? 'Outstanding contribution to community';
        break;
      case BonusType.helpfulModerator:
        bonus = EXCEPTIONAL_BEHAVIOR_BONUS;
        reason = customReason ?? 'Excellent moderation and community support';
        break;
      case BonusType.qualityDebater:
        bonus = EXCEPTIONAL_BEHAVIOR_BONUS;
        reason = customReason ?? 'Consistently high-quality debate participation';
        break;
    }
    
    return await adjustUserReputation(
      userId: userId,
      moderatorId: moderatorId,
      percentageChange: bonus,
      reason: reason,
    );
  }

  /// Reset user reputation to 100% (for appeals or mistakes)
  Future<bool> resetUserReputation({
    required String userId,
    required String moderatorId,
    required String reason,
  }) async {
    final profile = await _appwriteService.getUserProfile(userId);
    if (profile == null) return false;
    
    final change = 100 - profile.reputationPercentage;
    
    return await adjustUserReputation(
      userId: userId,
      moderatorId: moderatorId,
      percentageChange: change,
      reason: 'Reputation reset: $reason',
    );
  }

  /// Get user's reputation history (moderators only)
  Future<List<Map<String, dynamic>>> getUserReputationHistory(String userId, String requesterId) async {
    try {
      // Verify requester is a moderator
      final canModerate = await _verifyModeratorPermissions(requesterId);
      if (!canModerate) {
        AppLogger().error('❌ User $requesterId is not authorized to view reputation history');
        return [];
      }
      
      final response = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'reputation_logs',
        queries: [
          // Query for specific user's reputation changes
          // Order by timestamp descending (most recent first)
        ],
      );
      
      return response.documents.map((doc) => doc.data).toList();
      
    } catch (e) {
      AppLogger().error('Failed to get reputation history: $e');
      return [];
    }
  }

  /// Verify if user has moderator permissions
  Future<bool> _verifyModeratorPermissions(String userId) async {
    try {
      // Check if user is in moderators collection
      final response = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'moderators',
        queries: [
          // Query for specific moderator
        ],
      );
      
      return response.documents.isNotEmpty;
      
    } catch (e) {
      AppLogger().error('Failed to verify moderator permissions: $e');
      return false;
    }
  }

  /// Log reputation changes for audit trail
  Future<void> _logReputationChange({
    required String userId,
    required String moderatorId,
    required int oldPercentage,
    required int newPercentage,
    required int change,
    required String reason,
  }) async {
    try {
      await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'reputation_logs',
        documentId: 'unique()',
        data: {
          'userId': userId,
          'moderatorId': moderatorId,
          'oldPercentage': oldPercentage,
          'newPercentage': newPercentage,
          'percentageChange': change,
          'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'moderator_adjustment',
        },
      );
    } catch (e) {
      AppLogger().warning('Failed to log reputation change: $e');
    }
  }
}

/// Types of violations that can result in reputation penalties
enum ViolationType {
  minorViolation,
  moderateViolation,
  seriousViolation,
  severeViolation,
  majorViolation,
  spamming,
  harassment,
  hateSpeech,
  disruptiveBehavior,
}

/// Types of bonuses for exceptional behavior
enum BonusType {
  exceptionalBehavior,
  communityContribution,
  helpfulModerator,
  qualityDebater,
}