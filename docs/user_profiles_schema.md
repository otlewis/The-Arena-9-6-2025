# User Profiles Collection Schema

This document describes the enhanced user profiles collection schema for Arena.

## Collection: `users`

### Overview
Extended user profile data beyond basic Appwrite authentication. Stores comprehensive profile information, stats, and preferences.

### Attributes

| Attribute | Type | Size | Required | Array | Default | Description |
|-----------|------|------|----------|-------|---------|-------------|
| `name` | String | 255 | ✅ | ❌ | - | User's display name |
| `email` | String | 255 | ✅ | ❌ | - | User's email address |
| `bio` | String | 500 | ❌ | ❌ | - | User's biography/about text |
| `avatar` | String | 2048 | ❌ | ❌ | - | URL to user's avatar image |
| `location` | String | 255 | ❌ | ❌ | - | User's location/city |
| `website` | String | 2048 | ❌ | ❌ | - | User's website URL |
| `xHandle` | String | 50 | ❌ | ❌ | - | X (formerly Twitter) username (without @) |
| `linkedinHandle` | String | 100 | ❌ | ❌ | - | LinkedIn username |
| `youtubeHandle` | String | 100 | ❌ | ❌ | - | YouTube username |
| `facebookHandle` | String | 100 | ❌ | ❌ | - | Facebook username |
| `instagramHandle` | String | 100 | ❌ | ❌ | - | Instagram username |
| `preferences` | String | 2048 | ❌ | ❌ | '{}' | JSON string of user preferences |
| `reputation` | Integer | - | ❌ | ❌ | 0 | User's reputation score |
| `totalDebates` | Integer | - | ❌ | ❌ | 0 | Total number of debates participated |
| `totalWins` | Integer | - | ❌ | ❌ | 0 | Total number of debates won |
| `totalRoomsCreated` | Integer | - | ❌ | ❌ | 0 | Total rooms created by user |
| `totalRoomsJoined` | Integer | - | ❌ | ❌ | 0 | Total rooms joined by user |
| `interests` | String | 100 | ❌ | ✅ | [] | Array of interest topics |
| `joinedClubs` | String | 100 | ❌ | ✅ | [] | Array of club IDs user is member of |
| `isVerified` | Boolean | - | ❌ | ❌ | false | Whether user is verified |
| `isPublicProfile` | Boolean | - | ❌ | ❌ | true | Whether profile is public |

### Setup Instructions

1. **Create Collection**
   - Collection ID: `users`
   - Collection Name: `Users`

2. **Create Attributes**
   ```bash
   # Basic Info
   name: String, 255 chars, required
   email: String, 255 chars, required
   bio: String, 500 chars, optional
   avatar: String, 2048 chars, optional
   location: String, 255 chars, optional
   
   # Social Links
   website: String, 2048 chars, optional
   xHandle: String, 50 chars, optional
   linkedinHandle: String, 100 chars, optional
   youtubeHandle: String, 100 chars, optional
   facebookHandle: String, 100 chars, optional
   instagramHandle: String, 100 chars, optional
   
   # System Data
   preferences: String, 2048 chars, optional, default: '{}'
   
   # Stats
   reputation: Integer, optional, default: 0
   totalDebates: Integer, optional, default: 0
   totalWins: Integer, optional, default: 0
   totalRoomsCreated: Integer, optional, default: 0
   totalRoomsJoined: Integer, optional, default: 0
   
   # Arrays (select String + check Array checkbox)
   interests: String Array, 100 chars per item, optional
   joinedClubs: String Array, 100 chars per item, optional
   
   # Flags
   isVerified: Boolean, optional, default: false
   isPublicProfile: Boolean, optional, default: true
   ```

3. **Set Permissions**
   - Create Documents: Users (role:users)
   - Read Documents: Users (role:users)
   - Update Documents: Users (role:users) 
   - Delete Documents: Users (role:users)

4. **Create Indexes** (Optional for performance)
   - Index on `email` (unique)
   - Index on `reputation` (descending)
   - Index on `totalDebates` (descending)
   - Index on `isPublicProfile`

### Storage Bucket: `avatars`

For avatar image storage, create a storage bucket:

1. **Create Bucket**
   - Bucket ID: `avatars`
   - Bucket Name: `User Avatars`
   - Maximum File Size: 5MB
   - Allowed File Extensions: jpg, jpeg, png, webp
   - Compression: Enabled

2. **Set Permissions**
   - Create Files: Users (role:users)
   - Read Files: Any (role:any)
   - Update Files: Users (role:users)
   - Delete Files: Users (role:users)

### Usage Examples

#### Create User Profile
```dart
await appwrite.createUserProfile(
  userId: 'user123',
  name: 'John Doe',
  email: 'john@example.com',
  bio: 'Passionate debater interested in politics and technology',
  location: 'New York, NY',
  interests: ['Politics', 'Technology', 'Philosophy'],
);
```

#### Update Profile
```dart
await appwrite.updateUserProfile(
  userId: 'user123',
  bio: 'Updated bio text',
  website: 'https://johndoe.com',
  xHandle: 'johndoe',
  youtubeHandle: 'johndoevlogs',
  instagramHandle: 'john.doe.official',
  interests: ['Politics', 'Technology', 'Science'],
);
```

#### Upload Avatar
```dart
final avatarUrl = await appwrite.uploadAvatar(
  userId: 'user123',
  fileBytes: imageBytes,
  fileName: 'avatar.jpg',
);
```

### Data Relationships

- Document ID should match Appwrite User ID for consistency
- `joinedClubs` references Club document IDs
- `preferences` stores JSON for flexible user settings
- Stats are automatically calculated based on user activity

### Validation Rules

- Email must be valid email format
- Website must be valid URL format  
- X handle without @ symbol
- LinkedIn handle is username only
- YouTube handle is username/channel name only
- Facebook handle is username only  
- Instagram handle without @ symbol
- Bio limited to 500 characters
- Interests limited to predefined list 