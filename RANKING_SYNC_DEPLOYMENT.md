# 🚀 Ranking Sync Function Deployment Guide

## Quick Setup (5 minutes)

### **Step 1: Deploy the Function**

1. **Navigate to main project directory:**
```bash
cd /Users/otislewis/arena2
```

2. **Deploy to Appwrite using new CLI:**
```bash
appwrite push functions
```

Or deploy everything:
```bash
appwrite push
```

**If you get permission errors, login first:**
```bash
appwrite login
```

**Alternative manual method:**
```bash
# Create function manually in Appwrite Console
# Then upload the code from functions/ranking-sync/ directory
# Set runtime to node-18.0
# Set entrypoint to src/main.js
# Enable logging and set timeout to 30 seconds
```

### **Step 2: Test the Function**

1. **Test single user sync:**
```bash
appwrite functions createExecution \
  --functionId ranking-sync \
  --body '{"action": "sync-user", "userId": "YOUR_USER_ID"}'
```

2. **Test from Flutter app:**
```dart
final syncService = RankingSyncService();
syncService.initialize();
final result = await syncService.syncUserRanking(userId);
```

### **Step 3: Verify Results**

Check your Appwrite console:
- Go to **Databases** → **arena_db** → **monthly_rankings**
- You should see accurate points, ranks, and tiers

## 🛠️ Function Capabilities

### **Available Actions:**

1. **`sync-user`** - Sync single user
```json
{
  "action": "sync-user",
  "userId": "user123"
}
```

2. **`sync-all`** - Sync all users (admin)
```json
{
  "action": "sync-all"
}
```

3. **`sync-multiple`** - Sync specific users
```json
{
  "action": "sync-multiple",
  "userIds": ["user1", "user2", "user3"]
}
```

4. **`recalculate-ranks`** - Update global ranks only
```json
{
  "action": "recalculate-ranks"
}
```

## 🎯 What This Fixes

### **Accurate Calculations:**
- ✅ **Points**: WIN_BASE_POINTS (100) × wins + LOSS_PARTICIPATION_POINTS (10) × losses
- ✅ **Streak Bonuses**: 2x, 3x, 5x, 10x multipliers for consecutive wins
- ✅ **Tiers**: Bronze (0+), Silver (500+), Gold (1500+), Platinum (3500+), Diamond (7500+)
- ✅ **Global Ranks**: Properly sorted by monthly points

### **Real-time Sync:**
- ✅ **Home Screen**: Now shows accurate current stats
- ✅ **Rankings Screen**: Displays correct leaderboard
- ✅ **Auto-enrollment**: Creates records for new users
- ✅ **Monthly Reset**: Handles month transitions properly

## 🔧 Troubleshooting

### **Function Not Working:**
1. Check Appwrite Console → Functions → ranking-sync → Executions
2. Look for error logs
3. Verify permissions (databases.read, databases.write)

### **Data Still Wrong:**
1. Run full sync: `{"action": "sync-all"}`
2. Check if arena_participants collection has correct data
3. Verify month key format (YYYY-MM)

### **Performance Issues:**
1. Function timeout is set to 30 seconds
2. For large user bases, use `sync-multiple` with batches
3. Use `recalculate-ranks` for rank-only updates (faster)

## 📈 Next Steps

1. **Deploy the function** ✅
2. **Test with your user** ✅
3. **Run full sync if needed** (optional)
4. **Verify home screen shows correct data** ✅

The ranking system will now be bulletproof and accurate! 🎉