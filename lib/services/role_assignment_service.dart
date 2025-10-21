import 'dart:async';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import '../services/appwrite_service.dart';

/// Single source of truth for all arena role assignments
///
/// This service ensures atomic, synchronized role changes across:
/// - Appwrite database (with versioning)
/// - LiveKit media permissions
/// - All connected clients
///
/// Usage:
/// ```dart
/// final service = RoleAssignmentService();
/// final result = await service.assignRole(
///   roomId: 'room_123',
///   userId: 'user_456',
///   role: ArenaRole.judge1,
///   requesterId: currentUserId,
/// );
/// ```
class RoleAssignmentService {
  static final RoleAssignmentService _instance = RoleAssignmentService._internal();
  factory RoleAssignmentService() => _instance;
  RoleAssignmentService._internal();

  final _appwriteService = AppwriteService();

  // Track in-flight requests to prevent duplicate calls
  final Map<String, Completer<RoleAssignmentResult>> _pendingRequests = {};

  /// Assign a role to a user in an arena room
  ///
  /// This method:
  /// 1. Performs optimistic UI update (optional)
  /// 2. Calls the backend function for atomic updates
  /// 3. Handles rollback on failure
  /// 4. Returns detailed result with version info
  ///
  /// Parameters:
  /// - [roomId]: The arena room ID
  /// - [userId]: User whose role is being changed
  /// - [role]: New role to assign
  /// - [requesterId]: User making the request (must be moderator/super mod)
  /// - [optimisticUpdate]: Callback for immediate UI update (optional)
  /// - [rollback]: Callback to revert optimistic update on failure (optional)
  Future<RoleAssignmentResult> assignRole({
    required String roomId,
    required String userId,
    required ArenaRole role,
    required String requesterId,
    VoidCallback? optimisticUpdate,
    VoidCallback? rollback,
  }) async {
    // Create unique key for this request
    final requestKey = '$roomId:$userId:${role.value}';

    // Check if identical request is already in flight
    if (_pendingRequests.containsKey(requestKey)) {
      debugPrint('⏳ Duplicate role assignment request detected, waiting for existing request...');
      return await _pendingRequests[requestKey]!.future;
    }

    // Create completer for this request
    final completer = Completer<RoleAssignmentResult>();
    _pendingRequests[requestKey] = completer;

    try {
      // Step 1: Perform optimistic UI update if provided
      if (optimisticUpdate != null) {
        debugPrint('🔄 Performing optimistic UI update for $userId → ${role.value}');
        optimisticUpdate();
      }

      // Step 2: Call backend function
      debugPrint('📡 Calling assign-arena-role function...');
      final result = await _callAssignRoleFunction(
        roomId: roomId,
        userId: userId,
        role: role,
        requesterId: requesterId,
      );

      // Step 3: Handle result
      if (result.success) {
        debugPrint('✅ Role assignment successful: ${result.assignedRole?.value ?? "unknown"} (version: ${result.version})');
        completer.complete(result);
        return result;
      } else {
        debugPrint('❌ Role assignment failed: ${result.error}');

        // Step 4: Rollback optimistic update
        if (rollback != null) {
          debugPrint('↩️  Rolling back optimistic update');
          rollback();
        }

        completer.complete(result);
        return result;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Exception during role assignment: $e');
      debugPrint('Stack trace: $stackTrace');

      // Rollback on exception
      if (rollback != null) {
        debugPrint('↩️  Rolling back optimistic update due to exception');
        rollback();
      }

      final errorResult = RoleAssignmentResult.error(
        error: e.toString(),
        code: 'EXCEPTION',
      );

      completer.complete(errorResult);
      return errorResult;
    } finally {
      // Clean up pending request
      _pendingRequests.remove(requestKey);
    }
  }

  /// Internal method to call the Appwrite function
  Future<RoleAssignmentResult> _callAssignRoleFunction({
    required String roomId,
    required String userId,
    required ArenaRole role,
    required String requesterId,
  }) async {
    try {
      final functions = Functions(_appwriteService.client);

      // Prepare request body
      final requestBody = jsonEncode({
        'roomId': roomId,
        'userId': userId,
        'role': role.value,
        'requesterId': requesterId,
      });

      debugPrint('📤 Function request: $requestBody');

      // Execute function
      final execution = await functions.createExecution(
        functionId: 'assign-arena-role',
        body: requestBody,
      );

      debugPrint('📥 Function response status: ${execution.responseStatusCode}');
      debugPrint('📥 Function response body: ${execution.responseBody}');

      // Parse response
      if (execution.responseStatusCode == 200) {
        final responseData = jsonDecode(execution.responseBody) as Map<String, dynamic>;

        if (responseData['success'] == true) {
          return RoleAssignmentResult(
            success: true,
            assignedRole: responseData['assignedRole'] != null
                ? ArenaRole.fromString(responseData['assignedRole'] as String)
                : null,
            version: responseData['version'] as int,
            timestamp: DateTime.parse(responseData['timestamp'] as String),
            livekitUpdated: responseData['livekitUpdated'] as bool? ?? false,
            previousRole: responseData['previousRole'] != null
                ? ArenaRole.fromString(responseData['previousRole'] as String)
                : null,
          );
        } else {
          return RoleAssignmentResult.error(
            error: responseData['error'] as String? ?? 'Unknown error',
            code: responseData['code'] as String? ?? 'UNKNOWN',
          );
        }
      } else {
        // Non-200 response
        final responseData = jsonDecode(execution.responseBody) as Map<String, dynamic>;
        return RoleAssignmentResult.error(
          error: responseData['error'] as String? ?? 'Function returned non-200 status',
          code: responseData['code'] as String? ?? 'HTTP_${execution.responseStatusCode}',
        );
      }
    } on AppwriteException catch (e) {
      debugPrint('❌ AppwriteException: ${e.message} (code: ${e.code})');
      return RoleAssignmentResult.error(
        error: e.message ?? 'Appwrite error',
        code: e.code?.toString() ?? 'APPWRITE_ERROR',
      );
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return RoleAssignmentResult.error(
        error: e.toString(),
        code: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// Subscribe to role change events for a specific room
  ///
  /// Returns a stream of role change events that can be used to
  /// trigger snapshot refreshes
  Stream<ArenaRoleEvent> subscribeToRoleEvents(String roomId) {
    final realtime = Realtime(_appwriteService.client);
    final subscription = realtime.subscribe([
      'databases.arena_db.collections.arena_events.documents',
    ]);

    return subscription.stream
        .where((event) {
          // Filter for role_changed events in this room
          final payload = event.payload;
          return payload['type'] == 'role_changed' &&
                 payload['roomId'] == roomId;
        })
        .map((event) {
          final payload = event.payload;
          return ArenaRoleEvent(
            type: payload['type'] as String,
            roomId: payload['roomId'] as String,
            userId: payload['userId'] as String,
            role: ArenaRole.fromString(payload['role'] as String),
            version: payload['version'] as int,
            timestamp: DateTime.parse(payload['timestamp'] as String),
            requesterId: payload['requesterId'] as String,
          );
        });
  }

  /// Clear all pending requests (useful for cleanup)
  void clearPendingRequests() {
    _pendingRequests.clear();
  }
}

/// Arena role enumeration
enum ArenaRole {
  affirmative('affirmative'),
  negative('negative'),
  judge1('judge1'),
  judge2('judge2'),
  judge3('judge3'),
  moderator('moderator'),
  audience('audience');

  final String value;
  const ArenaRole(this.value);

  static ArenaRole fromString(String value) {
    return ArenaRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => ArenaRole.audience,
    );
  }
}

/// Result of a role assignment operation
class RoleAssignmentResult {
  final bool success;
  final ArenaRole? assignedRole;
  final int? version;
  final DateTime? timestamp;
  final bool? livekitUpdated;
  final ArenaRole? previousRole;
  final String? error;
  final String? code;

  RoleAssignmentResult({
    required this.success,
    this.assignedRole,
    this.version,
    this.timestamp,
    this.livekitUpdated,
    this.previousRole,
    this.error,
    this.code,
  });

  factory RoleAssignmentResult.error({
    required String error,
    required String code,
  }) {
    return RoleAssignmentResult(
      success: false,
      error: error,
      code: code,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'RoleAssignmentResult(success: true, role: ${assignedRole?.value}, version: $version)';
    } else {
      return 'RoleAssignmentResult(success: false, error: $error, code: $code)';
    }
  }
}

/// Arena role change event from realtime subscription
class ArenaRoleEvent {
  final String type;
  final String roomId;
  final String userId;
  final ArenaRole role;
  final int version;
  final DateTime timestamp;
  final String requesterId;

  ArenaRoleEvent({
    required this.type,
    required this.roomId,
    required this.userId,
    required this.role,
    required this.version,
    required this.timestamp,
    required this.requesterId,
  });

  @override
  String toString() {
    return 'ArenaRoleEvent(type: $type, user: $userId, role: ${role.value}, version: $version)';
  }
}
