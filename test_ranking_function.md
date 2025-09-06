# 🧪 Test Ranking Function

## Once deployment completes, run this test:

```bash
# Get your user ID first (replace with your actual user ID)
appwrite functions createExecution \
  --functionId ranking-sync \
  --body '{"action": "sync-user", "userId": "YOUR_USER_ID_HERE"}'
```

## To get your user ID:
1. Go to Appwrite Console
2. Navigate to Auth → Users  
3. Find your user and copy the ID
4. Or check your app logs when you login

## Expected Response:
```json
{
  "success": true,
  "message": "User ranking synced successfully",
  "data": {
    "userId": "your-user-id",
    "monthlyPoints": 0,
    "monthlyWins": 0,
    "monthlyLosses": 0,
    "tier": "bronze",
    "globalRank": 1
  }
}
```

## If successful:
✅ Your home screen should now show accurate stats
✅ Rankings screen should display proper leaderboard
✅ Points/rank sync is working!