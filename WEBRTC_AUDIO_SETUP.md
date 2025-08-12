# WebRTC Audio Room Setup Guide

## Overview
This setup creates a **WebRTC + Socket.IO audio conferencing system** that's perfect for debate platforms like Arena. It provides **two-way audio communication** with full control and **cost-effective scaling**.

## Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │ Socket.IO Server│    │   Flutter App   │
│   (Device 1)    │    │  (Signaling)    │    │   (Device 2)    │
│                 │    │                 │    │                 │
│ • Send Audio    │◄──►│ • WebRTC        │◄──►│ • Send Audio    │
│ • Receive Audio │    │ • Room mgmt     │    │ • Receive Audio │
│ • Speaking UI   │    │ • User mgmt     │    │ • Speaking UI   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                                                │
         └──────────── Direct P2P Audio ─────────────────┘
```

## Features

### ✅ **What Works**
- **Two-way audio** communication
- **Multi-participant** audio rooms
- **Real-time speaking** indicators
- **Mute/unmute** controls
- **Participant management**
- **Room join/leave** functionality
- **Cost effective** ($20-100/month for server)

### 🎯 **Perfect for Arena**
- **Debate rooms** with multiple speakers
- **Audience listening** mode
- **Moderator controls**
- **Speaking queue** management
- **Audio-first** design (no video overhead)

## Quick Setup

### 1. Start Signaling Server
```bash
# From Arena project root
./start-signaling-server.sh
```

This will:
- Create `webrtc-server/` directory
- Install Node.js dependencies
- Start server on `http://localhost:3001`

### 2. Test in Flutter App
1. Open Arena app
2. Tap **purple WebRTC Audio Test** button (floating action button)
3. Tap **"Connect to Server"**
4. Tap **"Join Audio Room"**
5. Test with multiple devices

## Server Requirements

### Development (Local Testing)
- **Node.js** 16+ installed
- **npm** for package management
- **Local network** for multi-device testing

### Production Deployment
Choose one option:

#### Option A: Simple VPS
- **DigitalOcean/Linode:** $20-50/month
- **2GB RAM, 1-2 CPUs**
- **Ubuntu 20.04+ with Node.js**

#### Option B: Cloud Platform
- **Heroku:** $25-100/month
- **Railway:** $20-80/month  
- **Render:** $25-75/month

## Configuration

### Server Settings (signaling-server.js)
```javascript
const PORT = process.env.PORT || 3001;

// CORS settings for production
const io = socketIo(server, {
  cors: {
    origin: "https://yourdomain.com", // Update for production
    methods: ["GET", "POST"]
  }
});
```

### Flutter App Settings (webrtc_audio_test.dart)
```dart
// Update server URL for production
_socket = IO.io('https://your-signaling-server.com', {
  'transports': ['websocket'],
  'autoConnect': false,
});
```

## Testing Instructions

### Single Device Test
1. Start signaling server
2. Open Flutter app
3. Join WebRTC Audio Test
4. Verify audio permissions work
5. Check participant list shows "You"

### Multi-Device Test
1. Ensure both devices on same network
2. Both connect to signaling server
3. Both join same room ("AUDIO_TEST_ROOM")
4. Speak on Device 1 → should hear on Device 2
5. Speak on Device 2 → should hear on Device 1
6. Test mute/unmute on both devices

## Troubleshooting

### ❌ "Connection failed"
- Check signaling server is running (`http://localhost:3001`)
- Verify Flutter app can reach server
- Check console logs in signaling server

### ❌ "Can't hear other participants"
- Verify WebRTC peer connections established
- Check ICE candidates are exchanging
- Ensure both devices have microphone permissions

### ❌ "Audio permissions denied"
- Go to device Settings → App permissions
- Enable microphone for Arena app
- Restart app after permission granted

## Integration with Arena

### Phase 1: Replace Ant Media
1. Remove Ant Media dependencies
2. Replace arena audio with WebRTC system
3. Use same UI patterns as test room

### Phase 2: Debate Features
1. **Speaker queue** management
2. **Moderator controls** (mute others)
3. **Hand raising** for speaking requests
4. **Timer integration** with audio cues

### Phase 3: Scale Features
1. **SFU server** for 10+ participants
2. **Recording** capabilities
3. **Audio quality** optimization
4. **Mobile optimization**

## Cost Analysis

### Community vs Enterprise
| Feature | WebRTC+Socket.IO | Ant Media Enterprise |
|---------|------------------|---------------------|
| Monthly Cost | $20-100 | $500-1000 |
| Setup Complexity | Medium | Low |
| Customization | Full Control | Limited |
| Participant Limit | Unlimited* | Unlimited |
| Audio Quality | Excellent | Excellent |

*Limited by server resources

### Scaling Costs
- **1-10 participants:** $20-50/month (simple P2P)
- **10-50 participants:** $50-150/month (SFU needed)
- **50+ participants:** $150-500/month (optimized SFU)

## Next Steps

1. **Test current setup** with multiple devices
2. **Verify audio quality** and reliability  
3. **Plan Arena integration** strategy
4. **Choose production server** option
5. **Deploy signaling server** to cloud

## Files Created
- `lib/screens/webrtc_audio_test.dart` - Flutter test screen
- `signaling-server.js` - WebRTC signaling server
- `start-signaling-server.sh` - Easy server startup
- `server-package.json` - Node.js dependencies
- `WEBRTC_AUDIO_SETUP.md` - This guide

Perfect foundation for converting Arena to an audio-first debate platform! 🎉