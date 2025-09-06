import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:appwrite/enums.dart';
import 'package:flutter/foundation.dart';
import '../constants/appwrite.dart';
import 'dart:convert';
import '../models/user_profile.dart';
import '../models/gift_transaction.dart';
import '../core/logging/app_logger.dart';
import 'firebase_arena_timer_service.dart';
import 'network_resilience_service.dart';
import 'offline_data_cache.dart';
import 'package:get_it/get_it.dart';

class AppwriteService {
  static final AppwriteService _instance = AppwriteService._internal();
  
  late final Client client;
  late final Account account;
  late final Databases databases;
  late final Storage storage;
  late final Realtime realtime;
  late final Functions functions;
  
  // Global room creation lock to prevent any simultaneous room creation by same user
  static final Map<String, bool> _roomCreationLocks = {};

  factory AppwriteService() {
    return _instance;
  }

  AppwriteService._internal() {
    client = Client()
      ..setEndpoint(AppwriteConstants.endpoint)
      ..setProject(AppwriteConstants.projectId);
    
    // Only set self-signed for local development endpoints
    // Since we're using cloud.appwrite.io, we don't need this
    // ..setSelfSigned(status: true); // Remove in production

    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
    realtime = Realtime(client);
    functions = Functions(client);
    
    // Log initialization for debugging
    AppLogger().debug('🚀 AppwriteService initialized with endpoint: ${AppwriteConstants.endpoint}');
    AppLogger().debug('🚀 Project ID: ${AppwriteConstants.projectId}');
  }

  // Getter for realtime access
  Realtime get realtimeInstance => realtime;
  
  // Getter for network resilience service
  NetworkResilienceService get _networkService => GetIt.instance<NetworkResilienceService>();
  
  // Getter for offline services
  OfflineDataCache get _cache => GetIt.instance<OfflineDataCache>();

  // Helper method for Chrome/browser detection and debugging
  String _getBrowserInfo() {
    if (!kIsWeb) return "Mobile/Desktop App";
    
    try {
      // Try to get user agent information using JS interop fallback
      if (kDebugMode) {
        return "Web Debug Mode";
      } else {
        return "Web Release Mode";
      }
    } catch (e) {
      return "Web (Unknown Browser)";
    }
  }

  void _logChromeSpecificDebugInfo() {
    if (kIsWeb) {
      AppLogger().debug('=== CHROME/BROWSER DEBUG INFO ===');
      AppLogger().debug('Browser: ${_getBrowserInfo()}');
      AppLogger().debug('Is Web Platform: $kIsWeb');
      AppLogger().debug('Is Debug Mode: $kDebugMode');
      AppLogger().debug('=== END BROWSER DEBUG INFO ===');
    }
  }

  /// Simplified debug method to test Appwrite connectivity
  Future<void> debugAppwriteConnection() async {
    AppLogger().debug('🧪 DEBUGGING APPWRITE CONNECTION');
    AppLogger().debug('   Endpoint: ${client.endPoint}');
    AppLogger().debug('   Project: ${AppwriteConstants.projectId}');
    
    try {
      AppLogger().debug('   Testing simple health check...');
      
      // Test the most basic operation first - just the SDK connection
      AppLogger().debug('   About to call account.get() with 5-second timeout');
      final stopwatch = Stopwatch()..start();
      
      final user = await account.get().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          final elapsed = stopwatch.elapsedMilliseconds;
          AppLogger().debug('   ⏰ TIMEOUT after ${elapsed}ms (expected 5000ms)');
          throw Exception('Connection timeout - SDK not responding');
        },
      );
      
      stopwatch.stop();
      AppLogger().debug('   ✅ Success! Got response in ${stopwatch.elapsedMilliseconds}ms');
      AppLogger().debug('   User: ${user.name} (${user.email})');
      
    } catch (e) {
      AppLogger().debug('   ❌ Connection test failed: $e');
      AppLogger().debug('   Error type: ${e.runtimeType}');
      
      // Try to get more details about what's failing
      if (e.toString().contains('timeout')) {
        AppLogger().debug('   🔍 This is a timeout issue - SDK call is hanging');
        AppLogger().debug('   🔍 Possible causes:');
        AppLogger().debug('      - Network connectivity issues');
        AppLogger().debug('      - Appwrite Cloud service down');
        AppLogger().debug('      - SDK configuration error');
        AppLogger().debug('      - Local firewall/proxy blocking requests');
      } else if (e.toString().contains('unauthorized') || e.toString().contains('scope')) {
        AppLogger().debug('   🔍 This is an authentication issue - user not logged in (expected)');
      } else {
        AppLogger().debug('   🔍 Unexpected error - investigating...');
      }
    }
  }

  /// Test method specifically for debugging Chrome user profile loading issues
  /// This method provides comprehensive debugging for troubleshooting
  Future<void> debugUserProfileLoading(String userId) async {
    AppLogger().debug('🔍 DEBUG: Starting comprehensive user profile loading test');
    AppLogger().debug('🔍 Target User ID: $userId');
    
    // Test basic connectivity first
    AppLogger().debug('🔍 Step 1: Testing Appwrite connectivity...');
    await debugAppwriteConnection();
    
    // Test authentication
    AppLogger().debug('🔍 Step 2: Testing authentication...');
    final currentUser = await getCurrentUser();
    
    // Test user profile loading  
    AppLogger().debug('🔍 Step 3: Testing user profile loading...');
    final userProfile = await getUserProfile(userId);
    
    // Summary
    AppLogger().debug('🔍 DEBUG SUMMARY:');
    AppLogger().debug('  - Authentication: ${currentUser != null ? "SUCCESS" : "FAILED"}');
    AppLogger().debug('  - Profile Loading: ${userProfile != null ? "SUCCESS" : "FAILED"}');
    if (currentUser != null) {
      AppLogger().debug('  - Current User ID: ${currentUser.$id}');
      AppLogger().debug('  - Matches Target: ${currentUser.$id == userId}');
    }
    if (userProfile != null) {
      AppLogger().debug('  - Profile Name: ${userProfile.name}');
      AppLogger().debug('  - Profile Email: ${userProfile.email}');
    }
    AppLogger().debug('🔍 DEBUG TEST COMPLETE');
  }

  // Network resilience wrapper methods
  
  /// Executes database operations with circuit breaker and adaptive timeouts
  Future<T> _executeWithResilience<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    return await _networkService.executeWithCircuitBreaker(
      operationName,
      () async {
        final timeout = _networkService.getAdaptiveTimeout();
        return await operation().timeout(timeout);
      },
    );
  }

  /// Executes database operations with retry logic for poor connections  
  Future<T> _executeWithRetry<T>(
    String operationName,
    Future<T> Function() operation, {
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await _executeWithResilience(operationName, operation);
      } catch (e) {
        attempts++;
        
        if (attempts >= maxRetries) {
          rethrow;
        }
        
        // Wait before retry with network-aware delay
        final delay = _networkService.getRetryDelay(attempts);
        AppLogger().warning('🔄 $operationName failed (attempt $attempts), retrying in ${delay.inSeconds}s: $e');
        await Future.delayed(delay);
      }
    }
    
    throw Exception('Max retries exceeded for $operationName');
  }

  // Auth Methods
  Future<models.User> createAccount({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      AppLogger().debug('🔐 Creating account for email: $email');
      
      // First, ensure no existing session conflicts
      try {
        await account.deleteSession(sessionId: 'current');
        AppLogger().debug('🔐 Cleared existing session before account creation');
      } catch (e) {
        AppLogger().debug('🔐 No existing session to clear (expected)');
      }
      
      final user = await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          AppLogger().debug('🔐 ⏰ Account creation timeout after 15 seconds');
          throw Exception('Account creation timed out after 15 seconds');
        },
      );
      
      AppLogger().debug('🔐 ✅ Account created successfully for: $email');
      AppLogger().debug('🔐    - User ID: ${user.$id}');
      AppLogger().debug('🔐    - User Name: ${user.name}');
      return user;
    } catch (e) {
      AppLogger().debug('🔐 ❌ Error creating account for $email:');
      AppLogger().debug('🔐    - Error type: ${e.runtimeType}');
      AppLogger().debug('🔐    - Error message: $e');
      
      // Provide more specific error messages
      if (e.toString().contains('user_already_exists')) {
        throw Exception('An account with this email already exists');
      } else if (e.toString().contains('password')) {
        throw Exception('Password does not meet requirements');
      } else if (e.toString().contains('email')) {
        throw Exception('Please enter a valid email address');
      } else if (e.toString().contains('timeout')) {
        throw Exception('Network timeout - please check your connection and try again');
      } else {
        throw Exception('Failed to create account: ${e.toString()}');
      }
    }
  }

  Future<models.Session> signIn({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger().debug('🔐 Starting signIn for: $email');
      
      final session = await _executeWithRetry(
        'signIn',
        () async {
          try {
            // Try to create session normally
            return await account.createEmailPasswordSession(
              email: email,
              password: password,
            );
          } catch (e) {
            // If there's already an active session, sign out first then retry
            if (e.toString().contains('user_session_already_exists')) {
              AppLogger().debug('🔐 Active session detected, signing out first...');
              try {
                await account.deleteSession(sessionId: 'current');
                AppLogger().debug('🔐 Previous session cleared, retrying login...');
              } catch (signOutError) {
                AppLogger().debug('🔐 Error clearing session (continuing): $signOutError');
              }
              
              // Retry session creation after clearing
              return await account.createEmailPasswordSession(
                email: email,
                password: password,
              );
            } else {
              // Re-throw other errors
              rethrow;
            }
          }
        },
      );
      
      AppLogger().debug('🔐 ✅ signIn successful for: $email');
      return session;
    } catch (e) {
      AppLogger().debug('🔐 ❌ Error signing in: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      // Try to delete the current session
      await account.deleteSession(sessionId: 'current');
      AppLogger().info('Successfully signed out');
    } catch (e) {
      AppLogger().warning('Error during sign out: $e');
      
      // If the error is due to missing scope (user already in guest state), that's fine
      if (e.toString().contains('general_unauthorized_scope') || 
          e.toString().contains('missing scope') ||
          e.toString().contains('user_unauthorized')) {
        AppLogger().info('User was already signed out (guest state)');
        return; // Don't rethrow for guest state errors
      }
      
      // For other errors, still complete the logout process locally
      AppLogger().warning('Continuing with local logout despite error');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await account.createRecovery(
        email: email,
        url: '${AppwriteConstants.endpoint}/password-reset', // This should be your app's reset URL
      );
      AppLogger().info('Password reset email sent to: $email');
    } catch (e) {
      AppLogger().error('Error sending password reset email: $e');
      rethrow;
    }
  }

  // Google OAuth Sign-In
  Future<models.Session> signInWithGoogle() async {
    try {
      AppLogger().debug('🔐 Starting Google OAuth sign-in');
      
      final session = await account.createOAuth2Session(
        provider: OAuthProvider.google,
      );
      
      AppLogger().debug('🔐 ✅ Google OAuth successful');
      return session;
    } catch (e) {
      AppLogger().debug('🔐 ❌ Error with Google OAuth: $e');
      rethrow;
    }
  }

  // User Methods
  Future<models.User?> getCurrentUser() async {
    AppLogger().debug('🔐 getCurrentUser - checking authentication status');
    
    try {
      final user = await account.get().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          AppLogger().debug('🔐 ⏰ getCurrentUser timeout after 8 seconds');
          throw Exception('getCurrentUser timed out');
        },
      );
      
      AppLogger().debug('🔐 ✅ getCurrentUser SUCCESS');
      AppLogger().debug('🔐 User: ${user.name} (${user.email})');
      return user;
      
    } catch (e) {
      if (e.toString().contains('general_unauthorized_scope') || 
          e.toString().contains('missing scope') ||
          e.toString().contains('user_unauthorized')) {
        AppLogger().debug('🔐 User not authenticated (guest mode)');
      } else {
        AppLogger().debug('🔐 ❌ getCurrentUser ERROR: $e');
      }
      return null;
    }
  }

  // Database Methods
  Future<void> createUserProfile({
    required String userId,
    required String name,
    required String email,
    String? bio,
    String? avatar,
    String? location,
    String? website,
    String? xHandle,
    String? linkedinHandle,
    String? youtubeHandle,
    String? facebookHandle,
    String? instagramHandle,
    List<String>? interests,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final profileData = {
        'name': name,
        'email': email,
        'bio': bio,
        'avatar': avatar,
        'location': location,
        'website': website,
        'xHandle': xHandle,
        'linkedinHandle': linkedinHandle,
        'youtubeHandle': youtubeHandle,
        'facebookHandle': facebookHandle,
        'instagramHandle': instagramHandle,
        'preferences': '{}',
        'reputation': 0,
        'totalDebates': 0,
        'totalWins': 0,
        'totalRoomsCreated': 0,
        'totalRoomsJoined': 0,
        'coinBalance': 100, // Start new users with 100 coins
        'totalGiftsSent': 0,
        'totalGiftsReceived': 0,
        'interests': interests ?? [],
        'joinedClubs': [],
        'isVerified': false,
        'isPublicProfile': true,
        'isAvailableAsModerator': false,
        'isAvailableAsJudge': false,
      };
      
      // Add metadata if provided (for TOS/Privacy acceptance tracking)
      if (metadata != null) {
        profileData.addAll(metadata);
      }

      // First, try to check if user profile already exists
      try {
        await databases.getDocument(
          databaseId: 'arena_db',
          collectionId: 'users',
          documentId: userId,
        );
        
        // If we get here, document exists, so update it
        AppLogger().debug('User profile already exists, updating: $userId');
        await databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'users',
          documentId: userId,
          data: profileData,
        );
      } catch (e) {
        // Document doesn't exist, create it
        AppLogger().debug('User profile does not exist, creating: $userId');
        try {
          await databases.createDocument(
            databaseId: 'arena_db',
            collectionId: 'users',
            documentId: userId,
            data: profileData,
          );
          AppLogger().debug('✅ Successfully created user profile: $userId');
        } catch (createError) {
          AppLogger().error('❌ Failed to create user profile: $userId');
          AppLogger().error('Create error details: $createError');
          
          // If document already exists, try to update it instead
          if (createError.toString().contains('document_already_exists') || 
              createError.toString().contains('Document with the requested ID already exists')) {
            AppLogger().warning('🔄 Document exists, attempting update instead for: $userId');
            try {
              await databases.updateDocument(
                databaseId: 'arena_db',
                collectionId: 'users',
                documentId: userId,
                data: profileData,
              );
              AppLogger().debug('✅ Successfully updated existing profile: $userId');
            } catch (updateError) {
              AppLogger().error('❌ Failed to update existing profile: $userId');
              AppLogger().error('Update error: $updateError');
              rethrow;
            }
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      AppLogger().debug('Error creating/updating user profile: $e');
      rethrow;
    }
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    // FORCE BYPASS ALL CIRCUIT BREAKERS FOR DEBUGGING
    AppLogger().error('🚨 FORCE DEBUGGING: getUserProfile called with userId: $userId');
    AppLogger().error('🚨 This will bypass ALL error handling to find the null type error');
    
    // Debug: Log method entry with platform information
    AppLogger().debug('========== getUserProfile START ==========');
    AppLogger().debug('getUserProfile called with userId: $userId');
    AppLogger().debug('Platform: ${_getBrowserInfo()}');
    
    // Log Chrome-specific debugging info
    _logChromeSpecificDebugInfo();
    
    // Check cache first
    try {
      final cachedProfile = await _cache.getCachedUserProfile(userId);
      if (cachedProfile != null) {
        AppLogger().debug('📦 Using cached user profile for: $userId');
        return UserProfile.fromMap(cachedProfile);
      }
    } catch (e) {
      AppLogger().warning('📦 Cache read failed, fetching from server: $e');
    }
    
    try {
      AppLogger().debug('Attempting to fetch user profile from database...');
      AppLogger().debug('Database ID: arena_db, Collection ID: users, Document ID: $userId');
      
      // Temporarily bypass circuit breaker for debugging
      AppLogger().debug('🔧 DEBUGGING: Bypassing circuit breaker for getUserProfile');
      late final models.Document response;
      try {
        response = await databases.getDocument(
          databaseId: 'arena_db',
          collectionId: 'users',
          documentId: userId,
        );
        AppLogger().debug('✅ Direct database call succeeded');
      } catch (e) {
        AppLogger().error('❌ Direct database call failed: $e');
        rethrow;
      }
      
      AppLogger().debug('Raw response received from Appwrite:');
      AppLogger().debug('Response ID: ${response.$id}');
      AppLogger().debug('Response createdAt: ${response.$createdAt}');
      AppLogger().debug('Response updatedAt: ${response.$updatedAt}');
      AppLogger().debug('Response data keys: ${response.data.keys.toList()}');
      AppLogger().debug('Response data values preview: ${response.data.toString().length > 500 ? '${response.data.toString().substring(0, 500)}...' : response.data.toString()}');
      
      Map<String, dynamic> profileData;
      try {
        profileData = _safeDocumentToMap(response);
        AppLogger().debug('Profile data after safe conversion - keys: ${profileData.keys.toList()}');
      } catch (e, stackTrace) {
        AppLogger().error('Error in _safeDocumentToMap: $e');
        AppLogger().error('Stack trace: $stackTrace');
        rethrow;
      }
      
      AppLogger().debug('About to create UserProfile from map...');
      
      UserProfile userProfile;
      try {
        userProfile = UserProfile.fromMap(profileData);
      } catch (e, stackTrace) {
        AppLogger().error('Error in UserProfile.fromMap: $e');
        AppLogger().error('Profile data causing error: $profileData');
        AppLogger().error('Stack trace: $stackTrace');
        rethrow;
      }
      AppLogger().debug('UserProfile successfully created:');
      AppLogger().debug('  - ID: ${userProfile.id}');
      AppLogger().debug('  - Name: ${userProfile.name}');
      AppLogger().debug('  - Email: ${userProfile.email}');
      AppLogger().debug('  - Avatar: ${userProfile.avatar}');
      AppLogger().debug('  - Created at: ${userProfile.createdAt}');
      
      // Cache the profile for offline access
      try {
        await _cache.cacheUserProfile(userId, profileData);
        AppLogger().debug('📦 Cached user profile for: $userId');
      } catch (e) {
        AppLogger().warning('📦 Failed to cache user profile: $e');
      }
      
      AppLogger().debug('========== getUserProfile SUCCESS ==========');
      return userProfile;
    } catch (e, stackTrace) {
      AppLogger().debug('ERROR in getUserProfile for userId: $userId');
      AppLogger().debug('Error type: ${e.runtimeType}');
      AppLogger().debug('Error message: $e');
      AppLogger().debug('Stack trace: $stackTrace');
      
      // Additional Chrome/Web-specific debugging
      if (kIsWeb) {
        AppLogger().debug('Web-specific error analysis:');
        AppLogger().debug('  - This error occurred on web platform');
        AppLogger().debug('  - Check browser console for additional network errors');
        AppLogger().debug('  - Verify CORS settings if this is a network-related error');
        
        if (e.toString().contains('NetworkException') || e.toString().contains('XMLHttpRequest')) {
          AppLogger().debug('  - NETWORK ERROR detected - this could be Chrome-specific');
          AppLogger().debug('  - Check if Chrome is blocking the request due to CORS or security policies');
        }
        
        if (e.toString().contains('permission') || e.toString().contains('unauthorized')) {
          AppLogger().debug('  - PERMISSION ERROR detected - check authentication state');
          AppLogger().debug('  - Verify that the user session is valid in Chrome');
        }
      }
      
      AppLogger().debug('========== getUserProfile FAILED ==========');
      return null;
    }
  }

  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? bio,
    String? avatar,
    String? location,
    String? website,
    String? xHandle,
    String? linkedinHandle,
    String? youtubeHandle,
    String? facebookHandle,
    String? instagramHandle,
    List<String>? interests,
    bool? isPublicProfile,
    bool? isAvailableAsModerator,
    bool? isAvailableAsJudge,
    int? coinBalance,
    int? totalGiftsSent,
    int? totalGiftsReceived,
    // Note: reputation is now reputationPercentage and managed by ModeratorReputationService only
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (name != null) updateData['name'] = name;
      if (bio != null) updateData['bio'] = bio;
      if (avatar != null) updateData['avatar'] = avatar;
      if (location != null) updateData['location'] = location;
      if (website != null) updateData['website'] = website;
      if (xHandle != null) updateData['xHandle'] = xHandle;
      if (linkedinHandle != null) updateData['linkedinHandle'] = linkedinHandle;
      if (youtubeHandle != null) updateData['youtubeHandle'] = youtubeHandle;
      if (facebookHandle != null) updateData['facebookHandle'] = facebookHandle;
      if (instagramHandle != null) updateData['instagramHandle'] = instagramHandle;
      if (interests != null) updateData['interests'] = interests;
      if (isPublicProfile != null) updateData['isPublicProfile'] = isPublicProfile;
      if (isAvailableAsModerator != null) updateData['isAvailableAsModerator'] = isAvailableAsModerator;
      if (isAvailableAsJudge != null) updateData['isAvailableAsJudge'] = isAvailableAsJudge;
      if (coinBalance != null) updateData['coinBalance'] = coinBalance;
      if (totalGiftsSent != null) updateData['totalGiftsSent'] = totalGiftsSent;
      if (totalGiftsReceived != null) updateData['totalGiftsReceived'] = totalGiftsReceived;

      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: updateData,
      );
    } catch (e) {
      AppLogger().debug('Error updating user profile: $e');
      rethrow;
    }
  }

  Future<void> updateUserStats({
    required String userId,
    int? reputation,
    int? totalDebates,
    int? totalWins,
    int? totalRoomsCreated,
    int? totalRoomsJoined,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (reputation != null) updateData['reputation'] = reputation;
      if (totalDebates != null) updateData['totalDebates'] = totalDebates;
      if (totalWins != null) updateData['totalWins'] = totalWins;
      if (totalRoomsCreated != null) updateData['totalRoomsCreated'] = totalRoomsCreated;
      if (totalRoomsJoined != null) updateData['totalRoomsJoined'] = totalRoomsJoined;

      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: updateData,
      );
    } catch (e) {
      AppLogger().debug('Error updating user stats: $e');
      rethrow;
    }
  }

  Future<String?> uploadAvatar({
    required String userId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      // Use Appwrite's built-in unique ID generator (max 36 chars)
      final file = await storage.createFile(
        bucketId: 'avatars',
        fileId: ID.unique(), // This ensures a valid, unique ID within Appwrite's limits
        file: InputFile.fromBytes(
          bytes: fileBytes,
          filename: fileName,
        ),
      );

      // Get the file URL
      final fileUrl = '${AppwriteConstants.endpoint}/storage/buckets/avatars/files/${file.$id}/view?project=${AppwriteConstants.projectId}';
      
      // Update user profile with new avatar URL
      await updateUserProfile(
        userId: userId,
        avatar: fileUrl,
      );

      return fileUrl;
    } catch (e) {
      AppLogger().debug('Error uploading avatar: $e');
      rethrow;
    }
  }

  Future<void> deleteAvatar(String userId) async {
    try {
      // Delete the file from storage
      await storage.deleteFile(
        bucketId: 'avatars',
        fileId: 'avatar_$userId',
      );

      // Remove avatar URL from user profile
      await updateUserProfile(
        userId: userId,
        avatar: null,
      );
    } catch (e) {
      AppLogger().debug('Error deleting avatar: $e');
      rethrow;
    }
  }

  // Debate Club methods
  Future<void> createDebateClub({
    required String name,
    required String description,
    required String createdBy,
  }) async {
    try {
      // Create the club
      final clubResponse = await databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'debate_clubs',
        documentId: ID.unique(),
        data: {
          'name': name,
          'description': description,
          'createdBy': createdBy,
          'createdAt': DateTime.now().toIso8601String(), // Required custom field
        },
      );
      
      AppLogger().info('Created club with ID: ${clubResponse.$id}');
      
      // Automatically add the creator as a member with 'president' role
      try {
        await createMembership(
          userId: createdBy,
          clubId: clubResponse.$id,
          role: 'president',
        );
        AppLogger().info('Added creator as president member for club: ${clubResponse.$id}');
      } catch (membershipError) {
        AppLogger().error('Failed to add creator as member: $membershipError');
        // Try to delete the club if membership creation fails
        try {
          await databases.deleteDocument(
            databaseId: 'arena_db',
            collectionId: 'debate_clubs',
            documentId: clubResponse.$id,
          );
          AppLogger().debug('🧹 Cleaned up club due to membership failure');
        } catch (cleanupError) {
          AppLogger().warning('Could not cleanup club: $cleanupError');
        }
        throw Exception('Failed to create club membership: $membershipError');
      }
      
    } catch (e) {
      AppLogger().error('Error creating debate club: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getDebateClubs() async {
    try {
      final response = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'debate_clubs',
        queries: [
          Query.orderDesc('\$createdAt'),
        ],
      );
      
      return response.documents.map((doc) => _safeDocumentToMap(doc)).toList();
    } catch (e) {
      AppLogger().debug('Error getting debate clubs: $e');
      rethrow;
    }
  }

  Future<void> joinDebateClub({
    required String clubId,
    required String userId,
    required String username,
  }) async {
    try {
      final doc = await databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'debate_clubs',
        documentId: clubId,
      );

      Map<String, dynamic> members = Map<String, dynamic>.from(doc.data['members']);
      members[userId] = {
        'role': 'Member',
        'username': username,
        'joinedAt': DateTime.now().toIso8601String(),
      };

      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'debate_clubs',
        documentId: clubId,
        data: {'members': members},
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> leaveDebateClub({
    required String clubId,
    required String userId,
  }) async {
    try {
      final doc = await databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'debate_clubs',
        documentId: clubId,
      );

      Map<String, dynamic> members = Map<String, dynamic>.from(doc.data['members']);
      members.remove(userId);

      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'debate_clubs',
        documentId: clubId,
        data: {'members': members},
      );
    } catch (e) {
      rethrow;
    }
  }

  // Membership Methods
  Future<void> createMembership({
    required String userId,
    required String clubId,
    String role = 'member',
  }) async {
    try {
      await databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'memberships',
        documentId: ID.unique(),
        data: {
          'userId': userId,
          'clubId': clubId,
          'role': role,
          'joinedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      AppLogger().debug('Error creating membership: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserMemberships(String userId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'memberships',
        queries: [
          Query.equal('userId', userId),
        ],
      );
      
      return response.documents.map((doc) => _safeDocumentToMap(doc)).toList();
    } catch (e) {
      AppLogger().debug('Error getting user memberships: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getClubMembers(String clubId) async {
    try {
      AppLogger().debug('Loading members for club: $clubId');
      final response = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'memberships',
        queries: [
          Query.equal('clubId', clubId),
        ],
      );
      
      final members = response.documents.map((doc) {
        final memberData = Map<String, dynamic>.from(doc.data);
        memberData['id'] = doc.$id; // Add the document ID
        return memberData;
      }).toList().cast<Map<String, dynamic>>();
      
      AppLogger().debug('Found ${members.length} members for club $clubId');
      for (final member in members) {
        AppLogger().debug('Member: ${member['userId']} - Role: ${member['role']}');
      }
      
      return members;
    } catch (e) {
      AppLogger().debug('Error getting club members: $e');
      rethrow;
    }
  }

  Future<void> updateMembershipRole({
    required String membershipId,
    required String newRole,
  }) async {
    try {
      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'memberships',
        documentId: membershipId,
        data: {
          'role': newRole,
        },
      );
    } catch (e) {
      AppLogger().debug('Error updating membership role: $e');
      rethrow;
    }
  }

  Future<void> deleteMembership(String membershipId) async {
    try {
      await databases.deleteDocument(
        databaseId: 'arena_db',
        collectionId: 'memberships',
        documentId: membershipId,
      );
    } catch (e) {
      AppLogger().debug('Error deleting membership: $e');
      rethrow;
    }
  }

  // Room Methods
  Future<String> createRoom({
    required String title,
    required String description,
    required String createdBy,
    List<String>? tags,
    int maxParticipants = 999999, // Effectively unlimited
  }) async {
    try {
      final response = await _executeWithRetry(
        'createRoom',
        () => databases.createDocument(
          databaseId: 'arena_db',
          collectionId: AppwriteConstants.roomsCollection,
          documentId: ID.unique(),
          data: {
            'name': title,
            'description': description,
            'type': 'discussion',
            'status': 'active',
            'createdBy': createdBy,
            'isPublic': true,
            'maxParticipants': maxParticipants,
            'participants': [],
            'moderatorId': createdBy,
            'settings': '{}',
            'tags': tags ?? [],
            'isFeatured': false,
          },
        ),
      );

      // Create initial room participant entry for the creator as moderator
      await joinRoom(
        roomId: response.$id,
        userId: createdBy,
        role: 'moderator',
      );
      
      return response.$id;
    } catch (e) {
      AppLogger().error('Error creating room: $e');
      rethrow;
    }
  }

  Future<String> createDiscussionRoom({
    required String title,
    required String description,
    required String createdBy,
    required String status, // 'active', 'scheduled'
    required bool isPrivate,
    List<String>? tags,
    int maxParticipants = 999999,
  }) async {
    try {
      AppLogger().debug('🔥 createDiscussionRoom called with title: $title');
      AppLogger().debug('🔥 Using collection: ${AppwriteConstants.roomsCollection}');
      
      // Use discussion_rooms collection (Open Discussion rooms)
      final response = await databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.roomsCollection,
        documentId: ID.unique(),
        data: {
          'title': title,
          'description': description,
          'type': 'discussion',
          'status': status,
          'createdBy': createdBy,
          'moderatorId': createdBy,
          'isPublic': !isPrivate,
          'maxParticipants': maxParticipants,
          'participants': [],
          'settings': json.encode({
            'allowChat': true,
            'recordSession': false,
            'moderatorApproval': false,
          }),
          'tags': tags ?? [],
          'isFeatured': false,
        },
      );
      
      // Create initial participant entry for the creator as moderator
      await joinRoom(
        roomId: response.$id,
        userId: createdBy,
        role: 'moderator', // Creator becomes moderator of Open Discussion room
      );
      
      return response.$id;
    } catch (e) {
      AppLogger().debug('Error creating room: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getRooms() async {
    try {
      final response = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomsCollection,
        queries: [
          Query.equal('type', 'discussion'),
          Query.or([
            Query.equal('status', 'active'),
            Query.equal('status', 'scheduled'),
          ]),
          Query.limit(50),
          Query.orderDesc('\$createdAt'),
        ],
      );
      
      // For each room, get participant count
      List<Map<String, dynamic>> roomsWithParticipants = [];
      for (var doc in response.documents) {
        final roomData = Map<String, dynamic>.from(doc.data);
        roomData['id'] = doc.$id;
        roomData['createdAt'] = doc.$createdAt;
        
        // Map 'title' to 'name' for frontend compatibility 
        if (roomData.containsKey('title') && !roomData.containsKey('name')) {
          roomData['name'] = roomData['title'];
        }
        
        // Parse JSON strings to Maps for Room model compatibility
        if (roomData['settings'] is String) {
          try {
            roomData['settings'] = Map<String, dynamic>.from(
              json.decode(roomData['settings'])
            );
          } catch (e) {
            roomData['settings'] = <String, dynamic>{};
          }
        }
        
        if (roomData['sides'] is String && roomData['sides'] != null) {
          try {
            roomData['sides'] = Map<String, dynamic>.from(
              json.decode(roomData['sides'])
            );
          } catch (e) {
            roomData['sides'] = null;
          }
        }
        
        // Get participant count
        final participantsResponse = await databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: AppwriteConstants.roomParticipantsCollection,
          queries: [
            Query.equal('roomId', doc.$id),
            Query.equal('status', 'joined'),
          ],
        );
        
        roomData['participantCount'] = participantsResponse.documents.length;
        roomData['participants'] = participantsResponse.documents.map((p) => p.data['userId']).toList();
        
        // Get moderator profile for room card display
        try {
          final moderatorProfile = await getUserProfile(roomData['createdBy']);
          if (moderatorProfile != null) {
            roomData['moderatorProfile'] = {
              'name': moderatorProfile.name,
              'avatar': moderatorProfile.avatar,
              'email': moderatorProfile.email,
            };
          }
        } catch (e) {
          AppLogger().debug('Error getting moderator profile for room ${doc.$id}: $e');
          // Continue without moderator profile
        }
        
        roomsWithParticipants.add(roomData);
      }
      
      return roomsWithParticipants;
    } catch (e) {
      AppLogger().debug('Error getting rooms: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getRoom(String roomId) async {
    try {
      final response = await databases.getDocument(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomsCollection,
        documentId: roomId,
      );
      
      final roomData = Map<String, dynamic>.from(response.data);
      roomData['id'] = response.$id;
      roomData['createdAt'] = response.$createdAt;
      
      // Parse JSON strings to Maps for Room model compatibility
      if (roomData['settings'] is String) {
        try {
          roomData['settings'] = Map<String, dynamic>.from(
            json.decode(roomData['settings'])
          );
        } catch (e) {
          roomData['settings'] = <String, dynamic>{};
        }
      }
      
      if (roomData['sides'] is String && roomData['sides'] != null) {
        try {
          roomData['sides'] = Map<String, dynamic>.from(
            json.decode(roomData['sides'])
          );
        } catch (e) {
          roomData['sides'] = null;
        }
      }
      
      // Get participants
      final participantsResponse = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomParticipantsCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('status', 'joined'),
        ],
      );
      
      roomData['participantCount'] = participantsResponse.documents.length;
      roomData['participants'] = participantsResponse.documents.map((p) {
        final participantData = Map<String, dynamic>.from(p.data);
        participantData['id'] = p.$id; // Include document ID
        return participantData;
      }).toList();
      
      return roomData;
    } catch (e) {
      AppLogger().debug('Error getting room: $e');
      rethrow;
    }
  }

  /// Clean up duplicate entries for a user in an Open Discussion room
  Future<void> _cleanupOpenDiscussionParticipantDuplicates(String roomId, String userId) async {
    try {
      // Get ALL entries for this user in this room (active or not)
      final allEntries = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomParticipantsCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
        ],
      );
      
      // Delete all existing entries to ensure no duplicates
      for (var entry in allEntries.documents) {
        await databases.deleteDocument(
          databaseId: 'arena_db',
          collectionId: AppwriteConstants.roomParticipantsCollection,
          documentId: entry.$id,
        );
      }
      
      if (allEntries.documents.isNotEmpty) {
        AppLogger().debug('Cleaned up ${allEntries.documents.length} duplicate Open Discussion entries for user $userId in room $roomId');
      }
    } catch (e) {
      AppLogger().error('Error cleaning up Open Discussion participant duplicates: $e');
    }
  }

  Future<void> joinRoom({
    required String roomId,
    required String userId,
    String role = 'audience',
  }) async {
    try {
      AppLogger().debug('🏠 JOIN ROOM: Starting joinRoom process...');
      AppLogger().debug('🏠 JOIN ROOM: roomId=$roomId, userId=$userId, role=$role');
      AppLogger().debug('🏠 JOIN ROOM: Using collection=${AppwriteConstants.roomParticipantsCollection}');
      
      // First, clean up any existing entries for this user in this room to prevent duplicates
      AppLogger().debug('🧹 JOIN ROOM: Starting cleanup of duplicates...');
      await _cleanupOpenDiscussionParticipantDuplicates(roomId, userId);
      AppLogger().debug('🧹 JOIN ROOM: Cleanup completed');
      
      // Get user info for participant record
      AppLogger().debug('👤 JOIN ROOM: Getting current user info...');
      final user = await getCurrentUser();
      AppLogger().debug('👤 JOIN ROOM: User info - name: ${user?.name}, id: ${user?.$id}');
      
      final documentData = {
        'userId': userId,
        'roomId': roomId,
        'userName': user?.name ?? 'User',
        'userAvatar': user?.prefs.data['avatar'],
        'role': role, // Store role as-is (audience, moderator, speaker)
        'status': 'joined',
        'joinedAt': DateTime.now().toIso8601String(),
        'metadata': '{}',
      };
      
      AppLogger().debug('📄 JOIN ROOM: Document data prepared: $documentData');
      AppLogger().debug('💾 JOIN ROOM: Creating document in database...');
      
      final document = await databases.createDocument(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomParticipantsCollection,
        documentId: ID.unique(),
        data: documentData,
      );
      
      AppLogger().debug('✅ JOIN ROOM: Document created successfully! ID: ${document.$id}');
      AppLogger().debug('✅ JOIN ROOM: Final document data: ${document.data}');
      
    } catch (e) {
      AppLogger().debug('❌ JOIN ROOM ERROR: $e');
      AppLogger().debug('❌ JOIN ROOM ERROR TYPE: ${e.runtimeType}');
      AppLogger().debug('❌ JOIN ROOM ERROR STACK: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<void> _cleanupDebateDiscussionParticipantDuplicates(String roomId, String userId) async {
    try {
      // Get ALL entries for this user in this room (active or not)
      final allEntries = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.debateDiscussionParticipantsCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
        ],
      );
      
      // Delete all existing entries to ensure no duplicates
      for (var entry in allEntries.documents) {
        await databases.deleteDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.debateDiscussionParticipantsCollection,
          documentId: entry.$id,
        );
      }
      
      if (allEntries.documents.isNotEmpty) {
        AppLogger().debug('Cleaned up ${allEntries.documents.length} duplicate Debate Discussion entries for user $userId in room $roomId');
      }
    } catch (e) {
      AppLogger().debug('Error cleaning up participant duplicates: $e');
      // Don't rethrow - this is a cleanup operation
    }
  }

  /// Join a debate discussion room (uses debate_discussion_participants collection)
  Future<void> joinDebateDiscussionRoom({
    required String roomId,
    required String userId,
    String role = 'audience',
  }) async {
    try {
      AppLogger().debug('🚪 DEBUG: joinDebateDiscussionRoom called - roomId: $roomId, userId: $userId, role: $role');
      AppLogger().debug('🗂️ DEBUG: Target collection: ${AppwriteConstants.debateDiscussionParticipantsCollection}');
      
      // First, clean up any existing entries for this user in this room to prevent duplicates
      await _cleanupDebateDiscussionParticipantDuplicates(roomId, userId);
      
      // Get user info for participant record
      final user = await getCurrentUser();
      AppLogger().debug('👤 DEBUG: Current user: ${user?.name ?? 'User'}');
      
      // Ensure avatar is never null - default to empty string
      try {
        // Avatar URL retrieved but not used in current implementation
        user?.prefs.data['avatar'] ?? '';
      } catch (e) {
        AppLogger().debug('Warning: Could not get avatar from user prefs: $e');
      }
      
      final documentData = {
        'userId': userId,
        'roomId': roomId,
        'role': role, // Store role as-is (audience, moderator, speaker)
        'status': 'joined',
        'joinedAt': DateTime.now().toIso8601String(),
        'lastActiveAt': DateTime.now().toIso8601String(), // Required field for collection schema
      };
      
      AppLogger().debug('📄 DEBUG: Creating document with data: $documentData');
      
      try {
        final createdDoc = await databases.createDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.debateDiscussionParticipantsCollection,
          documentId: ID.unique(),
          data: documentData,
        );

        AppLogger().debug('✅ DEBUG: Document created successfully with ID: ${createdDoc.$id}');
        AppLogger().debug('User $userId joined debate discussion room $roomId with role $role');
      } catch (e) {
        AppLogger().error('❌ DETAILED ERROR in joinDebateDiscussionRoom:');
        AppLogger().error('   Error type: ${e.runtimeType}');
        AppLogger().error('   Error message: $e');
        AppLogger().error('   Document data attempted: ${documentData.toString()}');
        AppLogger().error('   Database ID: ${AppwriteConstants.databaseId}');
        AppLogger().error('   Collection ID: ${AppwriteConstants.debateDiscussionParticipantsCollection}');
        
        // Try to extract more details from AppwriteException
        if (e.toString().contains('AppwriteException')) {
          AppLogger().error('   This appears to be an AppwriteException - check Appwrite console for collection schema requirements');
        }
        
        rethrow;
      }
    } catch (e) {
      AppLogger().error('❌ ERROR in joinDebateDiscussionRoom outer catch: $e');
      rethrow;
    }
  }

  Future<void> leaveRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      // Delete ALL entries for this user in this room to prevent duplicates
      await _cleanupOpenDiscussionParticipantDuplicates(roomId, userId);
      
      AppLogger().debug('User $userId left open discussion room $roomId (all entries deleted)');
    } catch (e) {
      AppLogger().debug('Error leaving room: $e');
      rethrow;
    }
  }

  Future<void> updateParticipantRole({
    required String roomId,
    required String userId,
    required String newRole,
  }) async {
    try {
      final participants = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomParticipantsCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
          Query.equal('status', 'joined'),
        ],
      );
      
      if (participants.documents.isNotEmpty) {
        await databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: AppwriteConstants.roomParticipantsCollection,
          documentId: participants.documents.first.$id,
          data: {
            'role': newRole, // Store role as-is (audience, moderator, speaker)
            'lastActiveAt': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      AppLogger().debug('Error updating participant role: $e');
      rethrow;
    }
  }

  Future<void> updateParticipantMetadata({
    required String roomId,
    required String userId,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final participants = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomParticipantsCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
          Query.equal('status', 'joined'),
        ],
      );
      
      if (participants.documents.isNotEmpty) {
        // Get existing metadata and merge with new data
        final existingData = participants.documents.first.data;
        Map<String, dynamic> existingMetadata = {};
        
        // Parse existing metadata if it exists
        try {
          final metadataField = existingData['metadata'];
          if (metadataField != null) {
            if (metadataField is String) {
              existingMetadata = json.decode(metadataField);
            } else if (metadataField is Map<String, dynamic>) {
              existingMetadata = metadataField;
            }
          }
        } catch (e) {
          AppLogger().warning('Error parsing existing metadata: $e');
          existingMetadata = {};
        }
        
        // Merge new metadata with existing
        existingMetadata.addAll(metadata);
        
        // Convert metadata to JSON string for database storage
        final metadataJson = json.encode(existingMetadata);
        
        await databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: AppwriteConstants.roomParticipantsCollection,
          documentId: participants.documents.first.$id,
          data: {
            'metadata': metadataJson,
            'lastActiveAt': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      AppLogger().debug('Error updating participant metadata: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserRoomParticipation({
    required String roomId,
    required String userId,
  }) async {
    try {
      final participants = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomParticipantsCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
          Query.equal('status', 'joined'),
        ],
      );
      
      if (participants.documents.isNotEmpty) {
        final data = Map<String, dynamic>.from(participants.documents.first.data);
        data['id'] = participants.documents.first.$id;
        return data;
      }
      return null;
    } catch (e) {
      AppLogger().debug('Error getting user room participation: $e');
      rethrow;
    }
  }

  Future<void> deleteDebateClub(String clubId) async {
    try {
      AppLogger().debug('🗑️ Deleting club: $clubId');
      
      // First, delete all memberships for this club
      final members = await getClubMembers(clubId);
      for (final member in members) {
        final membershipId = member['id'];
        if (membershipId != null) {
          try {
            await deleteMembership(membershipId);
            AppLogger().info('Deleted membership: $membershipId');
          } catch (e) {
            AppLogger().warning('Failed to delete membership $membershipId: $e');
          }
        }
      }
      
      // Then delete the club itself
      await databases.deleteDocument(
        databaseId: 'arena_db',
        collectionId: 'debate_clubs',
        documentId: clubId,
      );
      
      AppLogger().info('Successfully deleted club: $clubId');
    } catch (e) {
      AppLogger().error('Error deleting club: $e');
      rethrow;
    }
  }

  // Follow/Unfollow Methods
  Future<void> followUser({
    required String followerId,
    required String followingId,
  }) async {
    try {
      // Check if already following
      final existingFollow = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'follows',
        queries: [
          Query.equal('followerId', followerId),
          Query.equal('followingId', followingId),
        ],
      );

      if (existingFollow.documents.isNotEmpty) {
        throw Exception('Already following this user');
      }

      await databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'follows',
        documentId: ID.unique(),
        data: {
          'followerId': followerId,
          'followingId': followingId,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      AppLogger().info('User $followerId is now following $followingId');
    } catch (e) {
      AppLogger().error('Error following user: $e');
      rethrow;
    }
  }

  Future<void> unfollowUser({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final follows = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'follows',
        queries: [
          Query.equal('followerId', followerId),
          Query.equal('followingId', followingId),
        ],
      );

      for (final follow in follows.documents) {
        await databases.deleteDocument(
          databaseId: 'arena_db',
          collectionId: 'follows',
          documentId: follow.$id,
        );
      }

      AppLogger().info('User $followerId unfollowed $followingId');
    } catch (e) {
      AppLogger().error('Error unfollowing user: $e');
      rethrow;
    }
  }

  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final follows = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'follows',
        queries: [
          Query.equal('followerId', followerId),
          Query.equal('followingId', followingId),
        ],
      );

      return follows.documents.isNotEmpty;
    } catch (e) {
      AppLogger().error('Error checking follow status: $e');
      return false;
    }
  }

  Future<int> getFollowerCount(String userId) async {
    try {
      final followers = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'follows',
        queries: [
          Query.equal('followingId', userId),
        ],
      );

      return followers.documents.length;
    } catch (e) {
      AppLogger().error('Error getting follower count: $e');
      return 0;
    }
  }

  Future<int> getFollowingCount(String userId) async {
    try {
      final following = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'follows',
        queries: [
          Query.equal('followerId', userId),
        ],
      );

      return following.documents.length;
    } catch (e) {
      AppLogger().error('Error getting following count: $e');
      return 0;
    }
  }

  /// Get list of users that the given user is following
  Future<List<UserProfile>> getUserFollowing(String userId) async {
    try {
      final following = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'follows',
        queries: [
          Query.equal('followerId', userId),
          Query.limit(100), // Reasonable limit
        ],
      );

      List<UserProfile> followingUsers = [];
      for (final follow in following.documents) {
        final followingId = follow.data['followingId'];
        final userProfile = await getUserProfile(followingId);
        if (userProfile != null) {
          followingUsers.add(userProfile);
        }
      }

      return followingUsers;
    } catch (e) {
      AppLogger().error('Error getting following list: $e');
      return [];
    }
  }

  /// Get list of users following the given user
  Future<List<UserProfile>> getUserFollowers(String userId) async {
    try {
      final followers = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'follows',
        queries: [
          Query.equal('followingId', userId),
          Query.limit(100), // Reasonable limit
        ],
      );

      List<UserProfile> followerUsers = [];
      for (final follow in followers.documents) {
        final followerId = follow.data['followerId'];
        final userProfile = await getUserProfile(followerId);
        if (userProfile != null) {
          followerUsers.add(userProfile);
        }
      }

      return followerUsers;
    } catch (e) {
      AppLogger().error('Error getting followers list: $e');
      return [];
    }
  }

  /// Get combined network (followers + following + arena audience) with role filtering for arena invites
  Future<List<UserProfile>> getUserNetworkForArenaRoles(String userId, {String? arenaRoomId}) async {
    try {
      // Get both followers and following
      final following = await getUserFollowing(userId);
      final followers = await getUserFollowers(userId);
      
      // Combine and deduplicate
      final networkMap = <String, UserProfile>{};
      for (final user in following) {
        networkMap[user.id] = user;
      }
      for (final user in followers) {
        networkMap[user.id] = user;
      }
      
      // Add arena room audience members if room ID provided
      if (arenaRoomId != null) {
        try {
          final arenaParticipants = await getArenaParticipants(arenaRoomId);
          AppLogger().debug('🎭 Found ${arenaParticipants.length} arena participants for role selection');
          
          int audienceCount = 0;
          int totalParticipants = 0;
          
          for (final participant in arenaParticipants) {
            totalParticipants++;
            final participantUserId = participant['userId'];
            final userProfile = participant['userProfile'];
            final role = participant['role'];
            
            AppLogger().debug('🎭 Participant $totalParticipants: userId=$participantUserId, role=$role, hasProfile=${userProfile != null}');
            
            // Include audience members and other non-debater roles (but not current user)
            if (role == 'audience' && participantUserId != userId && userProfile != null) {
              try {
                final profile = UserProfile.fromMap(userProfile);
                networkMap[profile.id] = profile;
                audienceCount++;
                AppLogger().debug('🎭 ✅ Added audience member ${profile.name} to selectable officials');
              } catch (e) {
                AppLogger().debug('🎭 ❌ Error parsing audience member profile: $e');
              }
            } else if (role == 'audience' && participantUserId == userId) {
              AppLogger().debug('🎭 ⏭️ Skipping current user as audience member');
            } else if (role != 'audience') {
              AppLogger().debug('🎭 ⏭️ Skipping non-audience participant with role: $role');
            }
          }
          
          AppLogger().debug('🎭 📊 Arena participants summary: Total=$totalParticipants, Audience=$audienceCount, Added to selection=$audienceCount');
        } catch (e) {
          AppLogger().warning('Error loading arena participants for role selection: $e');
          // Continue without arena participants
        }
      } else {
        AppLogger().debug('🎭 No arena room ID provided, skipping audience member lookup');
      }
      
      // Filter for users who have indicated they can be judges/moderators
      final eligibleUsers = <UserProfile>[];
      for (final user in networkMap.values) {
        // Check if user has arena role preferences
        if (user.isAvailableAsModerator || user.isAvailableAsJudge) {
          eligibleUsers.add(user);
        }
      }
      
      // If no users have explicit role preferences, include all network members and audience
      if (eligibleUsers.isEmpty) {
        AppLogger().debug('🎭 No users with explicit role preferences, including all network and audience members');
        return networkMap.values.toList();
      }
      
      AppLogger().debug('🎭 Found ${eligibleUsers.length} eligible users for arena roles');
      return eligibleUsers;
    } catch (e) {
      AppLogger().error('Error getting network for arena roles: $e');
      return [];
    }
  }

  // Challenge Methods for Instant Debates
  Future<void> sendChallenge({
    required String challengerId,
    required String challengedId,
    required String topic,
    String? description,
    required String position,
  }) async {
    try {
      await databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'challenges',
        documentId: ID.unique(),
        data: {
          'challengerId': challengerId,
          'challengedId': challengedId,
          'topic': topic,
          'description': description ?? '',
          'position': position,
          'status': 'pending', // pending, accepted, declined, expired
          'createdAt': DateTime.now().toIso8601String(),
          'expiresAt': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        },
      );

      AppLogger().info('Challenge sent from $challengerId to $challengedId (position: $position)');
    } catch (e) {
      AppLogger().error('Error sending challenge: $e');
      rethrow;
    }
  }

  Future<void> respondToChallenge({
    required String challengeId,
    required String response, // 'accepted' or 'declined'
  }) async {
    try {
      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'challenges',
        documentId: challengeId,
        data: {
          'status': response,
          'respondedAt': DateTime.now().toIso8601String(),
        },
      );

      AppLogger().info('Challenge $challengeId $response');
    } catch (e) {
      AppLogger().error('Error responding to challenge: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserChallenges(String userId) async {
    try {
      final challenges = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'challenges',
        queries: [
          Query.equal('challengedId', userId),
          Query.equal('status', 'pending'),
          Query.orderDesc('\$createdAt'),
        ],
      );

      return challenges.documents.map((doc) => _safeDocumentToMap(doc)).toList();
    } catch (e) {
      AppLogger().error('Error getting user challenges: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserArenaRoleNotifications(String userId) async {
    try {
      final notifications = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_notifications',
        queries: [
          Query.equal('userId', userId),
          Query.equal('status', 'pending'),
          Query.orderDesc('\$createdAt'),
        ],
      );

      return notifications.documents.map((doc) => _safeDocumentToMap(doc)).toList();
    } catch (e) {
      AppLogger().error('Error getting user arena role notifications: $e');
      return [];
    }
  }

  // Debate & Discussion Room Methods (separate from Open Discussion Rooms)
  Future<String> createDebateDiscussionRoom({
    required String name,
    required String description,
    required String category,
    required String debateStyle,
    required String createdBy,
    bool isPrivate = false,
    String? password,
    bool isScheduled = false,
    DateTime? scheduledDate,
  }) async {
    try {
      // Debug: Log the name being sent
      AppLogger().debug('🔥 Creating room with name: "$name"');
      AppLogger().debug('🔥 Name length: ${name.length}');
      AppLogger().debug('🔥 Name is empty: ${name.isEmpty}');
      
      final response = await databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.debateDiscussionRoomsCollection,
        documentId: ID.unique(),
        data: {
          'name': name, // Back to 'name' field since that's what the collection has
          'description': description,
          'category': category,
          'debateStyle': debateStyle,
          'createdBy': createdBy,
          'moderatorId': createdBy,
          'status': isScheduled ? 'scheduled' : 'active',
          'isPrivate': isPrivate,
          'password': password ?? '',
          'isScheduled': isScheduled,
          'scheduledDate': scheduledDate?.toIso8601String(),
          'maxParticipants': 999999,
          'settings': json.encode({
            'allowChat': true,
            'recordSession': false,
            'moderatorApproval': false,
          }),
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      
      // Create initial participant entry for the creator as moderator
      await joinDebateDiscussionRoom(
        roomId: response.$id,
        userId: createdBy,
        role: 'moderator',
      );
      
      AppLogger().debug('Created debate discussion room: ${response.$id}');
      return response.$id;
    } catch (e) {
      AppLogger().error('🚨 FULL ERROR creating debate discussion room: $e');
      AppLogger().error('🚨 ERROR TYPE: ${e.runtimeType}');
      if (e.toString().contains('AppwriteException')) {
        AppLogger().error('🚨 This is an AppwriteException - check collection permissions and schema');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getDebateDiscussionRooms() async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.debateDiscussionRoomsCollection,
        queries: [
          Query.equal('status', ['active', 'scheduled']),
          Query.limit(50),
          Query.orderDesc('\$createdAt'),
        ],
      );
      
      // For each room, get participant count and moderator profile
      List<Map<String, dynamic>> roomsWithDetails = [];
      for (var doc in response.documents) {
        final roomData = Map<String, dynamic>.from(doc.data);
        roomData['id'] = doc.$id;
        roomData['createdAt'] = doc.$createdAt;
        
        // Map 'name' field to 'title' for consistency with frontend expectations
        if (roomData.containsKey('name') && !roomData.containsKey('title')) {
          roomData['title'] = roomData['name'];
        }
        
        // Parse settings JSON
        if (roomData['settings'] is String) {
          try {
            roomData['settings'] = json.decode(roomData['settings']);
          } catch (e) {
            roomData['settings'] = {};
          }
        }
        
        // Get participant count
        final participantsResponse = await databases.listDocuments(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.roomParticipantsCollection,
          queries: [
            Query.equal('roomId', doc.$id),
            Query.equal('status', 'joined'),
          ],
        );
        
        roomData['participantCount'] = participantsResponse.documents.length;
        
        // Add participants array for compatibility with frontend
        roomData['participants'] = participantsResponse.documents.map((p) => p.data['userId']).toList();
        
        // Map category to tags array for frontend compatibility
        if (roomData.containsKey('category') && !roomData.containsKey('tags')) {
          roomData['tags'] = [roomData['category']];
        } else if (!roomData.containsKey('tags')) {
          roomData['tags'] = [];
        }
        
        // Get moderator profile
        try {
          final moderatorProfile = await getUserProfile(roomData['createdBy']);
          if (moderatorProfile != null) {
            roomData['moderatorProfile'] = {
              'name': moderatorProfile.name,
              'avatar': moderatorProfile.avatar,
              'email': moderatorProfile.email,
            };
          }
        } catch (e) {
          AppLogger().debug('Error getting moderator profile for room ${doc.$id}: $e');
        }
        
        roomsWithDetails.add(roomData);
      }
      
      return roomsWithDetails;
    } catch (e) {
      AppLogger().error('Error getting debate discussion rooms: $e');
      rethrow;
    }
  }

  /// Paginated version of getDebateDiscussionRooms
  Future<List<Map<String, dynamic>>> getDebateDiscussionRoomsPaginated({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.debateDiscussionRoomsCollection,
        queries: [
          Query.equal('status', ['active', 'scheduled']),
          Query.limit(limit),
          Query.offset(offset),
          Query.orderDesc('\$createdAt'),
        ],
      );
      
      // For each room, get participant count and moderator profile
      List<Map<String, dynamic>> roomsWithDetails = [];
      for (var doc in response.documents) {
        final roomData = Map<String, dynamic>.from(doc.data);
        roomData['id'] = doc.$id;
        roomData['createdAt'] = doc.$createdAt;
        
        // Map 'name' field to 'title' for consistency with frontend expectations
        if (roomData.containsKey('name') && !roomData.containsKey('title')) {
          roomData['title'] = roomData['name'];
        }
        
        // Parse settings JSON
        if (roomData['settings'] is String) {
          try {
            roomData['settings'] = json.decode(roomData['settings']);
          } catch (e) {
            roomData['settings'] = {};
          }
        }
        
        // Get participant count
        final participantsResponse = await databases.listDocuments(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.roomParticipantsCollection,
          queries: [
            Query.equal('roomId', doc.$id),
            Query.equal('status', 'joined'),
          ],
        );
        
        roomData['participantCount'] = participantsResponse.documents.length;
        
        // Add participants array for compatibility with frontend
        roomData['participants'] = participantsResponse.documents.map((p) => p.data['userId']).toList();
        
        // Map category to tags array for frontend compatibility
        if (roomData.containsKey('category') && !roomData.containsKey('tags')) {
          roomData['tags'] = [roomData['category']];
        } else if (!roomData.containsKey('tags')) {
          roomData['tags'] = [];
        }
        
        // Get moderator profile
        try {
          final moderatorProfile = await getUserProfile(roomData['createdBy']);
          if (moderatorProfile != null) {
            roomData['moderatorProfile'] = {
              'name': moderatorProfile.name,
              'avatar': moderatorProfile.avatar,
              'email': moderatorProfile.email,
            };
          }
        } catch (e) {
          AppLogger().debug('Error getting moderator profile for room ${doc.$id}: $e');
        }
        
        roomsWithDetails.add(roomData);
      }
      
      return roomsWithDetails;
    } catch (e) {
      AppLogger().error('Error getting paginated debate discussion rooms: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getDebateDiscussionRoom(String roomId) async {
    try {
      final response = await databases.getDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.debateDiscussionRoomsCollection,
        documentId: roomId,
      );
      
      final roomData = Map<String, dynamic>.from(response.data);
      roomData['id'] = response.$id;
      roomData['createdAt'] = response.$createdAt;
      
      // Parse settings JSON
      if (roomData['settings'] is String) {
        try {
          roomData['settings'] = json.decode(roomData['settings']);
        } catch (e) {
          roomData['settings'] = {};
        }
      }
      
      return roomData;
    } catch (e) {
      AppLogger().error('Error getting debate discussion room: $e');
      rethrow;
    }
  }

  Future<bool> validateDebateDiscussionRoomPassword({
    required String roomId,
    required String enteredPassword,
  }) async {
    try {
      AppLogger().debug('🔐 Fetching room document for ID: $roomId');
      
      final room = await databases.getDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.debateDiscussionRoomsCollection,
        documentId: roomId,
      );
      
      AppLogger().debug('🔐 Room data: ${room.data}');
      
      final roomPassword = room.data['password'] as String?;
      final isPrivate = room.data['isPrivate'] as bool? ?? false;
      
      AppLogger().debug('🔐 Room password: $roomPassword');
      AppLogger().debug('🔐 Is private: $isPrivate');
      AppLogger().debug('🔐 Entered password: $enteredPassword');
      
      // If room is not private, no password needed
      if (!isPrivate) {
        AppLogger().debug('🔐 Room is not private, allowing access');
        return true;
      }
      
      // If room is private but has no password set, allow access (shouldn't happen)
      if (roomPassword == null || roomPassword.isEmpty) {
        AppLogger().debug('🔐 Room is private but has no password, allowing access');
        return true;
      }
      
      // Check if entered password matches room password
      final isValid = enteredPassword == roomPassword;
      AppLogger().debug('🔐 Password match result: $isValid');
      return isValid;
    } catch (e) {
      AppLogger().error('🔐 Error validating room password: $e');
      return false;
    }
  }


  Future<void> leaveDebateDiscussionRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      // Delete ALL entries for this user in this room to prevent duplicates
      await _cleanupDebateDiscussionParticipantDuplicates(roomId, userId);
      
      AppLogger().debug('User $userId left debate discussion room $roomId (all entries deleted)');
    } catch (e) {
      AppLogger().error('Error leaving debate discussion room: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getDebateDiscussionParticipants(String roomId) async {
    try {
      AppLogger().debug('🔍 DEBUG: getDebateDiscussionParticipants called for roomId: $roomId');
      AppLogger().debug('🗂️ DEBUG: Querying collection: ${AppwriteConstants.debateDiscussionParticipantsCollection}');
      
      final participants = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.debateDiscussionParticipantsCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('status', 'joined'),
          Query.orderDesc('\$createdAt'),
        ],
      );
      
      AppLogger().debug('📊 DEBUG: Found ${participants.documents.length} participants in collection');
      
      List<Map<String, dynamic>> participantsList = [];
      
      // OPTIMIZATION: Batch load all user profiles at once instead of N+1 queries
      final userIds = participants.documents.map((p) => p.data['userId'] as String).toSet().toList();
      AppLogger().debug('🚀 BATCH LOADING: ${userIds.length} user profiles for ${participants.documents.length} participants');
      
      final userProfilesMap = await _batchGetUserProfiles(userIds);
      
      for (var participant in participants.documents) {
        final participantData = Map<String, dynamic>.from(participant.data);
        participantData['id'] = participant.$id;
        
        // Get user profile from batch-loaded data
        final userId = participantData['userId'] as String;
        final userProfile = userProfilesMap[userId];
        if (userProfile != null) {
          participantData['userProfile'] = userProfile;
        } else {
          AppLogger().warning('User profile not found in batch for participant: $userId');
        }
        
        participantsList.add(participantData);
      }
      
      return participantsList;
    } catch (e) {
      AppLogger().error('Error getting debate discussion participants: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDiscussionRoomParticipants(String roomId) async {
    try {
      AppLogger().debug('🔍 DEBUG: getDiscussionRoomParticipants called for roomId: $roomId');
      AppLogger().debug('🗂️ DEBUG: Querying collection: ${AppwriteConstants.roomParticipantsCollection}');
      
      final participants = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.roomParticipantsCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('status', 'joined'),
          Query.orderDesc('\$createdAt'),
        ],
      );
      
      AppLogger().debug('📊 DEBUG: Found ${participants.documents.length} participants in collection');
      
      List<Map<String, dynamic>> participantsList = [];
      
      // OPTIMIZATION: Batch load all user profiles at once instead of N+1 queries
      final userIds = participants.documents.map((p) => p.data['userId'] as String).toSet().toList();
      AppLogger().debug('🚀 BATCH LOADING: ${userIds.length} user profiles for ${participants.documents.length} participants');
      
      final userProfilesMap = await _batchGetUserProfiles(userIds);
      
      for (var participant in participants.documents) {
        final participantData = Map<String, dynamic>.from(participant.data);
        participantData['id'] = participant.$id;
        
        // Get user profile from batch-loaded data
        final userProfile = userProfilesMap[participantData['userId']];
        if (userProfile != null) {
          participantData['userProfile'] = userProfile;
        }
        
        participantsList.add(participantData);
      }
      
      return participantsList;
    } catch (e) {
      AppLogger().error('Error getting discussion room participants: $e');
      return [];
    }
  }

  /// ONE-TIME CLEANUP: Remove incorrectly stored Open Discussion rooms and participants
  Future<void> cleanupIncorrectOpenDiscussionData() async {
    try {
      AppLogger().debug('🧹 CLEANUP: Starting cleanup of incorrect Open Discussion data');
      
      // Step 1: Find Open Discussion rooms in wrong collection (debate_discussion_rooms)
      final wrongRooms = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.debateDiscussionRoomsCollection,
        queries: [
          Query.equal('debateStyle', 'Open Discussion'),
        ],
      );
      
      AppLogger().debug('🔍 Found ${wrongRooms.documents.length} Open Discussion rooms in wrong collection');
      
      if (wrongRooms.documents.isEmpty) {
        AppLogger().debug('✅ No incorrect Open Discussion rooms found - cleanup not needed');
        return;
      }
      
      // Step 2: Delete participants for these rooms
      int totalParticipantsDeleted = 0;
      for (var room in wrongRooms.documents) {
        final participants = await databases.listDocuments(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.roomParticipantsCollection,
          queries: [
            Query.equal('roomId', room.$id),
          ],
        );
        
        AppLogger().debug('🗑️ Deleting ${participants.documents.length} participants for room: ${room.data['name']}');
        
        for (var participant in participants.documents) {
          try {
            await databases.deleteDocument(
              databaseId: AppwriteConstants.databaseId,
              collectionId: AppwriteConstants.roomParticipantsCollection,
              documentId: participant.$id,
            );
            totalParticipantsDeleted++;
          } catch (e) {
            AppLogger().error('❌ Failed to delete participant ${participant.$id}: $e');
          }
        }
      }
      
      // Step 3: Delete the rooms themselves
      int roomsDeleted = 0;
      for (var room in wrongRooms.documents) {
        try {
          await databases.deleteDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.debateDiscussionRoomsCollection,
            documentId: room.$id,
          );
          AppLogger().debug('✅ Deleted room: ${room.data['name']}');
          roomsDeleted++;
        } catch (e) {
          AppLogger().error('❌ Failed to delete room ${room.data['name']}: $e');
        }
      }
      
      AppLogger().debug('🎉 CLEANUP COMPLETE: Deleted $roomsDeleted rooms and $totalParticipantsDeleted participants');
      AppLogger().debug('💡 New Open Discussion rooms will now use the correct collections');
      
    } catch (e) {
      AppLogger().error('❌ Error during cleanup: $e');
    }
  }

  /// Batch load multiple user profiles for optimal performance
  Future<Map<String, Map<String, dynamic>>> _batchGetUserProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    
    try {
      AppLogger().debug('🚀 APPWRITE OPTIMIZATION: Batch loading ${userIds.length} user profiles');
      
      // Since Appwrite doesn't support batch document loading by ID list directly,
      // we'll load individual profiles but with better caching and concurrency
      final userProfilesMap = <String, Map<String, dynamic>>{};
      
      // Use Future.wait for concurrent loading instead of sequential
      final futures = userIds.map((userId) async {
        try {
          final userProfile = await getUserProfile(userId);
          if (userProfile != null) {
            return MapEntry(userId, userProfile.toMap());
          }
        } catch (e) {
          AppLogger().warning('Failed to load profile: $userId - $e');
        }
        return null;
      });
      
      final results = await Future.wait(futures);
      
      for (final result in results) {
        if (result != null) {
          userProfilesMap[result.key] = result.value;
        }
      }
      
      AppLogger().debug('✅ CONCURRENT SUCCESS: Loaded ${userProfilesMap.length}/${userIds.length} user profiles concurrently');
      return userProfilesMap;
      
    } catch (e) {
      AppLogger().error('Error in batch user profile loading: $e');
      return {};
    }
  }


  Future<void> updateDebateDiscussionParticipantRole({
    required String roomId,
    required String userId,
    required String newRole,
  }) async {
    try {
      final participants = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.debateDiscussionParticipantsCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
          Query.equal('status', 'joined'),
        ],
      );
      
      if (participants.documents.isNotEmpty) {
        await databases.updateDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.debateDiscussionParticipantsCollection,
          documentId: participants.documents.first.$id,
          data: {
            'role': newRole,
            'lastActiveAt': DateTime.now().toIso8601String(),
          },
        );
        
        AppLogger().debug('Updated participant $userId role to $newRole in room $roomId');
      }
    } catch (e) {
      AppLogger().error('Error updating participant role: $e');
      rethrow;
    }
  }

  /// Update room participant role (for open discussion rooms)
  Future<void> updateRoomParticipantRole({
    required String roomId,
    required String userId,
    required String newRole,
  }) async {
    try {
      final participants = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.roomParticipantsCollection,
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
          Query.equal('status', 'joined'),
        ],
      );
      
      if (participants.documents.isNotEmpty) {
        await databases.updateDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.roomParticipantsCollection,
          documentId: participants.documents.first.$id,
          data: {
            'role': newRole,
            'lastActiveAt': DateTime.now().toIso8601String(),
          },
        );
        
        AppLogger().debug('Updated room participant $userId role to $newRole in room $roomId');
      }
    } catch (e) {
      AppLogger().error('Error updating room participant role: $e');
      rethrow;
    }
  }

  Future<void> updateDebateDiscussionRoom({
    required String roomId,
    Map<String, dynamic>? data,
  }) async {
    try {
      await databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.debateDiscussionRoomsCollection,
        documentId: roomId,
        data: data ?? {},
      );
      
      AppLogger().debug('Updated debate discussion room $roomId');
    } catch (e) {
      AppLogger().error('Error updating debate discussion room: $e');
      rethrow;
    }
  }

  // Arena Methods for Challenge-based Debates
  Future<String> createArenaRoom({
    required String challengeId,
    required String challengerId,
    required String challengedId,
    required String topic,
    String? description,
  }) async {
    try {
      // First check if a room already exists for this challenge
      final existingRooms = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        queries: [
          Query.equal('challengeId', challengeId),
          Query.equal('status', 'waiting'),
        ],
      );
      
      if (existingRooms.documents.isNotEmpty) {
        final existingRoom = existingRooms.documents.first;
        AppLogger().info('Using existing arena room: ${existingRoom.$id}');
        return existingRoom.$id;
      }
      
      // Create new room with unique ID
      final response = await databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: ID.unique(),
        data: {
          'challengeId': challengeId,
          'challengerId': challengerId,
          'challengedId': challengedId,
          'topic': topic,
          'description': description ?? '',
          'status': 'waiting', // waiting, active, judging, completed
          'startedAt': null,
          'endedAt': null,
          'winner': null,
          'judgingComplete': false,
          'judgingEnabled': false,
          'totalJudges': 0,
          'judgesSubmitted': 0,
        },
      );

      // Initialize Firebase timer for this room
      try {
        final firebaseTimer = FirebaseArenaTimerService();
        await firebaseTimer.initializeArenaTimer(response.$id);
        AppLogger().info('🔥 Firebase timer initialized for arena: ${response.$id}');
      } catch (e) {
        AppLogger().warning('Failed to initialize Firebase timer for arena: $e');
        // Don't fail room creation if Firebase timer fails
      }

      AppLogger().info('Arena room created: ${response.$id}');
      return response.$id;
    } catch (e) {
      AppLogger().error('Error creating Arena room: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getArenaRoom(String roomId) async {
    try {
      final response = await databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
      );

      final roomData = Map<String, dynamic>.from(response.data);
      roomData['id'] = response.$id;
      roomData['createdAt'] = response.$createdAt;
      roomData['updatedAt'] = response.$updatedAt;

      return roomData;
    } catch (e) {
      AppLogger().error('Error getting Arena room: $e');
      return null;
    }
  }

  Future<void> closeArenaRoom(String roomId) async {
    try {
      // Update arena room status to completed
      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'status': 'completed',
          'endedAt': DateTime.now().toIso8601String(),
        },
      );

      // Set all participants as inactive (effectively removing them from the room)
      final participants = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('isActive', true),
        ],
      );

      // Update each participant to inactive
      for (final participant in participants.documents) {
        await databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          documentId: participant.$id,
          data: {
            'isActive': false,
            'leftAt': DateTime.now().toIso8601String(),
          },
        );
      }

      AppLogger().info('Arena room $roomId closed successfully by moderator');
    } catch (e) {
      AppLogger().error('Error closing Arena room: $e');
      rethrow;
    }
  }

  /// Clean up duplicate entries for a user in an Arena room
  Future<void> _cleanupArenaParticipantDuplicates(String roomId, String userId) async {
    try {
      // Get ALL entries for this user in this room (active or not)
      final allEntries = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
        ],
      );
      
      // Delete all existing entries to ensure no duplicates
      for (var entry in allEntries.documents) {
        await databases.deleteDocument(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          documentId: entry.$id,
        );
      }
      
      if (allEntries.documents.isNotEmpty) {
        AppLogger().debug('Cleaned up ${allEntries.documents.length} duplicate Arena entries for user $userId in room $roomId');
      }
    } catch (e) {
      AppLogger().error('Error cleaning up Arena participant duplicates: $e');
    }
  }

  Future<String> assignArenaRole({
    required String roomId,
    required String userId,
    required String role, // affirmative, negative, moderator, judge1, judge2, judge3, audience
  }) async {
    try {
      String finalRole = role;
      
      // Get existing participants for role conflict checking
      final existingRolesResponse = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('isActive', true),
        ],
      );
      
      final existingRoles = existingRolesResponse.documents
          .map((doc) => doc.data['role'] as String)
          .toList();
      
      // Special handling for moderator role - enforce first-come-first-serve
      if (role == 'moderator') {
        AppLogger().debug('🔍 Processing moderator role assignment for user $userId in room $roomId');
        AppLogger().debug('🔍 Existing roles: $existingRoles');
        
        // Check if moderator slot is already taken
        if (existingRoles.contains('moderator')) {
          AppLogger().warning('⚠️ Moderator slot already taken in room $roomId - assigning user $userId as audience');
          finalRole = 'audience';
        } else {
          AppLogger().debug('✅ Moderator slot available - assigning user $userId as moderator');
          finalRole = 'moderator';
        }
      }
      // Special handling for judge role - assign to next available judge slot
      else if (role == 'judge') {
        AppLogger().debug('🔍 Processing judge role assignment for user $userId in room $roomId');
        
        final judgeRoles = ['judge1', 'judge2', 'judge3'];
        final takenJudgeRoles = existingRoles
            .where((r) => judgeRoles.contains(r))
            .toSet();
        
        AppLogger().debug('🔍 Existing judge roles taken: $takenJudgeRoles');
        
        // Find the first available judge slot
        for (final judgeRole in judgeRoles) {
          if (!takenJudgeRoles.contains(judgeRole)) {
            finalRole = judgeRole;
            AppLogger().debug('🔍 Assigning judge to slot: $finalRole');
            break;
          }
        }
        
        // If all judge slots are taken, still assign as judge1 (this shouldn't happen normally)
        if (finalRole == 'judge') {
          finalRole = 'judge1';
          AppLogger().warning('All judge slots taken, assigning to judge1 anyway');
        }
      }
      
      // First, clean up any existing entries for this user in this room to prevent duplicates
      await _cleanupArenaParticipantDuplicates(roomId, userId);
      
      // Create new role assignment (always create fresh to avoid duplicates)
      await databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        documentId: ID.unique(),
        data: {
          'roomId': roomId,
          'userId': userId,
          'role': finalRole,
          'assignedAt': DateTime.now().toIso8601String(),
          'isActive': true,
        },
      );
      AppLogger().info('✅ Created new participant: user $userId as $finalRole in room $roomId (duplicates cleaned)');

      AppLogger().info('Assigned $finalRole to user $userId in room $roomId');
      return finalRole; // Return the actual role assigned (might be different from requested)
    } catch (e) {
      AppLogger().error('Error assigning Arena role: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getArenaParticipants(String roomId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('isActive', true),
        ],
      );

      List<Map<String, dynamic>> participants = [];
      for (var doc in response.documents) {
        final participantData = Map<String, dynamic>.from(doc.data);
        participantData['id'] = doc.$id;
        
        // Get user profile for each participant
        final userProfile = await getUserProfile(participantData['userId']);
        if (userProfile != null) {
          participantData['userProfile'] = userProfile.toMap();
        }
        
        participants.add(participantData);
      }

      return participants;
    } catch (e) {
      AppLogger().error('Error getting Arena participants: $e');
      return [];
    }
  }

  Future<void> updateArenaParticipantStatus({
    required String roomId,
    required String userId,
    bool? completedSelection,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Find the participant document
      final response = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
          Query.equal('isActive', true),
        ],
      );

      if (response.documents.isEmpty) {
        AppLogger().warning('No active participant found for user $userId in room $roomId');
        return;
      }

      final participantDoc = response.documents.first;
      Map<String, dynamic> updateData = {};

      if (completedSelection != null) {
        updateData['completedSelection'] = completedSelection;
        if (completedSelection) {
          updateData['completedAt'] = DateTime.now().toIso8601String();
        }
      }

      if (metadata != null) {
        updateData['metadata'] = jsonEncode(metadata);
      }

      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        documentId: participantDoc.$id,
        data: updateData,
      );

      AppLogger().info('Updated arena participant status for user $userId in room $roomId');
    } catch (e) {
      AppLogger().error('Error updating arena participant status: $e');
      rethrow;
    }
  }

  Future<void> submitArenaJudgment({
    required String roomId,
    required String judgeId,
    required String challengeId,
    required double affirmativeArguments,
    required double affirmativePresentation,
    required double affirmativeRebuttal,
    required double negativeArguments,
    required double negativePresentation,
    required double negativeRebuttal,
    required String winner, // 'affirmative' or 'negative'
    String? comments,
  }) async {
    try {
      // Check if this judge has already submitted
      final existingJudgments = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_judgments',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('judgeId', judgeId),
        ],
      );

      if (existingJudgments.documents.isNotEmpty) {
        throw Exception('You have already submitted your judgment for this debate.');
      }

      // Submit individual judgment
      await databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_judgments',
        documentId: ID.unique(),
        data: {
          'roomId': roomId,
          'challengeId': challengeId,
          'judgeId': judgeId,
          'affirmativeScores': jsonEncode({
            'arguments': affirmativeArguments,
            'presentation': affirmativePresentation,
            'rebuttal': affirmativeRebuttal,
            'total': affirmativeArguments + affirmativePresentation + affirmativeRebuttal,
          }),
          'negativeScores': jsonEncode({
            'arguments': negativeArguments,
            'presentation': negativePresentation,
            'rebuttal': negativeRebuttal,
            'total': negativeArguments + negativePresentation + negativeRebuttal,
          }),
          'winner': winner,
          'comments': comments ?? '',
          'submittedAt': DateTime.now().toIso8601String(),
        },
      );

      // Update room's judge count
      final room = await getArenaRoom(roomId);
      if (room != null) {
        final currentJudgesSubmitted = room['judgesSubmitted'] ?? 0;
        final judgesSubmitted = currentJudgesSubmitted + 1;
        final totalJudges = room['totalJudges'] ?? 0;
        
        AppLogger().debug('🔍 WINNER LOGIC: $judgesSubmitted judges submitted out of $totalJudges total');
        
        final judgingComplete = judgesSubmitted >= totalJudges && totalJudges >= 1; // Changed from 3 to 1 for testing
        
        await databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'arena_rooms',
          documentId: roomId,
          data: {
            'judgesSubmitted': judgesSubmitted,
            'judgingComplete': judgingComplete,
          },
        );

        AppLogger().debug('🔍 WINNER LOGIC: Updated room with judgesSubmitted=$judgesSubmitted, judgingComplete=$judgingComplete');

        // If all judges have submitted, determine final winner
        if (judgingComplete) {
          AppLogger().debug('🔍 WINNER LOGIC: All judges submitted, determining winner...');
          await _determineArenaWinner(roomId, challengeId);
        }
      }

      AppLogger().info('Arena judgment submitted by judge $judgeId');
    } catch (e) {
      AppLogger().error('Error submitting Arena judgment: $e');
      rethrow;
    }
  }

  Future<void> _determineArenaWinner(String roomId, String challengeId) async {
    try {
      AppLogger().debug('🔍 WINNER DETERMINATION: Starting for room $roomId');
      
      // Get all judgments for this room
      final judgments = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_judgments',
        queries: [
          Query.equal('roomId', roomId),
        ],
      );

      AppLogger().debug('🔍 WINNER DETERMINATION: Found ${judgments.documents.length} judgments');

      if (judgments.documents.isEmpty) {
        AppLogger().error('WINNER DETERMINATION: Not enough judgments (need at least 1)');
        return; // Need at least 1 judge for testing
      }

      // Count votes for each side
      int affirmativeVotes = 0;
      int negativeVotes = 0;
      
      for (var judgment in judgments.documents) {
        final winner = judgment.data['winner'];
        final judgeId = judgment.data['judgeId'];
        AppLogger().debug('🔍 WINNER DETERMINATION: Judge $judgeId voted for: $winner');
        
        if (winner == 'affirmative') {
          affirmativeVotes++;
        } else if (winner == 'negative') {
          negativeVotes++;
        }
      }

      final finalWinner = affirmativeVotes > negativeVotes ? 'affirmative' : 'negative';
      
      AppLogger().debug('🏆 WINNER DETERMINATION: Final result - Affirmative: $affirmativeVotes, Negative: $negativeVotes, Winner: $finalWinner');

      // Update room with final result
      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'winner': finalWinner,
          'status': 'completed',
          'judgingComplete': true,
          'endedAt': DateTime.now().toIso8601String(),
        },
      );

      // Update challenge with result
      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'challenges',
        documentId: challengeId,
        data: {
          'winner': finalWinner,
          'status': 'completed',
          'completedAt': DateTime.now().toIso8601String(),
        },
      );

      AppLogger().info('Arena winner determined: $finalWinner (A:$affirmativeVotes vs N:$negativeVotes)');
      AppLogger().info('Updated both arena room and challenge with final results');
    } catch (e) {
      AppLogger().error('Error determining Arena winner: $e');
    }
  }

  Future<void> startArenaDebate(String roomId) async {
    try {
      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'status': 'active',
          'startedAt': DateTime.now().toIso8601String(),
        },
      );

      AppLogger().info('Arena debate started: $roomId');
    } catch (e) {
      AppLogger().error('Error starting Arena debate: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getChallenge(String challengeId) async {
    try {
      final response = await databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'challenges',
        documentId: challengeId,
      );

      final challengeData = Map<String, dynamic>.from(response.data);
      challengeData['id'] = response.$id;
      return challengeData;
    } catch (e) {
      AppLogger().error('Error getting challenge: $e');
      return null;
    }
  }

  // Methods for finding available moderators and judges
  Future<List<UserProfile>> getAvailableModerators({
    int limit = 10,
    String? excludeArenaId,
    List<String>? excludeUserIds,
  }) async {
    try {
      // First, clean up any abandoned arena rooms to free up stuck users
      await cleanupAbandonedArenaRooms();
      
      // Get all users who are available as moderators
      final response = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [
          Query.equal('isAvailableAsModerator', true),
          Query.limit(100), // Get more initially for filtering
          Query.orderDesc('reputation'), // Prioritize high reputation users
        ],
      );

      List<UserProfile> availableUsers = response.documents.map((doc) {
        final userData = Map<String, dynamic>.from(doc.data);
        userData['id'] = doc.$id;
        userData['createdAt'] = doc.$createdAt;
        userData['updatedAt'] = doc.$updatedAt;
        return UserProfile.fromMap(userData);
      }).toList();

      // Filter out users who are already occupied
      List<UserProfile> filteredUsers = [];
      
      for (final user in availableUsers) {
        // Skip if user is in exclude list (e.g., debaters in current arena)
        if (excludeUserIds != null && excludeUserIds.contains(user.id)) {
          AppLogger().debug('🚫 Excluding user ${user.name} - in exclude list');
          continue;
        }

        // Check if user is already assigned to any active arena
        final userArenaParticipations = await databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          queries: [
            Query.equal('userId', user.id),
            Query.equal('isActive', true),
          ],
        );

        bool isOccupied = false;
        for (final participation in userArenaParticipations.documents) {
          final participationArenaId = participation.data['roomId'];
          final participationRole = participation.data['role'];
          
          // Skip if it's the current arena we're trying to fill (they might already be audience)
          if (excludeArenaId != null && participationArenaId == excludeArenaId) {
            // Only exclude if they have a significant role, not just audience
            if (['affirmative', 'negative', 'moderator', 'judge1', 'judge2', 'judge3'].contains(participationRole)) {
              AppLogger().debug('🚫 Excluding user ${user.name} - already $participationRole in current arena');
              isOccupied = true;
              break;
            }
          } else {
            // For other arenas, exclude if they have any ACTIVE role (not just audience)
            if (['affirmative', 'negative', 'moderator', 'judge1', 'judge2', 'judge3'].contains(participationRole)) {
              // Verify the arena is still active
              try {
                final arena = await getArenaRoom(participationArenaId);
                if (arena != null && arena['status'] != 'completed') {
                  AppLogger().debug('🚫 Excluding user ${user.name} - already $participationRole in active arena $participationArenaId');
                  isOccupied = true;
                  break;
                } else {
                  // Arena is completed or doesn't exist - clean up this participation
                  AppLogger().debug('🧹 Cleaning up stale participation for ${user.name} in arena $participationArenaId');
                  await _cleanupArenaParticipation(participation);
                }
              } catch (e) {
                // Arena might not exist anymore, clean up participation
                AppLogger().debug('🧹 Arena $participationArenaId not found, cleaning up participation for ${user.name}');
                await _cleanupArenaParticipation(participation);
              }
            } else if (participationRole == 'audience') {
              // Allow users who are only audience in other arenas to become moderator/judge
              AppLogger().info('User ${user.name} can moderate/judge - they are only audience in arena $participationArenaId');
            }
          }
        }

        if (!isOccupied) {
          filteredUsers.add(user);
          AppLogger().info('User ${user.name} is available as moderator');
        }

        // Stop once we have enough candidates
        if (filteredUsers.length >= limit) {
          break;
        }
      }

      AppLogger().debug('🔍 Found ${filteredUsers.length} available moderators (from ${availableUsers.length} total)');
      return filteredUsers.take(limit).toList();
    } catch (e) {
      AppLogger().error('Error getting available moderators: $e');
      return [];
    }
  }

  Future<List<UserProfile>> getAvailableJudges({
    int limit = 10,
    String? excludeArenaId,
    List<String>? excludeUserIds,
  }) async {
    try {
      // First, clean up any abandoned arena rooms to free up stuck users
      await cleanupAbandonedArenaRooms();
      
      // Get all users who are available as judges
      final response = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [
          Query.equal('isAvailableAsJudge', true),
          Query.limit(100), // Get more initially for filtering
          Query.orderDesc('reputation'), // Prioritize high reputation users
        ],
      );

      List<UserProfile> availableUsers = response.documents.map((doc) {
        final userData = Map<String, dynamic>.from(doc.data);
        userData['id'] = doc.$id;
        userData['createdAt'] = doc.$createdAt;
        userData['updatedAt'] = doc.$updatedAt;
        return UserProfile.fromMap(userData);
      }).toList();

      // Filter out users who are already occupied
      List<UserProfile> filteredUsers = [];
      
      for (final user in availableUsers) {
        // Skip if user is in exclude list (e.g., debaters in current arena)
        if (excludeUserIds != null && excludeUserIds.contains(user.id)) {
          AppLogger().debug('🚫 Excluding user ${user.name} - in exclude list');
          continue;
        }

        // Check if user is already assigned to any active arena
        final userArenaParticipations = await databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          queries: [
            Query.equal('userId', user.id),
            Query.equal('isActive', true),
          ],
        );

        bool isOccupied = false;
        for (final participation in userArenaParticipations.documents) {
          final participationArenaId = participation.data['roomId'];
          final participationRole = participation.data['role'];
          
          // Skip if it's the current arena we're trying to fill (they might already be audience)
          if (excludeArenaId != null && participationArenaId == excludeArenaId) {
            // Only exclude if they have a significant role, not just audience
            if (['affirmative', 'negative', 'moderator', 'judge1', 'judge2', 'judge3'].contains(participationRole)) {
              AppLogger().debug('🚫 Excluding user ${user.name} - already $participationRole in current arena');
              isOccupied = true;
              break;
            }
          } else {
            // For other arenas, exclude if they have any ACTIVE role (not just audience)
            if (['affirmative', 'negative', 'moderator', 'judge1', 'judge2', 'judge3'].contains(participationRole)) {
              // Verify the arena is still active
              try {
                final arena = await getArenaRoom(participationArenaId);
                if (arena != null && arena['status'] != 'completed') {
                  AppLogger().debug('🚫 Excluding user ${user.name} - already $participationRole in active arena $participationArenaId');
                  isOccupied = true;
                  break;
                } else {
                  // Arena is completed or doesn't exist - clean up this participation
                  AppLogger().debug('🧹 Cleaning up stale participation for ${user.name} in arena $participationArenaId');
                  await _cleanupArenaParticipation(participation);
                }
              } catch (e) {
                // Arena might not exist anymore, clean up participation
                AppLogger().debug('🧹 Arena $participationArenaId not found, cleaning up participation for ${user.name}');
                await _cleanupArenaParticipation(participation);
              }
            } else if (participationRole == 'audience') {
              // Allow users who are only audience in other arenas to become moderator/judge
              AppLogger().info('User ${user.name} can moderate/judge - they are only audience in arena $participationArenaId');
            }
          }
        }

        if (!isOccupied) {
          filteredUsers.add(user);
          AppLogger().info('User ${user.name} is available as judge');
        }

        // Stop once we have enough candidates
        if (filteredUsers.length >= limit) {
          break;
        }
      }

      AppLogger().debug('🔍 Found ${filteredUsers.length} available judges (from ${availableUsers.length} total)');
      return filteredUsers.take(limit).toList();
    } catch (e) {
      AppLogger().error('Error getting available judges: $e');
      return [];
    }
  }

  Future<void> sendArenaRoleNotification({
    required String userId,
    required String arenaId,
    required String topic,
    required String role, // 'moderator' or 'judge'
  }) async {
    try {
      await databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_notifications',
        documentId: ID.unique(),
        data: {
          'userId': userId,
          'arenaId': arenaId,
          'topic': topic,
          'role': role,
          'status': 'pending', // pending, accepted, declined, expired
          'createdAt': DateTime.now().toIso8601String(),
          'expiresAt': DateTime.now().add(const Duration(minutes: 2)).toIso8601String(),
        },
      );

      AppLogger().info('Arena $role notification sent to $userId for arena $arenaId');
    } catch (e) {
      AppLogger().error('Error sending arena notification: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getActiveArenaRooms() async {
    try {
      final response = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        queries: [
          Query.notEqual('status', 'completed'),
          Query.orderDesc('\$createdAt'),
          Query.limit(20),
        ],
      );

      return response.documents.map((doc) {
        try {
          return _safeDocumentToMap(doc);
        } catch (e) {
          AppLogger().warning('Error processing arena room document ${doc.$id}: $e');
          // Return minimal safe data
          return <String, dynamic>{
            'id': doc.$id,
            'createdAt': doc.$createdAt,
            'updatedAt': doc.$updatedAt,
            'title': 'Unknown Room',
            'status': 'active',
          };
        }
      }).toList();
    } catch (e) {
      AppLogger().error('Error getting active arena rooms: $e');
      return [];
    }
  }

  Future<void> updateArenaRoomJudgeCount(String roomId, int judgeCount) async {
    try {
      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'totalJudges': judgeCount,
        },
      );
      AppLogger().info('Updated arena room $roomId with $judgeCount expected judges');
    } catch (e) {
      AppLogger().error('Error updating arena room judge count: $e');
      rethrow;
    }
  }

  /// Update arena room status (e.g., from 'scheduled' to 'waiting')
  Future<void> updateArenaRoomStatus(String roomId, String newStatus) async {
    try {
      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'status': newStatus,
        },
      );
      AppLogger().info('Updated arena room $roomId status to $newStatus');
    } catch (e) {
      AppLogger().error('Error updating arena room status: $e');
      rethrow;
    }
  }

  Future<void> updateArenaJudgingEnabled(String roomId, bool judgingEnabled) async {
    try {
      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'judgingEnabled': judgingEnabled,
        },
      );
      AppLogger().info('Updated arena room $roomId judging enabled: $judgingEnabled');
    } catch (e) {
      AppLogger().error('Error updating arena judging state: $e');
      rethrow;
    }
  }

  Future<void> respondToArenaRoleNotification({
    required String notificationId,
    required String response, // 'accepted' or 'declined'
  }) async {
    try {
      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_notifications',
        documentId: notificationId,
        data: {
          'status': response,
        },
      );
      AppLogger().info('Arena role notification $response: $notificationId');
    } catch (e) {
      AppLogger().error('Error responding to arena notification: $e');
      rethrow;
    }
  }

  // User Discovery Methods
  Future<List<UserProfile>> getAllUsers({int limit = 100}) async {
    try {
      final response = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [
          Query.equal('isPublicProfile', true),
          Query.limit(limit),
          Query.orderDesc('reputation'),
        ],
      );

      return response.documents.map((doc) {
        final userData = Map<String, dynamic>.from(doc.data);
        userData['id'] = doc.$id;
        userData['createdAt'] = doc.$createdAt;
        userData['updatedAt'] = doc.$updatedAt;
        return UserProfile.fromMap(userData);
      }).toList();
    } catch (e) {
      AppLogger().error('Error getting all users: $e');
      return [];
    }
  }

  Future<List<UserProfile>> searchUsers(String query, {int limit = 50}) async {
    try {
      AppLogger().info('🔍 AppwriteService: Searching users with query: "$query"');
      
      // Try multiple search strategies
      late models.DocumentList response;
      bool needsManualFilter = false;
      
      try {
        // First try: Search by name field (requires index)
        AppLogger().debug('🔍 Trying search by name field');
        response = await databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'users',
          queries: [
            Query.search('name', query),
            Query.limit(limit),
            Query.orderDesc('reputation'),
          ],
        );
      } catch (e) {
        AppLogger().warning('🔍 Search by name failed: $e, trying alternative approach');
        
        // Fallback: Search using contains pattern
        try {
          response = await databases.listDocuments(
            databaseId: 'arena_db',
            collectionId: 'users',
            queries: [
              Query.contains('name', query),
              Query.limit(limit),
              Query.orderDesc('reputation'),
            ],
          );
        } catch (e2) {
          AppLogger().warning('🔍 Contains search failed: $e2, trying simple list');
          
          // Last resort: Get all users and filter manually
          needsManualFilter = true;
          try {
            response = await databases.listDocuments(
              databaseId: 'arena_db',
              collectionId: 'users',
              queries: [
                Query.limit(limit),
                Query.orderDesc('reputation'),
              ],
            );
          } catch (e3) {
            AppLogger().warning('🔍 Order by reputation failed: $e3, using simple list');
            // Ultra-simple fallback
            response = await databases.listDocuments(
              databaseId: 'arena_db',
              collectionId: 'users',
              queries: [Query.limit(limit)],
            );
          }
        }
      }
      
      AppLogger().info('🔍 AppwriteService: Found ${response.documents.length} users from database');
      
      var users = response.documents.map((doc) {
        try {
          final userData = _safeDocumentToMap(doc);
          final userProfile = UserProfile.fromMap(userData);
          AppLogger().debug('🔍 User found: ${userProfile.name} (${userProfile.id})');
          return userProfile;
        } catch (e) {
          AppLogger().warning('Error processing user document ${doc.$id}: $e');
          return null;
        }
      }).where((user) => user != null).cast<UserProfile>().toList();
      
      // If we had to fall back to listing all users, filter manually
      if (needsManualFilter && users.isNotEmpty) {
        final queryLower = query.toLowerCase();
        users = users.where((user) => 
          user.name.toLowerCase().contains(queryLower)
        ).toList();
        AppLogger().info('🔍 After manual filtering: ${users.length} users match "$query"');
      }
      
      AppLogger().info('🔍 AppwriteService: Returning ${users.length} users');
      return users;
    } catch (e) {
      AppLogger().error('❌ AppwriteService: Error searching users: $e');
      return [];
    }
  }

  // Debug method to test user search functionality
  Future<void> debugUserSearch() async {
    try {
      AppLogger().info('🔧 DEBUG: Testing user search functionality');
      
      // Test 1: List all users (no search)
      final allUsers = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [Query.limit(10)],
      );
      AppLogger().info('🔧 DEBUG: Found ${allUsers.documents.length} total users');
      
      // Show first few users for debugging
      for (int i = 0; i < allUsers.documents.length && i < 3; i++) {
        final doc = allUsers.documents[i];
        final name = doc.data['name'] ?? 'No name';
        AppLogger().info('🔧 DEBUG: User $i: $name (${doc.$id})');
      }
      
      // Test 2: Try a simple search if we have users
      if (allUsers.documents.isNotEmpty) {
        final firstUserName = allUsers.documents.first.data['name'] ?? '';
        if (firstUserName.isNotEmpty && firstUserName.length > 2) {
          final searchQuery = firstUserName.substring(0, 2);
          AppLogger().info('🔧 DEBUG: Testing search with "$searchQuery"');
          final searchResults = await searchUsers(searchQuery);
          AppLogger().info('🔧 DEBUG: Search returned ${searchResults.length} results');
        }
      }
      
    } catch (e) {
      AppLogger().error('🔧 DEBUG: Error in debug search: $e');
    }
  }

  /// Safely convert Appwrite document data to Map with proper null handling
  static Map<String, dynamic> _safeDocumentToMap(models.Document doc, {Map<String, dynamic>? additionalData}) {
    try {
      AppLogger().debug('🔧 _safeDocumentToMap processing document: ${doc.$id}');
      final result = <String, dynamic>{};
      
      // Safely copy document data
      if (doc.data.isNotEmpty) {
        AppLogger().debug('🔧 Document data keys: ${doc.data.keys.toList()}');
        doc.data.forEach((key, value) {
          AppLogger().debug('🔧 Processing field "$key": $value (${value.runtimeType})');
          result[key] = value; // Let null values pass through naturally
        });
      }
      
      // Add standard document fields
      result['id'] = doc.$id;
      result['createdAt'] = doc.$createdAt;
      result['updatedAt'] = doc.$updatedAt;
      
      // Add any additional data
      if (additionalData != null) {
        additionalData.forEach((key, value) {
          result[key] = value;
        });
      }
      
      return result;
    } catch (e) {
      AppLogger().warning('Error safely converting document ${doc.$id}: $e');
      // Return minimal safe data
      return {
        'id': doc.$id,
        'createdAt': doc.$createdAt,
        'updatedAt': doc.$updatedAt,
        ...?additionalData,
      };
    }
  }

  // Test real-time connection
  Future<void> testRealtimeConnection() async {
    try {
      AppLogger().debug('🔗 Testing real-time connection...');
      AppLogger().debug('Endpoint: ${client.config['endpoint']}');
      AppLogger().debug('Project: ${client.config['project']}');
      
      // Try to create a test subscription to see if real-time works
      final testSubscription = realtime.subscribe(['heartbeat']);
      
      AppLogger().debug('🔗 Test subscription created successfully');
      
      // Close test subscription after 1 second
      Future.delayed(const Duration(seconds: 1), () {
        testSubscription.close();
        AppLogger().debug('🔗 Test subscription closed');
      });
      
    } catch (e) {
      AppLogger().error('Real-time connection test failed: $e');
    }
  }

  Future<void> _cleanupArenaParticipation(dynamic participationDoc) async {
    try {
      final participationId = participationDoc.$id;
      if (participationId != null) {
        // Mark participation as inactive instead of deleting (for historical records)
        await databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          documentId: participationId,
          data: {
            'isActive': false,
          },
        );
        AppLogger().info('Cleaned up arena participation: $participationId');
      }
    } catch (e) {
      AppLogger().error('Error cleaning up participation: $e');
      // Don't rethrow to avoid blocking the main process
    }
  }

  Future<void> cleanupAbandonedArenaRooms() async {
    try {
      AppLogger().debug('🧹 Starting cleanup of abandoned arena rooms...');
      
      // Get all non-completed arena rooms
      final arenaRooms = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        queries: [
          Query.notEqual('status', 'completed'),
          Query.limit(100),
        ],
      );

      int cleanedRooms = 0;
      int cleanedParticipations = 0;

      for (final room in arenaRooms.documents) {
        final roomId = room.$id;
        final createdAt = DateTime.parse(room.$createdAt);
        final roomAge = DateTime.now().difference(createdAt);
        
        // Get active participants for this room
        final participants = await databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          queries: [
            Query.equal('roomId', roomId),
            Query.equal('isActive', true),
          ],
        );

        // Check if room should be cleaned up
        bool shouldCleanup = false;
        String reason = '';

        // Cleanup criteria (more reasonable):
        // 1. Room is older than 6 hours regardless of status
        // 2. Room is older than 2 hours with no active participants
        // 3. Room is in "waiting" status for more than 2 hours with no moderator
        // 4. Room has only audience members for 1+ hours
        // PROTECTION: Never cleanup rooms less than 5 minutes old to prevent race conditions
        
        if (roomAge.inMinutes < 5) {
          // PROTECTION: Never cleanup newly created rooms to prevent race conditions
          shouldCleanup = false;
          AppLogger().debug('🛡️ Protecting newly created room from cleanup: $roomId (age: ${roomAge.inMinutes}m)');
        } else if (roomAge.inHours >= 6) {
          shouldCleanup = true;
          reason = 'older than 6 hours';
        } else if (roomAge.inHours >= 2 && participants.documents.isEmpty) {
          shouldCleanup = true;
          reason = 'older than 2 hours with no participants';
        } else if (roomAge.inHours >= 2 && room.data['status'] == 'waiting') {
          // Check if room has a moderator
          final hasModerator = participants.documents.any((p) => p.data['role'] == 'moderator');
          if (!hasModerator) {
            shouldCleanup = true;
            reason = 'waiting status for 2+ hours with no moderator';
          }
        } else if (participants.documents.isNotEmpty && roomAge.inHours >= 1) {
          // Check if only audience members remain
          final importantRoles = ['affirmative', 'negative', 'moderator', 'judge1', 'judge2', 'judge3'];
          final hasImportantParticipants = participants.documents.any((p) => 
            importantRoles.contains(p.data['role']));
          
          if (!hasImportantParticipants) {
            shouldCleanup = true;
            reason = 'only audience members for 1+ hours';
          }
        }

        if (shouldCleanup) {
          AppLogger().debug('🧹 Cleaning up arena room $roomId ($reason)');
          
          // Mark all participants as inactive
          for (final participant in participants.documents) {
            await _cleanupArenaParticipation(participant);
            cleanedParticipations++;
          }
          
          // Mark arena room as completed/abandoned
          await databases.updateDocument(
            databaseId: 'arena_db',
            collectionId: 'arena_rooms',
            documentId: roomId,
            data: {
              'status': 'abandoned',
              'endedAt': DateTime.now().toIso8601String(),
            },
          );
          
          cleanedRooms++;
          AppLogger().info('Cleaned up arena room: $roomId');
        }
      }

      AppLogger().debug('🧹 Cleanup completed: $cleanedRooms rooms, $cleanedParticipations participations');
    } catch (e) {
      AppLogger().error('Error during arena cleanup: $e');
    }
  }

  Future<void> forceCleanupAllOldArenaRooms() async {
    try {
      AppLogger().debug('🚨 FORCE CLEANUP: Removing ALL old arena rooms...');
      
      // Get ALL arena rooms (not just non-completed ones)
      final allRooms = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        queries: [
          Query.limit(100),
        ],
      );

      int totalCleaned = 0;
      int participationsCleaned = 0;

      for (final room in allRooms.documents) {
        final roomId = room.$id;
        final createdAt = DateTime.parse(room.$createdAt);
        final roomAge = DateTime.now().difference(createdAt);
        
        // Clean up any room older than 5 minutes, regardless of status
        if (roomAge.inMinutes >= 5) {
          AppLogger().debug('🚨 Force cleaning room $roomId (age: ${roomAge.inMinutes} minutes)');
          
          // Get ALL participants for this room (active or not)
          final allParticipants = await databases.listDocuments(
            databaseId: 'arena_db',
            collectionId: 'arena_participants',
            queries: [
              Query.equal('roomId', roomId),
            ],
          );

          // Mark all participants as inactive
          for (final participant in allParticipants.documents) {
            await _cleanupArenaParticipation(participant);
            participationsCleaned++;
          }
          
          // Mark room as abandoned
          await databases.updateDocument(
            databaseId: 'arena_db',
            collectionId: 'arena_rooms',
            documentId: roomId,
            data: {
              'status': 'force_cleaned',
              'endedAt': DateTime.now().toIso8601String(),
            },
          );
          
          totalCleaned++;
        }
      }

      AppLogger().debug('🚨 FORCE CLEANUP COMPLETED: $totalCleaned rooms, $participationsCleaned participations');
    } catch (e) {
      AppLogger().error('Error during force cleanup: $e');
      rethrow;
    }
  }

  Future<void> deleteAllArenaRooms() async {
    try {
      AppLogger().debug('🗑️ DELETING ALL ARENA ROOMS...');
      
      // Get ALL arena rooms
      final allRooms = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        queries: [
          Query.limit(100),
        ],
      );

      int totalDeleted = 0;
      int participationsDeleted = 0;

      for (final room in allRooms.documents) {
        final roomId = room.$id;
        AppLogger().debug('🗑️ Deleting room $roomId');
        
        try {
          // Get ALL participants for this room
          final allParticipants = await databases.listDocuments(
            databaseId: 'arena_db',
            collectionId: 'arena_participants',
            queries: [
              Query.equal('roomId', roomId),
            ],
          );

          // Delete all participants
          for (final participant in allParticipants.documents) {
            await databases.deleteDocument(
              databaseId: 'arena_db',
              collectionId: 'arena_participants',
              documentId: participant.$id,
            );
            participationsDeleted++;
          }
          
          // Delete the arena room
          await databases.deleteDocument(
            databaseId: 'arena_db',
            collectionId: 'arena_rooms',
            documentId: roomId,
          );
          
          totalDeleted++;
          AppLogger().info('Deleted arena room: $roomId');
        } catch (e) {
          AppLogger().error('Error deleting room $roomId: $e');
        }
      }

      AppLogger().debug('🗑️ DELETION COMPLETED: $totalDeleted rooms, $participationsDeleted participations DELETED');
    } catch (e) {
      AppLogger().error('Error during deletion: $e');
      rethrow;
    }
  }

  Future<void> forceCloseArenaRoom(String roomId) async {
    try {
      AppLogger().debug('🚨 FORCE CLOSING arena room: $roomId');
      
      // Get all participants for this room
      final participants = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.equal('roomId', roomId),
        ],
      );

      AppLogger().debug('🚨 Found ${participants.documents.length} participants to remove');

      // Mark all participants as inactive immediately
      for (final participant in participants.documents) {
        await databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          documentId: participant.$id,
          data: {
            'isActive': false,
            'leftAt': DateTime.now().toIso8601String(),
          },
        );
        AppLogger().info('Removed participant: ${participant.data['userId']} (${participant.data['role']})');
      }
      
      // Mark room as force closed
      await databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'status': 'force_closed',
          'endedAt': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger().info('FORCE CLOSED arena room $roomId - all participants removed');
    } catch (e) {
      AppLogger().error('Error force closing arena room: $e');
      rethrow;
    }
  }

  Future<String> createManualArenaRoom({
    required String creatorId,
    required String topic,
    String? description,
    int maxParticipants = 1000, // Allow unlimited participants (high limit)
  }) async {
    try {
      // Enhanced duplicate prevention - check for recent rooms by the same creator
      final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String();
      
      // First check: Any waiting rooms by this creator in the last minute
      final recentCreatorRooms = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.equal('userId', creatorId),
          Query.equal('role', 'moderator'),
          Query.greaterThan('\$createdAt', oneMinuteAgo),
          Query.limit(10),
        ],
      );
      
      // Check if any of these rooms are still waiting
      for (final participation in recentCreatorRooms.documents) {
        final roomId = participation.data['roomId'];
        try {
          final room = await databases.getDocument(
            databaseId: 'arena_db',
            collectionId: 'arena_rooms',
            documentId: roomId,
          );
          
          // If room is still waiting and has similar topic, reuse it
          if (room.data['status'] == 'waiting') {
            final roomTopic = room.data['topic'] ?? '';
            final roomChallengeId = room.data['challengeId'] ?? '';
            
            // For manual rooms (empty challengeId) with same or similar topic
            if (roomChallengeId.isEmpty && 
                (roomTopic.toLowerCase() == topic.toLowerCase() || 
                 roomTopic.isEmpty)) {
              AppLogger().info('Reusing existing manual arena room: $roomId');
              return roomId;
            }
          }
        } catch (e) {
          // Room might have been deleted, continue checking
          AppLogger().debug('Room $roomId not found during duplicate check: $e');
        }
      }
      
      // Second check: Any rooms with exact same topic in last 5 minutes
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String();
      final existingRooms = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        queries: [
          Query.equal('challengeId', ''), // Manual rooms have empty challengeId
          Query.equal('topic', topic),
          Query.equal('status', 'waiting'),
          Query.greaterThan('\$createdAt', fiveMinutesAgo),
          Query.limit(3),
        ],
      );
      
      // Check if creator is moderator in any of these rooms
      for (final room in existingRooms.documents) {
        final roomId = room.$id;
        
        final participants = await databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          queries: [
            Query.equal('roomId', roomId),
            Query.equal('userId', creatorId),
            Query.equal('role', 'moderator'),
          ],
        );
        
        if (participants.documents.isNotEmpty) {
          AppLogger().info('Using existing manual arena room with same topic: $roomId');
          return roomId;
        }
      }
      
      // Use Appwrite's guaranteed unique ID instead of custom generation
      final roomId = 'arena_${ID.unique()}';
      
      AppLogger().info('Attempting to create room with ID: $roomId');
      
      final now = DateTime.now();
      
      // ATOMIC duplicate prevention - check for recent rooms by this user with same topic
      final recentThreshold = now.subtract(const Duration(minutes: 1)).toIso8601String();
      
      try {
        final recentRooms = await databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'arena_rooms',
          queries: [
            Query.equal('challengeId', ''), // Manual rooms only
            Query.equal('status', 'waiting'),
            Query.greaterThan('\$createdAt', recentThreshold),
            Query.limit(50),
          ],
        );
        
        // Check if any of these rooms have the same creator and topic
        for (final room in recentRooms.documents) {
          final roomTopic = room.data['topic']?.toString().toLowerCase() ?? '';
          final normalizedTopic = topic.toLowerCase();
          
          // Get participants to check if this user is the moderator
          try {
            final participants = await databases.listDocuments(
              databaseId: 'arena_db',
              collectionId: 'arena_participants',
              queries: [
                Query.equal('roomId', room.$id),
                Query.equal('userId', creatorId),
                Query.equal('role', 'moderator'),
              ],
            );
            
            if (participants.documents.isNotEmpty && roomTopic == normalizedTopic) {
              AppLogger().warning('Found duplicate room by same user with same topic: ${room.$id}');
              return room.$id; // Return existing room instead of creating duplicate
            }
          } catch (e) {
            // Continue checking other rooms
            AppLogger().debug('Error checking participants for room ${room.$id}: $e');
          }
        }
      } catch (e) {
        AppLogger().warning('Error checking for duplicate rooms: $e');
        // Continue with creation if check fails
      }
      
      // Final safety check - verify room ID doesn't already exist
      try {
        final existingRoom = await databases.getDocument(
          databaseId: 'arena_db',
          collectionId: 'arena_rooms',
          documentId: roomId,
        );
        if (existingRoom.data['status'] == 'waiting') {
          AppLogger().info('Room with ID $roomId already exists, reusing it');
          return roomId;
        }
      } catch (e) {
        // Room doesn't exist, which is what we want
        AppLogger().debug('Room $roomId does not exist, proceeding with creation');
      }
      
      // Parse team size from metadata in description (from Arena Lobby)
      int teamSize = 1; // Default to 1v1
      if (description != null && description.contains('[METADATA]')) {
        try {
          final metadataStartIndex = description.indexOf('[METADATA]') + '[METADATA]'.length;
          final metadataString = description.substring(metadataStartIndex);
          // Parse the metadata string (it's formatted like a Map toString())
          if (metadataString.contains('teamSize: 2v2')) {
            teamSize = 2; // 2v2 team
          } else if (metadataString.contains('teamSize: 1v1')) {
            teamSize = 1; // 1v1 team  
          }
          AppLogger().info('Parsed team size from metadata: $teamSize (${teamSize}v$teamSize)');
        } catch (e) {
          AppLogger().warning('Failed to parse team size from metadata: $e');
          // Keep default teamSize = 1
        }
      }

      try {
        await databases.createDocument(
          databaseId: 'arena_db',
          collectionId: 'arena_rooms',
          documentId: roomId,
          data: {
            'challengeId': '', // Empty for manual rooms
            'challengerId': '', // Empty for manual rooms
            'challengedId': '', // Empty for manual rooms
            'topic': topic,
            'description': description ?? '',
            'status': 'waiting', // waiting, active, judging, completed
            'startedAt': null,
            'endedAt': null,
            'winner': null,
            'judgingComplete': false,
            'judgingEnabled': false,
            'totalJudges': 0,
            'judgesSubmitted': 0,
            'teamSize': teamSize, // CRITICAL: Store team size for 2v2 support
            'moderatorId': creatorId,
          },
        );
      } catch (e) {
        // Handle document already exists error
        if (e.toString().contains('document_already_exists') || 
            e.toString().contains('Document with the requested ID already exists')) {
          AppLogger().warning('Room $roomId already exists, attempting to reuse it');
          try {
            final existingRoom = await databases.getDocument(
              databaseId: 'arena_db',
              collectionId: 'arena_rooms',
              documentId: roomId,
            );
            if (existingRoom.data['status'] == 'waiting') {
              AppLogger().info('Successfully reusing existing room: $roomId');
              return roomId;
            }
          } catch (getError) {
            AppLogger().error('Error retrieving existing room: $getError');
          }
        }
        // Re-throw if it's not a duplicate error or we can't handle it
        rethrow;
      }

      // Automatically assign creator as moderator
      final assignedRole = await assignArenaRole(
        roomId: roomId,
        userId: creatorId,
        role: 'moderator',
      );
      AppLogger().info('📝 Creator assigned as: $assignedRole');

      // Initialize Firebase timer for this room
      try {
        final firebaseTimer = FirebaseArenaTimerService();
        await firebaseTimer.initializeArenaTimer(roomId);
        AppLogger().info('🔥 Firebase timer initialized for manual arena: $roomId');
      } catch (e) {
        AppLogger().warning('Failed to initialize Firebase timer for manual arena: $e');
        // Don't fail room creation if Firebase timer fails
      }

      AppLogger().info('Manual arena room created with moderator: $roomId');
      return roomId;
    } catch (e) {
      AppLogger().error('Error creating manual Arena room: $e');
      rethrow;
    }
  }

  /// Create a scheduled arena room that doesn't start immediately
  Future<String> createScheduledArenaRoom({
    required String creatorId,
    required String topic,
    String? description,
    required DateTime scheduledTime,
  }) async {
    try {
      // Use Appwrite's guaranteed unique ID
      final roomId = 'scheduled_${ID.unique()}';
      
      AppLogger().info('Creating scheduled arena room with ID: $roomId for time: $scheduledTime');
      
      await databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: roomId,
        data: {
          'challengeId': '', // Empty for manual rooms
          'challengerId': '', // Empty for manual rooms
          'challengedId': '', // Empty for manual rooms
          'topic': topic,
          'description': description ?? '',
          'status': 'scheduled', // scheduled status - not waiting yet
          'startedAt': null,
          'endedAt': null,
          'winner': null,
          'judgingComplete': false,
          'judgingEnabled': false,
          'totalJudges': 0,
          'judgesSubmitted': 0,
        },
      );
      
      // Assign creator as moderator
      final assignedRole = await assignArenaRole(
        roomId: roomId,
        userId: creatorId,
        role: 'moderator',
      );
      AppLogger().info('📅 Scheduled room creator assigned as: $assignedRole');
      
      AppLogger().info('Scheduled arena room created: $roomId for $scheduledTime');
      return roomId;
    } catch (e) {
      AppLogger().error('Error creating scheduled Arena room: $e');
      rethrow;
    }
  }

  /// Simple arena room creation method with enhanced duplicate prevention
  Future<String> createSimpleArenaRoom({
    required String creatorId,
    required String topic,
    String? description,
  }) async {
    // Use a deterministic document ID for waiting rooms
    final documentId = 'waiting_$creatorId';

    // Global lock check - prevent ANY room creation by this user
    if (_roomCreationLocks[creatorId] == true) {
      AppLogger().warning('🚫 GLOBAL LOCK: User $creatorId already creating a room, blocking request');
      // Try to fetch the existing room by deterministic ID
      try {
        final existingRoom = await databases.getDocument(
          databaseId: 'arena_db',
          collectionId: 'arena_rooms',
          documentId: documentId,
        );
          return existingRoom.$id;
      } catch (_) {}
      throw Exception('Room creation in progress, please wait');
    }
    _roomCreationLocks[creatorId] = true;
    try {
      AppLogger().info('🔒 GLOBAL LOCK: Set for user $creatorId');
      // Try to fetch the existing room by deterministic ID
      try {
        final existingRoom = await databases.getDocument(
          databaseId: 'arena_db',
          collectionId: 'arena_rooms',
          documentId: documentId,
        );
           AppLogger().warning('🚫 DUPLICATE PREVENTION: User already has waiting room: ${existingRoom.$id}');
           return existingRoom.$id;
      } catch (_) {
        // Not found, continue to create
      }
      AppLogger().info('✅ DUPLICATE PREVENTION: No existing waiting room found for $creatorId');
      // Create the room with deterministic ID
      await databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        documentId: documentId,
        data: {
          'challengeId': '',
          'challengerId': '',
          'challengedId': '',
          'topic': topic,
          'description': description ?? '',
          'status': 'waiting',
          'startedAt': null,
          'endedAt': null,
          'winner': null,
          'judgingComplete': false,
          'judgingEnabled': false,
          'totalJudges': 0,
          'judgesSubmitted': 0,
          'moderatorId': creatorId,
          'teamSize': 1, // Simple rooms only support 1v1
        },
      );
      AppLogger().info('✅ Room document created: $documentId');
      
      // CRITICAL: Assign creator as moderator IMMEDIATELY
      // This prevents cleanup functions from seeing the room as having no moderator
      final assignedRole = await assignArenaRole(
        roomId: documentId,
        userId: creatorId,
        role: 'moderator',
      );
      AppLogger().info('⚡ Simple room creator assigned as: $assignedRole');
      AppLogger().info('✅ Moderator role assigned and confirmed before returning');
      
      // Initialize Firebase timer
      try {
        final firebaseTimer = FirebaseArenaTimerService();
        await firebaseTimer.initializeArenaTimer(documentId);
        AppLogger().info('✅ Firebase timer initialized');
      } catch (e) {
        AppLogger().warning('⚠️ Failed to initialize Firebase timer: $e');
      }
      
      // Brief delay to ensure all room setup operations are fully propagated
      await Future.delayed(const Duration(milliseconds: 500));
      
      AppLogger().info('🎉 Room creation completed successfully: $documentId');
      return documentId;
    } catch (e) {
      AppLogger().error('❌ Error creating room: $e');
      rethrow;
    } finally {
      _roomCreationLocks.remove(creatorId);
      AppLogger().info('🔓 GLOBAL LOCK: Released for user $creatorId');
    }
  }

  Future<List<Map<String, dynamic>>> getJoinableArenaRooms() async {
    try {
      final response = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_rooms',
        queries: [
          Query.equal('status', 'waiting'), // Only waiting rooms can be joined
          Query.equal('challengeId', ''), // Manual rooms have empty challengeId
          Query.orderDesc('\$createdAt'),
          Query.limit(20),
        ],
      );

      List<Map<String, dynamic>> joinableRooms = [];
      
      for (var doc in response.documents) {
        final roomData = _safeDocumentToMap(doc);

        // Only include manual rooms (empty challengeId indicates manual room)
        final challengeId = doc.data['challengeId'] ?? '';
        if (challengeId.isNotEmpty) {
          continue; // Skip challenge-based rooms
        }

        // Get participant count for this room
        final participants = await databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          queries: [
            Query.equal('roomId', doc.$id),
            Query.equal('isActive', true),
          ],
        );

        roomData['currentParticipants'] = participants.documents.length;
        roomData['participants'] = participants.documents.map((p) => _safeDocumentToMap(p)).toList();
        
        // Only include rooms that aren't full (using default max of 8 since field doesn't exist)
        const maxParticipants = 1000; // Allow unlimited participants
        if (participants.documents.length < maxParticipants) {
          joinableRooms.add(roomData);
        }
      }

      return joinableRooms;
    } catch (e) {
      AppLogger().error('Error getting joinable arena rooms: $e');
      return [];
    }
  }

  Future<void> joinArenaRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      // Check if user is already in the room
      final existingParticipants = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
          Query.equal('isActive', true),
        ],
      );

      if (existingParticipants.documents.isNotEmpty) {
        AppLogger().warning('User already in arena room: $roomId');
        return; // User already in room
      }

      // Get user profile
      final userProfile = await getUserProfile(userId);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      // Join as audience by default (moderator can assign roles later)
      final assignedRole = await assignArenaRole(
        roomId: roomId,
        userId: userId,
        role: 'audience',
      );
      AppLogger().info('👥 Joined user assigned as: $assignedRole');

      AppLogger().info('User $userId joined arena room $roomId as audience');
    } catch (e) {
      AppLogger().error('Error joining arena room: $e');
      rethrow;
    }
  }

  Future<void> cleanupUnusedDiscussionRooms() async {
    try {
      AppLogger().debug('🧹 Starting cleanup of unused discussion rooms...');
      
      // Get all active discussion rooms
      final discussionRooms = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomsCollection,
        queries: [
          Query.equal('type', 'discussion'),
          Query.equal('status', 'active'),
          Query.limit(100),
        ],
      );

      int cleanedRooms = 0;
      int cleanedParticipations = 0;

      for (final room in discussionRooms.documents) {
        final roomId = room.$id;
        final createdAt = DateTime.parse(room.$createdAt);
        final roomAge = DateTime.now().difference(createdAt);
        
        // Get active participants for this room
        final participants = await databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: AppwriteConstants.roomParticipantsCollection,
          queries: [
            Query.equal('roomId', roomId),
            Query.equal('status', 'joined'),
          ],
        );

        // Check if room should be cleaned up
        bool shouldCleanup = false;
        String reason = '';

        // Cleanup criteria for discussion rooms:
        // 1. Room is older than 4 hours with no active participants
        // 2. Room is older than 24 hours regardless of participant count
        // 3. Room has been empty (no participants) for more than 30 minutes
        // 4. Room has only 1 participant (likely the creator) for more than 2 hours
        
        if (roomAge.inHours >= 24) {
          shouldCleanup = true;
          reason = 'older than 24 hours';
        } else if (roomAge.inHours >= 4 && participants.documents.isEmpty) {
          shouldCleanup = true;
          reason = 'older than 4 hours with no participants';
        } else if (roomAge.inMinutes >= 30 && participants.documents.isEmpty) {
          shouldCleanup = true;
          reason = 'empty for 30+ minutes';
        } else if (roomAge.inHours >= 2 && participants.documents.length <= 1) {
          shouldCleanup = true;
          reason = 'only 1 or fewer participants for 2+ hours';
        }

        if (shouldCleanup) {
          AppLogger().debug('🧹 Cleaning up discussion room $roomId ($reason)');
          
          // Mark all participants as left
          for (final participant in participants.documents) {
            await databases.updateDocument(
              databaseId: 'arena_db',
              collectionId: AppwriteConstants.roomParticipantsCollection,
              documentId: participant.$id,
              data: {
                'status': 'left',
                'leftAt': DateTime.now().toIso8601String(),
              },
            );
            cleanedParticipations++;
          }
          
          // Mark discussion room as ended
          await databases.updateDocument(
            databaseId: 'arena_db',
            collectionId: AppwriteConstants.roomsCollection,
            documentId: roomId,
            data: {
              'status': 'ended',
              'endedAt': DateTime.now().toIso8601String(),
            },
          );
          
          cleanedRooms++;
          AppLogger().info('Cleaned up discussion room: $roomId');
        }
      }

      AppLogger().debug('🧹 Discussion room cleanup completed: $cleanedRooms rooms, $cleanedParticipations participations');
    } catch (e) {
      AppLogger().error('Error during discussion room cleanup: $e');
    }
  }

  Future<void> forceCleanupAllOldDiscussionRooms() async {
    try {
      AppLogger().debug('🚨 FORCE CLEANUP: Removing ALL old discussion rooms...');
      
      // Get ALL discussion rooms
      final allRooms = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomsCollection,
        queries: [
          Query.equal('type', 'discussion'),
          Query.limit(100),
        ],
      );

      int totalCleaned = 0;
      int participationsCleaned = 0;

      for (final room in allRooms.documents) {
        final roomId = room.$id;
        final createdAt = DateTime.parse(room.$createdAt);
        final roomAge = DateTime.now().difference(createdAt);
        
        // Clean up any discussion room older than 2 hours, regardless of status
        if (roomAge.inHours >= 2) {
          AppLogger().debug('🚨 Force cleaning discussion room $roomId (age: ${roomAge.inHours} hours)');
          
          // Get ALL participants for this room
          final allParticipants = await databases.listDocuments(
            databaseId: 'arena_db',
            collectionId: AppwriteConstants.roomParticipantsCollection,
            queries: [
              Query.equal('roomId', roomId),
            ],
          );

          // Mark all participants as left
          for (final participant in allParticipants.documents) {
            await databases.updateDocument(
              databaseId: 'arena_db',
              collectionId: AppwriteConstants.roomParticipantsCollection,
              documentId: participant.$id,
              data: {
                'status': 'left',
                'leftAt': DateTime.now().toIso8601String(),
              },
            );
            participationsCleaned++;
          }
          
          // Mark room as force cleaned
          await databases.updateDocument(
            databaseId: 'arena_db',
            collectionId: AppwriteConstants.roomsCollection,
            documentId: roomId,
            data: {
              'status': 'force_cleaned',
              'endedAt': DateTime.now().toIso8601String(),
            },
          );
          
          totalCleaned++;
        }
      }

      AppLogger().debug('🚨 FORCE CLEANUP COMPLETED: $totalCleaned discussion rooms, $participationsCleaned participations');
    } catch (e) {
      AppLogger().error('Error during force cleanup: $e');
      rethrow;
    }
  }

  Future<void> oneTimeCleanupOldDiscussionRooms() async {
    try {
      AppLogger().debug('🧹 ONE-TIME CLEANUP: Cleaning all existing discussion rooms...');
      
      // Get ALL discussion rooms (regardless of status)
      final allDiscussionRooms = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomsCollection,
        queries: [
          Query.equal('type', 'discussion'),
          Query.limit(100),
        ],
      );

      int cleanedRooms = 0;
      int cleanedParticipations = 0;

      for (final room in allDiscussionRooms.documents) {
        final roomId = room.$id;
        final roomTitle = room.data['title'] ?? 'Unknown Room';
        final roomStatus = room.data['status'] ?? 'active';
        final createdAt = DateTime.parse(room.$createdAt);
        final roomAge = DateTime.now().difference(createdAt);
        
        // Skip already cleaned rooms
        if (roomStatus == 'ended' || roomStatus == 'force_cleaned') {
          AppLogger().debug('⏭️ Skipping already cleaned room: $roomId');
          continue;
        }
        
        AppLogger().debug('🔍 Processing room $roomId: "$roomTitle" (Age: ${roomAge.inHours}h ${roomAge.inMinutes % 60}m, Status: $roomStatus)');
        
        // For one-time cleanup, clean up any room older than 1 hour (very aggressive)
        if (roomAge.inHours >= 1) {
          AppLogger().debug('🧹 One-time cleaning room: older than 1 hour');
          
          // Get ALL participants for this room
          final allParticipants = await databases.listDocuments(
            databaseId: 'arena_db',
            collectionId: AppwriteConstants.roomParticipantsCollection,
            queries: [
              Query.equal('roomId', roomId),
            ],
          );

          // Mark all participants as left
          for (final participant in allParticipants.documents) {
            if (participant.data['status'] != 'left') {
              await databases.updateDocument(
                databaseId: 'arena_db',
                collectionId: AppwriteConstants.roomParticipantsCollection,
                documentId: participant.$id,
                data: {
                  'status': 'left',
                  'leftAt': DateTime.now().toIso8601String(),
                },
              );
              cleanedParticipations++;
            }
          }
          
          // Mark room as ended with one-time cleanup flag
          await databases.updateDocument(
            databaseId: 'arena_db',
            collectionId: AppwriteConstants.roomsCollection,
            documentId: roomId,
            data: {
              'status': 'one_time_cleaned',
              'endedAt': DateTime.now().toIso8601String(),
            },
          );
          
          cleanedRooms++;
          AppLogger().info('One-time cleaned room: $roomId');
        } else {
          AppLogger().info('Room is recent, keeping it: $roomId');
        }
      }

      AppLogger().debug('🎉 ONE-TIME CLEANUP COMPLETED: $cleanedRooms rooms, $cleanedParticipations participations');
      AppLogger().debug('📊 Total rooms processed: ${allDiscussionRooms.documents.length}');
      AppLogger().debug('🏃 Active rooms remaining: ${allDiscussionRooms.documents.length - cleanedRooms}');
    } catch (e) {
      AppLogger().error('Error during one-time cleanup: $e');
      rethrow;
    }
  }

  // GIFT SYSTEM METHODS

  /// Send a gift from one user to another in a room
  Future<bool> sendGift({
    required String giftId,
    required String senderId,
    required String recipientId,
    required String roomId,
    required int cost,
    String? message,
  }) async {
    try {
      AppLogger().debug('🎁 DEBUG: Starting gift send process...');
      AppLogger().debug('🎁 DEBUG: Database ID: gifts_db');
      AppLogger().debug('🎁 DEBUG: Collection ID: gift_transactions');
      AppLogger().debug('🎁 DEBUG: Gift ID: $giftId');
      AppLogger().debug('🎁 DEBUG: Sender: $senderId');
      AppLogger().debug('🎁 DEBUG: Recipient: $recipientId');
      AppLogger().debug('🎁 DEBUG: Cost: $cost');

      // Check sender's coin balance
      final senderProfile = await getUserProfile(senderId);
      if (senderProfile == null || senderProfile.coinBalance < cost) {
        throw Exception('Insufficient coin balance');
      }

      AppLogger().debug('🎁 DEBUG: Sender has sufficient balance: ${senderProfile.coinBalance}');
      AppLogger().debug('🎁 DEBUG: Attempting to create document...');

      // Create gift transaction
      await databases.createDocument(
        databaseId: 'gifts_db',
        collectionId: 'gift_transactions',
        documentId: ID.unique(),
        data: {
          'giftId': giftId,
          'senderId': senderId,
          'recipientId': recipientId,
          'roomId': roomId,
          'cost': cost,
          'message': message,
          'sentAt': DateTime.now().toIso8601String(),
        },
      );

      // Update sender's profile (deduct coins, increment gifts sent)
      await updateUserProfile(
        userId: senderId,
        coinBalance: senderProfile.coinBalance - cost,
        totalGiftsSent: senderProfile.totalGiftsSent + 1,
      );

      // Update recipient's profile (increment gifts received, add reputation)
      final recipientProfile = await getUserProfile(recipientId);
      if (recipientProfile != null) {
        // Update recipient's gift count (reputation is now controlled by moderators only)
        await updateUserProfile(
          userId: recipientId,
          totalGiftsReceived: recipientProfile.totalGiftsReceived + 1,
        );
      }

      AppLogger().info('Gift sent: $giftId from $senderId to $recipientId (cost: $cost coins)');
      return true;
    } catch (e) {
      AppLogger().error('Error sending gift: $e');
      rethrow;
    }
  }

  /// Get gift transactions for a room (for notifications/feed)
  Future<List<GiftTransaction>> getRoomGiftTransactions(String roomId, {int limit = 50}) async {
    try {
      final response = await databases.listDocuments(
        databaseId: 'gifts_db',
        collectionId: 'gift_transactions',
        queries: [
          Query.equal('roomId', roomId),
          Query.orderDesc('\$createdAt'),
          Query.limit(limit),
        ],
      );

      return response.documents.map((doc) {
        final data = Map<String, dynamic>.from(doc.data);
        data['id'] = doc.$id;
        return GiftTransaction.fromMap(data);
      }).toList();
    } catch (e) {
      AppLogger().error('Error getting room gift transactions: $e');
      return [];
    }
  }

  /// Get user's gift sending history
  Future<List<GiftTransaction>> getUserGiftsSent(String userId, {int limit = 20}) async {
    try {
      final response = await databases.listDocuments(
        databaseId: 'gifts_db',
        collectionId: 'gift_transactions',
        queries: [
          Query.equal('senderId', userId),
          Query.orderDesc('\$createdAt'),
          Query.limit(limit),
        ],
      );

      return response.documents.map((doc) {
        final data = Map<String, dynamic>.from(doc.data);
        data['id'] = doc.$id;
        return GiftTransaction.fromMap(data);
      }).toList();
    } catch (e) {
      AppLogger().error('Error getting user gifts sent: $e');
      return [];
    }
  }

  /// Get user's gift receiving history
  Future<List<GiftTransaction>> getUserGiftsReceived(String userId, {int limit = 20}) async {
    try {
      final response = await databases.listDocuments(
        databaseId: 'gifts_db',
        collectionId: 'gift_transactions',
        queries: [
          Query.equal('recipientId', userId),
          Query.orderDesc('\$createdAt'),
          Query.limit(limit),
        ],
      );

      return response.documents.map((doc) {
        final data = Map<String, dynamic>.from(doc.data);
        data['id'] = doc.$id;
        return GiftTransaction.fromMap(data);
      }).toList();
    } catch (e) {
      AppLogger().error('Error getting user gifts received: $e');
      return [];
    }
  }

  /// Add coins to user's balance (for admin or reward purposes)
  Future<bool> addCoinsToUser(String userId, int amount, {String? reason}) async {
    try {
      final userProfile = await getUserProfile(userId);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      await updateUserProfile(
        userId: userId,
        coinBalance: userProfile.coinBalance + amount,
      );

      AppLogger().info('Added $amount coins to user $userId (reason: ${reason ?? 'unspecified'})');
      return true;
    } catch (e) {
      AppLogger().error('Error adding coins to user: $e');
      return false;
    }
  }

  // ===== PING REQUEST METHODS =====

  /// Create a ping request to a moderator or judge
  Future<String?> createPingRequest({
    required String fromUserId,
    required String fromUsername,
    required String toUserId,
    required String toUsername,
    required String roleType, // 'moderator' or 'judge'
    required String debateTitle,
    required String debateDescription,
    required String category,
    required String arenaRoomId,
    String? message,
  }) async {
    try {
      final pingData = {
        'fromUserId': fromUserId,
        'fromUsername': fromUsername,
        'toUserId': toUserId,
        'toUsername': toUsername,
        'roleType': roleType,
        'debateTitle': debateTitle,
        'debateDescription': debateDescription,
        'category': category,
        'scheduledTime': DateTime.now().toIso8601String(),
        'status': 'pending',
        'message': message,
        'createdAt': DateTime.now().toIso8601String(),
        'arenaRoomId': arenaRoomId,
      };

      final response = await databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.pingRequestsCollection,
        documentId: ID.unique(),
        data: pingData,
      );

      AppLogger().info('Created ping request: ${response.$id}');
      return response.$id;
    } catch (e) {
      AppLogger().error('Error creating ping request: $e');
      return null;
    }
  }

  /// Get pending ping requests for a user
  Future<List<Map<String, dynamic>>> getPendingPingRequests(String userId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.pingRequestsCollection,
        queries: [
          Query.equal('toUserId', userId),
          Query.equal('status', 'pending'),
          Query.orderDesc('\$createdAt'),
          Query.limit(10),
        ],
      );

      return response.documents.map((doc) {
        final data = Map<String, dynamic>.from(doc.data);
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      AppLogger().error('Error getting pending ping requests: $e');
      return [];
    }
  }

  /// Update ping request status
  Future<bool> updatePingRequestStatus({
    required String pingId,
    required String status,
    String? response,
  }) async {
    try {
      await databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.pingRequestsCollection,
        documentId: pingId,
        data: {
          'status': status,
          'response': response,
          'respondedAt': DateTime.now().toIso8601String(),
        },
      );

      AppLogger().info('Updated ping request $pingId status to $status');
      return true;
    } catch (e) {
      AppLogger().error('Error updating ping request status: $e');
      return false;
    }
  }

  /// Subscribe to ping requests for a user
  RealtimeSubscription subscribeToPingRequests(String userId, Function(RealtimeMessage) callback) {
    final subscription = realtime.subscribe([
      'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.pingRequestsCollection}.documents'
    ]);

    subscription.stream.listen((response) {
      try {
        // Filter for documents where toUserId matches the current user
        final data = response.payload;
        if (data['toUserId'] == userId && data['status'] == 'pending') {
          callback(response);
        }
      } catch (e) {
        AppLogger().error('Error processing ping request subscription: $e');
      }
    });

    return subscription;
  }

  /// Clean up expired ping requests (older than 2 minutes)
  Future<void> cleanupExpiredPingRequests() async {
    try {
      final twoMinutesAgo = DateTime.now().subtract(const Duration(minutes: 2));
      
      final response = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.pingRequestsCollection,
        queries: [
          Query.equal('status', 'pending'),
          Query.lessThan('createdAt', twoMinutesAgo.toIso8601String()),
        ],
      );

      for (final doc in response.documents) {
        await databases.updateDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.pingRequestsCollection,
          documentId: doc.$id,
          data: {
            'status': 'expired',
            'response': 'Request expired',
            'respondedAt': DateTime.now().toIso8601String(),
          },
        );
      }

      AppLogger().info('Cleaned up ${response.documents.length} expired ping requests');
    } catch (e) {
      AppLogger().error('Error cleaning up expired ping requests: $e');
    }
  }
} 