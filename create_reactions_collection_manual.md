# Create Room Reactions Collection in Appwrite

Since the automatic setup script requires Flutter dependencies, please create the collection manually in the Appwrite Console:

## Steps:

1. **Go to Appwrite Console**: https://cloud.appwrite.io/console
2. **Navigate to**: Your Project → Databases → `arena_db`
3. **Click**: "Create Collection"
4. **Collection ID**: `room_reactions`
5. **Collection Name**: Room Reactions

## Attributes to Create:

Click "Add Attribute" for each:

1. **roomId**
   - Type: String
   - Size: 255
   - Required: Yes

2. **emoji**
   - Type: String
   - Size: 10
   - Required: Yes

3. **targetUserId**
   - Type: String
   - Size: 255
   - Required: Yes

4. **senderUserId**
   - Type: String
   - Size: 255
   - Required: Yes

5. **timestamp**
   - Type: String
   - Size: 255
   - Required: Yes

## Indexes to Create:

Click "Create Index" for each:

1. **roomId_idx**
   - Type: Key
   - Attributes: roomId

2. **targetUserId_idx**
   - Type: Key
   - Attributes: targetUserId

## Permissions:

Set these permissions on the collection:

- **Read**: Any
- **Create**: Users
- **Update**: Users
- **Delete**: Users

## Done!

Once created, the reaction system will work automatically across all users in the room.
