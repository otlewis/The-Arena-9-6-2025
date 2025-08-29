#!/bin/bash

echo "🛡️ Creating super_moderators collection with proper string sizes..."

# Set project context
appwrite client set-project --project-id 683a37a8003719978879

echo "Creating collection..."
appwrite databases create-collection \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --name "Super Moderators"

echo "Adding userId attribute (size 255)..."
appwrite databases create-string-attribute \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --key "userId" \
    --size 255 \
    --required true

echo "Adding username attribute (size 100)..."
appwrite databases create-string-attribute \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --key "username" \
    --size 100 \
    --required true

echo "Adding profileImageUrl attribute (size 500)..."
appwrite databases create-string-attribute \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --key "profileImageUrl" \
    --size 500 \
    --required false

echo "Adding grantedBy attribute (size 255)..."
appwrite databases create-string-attribute \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --key "grantedBy" \
    --size 255 \
    --required false

echo "Adding isActive boolean attribute..."
appwrite databases create-boolean-attribute \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --key "isActive" \
    --required true \
    --xdefault true

echo "Adding grantedAt datetime attribute..."
appwrite databases create-datetime-attribute \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --key "grantedAt" \
    --required true

echo "Adding permissions string array attribute..."
appwrite databases create-string-attribute \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --key "permissions" \
    --size 50 \
    --required true \
    --array true

echo "Adding metadata attribute (size 1000)..."
appwrite databases create-string-attribute \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --key "metadata" \
    --size 1000 \
    --required false

echo "✅ Super Moderators collection created with all attributes and proper sizes!"