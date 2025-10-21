#!/bin/bash

# Setup room_invitations collection in Appwrite

echo "Setting up room_invitations collection..."

# Create collection
appwrite databases create-collection \
  --database-id arena_db \
  --collection-id room_invitations \
  --name "Room Invitations" \
  --permissions 'read("any")' 'create("users")' 'update("users")' 'delete("users")'

# Add attributes
echo "Creating attributes..."

# roomId - ID of the room being invited to
appwrite databases create-string-attribute \
  --database-id arena_db \
  --collection-id room_invitations \
  --key roomId \
  --size 255 \
  --required true

# roomName - Name of the room
appwrite databases create-string-attribute \
  --database-id arena_db \
  --collection-id room_invitations \
  --key roomName \
  --size 255 \
  --required true

# roomType - Type of room (Discussion, Debate, Take)
appwrite databases create-string-attribute \
  --database-id arena_db \
  --collection-id room_invitations \
  --key roomType \
  --size 50 \
  --required true

# inviterId - User ID of the person sending the invitation
appwrite databases create-string-attribute \
  --database-id arena_db \
  --collection-id room_invitations \
  --key inviterId \
  --size 255 \
  --required true

# inviterName - Name of the person sending the invitation
appwrite databases create-string-attribute \
  --database-id arena_db \
  --collection-id room_invitations \
  --key inviterName \
  --size 255 \
  --required true

# inviteeId - User ID of the person being invited
appwrite databases create-string-attribute \
  --database-id arena_db \
  --collection-id room_invitations \
  --key inviteeId \
  --size 255 \
  --required true

# status - Status of invitation (pending, accepted, declined, expired)
appwrite databases create-string-attribute \
  --database-id arena_db \
  --collection-id room_invitations \
  --key status \
  --size 50 \
  --required true

# createdAt - Timestamp when invitation was sent
appwrite databases create-string-attribute \
  --database-id arena_db \
  --collection-id room_invitations \
  --key createdAt \
  --size 100 \
  --required true

# expiresAt - Timestamp when invitation expires
appwrite databases create-string-attribute \
  --database-id arena_db \
  --collection-id room_invitations \
  --key expiresAt \
  --size 100 \
  --required true

# Wait for attributes to be created
echo "Waiting for attributes to be created..."
sleep 5

# Create indexes
echo "Creating indexes..."

# Index for finding invitations by invitee
appwrite databases create-index \
  --database-id arena_db \
  --collection-id room_invitations \
  --key inviteeId_status_idx \
  --type key \
  --attributes inviteeId status \
  --orders ASC ASC

# Index for finding invitations by room
appwrite databases create-index \
  --database-id arena_db \
  --collection-id room_invitations \
  --key roomId_status_idx \
  --type key \
  --attributes roomId status \
  --orders ASC ASC

# Index for sorting by creation date
appwrite databases create-index \
  --database-id arena_db \
  --collection-id room_invitations \
  --key createdAt_idx \
  --type key \
  --attributes createdAt \
  --orders DESC

# Index for finding expired invitations
appwrite databases create-index \
  --database-id arena_db \
  --collection-id room_invitations \
  --key expiresAt_status_idx \
  --type key \
  --attributes expiresAt status \
  --orders ASC ASC

echo "✅ room_invitations collection setup complete!"
echo ""
echo "Collection details:"
echo "  - Database: arena_db"
echo "  - Collection: room_invitations"
echo "  - Attributes: roomId, roomName, roomType, inviterId, inviterName, inviteeId, status, createdAt, expiresAt"
echo "  - Indexes: inviteeId_status_idx, roomId_status_idx, createdAt_idx, expiresAt_status_idx"
