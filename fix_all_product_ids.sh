#!/bin/bash

echo "🔧 Fixing ALL product IDs in Appwrite store_coins..."
echo ""
echo "Please enter your Appwrite API Key:"
read -s API_KEY
echo ""

if [ -z "$API_KEY" ]; then
    echo "❌ API Key is required"
    exit 1
fi

ENDPOINT="https://cloud.appwrite.io/v1"
PROJECT_ID="683a37a8003719978879"

echo "Updating coins_100..."
curl -X PATCH \
    "$ENDPOINT/databases/arena_db/collections/store_coins/documents/coins_100" \
    -H "Content-Type: application/json" \
    -H "X-Appwrite-Project: $PROJECT_ID" \
    -H "X-Appwrite-Key: $API_KEY" \
    -d '{"rc_product_id":"arena_coins_100"}'

echo ""
echo "Updating coins_600..."
curl -X PATCH \
    "$ENDPOINT/databases/arena_db/collections/store_coins/documents/coins_600" \
    -H "Content-Type: application/json" \
    -H "X-Appwrite-Project: $PROJECT_ID" \
    -H "X-Appwrite-Key: $API_KEY" \
    -d '{"rc_product_id":"arena_coins_600"}'

echo ""
echo "Updating coins_2000..."
curl -X PATCH \
    "$ENDPOINT/databases/arena_db/collections/store_coins/documents/coins_2000" \
    -H "Content-Type: application/json" \
    -H "X-Appwrite-Project: $PROJECT_ID" \
    -H "X-Appwrite-Key: $API_KEY" \
    -d '{"rc_product_id":"arena_coins_2000"}'

echo ""
echo "Updating coins_5000..."
curl -X PATCH \
    "$ENDPOINT/databases/arena_db/collections/store_coins/documents/coins_5000" \
    -H "Content-Type: application/json" \
    -H "X-Appwrite-Project: $PROJECT_ID" \
    -H "X-Appwrite-Key: $API_KEY" \
    -d '{"rc_product_id":"arena_coin_5000"}'

echo ""
echo "✅ All product IDs updated!"
echo ""
echo "📝 New mappings:"
echo "  coins_100 → arena_coins_100"
echo "  coins_600 → arena_coins_600"
echo "  coins_2000 → arena_coins_2000"
echo "  coins_5000 → arena_coin_5000 (no 's')"
echo ""
echo "🔄 Restart your app to test purchases!"