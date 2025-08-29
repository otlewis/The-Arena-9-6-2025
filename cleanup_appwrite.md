# Appwrite Data Cleanup Commands

After successfully logging in with `appwrite login`, run these commands:

## 1. List and Delete Users
```bash
# List all user documents
appwrite databases list-documents --database-id arena_db --collection-id users

# Delete each user document (replace USER_ID with actual IDs from the list above)
appwrite databases delete-document --database-id arena_db --collection-id users --document-id USER_ID
```

## 2. Clean Debate Clubs
```bash
# List all debate club documents
appwrite databases list-documents --database-id arena_db --collection-id debate_clubs

# Delete each debate club document
appwrite databases delete-document --database-id arena_db --collection-id debate_clubs --document-id CLUB_ID
```

## 3. Clean Memberships
```bash
# List all membership documents
appwrite databases list-documents --database-id arena_db --collection-id memberships

# Delete each membership document
appwrite databases delete-document --database-id arena_db --collection-id memberships --document-id MEMBERSHIP_ID
```

## 4. Clean Room Participants
```bash
# List all room participant documents
appwrite databases list-documents --database-id arena_db --collection-id room_participants

# Delete each participant document
appwrite databases delete-document --database-id arena_db --collection-id room_participants --document-id PARTICIPANT_ID
```

## 5. Clean Discussion Rooms
```bash
# List all discussion room documents
appwrite databases list-documents --database-id arena_db --collection-id discussion_rooms

# Delete each room document
appwrite databases delete-document --database-id arena_db --collection-id discussion_rooms --document-id ROOM_ID
```

## Quick Test Commands
After cleanup:
```bash
# Verify collections are empty
appwrite databases list-documents --database-id arena_db --collection-id users
appwrite databases list-documents --database-id arena_db --collection-id debate_clubs
```