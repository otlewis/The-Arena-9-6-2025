import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart';
import '../constants/appwrite.dart';
import 'dart:convert';
import '../models/user_profile.dart';
import '../models/gift_transaction.dart';
import '../core/logging/app_logger.dart';
import 'firebase_arena_timer_service.dart';

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
  }

  // Getter for realtime access
  Realtime get realtimeInstance => realtime;

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

  /// Test method specifically for debugging Chrome user profile loading issues
  /// This method provides comprehensive debugging for troubleshooting
  Future<void> debugUserProfileLoading(String userId) async {
    AppLogger().debug('🔍 DEBUG: Starting comprehensive user profile loading test');
    AppLogger().debug('🔍 Target User ID: $userId');
    
    // Test authentication first
    AppLogger().debug('🔍 Step 1: Testing authentication...');
    final currentUser = await getCurrentUser();
    
    // Test user profile loading
    AppLogger().debug('🔍 Step 2: Testing user profile loading...');
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

  // Auth Methods
  Future<models.User> createAccount({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final user = await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );
      return user;
    } catch (e) {
      AppLogger().debug('Error creating account: $e');
      rethrow;
    }
  }

  Future<models.Session> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final session = await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      return session;
    } catch (e) {
      AppLogger().debug('Error signing in: $e');
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

  // User Methods
  Future<models.User?> getCurrentUser() async {
    AppLogger().debug('========== getCurrentUser START ==========');
    AppLogger().debug('getCurrentUser called');
    AppLogger().debug('Platform: ${_getBrowserInfo()}');
    
    // Log Chrome-specific debugging info
    _logChromeSpecificDebugInfo();
    
    try {
      AppLogger().debug('Attempting to get current user from account...');
      final user = await account.get();
      
      AppLogger().debug('Current user retrieved successfully:');
      AppLogger().debug('  - User ID: ${user.$id}');
      AppLogger().debug('  - User Name: ${user.name}');
      AppLogger().debug('  - User Email: ${user.email}');
      AppLogger().debug('  - Email Verified: ${user.emailVerification}');
      AppLogger().debug('  - Registration: ${user.registration}');
      
      AppLogger().debug('========== getCurrentUser SUCCESS ==========');
      return user;
    } catch (e, stackTrace) {
      // Only log unexpected errors, not normal unauthorized scope for guests
      if (!e.toString().contains('general_unauthorized_scope') && !e.toString().contains('missing scope')) {
        AppLogger().debug('ERROR in getCurrentUser:');
        AppLogger().debug('Error type: ${e.runtimeType}');
        AppLogger().debug('Error message: $e');
        AppLogger().debug('Stack trace: $stackTrace');
        
        // Chrome/Web-specific debugging
        if (kIsWeb) {
          AppLogger().debug('Web-specific authentication error analysis:');
          AppLogger().debug('  - This authentication error occurred on web platform');
          AppLogger().debug('  - Chrome may have specific session/cookie handling issues');
          AppLogger().debug('  - Check if Chrome is blocking third-party cookies');
          AppLogger().debug('  - Verify Chrome local storage and session storage');
          
          if (e.toString().contains('network') || e.toString().contains('fetch')) {
            AppLogger().debug('  - NETWORK/FETCH ERROR in authentication - Chrome security policy issue?');
          }
        }
        AppLogger().debug('========== getCurrentUser FAILED ==========');
      } else {
        AppLogger().debug('User is not authenticated (expected for guest users)');
        AppLogger().debug('========== getCurrentUser NOT_AUTHENTICATED ==========');
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
  }) async {
    try {
      await databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
        data: {
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
        },
      );
    } catch (e) {
      AppLogger().debug('Error creating user profile: $e');
      rethrow;
    }
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    // Debug: Log method entry with platform information
    AppLogger().debug('========== getUserProfile START ==========');
    AppLogger().debug('getUserProfile called with userId: $userId');
    AppLogger().debug('Platform: ${_getBrowserInfo()}');
    
    // Log Chrome-specific debugging info
    _logChromeSpecificDebugInfo();
    
    try {
      AppLogger().debug('Attempting to fetch user profile from database...');
      AppLogger().debug('Database ID: arena_db, Collection ID: users, Document ID: $userId');
      
      final response = await databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: userId,
      );
      
      AppLogger().debug('Raw response received from Appwrite:');
      AppLogger().debug('Response ID: ${response.$id}');
      AppLogger().debug('Response createdAt: ${response.$createdAt}');
      AppLogger().debug('Response updatedAt: ${response.$updatedAt}');
      AppLogger().debug('Response data keys: ${response.data.keys.toList()}');
      AppLogger().debug('Response data values preview: ${response.data.toString().length > 500 ? response.data.toString().substring(0, 500) + "..." : response.data.toString()}');
      
      final profileData = Map<String, dynamic>.from(response.data);
      AppLogger().debug('Profile data after Map.from conversion - keys: ${profileData.keys.toList()}');
      
      profileData['id'] = response.$id;
      profileData['createdAt'] = response.$createdAt;
      profileData['updatedAt'] = response.$updatedAt;
      
      AppLogger().debug('Profile data after adding metadata - final keys: ${profileData.keys.toList()}');
      AppLogger().debug('About to create UserProfile from map...');
      
      final userProfile = UserProfile.fromMap(profileData);
      AppLogger().debug('UserProfile successfully created:');
      AppLogger().debug('  - ID: ${userProfile.id}');
      AppLogger().debug('  - Name: ${userProfile.name}');
      AppLogger().debug('  - Email: ${userProfile.email}');
      AppLogger().debug('  - Avatar: ${userProfile.avatar}');
      AppLogger().debug('  - Created at: ${userProfile.createdAt}');
      
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
    int? reputation,
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
      if (reputation != null) updateData['reputation'] = reputation;

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
          'memberCount': 1, // Creator is first member
          'isPublic': true,
          'category': 'General',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
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
      
      return response.documents.map((doc) {
        final clubData = Map<String, dynamic>.from(doc.data);
        clubData['id'] = doc.$id; // Add the document ID
        clubData['createdAt'] = doc.$createdAt;
        clubData['updatedAt'] = doc.$updatedAt;
        return clubData;
      }).toList().cast<Map<String, dynamic>>();
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
      
      return response.documents.map((doc) {
        final membershipData = Map<String, dynamic>.from(doc.data);
        membershipData['id'] = doc.$id;
        return membershipData;
      }).toList().cast<Map<String, dynamic>>();
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
      final response = await databases.createDocument(
        databaseId: 'arena_db',
        collectionId: AppwriteConstants.roomsCollection,
        documentId: ID.unique(),
        data: {
          'title': title,
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
      );
      
      // Create initial room participant entry for the creator as moderator
      await joinRoom(
        roomId: response.$id,
        userId: createdBy,
        role: 'moderator',
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
          Query.equal('status', 'active'),
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
          collectionId: 'room_participants',
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
        collectionId: 'room_participants',
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

  Future<void> joinRoom({
    required String roomId,
    required String userId,
    String role = 'audience',
  }) async {
    try {
      // Check if user is already in the room
      final existingParticipants = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'room_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
          Query.equal('status', 'joined'),
        ],
      );

      if (existingParticipants.documents.isNotEmpty) {
        return; // User already in room
      }

      // Get user info for participant record
      final user = await getCurrentUser();
      
      await databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'room_participants',
        documentId: ID.unique(),
        data: {
          'userId': userId,
          'roomId': roomId,
          'userName': user?.name ?? 'User',
          'userAvatar': user?.prefs.data['avatar'],
          'role': role, // Store role as-is (audience, moderator, speaker)
          'status': 'joined',
          'joinedAt': DateTime.now().toIso8601String(),
          'metadata': '{}',
        },
      );
    } catch (e) {
      AppLogger().debug('Error joining room: $e');
      rethrow;
    }
  }

  Future<void> leaveRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      final participants = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'room_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
          Query.equal('status', 'joined'),
        ],
      );
      
      for (var participant in participants.documents) {
        await databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'room_participants',
          documentId: participant.$id,
          data: {
            'status': 'left',
            'leftAt': DateTime.now().toIso8601String(),
          },
        );
      }
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
        collectionId: 'room_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
          Query.equal('status', 'joined'),
        ],
      );
      
      if (participants.documents.isNotEmpty) {
        await databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'room_participants',
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
        collectionId: 'room_participants',
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
          collectionId: 'room_participants',
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
        collectionId: 'room_participants',
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

      return challenges.documents.map((doc) {
        final challengeData = Map<String, dynamic>.from(doc.data);
        challengeData['id'] = doc.$id;
        return challengeData;
      }).toList().cast<Map<String, dynamic>>();
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

      return notifications.documents.map((doc) {
        final notificationData = Map<String, dynamic>.from(doc.data);
        notificationData['id'] = doc.$id;
        return notificationData;
      }).toList().cast<Map<String, dynamic>>();
    } catch (e) {
      AppLogger().error('Error getting user arena role notifications: $e');
      return [];
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
      final now = DateTime.now().toIso8601String();
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

  Future<void> assignArenaRole({
    required String roomId,
    required String userId,
    required String role, // affirmative, negative, moderator, judge1, judge2, judge3, audience
  }) async {
    try {
      String finalRole = role;
      
      // Special handling for judge role - assign to next available judge slot
      if (role == 'judge') {
        AppLogger().debug('🔍 Processing judge role assignment for user $userId in room $roomId');
        
        // Get existing participants roles only (not full profiles to avoid circular dependency)
        final existingRolesResponse = await databases.listDocuments(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          queries: [
            Query.equal('roomId', roomId),
            Query.equal('isActive', true),
          ],
        );
        
        final judgeRoles = ['judge1', 'judge2', 'judge3'];
        final takenJudgeRoles = existingRolesResponse.documents
            .map((doc) => doc.data['role'] as String)
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
      
      // Check if user already has a role in this room
      final existingRoles = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
        ],
      );

      if (existingRoles.documents.isNotEmpty) {
        // Update existing role
        await databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'arena_participants',
          documentId: existingRoles.documents.first.$id,
          data: {
            'role': finalRole,
            'assignedAt': DateTime.now().toIso8601String(),
            'isActive': true, // Ensure participant is marked as active
          },
        );
        AppLogger().info('✅ Updated existing participant: user $userId as $finalRole in room $roomId (isActive: true)');
      } else {
        // Create new role assignment
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
        AppLogger().info('✅ Created new participant: user $userId as $finalRole in room $roomId (isActive: true)');
      }

      AppLogger().info('Assigned $finalRole to user $userId in room $roomId');
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

      if (judgments.documents.length < 1) {
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
        final roomData = Map<String, dynamic>.from(doc.data);
        roomData['id'] = doc.$id;
        roomData['createdAt'] = doc.$createdAt;
        roomData['updatedAt'] = doc.$updatedAt;
        return roomData;
      }).toList().cast<Map<String, dynamic>>();
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
      final response = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [
          Query.equal('isPublicProfile', true),
          Query.search('name', query),
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
      AppLogger().error('Error searching users: $e');
      return [];
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
      Future.delayed(Duration(seconds: 1), () {
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
        
        if (roomAge.inHours >= 6) {
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
    int maxParticipants = 8, // moderator + 2 debaters + 3 judges + 2 audience
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
      final nowString = now.toIso8601String();
      
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
      
      late final models.Document response;
      
      try {
        response = await databases.createDocument(
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
      await assignArenaRole(
        roomId: roomId,
        userId: creatorId,
        role: 'moderator',
      );

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
        },
      );
      AppLogger().info('✅ Room document created: $documentId');
      
      // Assign creator as moderator
      try {
        await assignArenaRole(
          roomId: documentId,
          userId: creatorId,
          role: 'moderator',
        );
        AppLogger().info('✅ Moderator role assigned');
      } catch (e) {
        AppLogger().error('⚠️ Failed to assign moderator role: $e');
      }
      
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
        final roomData = Map<String, dynamic>.from(doc.data);
        roomData['id'] = doc.$id;
        roomData['createdAt'] = doc.$createdAt;
        roomData['updatedAt'] = doc.$updatedAt;

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
        roomData['participants'] = participants.documents.map((p) => Map<String, dynamic>.from(p.data)).toList().cast<Map<String, dynamic>>();
        
        // Only include rooms that aren't full (using default max of 8 since field doesn't exist)
        const maxParticipants = 8;
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
      await assignArenaRole(
        roomId: roomId,
        userId: userId,
        role: 'audience',
      );

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
          collectionId: 'room_participants',
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
              collectionId: 'room_participants',
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
            collectionId: 'room_participants',
            queries: [
              Query.equal('roomId', roomId),
            ],
          );

          // Mark all participants as left
          for (final participant in allParticipants.documents) {
            await databases.updateDocument(
              databaseId: 'arena_db',
              collectionId: 'room_participants',
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
            collectionId: 'room_participants',
            queries: [
              Query.equal('roomId', roomId),
            ],
          );

          // Mark all participants as left
          for (final participant in allParticipants.documents) {
            if (participant.data['status'] != 'left') {
              await databases.updateDocument(
                databaseId: 'arena_db',
                collectionId: 'room_participants',
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
      final transaction = await databases.createDocument(
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
        // Higher tier gifts give more reputation
        int reputationBonus = cost >= 50 ? 10 : (cost >= 15 ? 5 : (cost >= 5 ? 3 : 1));
        
        await updateUserProfile(
          userId: recipientId,
          totalGiftsReceived: recipientProfile.totalGiftsReceived + 1,
          reputation: recipientProfile.reputation + reputationBonus,
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
} 