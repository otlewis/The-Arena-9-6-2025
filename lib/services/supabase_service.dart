import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../core/logging/app_logger.dart';
import '../models/user_profile.dart';
import 'dart:async';

/// SupabaseService - Replaces SupabaseService for backend operations
///
/// This service handles all Supabase operations including:
/// - Authentication (sign up, sign in, sign out)
/// - User profiles and stats
/// - Room creation and management (Arena, Debates & Discussions, Open Discussions)
/// - Real-time subscriptions
/// - Challenges and messaging
/// - Moderation and safety
///
/// Migration Strategy: Start fresh with empty tables
/// - All 82 tables created in Supabase
/// - Uses UUID primary keys
/// - RLS enabled with permissive policies (to be secured later)
/// - Real-time subscriptions for live updates
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  late final SupabaseClient client;

  // RealtimeClient subscription tracking
  final Map<String, RealtimeChannel> _subscriptions = {};

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal() {
    client = Supabase.instance.client;
    AppLogger().debug('🚀 SupabaseService initialized');
  }

  /// Get the current authenticated user
  User? get currentUser => client.auth.currentUser;

  // ============================================================================
  // AUTHENTICATION
  // ============================================================================

  /// Create a new user account
  Future<User> createAccount({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      AppLogger().debug('📝 Creating account for: $email');

      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      if (response.user == null) {
        throw Exception('Failed to create account');
      }

      final user = response.user!;
      AppLogger().debug('✅ Account created: ${user.id}');

      // Create user profile in users table
      await createUserProfile(
        userId: user.id,
        name: name,
        email: email,
      );

      return user;
    } catch (e) {
      AppLogger().debug('❌ Account creation failed: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger().debug('🔐 Signing in: $email');

      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      AppLogger().debug('✅ Sign in successful: ${response.user?.id}');

      // Update last seen
      if (response.user != null) {
        await updateLastSeen(response.user!.id);
      }

      return response;
    } catch (e) {
      AppLogger().debug('❌ Sign in failed: $e');
      rethrow;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      AppLogger().debug('🚪 Signing out');

      // Clean up all subscriptions
      await _cleanupAllSubscriptions();

      await client.auth.signOut();
      AppLogger().debug('✅ Sign out successful');
    } catch (e) {
      AppLogger().debug('❌ Sign out failed: $e');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      AppLogger().debug('📧 Sending password reset email to: $email');

      await client.auth.resetPasswordForEmail(email);

      AppLogger().debug('✅ Password reset email sent');
    } catch (e) {
      AppLogger().debug('❌ Password reset failed: $e');
      rethrow;
    }
  }

  /// Resend confirmation email
  Future<void> resendConfirmationEmail(String email) async {
    try {
      AppLogger().debug('📧 Resending confirmation email to: $email');

      await client.auth.resend(
        type: OtpType.signup,
        email: email,
      );

      AppLogger().debug('✅ Confirmation email resent');
    } catch (e) {
      AppLogger().debug('❌ Resend confirmation failed: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      AppLogger().debug('🔐 Signing in with Google');

      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.arena://login-callback/',
      );

      AppLogger().debug('✅ Google sign in initiated');
      return true;
    } catch (e) {
      AppLogger().debug('❌ Google sign in failed: $e');
      return false;
    }
  }

  /// Sign in with Apple
  Future<bool> signInWithApple() async {
    try {
      AppLogger().debug('🔐 Signing in with Apple');

      await client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? null : 'io.supabase.arena://login-callback/',
      );

      AppLogger().debug('✅ Apple sign in initiated');
      return true;
    } catch (e) {
      AppLogger().debug('❌ Apple sign in failed: $e');
      return false;
    }
  }

  /// Get current user
  Future<User?> getCurrentUser() async {
    try {
      final user = client.auth.currentUser;

      if (user != null) {
        AppLogger().debug('✅ Current user: ${user.id}');
      } else {
        AppLogger().debug('ℹ️ No current user');
      }

      return user;
    } catch (e) {
      AppLogger().debug('❌ Get current user failed: $e');
      return null;
    }
  }

  /// Get auth state stream
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // Backward compatibility getters for migration
  /// Access to auth API (replaces Appwrite account)
  GoTrueClient get account => client.auth;

  /// Direct access to auth API (alias for account)
  GoTrueClient get auth => client.auth;

  /// Access to database API (replaces Appwrite databases)
  SupabaseQueryBuilder from(String table) => client.from(table);

  /// Backwards compatibility - databases property
  /// Note: In Supabase, use client.from('table') instead of databases.from()
  SupabaseClient get databases => client;

  /// Access to realtime API
  RealtimeClient get realtime => client.realtime;

  /// Access to realtime instance (alias for realtime)
  RealtimeClient get realtimeInstance => client.realtime;

  // ============================================================================
  // USER PROFILES
  // ============================================================================

  /// Create user profile in users table
  Future<void> createUserProfile({
    required String userId,
    required String name,
    required String email,
  }) async {
    try {
      AppLogger().debug('📝 Creating user profile: $userId');

      await client.from('users').insert({
        'id': userId,
        'name': name,
        'email': email,
        'reputation': 0,
        'total_debates': 0,
        'wins': 0,
        'losses': 0,
        'coins': 0,
        'is_premium': false,
        'is_banned': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      AppLogger().debug('✅ User profile created');
    } catch (e) {
      AppLogger().debug('❌ Create user profile failed: $e');
      rethrow;
    }
  }

  /// Get user profile
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      AppLogger().debug('📖 Getting user profile: $userId');

      final response = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        AppLogger().debug('ℹ️ User profile not found: $userId');
        return null;
      }

      AppLogger().debug('✅ User profile retrieved: $userId');

      // Map Supabase response to UserProfile format (snake_case to camelCase)
      final mappedData = {
        'id': response['id'],
        'name': response['name'],
        'email': response['email'],
        'bio': response['bio'],
        'avatar': response['avatar_url'], // Map snake_case to camelCase
        'location': response['location'],
        'website': response['website'],
        'xHandle': response['twitter_handle'],
        'linkedinHandle': response['linkedin_url'],
        'youtubeHandle': response['youtube_handle'],
        'facebookHandle': response['facebook_handle'],
        'instagramHandle': response['instagram_handle'],
        'preferences': response['notification_preferences'] ?? {},
        'reputationPercentage': response['reputation_percentage'] ?? 100,
        'reputation': response['reputation'] ?? 0,
        'totalDebates': response['total_debates'] ?? 0,
        'totalWins': response['wins'] ?? 0,
        'totalLosses': response['losses'] ?? 0,
        'totalRoomsCreated': response['total_rooms_created'] ?? 0,
        'totalRoomsJoined': response['total_rooms_joined'] ?? 0,
        'coinBalance': response['coins'] ?? 100,
        'totalGiftsSent': response['total_gifts_sent'] ?? 0,
        'totalGiftsReceived': response['total_gifts_received'] ?? 0,
        'interests': response['interests'] ?? [],
        'joinedClubs': response['joined_clubs'] ?? [],
        'createdAt': response['created_at'],
        'updatedAt': response['updated_at'],
        'isVerified': response['is_verified'] ?? false,
        'isPublicProfile': response['is_public'] ?? true,
        'isAvailableAsModerator': response['is_available_as_moderator'] ?? false,
        'isAvailableAsJudge': response['is_available_as_judge'] ?? false,
        'isPremium': response['is_premium'] ?? false,
        'premiumType': response['premium_type'],
        'premiumExpiry': response['premium_expires_at'],
        'isTestSubscription': response['is_test_subscription'] ?? false,
        'isBanned': response['is_banned'] ?? false,
        'banReason': response['ban_reason'],
        'bannedAt': response['banned_until'],
        'lastSeen': response['last_seen'],
      };

      return UserProfile.fromMap(mappedData);
    } catch (e) {
      AppLogger().debug('❌ Get user profile failed: $e');
      return null;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? bio,
    String? avatarUrl,
    String? location,
    String? website,
    String? xHandle,
    String? linkedinHandle,
    String? youtubeHandle,
    String? facebookHandle,
    String? instagramHandle,
    List<String>? interests,
    bool? isPublicProfile,
  }) async {
    try {
      AppLogger().debug('✏️ Updating user profile: $userId');

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (bio != null) updates['bio'] = bio;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (location != null) updates['location'] = location;
      if (website != null) updates['website'] = website;
      if (xHandle != null) updates['x_handle'] = xHandle;
      if (linkedinHandle != null) updates['linkedin_handle'] = linkedinHandle;
      if (youtubeHandle != null) updates['youtube_handle'] = youtubeHandle;
      if (facebookHandle != null) updates['facebook_handle'] = facebookHandle;
      if (instagramHandle != null) updates['instagram_handle'] = instagramHandle;
      if (interests != null) updates['interests'] = interests;
      // Note: is_public column doesn't exist in users table
      // if (isPublicProfile != null) updates['is_public'] = isPublicProfile;

      await client
          .from('users')
          .update(updates)
          .eq('id', userId);

      AppLogger().debug('✅ User profile updated');
    } catch (e) {
      AppLogger().debug('❌ Update user profile failed: $e');
      rethrow;
    }
  }

  /// Update user stats
  Future<void> updateUserStats({
    required String userId,
    int? reputation,
    int? totalDebates,
    int? wins,
    int? losses,
    int? coins,
  }) async {
    try {
      AppLogger().debug('📊 Updating user stats: $userId');

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (reputation != null) updates['reputation'] = reputation;
      if (totalDebates != null) updates['total_debates'] = totalDebates;
      if (wins != null) updates['wins'] = wins;
      if (losses != null) updates['losses'] = losses;
      if (coins != null) updates['coins'] = coins;

      await client
          .from('users')
          .update(updates)
          .eq('id', userId);

      AppLogger().debug('✅ User stats updated');
    } catch (e) {
      AppLogger().debug('❌ Update user stats failed: $e');
      rethrow;
    }
  }

  /// Update last seen timestamp
  Future<void> updateLastSeen(String userId) async {
    try {
      // Note: 'last_seen' column doesn't exist in users table schema
      // Only updating updated_at as a lightweight presence indicator
      await client
          .from('users')
          .update({
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      AppLogger().debug('❌ Update last seen failed: $e');
      // Non-critical, don't rethrow
    }
  }

  /// Upload avatar image
  Future<String?> uploadAvatar({
    required String userId,
    required String filePath,
    required Uint8List fileBytes,
  }) async {
    try {
      AppLogger().debug('📤 Uploading avatar for: $userId');

      // Store in user-specific folder for security policy compliance
      final fileName = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final avatarUrl = client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      // Update user profile with new avatar URL
      await updateUserProfile(userId: userId, avatarUrl: avatarUrl);

      AppLogger().debug('✅ Avatar uploaded: $avatarUrl');
      return avatarUrl;
    } catch (e) {
      AppLogger().debug('❌ Avatar upload failed: $e');
      rethrow;
    }
  }

  /// Delete avatar
  Future<void> deleteAvatar(String userId) async {
    try {
      AppLogger().debug('🗑️ Deleting avatar for: $userId');

      // Get current avatar URL
      final profile = await getUserProfile(userId);
      if (profile?.avatar == null) return;

      // Extract full file path from URL (including userId folder)
      final url = Uri.parse(profile!.avatar!);
      // Get path after /storage/v1/object/public/avatars/
      final pathSegments = url.pathSegments;
      final bucketIndex = pathSegments.indexOf('avatars');
      final filePath = pathSegments.skip(bucketIndex + 1).join('/');

      // Delete from storage
      await client.storage
          .from('avatars')
          .remove([filePath]);

      // Update user profile
      await updateUserProfile(userId: userId, avatarUrl: null);

      AppLogger().debug('✅ Avatar deleted');
    } catch (e) {
      AppLogger().debug('❌ Delete avatar failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // FOLLOWS
  // ============================================================================

  /// Follow a user
  Future<void> followUser({
    required String followerId,
    required String followingId,
  }) async {
    try {
      AppLogger().debug('➕ Following user: $followerId → $followingId');

      await client.from('follows').insert({
        'follower_id': followerId,
        'following_id': followingId,
        'created_at': DateTime.now().toIso8601String(),
      });

      AppLogger().debug('✅ User followed');
    } catch (e) {
      AppLogger().debug('❌ Follow user failed: $e');
      rethrow;
    }
  }

  /// Unfollow a user
  Future<void> unfollowUser({
    required String followerId,
    required String followingId,
  }) async {
    try {
      AppLogger().debug('➖ Unfollowing user: $followerId → $followingId');

      await client
          .from('follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);

      AppLogger().debug('✅ User unfollowed');
    } catch (e) {
      AppLogger().debug('❌ Unfollow user failed: $e');
      rethrow;
    }
  }

  /// Check if following
  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final response = await client
          .from('follows')
          .select()
          .eq('follower_id', followerId)
          .eq('following_id', followingId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      AppLogger().debug('❌ Check following failed: $e');
      return false;
    }
  }

  /// Get follower count
  Future<int> getFollowerCount(String userId) async {
    try {
      final response = await client
          .from('follows')
          .select()
          .eq('following_id', userId);

      return (response as List).length;
    } catch (e) {
      AppLogger().debug('❌ Get follower count failed: $e');
      return 0;
    }
  }

  /// Get following count
  Future<int> getFollowingCount(String userId) async {
    try {
      final response = await client
          .from('follows')
          .select()
          .eq('follower_id', userId);

      return (response as List).length;
    } catch (e) {
      AppLogger().debug('❌ Get following count failed: $e');
      return 0;
    }
  }

  /// Get all users with pagination
  Future<({List<UserProfile> users, bool hasMore})> getAllUsersPaginated({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      AppLogger().debug('📖 Getting users (limit: $limit, offset: $offset)');

      // Use range() for offset-based pagination
      final response = await client
          .from('users')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit); // Range is inclusive on both ends

      final responseList = response as List;

      // Handle empty result
      if (responseList.isEmpty) {
        AppLogger().debug('⚠️ No users in database');
        return (users: <UserProfile>[], hasMore: false);
      }

      // Check if there are more users beyond this page
      // If we got exactly limit+1 items, there are more
      final hasMore = responseList.length > limit;
      final usersData = hasMore ? responseList.sublist(0, limit) : responseList;

      final users = usersData
          .map((userData) {
            try {
              // Map Supabase response to UserProfile format
              final mappedData = {
                'id': userData['id'] ?? '',
                'name': userData['name'] ?? 'Unknown',
                'email': userData['email'] ?? '',
                'bio': userData['bio'],
                'avatar': userData['avatar_url'],
                'location': userData['location'],
                'website': userData['website'],
                'xHandle': userData['twitter_handle'],
                'linkedinHandle': userData['linkedin_url'],
                'youtubeHandle': userData['youtube_handle'],
                'facebookHandle': userData['facebook_handle'],
                'instagramHandle': userData['instagram_handle'],
                'preferences': userData['notification_preferences'] ?? {},
                'reputationPercentage': userData['reputation_percentage'] ?? 100,
                'reputation': userData['reputation'] ?? 0,
                'totalDebates': userData['total_debates'] ?? 0,
                'totalWins': userData['wins'] ?? 0,
                'totalLosses': userData['losses'] ?? 0,
                'totalRoomsCreated': userData['total_rooms_created'] ?? 0,
                'totalRoomsJoined': userData['total_rooms_joined'] ?? 0,
                'coinBalance': userData['coins'] ?? 100,
                'totalGiftsSent': userData['total_gifts_sent'] ?? 0,
                'totalGiftsReceived': userData['total_gifts_received'] ?? 0,
                'interests': userData['interests'] ?? [],
                'joinedClubs': userData['joined_clubs'] ?? [],
                'createdAt': userData['created_at'] ?? DateTime.now().toIso8601String(),
                'updatedAt': userData['updated_at'] ?? DateTime.now().toIso8601String(),
                'isVerified': userData['is_verified'] ?? false,
                'isPublicProfile': userData['is_public'] ?? true,
                'isAvailableAsModerator': userData['is_available_as_moderator'] ?? false,
                'isAvailableAsJudge': userData['is_available_as_judge'] ?? false,
                'isPremium': userData['is_premium'] ?? false,
                'premiumType': userData['premium_type'],
                'premiumExpiry': userData['premium_expires_at'],
                'isTestSubscription': userData['is_test_subscription'] ?? false,
                'isBanned': userData['is_banned'] ?? false,
                'banReason': userData['ban_reason'],
                'bannedAt': userData['banned_until'],
                'lastSeen': userData['last_seen'],
              };
              return UserProfile.fromMap(mappedData);
            } catch (e) {
              AppLogger().debug('⚠️ Error parsing user: $e');
              return null;
            }
          })
          .whereType<UserProfile>() // Filter out nulls
          .toList();

      AppLogger().debug('✅ Retrieved ${users.length} users (hasMore: $hasMore)');
      return (users: users, hasMore: hasMore);
    } catch (e, stackTrace) {
      AppLogger().debug('❌ Get users failed: $e');
      AppLogger().debug('Stack trace: $stackTrace');
      return (users: <UserProfile>[], hasMore: false);
    }
  }

  // ============================================================================
  // ARENA ROOMS
  // ============================================================================

  /// Get active arena rooms
  Future<List<Map<String, dynamic>>> getActiveArenaRooms() async {
    try {
      AppLogger().debug('🔍 Getting active arena rooms');

      final response = await client
          .from('arena_rooms')
          .select()
          .inFilter('status', ['pending', 'active'])
          .order('created_at', ascending: false)
          .limit(50);

      AppLogger().debug('✅ Found ${(response as List).length} active arena rooms');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger().debug('❌ Get active arena rooms failed: $e');
      return [];
    }
  }

  /// Get joinable arena rooms
  Future<List<Map<String, dynamic>>> getJoinableArenaRooms() async {
    try {
      AppLogger().debug('🔍 Getting joinable arena rooms');

      final response = await client
          .from('arena_rooms')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(50);

      AppLogger().debug('✅ Found ${(response as List).length} joinable arena rooms');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger().debug('❌ Get joinable arena rooms failed: $e');
      return [];
    }
  }

  /// Get arena participants with full user profiles (arena2-style reliable loading)
  Future<List<Map<String, dynamic>>> getArenaParticipants(String roomId) async {
    try {
      AppLogger().debug('🔍 Getting arena participants for room: $roomId');

      // Step 1: Get all participants for this room
      final participantsResponse = await client
          .from('arena_participants')
          .select()
          .eq('room_id', roomId)
          .eq('status', 'active')
          .order('created_at', ascending: true);

      final documents = List<Map<String, dynamic>>.from(participantsResponse);
      if (documents.isEmpty) {
        AppLogger().debug('ℹ️ No participants found for room: $roomId');
        return [];
      }

      AppLogger().debug('📋 Found ${documents.length} participant records');

      // Step 2: Collect all unique user IDs
      final userIds = documents
          .map((doc) => doc['user_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      AppLogger().debug('👥 Fetching profiles for ${userIds.length} users');

      // Step 3: Batch fetch all user profiles
      Map<String, UserProfile> userProfilesMap = {};
      if (userIds.isNotEmpty) {
        try {
          // Supabase supports in() filter for batch queries
          final usersResponse = await client
              .from('users')
              .select()
              .inFilter('id', userIds);

          for (var userDoc in usersResponse) {
            // DEBUG: Log raw avatar data from database
            final rawAvatarUrl = userDoc['avatar_url'];
            final rawAvatar = userDoc['avatar'];
            // CRITICAL FIX: Always prefer avatar_url since that's where the actual data is stored
            final avatarValue = rawAvatarUrl ?? rawAvatar;

            if (avatarValue == null || avatarValue.toString().isEmpty) {
              AppLogger().warning('🔴 DB: ${userDoc['name']} has NO avatar! avatar_url=$rawAvatarUrl, avatar=$rawAvatar');
            } else {
              AppLogger().debug('🟢 DB: ${userDoc['name']} has avatar: ${avatarValue.toString().substring(0, 50)}...');
            }

            final mappedData = {
              'id': userDoc['id'],
              'name': userDoc['name'] ?? '',
              'email': userDoc['email'] ?? '',
              'avatar': avatarValue, // Always use avatar_url first (that's where real data is)
              'bio': userDoc['bio'],
              'reputation': userDoc['reputation'] ?? 0,
              'reputationPercentage': userDoc['reputation_percentage'] ?? 100,
              'totalWins': userDoc['wins'] ?? userDoc['total_wins'] ?? 0,
              'totalLosses': userDoc['losses'] ?? userDoc['total_losses'] ?? 0,
              'coinBalance': userDoc['coins'] ?? 100,
              'isPremium': userDoc['is_premium'] ?? false,
              'createdAt': userDoc['created_at'],
              'updatedAt': userDoc['updated_at'],
            };
            final profile = UserProfile.fromMap(mappedData);
            userProfilesMap[userDoc['id']] = profile;
            AppLogger().debug('✅ Loaded profile: ${profile.name} (${profile.id}) avatar=${profile.avatar != null}');
          }
        } catch (e) {
          AppLogger().warning('⚠️ Error batch fetching user profiles: $e');
        }
      }

      // Step 4: Build participant list with attached profiles
      List<Map<String, dynamic>> participants = [];
      for (var doc in documents) {
        final participantData = Map<String, dynamic>.from(doc);

        final userId = participantData['user_id'] as String?;
        if (userId != null) {
          // Get cached profile or fetch individually as fallback
          UserProfile? userProfile = userProfilesMap[userId];

          if (userProfile == null) {
            // Try individual fetch as last resort
            AppLogger().warning('⚠️ Profile not in batch for $userId, fetching individually');
            userProfile = await getUserProfile(userId);
          }

          if (userProfile != null) {
            participantData['userProfile'] = userProfile.toMap();
            AppLogger().debug('📌 Attached profile ${userProfile.name} to role ${participantData['role']}');
          } else {
            // CRITICAL FIX: Create placeholder to prevent "Unknown" users
            AppLogger().warning('⚠️ CRITICAL: User profile missing for userId: $userId. Creating placeholder.');
            participantData['userProfile'] = {
              'id': userId,
              'name': 'User ${userId.substring(0, 8)}',
              'email': '',
              'avatar': null,
              'bio': '',
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            };
          }
        }

        participants.add(participantData);
      }

      AppLogger().debug('✅ Returning ${participants.length} arena participants with profiles');
      return participants;
    } catch (e) {
      AppLogger().error('❌ Get arena participants failed: $e');
      return [];
    }
  }

  /// Join arena room (enforces single room presence)
  Future<void> joinArenaRoom({
    required String roomId,
    required String userId,
    required String role,
  }) async {
    try {
      AppLogger().debug('🚪 Joining arena room: $roomId as $role');

      // First, leave all other rooms to enforce single room presence
      await leaveAllOtherRooms(userId: userId, exceptRoomId: roomId);

      await client.from('arena_participants').upsert({
        'room_id': roomId,
        'user_id': userId,
        'role': role,
        'status': 'active',
        'joined_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'room_id,user_id');

      AppLogger().debug('✅ Joined arena room');
    } catch (e) {
      AppLogger().debug('❌ Join arena room failed: $e');
      rethrow;
    }
  }

  /// Leave arena room
  Future<void> leaveArenaRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      AppLogger().debug('🚪 Leaving arena room: $roomId');

      await client
          .from('arena_participants')
          .delete()
          .eq('room_id', roomId)
          .eq('user_id', userId);

      AppLogger().debug('✅ Left arena room');
    } catch (e) {
      AppLogger().debug('❌ Leave arena room failed: $e');
      rethrow;
    }
  }

  /// Create arena room
  Future<String> createArenaRoom({
    required String title,
    required String topic,
    required String challengerId,
    required String challengedId,
    String? challengeId,
    String? stakes,
    int? stakeAmount,
    int? durationMinutes,
  }) async {
    try {
      AppLogger().debug('🏟️ Creating arena room: $title');

      final response = await client.from('arena_rooms').insert({
        'title': title,
        'topic': topic,
        'challenger_id': challengerId,
        'challenged_id': challengedId,
        'challenge_id': challengeId,
        'status': 'pending',
        'room_type': 'arena',
        'max_participants': 2,
        'stakes': stakes,
        'stake_amount': stakeAmount ?? 0,
        'duration_minutes': durationMinutes ?? 30,
        'created_by': challengerId, // Set room creator
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();

      final roomId = response['id'] as String;
      AppLogger().debug('✅ Arena room created: $roomId');

      return roomId;
    } catch (e) {
      AppLogger().debug('❌ Create arena room failed: $e');
      rethrow;
    }
  }

  /// Create simple arena room (for quick debates without challenge setup)
  Future<String> createSimpleArenaRoom({
    required String creatorId,
    required String topic,
    String? description,
  }) async {
    try {
      AppLogger().debug('🏟️ Creating simple arena room: $topic');

      final response = await client.from('arena_rooms').insert({
        'title': topic,
        'topic': topic,
        'description': description,
        'challenger_id': creatorId,
        'challenged_id': null, // Empty for open challenge
        'challenge_id': null, // Empty for simple room
        'status': 'pending',
        'room_type': 'arena',
        'max_participants': 10, // Allow moderator + debaters + judges + audience
        'duration_minutes': 30,
        'created_by': creatorId, // Set room creator
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();

      final roomId = response['id'] as String;
      AppLogger().debug('✅ Simple arena room created: $roomId');

      // Add creator as first participant (moderator)
      await joinArenaRoom(
        roomId: roomId,
        userId: creatorId,
        role: 'moderator',
      );

      return roomId;
    } catch (e) {
      AppLogger().debug('❌ Create simple arena room failed: $e');
      rethrow;
    }
  }

  /// Get arena room
  Future<Map<String, dynamic>?> getArenaRoom(String roomId) async {
    try {
      final response = await client
          .from('arena_rooms')
          .select()
          .eq('id', roomId)
          .maybeSingle();

      return response;
    } catch (e) {
      AppLogger().debug('❌ Get arena room failed: $e');
      return null;
    }
  }

  /// Update arena room status
  Future<void> updateArenaRoomStatus(String roomId, String status) async {
    try {
      AppLogger().debug('🔄 Updating arena room status: $roomId → $status');

      await client
          .from('arena_rooms')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', roomId);

      AppLogger().debug('✅ Arena room status updated');
    } catch (e) {
      AppLogger().debug('❌ Update arena room status failed: $e');
      rethrow;
    }
  }

  /// Start arena debate
  Future<void> startArenaDebate(String roomId) async {
    try {
      AppLogger().debug('▶️ Starting arena debate: $roomId');

      await client
          .from('arena_rooms')
          .update({
            'status': 'active',
            'started_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', roomId);

      AppLogger().debug('✅ Arena debate started');
    } catch (e) {
      AppLogger().debug('❌ Start arena debate failed: $e');
      rethrow;
    }
  }

  /// Complete arena room
  Future<void> completeArenaRoom(String roomId) async {
    try {
      AppLogger().debug('🏁 Completing arena room: $roomId');

      await client
          .from('arena_rooms')
          .update({
            'status': 'completed',
            'ended_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', roomId);

      AppLogger().debug('✅ Arena room completed');
    } catch (e) {
      AppLogger().debug('❌ Complete arena room failed: $e');
      rethrow;
    }
  }

  /// Broadcast arena results to all participants
  /// This calls the PostgreSQL function that:
  /// 1. Calculates winner from judgments
  /// 2. Updates arena_rooms with winner, show_results=true
  /// 3. Triggers realtime update to all clients
  Future<Map<String, dynamic>> broadcastArenaResults(String roomId) async {
    try {
      AppLogger().debug('📢 Broadcasting arena results: $roomId');

      final response = await client.rpc(
        'broadcast_arena_results',
        params: {'p_room_id': roomId},
      );

      AppLogger().debug('✅ Arena results broadcast: $response');

      // Handle response - it could be a Map directly or need parsing
      if (response is Map<String, dynamic>) {
        return response;
      } else if (response is List && response.isNotEmpty) {
        return response.first as Map<String, dynamic>;
      }

      return {
        'success': true,
        'message': 'Results broadcast',
      };
    } catch (e) {
      AppLogger().debug('❌ Broadcast arena results failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================================
  // DEBATE & DISCUSSION ROOMS
  // ============================================================================

  /// Create debate discussion room
  Future<String> createDebateDiscussionRoom({
    required String title,
    required String topic,
    required String creatorId,
    String? debateStyle,
    bool isPrivate = false,
    String? password,
    int? maxParticipants,
    bool requiresApproval = false,
    String speakerPanelStyle = 'grid', // 'grid' or 'floating'
  }) async {
    try {
      AppLogger().debug('💬 Creating debate discussion room: $title (style: $debateStyle, panel: $speakerPanelStyle)');

      final response = await client.from('debate_discussion_rooms').insert({
        'title': title,
        'topic': topic,
        'moderator_id': creatorId,
        'room_type': debateStyle ?? 'Discussion',
        'status': 'active',
        'is_private': isPrivate,
        'max_participants': maxParticipants ?? 50,
        'requires_approval': requiresApproval,
        'speaker_panel_style': speakerPanelStyle,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();

      final roomId = response['id'] as String;
      AppLogger().debug('✅ Debate discussion room created: $roomId');

      // Add creator as moderator
      AppLogger().debug('💬 Adding creator as moderator participant: $creatorId');
      await joinDebateDiscussionRoom(
        roomId: roomId,
        userId: creatorId,
        role: 'moderator',
      );

      // Verify participant was added
      final participants = await getDebateDiscussionParticipants(roomId);
      final creatorParticipant = participants.any((p) => p['user_id'] == creatorId && p['role'] == 'moderator');
      AppLogger().info('🔍 Creator participant verification: found=$creatorParticipant, total participants=${participants.length}');

      if (!creatorParticipant) {
        AppLogger().error('⚠️ WARNING: Creator was not added as participant! Room may not function correctly.');
      }

      return roomId;
    } catch (e) {
      AppLogger().debug('❌ Create debate discussion room failed: $e');
      rethrow;
    }
  }

  /// Get debate discussion room
  Future<Map<String, dynamic>?> getDebateDiscussionRoom(String roomId) async {
    try {
      final response = await client
          .from('debate_discussion_rooms')
          .select()
          .eq('id', roomId)
          .maybeSingle();

      return response;
    } catch (e) {
      AppLogger().debug('❌ Get debate discussion room failed: $e');
      return null;
    }
  }

  /// Get debate discussion rooms with moderator and debater info
  Future<List<Map<String, dynamic>>> getDebateDiscussionRooms() async {
    try {
      final response = await client
          .from('debate_discussion_rooms')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(50);

      // Enhance each room with moderator profile and debaters
      final rooms = List<Map<String, dynamic>>.from(response);
      for (int i = 0; i < rooms.length; i++) {
        final room = Map<String, dynamic>.from(rooms[i]);
        final moderatorId = room['moderator_id'] ?? room['created_by'];
        final roomId = room['id'];
        final roomType = room['room_type'];

        // Fetch moderator profile
        if (moderatorId != null) {
          try {
            final moderatorProfile = await client
                .from('users')
                .select('id, name, avatar, avatar_url')
                .eq('id', moderatorId)
                .maybeSingle();
            if (moderatorProfile != null) {
              room['moderatorProfile'] = moderatorProfile;
            }
          } catch (e) {
            AppLogger().debug('Could not fetch moderator profile: $e');
          }
        }

        // For Debate rooms, fetch debater info (affirmative and negative)
        final tags = room['tags'] as List?;
        final isDebateRoom = roomType == 'Debate' || (tags?.isNotEmpty == true && tags![0] == 'Debate');
        if (isDebateRoom && roomId != null) {
          try {
            final participants = await client
                .from('debate_discussion_participants')
                .select('user_id, role')
                .eq('room_id', roomId)
                .inFilter('role', ['affirmative', 'negative']);

            for (final participant in participants) {
              final odId = participant['user_id'];
              final role = participant['role'];

              // Fetch user profile for each debater
              final userProfile = await client
                  .from('users')
                  .select('id, name, avatar, avatar_url')
                  .eq('id', odId)
                  .maybeSingle();

              if (userProfile != null) {
                if (role == 'affirmative') {
                  room['affirmativeDebater'] = userProfile;
                } else if (role == 'negative') {
                  room['negativeDebater'] = userProfile;
                }
              }
            }
          } catch (e) {
            AppLogger().debug('Could not fetch debaters: $e');
          }
        }

        // Fetch participant count for all room types
        if (roomId != null) {
          try {
            final participantCountResponse = await client
                .from('debate_discussion_participants')
                .select('id')
                .eq('room_id', roomId);
            room['participantCount'] = (participantCountResponse as List).length;
          } catch (e) {
            AppLogger().debug('Could not fetch participant count: $e');
            room['participantCount'] = 0;
          }
        }

        rooms[i] = room;
      }

      return rooms;
    } catch (e) {
      AppLogger().debug('❌ Get debate discussion rooms failed: $e');
      return [];
    }
  }

  /// Validate debate discussion room password
  Future<bool> validateDebateDiscussionRoomPassword({
    required String roomId,
    required String password,
  }) async {
    try {
      AppLogger().debug('🔐 Validating room password: $roomId');

      final room = await getDebateDiscussionRoom(roomId);
      if (room == null) {
        AppLogger().debug('❌ Room not found: $roomId');
        return false;
      }

      final storedPassword = room['password'] as String?;
      if (storedPassword == null) {
        // Room has no password, allow access
        AppLogger().debug('✅ Room has no password');
        return true;
      }

      final isValid = storedPassword == password;
      AppLogger().debug(isValid ? '✅ Password valid' : '❌ Password invalid');
      return isValid;
    } catch (e) {
      AppLogger().debug('❌ Validate room password failed: $e');
      return false;
    }
  }

  /// Get all active room participations for a user (across all room types)
  /// Returns list of room IDs where user is currently active
  Future<List<String>> getUserActiveRooms(String userId) async {
    try {
      final activeRooms = <String>[];

      // Check debate_discussion_participants
      final ddParticipations = await client
          .from('debate_discussion_participants')
          .select('room_id')
          .eq('user_id', userId)
          .eq('status', 'active');

      for (final p in ddParticipations) {
        if (p['room_id'] != null) {
          activeRooms.add(p['room_id'] as String);
        }
      }

      // Check arena_participants
      final arenaParticipations = await client
          .from('arena_participants')
          .select('room_id')
          .eq('user_id', userId)
          .eq('status', 'active');

      for (final p in arenaParticipations) {
        if (p['room_id'] != null) {
          activeRooms.add(p['room_id'] as String);
        }
      }

      AppLogger().debug('👤 User $userId is in ${activeRooms.length} active rooms: $activeRooms');
      return activeRooms;
    } catch (e) {
      AppLogger().debug('❌ Get user active rooms failed: $e');
      return [];
    }
  }

  /// Leave all rooms except the specified one (enforces single room presence)
  Future<void> leaveAllOtherRooms({
    required String userId,
    required String exceptRoomId,
  }) async {
    try {
      AppLogger().debug('🚪 Leaving all rooms except: $exceptRoomId');

      // Leave all debate_discussion rooms except the target
      await client
          .from('debate_discussion_participants')
          .delete()
          .eq('user_id', userId)
          .neq('room_id', exceptRoomId);

      // Leave all arena rooms except the target
      await client
          .from('arena_participants')
          .delete()
          .eq('user_id', userId)
          .neq('room_id', exceptRoomId);

      AppLogger().debug('✅ Left all other rooms');
    } catch (e) {
      AppLogger().debug('❌ Leave all other rooms failed: $e');
      // Don't rethrow - this is a cleanup operation
    }
  }

  /// Join debate discussion room (enforces single room presence)
  Future<void> joinDebateDiscussionRoom({
    required String roomId,
    required String userId,
    String role = 'audience',
  }) async {
    try {
      AppLogger().debug('🚪 Joining debate discussion room: $roomId as $role');

      // Check if user is banned from this room
      final now = DateTime.now().toUtc().toIso8601String();
      final banCheck = await client
          .from('user_bans')
          .select()
          .eq('room_id', roomId)
          .eq('user_id', userId)
          .eq('is_active', true)
          .or('expires_at.is.null,expires_at.gt.$now')
          .maybeSingle();

      if (banCheck != null) {
        final expiresAt = banCheck['expires_at'];
        final isPermanent = expiresAt == null;
        AppLogger().warning('🔨 User $userId is banned from room $roomId (${isPermanent ? "permanent" : "expires: $expiresAt"})');
        throw Exception('You are banned from this room${isPermanent ? " permanently" : ""}');
      }

      // First, leave all other rooms to enforce single room presence
      await leaveAllOtherRooms(userId: userId, exceptRoomId: roomId);

      await client.from('debate_discussion_participants').upsert({
        'room_id': roomId,
        'user_id': userId,
        'role': role,
        'status': 'active',
        'joined_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'room_id,user_id');

      AppLogger().debug('✅ Joined debate discussion room');
    } catch (e) {
      AppLogger().debug('❌ Join debate discussion room failed: $e');
      rethrow;
    }
  }

  /// Leave debate discussion room
  Future<void> leaveDebateDiscussionRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      AppLogger().debug('🚪 Leaving debate discussion room: $roomId');

      await client
          .from('debate_discussion_participants')
          .delete()
          .eq('room_id', roomId)
          .eq('user_id', userId);

      AppLogger().debug('✅ Left debate discussion room');
    } catch (e) {
      AppLogger().debug('❌ Leave debate discussion room failed: $e');
      rethrow;
    }
  }

  /// Get debate discussion participants
  Future<List<Map<String, dynamic>>> getDebateDiscussionParticipants(String roomId) async {
    try {
      final response = await client
          .from('debate_discussion_participants')
          .select('*, users(*)')
          .eq('room_id', roomId)
          .eq('status', 'active');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger().debug('❌ Get debate discussion participants failed: $e');
      return [];
    }
  }

  /// Update debate discussion participant role
  Future<void> updateDebateDiscussionParticipantRole({
    required String roomId,
    required String userId,
    required String newRole,
  }) async {
    try {
      AppLogger().debug('🔄 Updating participant role: $userId → $newRole');

      await client
          .from('debate_discussion_participants')
          .update({
            'role': newRole,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('room_id', roomId)
          .eq('user_id', userId);

      AppLogger().debug('✅ Participant role updated');
    } catch (e) {
      AppLogger().debug('❌ Update participant role failed: $e');
      rethrow;
    }
  }

  /// Update debate discussion participant metadata
  Future<void> updateDebateDiscussionParticipantMetadata({
    required String roomId,
    required String userId,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      AppLogger().debug('🔄 Updating participant metadata: $userId');

      await client
          .from('debate_discussion_participants')
          .update({
            'metadata': metadata,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('room_id', roomId)
          .eq('user_id', userId);

      AppLogger().debug('✅ Participant metadata updated');
    } catch (e) {
      AppLogger().debug('❌ Update participant metadata failed: $e');
      rethrow;
    }
  }

  // Aliases for backward compatibility with old method names
  Future<Map<String, dynamic>?> getRoom(String roomId) async {
    return await getDebateDiscussionRoom(roomId);
  }

  Future<void> joinRoom({
    required String roomId,
    required String userId,
    String role = 'audience',
  }) async {
    return await joinDebateDiscussionRoom(
      roomId: roomId,
      userId: userId,
      role: role,
    );
  }

  Future<void> leaveRoom({
    required String roomId,
    required String userId,
  }) async {
    return await leaveDebateDiscussionRoom(
      roomId: roomId,
      userId: userId,
    );
  }

  Future<void> updateParticipantRole({
    required String roomId,
    required String userId,
    required String newRole,
  }) async {
    return await updateDebateDiscussionParticipantRole(
      roomId: roomId,
      userId: userId,
      newRole: newRole,
    );
  }

  Future<void> updateParticipantMetadata({
    required String roomId,
    required String userId,
    required Map<String, dynamic> metadata,
  }) async {
    return await updateDebateDiscussionParticipantMetadata(
      roomId: roomId,
      userId: userId,
      metadata: metadata,
    );
  }

  // ============================================================================
  // REAL-TIME SUBSCRIPTIONS
  // ============================================================================

  /// Subscribe to room participants changes
  Stream<List<Map<String, dynamic>>> subscribeToDebateDiscussionParticipants(String roomId) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    final channel = client
        .channel('debate_discussion_participants:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'debate_discussion_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) async {
            // Fetch latest participants
            final participants = await getDebateDiscussionParticipants(roomId);
            controller.add(participants);
          },
        )
        .subscribe();

    _subscriptions['debate_discussion_participants:$roomId'] = channel;

    // Initial load
    getDebateDiscussionParticipants(roomId).then((participants) {
      if (!controller.isClosed) {
        controller.add(participants);
      }
    });

    return controller.stream;
  }

  /// Subscribe to arena room changes
  Stream<Map<String, dynamic>?> subscribeToArenaRoom(String roomId) {
    final controller = StreamController<Map<String, dynamic>?>.broadcast();

    final channel = client
        .channel('arena_rooms:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'arena_rooms',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: roomId,
          ),
          callback: (payload) async {
            // Fetch latest room data
            final room = await getArenaRoom(roomId);
            controller.add(room);
          },
        )
        .subscribe();

    _subscriptions['arena_rooms:$roomId'] = channel;

    // Initial load
    getArenaRoom(roomId).then((room) {
      if (!controller.isClosed) {
        controller.add(room);
      }
    });

    return controller.stream;
  }

  /// Unsubscribe from a channel
  Future<void> unsubscribe(String channelKey) async {
    try {
      final channel = _subscriptions[channelKey];
      if (channel != null) {
        await client.removeChannel(channel);
        _subscriptions.remove(channelKey);
        AppLogger().debug('✅ Unsubscribed from: $channelKey');
      }
    } catch (e) {
      AppLogger().debug('❌ Unsubscribe failed: $e');
    }
  }

  /// Clean up all subscriptions
  Future<void> _cleanupAllSubscriptions() async {
    try {
      AppLogger().debug('🧹 Cleaning up all subscriptions');

      for (final channel in _subscriptions.values) {
        await client.removeChannel(channel);
      }

      _subscriptions.clear();
      AppLogger().debug('✅ All subscriptions cleaned up');
    } catch (e) {
      AppLogger().debug('❌ Cleanup subscriptions failed: $e');
    }
  }

  // ============================================================================
  // CHALLENGES
  // ============================================================================

  /// Send challenge
  Future<void> sendChallenge({
    required String challengerId,
    required String challengedId,
    required String title,
    required String topic,
    String? stakes,
    int? stakeAmount,
    DateTime? proposedTime,
  }) async {
    try {
      AppLogger().debug('⚔️ Sending challenge: $challengerId → $challengedId');

      await client.from('challenges').insert({
        'challenger_id': challengerId,
        'challenged_id': challengedId,
        'title': title,
        'topic': topic,
        'status': 'pending',
        'stakes': stakes,
        'stake_amount': stakeAmount ?? 0,
        'proposed_time': proposedTime?.toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      AppLogger().debug('✅ Challenge sent');
    } catch (e) {
      AppLogger().debug('❌ Send challenge failed: $e');
      rethrow;
    }
  }

  /// Respond to challenge
  Future<void> respondToChallenge({
    required String challengeId,
    required bool accept,
  }) async {
    try {
      AppLogger().debug('📝 Responding to challenge: $challengeId (accept: $accept)');

      await client
          .from('challenges')
          .update({
            'status': accept ? 'accepted' : 'rejected',
            'accepted_at': accept ? DateTime.now().toIso8601String() : null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', challengeId);

      AppLogger().debug('✅ Challenge response recorded');
    } catch (e) {
      AppLogger().debug('❌ Respond to challenge failed: $e');
      rethrow;
    }
  }

  /// Get user challenges
  Future<List<Map<String, dynamic>>> getUserChallenges(String userId) async {
    try {
      final response = await client
          .from('challenges')
          .select()
          .or('challenger_id.eq.$userId,challenged_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger().debug('❌ Get user challenges failed: $e');
      return [];
    }
  }

  // ============================================================================
  // UTILITY
  // ============================================================================

  /// Test Supabase connection
  Future<void> testConnection() async {
    try {
      AppLogger().debug('🧪 Testing Supabase connection');

      final response = await client
          .from('users')
          .select('count')
          .limit(1);

      AppLogger().debug('✅ Supabase connection successful');
      AppLogger().debug('   Response: $response');
    } catch (e) {
      AppLogger().debug('❌ Supabase connection failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // STUB METHODS (TODO: Implement properly)
  // ============================================================================

  /// Assign arena role to participant
  Future<void> assignArenaRole({
    required String roomId,
    required String userId,
    required String role,
  }) async {
    try {
      AppLogger().info('🎭 ASSIGN_ROLE: ENTRY - roomId=$roomId, userId=$userId, role=$role');

      final payload = {
        'room_id': roomId,
        'user_id': userId,
        'role': role,
        'status': 'active',
        'joined_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      AppLogger().info('🎭 ASSIGN_ROLE: Payload being sent: $payload');

      await client.from('arena_participants').upsert(payload, onConflict: 'room_id,user_id');

      AppLogger().info('🎭 ASSIGN_ROLE: SUCCESS - $userId assigned $role in $roomId');
    } catch (e) {
      AppLogger().error('🎭 ASSIGN_ROLE: FAILED - $userId → $role in $roomId: $e');
      rethrow;
    }
  }

  /// Get user memberships (debate clubs)
  Future<List<Map<String, dynamic>>> getUserMemberships(String userId) async {
    try {
      AppLogger().debug('📋 Getting user memberships: $userId');

      final response = await client
          .from('debate_club_members')
          .select('*, debate_clubs(*)')
          .eq('user_id', userId)
          .eq('status', 'active');

      AppLogger().debug('✅ Found ${(response as List).length} memberships');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger().debug('❌ Get user memberships failed: $e');
      return [];
    }
  }

  /// Get all rooms with moderator and debater info
  Future<List<Map<String, dynamic>>> getRooms() async {
    try {
      AppLogger().debug('🏠 Getting all rooms');

      final response = await client
          .from('debate_discussion_rooms')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(50);

      AppLogger().debug('✅ Found ${(response as List).length} rooms');

      // Enhance each room with moderator profile and debaters
      final rooms = List<Map<String, dynamic>>.from(response);
      for (int i = 0; i < rooms.length; i++) {
        final room = Map<String, dynamic>.from(rooms[i]);
        final moderatorId = room['moderator_id'] ?? room['created_by'];
        final roomId = room['id'];
        final roomType = room['room_type'];

        // Fetch moderator profile
        if (moderatorId != null) {
          try {
            final moderatorProfile = await client
                .from('users')
                .select('id, name, avatar, avatar_url')
                .eq('id', moderatorId)
                .maybeSingle();
            if (moderatorProfile != null) {
              room['moderatorProfile'] = moderatorProfile;
            }
          } catch (e) {
            AppLogger().debug('Could not fetch moderator profile: $e');
          }
        }

        // For Debate rooms, fetch debater info (affirmative and negative)
        final tags = room['tags'] as List?;
        final isDebateRoom = roomType == 'Debate' || (tags?.isNotEmpty == true && tags![0] == 'Debate');
        if (isDebateRoom && roomId != null) {
          try {
            final participants = await client
                .from('debate_discussion_participants')
                .select('user_id, role')
                .eq('room_id', roomId)
                .inFilter('role', ['affirmative', 'negative']);

            for (final participant in participants) {
              final userId = participant['user_id'];
              final role = participant['role'];

              // Fetch user profile for each debater
              final userProfile = await client
                  .from('users')
                  .select('id, name, avatar, avatar_url')
                  .eq('id', userId)
                  .maybeSingle();

              if (userProfile != null) {
                if (role == 'affirmative') {
                  room['affirmativeDebater'] = userProfile;
                } else if (role == 'negative') {
                  room['negativeDebater'] = userProfile;
                }
              }
            }
          } catch (e) {
            AppLogger().debug('Could not fetch debaters: $e');
          }
        }

        rooms[i] = room;
      }

      return rooms;
    } catch (e) {
      AppLogger().debug('❌ Get rooms failed: $e');
      return [];
    }
  }

  /// Get debate clubs
  Future<List<Map<String, dynamic>>> getDebateClubs() async {
    try {
      AppLogger().debug('🏛️ Getting debate clubs');

      final response = await client
          .from('debate_clubs')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(50);

      AppLogger().debug('✅ Found ${(response as List).length} clubs');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger().debug('❌ Get debate clubs failed: $e');
      return [];
    }
  }

  /// Exit all debate discussion rooms for a user
  Future<void> exitAllDebateDiscussionRooms(String userId) async {
    try {
      AppLogger().debug('🚪 Exiting all debate discussion rooms for: $userId');

      await client
          .from('debate_discussion_participants')
          .delete()
          .eq('user_id', userId);

      AppLogger().debug('✅ Exited all rooms');
    } catch (e) {
      AppLogger().debug('❌ Exit all rooms failed: $e');
      // Non-critical, don't rethrow
    }
  }

  // ============================================================================
  // ADDITIONAL METHODS (Supabase Migration)
  // ============================================================================

  /// Update debate discussion participant media status
  Future<void> updateDebateDiscussionParticipantMedia({
    required String roomId,
    required String userId,
    required bool hasAudio,
    required bool hasVideo,
  }) async {
    try {
      await client
          .from('debate_discussion_participants')
          .update({
            'has_audio': hasAudio,
            'has_video': hasVideo,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('room_id', roomId)
          .eq('user_id', userId);

      AppLogger().debug('✅ Updated participant media status');
    } catch (e) {
      AppLogger().debug('❌ Update participant media failed: $e');
      rethrow;
    }
  }

  /// Update debate discussion room
  Future<void> updateDebateDiscussionRoom({
    required String roomId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await client
          .from('debate_discussion_rooms')
          .update({
            ...updates,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', roomId);

      AppLogger().debug('✅ Updated debate discussion room');
    } catch (e) {
      AppLogger().debug('❌ Update room failed: $e');
      rethrow;
    }
  }

  /// Update arena participant presence
  /// Uses 'status' column (active/left) and 'left_at' timestamp
  /// Valid statuses: 'active', 'left', 'kicked'
  Future<void> updateArenaParticipantPresence({
    required String roomId,
    required String userId,
    required bool isPresent,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': isPresent ? 'active' : 'left',
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Set left_at timestamp when user leaves
      if (!isPresent) {
        updateData['left_at'] = DateTime.now().toIso8601String();
      }

      await client
          .from('arena_participants')
          .update(updateData)
          .eq('room_id', roomId)
          .eq('user_id', userId);

      AppLogger().debug('✅ Updated arena participant presence');
    } catch (e) {
      AppLogger().debug('❌ Update presence failed: $e');
      rethrow;
    }
  }

  /// Update arena participant role
  Future<void> updateArenaParticipantRole({
    required String roomId,
    required String userId,
    required String newRole,
  }) async {
    try {
      await client
          .from('arena_participants')
          .update({
            'role': newRole,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('room_id', roomId)
          .eq('user_id', userId);

      AppLogger().debug('✅ Updated arena participant role');
    } catch (e) {
      AppLogger().debug('❌ Update role failed: $e');
      rethrow;
    }
  }

  /// Close arena room
  Future<void> closeArenaRoom(String roomId) async {
    try {
      await client
          .from('arena_rooms')
          .update({
            'status': 'closed',
            'ended_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', roomId);

      AppLogger().debug('✅ Closed arena room');
    } catch (e) {
      AppLogger().debug('❌ Close room failed: $e');
      rethrow;
    }
  }

  /// Get available judges
  Future<List<Map<String, dynamic>>> getAvailableJudges({
    String? category,
    int limit = 50,
  }) async {
    try {
      var query = client
          .from('judges')
          .select('*, users(*)')
          .eq('is_active', true)
          .eq('is_available', true);

      if (category != null) {
        query = query.contains('categories', [category]);
      }

      final response = await query.limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger().debug('❌ Get available judges failed: $e');
      return [];
    }
  }

  /// Call Supabase Edge Function (replaces callFunction)
  Future<Map<String, dynamic>> callFunction(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await client.functions.invoke(
        functionName,
        body: body,
      );

      return response.data as Map<String, dynamic>? ?? {};
    } catch (e) {
      AppLogger().debug('❌ Function call failed: $e');
      rethrow;
    }
  }

  /// Close a room and notify all participants via Edge Function
  /// This ensures all participants are properly notified even if realtime is unreliable
  Future<Map<String, dynamic>> closeRoom({
    required String roomId,
    required String roomType,
    required String moderatorId,
  }) async {
    try {
      AppLogger().info('🚪 Closing room via Edge Function: $roomId');

      final response = await client.functions.invoke(
        'close-room',
        body: {
          'room_id': roomId,
          'room_type': roomType,
          'moderator_id': moderatorId,
        },
      );

      final data = response.data as Map<String, dynamic>? ?? {};

      if (data['success'] == true) {
        AppLogger().info('✅ Room closed successfully. Participants notified: ${data['participants_notified']}');
      } else if (data['error'] != null) {
        AppLogger().error('❌ Room close error: ${data['error']}');
      }

      return data;
    } catch (e) {
      AppLogger().error('❌ Close room Edge Function failed: $e');
      // Fallback to direct database update if Edge Function fails
      await updateDebateDiscussionRoom(
        roomId: roomId,
        updates: {
          'status': 'completed',
          'ended_at': DateTime.now().toIso8601String(),
        },
      );
      return {'success': true, 'fallback': true};
    }
  }

  /// Update debate discussion participant presence
  Future<void> updateDebateDiscussionParticipantPresence({
    required String roomId,
    required String userId,
    required bool isPresent,
  }) async {
    try {
      await client
          .from('debate_discussion_participants')
          .update({
            // 'is_present': isPresent, // Column doesn't exist in table yet
            // 'last_seen': DateTime.now().toIso8601String(), // Column doesn't exist in table
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('room_id', roomId)
          .eq('user_id', userId);

      AppLogger().debug('✅ Updated participant presence');
    } catch (e) {
      AppLogger().debug('❌ Update presence failed: $e');
      rethrow;
    }
  }

  /// Verify and repair challenge debaters (stub - implement logic as needed)
  Future<void> verifyAndRepairChallengeDebaters({
    required String roomId,
    required String challengerId,
    required String challengedId,
  }) async {
    try {
      AppLogger().debug('🔧 Verifying challenge debaters for room: $roomId');

      // Check if both participants exist
      final participants = await client
          .from('arena_participants')
          .select()
          .eq('room_id', roomId)
          .inFilter('user_id', [challengerId, challengedId]);

      // Add missing participants
      final existingIds = (participants as List)
          .map((p) => p['user_id'] as String)
          .toSet();

      if (!existingIds.contains(challengerId)) {
        await joinArenaRoom(
          roomId: roomId,
          userId: challengerId,
          role: 'affirmative',
        );
      }

      if (!existingIds.contains(challengedId)) {
        await joinArenaRoom(
          roomId: roomId,
          userId: challengedId,
          role: 'negative',
        );
      }

      AppLogger().debug('✅ Challenge debaters verified');
    } catch (e) {
      AppLogger().debug('❌ Verify challenge debaters failed: $e');
      rethrow;
    }
  }

  /// Start arena recording (stub - implement with storage logic)
  Future<void> startArenaRecording(String roomId) async {
    try {
      await client
          .from('arena_rooms')
          .update({
            'is_recording': true,
            'recording_started_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', roomId);

      AppLogger().debug('✅ Started arena recording');
    } catch (e) {
      AppLogger().debug('❌ Start recording failed: $e');
      rethrow;
    }
  }

  /// Add to speaker queue
  Future<void> addToSpeakerQueue({
    required String roomId,
    required String userId,
  }) async {
    try {
      await client.from('speaker_queue').insert({
        'room_id': roomId,
        'user_id': userId,
        'position': 0, // Will be calculated by database trigger
        'status': 'waiting',
        'created_at': DateTime.now().toIso8601String(),
      });

      AppLogger().debug('✅ Added to speaker queue');
    } catch (e) {
      AppLogger().debug('❌ Add to queue failed: $e');
      rethrow;
    }
  }

  /// Remove from speaker queue
  Future<void> removeFromSpeakerQueue({
    required String roomId,
    required String userId,
  }) async {
    try {
      await client
          .from('speaker_queue')
          .delete()
          .eq('room_id', roomId)
          .eq('user_id', userId);

      AppLogger().debug('✅ Removed from speaker queue');
    } catch (e) {
      AppLogger().debug('❌ Remove from queue failed: $e');
      rethrow;
    }
  }

  /// Set current speaker
  Future<void> setCurrentSpeaker({
    required String roomId,
    required String userId,
  }) async {
    try {
      await client
          .from('debate_discussion_rooms')
          .update({
            'current_speaker_id': userId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', roomId);

      AppLogger().debug('✅ Set current speaker');
    } catch (e) {
      AppLogger().debug('❌ Set speaker failed: $e');
      rethrow;
    }
  }

  /// Get speaker queue
  Future<List<Map<String, dynamic>>> getSpeakerQueue(String roomId) async {
    try {
      final response = await client
          .from('speaker_queue')
          .select('*, users(*)')
          .eq('room_id', roomId)
          .eq('status', 'waiting')
          .order('position');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger().debug('❌ Get speaker queue failed: $e');
      return [];
    }
  }

  /// Subscribe to speaker queue (returns stream)
  Stream<List<Map<String, dynamic>>> subscribeToSpeakerQueue(String roomId) {
    return subscribeToDebateDiscussionParticipants(roomId);
  }

  // ============================================================================
  // DEBATE CLUBS
  // ============================================================================

  /// Get club members
  Future<List<Map<String, dynamic>>> getClubMembers(String clubId) async {
    try {
      AppLogger().debug('👥 Getting club members: $clubId');

      final response = await client
          .from('club_memberships')
          .select('*, users(*)')
          .eq('club_id', clubId)
          .eq('status', 'active');

      AppLogger().debug('✅ Found ${(response as List).length} members');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger().debug('❌ Get club members failed: $e');
      return [];
    }
  }

  /// Create debate club
  Future<String> createDebateClub({
    required String name,
    required String description,
    required String creatorId,
    String? category,
    bool isPrivate = false,
  }) async {
    try {
      AppLogger().debug('🎭 Creating debate club: $name');

      final response = await client.from('debate_clubs').insert({
        'name': name,
        'description': description,
        'creator_id': creatorId,
        'category': category,
        'is_private': isPrivate,
        'member_count': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();

      final clubId = response['id'] as String;
      AppLogger().debug('✅ Debate club created: $clubId');

      // Add creator as admin
      await createMembership(
        clubId: clubId,
        userId: creatorId,
        role: 'admin',
      );

      return clubId;
    } catch (e) {
      AppLogger().debug('❌ Create debate club failed: $e');
      rethrow;
    }
  }

  /// Delete debate club
  Future<void> deleteDebateClub(String clubId) async {
    try {
      AppLogger().debug('🗑️ Deleting debate club: $clubId');

      await client.from('debate_clubs').delete().eq('id', clubId);

      AppLogger().debug('✅ Debate club deleted');
    } catch (e) {
      AppLogger().debug('❌ Delete debate club failed: $e');
      rethrow;
    }
  }

  /// Create club membership
  Future<void> createMembership({
    required String clubId,
    required String userId,
    String role = 'member',
  }) async {
    try {
      AppLogger().debug('➕ Creating membership: $clubId for user $userId');

      await client.from('club_memberships').insert({
        'club_id': clubId,
        'user_id': userId,
        'role': role,
        'status': 'active',
        'joined_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      AppLogger().debug('✅ Membership created');
    } catch (e) {
      AppLogger().debug('❌ Create membership failed: $e');
      rethrow;
    }
  }

  /// Delete club membership
  Future<void> deleteMembership({
    required String clubId,
    required String userId,
  }) async {
    try {
      AppLogger().debug('➖ Deleting membership: $clubId for user $userId');

      await client
          .from('club_memberships')
          .delete()
          .eq('club_id', clubId)
          .eq('user_id', userId);

      AppLogger().debug('✅ Membership deleted');
    } catch (e) {
      AppLogger().debug('❌ Delete membership failed: $e');
      rethrow;
    }
  }

  /// Update membership role
  Future<void> updateMembershipRole({
    required String clubId,
    required String userId,
    required String role,
  }) async {
    try {
      AppLogger().debug('🔄 Updating membership role: $role');

      await client
          .from('club_memberships')
          .update({
            'role': role,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('club_id', clubId)
          .eq('user_id', userId);

      AppLogger().debug('✅ Membership role updated');
    } catch (e) {
      AppLogger().debug('❌ Update membership role failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // PLAYBACK & RECORDING
  // ============================================================================

  /// Get available playbacks
  Future<List<Map<String, dynamic>>> getAvailablePlaybacks({
    int limit = 50,
    int offset = 0,
    String? category,
    String? userId,
  }) async {
    try {
      AppLogger().debug('📹 Getting available playbacks (limit: $limit, offset: $offset, userId: $userId)');

      // Build query with filters BEFORE order() and range()
      dynamic query = client
          .from('arena_playbacks')
          .select('*, arena_rooms(*)')
          .eq('status', 'available');

      // Apply optional filters before transforms
      if (category != null) {
        query = query.eq('category', category);
      }

      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      // Apply transforms (order and range) last
      query = query.order('created_at', ascending: false);
      query = query.range(offset, offset + limit - 1);

      final response = await query;

      AppLogger().debug('✅ Found ${(response as List).length} playbacks');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger().debug('❌ Get available playbacks failed: $e');
      return [];
    }
  }

  /// Get playback by ID
  Future<Map<String, dynamic>?> getPlayback(String playbackId) async {
    try {
      AppLogger().debug('📹 Getting playback: $playbackId');

      final response = await client
          .from('arena_playbacks')
          .select('*, arena_rooms(*)')
          .eq('id', playbackId)
          .maybeSingle();

      AppLogger().debug('✅ Playback retrieved');
      return response;
    } catch (e) {
      AppLogger().debug('❌ Get playback failed: $e');
      return null;
    }
  }

  /// Get playbacks by room ID
  Future<List<Map<String, dynamic>>> getPlaybacksByRoomId(String roomId) async {
    try {
      AppLogger().debug('📹 Getting playbacks for room: $roomId');

      final response = await client
          .from('arena_playbacks')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: false);

      AppLogger().debug('✅ Found ${(response as List).length} playbacks');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger().debug('❌ Get playbacks by room failed: $e');
      return [];
    }
  }

  /// Increment playback view count
  Future<void> incrementPlaybackViewCount(String playbackId) async {
    try {
      AppLogger().debug('👁️ Incrementing view count: $playbackId');

      // Use raw SQL to increment atomically
      await client.rpc('increment_playback_views', params: {
        'playback_id': playbackId,
      });

      AppLogger().debug('✅ View count incremented');
    } catch (e) {
      // Fallback to manual increment if function doesn't exist
      try {
        final playback = await getPlayback(playbackId);
        if (playback != null) {
          final currentViews = playback['view_count'] ?? 0;
          await client.from('arena_playbacks').update({
            'view_count': currentViews + 1,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', playbackId);
        }
      } catch (e2) {
        AppLogger().debug('❌ Increment view count failed: $e2');
      }
    }
  }

  /// Record playback event
  Future<void> recordPlaybackEvent({
    required String playbackId,
    required String userId,
    required String eventType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      AppLogger().debug('📊 Recording playback event: $eventType');

      await client.from('playback_events').insert({
        'playback_id': playbackId,
        'user_id': userId,
        'event_type': eventType,
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });

      AppLogger().debug('✅ Playback event recorded');
    } catch (e) {
      AppLogger().debug('❌ Record playback event failed: $e');
    }
  }

  /// Stop arena recording
  Future<void> stopArenaRecording(String roomId) async {
    try {
      AppLogger().debug('⏹️ Stopping arena recording: $roomId');

      await client
          .from('arena_rooms')
          .update({
            'is_recording': false,
            'recording_stopped_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', roomId);

      AppLogger().debug('✅ Arena recording stopped');
    } catch (e) {
      AppLogger().debug('❌ Stop arena recording failed: $e');
      rethrow;
    }
  }

  /// Create timeline segment
  Future<void> createTimelineSegment({
    required String playbackId,
    required String label,
    required int startTime,
    required int endTime,
    String? description,
  }) async {
    try {
      AppLogger().debug('⏱️ Creating timeline segment: $label');

      await client.from('playback_timeline_segments').insert({
        'playback_id': playbackId,
        'label': label,
        'start_time': startTime,
        'end_time': endTime,
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
      });

      AppLogger().debug('✅ Timeline segment created');
    } catch (e) {
      AppLogger().debug('❌ Create timeline segment failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // USER SEARCH & SOCIAL
  // ============================================================================

  /// Search users by username
  Future<List<Map<String, dynamic>>> searchUsersByUsername(
    String username, {
    int limit = 20,
  }) async {
    try {
      AppLogger().debug('🔍 Searching users by username: $username');

      final response = await client
          .from('users')
          .select()
          .ilike('name', '%$username%')
          .limit(limit);

      AppLogger().debug('✅ Found ${(response as List).length} users');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger().debug('❌ Search users failed: $e');
      return [];
    }
  }

  /// Get user followers
  Future<List<Map<String, dynamic>>> getUserFollowers(String userId) async {
    try {
      AppLogger().debug('👥 Getting followers for user: $userId');

      final response = await client
          .from('user_follows')
          .select('*, follower:users!follower_id(*)')
          .eq('followed_id', userId)
          .eq('status', 'active');

      AppLogger().debug('✅ Found ${(response as List).length} followers');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger().debug('❌ Get followers failed: $e');
      return [];
    }
  }

  /// Get follow notifications
  Future<List<Map<String, dynamic>>> getFollowNotifications(String userId) async {
    try {
      AppLogger().debug('🔔 Getting follow notifications for user: $userId');

      final response = await client
          .from('follow_notifications')
          .select('*, users(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      AppLogger().debug('✅ Found ${(response as List).length} notifications');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger().debug('❌ Get follow notifications failed: $e');
      return [];
    }
  }

  /// Get unread follow notification count
  Future<int> getUnreadFollowNotificationCount(String userId) async {
    try {
      final response = await client
          .from('follow_notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      AppLogger().debug('❌ Get unread count failed: $e');
      return 0;
    }
  }

  /// Mark follow notification as read
  Future<void> markFollowNotificationAsRead(String notificationId) async {
    try {
      await client.from('follow_notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', notificationId);

      AppLogger().debug('✅ Notification marked as read');
    } catch (e) {
      AppLogger().debug('❌ Mark notification as read failed: $e');
    }
  }

  /// Create ping request
  Future<void> createPingRequest({
    required String fromUserId,
    required String toUserId,
    required String roleType,
    required String debateTitle,
    String? debateDescription,
    String? message,
  }) async {
    try {
      AppLogger().debug('📢 Creating ping request from $fromUserId to $toUserId');

      await client.from('ping_requests').insert({
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'role_type': roleType,
        'debate_title': debateTitle,
        'debate_description': debateDescription,
        'message': message,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      AppLogger().debug('✅ Ping request created');
    } catch (e) {
      AppLogger().debug('❌ Create ping request failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // VALIDATION & UTILITIES
  // ============================================================================

  /// Get debate discussion rooms paginated
  Future<List<Map<String, dynamic>>> getDebateDiscussionRoomsPaginated({
    int page = 0,
    int pageSize = 20,
    String? status,
    String? category,
  }) async {
    try {
      AppLogger().debug('📄 Getting debate discussion rooms (page $page)');

      // Build query with filters BEFORE order() and range()
      dynamic query = client
          .from('debate_discussion_rooms')
          .select('*, users!creator_id(*)');

      // Apply optional filters before transforms
      if (status != null) {
        query = query.eq('status', status);
      }

      if (category != null) {
        query = query.eq('category', category);
      }

      // Apply transforms (order and range) last
      query = query.order('created_at', ascending: false);
      query = query.range(page * pageSize, (page + 1) * pageSize - 1);

      final response = await query;

      AppLogger().debug('✅ Found ${(response as List).length} rooms');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger().debug('❌ Get rooms paginated failed: $e');
      return [];
    }
  }

  /// Create scheduled arena room
  Future<String> createScheduledArenaRoom({
    required String title,
    required String topic,
    required String challengerId,
    required String challengedId,
    required DateTime scheduledTime,
    String? description,
    int? durationMinutes,
  }) async {
    try {
      AppLogger().debug('📅 Creating scheduled arena room: $title');

      final response = await client.from('arena_rooms').insert({
        'title': title,
        'topic': topic,
        'description': description,
        'challenger_id': challengerId,
        'challenged_id': challengedId,
        'status': 'pending',
        'room_type': 'arena',
        'scheduled_time': scheduledTime.toIso8601String(),
        'duration_minutes': durationMinutes ?? 30,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();

      final roomId = response['id'] as String;
      AppLogger().debug('✅ Scheduled arena room created: $roomId');

      return roomId;
    } catch (e) {
      AppLogger().debug('❌ Create scheduled arena room failed: $e');
      rethrow;
    }
  }

  /// Create manual arena room
  Future<String> createManualArenaRoom({
    required String title,
    required String topic,
    required String challengerId,
    String? description,
    int? durationMinutes,
  }) async {
    try {
      AppLogger().debug('🎯 Creating manual arena room: $title');

      final response = await client.from('arena_rooms').insert({
        'title': title,
        'topic': topic,
        'description': description,
        'challenger_id': challengerId,
        'challenged_id': null, // Manual room, no specific opponent
        'status': 'pending',
        'room_type': 'arena',
        'duration_minutes': durationMinutes ?? 30,
        'created_by': challengerId, // Set room creator for moderator lookup
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();

      final roomId = response['id'] as String;
      AppLogger().debug('✅ Manual arena room created: $roomId');

      // Add creator as participant (moderator)
      await joinArenaRoom(
        roomId: roomId,
        userId: challengerId,
        role: 'moderator',
      );

      return roomId;
    } catch (e) {
      AppLogger().debug('❌ Create manual arena room failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // FUNCTIONS & STORAGE GETTERS (for compatibility)
  // ============================================================================

  /// Get functions client (Edge Functions)
  /// Note: Supabase uses client.functions instead of a separate getter
  dynamic get functions => client.functions;

  /// Get storage client
  /// Note: Supabase uses client.storage instead of a separate getter
  dynamic get storage => client.storage;
}
