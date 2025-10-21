# Set Environment Variables for assign-arena-role Function

## IMPORTANT: Set These in Appwrite Console

Go to: https://cloud.appwrite.io/console/project-[YOUR_PROJECT]/functions/assign-arena-role/settings

### Required Environment Variables:

1. **APPWRITE_API_KEY**
   - Value: Get from Appwrite Console → Settings → API Keys
   - Create a new API key with these scopes:
     - `databases.read`
     - `databases.write`
   - Example: `standard_abc123...`

2. **LIVEKIT_HOST**
   - Value: Your LiveKit server URL
   - Example: `https://arena-dtd-y1kl8azy.livekit.cloud`
   - Or from memory: `34.171.185.205` (add https:// prefix)

3. **LIVEKIT_API_KEY**
   - Value: Your LiveKit API key
   - Get from LiveKit Cloud dashboard
   - Example: `APIabc123...`

4. **LIVEKIT_API_SECRET**
   - Value: Your LiveKit API secret
   - Get from LiveKit Cloud dashboard
   - Example: `secret123...`

## Steps to Set Variables:

1. Open Appwrite Console
2. Navigate to Functions → assign-arena-role
3. Click "Settings" tab
4. Scroll to "Environment Variables"
5. Click "Add Variable" for each of the 4 variables above
6. Save after adding all variables
7. Function will automatically restart with new variables

## After Setting Variables:

The function is ready to use! Test it with a sample execution.

## Function Status:

✅ Function created
✅ Deployment ready (status: ready)
✅ Build completed successfully
⏳ Waiting for environment variables to be set

## Next: Manual Step Required

**You need to set these variables manually in the Appwrite Console web interface.**

The Appwrite CLI doesn't support setting environment variables yet, so this must be done through the web UI.
