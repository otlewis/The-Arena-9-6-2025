# Arena Content Moderation Database Schema

## Collections Required

### 1. user_reports
Track all user reports for moderation review
```javascript
{
  id: string,
  reporterId: string,        // User who made the report
  reportedUserId: string,     // User being reported
  roomId: string,             // Where incident occurred
  reportType: string,         // 'harassment', 'spam', 'hate_speech', 'inappropriate', 'other'
  description: string,        // Details of the issue
  evidence: {
    messageId?: string,       // If reporting a specific message
    screenshot?: string,      // Optional screenshot URL
    timestamp: datetime       // When incident occurred
  },
  status: string,             // 'pending', 'reviewing', 'resolved', 'dismissed'
  moderatorId?: string,       // Moderator who handled it
  resolution?: string,        // Action taken
  createdAt: datetime,
  updatedAt: datetime
}
```

### 2. moderation_actions
Log all moderation actions taken
```javascript
{
  id: string,
  moderatorId: string,        // Who took the action
  targetUserId: string,       // User affected
  roomId?: string,            // If room-specific
  action: string,             // 'warning', 'mute', 'kick', 'ban', 'unban'
  duration?: number,          // For temporary actions (in minutes)
  reason: string,             // Why action was taken
  reportId?: string,          // Link to user report if applicable
  automated: boolean,         // If triggered by AI
  aiScore?: {
    toxicity?: number,
    threat?: number,
    profanity?: number,
    spam?: number
  },
  expiresAt?: datetime,       // For temporary bans/mutes
  createdAt: datetime
}
```

### 3. user_violations
Track violation history and warning counts
```javascript
{
  id: string,
  userId: string,
  violationType: string,      // 'profanity', 'harassment', 'spam', etc.
  severity: string,           // 'low', 'medium', 'high', 'critical'
  warningCount: number,       // Total warnings
  strikeCount: number,        // Serious violations
  lastViolation: datetime,
  status: string,             // 'active', 'muted', 'banned'
  muteExpiresAt?: datetime,
  banExpiresAt?: datetime,
  notes?: string,             // Moderator notes
  createdAt: datetime,
  updatedAt: datetime
}
```

### 4. appeals
Handle ban/suspension appeals
```javascript
{
  id: string,
  userId: string,
  actionId: string,           // Original moderation action
  appealReason: string,       // User's explanation
  evidence?: string,          // Any supporting evidence
  status: string,             // 'pending', 'reviewing', 'approved', 'denied'
  reviewerId?: string,        // Moderator reviewing appeal
  reviewNotes?: string,       // Decision reasoning
  createdAt: datetime,
  resolvedAt?: datetime
}
```

### 5. blocked_users
Personal user blocks (user-to-user)
```javascript
{
  id: string,
  userId: string,             // User who blocked
  blockedUserId: string,      // User being blocked
  reason?: string,            // Optional reason
  createdAt: datetime
}
```

### 6. content_filters
Automated content filtering rules
```javascript
{
  id: string,
  filterType: string,         // 'word', 'regex', 'domain'
  pattern: string,            // What to filter
  severity: string,           // 'low', 'medium', 'high'
  action: string,             // 'flag', 'hide', 'block'
  isActive: boolean,
  createdBy: string,
  createdAt: datetime,
  updatedAt: datetime
}
```

### 7. moderation_queue
Items awaiting moderator review
```javascript
{
  id: string,
  itemType: string,           // 'message', 'user', 'room'
  itemId: string,             // ID of the item
  reason: string,             // Why it's in queue
  priority: string,           // 'low', 'medium', 'high', 'urgent'
  aiAnalysis?: {
    toxicity?: number,
    threat?: number,
    profanity?: number,
    spam?: number,
    flaggedPhrases?: array
  },
  reportCount: number,        // How many users reported
  status: string,             // 'pending', 'reviewing', 'resolved'
  assignedTo?: string,        // Moderator assigned
  createdAt: datetime,
  resolvedAt?: datetime
}
```

## Indexes Needed

### user_reports
- reporterId + createdAt (DESC)
- reportedUserId + status
- status + createdAt (DESC)
- roomId + createdAt (DESC)

### moderation_actions
- targetUserId + createdAt (DESC)
- moderatorId + createdAt (DESC)
- action + expiresAt
- automated + createdAt (DESC)

### user_violations
- userId (UNIQUE)
- status + banExpiresAt
- warningCount + lastViolation

### appeals
- userId + status
- status + createdAt (ASC)

### blocked_users
- userId + blockedUserId (UNIQUE)
- blockedUserId

### moderation_queue
- status + priority + createdAt
- assignedTo + status

## Permission Rules

### user_reports
- Users can create reports
- Users can read their own reports
- Moderators can read all reports
- Moderators can update status

### moderation_actions
- Only moderators can create
- Users can read actions against them
- Moderators can read all

### appeals
- Users can create appeals for their own bans
- Users can read their own appeals
- Moderators can read and update all appeals

### blocked_users
- Users can create/delete their own blocks
- Users can read their own blocks

## Automated Triggers

1. **Auto-mute after 3 warnings** in 24 hours
2. **Auto-ban after 3 strikes** in 30 days
3. **Auto-flag messages** with toxicity > 0.8
4. **Auto-queue for review** when 3+ users report same person
5. **Auto-expire temporary bans/mutes** via scheduled function