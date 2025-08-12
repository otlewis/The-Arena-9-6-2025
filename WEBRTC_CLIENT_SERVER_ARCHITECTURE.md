# WebRTC Client-Server Architecture Summary

## Current Implementation: Simple WebRTC (Peer-to-Peer)

Your app is currently using **Simple WebRTC signaling** (not MediaSoup's SFU model), connecting to the `/signaling` namespace on port 3001.

### Client: SimpleMediaSoupService (misleading name - it's actually simple WebRTC)

```dart
// Connection
final serverUri = 'http://jitsi.dialecticlabs.com:3001/signaling';

// Key features:
- Multiple peer connections (mesh network)
- Direct peer-to-peer connections
- Each participant connects to every other participant
- Good for small rooms (< 5-6 participants)
```

#### Client Flow:
1. **Connect to signaling server**
   ```dart
   await connect(serverUrl, room, userId, audioOnly: false, role: 'moderator')
   ```

2. **Join room**
   ```dart
   _socket!.emit('join-room', {
     'roomId': room,
     'userId': userId,
     'role': role
   });
   ```

3. **Handle peer events**
   - `peer-joined`: New participant joined
   - Create RTCPeerConnection for each peer
   - Exchange offers/answers
   - Exchange ICE candidates

4. **Media handling**
   - Local stream: getUserMedia (audio + video based on role)
   - Remote streams: Received via peer connections
   - Moderators/Speakers: Publish audio+video
   - Audience: Receive only

### Server: unified-webrtc-server.cjs (Simple Signaling)

```javascript
// Signaling namespace
const signalingNamespace = io.of('/signaling');

// Events handled:
- 'join-room': User joins, notify others, send existing peers
- 'offer': Relay WebRTC offer between peers
- 'answer': Relay WebRTC answer between peers
- 'ice-candidate': Relay ICE candidates
- 'disconnect': Clean up and notify others
```

#### Key Server Features:
1. **Room participant tracking**
   ```javascript
   signalingRooms.set(roomId, new Map()); // roomId -> participants
   ```

2. **Peer discovery** (FIXED)
   ```javascript
   // Send existing participants to new joiner
   for (const existingParticipant of existingParticipants) {
     socket.emit('peer-joined', { peerId, userId, role });
   }
   ```

3. **Simple relay** - Server just relays WebRTC signaling messages

## Alternative: MediaSoup Server (SFU - Not Currently Used)

You have a MediaSoup server (`mediasoup-production-server.js`) but it's **NOT being used** by your client. Here's what it offers:

### MediaSoup Features:
1. **Selective Forwarding Unit (SFU)**
   - Server receives media from each participant
   - Selectively forwards to others
   - Better for larger rooms (10+ participants)
   - More server resources required

2. **Produce/Consume Model**
   ```javascript
   // Producer creates media
   socket.on('produce', async (data, callback) => {
     // Create producer on transport
     const producer = await transport.produce({
       kind, rtpParameters, appData
     });
   });

   // Consumer receives media
   socket.on('consume', async (data, callback) => {
     // Create consumer for specific producer
     const consumer = await transport.consume({
       producerId, rtpCapabilities
     });
   });
   ```

3. **Transport Management**
   - WebRTC transports for sending/receiving
   - Better bandwidth management
   - Server-side media control

## Current Issues & Solutions

### Issue: Video not displaying
**Root causes found:**
1. ✅ RTCVideoRenderer not initialized before use (FIXED)
2. ✅ Peer-joined events not sent for existing participants (FIXED)
3. ⚠️ Possible ICE/STUN configuration issues

### Recommendations:

1. **For current Simple WebRTC setup:**
   - Works well for small rooms (2-6 participants)
   - Ensure STUN servers are configured
   - Monitor peer connection states

2. **Consider MediaSoup if:**
   - Need to support 10+ participants
   - Want server-side recording
   - Need better bandwidth management
   - Want to control media quality per participant

3. **Debugging video issues:**
   - Check browser/device camera permissions
   - Verify ICE candidates are being exchanged
   - Monitor peer connection states
   - Check if video tracks are in the SDP offers/answers

## Testing Commands

```bash
# Test current simple WebRTC
node test-video-debug.cjs

# Check server health
curl http://jitsi.dialecticlabs.com:3001/health

# Monitor server logs
ssh root@jitsi.dialecticlabs.com
journalctl -u arena-webrtc-unified -f
```