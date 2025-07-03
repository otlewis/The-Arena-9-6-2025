# 🎙️ Agora Token Server Setup

This guide will help you set up a dynamic Agora token server using Appwrite Functions.

## Prerequisites

1. **Agora Account**: You need your App Certificate from Agora Console
2. **Appwrite Project**: Your existing Arena project on Appwrite

## Step 1: Get Your Agora App Certificate

1. Go to [Agora Console](https://console.agora.io/)
2. Navigate to your project with App ID: `3ccc264b24df4b5f91fa35741ea6e0b8`
3. Go to **Config** → **Features**
4. Enable **App Certificate** if not already enabled
5. Copy the **App Certificate** (you'll need this for the function)

## Step 2: Create Appwrite Function

1. Go to [Appwrite Console](https://console.appwrite.io/)
2. Navigate to your **Arena** project
3. Go to **Functions** in the left sidebar
4. Click **Create Function**

### Function Configuration:
- **Function ID**: `agora-token-generator`
- **Name**: `Agora Token Generator`
- **Runtime**: `Node.js 18.0`
- **Timeout**: `15` seconds
- **Execute Access**: `Users` (or `Any` if you want public access)

## Step 3: Upload Function Code

1. **Create a new folder** on your computer called `agora-token-function`
2. **Copy the files** from your project:
   - `agora_token_function.js`
   - `package.json`
3. **Zip the folder** (make sure the files are in the root of the zip, not in a subfolder)
4. **Upload the zip** to your Appwrite Function

## Step 4: Set Environment Variables

In your Appwrite Function settings, add these environment variables:

| Variable Name | Value |
|---------------|--------|
| `AGORA_APP_ID` | `3ccc264b24df4b5f91fa35741ea6e0b8` |
| `AGORA_APP_CERTIFICATE` | `[Your App Certificate from Step 1]` |

⚠️ **Important**: Keep your App Certificate secret and never commit it to code!

## Step 5: Deploy the Function

1. Click **Deploy** in your Appwrite Function
2. Wait for deployment to complete (usually 1-2 minutes)
3. Test the function using the **Execute** tab with this payload:

```json
{
  "channel": "arena",
  "uid": 0,
  "role": "publisher",
  "expireTime": 3600
}
```

Expected response:
```json
{
  "success": true,
  "data": {
    "token": "007eJx...",
    "appId": "3ccc264b24df4b5f91fa35741ea6e0b8",
    "channel": "arena",
    "uid": 0,
    "role": "publisher",
    "expiresAt": 1640995200,
    "expiresIn": 3600
  }
}
```

## Step 6: Update Function ID (if needed)

If you used a different Function ID than `agora-token-generator`, update it in:

**File**: `lib/services/agora_token_service.dart`
**Line**: Change `functionId: 'agora-token-generator'` to your actual function ID

## Step 7: Test the Integration

1. **Hot restart** your Flutter app
2. Try joining a voice channel in the arena
3. Check the console logs for:
   ```
   🎙️ Generating fresh Agora token for channel: arena
   ✅ Generated fresh Agora token (expires at: 1640995200)
   ✅ Successfully joined channel: arena with UID: 12345
   ```

## Benefits of Dynamic Tokens

✅ **Automatic Expiration**: Tokens refresh automatically  
✅ **Better Security**: No static tokens in your code  
✅ **Role-based**: Different tokens for publishers vs subscribers  
✅ **Caching**: Reduces unnecessary function calls  
✅ **Fallback**: Falls back to static token if function fails  

## Troubleshooting

### Function Execution Failed
- Check that the App Certificate is correct
- Verify the function has the required npm packages installed
- Check function logs in Appwrite Console

### Token Still Invalid
- Ensure the App ID matches your Agora project
- Verify the App Certificate is from the same Agora project
- Check that the channel name is exactly "arena"

### Network Issues
- The app falls back to static tokens automatically
- Check your internet connection
- Verify Appwrite Function permissions

## Security Notes

- App Certificate should never be exposed in client-side code
- Use Appwrite's environment variables for sensitive data
- Consider setting shorter token expiration times for better security
- Monitor function usage to detect unusual activity

## Cost Considerations

- Appwrite Functions: Free tier includes 750,000 function executions/month
- Token caching reduces function calls significantly
- Typical usage: ~10-50 function calls per user session 