# Manual Deployment Instructions for manage-coin-balance Function

The Appwrite CLI has issues with interactive prompts in this environment. Please follow these manual steps:

## ✅ Everything is Ready - Just Need Manual Upload

### Files Prepared:
- **Deployment Package**: `/Users/otislewis/arena2/manage-coin-balance-deployment.tar.gz` (2.3KB)
- **Function Code**: `/Users/otislewis/arena2/appwrite-functions/manage-coin-balance/`
- **Configuration**: Already added to `appwrite.json`

## Step-by-Step Deployment:

### Step 1: Open Appwrite Console
Go to: **https://cloud.appwrite.io/console/project-683a37a8003719978879/functions**

### Step 2: Create or Find the Function

**Option A: If "Manage Coin Balance" Already Exists**
1. Click on "Manage Coin Balance" in the functions list
2. Skip to Step 3

**Option B: If Function Doesn't Exist**
1. Click "+ Create function" button
2. Fill in:
   - **Name**: Manage Coin Balance
   - **Function ID**: `manage-coin-balance`
   - **Runtime**: Node.js 18.0
   - **Execute Access**: Users
   - **Timeout**: 15 seconds
3. Click "Create"
4. Go to "Settings" tab and add these scopes:
   - `documents.read`
   - `documents.write`
   - `databases.read`
   - `databases.write`
5. Save settings

### Step 3: Create Deployment
1. Click on "Deployments" tab
2. Click "+ Create deployment" button
3. Upload the deployment file:
   - Click "Manual" deployment
   - Upload: `/Users/otislewis/arena2/manage-coin-balance-deployment.tar.gz`
   - **Entrypoint**: `src/main.js`
   - **Commands**: `npm install`
4. Click "Create" and wait for build to complete (usually 1-2 minutes)

### Step 4: Activate Deployment
1. Once build shows "Ready", click the "Activate" button
2. The function is now live! ✅

### Step 5: Test the Function

1. In the function page, click "Execute" button
2. Use this test payload:

```json
{
  "operation": "GET",
  "userId": "683a3741002aac8c938b"
}
```

(Replace the userId with your actual user ID if needed)

3. Click "Execute"
4. You should get a response like:

```json
{
  "success": true,
  "operation": "GET",
  "userId": "683a3741002aac8c938b",
  "balance": 500,
  "timestamp": "2025-11-02T00:10:00.000Z"
}
```

## Verification

After deployment, verify the function works:

1. **Check Function Status**: Should show "Active" with a green dot
2. **Test Operations**:
   - GET: Check balance
   - DEDUCT: Try deducting 10 coins
   - ADD: Try adding coins back

### Test DEDUCT Operation:
```json
{
  "operation": "DEDUCT",
  "userId": "YOUR_USER_ID",
  "amount": 10
}
```

### Test ADD Operation:
```json
{
  "operation": "ADD",
  "userId": "YOUR_USER_ID",
  "amount": 10
}
```

## App Integration

Once deployed, your Flutter app will automatically use the function:

1. When users send gifts, the app calls the function
2. Coin deductions are handled server-side (atomic)
3. Real-time subscription updates the UI
4. No more balance reversion issues! ✅

## Troubleshooting

### Build Fails
- Check that Node.js 18 runtime is selected
- Verify entrypoint is `src/main.js`
- Ensure commands field has `npm install`

### Function Returns Error
- Check that all required scopes are added
- Verify the function is activated (not just deployed)
- Check function logs in the "Logs" tab

### Test Execution Fails
- Make sure you're using a valid userId from your users collection
- Check the JSON syntax is correct
- Look at execution logs for error details

## What Happens Next

After successful deployment:
- ✅ All coin operations go through the server function
- ✅ Atomic operations prevent race conditions
- ✅ Cache issues are eliminated
- ✅ Coin balance stays consistent
- ✅ Works in all room types (Arena, Debates & Discussions)

The fix is complete once deployed! 🎉
