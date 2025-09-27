#!/bin/bash

# Arena Store Data Population Script
# Populates store collections with sample data

set -e

echo "🎯 Populating Arena Store with Sample Data..."
echo ""

# Set environment variables
export APPWRITE_ENDPOINT="https://cloud.appwrite.io/v1"
export APPWRITE_PROJECT_ID="683a37a8003719978879"
export APPWRITE_DATABASE_ID="arena_db"

echo "📋 Environment configured:"
echo "  Endpoint: $APPWRITE_ENDPOINT"
echo "  Project: $APPWRITE_PROJECT_ID"
echo "  Database: $APPWRITE_DATABASE_ID"
echo ""

# Function to create document
create_document() {
    local collection_id="$1"
    local data="$2"
    local doc_id="$3"

    echo "  Adding document to $collection_id..."

    if [ -n "$doc_id" ]; then
        appwrite databases create-document \
            --database-id "$APPWRITE_DATABASE_ID" \
            --collection-id "$collection_id" \
            --document-id "$doc_id" \
            --data "$data" || echo "    ⚠️  Document might already exist"
    else
        appwrite databases create-document \
            --database-id "$APPWRITE_DATABASE_ID" \
            --collection-id "$collection_id" \
            --data "$data" || echo "    ⚠️  Document might already exist"
    fi
}

echo "📊 Adding Store Configuration Data..."

# Store Config Documents
create_document "store_config" '{"config_key":"teen_plans_enabled","config_value":"true","is_active":true}' "config_teen_enabled"
create_document "store_config" '{"config_key":"coin_purchases_enabled","config_value":"true","is_active":true}' "config_coins_enabled"
create_document "store_config" '{"config_key":"events_enabled","config_value":"true","is_active":true}' "config_events_enabled"
create_document "store_config" '{"config_key":"store_version","config_value":"1.0.0","is_active":true}' "config_version"

echo ""
echo "📱 Adding Subscription Plans..."

# Store Subscriptions Documents
create_document "store_subscriptions" '{"subscription_id":"teen_monthly","title":"Teen Plan (13–17)","price_display":"$4.99/mo","eligibility":"age_13_17","features":"Join debates, Ranked profile, Basic analytics, Parental controls","badge":"Requires parent OK","rc_product_id":"arena_teen_monthly","sort_order":1,"is_active":true}' "sub_teen_monthly"

create_document "store_subscriptions" '{"subscription_id":"adult_monthly","title":"Adult Plan (18+)","price_display":"$9.99/mo","eligibility":"age_18_plus","features":"Join & host debates, Advanced analytics, Priority queue, Full moderation tools","badge":"Most popular","rc_product_id":"arena_adult_monthly","sort_order":2,"is_active":true}' "sub_adult_monthly"

create_document "store_subscriptions" '{"subscription_id":"adult_yearly","title":"Adult Plan Yearly (18+)","price_display":"$99.99/year","eligibility":"age_18_plus","features":"Join & host debates, Advanced analytics, Priority queue, Full moderation tools, Save 17%","badge":"Best value","rc_product_id":"arena_adult_yearly","sort_order":3,"is_active":true}' "sub_adult_yearly"

echo ""
echo "🪙 Adding Coin Packages..."

# Store Coins Documents
create_document "store_coins" '{"coin_package_id":"coins_100","amount":100,"price_display":"$0.99","rc_product_id":"arena_coins_100","sort_order":1,"is_active":true}' "coins_100"

create_document "store_coins" '{"coin_package_id":"coins_600","amount":600,"price_display":"$4.99","badge":"Most Popular","rc_product_id":"arena_coins_600","sort_order":2,"is_active":true}' "coins_600"

create_document "store_coins" '{"coin_package_id":"coins_2000","amount":2000,"price_display":"$14.99","badge":"Best Value","rc_product_id":"arena_coins_2000","sort_order":3,"is_active":true}' "coins_2000"

create_document "store_coins" '{"coin_package_id":"coins_5000","amount":5000,"price_display":"$34.99","badge":"Premium","rc_product_id":"arena_coins_5000","sort_order":4,"is_active":true}' "coins_5000"

echo ""
echo "🎪 Adding Special Events..."

# Store Events Documents
create_document "store_events" '{"event_id":"winter_tournament_2025","title":"Winter Debate Tournament","description":"Compete against top debaters for prizes and recognition. Weekly matches with elimination rounds.","price_display":"$5 entry","cta_text":"Join Tournament","start_date":"2025-01-15T00:00:00.000Z","end_date":"2025-02-15T23:59:59.000Z","sort_order":1,"is_active":true}' "event_winter_tournament"

create_document "store_events" '{"event_id":"valentines_special_2025","title":"Valentine'\''s Day Debate Night","description":"Special themed debates about love, relationships, and society. Fun prizes for participants!","price_display":"$3 ticket","cta_text":"Get Ticket","start_date":"2025-02-14T19:00:00.000Z","end_date":"2025-02-14T23:00:00.000Z","sort_order":2,"is_active":true}' "event_valentines"

create_document "store_events" '{"event_id":"spring_championship_2025","title":"Spring Championship Series","description":"The ultimate debate championship! Monthly matches leading to the grand finale.","price_display":"$10 season pass","cta_text":"Enter Championship","start_date":"2025-03-01T00:00:00.000Z","end_date":"2025-05-31T23:59:59.000Z","sort_order":3,"is_active":false}' "event_spring_championship"

echo ""
echo "✅ Sample data populated successfully!"
echo ""
echo "🎯 What's been added:"
echo "  📊 4 configuration settings"
echo "  📱 3 subscription plans (teen + adult monthly/yearly)"
echo "  🪙 4 coin packages (100 to 5000 coins)"
echo "  🎪 3 special events (tournaments and themed nights)"
echo ""
echo "🚀 Ready to test! The Arena premium store will now:"
echo "  • Show teen plans for users 13-17"
echo "  • Show adult plans for users 18+"
echo "  • Display coin packages with badges"
echo "  • Show active special events"
echo ""
echo "💡 You can now modify pricing, disable offerings, or add new items"
echo "   directly in the Appwrite console without app updates!"
echo ""