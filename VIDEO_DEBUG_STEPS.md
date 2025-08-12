# Video Debug Steps

Since audio is working but video isn't, let's debug step by step:

## Step 1: Test Camera Permissions
Run this Flutter app to test if camera access works:

1. Add the debug screen to your app by importing `debug_video_setup.dart`
2. Navigate to the debug screen
3. Tap "Test Camera" button
4. Check if you can see your own video feed

**Expected**: You should see your own camera feed in the local video area

## Step 2: Check WebRTC Video Negotiation

Look at the Flutter console logs when connecting as moderator:
- Should see: "🎥 Video tracks: 1" for local stream
- Should see: "✅ Local video renderer set"
- Should see: "➕ Added video track [id] to peer connection"

## Step 3: Check Server-Side Peer Events

Run the test script:
```bash
node test-video-debug.cjs
```

**Expected**: Both moderator and audience should see peer-joined events

## Step 4: Common Issues & Fixes

### Issue 1: Camera Permission Denied
**Symptoms**: "❌ getUserMedia failed: NotAllowedError"
**Fix**: Grant camera permissions to the app

### Issue 2: Video Tracks Not Created
**Symptoms**: "🎥 Video tracks: 0" in logs
**Fix**: Check if `audioOnly: false` is being passed correctly

### Issue 3: Remote Video Not Displaying
**Symptoms**: Local video works, but remote video shows "No Remote Videos"
**Fix**: Check if remote stream callbacks are firing

### Issue 4: WebRTC Connection Issues
**Symptoms**: Peer-joined events work, but no video/audio exchange
**Fix**: Check STUN/TURN server configuration

## Step 5: Quick Fix Attempt

The most likely issue is that video constraints are not being properly applied. Try this quick fix:

In `simple_mediasoup_service.dart`, find the `getUserMedia` call and ensure video constraints are being set:

```dart
final Map<String, dynamic> mediaConstraints = {
  'audio': {
    'echoCancellation': true,
    'noiseSuppression': true,
    'autoGainControl': true,
  },
  'video': audioOnly ? false : {
    'width': {'ideal': 640},
    'height': {'ideal': 480},
    'frameRate': {'ideal': 30},
    'facingMode': 'user',
  },
};
```

Verify that `audioOnly` parameter is being set correctly:
- Moderator/Speaker: `audioOnly: false` (should have video)
- Audience: `audioOnly: true` (should not publish video, but can receive it)

## Step 6: Server Video Support Check

Check if the server is properly handling video in WebRTC offers. The current signaling server should relay all offer/answer/ICE messages including video tracks.

## Quick Test Commands

1. Test camera directly:
```bash
flutter run
# Navigate to debug screen, tap "Test Camera"
```

2. Test server signaling:
```bash
node test-video-debug.cjs
```

3. Check production server health:
```bash
curl http://jitsi.dialecticlabs.com:3001/health
```

Let me know what you see at each step!