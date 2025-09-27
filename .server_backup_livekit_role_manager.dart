// ignore_for_file: avoid_print, depend_on_referenced_packages, uri_does_not_exist, undefined_method, undefined_getter, unused_import

import 'dart:convert';
import 'dart:io';

/// LiveKit role management server
/// This server handles role changes and updates LiveKit participant permissions
/// Deploy this as a backend service (Cloud Run, Vercel, etc.)
class LiveKitRoleManager {
  final String liveKitHost;
  final String liveKitApiKey;
  final String liveKitSecretKey;
  final AppwriteConfig appwriteConfig;

  LiveKitRoleManager({
    required this.liveKitHost,
    required this.liveKitApiKey,
    required this.liveKitSecretKey,
    required this.appwriteConfig,
  });

  /// Start the server
  Future<void> start({int port = 8080}) async {
    final router = Router();

    // Health check endpoint
    router.get('/health', (Request request) {
      return Response.ok(jsonEncode({'status': 'healthy', 'timestamp': DateTime.now().toIso8601String()}));
    });

    // Promote participant to speaker
    router.post('/api/v1/rooms/<roomId>/promote', _handlePromoteToSpeaker);

    // Demote participant to audience
    router.post('/api/v1/rooms/<roomId>/demote', _handleDemoteToAudience);

    // Request to speak (raise hand)
    router.post('/api/v1/rooms/<roomId>/request-speak', _handleRequestToSpeak);

    // Cancel speaker request
    router.post('/api/v1/rooms/<roomId>/cancel-speak', _handleCancelSpeakerRequest);

    // Get room roster
    router.get('/api/v1/rooms/<roomId>/roster', _handleGetRoster);

    // Send heartbeat
    router.post('/api/v1/rooms/<roomId>/heartbeat', _handleHeartbeat);

    // Get role change events
    router.get('/api/v1/rooms/<roomId>/role-events', _handleGetRoleEvents);

    // LiveKit webhook handler
    router.post('/webhooks/livekit', _handleLiveKitWebhook);

    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware)
        .addMiddleware(_authMiddleware)
        .addHandler(router);

    final server = await io.serve(handler, InternetAddress.anyIPv4, port);
    print('🚀 LiveKit Role Manager running on port ${server.port}');
  }

  /// Handle promote to speaker request
  Future<Response> _handlePromoteToSpeaker(Request request) async {
    try {
      final roomId = request.params['roomId']!;
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final userId = data['userId'] as String;

      // Get user context from JWT
      final userContext = request.context['user'] as Map<String, dynamic>;
      final promoterUserId = userContext['userId'] as String;

      print('Promoting user $userId to speaker in room $roomId by $promoterUserId');

      // Step 1: Validate permissions
      final promoterRole = await _getUserRole(roomId, promoterUserId);
      if (promoterRole != 'moderator') {
        return Response.forbidden(jsonEncode({'error': 'Only moderators can promote participants'}));
      }

      final eventId = _generateEventId();

      // Step 2: Update Appwrite database
      await _updateParticipantRole(
        roomId: roomId,
        userId: userId,
        newRole: 'speaker',
        eventId: eventId,
        triggeredBy: promoterUserId,
      );

      // Step 3: Update LiveKit permissions
      await _updateLiveKitPermissions(
        roomId: roomId,
        userId: userId,
        canPublish: true,
        canPublishData: true,
      );

      // Step 4: Broadcast role change
      await _broadcastRoleChange(
        roomId: roomId,
        userId: userId,
        oldRole: 'audience',
        newRole: 'speaker',
        eventId: eventId,
      );

      return Response.ok(jsonEncode({
        'success': true,
        'eventId': eventId,
        'message': 'User promoted to speaker'
      }));
    } catch (e) {
      print('Error promoting user: $e');
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// Handle demote to audience request
  Future<Response> _handleDemoteToAudience(Request request) async {
    try {
      final roomId = request.params['roomId']!;
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final userId = data['userId'] as String;

      final userContext = request.context['user'] as Map<String, dynamic>;
      final demoterUserId = userContext['userId'] as String;

      print('Demoting user $userId to audience in room $roomId by $demoterUserId');

      // Validate permissions
      final demoterRole = await _getUserRole(roomId, demoterUserId);
      if (demoterRole != 'moderator') {
        return Response.forbidden(jsonEncode({'error': 'Only moderators can demote participants'}));
      }

      final eventId = _generateEventId();

      // Update database
      await _updateParticipantRole(
        roomId: roomId,
        userId: userId,
        newRole: 'audience',
        eventId: eventId,
        triggeredBy: demoterUserId,
      );

      // Update LiveKit permissions
      await _updateLiveKitPermissions(
        roomId: roomId,
        userId: userId,
        canPublish: false,
        canPublishData: true,
      );

      // Broadcast change
      await _broadcastRoleChange(
        roomId: roomId,
        userId: userId,
        oldRole: 'speaker',
        newRole: 'audience',
        eventId: eventId,
      );

      return Response.ok(jsonEncode({
        'success': true,
        'eventId': eventId,
        'message': 'User demoted to audience'
      }));
    } catch (e) {
      print('Error demoting user: $e');
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// Handle request to speak
  Future<Response> _handleRequestToSpeak(Request request) async {
    try {
      final roomId = request.params['roomId']!;
      final userContext = request.context['user'] as Map<String, dynamic>;
      final userId = userContext['userId'] as String;

      print('User $userId requesting to speak in room $roomId');

      final eventId = _generateEventId();

      // Update to pending state
      await _updateParticipantRole(
        roomId: roomId,
        userId: userId,
        newRole: 'pending',
        eventId: eventId,
        triggeredBy: userId,
      );

      // Broadcast the request
      await _broadcastRoleChange(
        roomId: roomId,
        userId: userId,
        oldRole: 'audience',
        newRole: 'pending',
        eventId: eventId,
      );

      return Response.ok(jsonEncode({
        'success': true,
        'eventId': eventId,
        'message': 'Speaker request sent'
      }));
    } catch (e) {
      print('Error requesting to speak: $e');
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// Handle cancel speaker request
  Future<Response> _handleCancelSpeakerRequest(Request request) async {
    try {
      final roomId = request.params['roomId']!;
      final userContext = request.context['user'] as Map<String, dynamic>;
      final userId = userContext['userId'] as String;

      print('User $userId canceling speaker request in room $roomId');

      final eventId = _generateEventId();

      // Update back to audience
      await _updateParticipantRole(
        roomId: roomId,
        userId: userId,
        newRole: 'audience',
        eventId: eventId,
        triggeredBy: userId,
      );

      // Broadcast cancellation
      await _broadcastRoleChange(
        roomId: roomId,
        userId: userId,
        oldRole: 'pending',
        newRole: 'audience',
        eventId: eventId,
      );

      return Response.ok(jsonEncode({
        'success': true,
        'eventId': eventId,
        'message': 'Speaker request cancelled'
      }));
    } catch (e) {
      print('Error canceling speaker request: $e');
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// Handle get roster request
  Future<Response> _handleGetRoster(Request request) async {
    try {
      final roomId = request.params['roomId']!;

      print('Fetching roster for room $roomId');

      final roster = await _getAuthoritativeRoster(roomId);

      return Response.ok(jsonEncode({
        'success': true,
        'roster': roster.entries.map((e) => {
          'userId': e.key,
          'role': e.value,
        }).toList(),
      }));
    } catch (e) {
      print('Error fetching roster: $e');
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// Handle heartbeat
  Future<Response> _handleHeartbeat(Request request) async {
    try {
      final roomId = request.params['roomId']!;
      final userContext = request.context['user'] as Map<String, dynamic>;
      final userId = userContext['userId'] as String;

      // Update last heartbeat
      await _updateLastHeartbeat(roomId, userId);

      return Response.ok(jsonEncode({'success': true}));
    } catch (e) {
      print('Error handling heartbeat: $e');
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// Handle get role events
  Future<Response> _handleGetRoleEvents(Request request) async {
    try {
      final roomId = request.params['roomId']!;
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '50') ?? 50;

      final events = await _getRoleChangeEvents(roomId, limit);

      return Response.ok(jsonEncode({
        'success': true,
        'events': events,
      }));
    } catch (e) {
      print('Error fetching role events: $e');
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// Handle LiveKit webhooks
  Future<Response> _handleLiveKitWebhook(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      print('Received LiveKit webhook: ${data['event']}');

      // Handle participant events
      switch (data['event']) {
        case 'participant_joined':
          await _handleParticipantJoined(data);
          break;
        case 'participant_left':
          await _handleParticipantLeft(data);
          break;
        case 'participant_disconnected':
          await _handleParticipantDisconnected(data);
          break;
      }

      return Response.ok(jsonEncode({'success': true}));
    } catch (e) {
      print('Error handling webhook: $e');
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // Helper methods (implement these based on your backend technology)

  Future<String> _getUserRole(String roomId, String userId) async {
    // Query Appwrite to get user's role
    // Return 'moderator', 'speaker', 'pending', or 'audience'
    return 'audience'; // Placeholder
  }

  Future<void> _updateParticipantRole({
    required String roomId,
    required String userId,
    required String newRole,
    required String eventId,
    required String triggeredBy,
  }) async {
    // Update Appwrite database
    // Include eventId for idempotency
  }

  Future<void> _updateLiveKitPermissions({
    required String roomId,
    required String userId,
    required bool canPublish,
    required bool canPublishData,
  }) async {
    try {
      // Generate JWT token for LiveKit API
      final token = _generateLiveKitToken();

      // Call LiveKit API to update participant permissions
      final response = await http.post(
        Uri.parse('$liveKitHost/twirp/livekit.RoomService/UpdateParticipant'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'room': roomId,
          'identity': userId,
          'permission': {
            'canPublish': canPublish,
            'canPublishData': canPublishData,
            'canSubscribe': true,
          },
        }),
      );

      if (response.statusCode != 200) {
        print('Failed to update LiveKit permissions: ${response.body}');
      }
    } catch (e) {
      print('Error updating LiveKit permissions: $e');
    }
  }

  Future<void> _broadcastRoleChange({
    required String roomId,
    required String userId,
    required String oldRole,
    required String newRole,
    required String eventId,
  }) async {
    // Broadcast via LiveKit data channel or WebSocket
    // This ensures all clients get the update immediately
  }

  Future<Map<String, String>> _getAuthoritativeRoster(String roomId) async {
    // Query Appwrite for current room participants and their roles
    return {}; // Placeholder
  }

  Future<void> _updateLastHeartbeat(String roomId, String userId) async {
    // Update lastHeartbeat timestamp in Appwrite
  }

  Future<List<Map<String, dynamic>>> _getRoleChangeEvents(String roomId, int limit) async {
    // Query role_change_events collection
    return []; // Placeholder
  }

  Future<void> _handleParticipantJoined(Map<String, dynamic> data) async {
    // Update participant presence
  }

  Future<void> _handleParticipantLeft(Map<String, dynamic> data) async {
    // Update participant presence
  }

  Future<void> _handleParticipantDisconnected(Map<String, dynamic> data) async {
    // Handle disconnection, possibly auto-demote
  }

  String _generateLiveKitToken() {
    // Generate JWT token for LiveKit API authentication
    return 'placeholder_token';
  }

  String _generateEventId() {
    return 'evt_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  // Middleware

  Middleware get _corsMiddleware {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }

        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  Map<String, String> get _corsHeaders => {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  Middleware get _authMiddleware {
    return (Handler innerHandler) {
      return (Request request) async {
        // Skip auth for health check and OPTIONS
        if (request.url.path == '/health' || request.method == 'OPTIONS') {
          return innerHandler(request);
        }

        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response.unauthorized(jsonEncode({'error': 'Missing or invalid authorization header'}));
        }

        final token = authHeader.substring(7);

        try {
          // Verify JWT token with Appwrite or your auth provider
          final userContext = await _verifyToken(token);

          // Add user context to request
          final updatedRequest = request.change(context: {'user': userContext});
          return innerHandler(updatedRequest);
        } catch (e) {
          return Response.unauthorized(jsonEncode({'error': 'Invalid token'}));
        }
      };
    };
  }

  Future<Map<String, dynamic>> _verifyToken(String token) async {
    // Verify JWT token and return user context
    // This should validate with your auth provider (Appwrite, Firebase, etc.)
    return {'userId': 'user123'}; // Placeholder
  }
}

/// Appwrite configuration
class AppwriteConfig {
  final String endpoint;
  final String projectId;
  final String databaseId;
  final String apiKey;

  AppwriteConfig({
    required this.endpoint,
    required this.projectId,
    required this.databaseId,
    required this.apiKey,
  });
}

/// Main entry point
void main() async {
  final liveKitHost = Platform.environment['LIVEKIT_HOST'] ?? 'https://your-livekit.com';
  final liveKitApiKey = Platform.environment['LIVEKIT_API_KEY'] ?? '';
  final liveKitSecretKey = Platform.environment['LIVEKIT_SECRET_KEY'] ?? '';

  final appwriteConfig = AppwriteConfig(
    endpoint: Platform.environment['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1',
    projectId: Platform.environment['APPWRITE_PROJECT_ID'] ?? '',
    databaseId: Platform.environment['APPWRITE_DATABASE_ID'] ?? 'arena_db',
    apiKey: Platform.environment['APPWRITE_API_KEY'] ?? '',
  );

  final server = LiveKitRoleManager(
    liveKitHost: liveKitHost,
    liveKitApiKey: liveKitApiKey,
    liveKitSecretKey: liveKitSecretKey,
    appwriteConfig: appwriteConfig,
  );

  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  await server.start(port: port);
}