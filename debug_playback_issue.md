# Debug Playback Recording Issue

## Steps to Debug

### 1. Check if room has playback enabled

Go to Appwrite Console → arena_db → arena_rooms → find your room:
- Check `enablePlayback` field - should be `true`
- Note the room ID

### 2. Check app logs when joining room

Look for these log messages when moderator joins:
```
🎬 Starting audio recording for arena room with playback enabled
🎬 Starting audio recording for room: [roomId]
✅ Audio recording started successfully
```

**If you DON'T see these:**
- Room doesn't have `enablePlayback: true`
- User is not the moderator
- Recording failed to start (check for error logs)

### 3. Check app logs when ending room

Look for these messages when moderator ends room:
```
🎬 ROOM CLOSURE - Stopping audio recording before closing room
🛑 Stopping audio recording
✅ Recording stopped. Duration: [X]s
📊 Recording file size: [X] MB
📤 Uploading recording to Appwrite...
✅ File uploaded to Appwrite: [fileId]
✅ Playback document created: [playbackId]
✅ ROOM CLOSURE - Audio recording stopped, playback created: [playbackId]
```

**If you DON'T see these:**
- Recording never started
- Recording service not initialized
- Upload failed (check for error logs)

### 4. Check Appwrite Storage

Go to Appwrite Console → Storage → arena-playbacks bucket:
- Look for newly uploaded .aac files
- Check file size (should be > 0 bytes)
- Click file to verify it exists and has content

**If file is missing:**
- Upload failed
- Network error during upload
- Permissions issue

### 5. Check arena_playbacks collection

Go to Appwrite Console → Databases → arena_db → arena_playbacks:
- Look for document with your roomId
- Check fields:
  - `recordingUrl` - should have a URL
  - `status` - should be "ready"
  - `duration` - should be > 0

**If document is missing:**
- Playback creation failed
- Check error logs for "Error creating playback document"

### 6. Check room status

Go to Appwrite Console → Databases → arena_db → arena_rooms → your room:
- `status` should be "completed"
- `playbackStatus` should be "ready"
- `playbackId` should have the playback document ID

**If status is wrong:**
- Room update failed
- Check error logs

## Common Issues

### Recording never starts
**Cause**: Room not created with `enablePlayback: true`
**Fix**: When creating room, ensure playback toggle is ON

### Recording fails to upload
**Cause**: Storage bucket permissions or network issue
**Fix**:
- Verify bucket permissions (Users can Create)
- Check network connection
- Check file size limit (default 50MB, may need to increase)

### No playback document created
**Cause**: Collection doesn't exist or create failed
**Fix**:
- Verify `arena_playbacks` collection exists
- Check create permissions

### Room doesn't show in lobby
**Cause**: Room status not updated to completed
**Fix**: Manually update room status in Appwrite

## Quick Test

1. Create new arena room with playback ON
2. Join as moderator
3. Watch logs for recording start message
4. End room immediately
5. Watch logs for upload messages
6. Check Appwrite Storage for file
7. Check arena_playbacks for document
8. Refresh Arena Lobby

## Still not working?

Share the complete logs from:
1. Joining the room (as moderator)
2. Ending the room
3. Any error messages in red
