# Assign Arena Role Function

**Single Source of Truth for Arena Role Assignments**

This Appwrite Function ensures atomic, synchronized role assignments across:
- Appwrite database (with versioning)
- LiveKit media permissions
- All connected clients

## Purpose

Prevents desynchronization issues where different devices show different user roles by:
1. Centralizing all role changes through one function
2. Adding version numbers to prevent out-of-order updates
3. Atomically updating database + LiveKit permissions
4. Broadcasting events to trigger client reconciliation

## Request Format

```json
{
  "roomId": "room_123",
  "userId": "user_456",
  "role": "judge1",
  "requesterId": "user_789"
}
```

### Parameters

- `roomId` (required): The arena room ID
- `userId` (required): ID of user whose role is being changed
- `role` (required): One of: `affirmative`, `negative`, `judge1`, `judge2`, `judge3`, `moderator`, `audience`
- `requesterId` (required): ID of user making the request (must be moderator or super mod)

## Response Format

### Success (200)
```json
{
  "success": true,
  "assignedRole": "judge1",
  "version": 42,
  "timestamp": "2025-01-19T10:30:00.000Z",
  "livekitUpdated": true,
  "previousRole": "audience"
}
```

### Error (400/403/500)
```json
{
  "success": false,
  "error": "Permission denied",
  "code": "UNAUTHORIZED"
}
```

## Environment Variables

Required in Appwrite Function settings:

- `APPWRITE_API_KEY`: API key with database permissions
- `LIVEKIT_HOST`: LiveKit server URL (e.g., `https://your-livekit-server.livekit.cloud`)
- `LIVEKIT_API_KEY`: LiveKit API key
- `LIVEKIT_API_SECRET`: LiveKit API secret

## Logic Flow

1. **Validate Request**: Check required fields and role validity
2. **Check Permissions**: Verify requester is moderator or super moderator
3. **Fetch Existing Participants**: Get current room state
4. **Resolve Conflicts**: Handle unique roles (moderator) and auto-assign judge slots
5. **Clean Up**: Delete user's old participant entries
6. **Increment Version**: Calculate next version number for room
7. **Create DB Entry**: Write new participant with version
8. **Update LiveKit**: Set media permissions based on role
9. **Mark Synced**: Update `livekitSynced` field
10. **Broadcast Event**: Notify all clients via `arena_events` collection
11. **Return Result**: Send success response with version info

## Role Permissions (LiveKit)

| Role | Can Publish Audio | Can Publish Video | Can Subscribe |
|------|-------------------|-------------------|---------------|
| affirmative | ✅ | ✅ | ✅ |
| negative | ✅ | ✅ | ✅ |
| judge1/2/3 | ✅ | ✅ | ✅ |
| moderator | ✅ | ✅ | ✅ |
| audience | ❌ | ❌ | ✅ |

## Conflict Resolution

- **Moderator**: If slot taken, assigns as `audience`
- **Judge**: If requesting `judge` (generic), assigns to first available slot (judge1/2/3)
- **Specific Judge Slot**: If requesting `judge2` specifically, assigns exactly that (may cause conflicts if taken)

## Deployment

```bash
# Install dependencies
cd appwrite-functions/assign-arena-role
npm install

# Deploy to Appwrite
appwrite deploy function

# Or use the provided script
./deploy-assign-arena-role.sh
```

## Testing

```bash
# Test with curl
curl -X POST https://cloud.appwrite.io/v1/functions/[FUNCTION_ID]/executions \
  -H "Content-Type: application/json" \
  -H "X-Appwrite-Project: [PROJECT_ID]" \
  -H "X-Appwrite-Key: [API_KEY]" \
  -d '{
    "roomId": "test_room",
    "userId": "test_user",
    "role": "judge1",
    "requesterId": "moderator_user"
  }'
```

## Error Codes

| Code | HTTP | Description |
|------|------|-------------|
| `INVALID_REQUEST` | 400 | Missing required fields |
| `INVALID_ROLE` | 400 | Role not in allowed list |
| `UNAUTHORIZED` | 403 | Requester not authorized |
| `INTERNAL_ERROR` | 500 | Server error |

## Monitoring

Check Appwrite Function logs for:
- `📋 Role assignment request` - Function invocation
- `🔐 Checking permissions` - Auth check
- `✅ Created participant document` - DB write success
- `✅ LiveKit permissions synced` - Media sync success
- `🎉 Role assignment complete` - Full success

## Integration

### Client-side (Flutter)

```dart
final result = await appwrite.functions.createExecution(
  functionId: 'assign-arena-role',
  body: jsonEncode({
    'roomId': roomId,
    'userId': targetUserId,
    'role': 'judge1',
    'requesterId': currentUserId,
  }),
);

final response = jsonDecode(result.responseBody);
if (response['success']) {
  final newVersion = response['version'];
  final assignedRole = response['assignedRole'];
  // Trigger snapshot refresh
  await refreshParticipants();
}
```

## Version History

- **v1.0.0** (2025-01-19): Initial implementation with atomic DB + LiveKit updates
