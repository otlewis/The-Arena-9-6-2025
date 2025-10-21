#!/bin/bash

# Script to add queueEnabled boolean attribute to debate_discussion_rooms collection

ENDPOINT="https://cloud.appwrite.io/v1"
PROJECT_ID="683a37a8003719978879"
DATABASE_ID="arena_db"
COLLECTION_ID="debate_discussion_rooms"

# Check if API key is provided
if [ -z "$APPWRITE_API_KEY" ]; then
    echo "❌ APPWRITE_API_KEY environment variable is required"
    echo "💡 Run: export APPWRITE_API_KEY=your_api_key_here"
    echo "🔗 Get your API key from: https://cloud.appwrite.io/console/project-${PROJECT_ID}/overview/keys"
    exit 1
fi

echo "🔄 Adding queueEnabled attribute to debate_discussion_rooms collection..."

# Add the queueEnabled boolean attribute
RESPONSE=$(curl -s -X POST \
  "${ENDPOINT}/databases/${DATABASE_ID}/collections/${COLLECTION_ID}/attributes/boolean" \
  -H "Content-Type: application/json" \
  -H "X-Appwrite-Response-Format: 1.6.0" \
  -H "X-Appwrite-Project: ${PROJECT_ID}" \
  -H "X-Appwrite-Key: ${APPWRITE_API_KEY}" \
  -d '{
    "key": "queueEnabled",
    "required": false,
    "default": true
  }')

# Check if the request was successful
if echo "$RESPONSE" | grep -q '"code":[45][0-9][0-9]'; then
    ERROR_MESSAGE=$(echo "$RESPONSE" | jq -r '.message // .')

    # Check if attribute already exists
    if echo "$ERROR_MESSAGE" | grep -q "already exists"; then
        echo "ℹ️  queueEnabled attribute already exists in the collection"
        echo "✅ Collection is ready for queue functionality"
        exit 0
    else
        echo "❌ Failed to add queueEnabled attribute:"
        echo "$ERROR_MESSAGE"
        exit 1
    fi
else
    echo "✅ Successfully added queueEnabled attribute to collection"
    echo "📋 Attribute details:"
    echo "$RESPONSE" | jq '.'
    echo ""
    echo "🎉 Collection is now ready for queue functionality!"
    echo "💡 New rooms will have queue enabled by default"
fi