# Setup Audio Playback Recording

## ✅ What's Been Done

1. Created `SimpleAudioRecordingService` - records audio locally and uploads to Appwrite
2. Updated `arena_screen.dart` to use simple audio recording instead of LiveKit Egress
3. Recordings will automatically create documents in `arena_playbacks` collection

## 📋 Setup Required

### 1. Create Appwrite Storage Bucket

Go to Appwrite Console → Storage → Create Bucket:

- **Bucket ID**: `arena-playbacks`
- **Bucket Name**: Arena Playbacks
- **File Size Limit**: 100 MB (or higher if needed)
- **Allowed File Extensions**: `aac, mp3, m4a, wav` (audio formats)
- **Permissions**:
  - **Read**: Any (so users can play the recordings)
  - **Create**: Users (moderators can upload)
  - **Update**: Users
  - **Delete**: Users

### 2. Verify arena_playbacks Collection Exists

The collection should already exist with these fields:
- `roomId` (string)
- `title` (string)
- `recordingUrl` (string)
- `duration` (integer)
- `status` (string) - values: "ready", "processing", "failed"
- `createdAt` (string/datetime)

If it doesn't exist, create it using the setup script or manually.

### 3. Test the System

1. **Create an Arena room** with `enablePlayback: true`
2. **Join as moderator**
3. **Start the debate** - audio recording should start automatically
4. **End the room** - recording stops, uploads to Appwrite, creates playback document
5. **Check Arena Lobby** - room should show playback available
6. **Play the recording** - should play the audio

## 🔍 How It Works

**Recording Flow:**
1. Moderator joins room → recording starts automatically
2. Audio recorded locally on moderator's device (AAC format, 128kbps)
3. When room ends → audio file uploads to Appwrite Storage
4. Playback document created in `arena_playbacks` collection
5. Room status updated to `completed` with `playbackStatus: "ready"`

**Playback Flow:**
1. User views Arena Lobby
2. Completed rooms with playback show "Watch Playback" button
3. Click button → opens `ArenaPlaybackScreen`
4. Audio plays from Appwrite Storage URL

## 📊 Benefits Over LiveKit Egress

- ✅ **Much simpler** - no external services required
- ✅ **More reliable** - fewer points of failure
- ✅ **Cheaper** - no LiveKit Egress costs
- ✅ **Smaller files** - audio-only vs video
- ✅ **Faster uploads** - smaller file size
- ✅ **Same UX** - still appears in Arena Playbacks

## 🐛 Troubleshooting

### Recording doesn't start
- Check microphone permissions
- Check logs for "Starting audio recording"
- Verify `enablePlayback: true` in room data

### Upload fails
- Verify `arena-playbacks` bucket exists
- Check bucket permissions allow Create
- Check Appwrite console for storage errors

### Playback doesn't appear
- Check `arena_playbacks` collection for document
- Verify room `playbackStatus` is "ready"
- Check logs for "Playback document created"

### Can't play audio
- Verify storage bucket Read permissions set to "Any"
- Check file URL in playback document
- Test URL in browser to verify it works
