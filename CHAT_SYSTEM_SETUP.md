# Chat System Setup Guide

## Overview

This guide outlines the setup required for the new Mattermost-inspired chat system that supports both room chat and direct messages in the Open Discussion feature.

## Appwrite Collections Required

### 1. `discussion_chat_messages` Collection

**Purpose**: Store room-based chat messages for Open Discussion rooms

**Attributes**:
```json
{
  "roomId": {
    "type": "string",
    "required": true,
    "array": false,
    "size": 255
  },
  "senderId": {
    "type": "string", 
    "required": true,
    "array": false,
    "size": 255
  },
  "senderName": {
    "type": "string",
    "required": true, 
    "array": false,
    "size": 255
  },
  "content": {
    "type": "string",
    "required": true,
    "array": false,
    "size": 10000
  },
  "timestamp": {
    "type": "datetime",
    "required": true,
    "array": false
  },
  "type": {
    "type": "enum",
    "required": true,
    "array": false,
    "elements": ["text", "image", "video", "voice", "file", "system", "announcement"]
  },
  "senderAvatar": {
    "type": "string",
    "required": false,
    "array": false,
    "size": 2048
  },
  "replyToId": {
    "type": "string",
    "required": false,
    "array": false,
    "size": 255
  },
  "replyToContent": {
    "type": "string",
    "required": false,
    "array": false,
    "size": 1000
  },
  "replyToSender": {
    "type": "string",
    "required": false,
    "array": false,
    "size": 255
  },
  "reactions": {
    "type": "string",
    "required": false,
    "array": false,
    "size": 2048,
    "default": "{}"
  },
  "mentions": {
    "type": "string",
    "required": false,
    "array": true,
    "size": 255
  },
  "attachments": {
    "type": "string",
    "required": false,
    "array": true,
    "size": 2048
  },
  "isEdited": {
    "type": "boolean",
    "required": false,
    "array": false,
    "default": false
  },
  "isDeleted": {
    "type": "boolean",
    "required": false,
    "array": false,
    "default": false
  },
  "editedAt": {
    "type": "datetime",
    "required": false,
    "array": false
  },
  "deletedAt": {
    "type": "datetime",
    "required": false,
    "array": false
  }
}
```

**Indexes**:
- `roomId` + `timestamp` (for chronological room messages)
- `senderId` (for user's message history)
- `replyToId` (for threaded conversations)

**Permissions**:
- Create: Users (authenticated users can send messages)
- Read: Users (all authenticated users can read)
- Update: Users (users can edit/delete their own messages)
- Delete: Users (moderators can delete any message)

### 2. `instant_messages` Collection (EXISTING - Enhanced)

**Purpose**: Store private direct messages between users

**Additional Attributes** (if not already present):
```json
{
  "conversationId": {
    "type": "string",
    "required": true,
    "array": false,
    "size": 255
  },
  "metadata": {
    "type": "string",
    "required": false,
    "array": false,
    "size": 2048,
    "default": "{}"
  }
}
```

**Enhanced Indexes**:
- `conversationId` + `timestamp` (for chronological conversation messages)
- `senderId` + `receiverId` (for bilateral conversations)

## Integration Points

### 1. Existing Services Integration

The chat system integrates with:
- **ChallengeMessagingService**: For challenge notifications and existing IM functionality
- **AppwriteService**: For database operations and user profile management
- **Open Discussion Room**: Seamless integration with room participants and roles

### 2. Real-time Features

Uses Appwrite Realtime subscriptions for:
- New message notifications
- Message updates (edits/deletions)
- Typing indicators (future enhancement)
- User presence (future enhancement)

### 3. Role-based Features

- **Moderators**: Can delete any message, send announcements
- **Speakers**: Full chat access with mic controls
- **Audience**: Chat access, can request to become speaker

## UI Components

### 1. MattermostChatWidget

**Features**:
- Tab-based interface (Room Chat / Direct Messages)
- Message threading and replies
- User mentions with @username
- Message reactions (future)
- File attachments (future)
- Role-based permissions

### 2. Integration with Open Discussion

- Activated via Chat button in control panel
- Modal bottom sheet presentation
- Maintains existing UI design consistency
- Seamless switching between room and DM modes

## Setup Instructions

### 1. Create Appwrite Collections

1. Navigate to Appwrite Console → Databases
2. Create `discussion_chat_messages` collection with attributes above
3. Configure indexes and permissions as specified
4. Enhance `instant_messages` collection if needed

### 2. Deploy Code

The chat system is already integrated into:
- `/lib/models/discussion_chat_message.dart` - Data models
- `/lib/services/unified_chat_service.dart` - Business logic
- `/lib/widgets/mattermost_chat_widget.dart` - UI implementation
- `/lib/screens/open_discussion_room_screen.dart` - Integration point

### 3. Test Functionality

1. Open any Open Discussion room
2. Tap the "Chat" button in control panel
3. Test room chat functionality
4. Switch to "Direct" tab and test private messages
5. Verify real-time updates across multiple devices

## Future Enhancements

### Phase 2 Features
- File sharing and attachments
- Message reactions with emoji picker
- Advanced threading
- Message search functionality
- User presence indicators
- Typing indicators

### Phase 3 Features  
- Voice messages
- Screen sharing integration
- Message formatting (markdown)
- Custom emoji/reactions
- Chat moderation tools
- Message encryption

## Security Considerations

- All messages stored in Appwrite with proper permissions
- Role-based access control for message operations
- Input sanitization for mentions and content
- Soft deletion for message history preservation
- Audit trail for moderation actions

## Performance Optimizations

- Message pagination (100 messages per load)
- User profile caching
- Efficient real-time subscription management
- Lazy loading for attachments
- Message deduplication
- Optimistic UI updates

## Monitoring and Analytics

Consider tracking:
- Message volume per room
- User engagement metrics
- Feature usage (DMs vs room chat)
- Performance metrics (load times, real-time latency)
- Error rates and user feedback