# Manual Deployment Steps for Signaling Fix

## Files to Upload
1. `unified-webrtc-server.cjs` - The fixed server with peer-joined event support

## Steps to Deploy

### 1. Upload the fixed server file
```bash
scp unified-webrtc-server.cjs root@jitsi.dialecticlabs.com:/opt/arena-webrtc/
```

### 2. SSH into the server
```bash
ssh root@jitsi.dialecticlabs.com
```

### 3. Navigate to the deployment directory
```bash
cd /opt/arena-webrtc
```

### 4. Backup the current server (optional)
```bash
cp unified-webrtc-server.cjs unified-webrtc-server.cjs.backup.$(date +%Y%m%d_%H%M%S)
```

### 5. Find and restart the running service
```bash
# Check what service is running
systemctl list-units --type=service --all | grep -E 'arena.*webrtc|webrtc.*arena'

# Restart the found service (replace SERVICE_NAME with actual service name)
systemctl restart SERVICE_NAME

# Or if no service is found, restart manually:
pkill -f unified-webrtc-server.cjs
nohup node unified-webrtc-server.cjs > server.log 2>&1 &
```

### 6. Verify the deployment
```bash
# Check service status
systemctl status SERVICE_NAME

# Or check process if started manually
ps aux | grep unified-webrtc-server.cjs

# Test health endpoint
curl http://localhost:3001/health
```

### 7. Test the fix
- Join debates & discussions room as moderator from one device
- Join as audience from another device  
- Audience should now see moderator's video feed correctly
- When audience becomes speaker, others should see their video feed

## What the Fix Addresses
- **Peer-joined events**: New joiners now receive events about existing participants
- **Video stream mapping**: Proper peer-to-user ID mapping prevents video reassignment
- **Speaker video**: Fixed role upgrade reconnection for video capabilities

## Expected Behavior After Fix
- Moderator's video feed stays consistent when new participants join
- Speakers can turn on video after role upgrade
- All video streams display correctly with proper user mapping