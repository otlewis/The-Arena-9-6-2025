# Appwrite Collections Setup for Hand Raises

## Create room_hand_raises Collection

### Collection Details
- **Collection ID**: `room_hand_raises`
- **Collection Name**: `Room Hand Raises`

### Required Attributes

1. **roomId** (String)
   - Required: Yes
   - Size: 50
   - Description: ID of the room

2. **userId** (String)
   - Required: Yes
   - Size: 50
   - Description: ID of the user raising hand

3. **userName** (String)
   - Required: Yes
   - Size: 100
   - Description: Display name of the user

4. **userAvatar** (String)
   - Required: No
   - Size: 500
   - Description: URL to user's avatar image

5. **raisedAt** (DateTime)
   - Required: Yes
   - Description: When the hand was raised

6. **status** (String)
   - Required: Yes
   - Size: 20
   - Default: "raised"
   - Description: Status of the hand raise

### Indexes (Recommended)
1. **roomId_index**: roomId (ASC)
2. **userId_index**: userId (ASC)
3. **status_index**: status (ASC)
4. **composite_index**: roomId, userId, status (ASC)

### Permissions
- **Read**: Role: user
- **Create**: Role: user  
- **Update**: Role: user
- **Delete**: Role: user

## Setup Instructions

1. Go to your Appwrite Console
2. Navigate to Database → arena_db
3. Click "Add Collection"
4. Set Collection ID: `room_hand_raises`
5. Add all the attributes listed above
6. Add the recommended indexes
7. Set the permissions as specified 