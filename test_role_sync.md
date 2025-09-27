# Role Authority System Multi-Device Synchronization Test

## Overview
This document outlines how to test the Role Authority System to verify that role changes sync correctly across multiple devices.

## Test Scenarios

### Test 1: Basic Role Promotion
**Setup**: 2 devices in the same room
- **Device A**: Moderator
- **Device B**: Audience member

**Steps**:
1. Device B raises hand using "Raise Hand" button
2. Device A promotes Device B to speaker
3. **Expected**: Device B immediately shows as speaker on both devices
4. **Expected**: Device B gains speaker controls (unmute, video)

### Test 2: Role Demotion
**Setup**: Device B is now a speaker (from Test 1)

**Steps**:
1. Device A demotes Device B back to audience
2. **Expected**: Device B immediately shows as audience on both devices
3. **Expected**: Device B loses speaker controls automatically

### Test 3: Self-Demotion
**Setup**: Device B is a speaker

**Steps**:
1. Device B clicks "Leave Speaker Panel" button
2. **Expected**: Device B immediately shows as audience on both devices
3. **Expected**: Device A sees Device B move from speakers to audience

### Test 4: Hand Raise Cancellation
**Setup**: Device B is audience

**Steps**:
1. Device B clicks "Raise Hand"
2. Verify Device A sees pending request
3. Device B clicks "Lower Hand"
4. **Expected**: Pending request disappears on both devices

### Test 5: Connection Resilience
**Setup**: 2 devices, one temporarily offline

**Steps**:
1. Device B goes offline
2. Device A promotes Device B (while B is offline)
3. Device B comes back online
4. **Expected**: Device B receives updated role upon reconnection

### Test 6: Rapid Role Changes
**Setup**: Multiple rapid role changes

**Steps**:
1. Device A rapidly promotes/demotes Device B multiple times
2. **Expected**: All changes sync without conflicts
3. **Expected**: Final state is consistent across devices

## Expected Behaviors

### ✅ Success Criteria
- [ ] Role changes appear on all devices within 2 seconds
- [ ] No "split-brain" scenarios (devices showing different roles)
- [ ] Audio/video permissions update automatically with role changes
- [ ] Hand raise/lower actions sync immediately
- [ ] Offline devices catch up when reconnected
- [ ] No duplicate role change events processed

### ❌ Failure Indicators
- Different devices showing different roles for the same user
- Role changes taking >5 seconds to sync
- Audio/video not updating with role changes
- Hand raise buttons not updating correctly
- Errors in Role Authority System logs

## Test Commands

### Flutter Test (Automated)
```bash
flutter test test/integration/role_authority_test.dart
```

### Manual Device Testing
1. Build and install on multiple devices:
```bash
flutter build apk --release
# Install on Device A and Device B
```

2. Join same room on both devices
3. Follow test scenarios above

### Debug Monitoring
Watch logs for Role Authority events:
```bash
flutter logs --verbose
# Look for messages with: 🎭, 🎤, 👥, ✋, 🖐️
```

## Rollback Plan
If role sync issues are found:

1. **Emergency Disable**:
   - Set feature flag `useRoleAuthority = false`
   - Fall back to old local role system

2. **Investigate**:
   - Check Appwrite realtime subscriptions
   - Verify database schema updates
   - Test network connectivity

3. **Fix and Retry**:
   - Address specific sync issues
   - Re-test with smaller user groups
   - Gradually roll out to all users

## Performance Monitoring
Monitor these metrics during testing:
- Role change latency (should be <2 seconds)
- Database query performance
- LiveKit permission update speed
- Memory usage (should not increase over time)
- Network bandwidth (role events should be minimal)

## Success Declaration
The Role Authority System is ready for production when:
- ✅ All 6 test scenarios pass consistently
- ✅ 10+ concurrent users can be tested without sync issues
- ✅ System works reliably over 1+ hour sessions
- ✅ No critical errors in production logs
- ✅ Performance metrics are within acceptable ranges