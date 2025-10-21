# Super Moderator Setup Guide

## Problem

Super moderator ban/kick/mute buttons weren't working because:

1. ✅ **FIXED**: Appwrite functions weren't deployed
2. ✅ **FIXED**: Required collections didn't exist (`super_moderators`, `room_bans`, `security_audit_log`)
3. ✅ **FIXED**: Functions had no API keys configured
4. ✅ **FIXED**: Function code had bugs (referenced non-existent collections)
5. ⚠️ **FINAL STEP**: Re-deploy functions to apply code fixes (see SUPER_MOD_DEPLOYMENT.md)

---

**📋 NEXT STEP**: See **[SUPER_MOD_DEPLOYMENT.md](./SUPER_MOD_DEPLOYMENT.md)** for final deployment instructions.

**Current Status**: Kritik (userId: 6843c3781d2c1c7154a0) is already configured as a super moderator with all permissions. Once you re-deploy the functions, everything should work.

---

## Solution - Add Yourself as Super Moderator (Already Done for Kritik)

### Option 1: Quick Flutter Console Command

Run this in your Flutter app's debug console or add a temporary button:

```dart
// Add this to any screen temporarily (like home_screen.dart)

ElevatedButton(
  onPressed: () async {
    try {
      final appwrite = AppwriteService();
      final superModService = SuperModeratorService();
      await superModService.initialize();

      final currentUser = await appwrite.getCurrentUser();
      final userProfile = await appwrite.getUserProfile(currentUser!.$id);

      final result = await superModService.grantSuperModeratorStatus(
        userId: currentUser.$id,
        username: userProfile!.name,
        grantedBy: 'system', // Bootstrap
        profileImageUrl: userProfile.avatar,
      );

      if (result != null) {
        print('✅ SUCCESS! You are now a super moderator!');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🛡️ You are now a super moderator!')),
        );
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  },
  child: Text('Make Me Super Mod'),
),
```

### Option 2: Using Appwrite Console

1. Go to https://cloud.appwrite.io
2. Navigate to your project → Databases → arena_db → super_moderators
3. Create a new document with:
   ```json
   {
     "userId": "YOUR_USER_ID",
     "username": "YOUR_USERNAME",
     "grantedAt": "2025-10-05T23:00:00.000Z",
     "grantedBy": "system",
     "isActive": true,
     "permissions": [
       "ban_users",
       "kick_users",
       "mute_users",
       "lock_microphones",
       "view_audit_logs",
       "manage_super_moderators",
       "promote_super_moderators",
       "emergency_shutdown"
     ]
   }
   ```

### Option 3: Run the Setup Script

```bash
# Make sure you're logged into the app first, then:
flutter run -d macos -t add_super_moderator.dart
```

## Testing Super Moderator Powers

Once you're added as a super moderator:

1. **Start the app** and log in
2. **Join any Debates & Discussions room**
3. **Click on another user's avatar**
4. **You should now see**:
   - 🔨 Ban User button (full width, orange)
   - 👢 Kick button + 🔇 Mute User button (side by side)
   - ⏰ Timeout User button (for moderators and super mods)

## Permissions Explained

- `ban_users` - Ban users from rooms (temporary or permanent)
- `kick_users` - Remove users from rooms (they can rejoin)
- `mute_users` - Mute specific user microphones
- `lock_microphones` - Lock all mics in a room
- `view_audit_logs` - See security audit trail
- `manage_super_moderators` - Grant/revoke super mod status
- `promote_super_moderators` - Add new super moderators
- `emergency_shutdown` - Emergency room shutdown

## Troubleshooting

### Buttons not showing?
- Make sure you're in a **Debates & Discussions room** (not Arena, not Open Discussion)
- Check console logs for super mod status check
- Restart the app after adding yourself

### Ban/Kick not working?
- Check that Appwrite functions are deployed: `appwrite functions list`
- Verify collections exist: `appwrite databases list-collections --database-id arena_db`
- Check function logs in Appwrite Console

### "User is not a super moderator" error?
- Verify you're in the `super_moderators` collection with `isActive: true`
- Check that `SuperModeratorService` is initialized
- Try restarting the app to reload the super mod cache

## Files Changed

- ✅ Deployed: `ban-user`, `kick-user`, `lock-microphones` functions
- ✅ Created: `super_moderators`, `room_bans`, `security_audit_log` collections
- No code changes needed - everything is already wired up!

## Next Steps

After adding yourself as super mod:
1. Test ban/kick/mute in a test room
2. Check audit logs in Appwrite Console → security_audit_log
3. Add other trusted users as super mods if needed
