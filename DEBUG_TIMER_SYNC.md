# 🐛 Timer Sync Debugging Guide

The timer isn't showing on other users' screens. Let's debug this step by step.

## 🔍 Step 1: Check Appwrite Functions Are Working

### Test Timer Controller Function:

1. **Go to Appwrite Console** → Functions → timer-controller → Executions
2. **Click "Execute now"**
3. **Use this exact test payload:**

```json
{
  "action": "create",
  "data": {
    "roomId": "debug-room-123",
    "roomType": "openDiscussion",
    "timerType": "general",
    "durationSeconds": 300,
    "createdBy": "debug-user"
  }
}
```

4. **Check the response** - should show `"success": true`
5. **Go to Database** → timers collection → should see a new timer document

### Test Timer Ticker Function:

1. **Go to** Functions → timer-ticker → Executions
2. **Click "Execute now"**
3. **Use empty payload:** `{}`
4. **Check response** - should show update counts

**❌ If functions fail:** Check environment variables and API key permissions

## 🔍 Step 2: Check Database Permissions

### Verify Collection Permissions:

1. **Go to** Databases → timers → Settings → Permissions
2. **Should show:**
   - Create: `users`
   - Read: `users` 
   - Update: `users`
   - Delete: `users`

3. **Go to** Databases → timer_events → Settings → Permissions
4. **Should show:**
   - Create: `users`
   - Read: `users`
   - Update: (empty)
   - Delete: (empty)

**❌ If wrong:** Fix permissions in Appwrite Console

## 🔍 Step 3: Check Realtime Subscriptions

### Test Realtime in Browser Console:

1. **Open your Flutter app in web browser**
2. **Open browser developer tools** (F12)
3. **Go to Console tab**
4. **Look for error messages** about WebSocket connections

### Common Realtime Issues:

- **Firewall blocking WebSocket connections**
- **Appwrite project doesn't have Realtime enabled**
- **Incorrect subscription channel format**

## 🔍 Step 4: Check Flutter App Integration

### Add Debug Logging to AppwriteTimerService:

Add this to your `AppwriteTimerService._subscribeToRoomTimers` method:

```dart
void _subscribeToRoomTimers(String roomId, StreamController<List<TimerState>> controller) {
  final channel = 'databases.${AppwriteConstants.databaseId}.collections.timers.documents';
  
  // ADD THIS DEBUG LINE
  print('🔍 DEBUG: Subscribing to channel: $channel for room: $roomId');
  
  try {
    final subscription = _appwriteService.realtime.subscribe([channel]);
    
    subscription.stream.listen((response) {
      // ADD THIS DEBUG LINE
      print('🔍 DEBUG: Received realtime update: ${response.events}');
      print('🔍 DEBUG: Payload: ${response.payload}');
      
      try {
        _loadRoomTimers(roomId, controller);
      } catch (e) {
        print('🔍 DEBUG: Error processing update: $e');
        controller.addError(e);
      }
    }, onError: (error) {
      // ADD THIS DEBUG LINE
      print('🔍 DEBUG: Realtime subscription error: $error');
      controller.addError(error);
    });
    
    // REST OF CODE...
  } catch (e) {
    print('🔍 DEBUG: Failed to subscribe: $e');
    controller.addError(e);
  }
}
```

### Check Your Database ID:

In `AppwriteTimerService`, verify you're using the correct database ID:

```dart
// Make sure this matches your actual Appwrite database ID
await _appwriteService.databases.getDocument(
  databaseId: 'YOUR_ACTUAL_DATABASE_ID', // ← Check this!
  collectionId: _timersCollectionId,
  documentId: timerId,
);
```

## 🔍 Step 5: Quick Sync Test

### Create a Simple Test Function:

Add this test method to your `AppwriteTimerTestScreen`:

```dart
Future<void> _testDirectDatabaseAccess() async {
  try {
    print('🔍 Testing direct database access...');
    
    // Test 1: List all timers
    final response = await AppwriteService().databases.listDocuments(
      databaseId: AppwriteConstants.databaseId, // Your actual DB ID
      collectionId: 'timers',
    );
    
    print('🔍 Found ${response.documents.length} timers in database');
    for (final doc in response.documents) {
      print('🔍 Timer: ${doc.data}');
    }
    
    // Test 2: Create a timer directly
    final newTimer = await AppwriteService().databases.createDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: 'timers',
      documentId: ID.unique(),
      data: {
        'roomId': 'test-sync-room',
        'roomType': 'openDiscussion',
        'timerType': 'general',
        'status': 'stopped',
        'durationSeconds': 60,
        'remainingSeconds': 60,
        'createdBy': 'test-user',
        'isActive': false,
        'lastTick': DateTime.now().toIso8601String(),
      },
    );
    
    print('🔍 Created timer: ${newTimer.data}');
    
  } catch (e) {
    print('🔍 Database test failed: $e');
  }
}
```

Call this in your test screen and check the console output.

## 🔍 Step 6: Check Common Issues

### Issue 1: Wrong Database ID
```dart
// In your constants file, make sure this is correct:
class AppwriteConstants {
  static const String databaseId = 'your_actual_database_id'; // ← Check this
}
```

### Issue 2: Timer Ticker Not Running
1. Go to Functions → timer-ticker → Executions
2. Should see executions every second
3. If not, re-create the schedule: `* * * * * *`

### Issue 3: Authentication Issues
```dart
// Make sure users are authenticated before creating timers
final user = await AppwriteService().account.get();
print('Current user: ${user.$id}');
```

### Issue 4: Realtime Channel Format
The realtime channel should be:
```dart
'databases.${databaseId}.collections.timers.documents'
```

NOT:
```dart
'databases.collections.timers.documents' // Missing database ID
```

## 🚀 Quick Fix Test

### Try This Simplified Test:

1. **Open your app on Device 1**
2. **Run this test function** (add to your test screen):

```dart
Future<void> _simpleTimerTest() async {
  try {
    // Create timer via function
    final response = await AppwriteService().functions.createExecution(
      functionId: 'timer-controller',
      body: jsonEncode({
        'action': 'create',
        'data': {
          'roomId': 'simple-test-room',
          'roomType': 'openDiscussion',
          'timerType': 'general',
          'durationSeconds': 120,
          'createdBy': 'test-user-1',
        }
      }),
    );
    
    print('Function response: ${response.responseBody}');
    
    // Check if timer appears in database
    await Future.delayed(Duration(seconds: 2));
    
    final timers = await AppwriteService().databases.listDocuments(
      databaseId: AppwriteConstants.databaseId,
      collectionId: 'timers',
      queries: [
        Query.equal('roomId', 'simple-test-room'),
      ],
    );
    
    print('Timers found: ${timers.documents.length}');
    
  } catch (e) {
    print('Simple test failed: $e');
  }
}
```

3. **Open your app on Device 2**
4. **Check if the timer appears**

## 💡 Most Likely Issues:

1. **Database ID mismatch** in Flutter constants vs Appwrite
2. **Timer ticker not scheduled** properly (not running every second)
3. **Realtime subscriptions not working** due to network/firewall
4. **Collection permissions** not set to `users`
5. **Authentication** - users not properly authenticated

Let me know what the debug output shows and I'll help you fix the specific issue!