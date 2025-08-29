# Super Moderator Appwrite Collections Setup

This document outlines the Appwrite collections that need to be created manually in the Appwrite Console to support the Super Moderator system.

## Required Collections

### 1. `super_moderators` Collection

**Purpose**: Store Super Moderator user data and permissions

**Attributes**:
- `userId` (String, required) - User ID of the Super Moderator
- `username` (String, required) - Username for display
- `profileImageUrl` (String, optional) - Profile image URL
- `grantedAt` (DateTime, required) - When Super Mod status was granted
- `grantedBy` (String, optional) - User ID of who granted the status
- `isActive` (Boolean, required, default: true) - Whether status is active
- `permissions` (String Array, required) - List of permissions
- `metadata` (String, optional) - JSON metadata

**Indexes**:
- `userId` (unique)
- `isActive`
- `grantedAt`

### 2. `room_bans` Collection

**Purpose**: Track banned users from rooms

**Attributes**:
- `userId` (String, required) - Banned user ID
- `roomId` (String, required) - Room ID where banned
- `roomType` (String, required) - Type of room (debate, discussion, etc.)
- `bannedBy` (String, required) - Super Moderator who issued the ban
- `reason` (String, optional) - Reason for ban
- `bannedAt` (DateTime, required) - When ban was issued
- `expiresAt` (DateTime, optional) - When ban expires (null = permanent)
- `isActive` (Boolean, required, default: true) - Whether ban is active

**Indexes**:
- `userId + roomId` (unique)
- `bannedBy`
- `isActive`
- `expiresAt`

### 3. `room_events` Collection

**Purpose**: Store room-level events (kicks, mic locks, etc.)

**Attributes**:
- `type` (String, required) - Event type (user_kicked, mic_lock_status, etc.)
- `userId` (String, optional) - Target user ID (for kicks)
- `roomId` (String, required) - Room ID
- `moderatorId` (String, required) - Super Moderator who triggered event
- `reason` (String, optional) - Reason for action
- `locked` (Boolean, optional) - For mic lock events
- `exemptUsers` (String Array, optional) - Users exempt from action
- `timestamp` (DateTime, required) - When event occurred
- `metadata` (String, optional) - Additional event data

**Indexes**:
- `roomId + timestamp`
- `moderatorId`
- `type`

### 4. `moderation_actions` Collection

**Purpose**: Audit log of all moderation actions

**Attributes**:
- `moderatorId` (String, required) - Super Moderator ID
- `targetUserId` (String, optional) - Target user ID
- `roomId` (String, optional) - Room ID if room-specific
- `action` (String, required) - Action type (ban, kick, warn, etc.)
- `reason` (String, optional) - Reason for action
- `duration` (Integer, optional) - Duration in minutes for timed actions
- `reportId` (String, optional) - Related report ID
- `automated` (Boolean, required, default: false) - Whether action was automated
- `aiScore` (String, optional) - AI confidence scores (JSON)
- `createdAt` (DateTime, required) - When action was taken
- `metadata` (String, optional) - Additional action data

**Indexes**:
- `moderatorId + createdAt`
- `targetUserId`
- `action`
- `reportId`

## Collection Permissions

For all collections, set the following permissions:

**Create**: 
- Any authenticated user (for self-reporting)
- Server (for system actions)

**Read**: 
- Any authenticated user (for transparency)
- Server

**Update**: 
- Only users with Super Moderator role
- Server

**Delete**: 
- Only users with Super Moderator role
- Server

## Setup Instructions

1. Log into your Appwrite Console
2. Navigate to your `arena_db` database
3. Create each collection with the specified attributes
4. Set up the indexes for optimal query performance
5. Configure permissions as specified above
6. Test the collections with the Super Moderator functionality

## Verification

After creating the collections, you can verify they work by:

1. Running the app with the new Super Moderator system
2. Using the script `lib/scripts/grant_kritik_supermod.dart`
3. Testing the Super Moderator dashboard
4. Checking that reports and actions are properly logged

## Notes

- The `permissions` field in `super_moderators` stores an array of permission strings
- The `metadata` fields allow for future extensibility
- All timestamps should be stored in ISO 8601 format
- The `aiScore` field can store JSON data from content moderation APIs