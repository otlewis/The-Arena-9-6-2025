# Speaker Promotion Race Condition Fix

## Problem
When promoting users to speaking roles (speaker, debater, judge), there was a race condition:
1. Appwrite role was updated first
2. User tried to enable microphone
3. LiveKit permissions weren't ready yet ❌
4. User couldn't speak

## Solution
Use n8n webhooks to coordinate LiveKit → Appwrite updates in the correct order.

## Files Created

### 1. `n8n-promote-speaker.json`
N8N workflow for **Debates & Discussions** speaker promotions.

**Webhook URL:** `http://50.21.187.76/webhook/promote-speaker`

**Flow:**
1. Receives webhook from Flutter (roomId, userId, participantDocId)
2. Updates LiveKit permissions FIRST (canPublish: true)
3. Waits 2 seconds for permissions to propagate
4. Updates Appwrite `debate_discussion_participants` collection
5. Returns success confirmation

### 2. `n8n-assign-arena-role.json`
N8N workflow for **Arena** role assignments.

**Webhook URL:** `http://50.21.187.76/webhook/assign-arena-role`

**Flow:**
1. Receives webhook from Flutter (roomId, userId, role)
2. Updates LiveKit permissions FIRST (canPublish: true)
3. Waits 2 seconds for permissions to propagate
4. Creates participant in Appwrite `arena_participants` collection
5. Returns success confirmation with participantId

## Code Changes

### Debates & Discussions (`lib/screens/debates_discussions_screen.dart`)

**Added:**
- `_participantDocIds` map to track document IDs (line 204)
- `_promoteToSpeakerViaWebhook()` method (lines 3542-3580)

**Modified:**
- `_loadParticipants()` - stores document IDs (lines 2075-2077)
- `_assignUserToRole()` - uses webhook for speaker roles (lines 3693-3731)

**Flow:**
1. Moderator approves speaker request
2. Optimistic UI update (speaker appears immediately)
3. **n8n webhook** updates LiveKit → Appwrite
4. Reload participants to sync UI
5. ✅ User can speak immediately

**Fallback:**
If webhook fails, falls back to direct Appwrite update with warning message.

### Arena (`lib/screens/arena_screen.dart`)

**Added:**
- `_assignRoleViaWebhook()` method (lines 6976-7007)

**Modified:**
- `_assignRole()` - uses webhook for speaking roles (lines 7062-7095)

**Speaking roles that use webhook:**
- `affirmative` - debater arguing FOR
- `negative` - debater arguing AGAINST
- `moderator` - debate moderator
- `judge1`, `judge2`, `judge3` - judges (need audio for questions/feedback)

**Non-speaking role (direct update):**
- `audience` - listen-only

**Fallback:**
If webhook fails, falls back to direct Appwrite update with warning message.

## Setup Instructions

### 1. Import n8n Workflows
```bash
# In n8n UI:
1. Go to http://50.21.187.76:5678
2. Click "Add workflow" → "Import from File"
3. Import n8n-promote-speaker.json
4. Import n8n-assign-arena-role.json
5. **Activate both workflows** (toggle in top-right must be GREEN)
```

### 2. Verify Webhook URLs
After activation, verify the production URLs match:
- Debates: `http://50.21.187.76/webhook/promote-speaker`
- Arena: `http://50.21.187.76/webhook/assign-arena-role`

### 3. Test the Flow

**Debates & Discussions:**
1. Create a Debates room as moderator
2. Join as another user (audience)
3. Raise hand
4. Moderator approves
5. ✅ User should appear in speaker panel and be able to speak immediately

**Arena:**
1. Create an Arena room as moderator
2. Assign someone from audience to judge/debater role
3. ✅ They should be able to speak immediately

## Monitoring

### Success Logs
```
🔗 WEBHOOK: Calling n8n to promote/assign...
✅ WEBHOOK: Successfully promoted/assigned...
```

### Fallback Logs (n8n offline)
```
⚠️ PROMOTION/ARENA: Webhook failed, falling back...
⚠️ PROMOTION/ARENA: Race condition may occur...
```

### User Messages
- **Success:** "✅ [User] assigned to [Role]"
- **Fallback:** "⚠️ [User] promoted (n8n offline - audio may have delay)"

## Benefits

✅ **No more race conditions** - LiveKit permissions granted BEFORE role update
✅ **Users can speak immediately** after being promoted
✅ **Graceful degradation** - Falls back to direct update if n8n is offline
✅ **Works for both systems** - Debates & Discussions + Arena
✅ **Server-side coordination** - Reliable sequencing of updates

## Technical Details

### LiveKit Permission Update
```json
{
  "room": "roomId",
  "identity": "userId",
  "permission": {
    "canPublish": true,
    "canSubscribe": true,
    "canPublishData": true
  }
}
```

### LiveKit API
- **Endpoint:** `http://34.171.185.205:7879/twirp/livekit.RoomService/UpdateParticipant`
- **Auth:** JWT token (generated in n8n with API key + secret)
- **Algorithm:** HS256
- **Expiry:** 1 hour

### Collections Updated
- **Debates:** `debate_discussion_participants`
- **Arena:** `arena_participants`

## Troubleshooting

### Webhook returns 404
**Cause:** n8n workflow not active
**Fix:** Activate the workflow in n8n (toggle must be GREEN)

### User still can't speak
**Possible causes:**
1. n8n workflow not running
2. LiveKit server down
3. Network issues

**Check:**
```bash
# Test n8n webhook
curl -X POST http://50.21.187.76/webhook/promote-speaker \
  -H "Content-Type: application/json" \
  -d '{"roomId":"test","userId":"test","participantDocId":"test"}'

# Should return success response (or error if workflow not active)
```

### Fallback warning appears
**Cause:** n8n webhook failed (offline or error)
**Effect:** User promoted but may experience audio delay
**Action:** Check n8n server status and workflow activation

## Future Improvements

- [ ] Add retry logic in n8n workflows
- [ ] Monitor webhook success rate
- [ ] Add webhook response caching
- [ ] Implement webhook health check endpoint
