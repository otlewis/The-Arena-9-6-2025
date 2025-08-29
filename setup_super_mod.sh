#!/bin/bash

# Arena Super Moderator Setup Script
# This script creates the required Appwrite collections and grants Kritik Super Moderator status

set -e  # Exit on any error

echo "🛡️  Arena Super Moderator Setup"
echo "================================="

# Appwrite configuration
APPWRITE_ENDPOINT="https://cloud.appwrite.io/v1"
APPWRITE_PROJECT_ID="683a37a8003719978879"
APPWRITE_DATABASE_ID="arena_db"

# Check if Appwrite CLI is installed
if ! command -v appwrite &> /dev/null; then
    echo "❌ Appwrite CLI not found. Installing..."
    npm install -g appwrite-cli
fi

echo "🔧 Setting up Appwrite CLI..."
appwrite client --endpoint $APPWRITE_ENDPOINT
appwrite login

echo "📊 Creating Super Moderator collections..."

# 1. Create super_moderators collection
echo "Creating super_moderators collection..."
appwrite databases create-collection \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "super_moderators" \
    --name "Super Moderators" \
    --permissions "create(\"users\")" "read(\"users\")" "update(\"users\")" "delete(\"users\")"

# Add attributes to super_moderators
appwrite databases create-string-attribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "super_moderators" \
    --key "userId" \
    --size 255 \
    --required true

appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "super_moderators" \
    --key "username" \
    --size 255 \
    --required true

appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "super_moderators" \
    --key "profileImageUrl" \
    --size 500 \
    --required false

appwrite databases createDatetimeAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "super_moderators" \
    --key "grantedAt" \
    --required true

appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "super_moderators" \
    --key "grantedBy" \
    --size 255 \
    --required false

appwrite databases createBooleanAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "super_moderators" \
    --key "isActive" \
    --required true \
    --default true

# 2. Create room_bans collection
echo "Creating room_bans collection..."
appwrite databases createCollection \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_bans" \
    --name "Room Bans" \
    --permissions "create(\"users\")" "read(\"users\")" "update(\"users\")" "delete(\"users\")"

# Add attributes to room_bans
appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_bans" \
    --key "userId" \
    --size 255 \
    --required true

appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_bans" \
    --key "roomId" \
    --size 255 \
    --required true

appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_bans" \
    --key "roomType" \
    --size 100 \
    --required true

appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_bans" \
    --key "bannedBy" \
    --size 255 \
    --required true

appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_bans" \
    --key "reason" \
    --size 500 \
    --required false

appwrite databases createDatetimeAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_bans" \
    --key "bannedAt" \
    --required true

appwrite databases createDatetimeAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_bans" \
    --key "expiresAt" \
    --required false

appwrite databases createBooleanAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_bans" \
    --key "isActive" \
    --required true \
    --default true

# 3. Create room_events collection
echo "Creating room_events collection..."
appwrite databases createCollection \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_events" \
    --name "Room Events" \
    --permissions "create(\"users\")" "read(\"users\")" "update(\"users\")" "delete(\"users\")"

# Add attributes to room_events
appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_events" \
    --key "type" \
    --size 100 \
    --required true

appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_events" \
    --key "userId" \
    --size 255 \
    --required false

appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_events" \
    --key "roomId" \
    --size 255 \
    --required true

appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_events" \
    --key "moderatorId" \
    --size 255 \
    --required true

appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_events" \
    --key "reason" \
    --size 500 \
    --required false

appwrite databases createDatetimeAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "room_events" \
    --key "timestamp" \
    --required true

# 4. Create moderation_actions collection
echo "Creating moderation_actions collection..."
appwrite databases createCollection \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "moderation_actions" \
    --name "Moderation Actions" \
    --permissions "create(\"users\")" "read(\"users\")" "update(\"users\")" "delete(\"users\")"

# Add attributes to moderation_actions
appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "moderation_actions" \
    --key "moderatorId" \
    --size 255 \
    --required true

appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "moderation_actions" \
    --key "targetUserId" \
    --size 255 \
    --required false

appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "moderation_actions" \
    --key "roomId" \
    --size 255 \
    --required false

appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "moderation_actions" \
    --key "action" \
    --size 100 \
    --required true

appwrite databases createStringAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "moderation_actions" \
    --key "reason" \
    --size 500 \
    --required false

appwrite databases createDatetimeAttribute \
    --databaseId $APPWRITE_DATABASE_ID \
    --collectionId "moderation_actions" \
    --key "createdAt" \
    --required true

echo "✅ Collections created successfully!"

echo ""
echo "🎖️  Next steps:"
echo "1. Run the Flutter app: flutter run"
echo "2. The app will automatically initialize the Super Moderator service"
echo "3. Use the in-app admin function to grant Kritik Super Moderator status"
echo ""
echo "🛡️  Setup complete!"