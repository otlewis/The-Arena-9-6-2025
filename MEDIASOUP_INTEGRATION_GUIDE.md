# MediaSoup SFU Integration Guide

## Overview
This guide shows how to integrate the new MediaSoup SFU mode into your Flutter app, allowing support for large rooms with many audience members.

## Server Setup

### 1. Deploy MediaSoup SFU Server
```bash
# Copy the new server file
cp mediasoup-sfu-server.js /opt/arena-webrtc/

# Install dependencies
cd /opt/arena-webrtc
npm install mediasoup

# Update environment variables
export ANNOUNCED_IP="172.236.109.9"  # Your Linode public IP
export PORT=3001

# Start the server
node mediasoup-sfu-server.js
```

### 2. Update Nginx (if needed)
Ensure UDP ports 10000-10100 are open for WebRTC media.

## Client Integration

### 1. Replace SimpleMediaSoupService
Replace the existing service file with the new SFU-enabled version:
```bash
cp lib/services/simple_mediasoup_service_sfu.dart lib/services/simple_mediasoup_service.dart
```

### 2. Update DebatesDiscussionsScreen

In `_connectToWebRTC()`, add SFU mode detection:

```dart
Future<void> _connectToWebRTC() async {
  if (!mounted || _isWebRTCConnecting || _isWebRTCConnected) {
    return;
  }

  setState(() {
    _isWebRTCConnecting = true;
  });

  try {
    // Determine user role and connection mode
    String userRole;
    bool shouldPublishVideo;
    bool useSFU = false; // Default to false, enable based on conditions
    
    if (_isCurrentUserModerator) {
      userRole = 'moderator';
      shouldPublishVideo = true;
      useSFU = true; // Moderators always use SFU
    } else if (_isCurrentUserSpeaker) {
      userRole = 'speaker';
      shouldPublishVideo = true;
      useSFU = true; // Speakers always use SFU
    } else {
      userRole = 'audience';
      shouldPublishVideo = false;
      // Use SFU for audience if room has many participants
      useSFU = (_participants.length > 5); // Or always true for production
    }
    
    final roomId = 'debates-discussion-${widget.roomId}';
    
    AppLogger().debug('🎥 Connecting to WebRTC for Debates & Discussions');
    AppLogger().debug('🎥 Room: $roomId');
    AppLogger().debug('🎥 User: ${_currentUser?.id} (${_currentUser?.name})');
    AppLogger().debug('🎥 Role: $userRole, Publish: $shouldPublishVideo');
    AppLogger().debug('🎥 Mode: ${useSFU ? "SFU" : "P2P"}');
    
    await _mediaSoupService.connect(
      'jitsi.dialecticlabs.com',
      roomId,
      _currentUser?.id ?? 'unknown',
      audioOnly: !shouldPublishVideo,
      role: userRole,
      sfuMode: useSFU, // NEW: Enable SFU mode
    );
    
    if (mounted) {
      setState(() {
        _isWebRTCConnected = true;
        _isWebRTCConnecting = false;
      });
    }
    
    AppLogger().debug('🎥 WebRTC connected successfully');
    
  } catch (e) {
    AppLogger().error('Failed to connect to WebRTC', e);
    if (mounted) {
      setState(() {
        _isWebRTCConnecting = false;
      });
    }
  }
}
```

### 3. No Other Changes Needed!

The beauty of this implementation is that the existing callbacks remain compatible:
- `onLocalStream(stream)` - Still called with local media
- `onRemoteStream(peerId, stream, userId, role)` - Still called for each remote participant
- `onPeerLeft(peerId)` - Still called when someone leaves
- Video renderers work the same way

## Testing

### 1. Test with Small Group (P2P Mode)
```dart
// Force P2P mode for testing
sfuMode: false
```

### 2. Test with Large Group (SFU Mode)
```dart
// Force SFU mode
sfuMode: true
```

### 3. Load Test
1. Join as moderator (publishes video/audio)
2. Join as 2-5 speakers (publish video/audio)
3. Join as 50+ audience members (receive only)
4. Verify all audience members see all speakers

## Monitoring & Debugging

### Server Logs
```bash
# Enable debug logs
DEBUG=mediasoup:* node mediasoup-sfu-server.js

# Monitor logs
journalctl -u mediasoup-sfu -f
```

### Client Logs
The service includes extensive logging:
- `🚛` Transport creation
- `🎙️` Producer creation
- `🎧` Consumer creation
- `📡` RTP capabilities
- `🆕` New producers
- `🛑` Producer closed
- `👋` Peer left

### Health Check
```bash
curl http://jitsi.dialecticlabs.com:3001/health
```

## Performance Tuning

### 1. Simulcast (Future Enhancement)
Enable VP8 simulcast for speakers:
```javascript
// In produce() on server
const producer = await transport.produce({
  kind,
  rtpParameters,
  encodings: [
    { rid: 'r0', active: true, maxBitrate: 100000 },
    { rid: 'r1', active: true, maxBitrate: 300000 },
    { rid: 'r2', active: true, maxBitrate: 900000 },
  ],
  appData,
});
```

### 2. Adaptive Bitrate
Adjust consumer preferred layers based on viewport:
```javascript
// On server
await consumer.setPreferredLayers({ 
  spatialLayer: 2, 
  temporalLayer: 2 
});
```

### 3. Multiple Workers
The server already creates 4 workers by default. Adjust based on CPU cores:
```javascript
const mediasoupConfig = {
  numWorkers: require('os').cpus().length,
  // ...
};
```

## Rollback Plan

If issues arise, you can quickly rollback to P2P mode:
1. Set `sfuMode: false` in the client
2. Or stop the MediaSoup server and use the original signaling server

## Common Issues & Solutions

### Issue: No video/audio
- Check firewall allows UDP 10000-10100
- Verify ANNOUNCED_IP is set correctly
- Check browser console for WebRTC errors

### Issue: High CPU on server
- Reduce video resolution in constraints
- Enable simulcast
- Add more workers

### Issue: Connection fails
- Check server is running: `curl http://server:3001/health`
- Verify room exists
- Check role permissions (audience can't produce)

## Next Steps

1. **Deploy server** with the new mediasoup-sfu-server.js
2. **Update client** with SFU-enabled service
3. **Test with small group** first (force P2P mode)
4. **Test with large group** (force SFU mode)
5. **Monitor performance** and adjust as needed
6. **Enable simulcast** for better quality adaptation