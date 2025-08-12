# Arena Messages Collection Setup Guide

## Collection Details
- **Collection ID**: `arena_messages`
- **Database**: `arena_db`
- **Purpose**: Store chat messages for Arena debate rooms

## Required Attributes

### 1. Core Message Data
| Attribute | Type | Size | Required | Default | Array |
|-----------|------|------|----------|---------|--------|
| roomId | String | 255 | Yes | - | No |
| userId | String | 255 | Yes | - | No |
| userName | String | 255 | Yes | - | No |
| content | String | 2000 | Yes | - | No |
| timestamp | DateTime | - | Yes | - | No |
| type | String | 50 | Yes | "user" | No |

### 2. Optional Attributes (for future expansion)
| Attribute | Type | Size | Required | Default | Array |
|-----------|------|------|----------|---------|--------|
| userRole | String | 50 | No | - | No |
| isEdited | Boolean | - | No | false | No |
| replyToId | String | 255 | No | - | No |

## Indexes (for performance)

### 1. Room Messages Index
- **Name**: `room_messages`
- **Type**: Key
- **Attributes**: 
  - roomId (ASC)
  - timestamp (ASC)
- **Purpose**: Fast retrieval of messages for a specific room in chronological order

### 2. User Messages Index
- **Name**: `user_messages`
- **Type**: Key  
- **Attributes**:
  - userId (ASC)
  - timestamp (DESC)
- **Purpose**: Fast retrieval of messages sent by a specific user

## Permissions

### Read Permissions
- **Users**: Any authenticated user can read messages in rooms they have access to
- **Rule**: `users` (all authenticated users)

### Write Permissions
- **Users**: Any authenticated user can send messages
- **Rule**: `users` (all authenticated users)

### Delete Permissions
- **Users**: Only message author or room moderators
- **Rule**: `user:[USER_ID]` (message author only for now)

## Manual Setup Steps

### In Appwrite Console:

1. **Navigate to your Arena Database**
   - Go to Databases → arena_db

2. **Create Collection**
   - Click "Create Collection"
   - Collection ID: `arena_messages`
   - Name: "Arena Messages"

3. **Add Attributes**
   ```
   roomId - String(255) - Required
   userId - String(255) - Required  
   userName - String(255) - Required
   content - String(2000) - Required
   timestamp - DateTime - Required
   type - String(50) - Required - Default: "user"
   ```

4. **Create Indexes**
   ```
   Index 1: room_messages
   - roomId (ASC)
   - timestamp (ASC)
   
   Index 2: user_messages  
   - userId (ASC)
   - timestamp (DESC)
   ```

5. **Set Permissions**
   ```
   Read: users
   Create: users
   Update: user:[USER_ID] (optional)
   Delete: user:[USER_ID] (optional)
   ```

## Test Data (Optional)

After creating the collection, you can test with sample data:

```json
{
  "roomId": "test_arena_room",
  "userId": "test_user_123", 
  "userName": "Test User",
  "content": "Hello, this is a test message!",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "type": "user"
}
```

## Validation Rules (Optional Future Enhancement)

- **Content Length**: 1-2000 characters
- **Type Values**: "user", "system", "moderator"
- **Timestamp**: Must be valid ISO 8601 format
- **RoomId Format**: Must match arena room ID pattern

## Integration Notes

- The Arena chat system will automatically start working once this collection is created
- Real-time updates are handled via Appwrite's real-time subscriptions
- Messages are loaded in chronological order (oldest first)
- The system supports both user messages and system announcements (type field)