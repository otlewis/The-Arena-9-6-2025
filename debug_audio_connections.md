# Debug Audio Connections - Auto vs Manual

## How to Debug the Issue

1. **Run the app and join a debates & discussions room**
2. **Look for these log patterns:**

### Auto-Connect Logs (should appear on room load):
```
🔥 AUTO-CONNECT: _autoConnectAudio() called - attempting to connect ALL users
🔥 AUTO-CONNECT: Current user: [userId], isModerator: [bool], isSpeaker: [bool]
🔥 AUTO-CONNECT: Audio state - connected: [bool], connecting: [bool]
🔥 AUTO-CONNECT: Participant roles: [map]
🔥 CONNECT-AUDIO: Role determination - isModerator: [bool], isSpeaker: [bool]
🔥 CONNECT-AUDIO: ✅ Assigned [ROLE] role
🔥 CONNECT-AUDIO: 🔑 Generated LiveKit token successfully: [token]...
🔥 CONNECT-AUDIO: ✅ Audio connected successfully as [role]
```

### Manual Connect Logs (when user clicks "Join Audio"):
```
🔥 MANUAL-CONNECT: Join Audio button pressed
🔥 MANUAL-CONNECT: Current user: [userId], isModerator: [bool], isSpeaker: [bool]
🔥 MANUAL-CONNECT: Audio state - connected: [bool], connecting: [bool]
🔥 MANUAL-CONNECT: Participant roles: [map]
🔥 CONNECT-AUDIO: Role determination - isModerator: [bool], isSpeaker: [bool]
🔥 CONNECT-AUDIO: ✅ Assigned [ROLE] role
🔥 CONNECT-AUDIO: 🔑 Generated LiveKit token successfully: [token]...
🔥 CONNECT-AUDIO: ✅ Audio connected successfully as [role]
```

## Key Differences to Look For:

1. **Role Assignment**: Compare the role determination between auto and manual
2. **Timing**: Does auto-connect happen before roles are properly loaded?
3. **Token Generation**: Are tokens different between auto and manual?
4. **LiveKit Service State**: Is there a difference in service state?

## Expected Behavior:
- **Auto-connect**: Should work immediately when room loads for ALL users
- **Manual connect**: Works when user clicks button
- **Role should be correct in both cases** based on database participant role

## Server-Side Debugging:
Since we can't access server logs directly, use these commands if you have server access:

```bash
# Check LiveKit server logs
ssh root@172.236.109.9 "docker logs -f livekit-server --tail=50"

# Check LiveKit container status  
ssh root@172.236.109.9 "docker ps | grep livekit"

# Check server resource usage
ssh root@172.236.109.9 "top -n 1"
```

## Next Steps:
1. Run the app and capture both auto-connect and manual connect logs
2. Compare the role assignments and token generation
3. Identify where the auto-connect flow differs from manual connect
4. Fix the identified difference