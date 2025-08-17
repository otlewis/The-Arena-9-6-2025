#!/bin/bash

# Email Drafts Collection Setup Script for Arena App
# This script creates the email_drafts collection in Appwrite

echo "Setting up Email Drafts Collection..."

# Configuration
PROJECT_ID="683a37a8003719978879"
DATABASE_ID="arena_db"
COLLECTION_ID="email_drafts"
COLLECTION_NAME="Email Drafts"

# Create email_drafts collection
appwrite databases createCollection \
    --databaseId "$DATABASE_ID" \
    --collectionId "$COLLECTION_ID" \
    --name "$COLLECTION_NAME" \
    --permissions 'read("any")' 'write("users")' \
    --documentSecurity true

echo "Created email_drafts collection"

# Create attributes
echo "Creating attributes..."

# userId - the user who owns the draft
appwrite databases createStringAttribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "$COLLECTION_ID" \
    --key "userId" \
    --size 255 \
    --required true

# recipientId - optional recipient user ID
appwrite databases createStringAttribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "$COLLECTION_ID" \
    --key "recipientId" \
    --size 255 \
    --required false

# recipientUsername - optional recipient username
appwrite databases createStringAttribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "$COLLECTION_ID" \
    --key "recipientUsername" \
    --size 255 \
    --required false

# recipientEmail - optional recipient email display
appwrite databases createStringAttribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "$COLLECTION_ID" \
    --key "recipientEmail" \
    --size 255 \
    --required false

# subject - email subject line
appwrite databases createStringAttribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "$COLLECTION_ID" \
    --key "subject" \
    --size 500 \
    --required false \
    --default ""

# body - email body content
appwrite databases createStringAttribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "$COLLECTION_ID" \
    --key "body" \
    --size 10000 \
    --required false \
    --default ""

# lastModified - when the draft was last saved
appwrite databases createDatetimeAttribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "$COLLECTION_ID" \
    --key "lastModified" \
    --required true

echo "Attributes created"

# Create indexes
echo "Creating indexes..."

# Index on userId for fetching user's drafts
appwrite databases createIndex \
    --databaseId "$DATABASE_ID" \
    --collectionId "$COLLECTION_ID" \
    --key "userId_idx" \
    --type "key" \
    --attributes "userId"

# Index on lastModified for sorting
appwrite databases createIndex \
    --databaseId "$DATABASE_ID" \
    --collectionId "$COLLECTION_ID" \
    --key "lastModified_idx" \
    --type "key" \
    --attributes "lastModified" \
    --orders "DESC"

# Compound index for user's drafts sorted by date
appwrite databases createIndex \
    --databaseId "$DATABASE_ID" \
    --collectionId "$COLLECTION_ID" \
    --key "user_drafts_idx" \
    --type "key" \
    --attributes "userId" "lastModified" \
    --orders "ASC" "DESC"

echo "Indexes created"

echo "Email Drafts collection setup complete!"
echo ""
echo "Collection ID: $COLLECTION_ID"
echo "Features:"
echo "  - Auto-save drafts every 5 seconds"
echo "  - Swipe to delete drafts"
echo "  - Resume editing from drafts tab"
echo "  - Drafts automatically deleted when email is sent"