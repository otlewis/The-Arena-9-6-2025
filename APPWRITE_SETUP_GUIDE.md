# 🚀 Appwrite Timer System Setup Guide

Complete step-by-step guide to set up the synchronized timer system in your Appwrite project.

## 📋 Prerequisites

- Appwrite project already created and configured
- Appwrite CLI installed (optional but recommended)
- Your existing Flutter app with Appwrite integration

## 🗄️ Step 1: Create Database Collections

### Using Appwrite Console (Recommended)

1. **Go to your Appwrite Console** → Your Project → Databases → Your Database

2. **Create `timers` Collection:**
   - Click "Create Collection"
   - **Collection ID**: `timers`
   - **Name**: `Timers`

3. **Add Attributes to `timers` collection:**

   Click "Create Attribute" for each:

   **String Attributes:**
   - `roomId` (Size: 100, Required: ✓)
   - `createdBy` (Size: 100, Required: ✓)
   - `currentSpeaker` (Size: 100, Required: ✗)
   - `title` (Size: 200, Required: ✗)

   **Enum Attributes:**
   - `roomType` (Elements: `openDiscussion,debatesDiscussions,arena`, Required: ✓)
   - `timerType` (Elements: `general,openingStatement,rebuttal,closingStatement,questionRound,speakerTurn`, Required: ✓)
   - `status` (Elements: `stopped,running,paused,completed`, Required: ✓)

   **Integer Attributes:**
   - `durationSeconds` (Required: ✓)
   - `remainingSeconds` (Required: ✓)

   **DateTime Attributes:**
   - `startTime` (Required: ✗)
   - `pausedAt` (Required: ✗)
   - `endTime` (Required: ✗)
   - `lastTick` (Required: ✗)

   **Boolean Attributes:**
   - `isActive` (Required: ✓, Default: false)

   **JSON Attributes:**
   - `config` (Required: ✗)

4. **Create Indexes for `timers` collection:**
   
   Go to Indexes tab and create:
   - **Index 1**: Key: `roomId_status`, Type: `key`, Attributes: `roomId` (ASC), `status` (ASC)
   - **Index 2**: Key: `roomId_isActive`, Type: `key`, Attributes: `roomId` (ASC), `isActive` (DESC)
   - **Index 3**: Key: `createdBy`, Type: `key`, Attributes: `createdBy` (ASC)

5. **Set Permissions for `timers` collection:**
   - **Create**: `users`
   - **Read**: `users` 
   - **Update**: `users`
   - **Delete**: `users`

6. **Create `timer_events` Collection:**
   - Click "Create Collection"
   - **Collection ID**: `timer_events`
   - **Name**: `Timer Events`

7. **Add Attributes to `timer_events` collection:**

   **String Attributes:**
   - `timerId` (Size: 100, Required: ✓)
   - `roomId` (Size: 100, Required: ✓)
   - `userId` (Size: 100, Required: ✓)
   - `details` (Size: 500, Required: ✗)

   **Enum Attributes:**
   - `action` (Elements: `created,started,paused,resumed,stopped,reset,completed,time_added`, Required: ✓)

   **DateTime Attributes:**
   - `timestamp` (Required: ✓)

   **JSON Attributes:**
   - `previousState` (Required: ✗)
   - `newState` (Required: ✗)
   - `metadata` (Required: ✗)

8. **Create Indexes for `timer_events` collection:**
   - **Index 1**: Key: `timerId_timestamp`, Type: `key`, Attributes: `timerId` (ASC), `timestamp` (DESC)
   - **Index 2**: Key: `roomId_timestamp`, Type: `key`, Attributes: `roomId` (ASC), `timestamp` (DESC)

9. **Set Permissions for `timer_events` collection:**
   - **Create**: `users`
   - **Read**: `users`
   - **Update**: (empty - no updates allowed)
   - **Delete**: (empty - no deletions allowed)

## 🔧 Step 2: Create API Key

1. Go to **Settings** → **API Keys**
2. Click **"Create API Key"**
3. **Name**: `Timer Functions Key`
4. **Scopes**: Select ALL scopes (or at minimum):
   - `databases.read`
   - `databases.write`
   - `functions.read`
   - `functions.write`
5. **Copy the API Key** - you'll need this for the functions

## ⚡ Step 3: Create Appwrite Functions

### Method A: Using Appwrite Console (Easier)

1. **Go to Functions** → **Create Function**

2. **Create Timer Controller Function:**
   - **Function ID**: `timer-controller`
   - **Name**: `Timer Controller`
   - **Runtime**: `Node.js 18.0`
   - **Entrypoint**: `src/main.js`
   - **Commands**: (leave empty)

3. **Set Environment Variables for timer-controller:**
   - Click on your function → **Settings** → **Environment Variables**
   - Add: `APPWRITE_DATABASE_ID` = `your_database_id` (find this in Database settings)

4. **Upload Function Code:**
   - Create a zip file from `appwrite/functions/timer-controller/`
   - Include: `src/main.js`, `package.json`
   - Go to **Deployments** → **Create Deployment** → Upload zip
   - Click **Activate** when deployment completes

5. **Set Function Permissions:**
   - Go to **Settings** → **Execute Access**
   - Add: `users` (any authenticated user can execute)

6. **Create Timer Ticker Function:**
   - **Function ID**: `timer-ticker`
   - **Name**: `Timer Ticker`
   - **Runtime**: `Node.js 18.0`
   - **Entrypoint**: `src/main.js`

7. **Set Environment Variables for timer-ticker:**
   - `APPWRITE_DATABASE_ID` = `your_database_id`
   - `TIMER_CONTROLLER_FUNCTION_ID` = `timer-controller`

8. **Upload Timer Ticker Code:**
   - Create zip from `appwrite/functions/timer-ticker/`
   - Deploy and activate

9. **Schedule Timer Ticker:**
   - Go to timer-ticker function → **Executions**
   - Click **"Execute now"** → **"Schedule"**
   - **Schedule**: `* * * * * *` (every second)
   - **Method**: `POST`
   - **Path**: `/tick`
   - **Headers**: `{"Content-Type": "application/json"}`
   - **Body**: `{}`
   - Click **"Schedule Execution"**

### Method B: Using Appwrite CLI (Advanced)

```bash
# Install Appwrite CLI
npm install -g appwrite-cli

# Login to your Appwrite project
appwrite login
appwrite init project

# Create timer-controller function
appwrite functions create \
  --functionId timer-controller \
  --name "Timer Controller" \
  --runtime node-18.0 \
  --execute users

# Deploy timer-controller
cd appwrite/functions/timer-controller
appwrite functions createDeployment \
  --functionId timer-controller \
  --code . \
  --activate true

# Create timer-ticker function
appwrite functions create \
  --functionId timer-ticker \
  --name "Timer Ticker" \
  --runtime node-18.0 \
  --execute admin

# Deploy timer-ticker
cd ../timer-ticker
appwrite functions createDeployment \
  --functionId timer-ticker \
  --code . \
  --activate true

# Schedule timer-ticker (every second)
appwrite functions createExecution \
  --functionId timer-ticker \
  --body '{}' \
  --async false \
  --path '/tick' \
  --method POST \
  --headers '{"Content-Type": "application/json"}'
```

## 🧪 Step 4: Test the Setup

### Test Functions in Console

1. **Test Timer Controller:**
   - Go to Functions → timer-controller → Executions
   - Click **"Execute now"**
   - **Body**:
   ```json
   {
     "action": "create",
     "data": {
       "roomId": "test-room",
       "roomType": "openDiscussion",
       "timerType": "general",
       "durationSeconds": 300,
       "createdBy": "test-user"
     }
   }
   ```
   - Should return success with timer data

2. **Test Timer Ticker:**
   - Go to Functions → timer-ticker → Executions
   - Click **"Execute now"**
   - **Body**: `{}`
   - Should return success with update counts

### Verify Database

1. Go to **Databases** → **timers** collection
2. You should see a test timer created
3. Check **timer_events** collection for logged events

## 📱 Step 5: Update Flutter App

### Add Timer Test Screen

Add this to your Flutter app navigation:

```dart
// In your main navigation (drawer, bottom nav, etc.)
ListTile(
  leading: Icon(Icons.timer),
  title: Text('Timer Test'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppwriteTimerTestScreen(),
      ),
    );
  },
),
```

### Initialize Offline Service

In your `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize your existing Appwrite
  // ... your existing initialization
  
  // Initialize timer offline service
  try {
    await AppwriteOfflineService().initialize();
  } catch (e) {
    print('Timer offline service init failed: $e');
  }
  
  runApp(MyApp());
}
```

## 🔍 Step 6: Verify Multi-Device Sync

1. **Open Timer Test Screen** on your phone/emulator
2. **Open same screen** in web browser or another device
3. **Start a timer** on one device
4. **Watch both devices** update in real-time with perfect sync
5. **Test offline** by disconnecting internet on one device

## 🚨 Troubleshooting

### Functions Not Working
```bash
# Check function logs in Appwrite Console
Functions → timer-controller → Executions → View logs

# Common issues:
- Missing environment variables
- Wrong database ID
- API key permissions
- Runtime errors in function code
```

### Database Permissions
```bash
# Verify permissions in Console:
Databases → timers → Settings → Permissions
Should show: users for create/read/update/delete
```

### Timer Not Syncing
```bash
# Check if ticker is running:
Functions → timer-ticker → Executions
Should show executions every second

# Check realtime subscriptions:
Enable realtime in your Appwrite project settings
```

## 📊 Monitor Performance

### Check Function Performance
- Functions should execute in < 1000ms
- Timer ticker should handle 50+ concurrent timers
- Monitor execution logs for errors

### Database Performance
- Queries should return in < 100ms
- Monitor index usage in slow queries
- Check connection limits

## 🎯 Next Steps

1. **Test thoroughly** with the test screen
2. **Replace existing timers** in your app with `AppwriteTimerWidget`
3. **Add sync indicators** to show connection status
4. **Monitor function logs** for any issues
5. **Scale test** with multiple concurrent timers

## 📞 Support

If you encounter issues:

1. **Check function logs** in Appwrite Console
2. **Verify database permissions** and indexes
3. **Test with Timer Test Screen** first
4. **Monitor network connectivity** in app

Your Appwrite Timer System is now ready for perfect multi-device synchronization! 🚀

---

**Important Notes:**
- Timer ticker runs every second - monitor function usage
- Each room limited to 1 concurrent timer (configurable)
- Functions automatically clean up old timers after 24 hours
- All timer logic is server-controlled for perfect sync