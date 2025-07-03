import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/appwrite_service.dart';
import '../../../services/challenge_messaging_service.dart';
import '../../../models/user_profile.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/providers/app_providers.dart';

/// User profile state
class UserProfileState {
  final UserProfile? userProfile;
  final bool isLoading;
  final bool isFollowing;
  final bool isLoadingAction;
  final int followerCount;
  final int followingCount;
  final String? error;

  const UserProfileState({
    this.userProfile,
    this.isLoading = false,
    this.isFollowing = false,
    this.isLoadingAction = false,
    this.followerCount = 0,
    this.followingCount = 0,
    this.error,
  });

  UserProfileState copyWith({
    UserProfile? userProfile,
    bool? isLoading,
    bool? isFollowing,
    bool? isLoadingAction,
    int? followerCount,
    int? followingCount,
    String? error,
  }) {
    return UserProfileState(
      userProfile: userProfile ?? this.userProfile,
      isLoading: isLoading ?? this.isLoading,
      isFollowing: isFollowing ?? this.isFollowing,
      isLoadingAction: isLoadingAction ?? this.isLoadingAction,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      error: error ?? this.error,
    );
  }
}

/// User profile state notifier
class UserProfileNotifier extends StateNotifier<UserProfileState> {
  UserProfileNotifier(this._appwrite, this._logger, this._messagingService, this._userId)
      : super(const UserProfileState()) {
    _loadUserProfile();
  }

  final AppwriteService _appwrite;
  final AppLogger _logger;
  final ChallengeMessagingService _messagingService;
  final String _userId;
  String? _currentUserId;

  Future<void> _loadUserProfile() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final userProfile = await _appwrite.getUserProfile(_userId);
      
      state = state.copyWith(
        userProfile: userProfile,
        isLoading: false,
      );
      
      // Load current user and follow status
      await _loadCurrentUser();
    } catch (e) {
      _logger.error('Error loading user profile: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _appwrite.getCurrentUser();
      if (user != null) {
        _currentUserId = user.$id;
        // Load follow status if we have a current user
        await _loadFollowStatus();
      }
    } catch (e) {
      // User not logged in - that's okay
      _logger.debug('No current user found: $e');
    }
  }

  Future<void> _loadFollowStatus() async {
    if (_currentUserId == null) return;

    try {
      final isFollowing = await _appwrite.isFollowing(
        followerId: _currentUserId!,
        followingId: _userId,
      );

      final followerCount = await _appwrite.getFollowerCount(_userId);
      final followingCount = await _appwrite.getFollowingCount(_userId);

      state = state.copyWith(
        isFollowing: isFollowing,
        followerCount: followerCount,
        followingCount: followingCount,
      );
    } catch (e) {
      _logger.debug('Error loading follow status: $e');
    }
  }

  Future<bool> toggleFollow() async {
    if (_currentUserId == null) {
      state = state.copyWith(error: 'Please sign in to follow users');
      return false;
    }

    if (state.isLoadingAction) return false;

    state = state.copyWith(isLoadingAction: true, error: null);

    try {
      if (state.isFollowing) {
        await _appwrite.unfollowUser(
          followerId: _currentUserId!,
          followingId: _userId,
        );
      } else {
        await _appwrite.followUser(
          followerId: _currentUserId!,
          followingId: _userId,
        );
      }

      // Refresh follow status
      await _loadFollowStatus();
      
      state = state.copyWith(isLoadingAction: false);
      return true;
    } catch (e) {
      _logger.error('Error toggling follow: $e');
      state = state.copyWith(
        isLoadingAction: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> sendChallenge(String topic, String? description, String position) async {
    if (_currentUserId == null) {
      state = state.copyWith(error: 'Please sign in to send challenges');
      return false;
    }

    if (topic.trim().isEmpty) {
      state = state.copyWith(error: 'Please enter a debate topic');
      return false;
    }

    try {
      // Enhanced debugging for challenge sending issues
      _logger.debug('🔍 CHALLENGE DEBUG: Starting challenge send process...');
      _logger.debug('🔍 CHALLENGE DEBUG: Current user ID: $_currentUserId');
      _logger.debug('🔍 CHALLENGE DEBUG: Target user ID: $_userId');
      _logger.debug('🔍 CHALLENGE DEBUG: Topic: $topic');
      _logger.debug('🔍 CHALLENGE DEBUG: Position: $position');

      // Verify user is still authenticated
      final currentUser = await _appwrite.getCurrentUser();
      if (currentUser == null) {
        _logger.error('CHALLENGE DEBUG: User not authenticated');
        state = state.copyWith(error: 'Please sign in again to send challenges');
        return false;
      }

      if (currentUser.$id != _currentUserId) {
        _logger.warning('CHALLENGE DEBUG: User ID mismatch - refreshing...');
        _currentUserId = currentUser.$id;
      }

      _logger.info('CHALLENGE DEBUG: Authentication verified, sending challenge...');

      await _messagingService.sendChallenge(
        challengedUserId: _userId,
        topic: topic.trim(),
        description: description?.trim().isEmpty == false ? description!.trim() : null,
        position: position,
      );

      _logger.info('CHALLENGE DEBUG: Challenge sent successfully!');
      return true;
    } catch (e) {
      _logger.error('CHALLENGE DEBUG: Error sending challenge: $e');
      state = state.copyWith(error: 'Error sending challenge: $e');
      return false;
    }
  }

  Future<void> refresh() async {
    await _loadUserProfile();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  bool get isOwnProfile => _currentUserId == _userId;
  bool get canInteract => _currentUserId != null && !isOwnProfile;
}

/// User profile provider factory
final userProfileProvider = StateNotifierProvider.autoDispose
    .family<UserProfileNotifier, UserProfileState, String>((ref, userId) {
  final appwrite = ref.read(appwriteServiceProvider);
  final logger = ref.read(loggerProvider);
  final messagingService = ref.read(challengeMessagingServiceProvider);
  return UserProfileNotifier(appwrite, logger, messagingService, userId);
});

/// Convenience providers for easier access
final userProfileDataProvider = Provider.autoDispose.family<UserProfile?, String>((ref, userId) {
  return ref.watch(userProfileProvider(userId)).userProfile;
});

final isUserProfileLoadingProvider = Provider.autoDispose.family<bool, String>((ref, userId) {
  return ref.watch(userProfileProvider(userId)).isLoading;
});

final userProfileErrorProvider = Provider.autoDispose.family<String?, String>((ref, userId) {
  return ref.watch(userProfileProvider(userId)).error;
});

final isFollowingUserProvider = Provider.autoDispose.family<bool, String>((ref, userId) {
  return ref.watch(userProfileProvider(userId)).isFollowing;
});

final userFollowStatsProvider = Provider.autoDispose.family<Map<String, int>, String>((ref, userId) {
  final state = ref.watch(userProfileProvider(userId));
  return {
    'followers': state.followerCount,
    'following': state.followingCount,
  };
});