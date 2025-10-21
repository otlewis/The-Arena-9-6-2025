# Check for Unprocessed Recordings

## Steps to check if recordings exist:

1. **Check LiveKit Cloud Dashboard**:
   - Go to https://cloud.livekit.io
   - Click on your Arena project
   - Click "Egress" in sidebar
   - Look for recordings that completed but weren't processed
   - Note the room IDs/names

2. **Check Appwrite arena_playbacks collection**:
   - Go to Appwrite Console → arena_db → arena_playbacks
   - See if playback documents exist for your stuck rooms
   - If they exist but status is "processing", the upload failed

3. **Check your storage (IONOS or cloud)**:
   - If using IONOS: SSH into your server and check `/var/www/arena-recordings/`
   - Look for .mp4 or .webm files matching your room IDs

## If recordings DO exist:

You can manually create playback documents:

1. Go to Appwrite Console → arena_db → arena_playbacks
2. Click "Add Document"
3. Fill in:
   - `roomId`: The stuck room ID
   - `recordingUrl`: URL to the recording file
   - `status`: "ready"
   - `duration`: Duration in seconds (estimate if needed)
   - `title`: Room topic
   - `createdAt`: Current timestamp

## If recordings DON'T exist:

**The rooms can't be recovered.** Those debates weren't recorded.

For the stuck rooms showing "processing":
- Just mark them as `status: "completed"` and `playbackStatus: "failed"`
- This removes them from the "processing" state
- Users will see them as completed debates without playback

## Prevention for future rooms:

1. **Verify LiveKit is working**:
   - Check LiveKit API credentials are correct
   - Test recording in a test room
   - Monitor LiveKit dashboard during debates

2. **Enable playback in room creation**:
   - Make sure `enablePlayback: true` when creating rooms
   - Check room creation logs for any errors

3. **Monitor processing**:
   - Rooms should move from "processing" to "completed" within 5-10 minutes
   - If stuck longer, check LiveKit dashboard for errors
