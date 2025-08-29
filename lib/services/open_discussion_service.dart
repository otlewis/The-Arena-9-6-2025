import 'dart:convert';
import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:http/http.dart' as http;
import '../core/logging/app_logger.dart';
import '../constants/appwrite.dart';
import 'appwrite_service.dart';
import 'livekit_config_service.dart';
import 'livekit_token_service.dart';

/// Service for managing Open Discussion rooms using LiveKit Server APIs
/// This service provides room and participant management with LiveKit as the source of truth
class OpenDiscussionService {
  static final OpenDiscussionService _instance = OpenDiscussionService._internal();
  factory OpenDiscussionService() => _instance;
  OpenDiscussionService._internal() {
    // Initialize room list stream
    _initializeRoomListStream();
  }

  // Prevent duplicate room creation
  bool _isCreatingRoom = false;
  String? _lastCreatedRoomName;

  // Stream controllers for real-time updates
  final _roomsStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get roomsStream => _roomsStreamController.stream;
  
  final _participantsStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get participantsStream => _participantsStreamController.stream;
  
  // Room closure notification stream
  final _roomClosureStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get roomClosureStream => _roomClosureStreamController.stream;
  
  RealtimeSubscription? _roomsSubscription;
  RealtimeSubscription? _participantsSubscription;
  Timer? _roomsRefreshTimer;
  String? _currentRoomId;
  
  // Simple cache for room list (5 minute TTL)
  List<Map<String, dynamic>>? _cachedRooms;
  DateTime? _cacheTimestamp;
  static const Duration _cacheExpiryDuration = Duration(minutes: 5);

  // LiveKit server configuration
  String get _httpApiUrl => LiveKitConfigService.instance.httpApiUrl;

  /// Generate authentication headers for LiveKit API requests
  Map<String, String> get _headers {
    // For LiveKit Server APIs, we need to create a special token with server permissions
    final token = _generateServerApiToken();

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Generate server API token with proper permissions for room management
  String _generateServerApiToken() {
    AppLogger().debug('🔑 Generating server API token');
    
    try {
      // Use exact same payload structure as working standalone script
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiry = now + 3600; // 1 hour
      
      final payload = {
        'iss': LiveKitConfigService.instance.apiKey,
        'sub': 'test-admin',
        'iat': now,
        'exp': expiry,
        'video': {
          'roomAdmin': true,
          'roomList': true,
          'roomCreate': true,
        }
      };
      
      AppLogger().debug('🔧 JWT Payload: $payload');
      final token = LiveKitTokenService.generateJWT(payload);
      AppLogger().debug('✅ Generated server API token successfully');
      return token;
      
    } catch (e) {
      AppLogger().error('❌ Failed to generate server API token: $e');
      
      // Fallback to standard token generation
      return LiveKitTokenService.generateToken(
        roomName: '',
        identity: 'server-admin',
        userRole: 'admin',
        roomType: 'server-api',
        ttl: const Duration(hours: 1),
      );
    }
  }

  // =====================================================
  // ROOM MANAGEMENT
  // =====================================================

  /// Test server connectivity
  Future<bool> testServerConnection() async {
    try {
      AppLogger().debug('🔗 Testing LiveKit server connectivity');
      
      final url = Uri.parse('$_httpApiUrl/twirp/livekit.RoomService/ListRooms');
      final response = await http.post(url, headers: _headers, body: '{}');
      
      AppLogger().debug('📡 Server response: ${response.statusCode}');
      AppLogger().debug('📄 Response body: ${response.body}');
      
      return response.statusCode == 200;
    } catch (e) {
      AppLogger().error('❌ Server connection test failed: $e');
      return false;
    }
  }

  /// Create a new open discussion room using unified Appwrite Function
  Future<Map<String, dynamic>> createRoom({
    required String roomName,
    String displayTitle = '', // Clean title for display
    String description = '',
    String category = 'General',
    String moderatorId = '',
    int emptyTimeout = 600, // 10 minutes
    int maxParticipants = 0, // 0 means unlimited
  }) async {
    try {
      // Prevent duplicate calls
      if (_isCreatingRoom && _lastCreatedRoomName == roomName) {
        AppLogger().debug('⚠️ Room creation already in progress for: $roomName');
        throw Exception('Room creation already in progress');
      }
      
      _isCreatingRoom = true;
      _lastCreatedRoomName = roomName;
      
      AppLogger().debug('🏗️ Creating room via unified Appwrite Function: $roomName');
      
      final appwriteService = AppwriteService();
      
      // Call unified Appwrite Function for optimized server-side room creation
      final response = await appwriteService.functions.createExecution(
        functionId: 'create-livekit-room',
        body: jsonEncode({
          'action': 'createRoom',
          'payload': {
            'roomName': roomName,
            'displayTitle': displayTitle.isNotEmpty ? displayTitle : roomName,
            'description': description.isNotEmpty ? description : 'No description provided',
            'category': category,
            'moderatorId': moderatorId,
            'maxParticipants': maxParticipants,
          }
        }),
      );

      final result = jsonDecode(response.responseBody);
      
      if (!result['success']) {
        throw Exception('Failed to create room: ${result['error']}');
      }

      AppLogger().debug('✅ Room created successfully via function: ${result['roomId']}');
      
      // Clear the creation lock
      _isCreatingRoom = false;
      _lastCreatedRoomName = null;
      
      // Return data in format expected by UI
      return {
        'sid': result['roomId'],
        'name': result['roomName'],
        'token': result['token'], // LiveKit token for moderator
        'livekitUrl': result['livekitUrl'],
        'empty_timeout': emptyTimeout,
        'max_participants': maxParticipants,
        'num_participants': 0,
        'creation_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'metadata': jsonEncode({
          'type': 'open_discussion',
          'created_at': DateTime.now().toIso8601String(),
          'description': description,
          'category': category,
          'moderatorId': moderatorId,
          'displayTitle': displayTitle,
          'title': displayTitle,
        }),
        'active_recording': false,
      };
      
    } catch (e) {
      AppLogger().error('❌ Error creating room via function: $e');
      // Clear the creation lock on error
      _isCreatingRoom = false;
      _lastCreatedRoomName = null;
      rethrow;
    }
  }

  /// Join an existing room using unified Appwrite Function
  Future<Map<String, dynamic>> joinRoom({
    required String roomName,
    required String userId,
    String userRole = 'audience',
  }) async {
    try {
      AppLogger().debug('🚪 Joining room via unified function: $roomName as $userRole');
      
      final appwriteService = AppwriteService();
      
      // Call unified Appwrite Function for optimized token generation
      final response = await appwriteService.functions.createExecution(
        functionId: 'create-livekit-room',
        body: jsonEncode({
          'action': 'joinRoom',
          'payload': {
            'roomName': roomName,
            'userId': userId,
            'userRole': userRole,
          }
        }),
      );

      final result = jsonDecode(response.responseBody);
      
      if (!result['success']) {
        throw Exception('Failed to join room: ${result['error']}');
      }

      AppLogger().debug('✅ Join token generated via function for $userId');
      
      return {
        'token': result['token'],
        'livekitUrl': result['livekitUrl'],
        'roomName': result['roomName'],
        'userRole': result['userRole'],
      };
      
    } catch (e) {
      AppLogger().error('❌ Error joining room via function: $e');
      rethrow;
    }
  }


  /// List all active rooms with optimized batch queries and caching
  Future<List<Map<String, dynamic>>> listRooms() async {
    try {
      // Check cache first for super fast subsequent loads
      if (_cachedRooms != null && 
          _cacheTimestamp != null && 
          DateTime.now().difference(_cacheTimestamp!) < _cacheExpiryDuration) {
        AppLogger().debug('📋 Returning cached rooms (${_cachedRooms!.length} rooms)');
        return _cachedRooms!;
      }
      
      AppLogger().debug('📋 Listing rooms via unified Appwrite Function');
      final stopwatch = Stopwatch()..start();
      
      final appwriteService = AppwriteService();
      
      // Call unified Appwrite Function for optimized server-side processing
      final response = await appwriteService.functions.createExecution(
        functionId: 'create-livekit-room', // Using existing function ID
        body: jsonEncode({
          'action': 'listRooms',
          'payload': {
            'limit': 50,
            'offset': 0,
            'status': 'active'
          }
        }),
      );

      final result = jsonDecode(response.responseBody);
      
      if (!result['success']) {
        throw Exception('Failed to list rooms: ${result['error']}');
      }

      // Convert function response to expected format
      final List<Map<String, dynamic>> rooms = [];
      for (final room in result['rooms']) {
        final settings = room['settings'] ?? {};
        
        rooms.add({
          'sid': room['id'] ?? '',
          'name': settings['liveKitRoomName'] ?? room['title'] ?? 'Unnamed Room', // Technical name for LiveKit joining
          'title': room['title'] ?? 'Unnamed Room', // Clean display title
          'empty_timeout': settings['emptyTimeout'] ?? 600,
          'max_participants': room['maxParticipants'] ?? 0,
          'num_participants': room['participantCount'] ?? 0, // From function
          'creation_time': room['createdAt'] != null 
              ? (DateTime.tryParse(room['createdAt'])?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch) ~/ 1000
              : DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'metadata': jsonEncode({
            'type': 'open_discussion',
            'created_at': room['createdAt'] ?? DateTime.now().toIso8601String(),
            'description': room['description'] ?? '',
            'category': (room['tags'] as List?)?.isNotEmpty == true ? room['tags'][0] : 'General',
            'moderatorId': room['moderator'] != null ? room['moderator']['displayName'] : 'Unknown',
            'moderatorName': room['moderator'] != null ? room['moderator']['displayName'] : 'Unknown',
            'title': room['title'] ?? 'Unnamed Room',
          }),
          'active_recording': false,
          // Additional fields for UI display
          'description': room['description'] ?? 'No description provided',
          'category': (room['tags'] as List?)?.isNotEmpty == true ? room['tags'][0] : 'General',
          'moderatorId': '', // Will be populated from metadata if needed
          'moderatorName': room['moderator'] != null ? room['moderator']['displayName'] : 'Unknown',
          'moderatorProfileImageUrl': room['moderator'] != null ? room['moderator']['avatar'] : null,
        });
      }
      
      stopwatch.stop();
      AppLogger().debug('✅ Successfully fetched ${rooms.length} rooms via function in ${stopwatch.elapsedMilliseconds}ms');
      
      // Cache the results for faster subsequent loads
      _cachedRooms = rooms;
      _cacheTimestamp = DateTime.now();
      
      return rooms;
      
    } catch (e) {
      AppLogger().error('❌ Error listing rooms via function: $e');
      return []; // Return empty list instead of throwing
    }
  }

  /// Update room metadata
  Future<void> updateRoomMetadata({
    required String roomName,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      AppLogger().debug('📝 Updating room metadata: $roomName');
      
      final url = Uri.parse('$_httpApiUrl/twirp/livekit.RoomService/UpdateRoomMetadata');
      final body = jsonEncode({
        'room': roomName,
        'metadata': jsonEncode(metadata),
      });

      final response = await http.post(url, headers: _headers, body: body);
      
      if (response.statusCode == 200) {
        AppLogger().debug('✅ Room metadata updated successfully: $roomName');
      } else {
        AppLogger().error('❌ Failed to update room metadata: ${response.statusCode} ${response.body}');
        throw Exception('Failed to update room metadata: ${response.body}');
      }
    } catch (e) {
      AppLogger().error('❌ Error updating room metadata: $e');
      rethrow;
    }
  }

  /// Close a room (moderator action) - immediately closes and navigates all users
  /// This version directly updates the database without using Appwrite function
  Future<void> closeRoom({
    required String roomId,
    required String moderatorId,
    String reason = 'moderator_closed',
  }) async {
    try {
      AppLogger().debug('🚪 Closing room directly: $roomId by moderator: $moderatorId');
      AppLogger().debug('🔧 Using database: ${AppwriteConstants.databaseId}');
      AppLogger().debug('🔧 Using room collection: ${AppwriteConstants.debateDiscussionRoomsCollection}');
      AppLogger().debug('🔧 Using participant collection: ${AppwriteConstants.roomParticipantsCollection}');
      
      final appwriteService = AppwriteService();
      
      // Step 1: Delete room document from database (preferred over marking as closed)
      try {
        // For open discussion rooms, try the discussion_rooms collection first
        try {
          await appwriteService.databases.deleteDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.roomsCollection, // This is 'discussion_rooms' 
            documentId: roomId,
          );
          AppLogger().debug('✅ Room deleted from discussion_rooms collection');
        } catch (discussionRoomError) {
          // If not found in discussion_rooms, try debate_discussion_rooms
          AppLogger().debug('⚠️ Room not found in discussion_rooms, trying debate_discussion_rooms');
          await appwriteService.databases.deleteDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.debateDiscussionRoomsCollection,
            documentId: roomId,
          );
          AppLogger().debug('✅ Room deleted from debate_discussion_rooms collection');
        }
      } catch (e) {
        AppLogger().warning('⚠️ Could not delete room from database (room document may not exist): $e');
        // Don't throw here - room closure can still proceed without database delete
        // This allows closure to work even if room was created only in LiveKit
      }
      
      // Step 2: First update all participants to 'room_closed' status (triggers real-time notifications)
      List<String> participantIds = [];
      try {
        final participantsResponse = await appwriteService.databases.listDocuments(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.roomParticipantsCollection,
          queries: [
            Query.equal('roomId', roomId),
          ],
        );
        
        AppLogger().debug('🔍 Found ${participantsResponse.documents.length} participants to notify of room closure');
        
        // First, update each participant to 'room_closed' status - this triggers real-time notifications
        for (final participant in participantsResponse.documents) {
          try {
            participantIds.add(participant.$id);
            await appwriteService.databases.updateDocument(
              databaseId: AppwriteConstants.databaseId,
              collectionId: AppwriteConstants.roomParticipantsCollection,
              documentId: participant.$id,
              data: {
                'status': 'room_closed',
                'leftAt': DateTime.now().toIso8601String(),
                'leftReason': reason,
                'closedBy': moderatorId,
              },
            );
            AppLogger().debug('📢 Notified participant ${participant.data['userId']} of room closure via status update');
          } catch (e) {
            AppLogger().warning('⚠️ Failed to update participant ${participant.$id}: $e');
          }
        }
        
        AppLogger().debug('✅ Notified ${participantsResponse.documents.length} participants of room closure');
        
        // Wait a moment for notifications to be processed by all clients
        await Future.delayed(const Duration(milliseconds: 1000));
        
        // Then delete the participant documents for cleanup
        for (final participantId in participantIds) {
          try {
            await appwriteService.databases.deleteDocument(
              databaseId: AppwriteConstants.databaseId,
              collectionId: AppwriteConstants.roomParticipantsCollection,
              documentId: participantId,
            );
          } catch (e) {
            AppLogger().warning('⚠️ Failed to delete participant $participantId: $e');
          }
        }
        
        AppLogger().debug('✅ Cleaned up ${participantIds.length} participant documents');
        
      } catch (e) {
        AppLogger().warning('⚠️ Could not notify participants of room closure: $e');
        // Continue even if participant notification fails
      }
      
      // Step 3: Delete the LiveKit room to properly close it on the server
      try {
        await deleteRoom(roomId);
        AppLogger().debug('✅ LiveKit room deleted successfully');
      } catch (e) {
        AppLogger().warning('⚠️ Could not delete LiveKit room (may not exist): $e');
        // Continue with closure even if LiveKit deletion fails
      }
      
      // Step 4: Emit room closure notification multiple times for reliability
      AppLogger().debug('📢 Emitting room closure notification for room: $roomId');
      final closureNotification = {
        'roomId': roomId,
        'roomTitle': 'Room Closed',
        'closedBy': moderatorId,
        'reason': reason,
        'message': 'This room has been closed by the moderator',
        'timestamp': DateTime.now().toIso8601String(),
        'forceDisconnect': true,
      };
      
      // Emit immediately
      _roomClosureStreamController.add(closureNotification);
      
      // Emit again after a short delay to catch any clients that might have missed the first one
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_roomClosureStreamController.isClosed) {
          _roomClosureStreamController.add(closureNotification);
        }
      });
      
      // Emit a third time after longer delay as final safety net
      Future.delayed(const Duration(seconds: 1), () {
        if (!_roomClosureStreamController.isClosed) {
          _roomClosureStreamController.add(closureNotification);
        }
      });
      
      AppLogger().debug('📢 Room closure notification emitted (with retries)');
      
      AppLogger().debug('✅ Room closed successfully');
      
      // Force immediate room list refresh to remove deleted room
      _cachedRooms = null;
      _cacheTimestamp = null;
      refreshRoomList();
      
    } catch (e) {
      AppLogger().error('❌ Error closing room: $e');
      
      // Still emit closure notification even if there were errors
      // This ensures all users are disconnected even if database/LiveKit operations fail
      try {
        AppLogger().debug('📢 Emitting emergency room closure notification');
        final emergencyNotification = {
          'roomId': roomId,
          'roomTitle': 'Room Closed',
          'closedBy': moderatorId,
          'reason': reason,
          'message': 'This room has been closed by the moderator',
          'timestamp': DateTime.now().toIso8601String(),
          'forceDisconnect': true,
          'emergency': true,
        };
        
        // Emit multiple times for emergency situations
        _roomClosureStreamController.add(emergencyNotification);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!_roomClosureStreamController.isClosed) {
            _roomClosureStreamController.add(emergencyNotification);
          }
        });
        Future.delayed(const Duration(milliseconds: 700), () {
          if (!_roomClosureStreamController.isClosed) {
            _roomClosureStreamController.add(emergencyNotification);
          }
        });
      } catch (notificationError) {
        AppLogger().error('❌ Failed to emit emergency closure notification: $notificationError');
      }
      
      rethrow;
    }
  }

  /// Delete a room
  Future<void> deleteRoom(String roomName) async {
    try {
      AppLogger().debug('🗑️ Deleting room: $roomName');
      
      final url = Uri.parse('$_httpApiUrl/twirp/livekit.RoomService/DeleteRoom');
      final body = jsonEncode({'room': roomName});

      final response = await http.post(url, headers: _headers, body: body);
      
      if (response.statusCode == 200) {
        AppLogger().debug('✅ Room deleted successfully: $roomName');
      } else {
        AppLogger().error('❌ Failed to delete room: ${response.statusCode} ${response.body}');
        throw Exception('Failed to delete room: ${response.body}');
      }
    } catch (e) {
      AppLogger().error('❌ Error deleting room: $e');
      rethrow;
    }
  }

  // =====================================================
  // PARTICIPANT MANAGEMENT
  // =====================================================

  /// List participants in a room
  Future<List<Map<String, dynamic>>> listParticipants(String roomName) async {
    try {
      AppLogger().debug('👥 Listing participants in room: $roomName');
      
      final url = Uri.parse('$_httpApiUrl/twirp/livekit.RoomService/ListParticipants');
      final body = jsonEncode({'room': roomName});

      final response = await http.post(url, headers: _headers, body: body);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final participants = List<Map<String, dynamic>>.from(data['participants'] ?? []);
        AppLogger().debug('✅ Found ${participants.length} participants');
        return participants;
      } else {
        AppLogger().error('❌ Failed to list participants: ${response.statusCode} ${response.body}');
        throw Exception('Failed to list participants: ${response.body}');
      }
    } catch (e) {
      AppLogger().error('❌ Error listing participants: $e');
      rethrow;
    }
  }

  /// Get details for a specific participant
  Future<Map<String, dynamic>?> getParticipant(String roomName, String identity) async {
    try {
      AppLogger().debug('👤 Getting participant: $identity in room: $roomName');
      
      final url = Uri.parse('$_httpApiUrl/twirp/livekit.RoomService/GetParticipant');
      final body = jsonEncode({
        'room': roomName,
        'identity': identity,
      });

      final response = await http.post(url, headers: _headers, body: body);
      
      if (response.statusCode == 200) {
        final participant = jsonDecode(response.body);
        AppLogger().debug('✅ Found participant: ${participant['identity']}');
        return participant;
      } else if (response.statusCode == 404) {
        AppLogger().debug('👤 Participant not found: $identity');
        return null;
      } else {
        AppLogger().error('❌ Failed to get participant: ${response.statusCode} ${response.body}');
        throw Exception('Failed to get participant: ${response.body}');
      }
    } catch (e) {
      AppLogger().error('❌ Error getting participant: $e');
      rethrow;
    }
  }

  /// Update participant permissions (promote/demote)
  Future<Map<String, dynamic>> updateParticipantPermissions({
    required String roomName,
    required String identity,
    bool canPublish = false,
    bool canSubscribe = true,
    bool canPublishData = true,
  }) async {
    try {
      AppLogger().debug('🔄 Updating permissions for $identity: publish=$canPublish');
      
      final url = Uri.parse('$_httpApiUrl/twirp/livekit.RoomService/UpdateParticipant');
      final body = jsonEncode({
        'room': roomName,
        'identity': identity,
        'permission': {
          'can_subscribe': canSubscribe,
          'can_publish': canPublish,
          'can_publish_data': canPublishData,
        },
      });

      final response = await http.post(url, headers: _headers, body: body);
      
      if (response.statusCode == 200) {
        final participant = jsonDecode(response.body);
        AppLogger().debug('✅ Updated permissions for: ${participant['identity']}');
        return participant;
      } else {
        AppLogger().error('❌ Failed to update permissions: ${response.statusCode} ${response.body}');
        throw Exception('Failed to update permissions: ${response.body}');
      }
    } catch (e) {
      AppLogger().error('❌ Error updating permissions: $e');
      rethrow;
    }
  }

  /// Update participant metadata
  Future<Map<String, dynamic>> updateParticipantMetadata({
    required String roomName,
    required String identity,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      AppLogger().debug('📝 Updating metadata for $identity');
      
      final url = Uri.parse('$_httpApiUrl/twirp/livekit.RoomService/UpdateParticipant');
      final body = jsonEncode({
        'room': roomName,
        'identity': identity,
        'metadata': jsonEncode(metadata),
      });

      final response = await http.post(url, headers: _headers, body: body);
      
      if (response.statusCode == 200) {
        final participant = jsonDecode(response.body);
        AppLogger().debug('✅ Updated metadata for: ${participant['identity']}');
        return participant;
      } else {
        AppLogger().error('❌ Failed to update metadata: ${response.statusCode} ${response.body}');
        throw Exception('Failed to update metadata: ${response.body}');
      }
    } catch (e) {
      AppLogger().error('❌ Error updating metadata: $e');
      rethrow;
    }
  }

  /// Remove a participant from the room
  Future<void> removeParticipant(String roomName, String identity) async {
    try {
      AppLogger().debug('🚫 Removing participant: $identity from room: $roomName');
      
      final url = Uri.parse('$_httpApiUrl/twirp/livekit.RoomService/RemoveParticipant');
      final body = jsonEncode({
        'room': roomName,
        'identity': identity,
      });

      final response = await http.post(url, headers: _headers, body: body);
      
      if (response.statusCode == 200) {
        AppLogger().debug('✅ Removed participant: $identity');
      } else {
        AppLogger().error('❌ Failed to remove participant: ${response.statusCode} ${response.body}');
        throw Exception('Failed to remove participant: ${response.body}');
      }
    } catch (e) {
      AppLogger().error('❌ Error removing participant: $e');
      rethrow;
    }
  }

  // =====================================================
  // AUDIO CONTROL
  // =====================================================

  /// Mute a participant's track
  Future<void> muteParticipant({
    required String roomName,
    required String identity,
    required String trackSid,
  }) async {
    try {
      AppLogger().debug('🔇 Muting track $trackSid for $identity');
      
      final url = Uri.parse('$_httpApiUrl/twirp/livekit.RoomService/MutePublishedTrack');
      final body = jsonEncode({
        'room': roomName,
        'identity': identity,
        'track_sid': trackSid,
        'muted': true,
      });

      final response = await http.post(url, headers: _headers, body: body);
      
      if (response.statusCode == 200) {
        AppLogger().debug('✅ Muted track for: $identity');
      } else {
        AppLogger().error('❌ Failed to mute track: ${response.statusCode} ${response.body}');
        throw Exception('Failed to mute track: ${response.body}');
      }
    } catch (e) {
      AppLogger().error('❌ Error muting track: $e');
      rethrow;
    }
  }

  /// Unmute a participant's track
  Future<void> unmuteParticipant({
    required String roomName,
    required String identity,
    required String trackSid,
  }) async {
    try {
      AppLogger().debug('🔊 Unmuting track $trackSid for $identity');
      
      final url = Uri.parse('$_httpApiUrl/twirp/livekit.RoomService/MutePublishedTrack');
      final body = jsonEncode({
        'room': roomName,
        'identity': identity,
        'track_sid': trackSid,
        'muted': false,
      });

      final response = await http.post(url, headers: _headers, body: body);
      
      if (response.statusCode == 200) {
        AppLogger().debug('✅ Unmuted track for: $identity');
      } else {
        AppLogger().error('❌ Failed to unmute track: ${response.statusCode} ${response.body}');
        throw Exception('Failed to unmute track: ${response.body}');
      }
    } catch (e) {
      AppLogger().error('❌ Error unmuting track: $e');
      rethrow;
    }
  }

  // =====================================================
  // ROLE MANAGEMENT HELPERS
  // =====================================================

  /// Promote audience member to speaker (approve hand raise)
  Future<void> promoteToSpeaker(String roomName, String identity) async {
    // First update Appwrite database (this triggers role change flow)
    await updateParticipantRole(
      roomId: roomName,
      userId: identity,
      newRole: 'speaker',
    );
    
    // Clear the hand raise status
    await updateParticipantMetadata(
      roomName: roomName,
      identity: identity,
      metadata: {
        'role': 'speaker',
        'promoted_at': DateTime.now().toIso8601String(),
        'hand_raised': false,
      },
    );
  }

  /// Demote speaker back to audience
  Future<void> demoteToAudience(String roomName, String identity) async {
    // First update Appwrite database (this triggers role change flow)
    await updateParticipantRole(
      roomId: roomName,
      userId: identity,
      newRole: 'audience',
    );
    
    // Clear any metadata
    await updateParticipantMetadata(
      roomName: roomName,
      identity: identity,
      metadata: {
        'role': 'audience',
        'demoted_at': DateTime.now().toIso8601String(),
        'hand_raised': false,
      },
    );
  }

  /// Handle hand raise request using Appwrite
  Future<void> raiseHand(String roomName, String identity) async {
    try {
      AppLogger().debug('✋ Raising hand for $identity in room $roomName');
      
      final appwriteService = AppwriteService();
      
      // Create or update hand raise document
      // Use a shorter document ID to avoid the 36 char limit
      final docId = '${identity.substring(0, 20)}_${roomName.hashCode.abs()}';
      
      try {
        await appwriteService.databases.createDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: 'handraises',
          documentId: docId,
          data: {
            'roomId': roomName,
            'userId': identity,
            'userName': identity, // Can be updated with actual name
            'status': 'raised',
            'raisedAt': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        // If document exists, update it
        try {
          await appwriteService.databases.updateDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: 'handraises',
            documentId: docId,
            data: {
              'status': 'raised',
              'raisedAt': DateTime.now().toIso8601String(),
            },
          );
        } catch (updateError) {
          AppLogger().error('Failed to update hand raise: $updateError');
          rethrow;
        }
      }
      
      AppLogger().debug('✅ Hand raised successfully');
    } catch (e) {
      AppLogger().error('❌ Failed to raise hand: $e');
      rethrow;
    }
  }

  /// Lower hand using Appwrite
  Future<void> lowerHand(String roomName, String identity) async {
    try {
      AppLogger().debug('👋 Lowering hand for $identity in room $roomName');
      
      final appwriteService = AppwriteService();
      
      // Update hand raise document
      // Use the same shorter document ID format
      final docId = '${identity.substring(0, 20)}_${roomName.hashCode.abs()}';
      
      try {
        await appwriteService.databases.updateDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: 'handraises',
          documentId: docId,
          data: {
            'status': 'lowered',
          },
        );
      } catch (e) {
        // If document doesn't exist, that's okay - hand wasn't raised
        AppLogger().debug('Hand raise document not found - may already be lowered');
      }
      
      AppLogger().debug('✅ Hand lowered successfully');
    } catch (e) {
      AppLogger().error('❌ Failed to lower hand: $e');
      rethrow;
    }
  }

  // =====================================================
  // ROOM PARTICIPANTS MANAGEMENT
  // =====================================================

  /// Add user to Room Participants collection when joining
  Future<void> addRoomParticipant({
    required String roomId,
    required String userId,
    required String userName,
    String? userAvatar,
    String role = 'audience',
  }) async {
    try {
      AppLogger().debug('👥 Adding participant $userName to room $roomId as $role');
      
      final appwriteService = AppwriteService();
      
      // Check if participant already exists and is active
      final existingResponse = await appwriteService.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'room_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
          Query.equal('status', 'joined'),
        ],
      );

      if (existingResponse.documents.isNotEmpty) {
        AppLogger().debug('👥 User already active in room, updating lastActiveAt');
        // Update existing record
        await appwriteService.databases.updateDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: 'room_participants',
          documentId: existingResponse.documents.first.$id,
          data: {
            'lastActiveAt': DateTime.now().toIso8601String(),
            'role': role,
          },
        );
        return;
      }

      // Create new participant record
      await appwriteService.databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'room_participants',
        documentId: ID.unique(),
        data: {
          'roomId': roomId,
          'userId': userId,
          'userName': userName,
          'userAvatar': userAvatar ?? '',
          'role': role,
          'status': 'joined',
          'joinedAt': DateTime.now().toIso8601String(),
          'lastActiveAt': DateTime.now().toIso8601String(),
          'metadata': '{}',
        },
      );

      AppLogger().debug('✅ Added participant $userName to room $roomId');
    } catch (e) {
      AppLogger().error('❌ Failed to add room participant: $e');
      rethrow;
    }
  }

  /// Remove user from Room Participants (mark as left)
  Future<void> removeRoomParticipant({
    required String roomId,
    required String userId,
  }) async {
    try {
      AppLogger().debug('👥 Removing participant $userId from room $roomId');
      
      final appwriteService = AppwriteService();
      
      // Find active participant record
      final response = await appwriteService.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'room_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
          Query.equal('status', 'joined'),
        ],
      );

      if (response.documents.isNotEmpty) {
        // Update status to 'left' instead of deleting
        await appwriteService.databases.updateDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: 'room_participants',
          documentId: response.documents.first.$id,
          data: {
            'status': 'left',
            'leftAt': DateTime.now().toIso8601String(),
          },
        );
        AppLogger().debug('✅ Marked participant as left: $userId');
      } else {
        AppLogger().debug('⚠️ No active participant found to remove: $userId');
      }
    } catch (e) {
      AppLogger().error('❌ Failed to remove room participant: $e');
      rethrow;
    }
  }

  /// Get all active participants in a room with their profile data
  Future<List<Map<String, dynamic>>> getRoomParticipants(String roomId) async {
    try {
      AppLogger().debug('👥 Getting participants for room: $roomId');
      
      final appwriteService = AppwriteService();
      
      // Use a more defensive approach with timeout
      final response = await appwriteService.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'room_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('status', 'joined'),
          Query.orderDesc('\$createdAt'),
        ],
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger().error('❌ Timeout getting room participants');
          throw TimeoutException('Room participants query timeout', const Duration(seconds: 10));
        },
      );

      final participants = <Map<String, dynamic>>[];
      
      for (final doc in response.documents) {
        try {
          final data = doc.data;
          
          // Create safe participant data with comprehensive null checking
          final participantData = <String, dynamic>{
            'id': doc.$id,
            'roomId': _safeStringValue(data['roomId']) ?? roomId,
            'userId': _safeStringValue(data['userId']) ?? '',
            'userName': _safeStringValue(data['userName']) ?? 'Unknown User',
            'userAvatar': _safeStringValue(data['userAvatar']),
            'role': _safeStringValue(data['role']) ?? 'audience',
            'status': _safeStringValue(data['status']) ?? 'joined',
            'joinedAt': _safeStringValue(data['joinedAt']) ?? DateTime.now().toIso8601String(),
            'lastActiveAt': _safeStringValue(data['lastActiveAt']) ?? DateTime.now().toIso8601String(),
            'metadata': _safeMapValue(data['metadata']) ?? {},
          };
          
          participants.add(participantData);
        } catch (e) {
          AppLogger().error('❌ Error processing participant document ${doc.$id}: $e');
          // Create minimal fallback participant to avoid breaking the UI
          participants.add({
            'id': doc.$id,
            'roomId': roomId,
            'userId': '',
            'userName': 'Unknown User',
            'userAvatar': '',
            'role': 'audience',
            'status': 'joined',
            'joinedAt': DateTime.now().toIso8601String(),
            'lastActiveAt': DateTime.now().toIso8601String(),
            'metadata': {},
          });
        }
      }

      AppLogger().debug('✅ Found ${participants.length} active participants');
      return participants;
    } catch (e) {
      AppLogger().error('❌ Failed to get room participants: $e');
      // Return empty list to prevent UI crashes
      return [];
    }
  }

  /// Safely extract string value from dynamic data
  String? _safeStringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  /// Safely extract map value from dynamic data  
  Map<String, dynamic>? _safeMapValue(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  /// Update participant role
  Future<void> updateParticipantRole({
    required String roomId,
    required String userId,
    required String newRole,
  }) async {
    try {
      AppLogger().debug('👥 Updating participant $userId role to $newRole in room $roomId');
      
      final appwriteService = AppwriteService();
      
      // First check current role to avoid unnecessary updates
      final currentResponse = await appwriteService.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'room_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
          Query.equal('status', 'joined'),
        ],
      );

      if (currentResponse.documents.isNotEmpty) {
        final currentRole = currentResponse.documents.first.data['role'];
        if (currentRole == newRole) {
          AppLogger().debug('👥 User $userId already has role $newRole, skipping update');
          return;
        }
      }
      
      final response = await appwriteService.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'room_participants',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('userId', userId),
          Query.equal('status', 'joined'),
        ],
      );

      if (response.documents.isNotEmpty) {
        await appwriteService.databases.updateDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: 'room_participants',
          documentId: response.documents.first.$id,
          data: {
            'role': newRole,
            'lastActiveAt': DateTime.now().toIso8601String(),
          },
        );
        AppLogger().debug('✅ Updated participant role: $userId → $newRole');
        
        // Update LiveKit permissions server-side - this is REQUIRED for microphone access
        await updateLiveKitParticipantPermissions(
          roomName: roomId, // In open discussion, roomId is the LiveKit room name
          participantIdentity: userId,
          newRole: newRole,
        );
        
      } else {
        AppLogger().debug('⚠️ No active participant found to update: $userId');
      }
    } catch (e) {
      AppLogger().error('❌ Failed to update participant role: $e');
      rethrow;
    }
  }

  /// Update participant permissions in LiveKit server (dynamic permission change)
  Future<void> updateLiveKitParticipantPermissions({
    required String roomName,
    required String participantIdentity,
    required String newRole,
  }) async {
    try {
      AppLogger().debug('🔑 Updating LiveKit permissions for $participantIdentity to $newRole in room $roomName');

      // Determine new permissions based on role
      bool canPublish = false;
      bool canPublishData = true; // Always allow data publishing for hand raises, etc.
      bool canSubscribe = true; // Always allow subscribing to other participants
      
      switch (newRole) {
        case 'moderator':
          canPublish = true;
          break;
        case 'speaker':
          canPublish = true;
          break;
        case 'audience':
        case 'pending':
          canPublish = false;
          break;
      }

      // Prepare request payload matching LiveKit UpdateParticipantRequest protobuf format
      // Based on LiveKit Node.js SDK: roomService.updateParticipant(roomName, identity, metadata, permission)
      final requestBody = {
        'room': roomName,
        'identity': participantIdentity,
        'metadata': '', // Empty metadata (equivalent to undefined in Node.js SDK)
        'permission': {
          'canPublish': canPublish,
          'canSubscribe': canSubscribe,
          'canPublishData': canPublishData,
        },
      };

      // Get HTTP URL for API calls  
      final String apiUrl = LiveKitConfigService.instance.httpApiUrl;

      // Create authorization header (JWT with roomAdmin permissions)
      final adminToken = LiveKitTokenService.generateToken(
        roomName: roomName,
        identity: 'admin-service',
        userRole: 'admin',
        roomType: 'server-api',
        ttl: const Duration(minutes: 10),
      );

      // Make HTTP POST request to LiveKit UpdateParticipant API
      // Using the exact endpoint format from LiveKit server SDK
      final url = Uri.parse('$apiUrl/twirp/livekit.RoomService/UpdateParticipant');
      
      AppLogger().debug('📡 Making request to: $url');
      AppLogger().debug('🔑 Using admin token: ${adminToken.substring(0, 20)}...');
      AppLogger().debug('📦 Request body: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $adminToken',
        },
        body: jsonEncode(requestBody),
      );

      AppLogger().debug('📬 Response status: ${response.statusCode}');
      AppLogger().debug('📬 Response headers: ${response.headers}');
      AppLogger().debug('📬 Response body: ${response.body}');

      if (response.statusCode == 200) {
        AppLogger().debug('✅ Successfully updated LiveKit permissions for $participantIdentity');
        
        // The participant will receive a ParticipantPermissionsChanged event
        // and can now use their new permissions without reconnecting
      } else {
        final errorBody = response.body;
        AppLogger().error('❌ Failed to update LiveKit permissions: ${response.statusCode}');
        AppLogger().error('❌ Error body: $errorBody');
        AppLogger().error('❌ Request was: ${jsonEncode(requestBody)}');
        AppLogger().error('❌ URL was: $url');
        throw Exception('LiveKit UpdateParticipant failed: ${response.statusCode} - $errorBody');
      }
      
    } catch (e) {
      AppLogger().error('❌ Failed to update LiveKit participant permissions: $e');
      AppLogger().error('❌ Error type: ${e.runtimeType}');
      
      // Don't rethrow LiveKit permission errors if the participant already has mic access
      // This prevents "Failed to promote" errors when the user is already functioning as a speaker
      if (e.toString().contains('400') || e.toString().contains('404') || e.toString().contains('LiveKit')) {
        AppLogger().warning('⚠️ LiveKit permission update failed, but user may already have correct permissions');
        AppLogger().warning('⚠️ User should still be able to speak if they already have mic access');
        // Don't rethrow - this prevents the red error banner
        return;
      } else {
        rethrow;
      }
    }
  }

  // =====================================================
  // STREAM MANAGEMENT
  // =====================================================

  /// Initialize room list stream with real-time updates
  void _initializeRoomListStream() {
    try {
      AppLogger().debug('🔄 Initializing room list stream');
      
      // Set up Appwrite real-time subscription for room changes
      _setupRoomsSubscription();
      
      // Set up periodic refresh as fallback
      _roomsRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        refreshRoomList();
      });
      
      // Initial load
      refreshRoomList();
      
    } catch (e) {
      AppLogger().error('❌ Failed to initialize room list stream: $e');
    }
  }

  /// Set up real-time subscription for room changes
  void _setupRoomsSubscription() {
    try {
      final realtime = AppwriteService().realtime;
      
      _roomsSubscription = realtime.subscribe([
        'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.debateDiscussionRoomsCollection}.documents',
        'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.roomsCollection}.documents',
      ]);

      _roomsSubscription!.stream.listen((data) {
        AppLogger().debug('🔔 Room list update received: ${data.events}');
        AppLogger().debug('🔔 Payload: ${data.payload}');
        AppLogger().debug('🔔 Payload type: ${data.payload.runtimeType}');
        AppLogger().debug('🔔 Room ID in payload: ${data.payload['\$id']}');
        AppLogger().debug('🔔 Room status in payload: ${data.payload['status']}');
        
        // Check if this is a room closure event
        for (final event in data.events) {
          AppLogger().debug('🔔 Processing event: $event');
          
          if ((event.contains('update') || event.contains('delete'))) {
            final roomData = data.payload;
            AppLogger().debug('🔔 Room data: $roomData');
            
            // Handle room deletion (preferred method)
            if (event.contains('delete')) {
              AppLogger().debug('🚪 Room deleted detected: ${roomData['title'] ?? roomData['\$id']}');
              
              // Emit room closure notification immediately
              _roomClosureStreamController.add({
                'roomId': roomData['\$id'],
                'roomTitle': roomData['title'] ?? 'Unknown Room',
                'closedBy': 'moderator',
                'reason': 'moderator_closed',
                'message': 'This room has been closed by the moderator',
              });
              
              // Also refresh immediately to remove from list
              Future.microtask(() => refreshRoomList());
            }
            // Handle room status update (fallback method)
            else if (event.contains('update') && roomData['status'] == 'closed') {
              AppLogger().debug('🚪 Room closed detected: ${roomData['title']}');
              
              // Emit room closure notification immediately
              _roomClosureStreamController.add({
                'roomId': roomData['\$id'],
                'roomTitle': roomData['title'] ?? 'Unknown Room',
                'closedBy': roomData['closedBy'] ?? 'moderator',
                'reason': roomData['closureReason'] ?? 'moderator_closed',
                'message': 'This room has been closed by the moderator',
              });
              
              // Also refresh immediately to remove from list
              Future.microtask(() => refreshRoomList());
            }
          }
        }
        
        // Always refresh room list on any change
        refreshRoomList();
      }, onError: (error) {
        AppLogger().error('❌ Room subscription error: $error');
      });
      
    } catch (e) {
      AppLogger().error('❌ Failed to setup rooms subscription: $e');
    }
  }

  /// Refresh room list and emit to stream
  void refreshRoomList() async {
    try {
      // Invalidate cache to force fresh data on refresh
      _cachedRooms = null;
      _cacheTimestamp = null;
      
      final rooms = await listRooms();
      _roomsStreamController.add(rooms);
      AppLogger().debug('📋 Room list refreshed: ${rooms.length} rooms');
    } catch (e) {
      AppLogger().error('❌ Failed to refresh room list: $e');
    }
  }

  /// Initialize participants stream for a specific room
  void initializeParticipantsStream(String roomId) {
    try {
      if (_currentRoomId == roomId) {
        AppLogger().debug('🔄 Participants stream already initialized for room: $roomId');
        return;
      }

      AppLogger().debug('🔄 Initializing participants stream for room: $roomId');
      _currentRoomId = roomId;
      
      // Clean up previous subscription
      _participantsSubscription?.close();
      
      // Set up Appwrite real-time subscription for participant changes
      _setupParticipantsSubscription(roomId);
      
      // Initial load
      _refreshParticipantsList(roomId);
      
    } catch (e) {
      AppLogger().error('❌ Failed to initialize participants stream: $e');
    }
  }

  /// Set up real-time subscription for participant changes
  void _setupParticipantsSubscription(String roomId) {
    try {
      final realtime = AppwriteService().realtime;
      
      _participantsSubscription = realtime.subscribe([
        'databases.${AppwriteConstants.databaseId}.collections.room_participants.documents',
        'databases.${AppwriteConstants.databaseId}.collections.handraises.documents',
      ]);

      _participantsSubscription!.stream.listen((data) {
        AppLogger().debug('🔔 Participants update received: ${data.events}');
        _refreshParticipantsList(roomId);
      }, onError: (error) {
        AppLogger().error('❌ Participants subscription error: $error');
      });
      
    } catch (e) {
      AppLogger().error('❌ Failed to setup participants subscription: $e');
    }
  }

  /// Refresh participants list and emit to stream
  void _refreshParticipantsList(String roomId) async {
    try {
      final participants = await getRoomParticipants(roomId);
      _participantsStreamController.add(participants);
      AppLogger().debug('👥 Participants list refreshed: ${participants.length} participants');
    } catch (e) {
      AppLogger().error('❌ Failed to refresh participants list: $e');
    }
  }

  /// Clean up participants stream
  void cleanupParticipantsStream() {
    try {
      _participantsSubscription?.close();
      _participantsSubscription = null;
      _currentRoomId = null;
      AppLogger().debug('🔄 Participants stream cleaned up');
    } catch (e) {
      AppLogger().error('❌ Error cleaning up participants stream: $e');
    }
  }

  /// Dispose streams and subscriptions
  void dispose() {
    try {
      _roomsSubscription?.close();
      _participantsSubscription?.close();
      _roomsRefreshTimer?.cancel();
      _roomsStreamController.close();
      _participantsStreamController.close();
      _roomClosureStreamController.close();
      AppLogger().debug('🔄 OpenDiscussionService streams disposed');
    } catch (e) {
      AppLogger().error('❌ Error disposing OpenDiscussionService: $e');
    }
  }

  // =====================================================
  // TOKEN GENERATION
  // =====================================================

  /// Generate access token for joining room
  String generateRoomToken({
    required String roomName,
    required String identity,
    required String role, // 'moderator', 'speaker', 'audience'
  }) {
    return LiveKitTokenService.generateToken(
      roomName: roomName,
      identity: identity,
      userRole: role,
      roomType: 'open_discussion',
      ttl: const Duration(hours: 6),
    );
  }
}