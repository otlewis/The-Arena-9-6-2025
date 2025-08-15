# MediaSoup Complete Removal Instructions

## Overview
MediaSoup has been completely removed from the Arena Flutter app to resolve audio conflicts with LiveKit. The server-side MediaSoup installation also needs to be removed from your Linode server.

## Manual Server Cleanup Required

Since I don't have access to your SSH private key, you'll need to manually run these commands on your Linode server.

### Step 1: Connect to Your Server
```bash
ssh root@172.236.109.9
```

### Step 2: Stop All MediaSoup Processes
```bash
# Kill all MediaSoup processes
pkill -f mediasoup || true
pkill -f 'node.*mediasoup' || true
pkill -f 'mediasoup.*server' || true

# Check for any remaining processes
ps aux | grep -i mediasoup | grep -v grep
```

### Step 3: Remove MediaSoup Directory
```bash
# Remove the main MediaSoup server directory
rm -rf /opt/mediasoup-server

# Check for other MediaSoup installations
find /opt -name '*mediasoup*' -type d 2>/dev/null
find /home -name '*mediasoup*' -type d 2>/dev/null
find /root -name '*mediasoup*' -type d 2>/dev/null
```

### Step 4: Remove SystemD Services
```bash
# Stop and disable any MediaSoup services
systemctl stop mediasoup* 2>/dev/null || true
systemctl disable mediasoup* 2>/dev/null || true

# Remove service files
rm -f /etc/systemd/system/mediasoup*
rm -f /etc/systemd/system/*mediasoup*

# Reload systemd
systemctl daemon-reload
```

### Step 5: Check Network Ports
```bash
# Ensure MediaSoup ports are no longer in use
netstat -tlnp | grep ':3005\|:3002\|:3000'

# If any MediaSoup processes are still using these ports, kill them
lsof -ti:3005 | xargs kill -9 2>/dev/null || true
lsof -ti:3002 | xargs kill -9 2>/dev/null || true
```

### Step 6: Clean Up Any Remaining Files
```bash
# Remove any MediaSoup logs or temporary files
find /var/log -name '*mediasoup*' -delete 2>/dev/null || true
find /tmp -name '*mediasoup*' -delete 2>/dev/null || true
```

### Step 7: Verify Cleanup
```bash
# Final verification - should show no results
ps aux | grep -E '(mediasoup|node.*3005|node.*3002)' | grep -v grep
netstat -tlnp | grep ':3005\|:3002'
find / -name '*mediasoup*' -type f 2>/dev/null | head -10
```

## Expected Result
After completing these steps:
- ✅ No MediaSoup processes running
- ✅ Ports 3005 and 3002 free (MediaSoup ports)
- ✅ All MediaSoup files and directories removed
- ✅ Only LiveKit should remain active for Arena audio

## LiveKit Verification (Optional)
If you want to verify LiveKit is still working:
```bash
# Check if LiveKit is running (usually on port 7880)
netstat -tlnp | grep ':7880'
ps aux | grep livekit
```

## What This Fixes
- **Audio Conflicts**: Eliminates competition between MediaSoup and LiveKit for microphone access
- **Consistent Audio**: All users will now use the same LiveKit audio stack
- **Simpler Architecture**: One WebRTC solution instead of multiple conflicting ones
- **Better Reliability**: No more "some can hear/talk, others can only hear" issues

## Files Already Removed from App
The following MediaSoup-related files have already been disabled/removed from the Arena app:
- All MediaSoup service classes (*.dart.disabled)
- MediaSoup dependencies from pubspec.yaml and package.json
- MediaSoup video panels and UI components
- MediaSoup server files in project root

## Next Steps
1. Complete the server cleanup above
2. Test Arena audio functionality with multiple users
3. Verify all participants can consistently mute/unmute microphones
4. Monitor for any remaining audio issues

## Support
If you encounter any issues during cleanup or need help with specific commands, let me know and I can provide more detailed guidance for your specific server setup.