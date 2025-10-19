import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../core/logging/app_logger.dart';

/// Debates & Discussions Role Types
enum DDRole {
  moderator,
  speaker,
  pending,
  audience,
}

extension DDRoleExtension on DDRole {
  String get value {
    switch (this) {
      case DDRole.moderator:
        return 'moderator';
      case DDRole.speaker:
        return 'speaker';
      case DDRole.pending:
        return 'pending';
      case DDRole.audience:
        return 'audience';
    }
  }

  static DDRole fromString(String value) {
    switch (value) {
      case 'moderator':
        return DDRole.moderator;
      case 'speaker':
        return DDRole.speaker;
      case 'pending':
        return DDRole.pending;
      case 'audience':
      default:
        return DDRole.audience;
    }
  }
}

/// Event broadcast when a role changes
class DDRoleEvent {
  final String roomId;
  final String userId;
  final DDRole role;
  final int version;
  final DateTime timestamp;
  final String? requesterId;

  DDRoleEvent({
    required this.roomId,
    required this.userId,
    required this.role,
    required this.version,
    required this.timestamp,
    this.requesterId,
  });

  factory DDRoleEvent.fromDocument(models.Document doc) {
    return DDRoleEvent(
      roomId: doc.data['roomId'] ?? '',
      userId: doc.data['userId'] ?? '',
      role: DDRoleExtension.fromString(doc.data['role'] ?? 'audience'),
      version: doc.data['version'] ?? 0,
      timestamp: DateTime.parse(doc.data['timestamp'] ?? DateTime.now().toIso8601String()),
      requesterId: doc.data['requesterId'],
    );
  }
}

/// Service for atomic Debates & Discussions role assignments
///
/// This service ensures role assignments are:
/// - Atomic (database + LiveKit updated together)
/// - Versioned (prevents out-of-order updates)
/// - Optimistic (instant UI feedback with rollback on failure)
/// - Synchronized (all devices see changes within 300ms)
class DDRoleAssignmentService {
  final Functions _functions;
  final Realtime _realtime;
  final String _databaseId = 'arena_db';
  final String _eventsCollectionId = 'dd_events';

  // Track pending requests to prevent duplicates
  final Map<String, DateTime> _pendingRequests = {};
  final Duration _requestCooldown = const Duration(milliseconds: 200);

  DDRoleAssignmentService({
    required Functions functions,
    required Databases databases,
    required Realtime realtime,
  })  : _functions = functions,
        _realtime = realtime;

  /// Assign a role to a user in a Debates & Discussions room
  ///
  /// Returns the assigned role (may differ from requested if conflict resolution occurred)
  ///
  /// Example:
  /// ```dart
  /// final result = await service.assignRole(
  ///   roomId: roomId,
  ///   userId: userId,
  ///   role: DDRole.speaker,
  ///   requesterId: currentUserId,
  ///   optimisticUpdate: () {
  ///     // Update UI instantly
  ///     setState(() => _participants[userId] = 'speaker');
  ///   },
  ///   rollback: () {
  ///     // Revert UI if backend fails
  ///     setState(() => _participants[userId] = oldRole);
  ///   },
  /// );
  /// ```
  Future<Map<String, dynamic>> assignRole({
    required String roomId,
    required String userId,
    required DDRole role,
    required String requesterId,
    Function()? optimisticUpdate,
    Function()? rollback,
  }) async {
    final requestKey = '$roomId-$userId-${role.value}';

    // Prevent duplicate rapid requests
    if (_pendingRequests.containsKey(requestKey)) {
      final lastRequest = _pendingRequests[requestKey]!;
      if (DateTime.now().difference(lastRequest) < _requestCooldown) {
        AppLogger().warning('⚠️ Duplicate role assignment request ignored (cooldown)');
        return {
          'success': false,
          'error': 'Request too soon after previous request',
          'code': 'DUPLICATE_REQUEST',
        };
      }
    }

    _pendingRequests[requestKey] = DateTime.now();

    AppLogger().info('📡 D&D Role Assignment: $userId → ${role.value} in room $roomId');

    // Optimistic update (instant UI feedback)
    if (optimisticUpdate != null) {
      AppLogger().debug('  ⚡ Applying optimistic update');
      optimisticUpdate();
    }

    try {
      // Call backend function
      final execution = await _functions.createExecution(
        functionId: 'assign-dd-role',
        body: {
          'roomId': roomId,
          'userId': userId,
          'role': role.value,
          'requesterId': requesterId,
        }.toString(),
      );

      // Parse response
      final responseBody = execution.responseBody;
      final response = _parseResponse(responseBody);

      if (response['success'] == true) {
        AppLogger().info('✅ D&D Role assignment successful');
        AppLogger().debug('  - Assigned role: ${response['assignedRole']}');
        AppLogger().debug('  - Version: ${response['version']}');
        AppLogger().debug('  - LiveKit updated: ${response['livekitUpdated']}');

        return response;
      } else {
        // Backend returned error - rollback optimistic update
        AppLogger().error('❌ D&D Role assignment failed: ${response['error']}');
        if (rollback != null) {
          AppLogger().debug('  🔄 Rolling back optimistic update');
          rollback();
        }

        return response;
      }
    } catch (e) {
      AppLogger().error('❌ D&D Role assignment exception: $e');

      // Rollback optimistic update on exception
      if (rollback != null) {
        AppLogger().debug('  🔄 Rolling back optimistic update due to exception');
        rollback();
      }

      return {
        'success': false,
        'error': e.toString(),
        'code': 'EXCEPTION',
      };
    } finally {
      // Clear pending request after timeout
      Future.delayed(_requestCooldown, () {
        _pendingRequests.remove(requestKey);
      });
    }
  }

  /// Subscribe to role change events for a room
  ///
  /// All clients subscribe to this to receive real-time role updates
  ///
  /// Example:
  /// ```dart
  /// _subscription = service.subscribeToRoleEvents(roomId)
  ///   .listen((event) {
  ///     print('Role changed: ${event.userId} → ${event.role.value}');
  ///     _refreshParticipants();
  ///   });
  /// ```
  Stream<DDRoleEvent> subscribeToRoleEvents(String roomId) {
    AppLogger().info('🔔 Subscribing to D&D role events for room: $roomId');

    final subscription = _realtime.subscribe([
      'databases.$_databaseId.collections.$_eventsCollectionId.documents',
    ]);

    return subscription.stream
        .where((response) {
          // Filter for events related to this room
          final payload = response.payload;
          return payload['roomId'] == roomId && payload['type'] == 'role_changed';
        })
        .map((response) {
          final doc = models.Document.fromMap(response.payload);
          return DDRoleEvent.fromDocument(doc);
        });
  }

  /// Parse function response body
  Map<String, dynamic> _parseResponse(String responseBody) {
    try {
      // Response is already a JSON string, parse it
      final dynamic parsed = _parseJson(responseBody);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
      return {
        'success': false,
        'error': 'Invalid response format',
        'code': 'PARSE_ERROR',
      };
    } catch (e) {
      AppLogger().error('Failed to parse response: $e');
      return {
        'success': false,
        'error': 'Failed to parse response: $e',
        'code': 'PARSE_ERROR',
      };
    }
  }

  /// Simple JSON parser
  dynamic _parseJson(String jsonString) {
    // Remove any leading/trailing whitespace
    jsonString = jsonString.trim();

    // If it starts with {, it's an object
    if (jsonString.startsWith('{')) {
      final Map<String, dynamic> result = {};
      // Remove braces
      final content = jsonString.substring(1, jsonString.length - 1).trim();
      if (content.isEmpty) return result;

      // Split by commas (simple parser, doesn't handle nested objects)
      final pairs = content.split(',');
      for (final pair in pairs) {
        final keyValue = pair.split(':');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim().replaceAll('"', '');
          var value = keyValue[1].trim();

          // Parse value
          if (value == 'true') {
            result[key] = true;
          } else if (value == 'false') {
            result[key] = false;
          } else if (value == 'null') {
            result[key] = null;
          } else if (value.startsWith('"') && value.endsWith('"')) {
            result[key] = value.substring(1, value.length - 1);
          } else {
            // Try to parse as number
            final num = int.tryParse(value) ?? double.tryParse(value);
            result[key] = num ?? value;
          }
        }
      }
      return result;
    }

    return jsonString;
  }

  /// Cleanup method - call when disposing the service
  void dispose() {
    _pendingRequests.clear();
  }
}
