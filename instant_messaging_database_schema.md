# Instant Messaging Database Schema

This document describes the Appwrite database schema for the instant messaging system.

## Collection: instant_messages

Store private messages between users.

### Fields:
- **senderId** (string, required)
  - The ID of the user sending the message
  - Index: Yes
  
- **receiverId** (string, required)
  - The ID of the user receiving the message
  - Index: Yes
  
- **content** (string, required)
  - The message content
  - Max length: 1000
  
- **timestamp** (datetime, required)
  - When the message was sent
  - Index: Yes (for ordering)
  
- **isRead** (boolean, required)
  - Whether the message has been read by the recipient
  - Default: false
  - Index: Yes
  
- **senderUsername** (string, optional)
  - Cached username of sender for display
  
- **senderAvatar** (string, optional)
  - Cached avatar URL of sender
  
- **conversationId** (string, required)
  - Unique identifier for the conversation (hash of sorted user IDs)
  - Index: Yes
  
- **metadata** (object, optional)
  - Additional metadata (reactions, attachments, etc.)

### Indexes:
1. **conversationId_timestamp** (Composite)
   - Fields: conversationId (ASC), timestamp (DESC)
   - For efficient conversation message retrieval
   
2. **receiverId_isRead** (Composite)
   - Fields: receiverId (ASC), isRead (ASC)
   - For unread message counts
   
3. **senderId_timestamp** (Composite)
   - Fields: senderId (ASC), timestamp (DESC)
   - For sent message history

### Permissions:
- **Create**: Users (authenticated)
- **Read**: Users (where senderId = userId OR receiverId = userId)
- **Update**: Users (where receiverId = userId) - for marking as read
- **Delete**: Users (where senderId = userId)

## Collection: user_presence (Optional)

Track user online status for instant messaging.

### Fields:
- **userId** (string, required)
  - The user's ID
  - Index: Yes
  
- **isOnline** (boolean, required)
  - Whether the user is currently online
  
- **lastSeen** (datetime, required)
  - Last time the user was active
  
- **status** (string, optional)
  - User status message

### Permissions:
- **Create**: Users (where userId = current user)
- **Read**: Users (authenticated)
- **Update**: Users (where userId = current user)
- **Delete**: Users (where userId = current user)

## Real-time Subscriptions

The instant messaging system uses Appwrite's real-time features:

1. **Message Updates**: Subscribe to `instant_messages` collection for new messages
2. **Presence Updates**: Subscribe to `user_presence` for online status changes

## Security Considerations

1. **Message Privacy**: Users can only read messages where they are sender or receiver
2. **Read Receipts**: Only receivers can mark messages as read
3. **Conversation IDs**: Generated deterministically to ensure consistent IDs
4. **Rate Limiting**: Consider implementing rate limits on message creation

## Implementation Notes

1. **Conversation Management**: Conversations are derived from messages, not stored separately
2. **Unread Counts**: Calculated from messages where `receiverId = currentUser && isRead = false`
3. **Search**: User search uses the existing `users` collection
4. **Notifications**: Can be integrated with push notifications for new messages