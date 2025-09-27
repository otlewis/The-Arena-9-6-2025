#!/bin/bash

# Update store_coins collection with optimized coin amounts

echo "🔄 Updating Store Coins with optimized amounts..."
echo ""

# Function to update a coin package
update_coin_package() {
    local doc_id=$1
    local amount=$2
    local price=$3
    local badge=$4
    local sort_order=$5
    local rc_product=$6

    echo "Updating $doc_id: $amount coins for $price"

    # Construct the data JSON
    if [ -z "$badge" ]; then
        data="{\"coin_package_id\":\"$doc_id\",\"amount\":$amount,\"price_display\":\"$price\",\"rc_product_id\":\"$rc_product\",\"sort_order\":$sort_order,\"is_active\":true}"
    else
        data="{\"coin_package_id\":\"$doc_id\",\"amount\":$amount,\"price_display\":\"$price\",\"badge\":\"$badge\",\"rc_product_id\":\"$rc_product\",\"sort_order\":$sort_order,\"is_active\":true}"
    fi

    # Update using appwrite CLI or curl
    curl -X PATCH \
        "https://cloud.appwrite.io/v1/databases/arena_db/collections/store_coins/documents/$doc_id" \
        -H "Content-Type: application/json" \
        -H "X-Appwrite-Project: 683a37a8003719978879" \
        -H "X-Appwrite-Key: YOUR_API_KEY_HERE" \
        -d "$data"

    echo ""
}

echo "⚠️  NOTE: You need to add your Appwrite API key to this script"
echo "Get it from: Appwrite Console > Settings > API Keys"
echo ""
echo "Once you have the API key, update the script and run it again."
echo ""
echo "The updates will be:"
echo "├── coins_100: 100 coins for \$0.99 (no badge)"
echo "├── coins_600: 600 coins for \$4.99 (Most Popular)"
echo "├── coins_2000: 2,000 coins for \$14.99 (Best Value)"
echo "└── coins_5000: 5,000 coins for \$34.99 (Premium)"

# Uncomment these lines after adding your API key:
# update_coin_package "coins_100" 100 "\$0.99" "" 1 "arena_coins_100"
# update_coin_package "coins_600" 600 "\$4.99" "Most Popular" 2 "arena_coins_600"
# update_coin_package "coins_2000" 2000 "\$14.99" "Best Value" 3 "arena_coins_2000"
# update_coin_package "coins_5000" 5000 "\$34.99" "Premium" 4 "arena_coins_5000"

echo ""
echo "📊 Benefits of new structure:"
echo "├── Faster depletion = More frequent purchases"
echo "├── Gifts feel more meaningful (higher % of balance)"
echo "├── 5-10x higher purchase frequency expected"
echo "└── Better monetization for staff payouts"