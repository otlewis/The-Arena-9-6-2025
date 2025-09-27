#!/bin/bash

# Arena Store Collections Setup via API
# Creates collections using Appwrite REST API

set -e

echo "🛒 Setting up Arena Store Collections via API..."
echo ""

# Configuration
APPWRITE_ENDPOINT="https://cloud.appwrite.io/v1"
PROJECT_ID="683a37a8003719978879"
DATABASE_ID="arena_db"

# You'll need to replace this with your actual API key
# Get it from: https://cloud.appwrite.io/console/project-683a37a8003719978879/overview/keys
API_KEY="YOUR_API_KEY_HERE"

if [ "$API_KEY" = "YOUR_API_KEY_HERE" ]; then
    echo "❌ Please set your API key in this script"
    echo "Get it from: https://cloud.appwrite.io/console/project-$PROJECT_ID/overview/keys"
    exit 1
fi

# Function to create collection
create_collection() {
    local collection_id="$1"
    local name="$2"

    echo "📋 Creating collection: $name ($collection_id)"

    curl -s -X POST \
        "$APPWRITE_ENDPOINT/databases/$DATABASE_ID/collections" \
        -H "X-Appwrite-Project: $PROJECT_ID" \
        -H "X-Appwrite-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"collectionId\": \"$collection_id\",
            \"name\": \"$name\",
            \"permissions\": [\"read(\\\"any\\\")\", \"write(\\\"users\\\")\"],
            \"documentSecurity\": true
        }" > /tmp/collection_response.json

    if grep -q "error" /tmp/collection_response.json; then
        echo "  ⚠️ Collection might already exist"
        cat /tmp/collection_response.json
    else
        echo "  ✅ Collection created successfully"
    fi
    echo ""
}

# Function to create string attribute
create_string_attribute() {
    local collection_id="$1"
    local key="$2"
    local size="$3"
    local required="$4"
    local default_value="$5"

    echo "  Adding string attribute: $key"

    data="{\"key\":\"$key\",\"size\":$size,\"required\":$required"
    if [ -n "$default_value" ] && [ "$default_value" != "null" ]; then
        data="$data,\"default\":\"$default_value\""
    fi
    data="$data}"

    curl -s -X POST \
        "$APPWRITE_ENDPOINT/databases/$DATABASE_ID/collections/$collection_id/attributes/string" \
        -H "X-Appwrite-Project: $PROJECT_ID" \
        -H "X-Appwrite-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "$data" > /tmp/attr_response.json

    if grep -q "error" /tmp/attr_response.json; then
        echo "    ⚠️ Attribute might already exist"
    else
        echo "    ✅ Attribute created"
    fi
}

# Function to create integer attribute
create_integer_attribute() {
    local collection_id="$1"
    local key="$2"
    local required="$3"
    local default_value="$4"

    echo "  Adding integer attribute: $key"

    data="{\"key\":\"$key\",\"required\":$required"
    if [ -n "$default_value" ] && [ "$default_value" != "null" ]; then
        data="$data,\"default\":$default_value"
    fi
    data="$data}"

    curl -s -X POST \
        "$APPWRITE_ENDPOINT/databases/$DATABASE_ID/collections/$collection_id/attributes/integer" \
        -H "X-Appwrite-Project: $PROJECT_ID" \
        -H "X-Appwrite-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "$data" > /tmp/attr_response.json

    if grep -q "error" /tmp/attr_response.json; then
        echo "    ⚠️ Attribute might already exist"
    else
        echo "    ✅ Attribute created"
    fi
}

# Function to create boolean attribute
create_boolean_attribute() {
    local collection_id="$1"
    local key="$2"
    local required="$3"
    local default_value="$4"

    echo "  Adding boolean attribute: $key"

    curl -s -X POST \
        "$APPWRITE_ENDPOINT/databases/$DATABASE_ID/collections/$collection_id/attributes/boolean" \
        -H "X-Appwrite-Project: $PROJECT_ID" \
        -H "X-Appwrite-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"key\":\"$key\",\"required\":$required,\"default\":$default_value}" > /tmp/attr_response.json

    if grep -q "error" /tmp/attr_response.json; then
        echo "    ⚠️ Attribute might already exist"
    else
        echo "    ✅ Attribute created"
    fi
}

# Function to create datetime attribute
create_datetime_attribute() {
    local collection_id="$1"
    local key="$2"
    local required="$3"

    echo "  Adding datetime attribute: $key"

    curl -s -X POST \
        "$APPWRITE_ENDPOINT/databases/$DATABASE_ID/collections/$collection_id/attributes/datetime" \
        -H "X-Appwrite-Project: $PROJECT_ID" \
        -H "X-Appwrite-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"key\":\"$key\",\"required\":$required}" > /tmp/attr_response.json

    if grep -q "error" /tmp/attr_response.json; then
        echo "    ⚠️ Attribute might already exist"
    else
        echo "    ✅ Attribute created"
    fi
}

echo "🗂️ Creating Collections..."
echo ""

# 1. Store Config Collection
create_collection "store_config" "Store Configuration"
sleep 2
create_string_attribute "store_config" "config_key" 50 true
sleep 1
create_string_attribute "store_config" "config_value" 5000 true
sleep 1
create_boolean_attribute "store_config" "is_active" true true

echo ""

# 2. Store Subscriptions Collection
create_collection "store_subscriptions" "Store Subscriptions"
sleep 2
create_string_attribute "store_subscriptions" "subscription_id" 50 true
sleep 1
create_string_attribute "store_subscriptions" "title" 100 true
sleep 1
create_string_attribute "store_subscriptions" "price_display" 50 true
sleep 1
create_string_attribute "store_subscriptions" "eligibility" 20 true
sleep 1
create_string_attribute "store_subscriptions" "features" 2000 true
sleep 1
create_string_attribute "store_subscriptions" "badge" 50 false
sleep 1
create_string_attribute "store_subscriptions" "rc_product_id" 100 true
sleep 1
create_integer_attribute "store_subscriptions" "sort_order" true 0
sleep 1
create_boolean_attribute "store_subscriptions" "is_active" true true

echo ""

# 3. Store Coins Collection
create_collection "store_coins" "Store Coins"
sleep 2
create_string_attribute "store_coins" "coin_package_id" 50 true
sleep 1
create_integer_attribute "store_coins" "amount" true
sleep 1
create_string_attribute "store_coins" "price_display" 50 true
sleep 1
create_string_attribute "store_coins" "badge" 50 false
sleep 1
create_string_attribute "store_coins" "rc_product_id" 100 true
sleep 1
create_integer_attribute "store_coins" "sort_order" true 0
sleep 1
create_boolean_attribute "store_coins" "is_active" true true

echo ""

# 4. Store Events Collection
create_collection "store_events" "Store Events"
sleep 2
create_string_attribute "store_events" "event_id" 50 true
sleep 1
create_string_attribute "store_events" "title" 100 true
sleep 1
create_string_attribute "store_events" "description" 500 false
sleep 1
create_string_attribute "store_events" "price_display" 50 true
sleep 1
create_string_attribute "store_events" "cta_text" 50 true
sleep 1
create_string_attribute "store_events" "rc_product_id" 100 false
sleep 1
create_datetime_attribute "store_events" "start_date" false
sleep 1
create_datetime_attribute "store_events" "end_date" false
sleep 1
create_integer_attribute "store_events" "sort_order" true 0
sleep 1
create_boolean_attribute "store_events" "is_active" true true

echo ""
echo "✅ All collections and attributes created!"
echo ""
echo "🎯 Next steps:"
echo "1. Run the populate_store_data_api.sh script to add sample data"
echo "2. Check the collections in your Appwrite console"
echo "3. Test the premium store in your Arena app"
echo ""