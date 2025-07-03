# Appwrite Schema Configuration

This document outlines the required attributes for each collection in the Arena database.

## Database: `arena_db`

### 1. Collection: `rooms`

**Required Attributes:**

| Attribute | Type | Size | Required | Default | Array |
|-----------|------|------|----------|---------|--------|
| title | String | 255 | Yes | - | No |
| description | String | 1000 | Yes | - | No |
| type | String | 50 | Yes | "discussion" | No |
| status | String | 50 | Yes | "scheduled" | No |
| createdBy | String | 255 | Yes | - | No |
| scheduledAt | DateTime | - | No | - | No |
| startedAt | DateTime | - | No | - | No |
| endedAt | DateTime | - | No | - | No |
| clubId | String | 255 | No | - | No |
| isPublic | Boolean | - | No | true | No |
| maxParticipants | Integer | - | No | 50 | No |
| participantIds | String | 255 | No | - | Yes |
| moderatorId | String | 255 | No | - | No |
| settings | String | 2000 | No | "{}" | No |
| debateFormat | String | 50 | No | - | No |
| timeLimit | Integer | - | No | - | No |
| votingEnabled | Boolean | - | No | false | No |
| currentSpeakerId | String | 255 | No | - | No |
| speakerQueue | String | 255 | No | - | Yes |
| sides | String | 2000 | No | - | No |
| tags | String | 100 | No | - | Yes |
| isFeatured | Boolean | - | No | false | No |
| prizeDescription | String | 500 | No | - | No |
| judgeIds | String | 255 | No | - | Yes |

### 2. Collection: `room_participants`

**Required Attributes:**

| Attribute | Type | Size | Required | Default | Array |
|-----------|------|------|----------|---------|--------|
| userId | String | 255 | Yes | - | No |
| roomId | String | 255 | Yes | - | No |
| userName | String | 255 | Yes | - | No |
| userAvatar | String | 500 | No | - | No |
| role | String | 50 | Yes | "listener" | No |
| status | String | 50 | Yes | "joined" | No |
| joinedAt | DateTime | - | Yes | - | No |
| leftAt | DateTime | - | No | - | No |
| lastActiveAt | DateTime | - | No | - | No |
| side | String | 50 | No | - | No |
| speakingOrder | Integer | - | No | - | No |
| metadata | String | 2000 | No | "{}" | No |

### 3. Collection: `users` (should already exist)

**Required Attributes:**

| Attribute | Type | Size | Required | Default | Array |
|-----------|------|------|----------|---------|--------|
| name | String | 255 | Yes | - | No |
| email | String | 255 | Yes | - | No |
| avatar | String | 500 | No | - | No |
| bio | String | 500 | No | - | No |
| location | String | 255 | No | - | No |
| website | String | 255 | No | - | No |
| twitterHandle | String | 100 | No | - | No |
| linkedinHandle | String | 100 | No | - | No |
| preferences | String | 2000 | No | "{}" | No |
| reputation | Integer | - | No | 0 | No |
| totalDebates | Integer | - | No | 0 | No |
| totalWins | Integer | - | No | 0 | No |
| joinedClubs | String | 255 | No | - | Yes |

### 4. Collection: `debate_clubs` (should already exist)

**Required Attributes:**

| Attribute | Type | Size | Required | Default | Array |
|-----------|------|------|----------|---------|--------|
| name | String | 255 | Yes | - | No |
| description | String | 1000 | Yes | - | No |
| topic | String | 255 | Yes | - | No |
| isPublic | Boolean | - | No | true | No |
| memberCount | Integer | - | No | 0 | No |
| createdBy | String | 255 | Yes | - | No |
| moderators | String | 255 | No | - | Yes |
| members | String | 255 | No | - | Yes |
| rules | String | 2000 | No | - | No |
| tags | String | 100 | No | - | Yes |

### 5. Collection: `memberships` (should already exist)

**Required Attributes:**

| Attribute | Type | Size | Required | Default | Array |
|-----------|------|------|----------|---------|--------|
| userId | String | 255 | Yes | - | No |
| clubId | String | 255 | Yes | - | No |
| role | String | 50 | Yes | "member" | No |
| joinedAt | DateTime | - | Yes | - | No |
| leftAt | DateTime | - | No | - | No |
| isActive | Boolean | - | No | true | No |

## Setup Instructions

1. **Go to Appwrite Console** → Your Project → Databases → `arena_db`

2. **For each collection**, click on the collection name, then "Attributes"

3. **Add each attribute** listed above with the exact specifications

4. **Set proper permissions** for each collection:
   - Read: `role:authenticated`
   - Create: `role:authenticated` 
   - Update: `role:authenticated`
   - Delete: `role:authenticated`

5. **Create indexes** for better performance:

### Recommended Indexes:

**rooms collection:**
- `status_index`: status (ASC)
- `type_index`: type (ASC)
- `createdBy_index`: createdBy (ASC)
- `isPublic_index`: isPublic (ASC)

**room_participants collection:**
- `userId_index`: userId (ASC)
- `roomId_index`: roomId (ASC)
- `role_index`: role (ASC)
- `status_index`: status (ASC)
- `userId_roomId_compound`: userId (ASC), roomId (ASC)

**users collection:**
- `email_index`: email (ASC) - should already exist

**memberships collection:**
- `userId_index`: userId (ASC)
- `clubId_index`: clubId (ASC)
- `userId_clubId_compound`: userId (ASC), clubId (ASC)

## Notes

- **String fields storing JSON**: Use String type for complex objects (settings, metadata, sides) that will be JSON stringified
- **Array fields**: Set Array=Yes for fields that store multiple values
- **DateTime fields**: Use DateTime type, not String
- **Boolean fields**: Use Boolean type with appropriate defaults
- **Required fields**: Mark as required only for essential fields
- **Size limits**: Adjust based on your needs, these are reasonable defaults 