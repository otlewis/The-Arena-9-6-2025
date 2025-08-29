#!/bin/bash

# Simple Super Moderator Collection Creation
echo "🛡️ Creating super_moderators collection..."

# Set the project first
appwrite client --endpoint https://cloud.appwrite.io/v1
appwrite client set-project --projectId 683a37a8003719978879

# Create the super_moderators collection
appwrite databases create-collection \
    --databaseId "arena_db" \
    --collectionId "super_moderators" \
    --name "Super Moderators"

# Add the essential attributes
appwrite databases create-string-attribute \
    --databaseId "arena_db" \
    --collectionId "super_moderators" \
    --key "userId" \
    --size 255 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "arena_db" \
    --collectionId "super_moderators" \
    --key "username" \
    --size 255 \
    --required true

appwrite databases create-boolean-attribute \
    --databaseId "arena_db" \
    --collectionId "super_moderators" \
    --key "isActive" \
    --required true \
    --default true

appwrite databases create-datetime-attribute \
    --databaseId "arena_db" \
    --collectionId "super_moderators" \
    --key "grantedAt" \
    --required true

echo "✅ Super Moderators collection created!"
echo "🎯 Now you can use the in-app setup to grant Kritik Super Moderator status"