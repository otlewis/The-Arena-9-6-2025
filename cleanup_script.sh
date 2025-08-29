#!/bin/bash

echo "🧹 Starting Appwrite data cleanup..."

# Set project details
appwrite client --endpoint https://cloud.appwrite.io/v1
appwrite client --project-id fra-683a37a8003719978879

echo "📋 Listing and cleaning users collection..."
# Get user IDs and delete them
appwrite databases list-documents --database-id arena_db --collection-id users --output json | jq -r '.documents[]."\$id"' | while read -r doc_id; do
    if [ ! -z "$doc_id" ] && [ "$doc_id" != "null" ]; then
        echo "Deleting user: $doc_id"
        appwrite databases delete-document --database-id arena_db --collection-id users --document-id "$doc_id"
    fi
done

echo "📋 Listing and cleaning debate_clubs collection..."
# Get club IDs and delete them
appwrite databases list-documents --database-id arena_db --collection-id debate_clubs --output json | jq -r '.documents[]."\$id"' | while read -r doc_id; do
    if [ ! -z "$doc_id" ] && [ "$doc_id" != "null" ]; then
        echo "Deleting club: $doc_id"
        appwrite databases delete-document --database-id arena_db --collection-id debate_clubs --document-id "$doc_id"
    fi
done

echo "📋 Listing and cleaning memberships collection..."
# Get membership IDs and delete them
appwrite databases list-documents --database-id arena_db --collection-id memberships --output json | jq -r '.documents[]."\$id"' | while read -r doc_id; do
    if [ ! -z "$doc_id" ] && [ "$doc_id" != "null" ]; then
        echo "Deleting membership: $doc_id"
        appwrite databases delete-document --database-id arena_db --collection-id memberships --document-id "$doc_id"
    fi
done

echo "📋 Listing and cleaning room_participants collection..."
# Get participant IDs and delete them
appwrite databases list-documents --database-id arena_db --collection-id room_participants --output json | jq -r '.documents[]."\$id"' | while read -r doc_id; do
    if [ ! -z "$doc_id" ] && [ "$doc_id" != "null" ]; then
        echo "Deleting participant: $doc_id"
        appwrite databases delete-document --database-id arena_db --collection-id room_participants --document-id "$doc_id"
    fi
done

echo "✅ Cleanup complete! Try logging into your app now."