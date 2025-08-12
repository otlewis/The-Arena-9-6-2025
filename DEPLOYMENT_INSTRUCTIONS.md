# Arena WebRTC Server Deployment Guide

## Quick Deploy to Linode Server (172.236.109.9)

### Method 1: Automated Script (if SSH access works)
```bash
./deploy-webrtc-server.sh
```

### Method 2: Manual Deployment

1. **Copy files to your Linode server:**
   ```bash
   scp arena-webrtc-server.cjs root@172.236.109.9:~/
   scp server-package.json root@172.236.109.9:~/package.json
   ```

2. **SSH into your server:**
   ```bash
   ssh root@172.236.109.9
   ```

3. **Install dependencies and start server:**
   ```bash
   npm install
   pkill -f "node.*3000" || true
   ufw allow 3000
   nohup node arena-webrtc-server.cjs > arena-webrtc.log 2>&1 &
   ```

4. **Verify server is running:**
   ```bash
   curl http://localhost:3000/
   ```

### Method 3: Alternative - Use Existing Domain/Server

If you have issues with the Linode server, you can also:

1. **Deploy to any VPS/cloud provider**
2. **Use a service like Railway, Heroku, or Vercel**
3. **Update the connection URL in the Flutter app:**

```dart
// In lib/screens/arena_webrtc_screen.dart line 190:
_socket = io.io('http://YOUR_SERVER_URL:3000', <String, dynamic>{
```

## Testing the Deployment

1. **Check server health:**
   ```bash
   curl http://172.236.109.9:3000/
   ```
   Should return: `{"message":"Arena WebRTC Server","status":"running",...}`

2. **Run the Flutter app:**
   ```bash
   flutter run test_arena_webrtc.dart -d chrome
   ```

3. **Open multiple browser tabs** to test multi-participant video calling

## Server Logs

To view server logs:
```bash
ssh root@172.236.109.9 'tail -f arena-webrtc.log'
```

## Troubleshooting

- **Connection refused**: Server not running or firewall blocking port 3000
- **CORS errors**: Check server CORS configuration (already set to allow all)
- **WebRTC connection issues**: Check STUN/TURN server configuration

## Success Indicators

✅ Server responds to health check
✅ App connects to server without timeout
✅ Local video stream shows
✅ Participant count increases when multiple users join
✅ WebRTC signaling messages appear in server logs