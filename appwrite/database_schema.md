# Appwrite Database Schema for Synchronized Timer System

## Collections Structure

### 1. `timers` Collection

**Purpose**: Store timer state and configuration

**Collection ID**: `timers`
**Database ID**: Use your existing database ID

#### Attributes:

| Attribute | Type | Size | Required | Description |
|-----------|------|------|----------|-------------|
| roomId | string | 100 | ✓ | Reference to room (from your existing rooms) |
| roomType | enum | - | ✓ | ["openDiscussion", "debatesDiscussions", "arena"] |
| timerType | enum | - | ✓ | ["general", "openingStatement", "rebuttal", "closingStatement", "questionRound", "speakerTurn"] |
| status | enum | - | ✓ | ["stopped", "running", "paused", "completed"] |
| durationSeconds | integer | - | ✓ | Total timer duration in seconds |
| remainingSeconds | integer | - | ✓ | Current remaining seconds |
| startTime | datetime | - | ✗ | Server timestamp when timer started |
| pausedAt | datetime | - | ✗ | Server timestamp when timer was paused |
| endTime | datetime | - | ✗ | Calculated end time (startTime + duration) |
| createdBy | string | 100 | ✓ | User ID who created the timer |
| currentSpeaker | string | 100 | ✗ | Current speaker name/ID |
| title | string | 200 | ✗ | Timer title/description |
| config | json | - | ✗ | Timer configuration (colors, warnings, etc.) |
| lastTick | datetime | - | ✗ | Last server update timestamp |
| isActive | boolean | - | ✓ | Quick status check (true for running/paused) |

#### Indexes:

1. **roomId_status**: `roomId` ASC, `status` ASC
2. **roomId_isActive**: `roomId` ASC, `isActive` DESC
3. **createdBy**: `createdBy` ASC
4. **endTime**: `endTime` ASC (for expired timer cleanup)

#### Permissions:

```json
{
  "read": ["users"],
  "create": ["users"],
  "update": ["users"],
  "delete": ["users"]
}
```

### 2. `timer_events` Collection

**Purpose**: Audit trail and event history

**Collection ID**: `timer_events`

#### Attributes:

| Attribute | Type | Size | Required | Description |
|-----------|------|------|----------|-------------|
| timerId | string | 100 | ✓ | Reference to timer document |
| roomId | string | 100 | ✓ | Reference to room for easy querying |
| action | enum | - | ✓ | ["created", "started", "paused", "resumed", "stopped", "reset", "completed", "time_added"] |
| userId | string | 100 | ✓ | User who performed the action |
| timestamp | datetime | - | ✓ | When the action occurred |
| details | string | 500 | ✗ | Additional details about the action |
| previousState | json | - | ✗ | Timer state before the action |
| newState | json | - | ✗ | Timer state after the action |
| metadata | json | - | ✗ | Additional metadata |

#### Indexes:

1. **timerId_timestamp**: `timerId` ASC, `timestamp` DESC
2. **roomId_timestamp**: `roomId` ASC, `timestamp` DESC
3. **userId_timestamp**: `userId` ASC, `timestamp` DESC

#### Permissions:

```json
{
  "read": ["users"],
  "create": ["users"],
  "update": [],
  "delete": []
}
```

### 3. `timer_configs` Collection (Optional)

**Purpose**: Store reusable timer configurations per room type

**Collection ID**: `timer_configs`

#### Attributes:

| Attribute | Type | Size | Required | Description |
|-----------|------|------|----------|-------------|
| roomType | enum | - | ✓ | ["openDiscussion", "debatesDiscussions", "arena"] |
| timerType | enum | - | ✓ | Timer type from predefined list |
| name | string | 100 | ✓ | Display name |
| description | string | 300 | ✗ | Description |
| defaultDuration | integer | - | ✓ | Default duration in seconds |
| presetDurations | json | - | ✓ | Array of preset durations |
| allowPause | boolean | - | ✓ | Can this timer be paused |
| allowAddTime | boolean | - | ✓ | Can time be added to this timer |
| warningThreshold | integer | - | ✓ | Warning seconds threshold |
| colors | json | - | ✓ | Color configuration |
| isEnabled | boolean | - | ✓ | Is this config active |

#### Permissions:

```json
{
  "read": ["users"],
  "create": ["admin"],
  "update": ["admin"],
  "delete": ["admin"]
}
```

## Setup Instructions

### 1. Create Database Collections

Use the Appwrite Console or CLI to create these collections:

```bash
# Using Appwrite CLI
appwrite databases createCollection \
    --databaseId YOUR_DATABASE_ID \
    --collectionId timers \
    --name "Timers" \
    --permissions 'read("users")' 'create("users")' 'update("users")' 'delete("users")'

appwrite databases createCollection \
    --databaseId YOUR_DATABASE_ID \
    --collectionId timer_events \
    --name "Timer Events" \
    --permissions 'read("users")' 'create("users")'

appwrite databases createCollection \
    --databaseId YOUR_DATABASE_ID \
    --collectionId timer_configs \
    --name "Timer Configurations" \
    --permissions 'read("users")' 'create("admin")' 'update("admin")' 'delete("admin")'
```

### 2. Create Attributes

For each collection, create the attributes as defined above using:

```bash
# Example for timers collection
appwrite databases createStringAttribute \
    --databaseId YOUR_DATABASE_ID \
    --collectionId timers \
    --key roomId \
    --size 100 \
    --required true

appwrite databases createEnumAttribute \
    --databaseId YOUR_DATABASE_ID \
    --collectionId timers \
    --key status \
    --elements "stopped,running,paused,completed" \
    --required true
```

### 3. Create Indexes

```bash
# Room and status index for efficient queries
appwrite databases createIndex \
    --databaseId YOUR_DATABASE_ID \
    --collectionId timers \
    --key roomId_status \
    --type key \
    --attributes roomId,status
```

### 4. Sample Data Structure

#### Timer Document Example:
```json
{
  "$id": "timer_123",
  "$createdAt": "2025-01-13T10:00:00.000Z",
  "$updatedAt": "2025-01-13T10:05:00.000Z",
  "roomId": "room_456",
  "roomType": "arena",
  "timerType": "openingStatement",
  "status": "running",
  "durationSeconds": 240,
  "remainingSeconds": 125,
  "startTime": "2025-01-13T10:03:00.000Z",
  "pausedAt": null,
  "endTime": "2025-01-13T10:07:00.000Z",
  "createdBy": "user_789",
  "currentSpeaker": "Debater 1",
  "title": "Opening Statement - Pro Side",
  "config": {
    "warningThreshold": 30,
    "allowPause": false,
    "colors": {
      "primary": "#1976D2",
      "warning": "#FF9800",
      "expired": "#D32F2F"
    }
  },
  "lastTick": "2025-01-13T10:05:00.000Z",
  "isActive": true
}
```

#### Timer Event Example:
```json
{
  "$id": "event_456",
  "$createdAt": "2025-01-13T10:03:00.000Z",
  "timerId": "timer_123",
  "roomId": "room_456",
  "action": "started",
  "userId": "user_789",
  "timestamp": "2025-01-13T10:03:00.000Z",
  "details": "Timer started for opening statement",
  "previousState": {
    "status": "stopped",
    "remainingSeconds": 240
  },
  "newState": {
    "status": "running",
    "remainingSeconds": 240,
    "startTime": "2025-01-13T10:03:00.000Z"
  }
}
```

## Realtime Subscription Channels

### Client Subscriptions

```dart
// Subscribe to all timers in a room
"databases.YOUR_DB_ID.collections.timers.documents"

// Subscribe to specific timer
"databases.YOUR_DB_ID.collections.timers.documents.TIMER_ID"

// Subscribe to timer events for a room
"databases.YOUR_DB_ID.collections.timer_events.documents"
```

### Filter Patterns

```dart
// Room-specific timer updates
client.subscribe([
  'databases.${AppwriteConstants.databaseId}.collections.timers.documents'
]).where('roomId').equal(roomId);

// User's timer events
client.subscribe([
  'databases.${AppwriteConstants.databaseId}.collections.timer_events.documents'
]).where('userId').equal(userId);
```

This schema provides a robust foundation for the server-controlled timer system with proper indexing for performance and comprehensive audit trails.