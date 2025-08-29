#!/bin/bash

echo "🛡️ Granting Kritik Super Moderator status..."

# Set project context
export APPWRITE_ENDPOINT="https://cloud.appwrite.io/v1"
export APPWRITE_PROJECT_ID="683a37a8003719978879"
export APPWRITE_DATABASE_ID="arena_db"

echo "🔍 Finding user 'Kritik'..."

# Get Kritik's user ID by searching username
KRITIK_USER_ID=$(appwrite databases list-documents \
    --database-id "arena_db" \
    --collection-id "users" \
    --queries '["equal(\"name\", \"Kritik\")"]' | jq -r '.documents[0].$id' 2>/dev/null)

if [ "$KRITIK_USER_ID" = "null" ] || [ -z "$KRITIK_USER_ID" ]; then
    echo "❌ User 'Kritik' not found. Please check the username exists in the users collection."
    exit 1
fi

echo "✅ Found Kritik with ID: $KRITIK_USER_ID"
echo "🔧 Creating Super Moderator entry..."

# Create Super Moderator document
appwrite databases create-document \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --document-id unique() \
    --data '{
        "userId": "'$KRITIK_USER_ID'",
        "username": "Kritik",
        "isActive": true,
        "grantedAt": "'$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")'",
        "permissions": ["access_reports", "ban_users", "kick_users", "lock_microphones", "close_rooms", "promote_moderators"]
    }' \
    --permissions '["read(\"any\")", "write(\"any\")", "update(\"any\")", "delete(\"any\")"]'

if [ $? -eq 0 ]; then
    echo "🎉 SUCCESS! Kritik has been granted Super Moderator status!"
    echo "✨ Kritik now has:"
    echo "   - Golden 'SM' badge"
    echo "   - Immunity from kicks"
    echo "   - Instant speaker access"
    echo "   - Access to reports and moderation tools"
    echo "   - Ability to ban/kick users and close rooms"
else
    echo "❌ Failed to grant Super Moderator status"
    exit 1
fi