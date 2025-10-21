# Arena Challenge Navigation System Setup

This document describes the backend-driven navigation system for instant challenges.

## Overview

The system uses a hybrid approach:
1. **Backend (n8n)**: Watches for accepted challenges and creates navigation notifications
2. **Client (Flutter)**: Subscribes to notifications and navigates both users to the arena
3. **Reliability**: Persistent notifications ensure delivery even if user is offline

## Architecture

```
Challenge Accepted
       ↓
Appwrite Webhook
       ↓
n8n Workflow
       ↓
Creates 2 Navigation Notifications
(one for challenger, one for challenged)
       ↓
Flutter Clients Subscribe
       ↓
Both Users Navigate to Arena
```

## Setup Instructions

### 1. Collection Setup ✅ DONE

The `arena_navigation_notifications` collection has been created with:
- **userId**: Who should navigate
- **type**: Notification type (`arena_ready`)
- **arenaRoomId**: Target arena room ID
- **challengeId**: Related challenge ID
- **status**: `pending`, `processed`, or `expired`
- **topic**: Challenge topic
- **description**: Challenge description
- **processedAt**: When the notification was processed

### 2. n8n Workflow Setup

1. **Import the workflow**:
   - Open n8n instance
   - Import `n8n-arena-challenge-navigation.json`

2. **Configure Appwrite credentials**:
   - Add Appwrite API credentials in n8n
   - Endpoint: `https://cloud.appwrite.io/v1`
   - Project ID: `683a37a8003719978879`
   - API Key: Your Appwrite API key

3. **Activate the workflow**:
   - Open the workflow in n8n
   - Click "Active" toggle

4. **Get the webhook URL**:
   - Open the "Webhook - Challenge Update" node
   - Copy the production webhook URL
   - It will look like: `https://your-n8n-instance.com/webhook/arena-challenge-accepted`

### 3. Appwrite Webhook Setup

Create an Appwrite webhook that triggers when challenges are accepted:

```bash
# Option 1: Using Appwrite Console
# 1. Go to Appwrite Console
# 2. Navigate to your project
# 3. Go to "Webhooks"
# 4. Click "Add Webhook"
# 5. Configure:
#    - Name: "Arena Challenge Navigation"
#    - Events: Database → challenge_messages → Update
#    - URL: [Your n8n webhook URL]
#    - Headers: (optional)

# Option 2: Using create_arena_webhook.sh script
./create_arena_webhook.sh [YOUR_N8N_WEBHOOK_URL]
```

### 4. Flutter Client Setup ✅ DONE

The Flutter client has been updated in `lib/main.dart`:
- Added `_setupArenaNavigationListener()` method
- Subscribes to `arena_navigation_notifications` collection
- Processes `arena_ready` notifications
- Marks notifications as `processed` after handling
- Keeps old `challengeUpdates` listener as fallback

## Testing

### Test the Complete Flow:

1. **Send a Challenge**:
   - User A sends challenge to User B
   - Challenge document created with status `pending`

2. **Accept the Challenge**:
   - User B accepts the challenge
   - Arena room is created
   - Challenge document updated with status `accepted` and `arenaRoomId`

3. **Webhook Triggers**:
   - Appwrite webhook fires on challenge update
   - n8n workflow receives the payload

4. **Notifications Created**:
   - n8n creates 2 navigation notification documents:
     - One for User A (challenger)
     - One for User B (challenged)
   - Both with status `pending`

5. **Navigation Happens**:
   - Both users' Flutter clients receive the realtime notification
   - Both clients navigate to the arena
   - Notifications marked as `processed`

6. **Verify in Logs**:
```
User A logs:
🎯 ✅ Navigation notification received: type=arena_ready, arenaRoomId=...
🚀 CHALLENGE: Preparing to navigate to Arena room: ...

User B logs:
🎯 ✅ Navigation notification received: type=arena_ready, arenaRoomId=...
🚀 CHALLENGE: Preparing to navigate to Arena room: ...
```

## Debugging

### Check n8n Workflow Executions:
- Open n8n
- Go to "Executions"
- Look for workflow runs
- Check for errors

### Check Notifications in Appwrite:
```bash
# Query navigation notifications
appwrite databases list-documents \
  --database-id arena_db \
  --collection-id arena_navigation_notifications
```

### Check Flutter Logs:
Look for these log patterns:
- `🎯 Setting up arena navigation listener`
- `🎯 Navigation notification event:`
- `🎯 ✅ Navigation notification received`
- `🎯 ✅ Notification marked as processed`

## Troubleshooting

### Issue: No notifications created
**Check**:
1. Is the webhook configured correctly?
2. Is the n8n workflow active?
3. Check n8n execution logs

### Issue: Notifications created but navigation doesn't happen
**Check**:
1. Is the Flutter client subscribed? (Look for setup log)
2. Is the userId matching?
3. Is the notification status `pending`?

### Issue: Navigation happens but delayed
**Possible causes**:
1. Realtime subscription delay
2. Network latency
3. App in background (suspended)

### Issue: Duplicate navigations
**Possible causes**:
1. Both backend notification AND fallback triggered
2. Check if filtering is correct in Flutter listener

## Cleanup Script

To clean up old processed notifications:

```dart
// Run periodically (e.g., daily)
final oldNotifications = await databases.listDocuments(
  databaseId: 'arena_db',
  collectionId: 'arena_navigation_notifications',
  queries: [
    Query.equal('status', 'processed'),
    Query.lessThan('\$createdAt', DateTime.now().subtract(Duration(days: 7)).toIso8601String()),
  ],
);

for (final doc in oldNotifications.documents) {
  await databases.deleteDocument(
    databaseId: 'arena_db',
    collectionId: 'arena_navigation_notifications',
    documentId: doc.$id,
  );
}
```

## Future Enhancements

- [ ] Add push notifications for offline users
- [ ] Add retry mechanism for failed navigations
- [ ] Add analytics for navigation success rate
- [ ] Support batch notifications (tournaments, etc.)
- [ ] Add expiration handling (auto-expire old notifications)

## Files Created/Modified

### Created:
- `/scripts/create_navigation_notifications_collection.dart`
- `/n8n-arena-challenge-navigation.json`
- `/ARENA_NAVIGATION_SETUP.md` (this file)

### Modified:
- `/lib/main.dart` (added navigation listener)
- `/lib/services/challenge_messaging_service.dart` (added logging)

## Related Documentation

- [Challenge System](./CLAUDE.md#instant-messaging-system)
- [n8n Workflows](./n8n-workflows/)
- [Appwrite Collections](./appwrite.json)
