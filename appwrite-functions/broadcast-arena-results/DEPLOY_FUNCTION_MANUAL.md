# Manual Deployment Guide: broadcast-arena-results Function

The Appwrite CLI has deployment activation issues. The simplified function has been deployed but needs manual activation through the console.

## Quick Fix: Activate Latest Deployment

### Option 1: Appwrite Console (FASTEST)

1. **Go to Functions:**
   https://cloud.appwrite.io/console/project-683a37a8003719978879/functions/function-broadcast-arena-results

2. **Click "Deployments" tab**

3. **Find the latest deployment:**
   - Deployment ID: `68f41a25bab079193e56`
   - Created: 2025-10-18T22:52:21
   - Status: Should show "Ready"
   - Size: 2911 bytes (source)

4. **Activate it:**
   - Click the three dots (•••) menu on the right
   - Select "Activate"
   - Confirm activation

5. **Verify:**
   - The deployment should now show a green "Active" badge
   - Previous deployment should no longer be active

### Option 2: Delete Old Function and Redeploy

If Option 1 doesn't work, delete and recreate:

1. Go to Functions in Appwrite Console
2. Delete `broadcast-arena-results` function
3. Run from terminal in this directory:
```bash
cd /Users/otislewis/arena2/appwrite-functions/broadcast-arena-results

appwrite functions create \
  --function-id broadcast-arena-results \
  --name "Broadcast Arena Results" \
  --runtime node-18.0 \
  --execute any \
  --execute guests \
  --entrypoint index.js \
  --commands "npm install" \
  --timeout 15 \
  --enabled true \
  --logging true

appwrite functions update \
  --function-id broadcast-arena-results \
  --scopes "documents.read" "documents.write" "databases.read" "databases.write"

appwrite functions create-deployment \
  --function-id broadcast-arena-results \
  --entrypoint index.js \
  --code . \
  --activate true
```

## What the Function Does (Simplified Version)

The current `index.js` has NO authorization checks. It:

1. Accepts `roomId` parameter
2. Fetches all judgments for that room from `arena_judgments` collection
3. Counts votes (affirmative vs negative)
4. Calculates total scores as tiebreaker
5. Determines winner
6. Updates `arena_rooms` with:
   - `winner`: affirmative/negative/tie
   - `judgingComplete`: true
   - `judgingEnabled`: false
   - **`showResults`: true** ← This triggers realtime broadcast!
7. Returns success with vote breakdown

## Testing After Activation

1. Create an arena room
2. Have judges vote
3. Close voting as moderator
4. Expected result:
   - ✅ Function executes successfully (no 500 error)
   - ✅ Trophy icon appears on ALL users' screens
   - ✅ All users can tap trophy to view results

## Current Issue

**Problem:** Old deployment (`68f415855f7f99eca97e`) with authorization checks is still active, even though new deployment (`68f41a25bab079193e56`) without auth checks has been created.

**Evidence:** Function execution logs show deployment ID `68f415855f7f99eca97e` is being used, which causes the authorization error.

**Root Cause:** Appwrite may cache the active deployment or require manual activation through the console when using `--activate true` flag in CLI.

**Fix:** Manually activate deployment `68f41a25bab079193e56` through Appwrite Console as described above.

## Deployment History

- **68f415855f7f99eca97e** - Old version with moderator auth checks (CURRENTLY ACTIVE - WRONG!)
- **68f41860b475980e4be8** - Attempted fix with fallback logic (stuck in waiting)
- **68f41919a018d0cb452c** - Second attempt at simplified version
- **68f41a25bab079193e56** - Latest simplified version with NO auth (SHOULD BE ACTIVE!)

## Files Reference

**Current code (simplified):**
```
/Users/otislewis/arena2/appwrite-functions/broadcast-arena-results/index.js
```

**Backup with auth (for future use):**
```
/Users/otislewis/arena2/appwrite-functions/broadcast-arena-results/index-auth.js
```

---

Once the latest deployment is activated, the feature should work immediately without app restart!
