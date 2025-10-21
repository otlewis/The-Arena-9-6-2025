# Manual Deployment Guide: broadcast-arena-results Function

The Appwrite CLI has interactive prompt issues, and the API key doesn't have `functions.write` scope, so we'll deploy manually through the Appwrite Console.

## Step-by-Step Instructions

### 1. Open Appwrite Console
Go to: https://cloud.appwrite.io/console/project-683a37a8003719978879/functions

### 2. Create New Function
Click the **"Create function"** button (top right)

### 3. Fill in Function Details

**Template:** Select "Blank Function" or "Custom"

**Function ID:**
```
broadcast-arena-results
```
⚠️ **IMPORTANT:** Must match exactly (the Flutter app is looking for this ID)

**Name:**
```
Broadcast Arena Results
```

**Runtime:**
```
Node.js 18
```
(Select from dropdown)

**Entrypoint:**
```
index.js
```

**Build Commands:**
```
npm install
```

**Execute permissions:**
- Click "Add Role"
- Select "Any" → "Any authenticated user"
- Or manually add: `users`

**Timeout:**
```
15
```
(seconds)

**Enable:**
- ✅ Check "Enabled"
- ✅ Check "Enable logging"

Click **"Create"** button

### 4. Configure Scopes

After the function is created:

1. Go to the **"Settings"** tab
2. Scroll down to **"Scopes"** section
3. Click **"Add scope"** and add each of these:
   - `documents.read`
   - `documents.write`
   - `databases.read`
   - `databases.write`
4. Click **"Update"** to save

### 5. Deploy the Code

1. Go to the **"Deployments"** tab
2. Click **"Create deployment"** button
3. **Manual deployment** (recommended):
   - Select "Manual"
   - Click **"Choose File"** or drag and drop
   - Upload the file: **`broadcast-arena-results-deployment.tar.gz`**
   - Location: `/Users/otislewis/arena2/broadcast-arena-results-deployment.tar.gz`
4. Click **"Create"**

### 6. Wait for Build

- Watch the deployment status
- It should show "Building..." then "Ready"
- This usually takes 1-2 minutes
- Check the **"Build logs"** if there are any errors

### 7. Verify Deployment

Once the deployment shows **"Ready"** status:

1. Go to the **"Executions"** tab
2. You should see "No executions yet" (this is normal)
3. The function is now ready to be called from the app

## Testing

After deploying:

1. **Open your Flutter app**
2. **Create an arena room** (as moderator)
3. **Have 3 judges join and vote**
4. **Close voting** as moderator
5. **Expected behavior:**
   - Moderator sees: "✅ Results broadcast successfully!"
   - Trophy icon appears on ALL users' screens
   - Check function logs in Appwrite Console → Executions tab

## Troubleshooting

### Build Failed
- Check "Build logs" in the deployment
- Verify `package.json` is correct
- Verify `index.js` has no syntax errors

### Function Not Found (when calling from app)
- Verify Function ID is exactly: `broadcast-arena-results`
- Verify function is "Enabled" in Settings
- Verify deployment status is "Ready"

### Unauthorized Error
- Verify "Execute permissions" includes `users`
- Verify scopes include all 4 database permissions
- Verify user is logged in (has valid session)

### No votes submitted error
- Ensure at least one judge has voted before closing voting
- Check `arena_judgments` collection has documents for the room

## Files Reference

**Deployment Package:**
```
/Users/otislewis/arena2/broadcast-arena-results-deployment.tar.gz
```

**Source Code:**
```
/Users/otislewis/arena2/appwrite-functions/broadcast-arena-results/index.js
/Users/otislewis/arena2/appwrite-functions/broadcast-arena-results/package.json
```

**Flutter Integration:**
```
/Users/otislewis/arena2/lib/screens/arena_screen.dart
Line ~3085: _appwrite.functions.createExecution(functionId: 'broadcast-arena-results', ...)
```

## Quick Check

After deployment, you can test the function directly in Appwrite Console:

1. Go to function → **"Execute"** tab
2. Enter test body:
   ```json
   {
     "roomId": "arena_xxxxx"
   }
   ```
   (Replace with a real room ID that has votes)
3. Click **"Execute"**
4. Check the response and logs

---

✅ Once deployed, the function will automatically broadcast results to all users when the moderator closes voting!
