# Role Authority System Implementation Guide

## Overview

This guide helps you implement the new Role Authority System that eliminates state sync inconsistencies across clients. The system ensures all role changes go through a central authority (backend) preventing the split-brain scenarios where different clients see different role states.

## Problem Solved

**Before**: User switches roles → Some clients update, others don't → Inconsistent state across devices
**After**: All role changes go through backend → All clients receive authoritative updates → Consistent state everywhere

## Implementation Steps

### Step 1: Update Appwrite Collections Schema

Run the database schema update script:

```bash
dart run scripts/update_participant_collections_schema.dart
```

This adds the following fields to all participant collections:
- `role` (string) - Authoritative role field
- `eventId` (string) - For idempotency
- `roleUpdatedAt` (datetime) - Timestamp tracking
- `lastHeartbeat` (datetime) - Presence tracking
- `isConnected` (boolean) - Connection status

### Step 2: Deploy Backend API Server

Deploy the `server/livekit_role_manager.dart` to your cloud provider:

**Option A: Google Cloud Run**
```bash
# Build Docker image
docker build -t role-manager .
docker tag role-manager gcr.io/your-project/role-manager
docker push gcr.io/your-project/role-manager

# Deploy to Cloud Run
gcloud run deploy role-manager \
  --image gcr.io/your-project/role-manager \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars LIVEKIT_HOST=your-livekit-host \
  --set-env-vars LIVEKIT_API_KEY=your-api-key \
  --set-env-vars APPWRITE_ENDPOINT=https://cloud.appwrite.io/v1 \
  --set-env-vars APPWRITE_PROJECT_ID=your-project-id
```

**Option B: Vercel/Netlify Functions**
- Convert the Dart server to Node.js/Python
- Deploy as serverless functions

**Option C: Use Direct Appwrite (No Server Required)**
- Use the `DirectAppwriteRoleAPI` class instead
- All operations go directly through Appwrite
- Good for MVP/testing

### Step 3: Update Client Code

#### Replace Old Role Management

**Before (Old Pattern):**
```dart
// DON'T DO THIS - Direct local mutations
setState(() {
  participants[userId].role = 'speaker';
});
```

**After (New Pattern):**
```dart
// DO THIS - Go through authority system
await clientRoleManager.promoteToSpeaker(userId);
// UI updates automatically via streams
```

#### Initialize the New System

```dart
// In your main.dart or room join logic
final clientRoleManager = ClientRoleManager();
await clientRoleManager.initialize(currentUserId);
await clientRoleManager.joinRoom(roomId);

// Listen to authoritative roster updates
clientRoleManager.rosterStream.listen((roster) {
  // Update your UI with the authoritative roster
  setState(() {
    this.participants = roster;
  });
});
```

### Step 4: Update UI Components

#### Replace Role Mutations in Widgets

**Before:**
```dart
// In your participant panel
onTap: () {
  setState(() {
    participant.role = 'speaker'; // LOCAL MUTATION - BAD
  });
}
```

**After:**
```dart
// In your participant panel
onTap: () async {
  if (clientRoleManager.canModerate) {
    await clientRoleManager.promoteToSpeaker(participant.userId);
    // UI updates automatically via roleStream
  }
}
```

#### Add Role Request Buttons

```dart
// Raise hand button
if (clientRoleManager.isAudience)
  ElevatedButton(
    onPressed: () => clientRoleManager.requestToSpeak(),
    child: Text('Raise Hand'),
  ),

// Cancel request button
if (clientRoleManager.hasPendingSpeakerRequest)
  ElevatedButton(
    onPressed: () => clientRoleManager.cancelSpeakerRequest(),
    child: Text('Lower Hand'),
  ),
```

### Step 5: Remove All Local Role Mutations

**Search and Replace These Patterns:**

1. **Direct role assignments:**
```dart
// REMOVE THESE
participant.role = 'speaker';
setState(() { userRole = 'audience'; });
_updateParticipantRole(userId, newRole);
```

2. **Local state toggles:**
```dart
// REMOVE THESE
_isCurrentUserSpeaker = true;
_isModerator = false;
widget.participants.where((p) => p.role == 'speaker').forEach(...)
```

3. **Optimistic UI updates:**
```dart
// REMOVE THESE - Let backend be source of truth
setState(() {
  // Optimistically show as speaker
  localParticipant.role = 'speaker';
});
```

### Step 6: Test the Implementation

#### Manual Testing Checklist

1. **Single Device Test:**
   - [ ] Join room → Role fetched from backend
   - [ ] Raise hand → Shows as pending
   - [ ] Moderator promotes → Shows as speaker
   - [ ] Leave and rejoin → Role persists correctly

2. **Multi-Device Test:**
   - [ ] Device A raises hand
   - [ ] Device B (moderator) sees the request
   - [ ] Device B promotes Device A
   - [ ] Device A immediately sees speaker role
   - [ ] Device C also sees Device A as speaker

3. **Edge Cases:**
   - [ ] Network disconnection during role change
   - [ ] Multiple rapid role changes
   - [ ] Room with 50+ participants
   - [ ] Concurrent moderator actions

#### Automated Testing

Run the comprehensive test suite:
```bash
./test/run_all_tests.sh
```

This includes:
- Unit tests for RoleAuthorityService
- Integration tests for role change flows
- Performance tests with multiple participants

### Step 7: Monitor and Debug

#### Use the Admin Dashboard

Navigate to the Role Authority Admin Dashboard to monitor:
- Real-time participant states across all rooms
- Recent role change events with timestamps
- System health metrics and stale connections
- Event idempotency and duplicate detection

#### Enable Debug Logging

```dart
// In your app initialization
AppLogger.setLevel(LogLevel.debug);

// This will show:
// - Role change events received
// - Backend authority decisions
// - Heartbeat status
// - Event idempotency checks
```

## Architecture Summary

### Data Flow

1. **User Action** → Client calls RoleManager method
2. **Client** → Sends request to Backend API
3. **Backend** → Updates Appwrite database (source of truth)
4. **Backend** → Updates LiveKit permissions
5. **Backend** → Broadcasts role change event
6. **All Clients** → Receive event and update UI

### Key Principles

1. **Backend Authority**: Database is the single source of truth
2. **Event-Driven**: All updates via real-time events
3. **Idempotent**: Duplicate events are safely ignored
4. **Resilient**: Heartbeat monitoring and presence tracking
5. **Auditable**: All role changes are logged

## Migration Checklist

- [ ] Update Appwrite schema with new fields
- [ ] Deploy backend API server (or use direct Appwrite)
- [ ] Initialize ClientRoleManager in app
- [ ] Replace all local role mutations
- [ ] Update UI to use streams instead of local state
- [ ] Add role request/cancel buttons
- [ ] Test multi-device scenarios
- [ ] Monitor with admin dashboard
- [ ] Enable debug logging
- [ ] Run full test suite

## Rollback Plan

If issues arise, you can rollback by:

1. **Keep old role management code commented out**
2. **Use feature flags to toggle between systems**
3. **Database changes are additive (won't break existing)**
4. **Backend API is optional (can use direct Appwrite)**

```dart
// Feature flag approach
if (useNewRoleSystem) {
  await clientRoleManager.promoteToSpeaker(userId);
} else {
  // Fall back to old system
  setState(() { participant.role = 'speaker'; });
}
```

## Performance Considerations

- **Database Queries**: New indexes optimize role-based queries
- **Real-time Updates**: Events only sent to room participants
- **Heartbeat Frequency**: 30-second intervals (configurable)
- **Event Deduplication**: Prevents processing same event twice
- **Roster Sync**: 2-minute fallback sync for missed events

## Security Considerations

- **Permission Validation**: Backend validates moderator permissions
- **Authentication**: All API calls require valid JWT tokens
- **Rate Limiting**: Prevent spam role change requests
- **Audit Trail**: All role changes logged with user and timestamp

## Support and Troubleshooting

### Common Issues

1. **"Role changes not syncing"**
   - Check backend API connectivity
   - Verify Appwrite realtime subscriptions
   - Check admin dashboard for events

2. **"Multiple users showing as speaker"**
   - Ensure using new role system exclusively
   - Check for remaining local role mutations
   - Verify database constraints

3. **"Roles reverting after app restart"**
   - Confirm authoritative roster fetch on join
   - Check database persistence
   - Verify role field updates

### Debug Tools

- **Admin Dashboard**: Real-time system monitoring
- **Role Authority Demo Widget**: Test all role operations
- **Appwrite Console**: Direct database inspection
- **LiveKit Dashboard**: Permission verification

This system completely eliminates the state sync inconsistencies you were experiencing. All clients will always see the same role state because there's only one source of truth - the backend database.