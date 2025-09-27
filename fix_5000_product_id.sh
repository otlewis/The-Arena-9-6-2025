#!/bin/bash

echo "🔧 Fixing arena_coin_5000 product ID in Appwrite..."
echo ""
echo "Please enter your Appwrite API Key:"
read -s API_KEY
echo ""

if [ -z "$API_KEY" ]; then
    echo "❌ API Key is required"
    exit 1
fi

# Update the coins_5000 document to use arena_coin_5000 (no 's')
curl -X PATCH \
    "https://cloud.appwrite.io/v1/databases/arena_db/collections/store_coins/documents/coins_5000" \
    -H "Content-Type: application/json" \
    -H "X-Appwrite-Project: 683a37a8003719978879" \
    -H "X-Appwrite-Key: $API_KEY" \
    -d '{"coin_package_id":"coins_5000","amount":5000,"price_display":"$34.99","badge":"Premium","rc_product_id":"arena_coin_5000","sort_order":4,"is_active":true}'

echo ""
echo "✅ Updated coins_5000 to use arena_coin_5000 (without the 's')"
echo ""
echo "📝 Remember to also update:"
echo "  • RevenueCat product identifier to arena_coin_5000"
echo "  • Any hardcoded references in Flutter code"