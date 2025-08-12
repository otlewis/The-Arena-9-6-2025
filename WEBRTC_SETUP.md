# WebRTC Setup Guide for Arena

## Why Build Custom WebRTC?
- Complete control over the implementation
- No third-party SDK issues
- Works reliably on both iOS and Android
- Lighter weight than Jitsi
- Can customize exactly for Arena's needs

## Server Setup (on your Linode)

1. **SSH into your server**:
```bash
ssh root@172.236.109.9
```

2. **Install Node.js**:
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs
```

3. **Create the signaling server**:
```bash
mkdir /opt/webrtc-server
cd /opt/webrtc-server
```

4. **Copy the signaling server code**:
```bash
nano server.js
# Paste the contents of webrtc-signaling-server.js
```

5. **Install dependencies**:
```bash
npm init -y
npm install ws
```

6. **Create systemd service**:
```bash
nano /etc/systemd/system/webrtc-signaling.service
```

Add:
```ini
[Unit]
Description=WebRTC Signaling Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/webrtc-server
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

7. **Start the service**:
```bash
systemctl enable webrtc-signaling
systemctl start webrtc-signaling
systemctl status webrtc-signaling
```

8. **Open firewall port**:
```bash
ufw allow 8443/tcp
```

## Flutter App Setup

1. **Run pub get**:
```bash
flutter pub get
```

2. **Test WebRTC in your app**:

Add to any screen:
```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebRTCCallScreen(
          roomName: 'TestRoom123',
          userName: 'Flutter User',
        ),
      ),
    );
  },
  child: const Text('Test WebRTC'),
),
```

3. **iOS Additional Setup** (if needed):

Add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access for voice calls</string>
```

## How It Works

1. **Signaling**: WebSocket connection to coordinate peer connections
2. **STUN**: Uses Google's free STUN servers for NAT traversal
3. **Peer-to-Peer**: Direct connection between users (no media server needed)
4. **Fallback**: Can add TURN server later if needed

## Testing

1. Open the app on two devices
2. Join the same room name
3. Should connect directly without any lobby or authentication

## Advantages Over Jitsi

- **Simplicity**: ~300 lines of code vs Jitsi's complexity
- **Control**: You own every line of code
- **Performance**: Direct P2P connection
- **Reliability**: No SDK version conflicts
- **Customization**: Add features as needed

## Next Steps

1. Add TURN server for better connectivity behind firewalls
2. Support for multiple participants (mesh or SFU)
3. Recording capabilities
4. Screen sharing

## Troubleshooting

- **Can't connect**: Check firewall port 8443
- **No video/audio**: Check permissions
- **Connection drops**: May need TURN server

This approach gives you a working video/voice solution TODAY without fighting Jitsi configuration issues!