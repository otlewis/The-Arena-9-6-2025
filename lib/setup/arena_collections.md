# Arena Database Collections

These collections need to be created in your Appwrite database for The Arena functionality:

## 1. arena_rooms
- **Collection ID:** `arena_rooms`
- **Permissions:** 
  - Create: `users` 
  - Read: `users`
  - Update: `users`
  - Delete: `users`

### Attributes:
- `challengeId` (String, 36, required) - Links to original challenge
- `challengerId` (String, 36, required) - User who sent the challenge  
- `challengedId` (String, 36, required) - User who was challenged
- `topic` (String, 500, required) - Debate topic
- `description` (String, 1000, optional) - Additional debate details
- `status` (String, 20, required) - waiting, active, judging, completed
- `startedAt` (String, 50, optional) - ISO timestamp when debate started
- `endedAt` (String, 50, optional) - ISO timestamp when debate ended  
- `winner` (String, 20, optional) - affirmative or negative
- `judgingComplete` (Boolean, required, default: false)
- `totalJudges` (Integer, required, default: 0)
- `judgesSubmitted` (Integer, required, default: 0)

#### Timer Management Fields:
- `currentPhase` (String, 30, optional) - Current debate phase (preDebate, openingAffirmative, etc.)
- `remainingTime` (Integer, required, default: 0) - Seconds remaining in current phase
- `isTimerRunning` (Boolean, required, default: false) - Whether timer is currently active
- `isPaused` (Boolean, required, default: false) - Whether timer is paused
- `phaseStartedAt` (String, 50, optional) - ISO timestamp when current phase began
- `lastTimerUpdate` (String, 50, optional) - ISO timestamp of last timer state change
- `currentSpeaker` (String, 36, optional) - User ID of current speaker

## 2. arena_participants  
- **Collection ID:** `arena_participants`
- **Permissions:** 
  - Create: `users`
  - Read: `users` 
  - Update: `users`
  - Delete: `users`

### Attributes:
- `roomId` (String, 50, required) - Links to arena_rooms
- `userId` (String, 36, required) - Participant user ID
- `role` (String, 20, required) - affirmative, negative, moderator, judge1, judge2, judge3, audience
- `assignedAt` (String, 50, required) - ISO timestamp of assignment
- `isActive` (Boolean, required, default: true)

## 3. arena_judgments
- **Collection ID:** `arena_judgments`  
- **Permissions:**
  - Create: `users`
  - Read: `users`
  - Update: `users` 
  - Delete: `users`

### Attributes:
- `roomId` (String, 50, required) - Links to arena_rooms
- `challengeId` (String, 36, required) - Links to original challenge
- `judgeId` (String, 36, required) - Judge user ID
- `affirmativeScores` (String, 500, required) - JSON with arguments, presentation, rebuttal, total
- `negativeScores` (String, 500, required) - JSON with arguments, presentation, rebuttal, total  
- `winner` (String, 20, required) - affirmative or negative
- `comments` (String, 1000, optional) - Judge feedback
- `submittedAt` (String, 50, required) - ISO timestamp

## Setup Instructions:

1. Go to your Appwrite Console
2. Navigate to your `arena_db` database
3. Create each collection with the exact Collection IDs above
4. Add all attributes with the specified types and requirements
5. Set permissions for each collection to allow `users` role for all operations
6. The collections will integrate with your existing `challenges` collection

## Integration Notes:

- When a challenge is accepted, an `arena_rooms` record is created
- The challenger gets `affirmative` role, challenged gets `negative` role
- Moderators and judges are assigned manually via role management
- All judgments are collected before determining final winner
- Final results update both `arena_rooms` and original `challenges` records 