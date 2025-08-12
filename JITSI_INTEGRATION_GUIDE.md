# Jitsi Meet Flutter Integration Guide

## Complete Implementation to Fix JavaScript Errors

### 1. Testing the Integration

To test the Jitsi integration in your Arena app:

```dart
// Add this to your home_screen.dart or any screen where you want to test
import 'screens/jitsi_main_screen.dart';

// Add a test button
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JitsiMainScreen(),
      ),
    );
  },
  child: const Text('Test Jitsi'),
),
```

### 2. Run the App

```bash
# For iOS
flutter run -d 00008101-001D65A91A50001E

# For Android
flutter run -d ZDZLOJCEJVDATSVG

# Or just
flutter run
```

### 3. Using the Simple Service in Your Existing Code

Replace your current Jitsi implementation with:

```dart
import 'package:arena/services/jitsi_simple_service.dart';

class YourScreen extends StatefulWidget {
  // ... your code
  
  final JitsiSimpleService _jitsiService = JitsiSimpleService();
  
  @override
  void initState() {
    super.initState();
    _jitsiService.initialize();
    
    // Set up callbacks
    _jitsiService.onConferenceJoined = (url) {
      setState(() {
        _isConnected = true;
      });
    };
    
    _jitsiService.onConferenceTerminated = (url, error) {
      setState(() {
        _isConnected = false;
        if (error != null) {
          _showError(error.toString());
        }
      });
    };
  }
  
  void _joinCall() async {
    await _jitsiService.joinMeeting(
      serverUrl: 'https://jitsi.dialecticlabs.com',
      roomName: 'Room${DateTime.now().millisecondsSinceEpoch}',
      displayName: 'Flutter User',
      audioOnly: false, // Set to true for audio-only
    );
  }
}
```

### 4. Server Configuration Fix

The JavaScript errors are happening because your server needs these fixes:

```bash
# SSH into your server
ssh root@172.236.109.9

# Create proper language files
mkdir -p /usr/share/jitsi-meet/lang
echo '{"en": "English"}' > /usr/share/jitsi-meet/lang/languages.json
echo '{"welcomepage": {"title": "Welcome"}}' > /usr/share/jitsi-meet/lang/main-en.json

# Fix the config to not reference interfaceConfig
nano /etc/jitsi/meet/jitsi.dialecticlabs.com-config.js
```

Remove any references to `interfaceConfig` from the config.js file.

### 5. Alternative: Use Public Jitsi Server

If your self-hosted server continues to have issues:

```dart
// In jitsi_simple_service.dart or your service file
await _jitsiService.joinMeeting(
  serverUrl: 'https://meet.jit.si', // Use public server
  roomName: 'ArenaRoom${DateTime.now().millisecondsSinceEpoch}',
  displayName: userName,
  audioOnly: false,
);
```

### 6. Debugging Connection Issues

Add logging to see what's happening:

```dart
// Enable verbose logging
JitsiMeetEventListener(
  conferenceJoined: (url) {
    print('✅ Joined: $url');
  },
  conferenceTerminated: (url, error) {
    print('❌ Terminated: $url, Error: $error');
  },
  conferenceWillJoin: (url) {
    print('🔄 Connecting to: $url');
  },
  audioMutedChanged: (muted) {
    print('🔇 Audio muted: $muted');
  },
  videoMutedChanged: (muted) {
    print('📹 Video muted: $muted');
  },
);
```

### 7. Common Issues and Solutions

**Issue: "interfaceConfig is not defined"**
- Solution: Use minimal configOverrides and featureFlags as shown in jitsi_simple_service.dart

**Issue: "You have been disconnected" loop**
- Check firewall: `ufw status`
- Ensure ports are open: 443/tcp, 4443/tcp, 10000/udp
- Check SSL certificate: `openssl s_client -connect jitsi.dialecticlabs.com:443`

**Issue: Black screen in browser**
- Missing language files (see step 4)
- JavaScript errors in config files

### 8. Testing Checklist

- [ ] Permissions granted (camera/microphone)
- [ ] Server accessible via browser
- [ ] No JavaScript errors in browser console
- [ ] Ports open on server (443, 4443, 10000)
- [ ] SSL certificate valid
- [ ] App can connect without lobby screen

## Quick Test

1. Run: `flutter run`
2. Navigate to Jitsi test screen
3. Click "Start Test"
4. Grant permissions if asked
5. Click "Join Call"
6. Should connect without errors

If it still doesn't work, temporarily use `https://meet.jit.si` as the server URL to verify the app code is working correctly.