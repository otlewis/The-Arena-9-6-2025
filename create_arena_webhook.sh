#!/bin/bash

# Appwrite webhook creation script for Arena Winner Broadcast

PROJECT_ID="683a37a8003719978879"
API_KEY="standard_6776d54c8aeb5d7cdce3743744d30f04bd0a5f13fa2460f5915428fba1f34153045818ddf4e69177df5237e47349e0fbb6ddefb9be1197c318d5b1d6342118824bb46e6ddaa08c0746c2cdc3b8b1cb9ec82b53dffd46dc3b0d5da58c3db219628ecad225d5dc565bc16b40f61fbb2f590d2f895f5eae4d1c33b984b8c36f2235"
WEBHOOK_URL="http://50.21.187.76/webhook-test/appwrite-arena-rooms-update"
ENDPOINT="https://cloud.appwrite.io/v1"

echo "Creating Arena Winner Broadcast webhook..."

curl -X POST \
  "${ENDPOINT}/projects/${PROJECT_ID}/webhooks" \
  -H "Content-Type: application/json" \
  -H "X-Appwrite-Project: ${PROJECT_ID}" \
  -H "X-Appwrite-Key: ${API_KEY}" \
  -d '{
    "name": "Arena Winner Broadcast",
    "events": ["databases.arena_db.collections.arena_rooms.documents.*.update"],
    "url": "'"${WEBHOOK_URL}"'",
    "security": false,
    "enabled": true
  }'

echo ""
echo "Webhook creation complete!"
