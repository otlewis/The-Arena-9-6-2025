# Follower Invitation Feature

## Overview
The Follower Invitation system allows users to ping their followers to join them in active debate/discussion rooms. This increases engagement and helps users build their audience.

## Features Implemented

### 1. FollowerInvitationService (`lib/services/follower_invitation_service.dart`)
**Purpose**: Manages the sending and tracking of room invitations

**Key Features**:
- Send invitations to selected followers
- Broadcast to all followers at once
- Rate limiting (5-minute cooldown per user/room combination)
- Track invitation status (pending, accepted, declined, expired)
- Auto-expire invitations after 1 hour
- Clean up expired invitations

**Key Methods**:
- `inviteFollowersToRoom()` - Send invitations to specific followers
- `broadcastToAllFollowers()` - One-tap invite all followers
- `acceptInvitation()` / `declineInvitation()` - Handle invitation responses
- `getPendingInvitations()` - Get user's pending invitations
- `cleanupExpiredInvitations()` - Remove expired invitations

### 2. InviteFollowersBottomSheet (`lib/widgets/invite_followers_bottom_sheet.dart`)
**Purpose**: Beautiful UI for selecting and inviting followers

**Key Features**:
- List of all followers with avatars
- Individual selection with checkboxes
- "Select All" / "Deselect All" toggle
- "Broadcast" button for one-tap invite all
- Selection counter
- Loading, error, and empty states
- Beautiful purple-themed design matching app style

**UI Components**:
- Header with room name
- Action buttons (Select All, Broadcast)
- Scrollable follower list
- Send button with loading state

### 3. Integration in Debates & Discussions Screen
**Location**: `lib/screens/debates_discussions_screen.dart`

**Added**:
- "Invite Followers" button in moderator menu
- Located between "Speaker Queue" and "End Room" options
- Opens bottom sheet when clicked
- Async loading of current user

### 4. Database Collection Setup
**Script**: `setup_room_invitations_collection.sh`

**Collection**: `room_invitations`

**Attributes**:
- `roomId` - ID of the room being invited to
- `roomName` - Name of the room
- `roomType` - Type of room (Discussion, Debate, Take)
- `inviterId` - User ID of inviter
- `inviterName` - Name of inviter
- `inviteeId` - User ID of person being invited
- `status` - Status (pending, accepted, declined, expired)
- `createdAt` - Timestamp of invitation
- `expiresAt` - Expiration timestamp (1 hour from creation)

**Indexes**:
- `inviteeId_status_idx` - Find invitations by invitee
- `roomId_status_idx` - Find invitations by room
- `createdAt_idx` - Sort by creation date
- `expiresAt_status_idx` - Find expired invitations

## User Flow

### Inviting Followers
1. User (moderator) opens room options menu
2. Clicks "Invite Followers"
3. Bottom sheet opens with follower list
4. User can:
   - Select individual followers (checkbox)
   - Select all followers (button)
   - Broadcast to all (button)
5. Click "Send Invitations"
6. Service creates invitation records in database
7. Success message shows count sent

### Receiving Invitations
*Future Implementation:*
- Users receive in-app notifications
- Notification shows room name and inviter
- Tap to join room directly
- Option to accept/decline invitation

## Rate Limiting

### Purpose
Prevent spam and abuse

### Implementation
- 5-minute cooldown per user/room combination
- Tracked in memory (FollowerInvitationService)
- Shows count of rate-limited followers in result

### Example
- User A invites User B to Room 1 at 2:00 PM
- User A cannot invite User B to Room 1 again until 2:05 PM
- User A can still invite User B to Room 2 immediately
- User A can still invite User C to Room 1 immediately

## Expiration System

### Auto-Expiration
- All invitations expire 1 hour after creation
- `expiresAt` timestamp set during creation
- `cleanupExpiredInvitations()` marks them as expired

### Why 1 Hour?
- Rooms are typically time-limited
- Prevents stale invitations
- Encourages timely responses
- Keeps database clean

## Future Enhancements

### 1. Notification System
- Push notifications for invitations
- In-app notification bell with badge
- Deep linking to join room from notification

### 2. Auto-Prompt When Going Live
- Prompt moderator when they first join as moderator
- "Want to invite your followers?" dialog
- Remember user preference (opt-in/opt-out setting)

### 3. Invitation History
- See who you've invited to past rooms
- Track invitation acceptance rates
- Analytics on follower engagement

### 4. Smart Invitations
- Show online followers first
- Suggest followers based on room topic
- Recommend users who might be interested

### 5. Response Tracking
- See who accepted/declined
- Follow-up with users who declined
- Thank users who joined

## Database Setup

To activate this feature, run:

```bash
./setup_room_invitations_collection.sh
```

This will create the `room_invitations` collection in your Appwrite database with all necessary attributes and indexes.

## Testing

### Manual Testing Steps

1. **Create a room as moderator**
2. **Open moderator menu** (three dots)
3. **Click "Invite Followers"**
4. **Verify**:
   - Bottom sheet opens
   - Followers list loads
   - Can select/deselect followers
   - "Select All" works
   - "Broadcast" button works
   - "Send Invitations" works
5. **Check rate limiting**:
   - Send invitation to same follower
   - Wait 5 minutes
   - Try again - should work

### Expected Behavior

- ✅ Moderators can see "Invite Followers" option
- ✅ Non-moderators don't see the option
- ✅ Bottom sheet shows all followers
- ✅ Can select multiple followers
- ✅ Broadcast sends to all followers
- ✅ Rate limiting prevents spam
- ✅ Success message shows count sent
- ✅ Error handling for network issues

## Code Files Modified

1. `lib/services/follower_invitation_service.dart` (NEW)
2. `lib/widgets/invite_followers_bottom_sheet.dart` (NEW)
3. `lib/screens/debates_discussions_screen.dart` (MODIFIED)
   - Added import for InviteFollowersBottomSheet
   - Added "Invite Followers" menu option
   - Added `_showInviteFollowers()` method
4. `setup_room_invitations_collection.sh` (NEW)

## Dependencies

All required dependencies are already in the project:
- `appwrite` - Database operations
- `flutter` - UI framework
- Material Design widgets

No new packages needed!

## Summary

This feature enables users to:
- ✅ Invite specific followers to rooms
- ✅ Broadcast to all followers
- ✅ Rate-limited to prevent spam
- ✅ Auto-expiring invitations
- ✅ Beautiful, intuitive UI
- ✅ Integrated into moderator menu

Ready for testing after running the database setup script!
