import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/logging/app_logger.dart';
import 'role_authority_service.dart';

/// API endpoints for role management operations
/// These should be hosted on your backend server (Node.js, Python, etc.)
/// This class provides the client-side interface to those endpoints
class RoleManagementAPI {
  static final RoleManagementAPI _instance = RoleManagementAPI._internal();
  factory RoleManagementAPI() => _instance;
  RoleManagementAPI._internal();

  final AppLogger _logger = AppLogger();
  final RoleAuthorityService _roleService = RoleAuthorityService();

  // Configure your backend API URL
  static const String _baseUrl = 'https://your-arena-api.com'; // Replace with your backend URL
  static const String _apiVersion = 'v1';

  /// Promote a participant to speaker
  Future<ApiResponse<void>> promoteToSpeaker({
    required String roomId,
    required String userId,
    required String authToken,
  }) async {
    try {
      _logger.info('API: Promoting user $userId to speaker in room $roomId');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/$_apiVersion/rooms/$roomId/promote'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        _logger.info('Successfully promoted user via API');
        return ApiResponse.success(null);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        _logger.error('API promotion failed: $error');
        return ApiResponse.error(error);
      }
    } catch (e) {
      _logger.error('API promotion error: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Demote a participant to audience
  Future<ApiResponse<void>> demoteToAudience({
    required String roomId,
    required String userId,
    required String authToken,
  }) async {
    try {
      _logger.info('API: Demoting user $userId to audience in room $roomId');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/$_apiVersion/rooms/$roomId/demote'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        _logger.info('Successfully demoted user via API');
        return ApiResponse.success(null);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        _logger.error('API demotion failed: $error');
        return ApiResponse.error(error);
      }
    } catch (e) {
      _logger.error('API demotion error: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Request to speak (raise hand)
  Future<ApiResponse<void>> requestToSpeak({
    required String roomId,
    required String authToken,
  }) async {
    try {
      _logger.info('API: Requesting to speak in room $roomId');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/$_apiVersion/rooms/$roomId/request-speak'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        _logger.info('Successfully requested to speak via API');
        return ApiResponse.success(null);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        _logger.error('API speak request failed: $error');
        return ApiResponse.error(error);
      }
    } catch (e) {
      _logger.error('API speak request error: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Cancel speaker request (lower hand)
  Future<ApiResponse<void>> cancelSpeakerRequest({
    required String roomId,
    required String authToken,
  }) async {
    try {
      _logger.info('API: Canceling speaker request in room $roomId');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/$_apiVersion/rooms/$roomId/cancel-speak'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        _logger.info('Successfully cancelled speaker request via API');
        return ApiResponse.success(null);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        _logger.error('API cancel request failed: $error');
        return ApiResponse.error(error);
      }
    } catch (e) {
      _logger.error('API cancel request error: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Get authoritative room roster
  Future<ApiResponse<Map<String, ParticipantRole>>> getRoomRoster({
    required String roomId,
    required String authToken,
  }) async {
    try {
      _logger.info('API: Fetching room roster for room $roomId');

      final response = await http.get(
        Uri.parse('$_baseUrl/api/$_apiVersion/rooms/$roomId/roster'),
        headers: {
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final roster = <String, ParticipantRole>{};

        for (final entry in data['roster']) {
          final userId = entry['userId'] as String;
          final role = _parseRole(entry['role'] as String);
          roster[userId] = role;
        }

        _logger.info('Successfully fetched roster with ${roster.length} participants');
        return ApiResponse.success(roster);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        _logger.error('API roster fetch failed: $error');
        return ApiResponse.error(error);
      }
    } catch (e) {
      _logger.error('API roster fetch error: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Send heartbeat to maintain presence
  Future<ApiResponse<void>> sendHeartbeat({
    required String roomId,
    required String authToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/$_apiVersion/rooms/$roomId/heartbeat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        return ApiResponse.success(null);
      } else {
        return ApiResponse.error('Heartbeat failed');
      }
    } catch (e) {
      return ApiResponse.error('Heartbeat error: $e');
    }
  }

  /// Get role change events (for audit/debugging)
  Future<ApiResponse<List<RoleChangeEvent>>> getRoleChangeEvents({
    required String roomId,
    required String authToken,
    int limit = 50,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/$_apiVersion/rooms/$roomId/role-events?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final events = <RoleChangeEvent>[];

        for (final eventData in data['events']) {
          events.add(RoleChangeEvent(
            roomId: eventData['roomId'],
            userId: eventData['userId'],
            oldRole: _parseRole(eventData['oldRole']),
            newRole: _parseRole(eventData['newRole']),
            eventId: eventData['eventId'],
            timestamp: DateTime.parse(eventData['timestamp']),
          ));
        }

        return ApiResponse.success(events);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        return ApiResponse.error(error);
      }
    } catch (e) {
      return ApiResponse.error('Events fetch error: $e');
    }
  }

  /// Parse role string to enum
  ParticipantRole _parseRole(String roleString) {
    switch (roleString.toLowerCase()) {
      case 'moderator':
        return ParticipantRole.moderator;
      case 'speaker':
        return ParticipantRole.speaker;
      case 'pending':
        return ParticipantRole.pending;
      case 'audience':
      default:
        return ParticipantRole.audience;
    }
  }
}

/// Generic API response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResponse._({
    required this.success,
    this.data,
    this.error,
  });

  factory ApiResponse.success(T data) {
    return ApiResponse._(success: true, data: data);
  }

  factory ApiResponse.error(String error) {
    return ApiResponse._(success: false, error: error);
  }
}

/// Fallback implementation using direct Appwrite calls
/// Use this when you don't have a backend API server yet
class DirectAppwriteRoleAPI {
  final RoleAuthorityService _roleService = RoleAuthorityService();
  final AppLogger _logger = AppLogger();

  /// Promote to speaker using direct Appwrite
  Future<ApiResponse<void>> promoteToSpeaker({
    required String roomId,
    required String userId,
    required String promoterUserId,
  }) async {
    try {
      await _roleService.promoteToSpeaker(
        roomId: roomId,
        userId: userId,
        promoterUserId: promoterUserId,
      );
      return ApiResponse.success(null);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Demote to audience using direct Appwrite
  Future<ApiResponse<void>> demoteToAudience({
    required String roomId,
    required String userId,
    required String demoterUserId,
  }) async {
    try {
      await _roleService.demoteToAudience(
        roomId: roomId,
        userId: userId,
        demoterUserId: demoterUserId,
      );
      return ApiResponse.success(null);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Request to speak using direct Appwrite
  Future<ApiResponse<void>> requestToSpeak({
    required String roomId,
    required String userId,
  }) async {
    try {
      await _roleService.requestToSpeak(
        roomId: roomId,
        userId: userId,
      );
      return ApiResponse.success(null);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Cancel speaker request using direct Appwrite
  Future<ApiResponse<void>> cancelSpeakerRequest({
    required String roomId,
    required String userId,
  }) async {
    try {
      await _roleService.cancelSpeakerRequest(
        roomId: roomId,
        userId: userId,
      );
      return ApiResponse.success(null);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Get roster using direct Appwrite
  Future<ApiResponse<Map<String, ParticipantRole>>> getRoomRoster({
    required String roomId,
  }) async {
    try {
      final roster = await _roleService.getAuthoritativeRoster(roomId);
      return ApiResponse.success(roster);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }
}