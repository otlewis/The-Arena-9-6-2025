# Phase 3 Complete: Client Service Implementation ✅

## What Was Created

### RoleAssignmentService - Single Interface for Role Changes

**File**: `lib/services/role_assignment_service.dart`

**Purpose**: Unified, atomic role assignment client that ensures synchronized updates across database, LiveKit, and all connected clients.

## Service Features

### 1. Unified `assignRole()` Method ✅

Single method for ALL role changes in the app:

```dart
final service = RoleAssignmentService();

final result = await service.assignRole(
  roomId: 'arena_room_123',
  userId: 'user_456',
  role: ArenaRole.judge1,
  requesterId: currentUserId,
);

if (result.success) {
  print('✅ Role assigned: ${result.assignedRole}');
  print('Version: ${result.version}');
  print('LiveKit synced: ${result.livekitUpdated}');
} else {
  print('❌ Failed: ${result.error} (${result.code})');
}
```

### 2. Optimistic Updates with Rollback ✅

Immediate UI feedback with automatic rollback on failure:

```dart
await service.assignRole(
  roomId: roomId,
  userId: userId,
  role: ArenaRole.affirmative,
  requesterId: currentUserId,
  optimisticUpdate: () {
    // Update UI immediately
    setState(() {
      participants[userId]?.role = 'affirmative';
    });
  },
  rollback: () {
    // Revert UI if function fails
    setState(() {
      participants[userId]?.role = previousRole;
    });
  },
);
```

### 3. Duplicate Request Prevention ✅

Prevents multiple identical requests from racing:

```dart
// These calls will be deduplicated automatically
service.assignRole(...); // Executes
service.assignRole(...); // Waits for first to complete (if identical)
```

### 4. Realtime Event Subscription ✅

Listen for role changes in a room:

```dart
final subscription = service.subscribeToRoleEvents(roomId);

subscription.listen((event) {
  print('Role changed: ${event.userId} → ${event.role.value}');
  print('Version: ${event.version}');

  // Trigger snapshot refresh
  await refreshParticipants();
});
```

## ArenaRole Enum

Type-safe role representation:

```dart
enum ArenaRole {
  affirmative('affirmative'),
  negative('negative'),
  judge1('judge1'),
  judge2('judge2'),
  judge3('judge3'),
  moderator('moderator'),
  audience('audience');
}

// Usage:
final role = ArenaRole.judge1;
print(role.value); // "judge1"

// From string:
final parsed = ArenaRole.fromString('judge2');
```

## RoleAssignmentResult

Detailed result with all relevant information:

```dart
class RoleAssignmentResult {
  final bool success;
  final ArenaRole? assignedRole;      // Actual role assigned (may differ from requested)
  final int? version;                  // Version number for this change
  final DateTime? timestamp;           // Server timestamp
  final bool? livekitUpdated;         // Was LiveKit successfully updated?
  final ArenaRole? previousRole;      // User's previous role
  final String? error;                // Error message (if failed)
  final String? code;                 // Error code (if failed)
}
```

## Integration Examples

### Example 1: Moderator Assigning Judge

```dart
// In moderator_control_modal.dart
class _ModeratorControlsState extends State<ModeratorControls> {
  final _roleService = RoleAssignmentService();

  Future<void> _assignJudge(String userId) async {
    final result = await _roleService.assignRole(
      roomId: widget.roomId,
      userId: userId,
      role: ArenaRole.judge1,
      requesterId: widget.currentUserId,
      optimisticUpdate: () {
        // Show loading indicator
        setState(() => _isAssigningRole = true);
      },
      rollback: () {
        // Hide loading, show error
        setState(() => _isAssigningRole = false);
        _showError('Failed to assign judge role');
      },
    );

    setState(() => _isAssigningRole = false);

    if (result.success) {
      _showSuccess('Assigned ${userId} as ${result.assignedRole?.value}');
    } else {
      _showError('Error: ${result.error}');
    }
  }
}
```

### Example 2: Arena Provider with Event Listening

```dart
// In arena_provider.dart
class ArenaProvider extends StateNotifier<ArenaState> {
  final _roleService = RoleAssignmentService();
  StreamSubscription<ArenaRoleEvent>? _roleEventsSub;

  void initRoom(String roomId) {
    // Subscribe to role change events
    _roleEventsSub = _roleService.subscribeToRoleEvents(roomId).listen((event) {
      debugPrint('📡 Role event: ${event.userId} → ${event.role.value}');

      // Refresh participants snapshot to get authoritative state
      _refreshParticipants(roomId);
    });
  }

  Future<void> assignRole(String userId, ArenaRole role, String requesterId) async {
    final result = await _roleService.assignRole(
      roomId: state.roomId,
      userId: userId,
      role: role,
      requesterId: requesterId,
    );

    if (result.success) {
      // State automatically updates via realtime subscription
      debugPrint('✅ Role assigned at version ${result.version}');
    } else {
      // Handle error
      _showError(result.error);
    }
  }

  @override
  void dispose() {
    _roleEventsSub?.cancel();
    super.dispose();
  }
}
```

### Example 3: Direct Usage in Widget

```dart
// In arena_screen.dart
class _ArenaScreenState extends State<ArenaScreen> {
  final _roleService = RoleAssignmentService();

  Future<void> _handleRoleSelection(String userId, String roleString) async {
    final role = ArenaRole.fromString(roleString);

    // Store current role for rollback
    final previousRole = _participants[userId]?.role;

    final result = await _roleService.assignRole(
      roomId: widget.roomId,
      userId: userId,
      role: role,
      requesterId: _currentUserId,
      optimisticUpdate: () {
        // Update local state immediately
        setState(() {
          _participants[userId]?.role = roleString;
        });
      },
      rollback: () {
        // Revert on failure
        setState(() {
          _participants[userId]?.role = previousRole;
        });
      },
    );

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${result.error}')),
      );
    }
  }
}
```

## Migration Checklist

### Current Code to Update:

1. **Arena Screen** (`lib/screens/arena_screen.dart`)
   - Replace direct database writes with `service.assignRole()`
   - Add role event listener for snapshot refresh

2. **Moderator Controls** (`lib/features/arena/dialogs/moderator_control_modal.dart`)
   - Use service for all moderator-initiated role changes
   - Add optimistic UI updates

3. **Arena Provider** (`lib/features/arena/providers/arena_provider.dart`)
   - Add service instance
   - Implement role event subscription
   - Replace any direct DB operations

4. **Create Arena Room** (`lib/features/arena/widgets/create_arena_room.dart`)
   - Initial moderator assignment can use service
   - Or keep direct DB for room creation flow

### Migration Strategy:

**Phase 4** (Next):
1. Add `RoleAssignmentService` instance to arena provider
2. Update moderator controls to use service
3. Add realtime event listeners for snapshot refresh

**Phase 5** (After):
1. Replace ALL direct database writes
2. Remove old role assignment code paths
3. Test with multiple devices

**Phase 6** (Testing):
1. Test role conflicts (duplicate moderator, judge slots)
2. Test network failures and rollback
3. Test multi-device synchronization
4. Verify no desyncs occur

## Error Codes

The service returns standardized error codes:

| Code | Meaning |
|------|---------|
| `INVALID_REQUEST` | Missing required fields |
| `INVALID_ROLE` | Role name not valid |
| `UNAUTHORIZED` | User lacks permission |
| `INTERNAL_ERROR` | Server error |
| `EXCEPTION` | Client-side exception |
| `APPWRITE_ERROR` | Appwrite SDK error |
| `HTTP_XXX` | Non-200 HTTP response |

## Benefits vs. Old Approach

### Before (Direct DB Writes)
- ❌ No version control → race conditions
- ❌ DB and LiveKit updated separately → desyncs
- ❌ No conflict resolution → duplicate moderators
- ❌ No optimistic updates → slow UX
- ❌ Multiple code paths → bugs

### After (RoleAssignmentService)
- ✅ Single atomic function call
- ✅ Automatic versioning
- ✅ Conflict resolution built-in
- ✅ Optimistic updates with rollback
- ✅ Type-safe API
- ✅ Duplicate request prevention
- ✅ Realtime event broadcasting
- ✅ Centralized error handling

## Debug Logging

The service includes extensive logging:

```
🔄 Performing optimistic UI update for user_123 → judge1
📡 Calling assign-arena-role function...
📤 Function request: {"roomId":"room_123","userId":"user_123","role":"judge1","requesterId":"mod_456"}
📥 Function response status: 200
📥 Function response body: {"success":true,"assignedRole":"judge1","version":42,...}
✅ Role assignment successful: judge1 (version: 42)
```

On failure:
```
❌ Role assignment failed: Permission denied
↩️  Rolling back optimistic update
```

## Next Steps (Phase 4)

Now that the service is complete, we need to integrate it:

1. Update arena providers to use `RoleAssignmentService`
2. Update moderator controls dialog
3. Update arena_screen.dart
4. Add version checking to realtime listeners
5. Implement snapshot refresh on role events

Ready to proceed when you are! 🚀

## Phase 3 Status: COMPLETE ✅

- ✅ RoleAssignmentService class created
- ✅ Unified assignRole() method implemented
- ✅ Optimistic updates with rollback
- ✅ Duplicate request prevention
- ✅ Realtime event subscription
- ✅ Type-safe ArenaRole enum
- ✅ Comprehensive error handling
- ✅ Debug logging
- ✅ Documentation and examples
