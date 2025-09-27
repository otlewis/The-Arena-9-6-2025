#!/bin/bash

# Update store coins with the appwrite CLI
# Uses the same method we used to create them

echo "🔄 Updating Store Coins to optimized amounts..."
echo ""

# Set environment variables (same as populate script)
export APPWRITE_ENDPOINT="https://cloud.appwrite.io/v1"
export APPWRITE_PROJECT_ID="683a37a8003719978879"
export APPWRITE_DATABASE_ID="arena_db"

# First, let's login with the expect script
echo "📱 Logging into Appwrite..."
./login_appwrite.exp

# Give it a moment for the login to complete
sleep 2

# Function to update document
update_document() {
    local collection_id="$1"
    local doc_id="$2"
    local data="$3"
    local description="$4"

    echo "  Updating $doc_id: $description"

    appwrite databases update-document \
        --database-id "$APPWRITE_DATABASE_ID" \
        --collection-id "$collection_id" \
        --document-id "$doc_id" \
        --data "$data" && echo "    ✅ Updated successfully" || echo "    ❌ Update failed"
}

echo ""
echo "🪙 Updating Coin Packages..."

# Update each coin package with new optimized amounts
update_document "store_coins" "coins_100" \
    '{"coin_package_id":"coins_100","amount":100,"price_display":"$0.99","rc_product_id":"arena_coins_100","sort_order":1,"is_active":true}' \
    "100 coins for $0.99"

update_document "store_coins" "coins_600" \
    '{"coin_package_id":"coins_600","amount":600,"price_display":"$4.99","badge":"Most Popular","rc_product_id":"arena_coins_600","sort_order":2,"is_active":true}' \
    "600 coins for $4.99 (Most Popular)"

update_document "store_coins" "coins_2000" \
    '{"coin_package_id":"coins_2000","amount":2000,"price_display":"$14.99","badge":"Best Value","rc_product_id":"arena_coins_2000","sort_order":3,"is_active":true}' \
    "2,000 coins for $14.99 (Best Value)"

update_document "store_coins" "coins_5000" \
    '{"coin_package_id":"coins_5000","amount":5000,"price_display":"$34.99","badge":"Premium","rc_product_id":"arena_coins_5000","sort_order":4,"is_active":true}' \
    "5,000 coins for $34.99 (Premium)"

echo ""
echo "✅ Store coins updated successfully!"
echo ""
echo "📊 New Optimized Coin Economy:"
echo "├── Starter: 100 coins for $0.99 (1¢ per coin)"
echo "├── Popular: 600 coins for $4.99 (0.83¢ per coin)"
echo "├── Value: 2,000 coins for $14.99 (0.75¢ per coin)"
echo "└── Premium: 5,000 coins for $34.99 (0.7¢ per coin)"
echo ""
echo "💡 Benefits:"
echo "├── 10x faster coin depletion"
echo "├── Gifts feel more meaningful (higher % of balance)"
echo "├── 5-10x higher purchase frequency expected"
echo "└── Better monetization for staff payouts"