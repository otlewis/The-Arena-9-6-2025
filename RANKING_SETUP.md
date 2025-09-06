# 🎮 Gamified Ranking System Setup Guide

## Quick Appwrite Setup (5 minutes)

### **Step 1: Create Collections**

Go to your Appwrite Console → arena_db database and create these 3 collections:

#### **Collection 1: "monthly_rankings"**
```
Collection ID: monthly_rankings
```
**Attributes to add:**
- `userId` (String, required, 128 chars)
- `monthKey` (String, required, 8 chars) 
- `monthlyPoints` (Integer, required, default: 0)
- `monthlyWins` (Integer, required, default: 0)
- `monthlyLosses` (Integer, required, default: 0)
- `currentWinStreak` (Integer, required, default: 0)
- `bestWinStreak` (Integer, required, default: 0)
- `activityXP` (Integer, required, default: 0)
- `tier` (String, required, default: "bronze", 16 chars)
- `globalRank` (Integer, required, default: 0)
- `lastUpdated` (String, required, 64 chars)

#### **Collection 2: "achievements"**
```
Collection ID: achievements
```
**Attributes to add:**
- `userId` (String, required, 128 chars)
- `achievementId` (String, required, 64 chars)
- `title` (String, required, 128 chars)
- `description` (String, required, 256 chars)
- `category` (String, required, 32 chars)
- `rarity` (String, required, default: "common", 16 chars)
- `isUnlocked` (Boolean, required, default: false)
- `unlockedAt` (String, optional, 64 chars)

#### **Collection 3: "ranking_history"**
```
Collection ID: ranking_history
```
**Attributes to add:**
- `userId` (String, required, 128 chars)
- `monthKey` (String, required, 8 chars)
- `finalRank` (Integer, required)
- `finalPoints` (Integer, required)
- `finalTier` (String, required, 16 chars)
- `premiumAwarded` (Boolean, required, default: false)
- `archivedAt` (String, required, 64 chars)

### **Step 2: Set Permissions**
For each collection, click on Settings → Permissions and add:
- **Read**: Select "Any" (so all users can read rankings)
- **Create**: Select "Users" (so the app can create records)
- **Update**: Select "Users" (so the app can update records)
- **Delete**: Leave empty (recommended - prevents accidental data deletion)

### **Step 3: Test the System**
1. Run the app
2. Go to Rankings from the home screen
3. You should see the rankings card (will show mock data initially)
4. After users start debating, real data will populate

## **What Happens Next?**

### **Automatic User Enrollment**
- New users get initialized with 100% reputation and 0 points
- Existing users will be added to rankings when they first participate

### **Point Scoring**
- **Win**: 100 base points + bonuses for streaks/opponent tier
- **Loss**: 10 participation points
- **Activities**: XP for room creation, gifts, daily login

### **Monthly Cycle**
- Rankings reset every month
- Top performer gets 1 month free premium
- Previous month data is archived

### **Tier Progression**
- 🥉 Bronze: 0-499 points
- 🥈 Silver: 500-1499 points  
- 🥇 Gold: 1500-3499 points
- 💎 Platinum: 3500-7499 points
- 💠 Diamond: 7500+ points

## **Optional: Initialize Existing Users**

If you want to initialize rankings for existing users right away, you can run this Dart script:

```bash
cd /Users/otislewis/arena2
dart run lib/setup/gamified_ranking_migration.dart
```

## **That's It! 🎉**

The ranking system will start working immediately once the collections are created. Users will see their rankings update in real-time as they participate in debates!