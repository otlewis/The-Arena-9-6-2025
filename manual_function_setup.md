# Manual Agora Function Setup

Your Agora function needs to be in the **Arena Debate App** project (`683a37a8003719978879`) where your app data is located.

## Steps:

### 1. Go to the Correct Project
Visit: https://cloud.appwrite.io/console/project-683a37a8003719978879
(This is your "Arena Debate App" project where your collections are)

### 2. Create the Function
1. Go to **Functions** in the left sidebar
2. Click **Create Function**
3. Set these values:
   - **Function ID**: `agora-token-generator`
   - **Name**: `Agora Token Generator`
   - **Runtime**: `Node.js 18.0`
   - **Timeout**: `15` seconds
   - **Execute Access**: `Any` (or `Users` if you prefer)

### 3. Upload Function Code
1. Download the file: `agora-function-uid-fix.tar.gz` from your project folder
2. In the function settings, click **Deploy** tab
3. Upload the `agora-function-uid-fix.tar.gz` file
4. Set **Entry Point**: `src/main.js`
5. Click **Deploy**

### 4. Set Environment Variables
Go to **Variables** tab and add:
- **AGORA_APP_ID**: `3ccc264b24df4b5f91fa35741ea6e0b8`
- **AGORA_APP_CERTIFICATE**: `46c66fcc3173422fa582a36044d1ce89`

### 5. Test the Function
1. Go to **Execute** tab
2. Use this test payload:
```json
{
  "channelName": "arena",
  "uid": 0,
  "role": "subscriber"
}
```
3. Click **Execute**
4. You should get a response with `"success": true` and a token

### 6. Revert App to Use Function
Once the function is working, we'll change the app back to use the function instead of the static token.

## Why This is Needed
- Your app connects to project `683a37a8003719978879` 
- But your Agora function was in project `683a6bab000562231eeb`
- Functions can only be called within the same project

After setup, your audio should work perfectly! 🎙️ 