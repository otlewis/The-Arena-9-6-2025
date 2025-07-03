# 🔧 Appwrite Schema Setup Instructions

Follow these steps exactly to fix the schema issues and enable real room/participant data.

## Step 1: Access Appwrite Console

1. Go to https://console.appwrite.io/
2. Log in to your account
3. Select your **Arena** project
4. Navigate to **Databases** → **arena_db**

## Step 2: Update Collections Schema

### Collection: `rooms`

1. Click on **"rooms"** collection
2. Go to **"Attributes"** tab
3. **Add these attributes one by one:**

| Click "Create Attribute" → String | Required Fields |
|-----------------------------------|-----------------|
| **Key:** `title` | **Size:** 255, **Required:** ✅ |
| **Key:** `description` | **Size:** 1000, **Required:** ✅ |
| **Key:** `type` | **Size:** 50, **Required:** ✅, **Default:** "discussion" |
| **Key:** `status` | **Size:** 50, **Required:** ✅, **Default:** "scheduled" |
| **Key:** `createdBy` | **Size:** 255, **Required:** ✅ |
| **Key:** `clubId` | **Size:** 255, **Required:** ❌ |
| **Key:** `moderatorId` | **Size:** 255, **Required:** ❌ |
| **Key:** `settings` | **Size:** 2000, **Required:** ❌, **Default:** "{}" |
| **Key:** `debateFormat` | **Size:** 50, **Required:** ❌ |
| **Key:** `currentSpeakerId` | **Size:** 255, **Required:** ❌ |
| **Key:** `sides` | **Size:** 2000, **Required:** ❌ |
| **Key:** `prizeDescription` | **Size:** 500, **Required:** ❌ |

| Click "Create Attribute" → DateTime | Required Fields |
|-------------------------------------|-----------------|
| **Key:** `scheduledAt` | **Required:** ❌ |
| **Key:** `startedAt` | **Required:** ❌ |
| **Key:** `endedAt` | **Required:** ❌ |

| Click "Create Attribute" → Boolean | Required Fields |
|------------------------------------|-----------------|
| **Key:** `isPublic` | **Required:** ❌, **Default:** true |
| **Key:** `votingEnabled` | **Required:** ❌, **Default:** false |
| **Key:** `isFeatured` | **Required:** ❌, **Default:** false |

| Click "Create Attribute" → Integer | Required Fields |
|------------------------------------|-----------------|
| **Key:** `maxParticipants` | **Required:** ❌, **Default:** 50 |
| **Key:** `timeLimit` | **Required:** ❌ |

| Click "Create Attribute" → String Array | Required Fields |
|------------------------------------------|-----------------|
| **Key:** `participantIds` | **Size:** 255, **Required:** ❌ |
| **Key:** `speakerQueue` | **Size:** 255, **Required:** ❌ |
| **Key:** `tags` | **Size:** 100, **Required:** ❌ |
| **Key:** `judgeIds` | **Size:** 255, **Required:** ❌ |

### Collection: `room_participants`

1. Click on **"room_participants"** collection
2. Go to **"Attributes"** tab
3. **Add these attributes:**

| Click "Create Attribute" → String | Required Fields |
|-----------------------------------|-----------------|
| **Key:** `userId` | **Size:** 255, **Required:** ✅ |
| **Key:** `roomId` | **Size:** 255, **Required:** ✅ |
| **Key:** `userName` | **Size:** 255, **Required:** ✅ |
| **Key:** `userAvatar` | **Size:** 500, **Required:** ❌ |
| **Key:** `role` | **Size:** 50, **Required:** ✅, **Default:** "listener" |
| **Key:** `status` | **Size:** 50, **Required:** ✅, **Default:** "joined" |
| **Key:** `side` | **Size:** 50, **Required:** ❌ |
| **Key:** `metadata` | **Size:** 2000, **Required:** ❌, **Default:** "{}" |

| Click "Create Attribute" → DateTime | Required Fields |
|-------------------------------------|-----------------|
| **Key:** `joinedAt` | **Required:** ✅ |
| **Key:** `leftAt` | **Required:** ❌ |
| **Key:** `lastActiveAt` | **Required:** ❌ |

| Click "Create Attribute" → Integer | Required Fields |
|------------------------------------|-----------------|
| **Key:** `speakingOrder` | **Required:** ❌ |

## Step 3: Update Permissions

For **both collections** (`rooms` and `room_participants`):

1. Go to **"Settings"** tab
2. Click **"Update Permissions"**
3. Set these permissions:
   - **Read:** `role:authenticated`
   - **Create:** `role:authenticated`
   - **Update:** `role:authenticated`
   - **Delete:** `role:authenticated`
4. Click **"Update"**

## Step 4: Create Indexes (Optional but Recommended)

### For `rooms` collection:
1. Go to **"Indexes"** tab
2. Click **"Create Index"**
3. Create these indexes:
   - **Key:** `status_index`, **Type:** key, **Attributes:** status (ASC)
   - **Key:** `createdBy_index`, **Type:** key, **Attributes:** createdBy (ASC)
   - **Key:** `isPublic_index`, **Type:** key, **Attributes:** isPublic (ASC)

### For `room_participants` collection:
1. Go to **"Indexes"** tab
2. Click **"Create Index"**
3. Create these indexes:
   - **Key:** `userId_index`, **Type:** key, **Attributes:** userId (ASC)
   - **Key:** `roomId_index`, **Type:** key, **Attributes:** roomId (ASC)
   - **Key:** `status_index`, **Type:** key, **Attributes:** status (ASC)
   - **Key:** `userId_roomId_compound`, **Type:** key, **Attributes:** userId (ASC), roomId (ASC)

## Step 5: Test the Schema

1. **Run the app** on your iPhone
2. **Create a new room** - it should now save to Appwrite instead of using mock data
3. **Check the Appwrite console** → Databases → arena_db → rooms to see your created room
4. **Join the room** and verify participants are saved in the room_participants collection

## Step 6: Verify Everything Works

You should now see:

✅ **Real room creation** - rooms saved to Appwrite database  
✅ **Real room listing** - rooms loaded from Appwrite  
✅ **Real participants** - participant data saved to Appwrite  
✅ **Voice chat working** - Agora voice with real participant count  
✅ **No more schema errors** - all attributes exist  

## Troubleshooting

If you get errors:

1. **"Attribute not found"** → Double-check attribute names match exactly
2. **"Invalid document structure"** → Verify all required fields are marked as required
3. **"Permission denied"** → Check permissions are set to `role:authenticated`
4. **"Document creation failed"** → Check default values for required fields

## Next Steps

Once this is working, you'll have:
- ✅ Real-time room creation and joining
- ✅ Proper participant tracking
- ✅ Voice chat with actual user data
- ✅ Foundation for advanced features like moderation, user profiles, etc.

Good luck! 🚀 