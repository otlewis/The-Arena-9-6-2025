# Arena Race Conditions - Complete Analysis

## Summary

The Arena screen has **7 critical race conditions** that cause role assignment failures, duplicate events, and inconsistent state. These issues prevent users from speaking after being promoted and cause UI flickering.

---

## 🔴 Race Condition #1: Broken Webhook Integration

**Location**: `lib/screens/arena_screen.dart:7681-7794`

**Problem**:
The n8n webhook function exists but is **NEVER CALLED**. Role assignments go directly to Appwrite without updating LiveKit permissions first.

**Current Flow** (Broken):
```
Moderator assigns role
    ↓
Appwrite database updated
    ↓
LiveKit permissions NOT updated ❌
    ↓
User cannot enable microphone ❌
```

**Expected Flow** (Working in Debates & Discussions):
```
Moderator assigns role
    ↓
n8n webhook called
    ↓
LiveKit permissions updated FIRST ✅
    ↓
Appwrite database updated
    ↓
User can speak immediately ✅
```

**Code Evidence**:
```dart
// Line 7681: Webhook function EXISTS but unused
Future<bool> _assignRoleViaWebhook(String userId, String role) async {
  final webhookUrl = 'http://50.21.187.76/webhook/assign-arena-role';
  // ... implementation
}

// Line 7712: _assignRole() does NOT call webhook
Future<void> _assignRole(String userId, String newRole) async {
  await _sendRoleChangeNotification(userId, newRole);  // Just notification
  setState(() { /* optimistic update */ });
  await _appwrite.assignArenaRole(...);  // Direct database ❌
}
```

**Fix Required**:
```dart
Future<void> _assignRole(String userId, String newRole) async {
  // Try webhook first
  final webhookSuccess = await _assignRoleViaWebhook(userId, newRole);

  if (!webhookSuccess) {
    // Fallback to direct update with warning
    await _appwrite.assignArenaRole(...);
  }
}
```

---

## 🔴 Race Condition #2: LiveKit Data Channel ≠ Permission Update

**Location**: `lib/screens/arena_screen.dart:7724-7824`

**Problem**:
`_sendRoleChangeNotification()` sends a message to the user but does NOT grant LiveKit publish permissions.

**Code Evidence**:
```dart
// Line 7797: This is just a NOTIFICATION
Future<void> _sendRoleChangeNotification(String userId, String newRole) async {
  await _liveKitService.localParticipant?.publishData(
    messageBytes,
    destinationIdentities: [userId],  // Sends message
  );
  // ❌ Does NOT call LiveKit Server API to update permissions
  // ❌ Does NOT set canPublish: true
}
```

**What's Missing**:
- No call to `POST /twirp/livekit.RoomService/UpdateParticipant`
- No `canPublish: true` in participant permissions
- User receives notification but still can't publish audio

**Impact**:
User sees "You are now affirmative debater" but microphone button stays disabled.

---

## 🔴 Race Condition #3: Optimistic Update Without Rollback

**Location**: `lib/screens/arena_screen.dart:7730-7793`

**Problem**:
UI updates immediately, but if database fails, there's no rollback mechanism.

**Flow**:
```dart
// 1. Optimistic update
setState(() {
  _participants[newRole] = userProfile;  // UI shows new role ✅
});

// 2. Database update (could fail)
await _appwrite.assignArenaRole(...);  // Network error, validation error

// 3. No rollback
// ❌ UI still shows user in new role
// ❌ Database has user in old role
// ❌ Inconsistent state
```

**Race Scenario**:
1. Moderator assigns User A to "affirmative"
2. UI shows User A as affirmative (optimistic)
3. Database call fails (network timeout)
4. UI still shows User A as affirmative ❌
5. User A cannot speak (no permissions)
6. Other users see User A as audience
7. Room is in inconsistent state

**Fix Required**:
```dart
setState(() { /* optimistic update */ });

try {
  await _appwrite.assignArenaRole(...);
} catch (e) {
  // ROLLBACK optimistic update
  setState(() {
    _participants[newRole] = null;
    _audience.add(userProfile);
  });
  showError('Failed to assign role');
}
```

---

## 🔴 Race Condition #4: Check-Then-Act in Role Assignment

**Location**: `lib/services/appwrite_service.dart:3225-3304`

**Problem**:
Classic TOCTOU (Time-Of-Check-Time-Of-Use) race condition.

**Code Evidence**:
```dart
// 1. Check existing roles (Time of Check)
final existingRolesResponse = await databases.listDocuments(...);
final existingRoles = existingRolesResponse.documents
    .map((doc) => doc.data['role'] as String)
    .toList();

// 2. Gap between check and create
if (existingRoles.contains('moderator')) {
  finalRole = 'audience';
}

// 3. Create document (Time of Use)
await databases.createDocument(
  data: {'role': finalRole},
);
```

**Race Scenario**:
```
Moderator A                    Moderator B
    |                              |
    ├─ Check affirmative slot      |
    |  (empty) ✅                   |
    |                              ├─ Check affirmative slot
    |                              |  (empty) ✅
    ├─ Assign User X               |
    |  to affirmative              |
    |                              ├─ Assign User Y
    |                              |  to affirmative
    └─ Both written! ❌            └─ Both written! ❌

Result: Two users in same role slot
```

**Fix Required**:
Use database transactions or unique constraints:
```dart
// Option 1: Unique index on (roomId, role)
// Option 2: Optimistic concurrency control with version field
// Option 3: Server-side function with transaction
```

---

## 🔴 Race Condition #5: Duplicate Cleanup Race

**Location**: `lib/services/appwrite_service.dart:3281-3296`

**Problem**:
Cleanup and creation are separate operations without atomicity.

**Code Evidence**:
```dart
// 1. Cleanup duplicates
await _cleanupArenaParticipantDuplicates(roomId, userId);

// 2. Create new entry (gap between cleanup and create)
await databases.createDocument(...);
```

**Race Scenario**:
```
Moderator A                           Moderator B
    |                                     |
    ├─ Assign User X to affirmative      |
    |  - Cleanup User X                  |
    |                                    ├─ Assign User X to judge1
    |                                    |  - Cleanup User X
    ├─ Create User X as affirmative      |
    |                                    ├─ Create User X as judge1
    └─ Both exist! ❌                    └─ Both exist! ❌

Result: User X has TWO active participant records
```

---

## 🔴 Race Condition #6: Multiple Event Streams & Double Subscriptions

**Location**: `lib/screens/arena_screen.dart:902-1040, 1143-1217, 5795-5844`

### Problem 6A: Re-subscription Without Cleanup

**Code Evidence**:
```dart
void _setupRealtimeSubscription() async {
  // ❌ No check if subscription already exists
  // ❌ No cancellation of old subscription

  _roomSubscription = await _realtimeManager.subscribeToRoom(
    roomId: widget.roomId,
    roomType: 'arena',
  );
  // Creates NEW subscription even if old one exists
}
```

**Called From**:
- Line 733: Initial iOS setup
- Line 761: Standard setup
- Line 1021: Reconnect on error
- Line 1035: Reconnect on close

**Race Scenario**:
```
T1: Initial connection → Subscription A created ✅
T2: Network hiccup → onError triggered
T3: Reconnect timer fires → Subscription B created
T4: Both subscriptions active ❌
T5: Role change event arrives
T6: Event processed by Subscription A → setState()
T7: Event processed by Subscription B → setState()
T8: UI rebuilds twice, queries run twice
```

### Problem 6B: Four Separate Subscription Systems

**Code Evidence**:
```dart
// System 1: Centralized (line 913)
_roomSubscription = await _realtimeManager.subscribeToRoom(...)

// System 2: Direct judgments (line 1143)
_arenaJudgmentsSubscription = realtime.subscribe([
  'databases.arena_db.collections.arena_judgments.documents'
])

// System 3: Direct notifications (line 1215)
_notificationsStreamListener = realtime.subscribe([
  'databases.arena_db.collections.arena_notifications.documents'
])

// System 4: Direct reactions (line 5798)
_reactionsSubscription = realtime.subscribe([
  'databases.arena_db.collections.room_reactions.documents'
])
```

**Impact**:
When role changes, multiple subscriptions fire → 3-4 concurrent setState() calls.

### Problem 6C: Reconnect Timers Not Cancelled

**Code Evidence**:
```dart
// Line 1019: Creates timer on error
Timer(Duration(seconds: delaySeconds), () {
  _setupRealtimeSubscription();
});

// Line 1033: Creates ANOTHER timer on close
Timer(const Duration(seconds: 3), () {
  _setupRealtimeSubscription();
});

// ❌ Old timers never cancelled
// ❌ Multiple timers can fire
```

**Race Scenario**:
```
T1: Connection drops → onError → Timer A (5 sec)
T2: Connection closes → onDone → Timer B (3 sec)
T3 (3 sec): Timer B fires → Subscription 1
T4 (5 sec): Timer A fires → Subscription 2
T5: TWO subscriptions active → duplicate events
```

**Fix Required**:
```dart
Timer? _reconnectTimer;

void _setupRealtimeSubscription() async {
  // Cancel old timer
  _reconnectTimer?.cancel();

  // Cancel old subscription
  if (_roomSubscription != null) {
    await _participantStreamListener?.cancel();
    await _roomStatusStreamListener?.cancel();
    _roomSubscription = null;
  }

  // Create new subscription
  _roomSubscription = await _realtimeManager.subscribeToRoom(...);
}
```

---

## 🔴 Race Condition #7: Stale Local State

**Location**: `lib/screens/arena_screen.dart:7730-7773, 7987-8065, 2632-2680`

### Problem 7A: Triple State Update

**Flow**:
```dart
// UPDATE 1: Optimistic (moderator)
setState(() { _participants[newRole] = userProfile; });

// UPDATE 2: Database write
await _appwrite.assignArenaRole(...);

// UPDATE 3: Realtime subscription
_handleArenaParticipantRoleChange(payload);
setState(() { _participants[newRole] = userProfile; });

// UPDATE 4: Manual refresh
await _loadParticipants();  // Overwrites everything
```

**Race Scenario**:
```
T1: Assign User A to affirmative
T2: Optimistic update → UI shows User A as affirmative ✅
T3: Database write starts (slow network)
T4: Assign User B to judge1
T5: Second optimistic update → UI shows User B as judge1 ✅
T6: First database write completes → realtime fires
T7: _handleArenaParticipantRoleChange() for User A
T8: _loadParticipants() called
T9: Fetches from database → User B not in DB yet ❌
T10: UI shows User B disappeared ❌
T11: Second database write completes
T12: User B reappears ✅
```

### Problem 7B: No Version Control

**Code Evidence**:
```dart
// No timestamps or version numbers
setState(() {
  _userRole = newRole;  // Could be overwritten by stale update
});
```

**Race Scenario**:
```
T1: Promoted to judge1 → _userRole = 'judge1' ✅
T2: Promoted to affirmative → _userRole = 'affirmative' ✅
T3: First realtime event (delayed) → _userRole = 'judge1' ❌ (stale)
T4: UI shows wrong role
T5: Second realtime event → _userRole = 'affirmative' ✅ (correct)
```

### Problem 7C: `_loadParticipants()` Overwrites Optimistic Updates

**Code Evidence**:
```dart
// Line 7755: Optimistic update
_participants[newRole] = userProfile;

// Line 7764: Database write starts (100-500ms)
await _appwrite.assignArenaRole(...);

// Line 7773: Fetch IMMEDIATELY (before write finishes)
await _loadParticipants();

// Line 2632: CLEARS optimistic update
_participants = {
  'moderator': null,
  'affirmative': null,
  // ... all null
};

// Line 2676: Rebuilds from database (doesn't have new role yet)
_participants[role] = userProfile;  // Old role from database ❌
```

**Impact**: User flashes between roles as optimistic update → cleared → re-added.

### Problem 7D: `_userRole` Out of Sync with `_participants`

**Code Evidence**:
```dart
String _userRole = 'audience';  // Line 551
Map<String, UserProfile?> _participants = { /* ... */ };  // Line 553

// These are updated SEPARATELY
```

**Race Scenario**:
```dart
// Update 1: Optimistic
_participants['affirmative'] = currentUser;
// _userRole still = 'audience' ❌

// Update 2: Realtime
_userRole = 'affirmative';
// _participants might be cleared by _loadParticipants()

// Update 3: Another moderator demotes
_participants['affirmative'] = null;
// _userRole still = 'affirmative' ❌
```

**Impact**:
- `_isModerator` getter uses `_userRole`
- Shows moderator controls when user is audience
- Or hides controls when user is moderator

---

## Comparison: Arena vs Debates & Discussions

| Feature | Arena | Debates & Discussions |
|---------|-------|----------------------|
| **Webhook Integration** | ❌ Function exists, not called | ✅ Active, working |
| **LiveKit Permission Update** | ❌ Only notification sent | ✅ Server API called |
| **Optimistic Rollback** | ❌ No rollback | ❌ No rollback |
| **Concurrent Role Conflicts** | ❌ No protection | ❌ No protection |
| **Subscription Management** | ❌ No cleanup before reconnect | ✅ Proper cleanup |
| **Duplicate Subscription Prevention** | ❌ None | ✅ Guards in place |
| **Reconnect Timer Management** | ❌ Multiple timers | ✅ Single timer |
| **State Update Ordering** | ❌ Stale overwrites fresh | ⚠️ Partial mitigation |

---

## Critical Fixes Needed (Priority Order)

### 1. **Enable Webhook for Role Assignments** (Highest Priority)
Update `_assignRole()` to call `_assignRoleViaWebhook()` first, matching Debates & Discussions pattern.

### 2. **Add Subscription Guards**
Prevent duplicate subscriptions by checking and cancelling old ones.

### 3. **Implement Rollback Logic**
Add try-catch with state rollback if database update fails.

### 4. **Add Version Control to State Updates**
Include timestamps to prevent stale updates from overwriting fresh data.

### 5. **Remove `_loadParticipants()` After Optimistic Update**
Wait for realtime subscription instead of immediately querying database.

### 6. **Consolidate Subscription Systems**
Move all subscriptions into RealtimeManager, remove separate direct subscriptions.

### 7. **Add Database Constraints**
Implement unique constraints or transactions to prevent concurrent role conflicts.

### 8. **Synchronize `_userRole` with `_participants`**
Derive `_userRole` from `_participants` instead of maintaining separate state.

---

## Testing Recommendations

1. **Multi-moderator stress test**: Two moderators assign roles rapidly
2. **Network latency simulation**: Add 500ms delay to Appwrite calls
3. **Reconnection testing**: Drop WebSocket connection during role change
4. **Concurrent role changes**: Assign same user to different roles simultaneously
5. **Database failure testing**: Kill Appwrite during role assignment

---

---

## 🔴 Race Condition #8: Server-Client Drift (Latency / Missed Events)

**Location**: `lib/screens/arena_screen.dart:487-534, 1004-1038, 1275-1476`

### Problem: Reconnection Causes Missed Events

Events fired during WebSocket disconnection are **lost forever** with no replay mechanism.

**Race Scenario**:
```
T1: Network drops → WebSocket disconnects
T2: Reconnect scheduled (2-10 seconds exponential backoff)
T3: Moderator assigns user to affirmative
T4: Database updated
T5: Realtime event fired BUT client offline ❌
T6: Reconnection completes
T7: Client syncs from database ✅
T8: BUT LiveKit permissions never updated ❌
T9: User shows as affirmative but cannot speak
```

**Code Evidence**:
```dart
// Line 913: New subscription after reconnect
_roomSubscription = await _realtimeManager.subscribeToRoom(...)

// Line 919: Only receives NEW events
_participantStreamListener = _roomSubscription!.participants.listen((response) {
  // ❌ No replay of events missed during disconnection
});
```

### Problem: `_loadParticipants()` Doesn't Fix Permissions

After reconnection, role data syncs but LiveKit permissions don't update.

**Fix Required**:
```dart
if (wasDisconnected) {
  // 1. Resync participant state
  await _loadParticipants();

  // 2. If role changed during disconnect, update permissions
  if (_userRole != oldRole && _shouldUserPublishMedia()) {
    await _reconnectWithNewPermissions();
  }
}
```

---

## 🔴 Race Condition #9: No Unique Ownership of Role

**Location**: `lib/services/appwrite_service.dart:3188-3304`

### Problem: No Database Constraint

The `arena_participants` collection has **NO unique index** on `(roomId, role)`.

**Database Structure**:
```
arena_participants:
  ✅ id (unique)
  ❌ (roomId, role) - NO unique constraint

Result: Multiple users can have same role
```

### Problem: 300ms Race Window

**Code Flow**:
```dart
// 1. CHECK roles (50ms)
final existingRoles = await databases.listDocuments(...);

// 2. CLEANUP old entries (200ms)
await _cleanupArenaParticipantDuplicates(roomId, userId);

// 3. CREATE new entry (50ms)
await databases.createDocument(
  data: { 'role': finalRole },
);

Total: 300ms race window ❌
```

### Race Scenario: Two Users, Same Role

```
Moderator A                          Moderator B
    |                                     |
T0  ├─ Assign User X to affirmative      |
T1  |  Check: affirmative empty ✅       |
T3  |  Cleanup User X entries             |
T4  |                                    ├─ Assign User Y to affirmative
T5  |                                    |  Check: affirmative empty ✅
T6  |                                    |  Cleanup User Y entries
T7  |  Create: User X = affirmative      |
T8  |                                    |  Create: User Y = affirmative
T9  └─ Success ✅                        └─ Success ✅

Result: TWO affirmative debaters in database ❌
```

**UI Impact**:
```
Client A sees: Affirmative = User X
Client B sees: Affirmative = User Y
Database has: BOTH User X and User Y as affirmative

Who can speak? → Audio collision
Which vote counts? → Scoring broken
```

### Problem: Moderator Slot Has Same Bug

```dart
// Line 3245: Check-then-act
if (existingRoles.contains('moderator')) {
  finalRole = 'audience';
} else {
  finalRole = 'moderator';  // Two users can pass this check
}
```

**Race Scenario**:
```
User A and User B join simultaneously
Both check: moderator slot empty ✅
Both assign: self as moderator
Result: TWO moderators ❌
```

### Proper Solutions

**Option 1: Database Unique Constraint** (Best)
```sql
CREATE UNIQUE INDEX idx_room_role
ON arena_participants (roomId, role)
WHERE isActive = true;
```

**Option 2: Server-Side Transaction** (Recommended)
```javascript
// Appwrite Function with atomic transaction
const result = await database.transaction(async (tx) => {
  // 1. Check + Delete + Create in single transaction
  const existing = await tx.query(
    `SELECT * FROM arena_participants
     WHERE roomId = $1 AND role = $2 AND isActive = true`,
    [roomId, role]
  );

  if (existing.length > 0) {
    throw new Error('Role already taken');
  }

  await tx.deleteOldEntries(roomId, userId);
  await tx.createNewEntry(roomId, userId, role);

  return { success: true };
});
```

---

## Related Files

- `lib/screens/arena_screen.dart` - Main Arena UI with all race conditions
- `lib/services/appwrite_service.dart` - Role assignment with TOCTOU bug and no unique constraints
- `lib/screens/debates_discussions_screen.dart` - Reference for working webhook pattern
- `SPEAKER_PROMOTION_FIX.md` - Documentation of Debates & Discussions fix (not applied to Arena)

---

## Summary

The Arena screen has **9 interconnected race conditions** that compound each other:

1. **No webhook** → users can't speak (permissions never updated)
2. **Optimistic updates without rollback** → UI shows wrong state
3. **Duplicate subscriptions** → events processed multiple times
4. **Stale data** → updates overwrite each other
5. **Database TOCTOU** → check-then-act vulnerability
6. **Duplicate cleanup race** → concurrent assignments conflict
7. **Multiple event streams** → 3-4 concurrent setState() calls
8. **Server-client drift** → missed events during disconnection
9. **No unique ownership** → multiple users in same role slot

**Root Cause Chain**:
```
No webhook (#1)
    ↓
Permissions never updated
    ↓
Database shows correct role (#2 optimistic)
    ↓
But LiveKit has wrong permissions
    ↓
User cannot speak
    ↓
Network drops (#8)
    ↓
Reconnection loses permission update event
    ↓
State permanently broken
    ↓
Meanwhile, another user assigned to same slot (#9)
    ↓
Both users show as affirmative
    ↓
Both try to speak → audio collision
    ↓
Room becomes unusable
```

**Result**: Users assigned to roles cannot speak, UI flickers, multiple users occupy same role, and room state becomes permanently inconsistent.
