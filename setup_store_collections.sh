#!/bin/bash

# Arena Store Collections Setup Script
# Sets up dynamic store configuration collections in Appwrite

set -e

echo "🛒 Setting up Arena Store Collections..."
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

# Function to create collection with error handling
create_collection() {
    local collection_id="$1"
    local name="$2"

    echo "Creating collection: $name ($collection_id)..."

    if appwrite databases create-collection \
        --database-id "$APPWRITE_DATABASE_ID" \
        --collection-id "$collection_id" \
        --name "$name" \
        --permissions 'read("any")' 'write("users")' \
        --document-security true; then
        echo "✅ Collection '$collection_id' created successfully"
    else
        echo "⚠️  Collection '$collection_id' might already exist, continuing..."
    fi
    echo ""
}

# Function to create string attribute
create_string_attr() {
    local collection_id="$1"
    local key="$2"
    local size="$3"
    local required="$4"
    local default_val="${5:-}"

    echo "  Adding string attribute: $key (size: $size, required: $required)"

    if [ -n "$default_val" ]; then
        appwrite databases create-string-attribute \
            --database-id "$APPWRITE_DATABASE_ID" \
            --collection-id "$collection_id" \
            --key "$key" \
            --size "$size" \
            --required "$required" \
            --default "$default_val" || echo "    ⚠️  Attribute might already exist"
    else
        appwrite databases create-string-attribute \
            --database-id "$APPWRITE_DATABASE_ID" \
            --collection-id "$collection_id" \
            --key "$key" \
            --size "$size" \
            --required "$required" || echo "    ⚠️  Attribute might already exist"
    fi
}

# Function to create integer attribute
create_integer_attr() {
    local collection_id="$1"
    local key="$2"
    local required="$3"
    local default_val="${4:-}"

    echo "  Adding integer attribute: $key (required: $required)"

    if [ -n "$default_val" ]; then
        appwrite databases create-integer-attribute \
            --database-id "$APPWRITE_DATABASE_ID" \
            --collection-id "$collection_id" \
            --key "$key" \
            --required "$required" \
            --default "$default_val" || echo "    ⚠️  Attribute might already exist"
    else
        appwrite databases create-integer-attribute \
            --database-id "$APPWRITE_DATABASE_ID" \
            --collection-id "$collection_id" \
            --key "$key" \
            --required "$required" || echo "    ⚠️  Attribute might already exist"
    fi
}

# Function to create boolean attribute
create_boolean_attr() {
    local collection_id="$1"
    local key="$2"
    local required="$3"
    local default_val="${4:-true}"

    echo "  Adding boolean attribute: $key (required: $required, default: $default_val)"

    appwrite databases create-boolean-attribute \
        --database-id "$APPWRITE_DATABASE_ID" \
        --collection-id "$collection_id" \
        --key "$key" \
        --required "$required" \
        --default "$default_val" || echo "    ⚠️  Attribute might already exist"
}

# Function to create datetime attribute
create_datetime_attr() {
    local collection_id="$1"
    local key="$2"
    local required="$3"

    echo "  Adding datetime attribute: $key (required: $required)"

    appwrite databases create-datetime-attribute \
        --database-id "$APPWRITE_DATABASE_ID" \
        --collection-id "$collection_id" \
        --key "$key" \
        --required "$required" || echo "    ⚠️  Attribute might already exist"
}

# Function to create index
create_index() {
    local collection_id="$1"
    local key="$2"
    local type="$3"
    local attributes="$4"

    echo "  Creating index: $key ($type)"

    appwrite databases create-index \
        --database-id "$APPWRITE_DATABASE_ID" \
        --collection-id "$collection_id" \
        --key "$key" \
        --type "$type" \
        --attributes "$attributes" || echo "    ⚠️  Index might already exist"
}

echo "🗂️  Creating Collections..."
echo ""

# 1. Store Config Collection
echo "1️⃣  Store Configuration Collection"
create_collection "store_config" "Store Configuration"

echo "  Adding attributes..."
create_string_attr "store_config" "config_key" 50 true
create_string_attr "store_config" "config_value" 5000 true
create_boolean_attr "store_config" "is_active" true true

echo "  Creating indexes..."
create_index "store_config" "config_key_index" "key" "config_key"

# 2. Store Subscriptions Collection
echo "2️⃣  Store Subscriptions Collection"
create_collection "store_subscriptions" "Store Subscriptions"

echo "  Adding attributes..."
create_string_attr "store_subscriptions" "subscription_id" 50 true
create_string_attr "store_subscriptions" "title" 100 true
create_string_attr "store_subscriptions" "price_display" 50 true
create_string_attr "store_subscriptions" "eligibility" 20 true
create_string_attr "store_subscriptions" "features" 2000 true
create_string_attr "store_subscriptions" "badge" 50 false
create_string_attr "store_subscriptions" "rc_product_id" 100 true
create_integer_attr "store_subscriptions" "sort_order" true 0
create_boolean_attr "store_subscriptions" "is_active" true true

echo "  Creating indexes..."
create_index "store_subscriptions" "subscription_active_sort" "key" "is_active,sort_order"
create_index "store_subscriptions" "subscription_eligibility" "key" "eligibility"

# 3. Store Coins Collection
echo "3️⃣  Store Coins Collection"
create_collection "store_coins" "Store Coins"

echo "  Adding attributes..."
create_string_attr "store_coins" "coin_package_id" 50 true
create_integer_attr "store_coins" "amount" true
create_string_attr "store_coins" "price_display" 50 true
create_string_attr "store_coins" "badge" 50 false
create_string_attr "store_coins" "rc_product_id" 100 true
create_integer_attr "store_coins" "sort_order" true 0
create_boolean_attr "store_coins" "is_active" true true

echo "  Creating indexes..."
create_index "store_coins" "coins_active_sort" "key" "is_active,sort_order"

# 4. Store Events Collection
echo "4️⃣  Store Events Collection"
create_collection "store_events" "Store Events"

echo "  Adding attributes..."
create_string_attr "store_events" "event_id" 50 true
create_string_attr "store_events" "title" 100 true
create_string_attr "store_events" "description" 500 false
create_string_attr "store_events" "price_display" 50 true
create_string_attr "store_events" "cta_text" 50 true
create_string_attr "store_events" "rc_product_id" 100 false
create_datetime_attr "store_events" "start_date" false
create_datetime_attr "store_events" "end_date" false
create_integer_attr "store_events" "sort_order" true 0
create_boolean_attr "store_events" "is_active" true true

echo "  Creating indexes..."
create_index "store_events" "events_active_sort" "key" "is_active,sort_order"
create_index "store_events" "events_dates" "key" "start_date,end_date"

echo ""
echo "✅ All collections created successfully!"
echo ""
echo "🎯 Next steps:"
echo "1. Wait a few moments for attributes to be ready"
echo "2. Run the data population script to add sample data"
echo "3. Test the premium store in the app"
echo ""