# Arena Role Synchronization Architecture

## Problem Statement

Clients experience desynchronization where some devices show a user in a speaker slot while others show them in audience. This happens because:

1. **Race conditions** - Role updates through multiple paths (webhook, DB write, optimistic UI)
2. **Event propagation gaps** - Realtime events arrive late, dropped, or applied before state is ready
3. **Multiple sources of truth** - UI, Appwrite DB, and LiveKit permissions updated non-atomically
4. **Missing reconciliation** - No guaranteed snapshot resync when events are missed

## Solution Architecture

### 1. Single Source of Truth: Appwrite Function

**Function**: `assign-arena-role`

**Responsibilities**:
- Validate permissions
- Update Appwrite DB with versioned document
- Update LiveKit media permissions
- Emit canonical "role_changed" event
- Return atomic success/failure

**Input**:
```json
{
  "roomId": "string",
  "userId": "string",
  "role": "affirmative|negative|judge1|judge2|judge3|moderator|audience",
  "requesterId": "string",
  "clientVersion": "number (optional)"
}
```

**Output**:
```json
{
  "success": true,
  "assignedRole": "judge1",
  "version": 42,
  "timestamp": "2025-01-19T...",
  "livekitUpdated": true
}
```

### 2. Versioned Participant Documents

**Schema Addition** to `arena_participants`:
```dart
{
  "userId": "...",
  "roomId": "...",
  "role": "...",
  "version": 1,              // NEW: Monotonically increasing
  "updatedAt": "ISO8601",    // NEW: Timestamp for ordering
  "assignedAt": "ISO8601",   // Existing
  "isActive": true,
  "livekitSynced": true      // NEW: Track media permission sync
}
```

**Version Rules**:
- Clients only apply updates if `event.version > local.version`
- Backend increments version on every role change
- Prevents out-of-order event application

### 3. Event + Snapshot Model

**On Role Change**:
1. Client makes optimistic UI update
2. Calls `assign-arena-role` function
3. Function returns with new version
4. Client receives realtime event with version
5. Client fetches fresh snapshot and reconciles

**On Reconnect**:
- Always fetch snapshot
- Reconcile local state with server state
- Update UI to match truth

### 4. Unified Client Flow

**New Service**: `RoleAssignmentService`

```dart
class RoleAssignmentService {
  // Single method for ALL role changes
  Future<RoleChangeResult> assignRole({
    required String roomId,
    required String userId,
    required String targetRole,
  }) async {
    // 1. Optimistic update
    _updateLocalStateOptimistic(userId, targetRole);

    try {
      // 2. Call backend function
      final result = await _callAssignRoleFunction(roomId, userId, targetRole);

      // 3. Force snapshot refresh
      await _refreshParticipantSnapshot(roomId);

      // 4. Reconcile UI
      _reconcileWithSnapshot();

      return RoleChangeResult.success(result);
    } catch (e) {
      // 5. Rollback on failure
      await _rollbackOptimisticUpdate(userId);
      return RoleChangeResult.failure(e);
    }
  }
}
```

### 5. Cross-Client Event Broadcasting

**Option A: LiveKit Data Messages** (Recommended)
- Use LiveKit's data channel for instant cross-client sync
- Lightweight "role_changed" ping
- All clients refetch snapshot on receive

**Option B: Arena Events Collection**
- Create `arena_events` collection
- Write event: `{type: 'role_changed', roomId, userId, version, timestamp}`
- Realtime subscription triggers snapshot refresh

**Implementation**: Use LiveKit data for speed, with Appwrite events as backup

### 6. Snapshot Reconciliation

**After Every Role Event**:
```dart
Future<void> _reconcileParticipants(String roomId) async {
  // 1. Fetch authoritative snapshot
  final snapshot = await appwrite.databases.listDocuments(
    databaseId: 'arena_db',
    collectionId: 'arena_participants',
    queries: [
      Query.equal('roomId', roomId),
      Query.equal('isActive', true),
      Query.orderDesc('version'), // Get latest versions
    ],
  );

  // 2. Build participant map by userId
  final serverState = <String, Participant>{};
  for (final doc in snapshot.documents) {
    final userId = doc.data['userId'];
    final version = doc.data['version'];

    // Keep highest version for each user
    if (!serverState.containsKey(userId) ||
        version > serverState[userId]!.version) {
      serverState[userId] = Participant.fromMap(doc.data);
    }
  }

  // 3. Update local state to match server
  setState(() {
    _participants = serverState;
    _rebuildRoleSlots();
  });
}
```

### 7. LiveKit Permission Sync

**In Backend Function**:
```javascript
// After DB update succeeds
const livekit = require('livekit-server-sdk');

async function updateLivekitPermissions(roomId, userId, role) {
  const canPublish = ['affirmative', 'negative', 'judge1', 'judge2', 'judge3', 'moderator'].includes(role);

  const participantInfo = await livekitClient.updateParticipant(
    roomId,
    userId,
    {
      canPublish: canPublish,
      canSubscribe: true,
      canPublishData: true,
    }
  );

  return { success: true, participantInfo };
}
```

## Implementation Checklist

### Phase 1: Backend Function
- [ ] Create `appwrite-functions/assign-arena-role/`
- [ ] Implement function with validation
- [ ] Add LiveKit permission updates
- [ ] Add version increment logic
- [ ] Deploy and test function

### Phase 2: Schema Updates
- [ ] Add `version` field to arena_participants collection (default: 1)
- [ ] Add `updatedAt` field to arena_participants collection
- [ ] Add `livekitSynced` field to arena_participants collection
- [ ] Migration script for existing documents

### Phase 3: Client Service
- [ ] Create `RoleAssignmentService`
- [ ] Implement unified `assignRole()` method
- [ ] Add optimistic updates
- [ ] Add rollback logic
- [ ] Add snapshot reconciliation

### Phase 4: Realtime Integration
- [ ] Update realtime listeners to check version
- [ ] Add snapshot refresh on role_changed events
- [ ] Add reconnection snapshot refresh
- [ ] Implement LiveKit data message broadcasting

### Phase 5: Refactoring
- [ ] Replace all direct DB role writes with service calls
- [ ] Update `arena_screen.dart` to use new service
- [ ] Update moderator controls to use new service
- [ ] Update webhook handlers to call backend function

### Phase 6: Testing
- [ ] Test with 2 devices simultaneously changing roles
- [ ] Test with poor network (delayed events)
- [ ] Test reconnection scenarios
- [ ] Test version conflict resolution
- [ ] Verify LiveKit permissions sync correctly

## Migration Strategy

### Week 1: Preparation
- Deploy backend function (shadow mode - log only, don't write)
- Add new fields to schema
- Monitor logs for conflicts

### Week 2: Dual Write
- Backend function writes to DB
- Old client code still works
- Both paths run in parallel
- Compare results, fix discrepancies

### Week 3: Client Migration
- Deploy new RoleAssignmentService
- Gradually migrate UI components
- Monitor sync quality metrics

### Week 4: Cleanup
- Remove old direct DB write code
- Backend function becomes authoritative
- Remove dual-write logic

## Monitoring & Metrics

**Add Logging**:
- Role assignment latency
- Version conflicts detected
- Snapshot reconciliation frequency
- LiveKit sync failures

**Success Criteria**:
- Zero version conflicts after 48 hours
- <100ms role change latency
- 100% LiveKit sync success rate
- Zero user-reported desyncs

## Rollback Plan

If issues arise:
1. Revert client to direct DB writes
2. Keep backend function for new clients
3. Gradual rollout with feature flag
4. A/B test: 10% → 50% → 100%

## Future Enhancements

1. **Optimistic Locking**: Use document `$updatedAt` for conflict detection
2. **Event Sourcing**: Log all role changes for audit/replay
3. **Conflict Resolution UI**: Let moderator resolve conflicts manually
4. **Real-time Sync Status**: Show sync indicator to users
5. **Automatic Healing**: Background task to detect and fix desyncs
