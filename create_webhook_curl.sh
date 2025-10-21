#!/bin/bash

# Since we need console-level access to create webhooks,
# this script creates the webhook using your user session

# First, let's get your session cookie from the browser
# You'll need to:
# 1. Open Chrome DevTools (Cmd+Option+I)
# 2. Go to Application tab -> Cookies -> https://cloud.appwrite.io
# 3. Find the cookie named "a_session_console" or similar
# 4. Copy the value

echo "To create the webhook, we need your Appwrite console session cookie."
echo ""
echo "Please follow these steps:"
echo "1. Open https://cloud.appwrite.io in Chrome"
echo "2. Press Cmd+Option+I to open DevTools"
echo "3. Go to Application tab -> Cookies -> https://cloud.appwrite.io"
echo "4. Find the cookie named 'a_session_console' (or similar session cookie)"
echo "5. Copy the cookie value"
echo ""
read -p "Paste the session cookie value here: " SESSION_COOKIE

if [ -z "$SESSION_COOKIE" ]; then
    echo "Error: No session cookie provided"
    exit 1
fi

echo ""
echo "Creating webhook..."

curl -X POST \
  'https://cloud.appwrite.io/v1/projects/683a37a8003719978879/webhooks' \
  -H 'Content-Type: application/json' \
  -H "Cookie: a_session_console=$SESSION_COOKIE" \
  -H 'X-Appwrite-Project: console' \
  -d '{
    "name": "Arena Winner Broadcast",
    "events": ["databases.arena_db.collections.arena_rooms.documents.*.update"],
    "url": "http://n8n.dialecticlabs.com/webhook-test/appwrite-arena-rooms-update",
    "security": false,
    "enabled": true
  }'

echo ""
echo ""
echo "Webhook creation complete! Check the Appwrite console to verify."
