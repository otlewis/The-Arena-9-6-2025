#!/bin/bash

echo "🛡️ Creating super_moderators collection manually..."

# Set project context
appwrite client set-project --project-id 683a37a8003719978879

echo "Creating collection..."
appwrite databases create-collection \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --name "Super Moderators"

echo "Adding userId attribute..."
appwrite databases create-string-attribute \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --key "userId" \
    --size 255 \
    --required true

echo "Adding username attribute..."
appwrite databases create-string-attribute \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --key "username" \
    --size 255 \
    --required true

echo "Adding isActive attribute..."
appwrite databases create-boolean-attribute \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --key "isActive" \
    --required true \
    --default true

echo "Adding grantedAt attribute..."
appwrite databases create-datetime-attribute \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --key "grantedAt" \
    --required true

echo "Adding permissions array attribute..."
appwrite databases create-string-attribute \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --key "permissions" \
    --size 2000 \
    --required true \
    --array true

echo "✅ Super Moderators collection created with all attributes!"