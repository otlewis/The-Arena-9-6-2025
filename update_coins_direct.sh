#!/bin/bash

# Direct update script for store_coins collection
# This updates the coin amounts to the optimized 10x lower values

echo "🔄 Updating Store Coins Collection..."
echo ""
echo "Please enter your Appwrite API Key (get it from Console > Settings > API Keys):"
read -s API_KEY
echo ""

if [ -z "$API_KEY" ]; then
    echo "❌ API Key is required. Get it from:"
    echo "   https://cloud.appwrite.io/console/project-683a37a8003719978879/settings/api-keys"
    exit 1
fi

# Appwrite configuration
ENDPOINT="https://cloud.appwrite.io/v1"
PROJECT_ID="683a37a8003719978879"
DATABASE_ID="arena_db"
COLLECTION_ID="store_coins"

# Function to update a document
update_document() {
    local doc_id=$1
    local data=$2
    local description=$3

    echo "Updating $doc_id: $description"

    response=$(curl -s -X PATCH \
        "$ENDPOINT/databases/$DATABASE_ID/collections/$COLLECTION_ID/documents/$doc_id" \
        -H "Content-Type: application/json" \
        -H "X-Appwrite-Project: $PROJECT_ID" \
        -H "X-Appwrite-Key: $API_KEY" \
        -d "$data")

    if echo "$response" | grep -q "amount"; then
        echo "✅ Successfully updated $doc_id"
    else
        echo "❌ Failed to update $doc_id"
        echo "   Response: $response"
    fi
    echo ""
}

# Update each coin package
update_document "coins_100" \
    '{"coin_package_id":"coins_100","amount":100,"price_display":"$0.99","rc_product_id":"arena_coins_100","sort_order":1,"is_active":true}' \
    "100 coins for $0.99 (no badge)"

update_document "coins_600" \
    '{"coin_package_id":"coins_600","amount":600,"price_display":"$4.99","badge":"Most Popular","rc_product_id":"arena_coins_600","sort_order":2,"is_active":true}' \
    "600 coins for $4.99 (Most Popular)"

update_document "coins_2000" \
    '{"coin_package_id":"coins_2000","amount":2000,"price_display":"$14.99","badge":"Best Value","rc_product_id":"arena_coins_2000","sort_order":3,"is_active":true}' \
    "2,000 coins for $14.99 (Best Value)"

update_document "coins_5000" \
    '{"coin_package_id":"coins_5000","amount":5000,"price_display":"$34.99","badge":"Premium","rc_product_id":"arena_coins_5000","sort_order":4,"is_active":true}' \
    "5,000 coins for $34.99 (Premium)"

echo "📊 Update Complete! New Coin Economy:"
echo "├── Starter: 100 coins for \$0.99 (1¢ per coin)"
echo "├── Popular: 600 coins for \$4.99 (0.83¢ per coin)"
echo "├── Value: 2,000 coins for \$14.99 (0.75¢ per coin)"
echo "└── Premium: 5,000 coins for \$34.99 (0.7¢ per coin)"
echo ""
echo "💡 Benefits:"
echo "├── 10x faster coin depletion"
echo "├── Gifts feel more meaningful"
echo "├── 5-10x higher purchase frequency"
echo "└── Better staff monetization"