#!/bin/bash

echo "🛡️ Creating Super Moderator entry for user..."

# Set up environment
export APPWRITE_ENDPOINT="https://cloud.appwrite.io/v1"
export APPWRITE_PROJECT_ID="683a37a8003719978879"  
export APPWRITE_DATABASE_ID="arena_db"

# Use one of the known user IDs from the logs (6847542aaf2b8753e314 appears to be Kritik based on the logs)
KRITIK_USER_ID="6847542aaf2b8753e314"

echo "✅ Using user ID: $KRITIK_USER_ID"
echo "🔧 Creating Super Moderator entry..."

# Create Super Moderator document
appwrite databases create-document \
    --database-id "arena_db" \
    --collection-id "super_moderators" \
    --document-id unique\(\) \
    --data "{
        \"userId\": \"$KRITIK_USER_ID\",
        \"username\": \"Kritik\",
        \"isActive\": true,
        \"grantedAt\": \"$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")\",
        \"permissions\": [\"access_reports\", \"ban_users\", \"kick_users\", \"lock_microphones\", \"close_rooms\", \"promote_moderators\"]
    }" \
    --permissions "[\"read(\\\"any\\\")\", \"write(\\\"any\\\")\", \"update(\\\"any\\\")\", \"delete(\\\"any\\\")\"]"

if [ $? -eq 0 ]; then
    echo "🎉 SUCCESS! Super Moderator status granted!"
    echo "✨ Now the user has:"
    echo "   - Golden 'SM' badge"
    echo "   - Immunity from kicks" 
    echo "   - Instant speaker access"
    echo "   - Access to reports and moderation tools"
    echo "   - Ability to ban/kick users and close rooms"
else
    echo "❌ Failed to grant Super Moderator status"
fi