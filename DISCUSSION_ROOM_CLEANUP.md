# Discussion Room Cleanup System

This document explains the automated cleanup system for unused discussion rooms in the Arena app.

## Overview

The discussion room cleanup system automatically removes inactive and unused discussion rooms to keep the platform clean and improve performance. This prevents the accumulation of abandoned rooms that clutter the interface.

## Cleanup Criteria

### Regular Cleanup (`cleanupUnusedDiscussionRooms`)

Rooms are automatically cleaned up when they meet any of these criteria:

1. **Age-based cleanup**:
   - Rooms older than **24 hours** (regardless of participant count)
   - Rooms older than **4 hours** with **no active participants**

2. **Inactivity-based cleanup**:
   - Rooms that have been **empty for 30+ minutes**
   - Rooms with **only 1 participant** (likely the creator) for **2+ hours**

### Force Cleanup (`forceCleanupAllOldDiscussionRooms`)

More aggressive cleanup that removes:
- Any discussion room older than **2 hours**, regardless of status or participants

## How Cleanup Works

### 1. Participant Management
- All participants are marked as `left` with a `leftAt` timestamp
- No data is deleted - historical records are preserved

### 2. Room Status Update
- Room status is changed from `active` to `ended` (regular cleanup)
- Room status is changed to `force_cleaned` (force cleanup)
- An `endedAt` timestamp is added

### 3. UI Filtering
- The `getRooms()` method only returns rooms with `status: 'active'`
- Cleaned rooms automatically disappear from the room list

## Automatic Triggers

### 1. App Initialization
```dart
// In NotificationService.initialize()
await _appwrite.cleanupUnusedDiscussionRooms();
```

### 2. Manual Triggers
Users can manually trigger cleanup from the Profile screen:
- **"Cleanup Discussions"** - Regular cleanup
- **"Force Cleanup"** - Aggressive cleanup (orange button)

### 3. Standalone Script
```bash
dart cleanup_discussion_rooms.dart
```

## Real-time Handling

### Room Status Monitoring
The `OpenDiscussionRoomScreen` listens for real-time room status changes:

```dart
// Real-time subscription handles:
- Room status changes to 'ended', 'force_cleaned', or 'closed'
- Automatic navigation back to room list
- User notifications about room closure
```

### Fallback Checking
When real-time is unavailable:
- Periodic status checks every 30 seconds
- Same handling as real-time updates

## User Experience

### When a Room is Cleaned Up

1. **For users in the room**:
   - Real-time notification: "🧹 This discussion room was cleaned up due to inactivity"
   - Automatic navigation back to the room list
   - No data loss - conversation history preserved

2. **For users browsing rooms**:
   - Room disappears from the active room list
   - No visible indication of cleanup

### Messages Shown

- **Force cleaned**: "🧹 This discussion room was cleaned up due to inactivity"
- **Manually closed**: "🔒 This discussion room has been closed"
- **Room deleted**: "🧹 This discussion room has been removed"

## Technical Implementation

### Database Structure

```javascript
// Rooms collection
{
  id: "room_id",
  type: "discussion",
  status: "ended", // or "force_cleaned"
  endedAt: "2024-01-01T00:00:00.000Z"
}

// Room participants collection
{
  roomId: "room_id",
  userId: "user_id",
  status: "left", // changed from "joined"
  leftAt: "2024-01-01T00:00:00.000Z"
}
```

### Service Methods

```dart
// AppwriteService methods
await cleanupUnusedDiscussionRooms();        // Regular cleanup
await forceCleanupAllOldDiscussionRooms();   // Force cleanup
```

## Benefits

1. **Performance**: Reduces database load by limiting active rooms
2. **User Experience**: Cleaner room lists without abandoned rooms  
3. **Resource Management**: Prevents indefinite accumulation of inactive rooms
4. **Maintenance**: Automatic cleanup reduces manual intervention needs

## Configuration

### Cleanup Timing (Configurable)
```dart
// Current settings in cleanupUnusedDiscussionRooms()
final maxAge = 24; // hours
final emptyTimeout = 30; // minutes
final soloTimeout = 2; // hours
final inactiveTimeout = 4; // hours
```

### Force Cleanup Timing
```dart
// Current setting in forceCleanupAllOldDiscussionRooms()
final forceCleanupAge = 2; // hours
```

## Monitoring

### Logs
The cleanup system provides detailed logging:

```
🧹 Starting cleanup of unused discussion rooms...
🔍 Room room_123: "Tech Discussion" (Age: 5h 23m)
   👥 Participants: 0
🧹 Cleaning up room: empty for 30+ minutes
✅ Room cleaned up successfully
🧹 Discussion room cleanup completed: 3 rooms, 5 participations
```

### Script Output
The standalone script provides a summary:

```
🎉 Cleanup completed!
📊 Total rooms processed: 15
🧹 Rooms cleaned up: 3
🏃 Active rooms remaining: 12
```

## Troubleshooting

### Common Issues

1. **Real-time not working**: Fallback timer handles status checks
2. **User stuck in cleaned room**: Multiple navigation attempts with delays
3. **Cleanup not running**: Check notification service initialization

### Force Recovery
If rooms get stuck, use the force cleanup methods:

```dart
// From profile screen or standalone script
await _appwrite.forceCleanupAllOldDiscussionRooms();
``` 