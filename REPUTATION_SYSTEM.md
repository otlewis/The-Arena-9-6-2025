# Arena Reputation System

## Overview
The reputation system rewards users for positive engagement and good behavior in Arena debates and discussions.

## Point Values

### Debate Performance
- **Debate Win**: +100 points (base)
  - +25 bonus for exceptional performance (90+ judge score)
  - +15 bonus for great performance (80+ judge score)  
  - +10 bonus for good performance (70+ judge score)
- **Debate Loss**: -25 points (base)
  - -10 for close loss (60+ judge score)
  - -15 for medium loss (40-60 judge score)
  - -25 for poor performance (below 40 score)
- **Debate Participation**: +10 points (regardless of outcome)

### Community Engagement
- **Room Creation**: +15 points
- **Daily Login**: +1 point (once per day)
- **Gift Received**: +1-20 points (scaled by gift value)
- **Gift Sent**: +1-10 points (scaled by gift value)

### Role Performance
- **Excellent Judge Performance** (4.5+ stars): +75 points
- **Good Judge Performance** (4.0+ stars): +50 points
- **Fair Judge Performance** (3.5+ stars): +25 points
- **Excellent Moderator Performance** (4.5+ stars): +50 points
- **Good Moderator Performance** (4.0+ stars): +30 points
- **Fair Moderator Performance** (3.5+ stars): +15 points

### Penalties
- **Bad Behavior**: -50 points
- **Spam**: -25 points  
- **Abandon Debate**: -30 points

## Required Appwrite Collection

You need to create a new collection called `reputation_logs` in your Appwrite database:

### Collection: `reputation_logs`

**Attributes:**
- `userId` (String, Required) - User who gained/lost reputation
- `pointsChange` (Integer, Required) - Points added or removed (+/-)  
- `newTotal` (Integer, Required) - User's total reputation after change
- `reason` (String, Required) - Description of why reputation changed
- `timestamp` (DateTime, Required) - When the change occurred

**Indexes:**
- `userId` (Key index for querying user's reputation history)
- `timestamp` (Key index for chronological queries)
- `userId_timestamp` (Compound index for efficient user history queries)

**Permissions:**
- **Read**: Users can read their own logs
- **Create**: Only server/admin can create logs
- **Update**: No one (logs are immutable)
- **Delete**: Only admin can delete logs

## Integration Points

### When Reputation is Awarded/Deducted:

1. **Debate Completion**
   - Winner gets win points + performance bonus
   - Loser gets loss points (reduced for close matches)
   - Both get participation points

2. **Gift Transactions**
   - Sender gets small reputation for generosity
   - Receiver gets reputation for community support

3. **Room Activities**  
   - Room creation awards points
   - Daily login awards small bonus

4. **Role Performance**
   - Judge/Moderator ratings trigger reputation awards
   - Based on star ratings from participants

5. **Behavior Management**
   - Bad behavior reports trigger penalties
   - Spam detection triggers automatic penalties

## Display

The reputation is displayed as:
- **Home Screen Rank**: `reputation ÷ 100` (e.g., 5490 reputation = 54.9 rank)
- **Profile**: Full reputation number with formatted display
- **Leaderboards**: Sorted by total reputation points

## Benefits of High Reputation

Users with higher reputation could get:
- Special badges or titles
- Priority in matchmaking
- Access to exclusive features
- Moderator/Judge privileges
- Enhanced profile visibility

## Implementation Status

✅ **Completed:**
- Reputation service with all point calculations
- Integration with coin service for gifts
- Automatic logging of reputation changes
- Proper separation of coins vs reputation

🔄 **Next Steps:**
1. Create `reputation_logs` collection in Appwrite
2. Integrate reputation awards into debate completion flow
3. Add daily login bonus system
4. Create reputation-based leaderboards
5. Implement role performance rating system

## Usage Example

```dart
// Award reputation for debate win
await reputationService.awardDebateWin(userId, judgeScore: 85);

// Send gift (automatically awards reputation)
await coinService.sendGift(senderId, receiverId, 100);

// Penalize bad behavior  
await reputationService.penalizeBadBehavior(userId, "Spam in chat");
```