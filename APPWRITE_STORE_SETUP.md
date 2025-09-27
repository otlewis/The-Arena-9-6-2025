# Appwrite Store Collections Setup Guide

This guide explains how to manually set up the store configuration collections in your Appwrite console for Arena's data-driven premium store.

## 📋 Collections to Create

### 1. store_config
**Collection ID:** `store_config`
**Name:** Store Configuration

**Attributes:**
- `config_key` (string, size: 50, required)
- `config_value` (string, size: 5000, required)
- `is_active` (boolean, required, default: true)

**Indexes:**
- `config_key_index` (key, ASC on config_key)

**Permissions:**
- Read: Any
- Write: Users (authenticated users can update)

---

### 2. store_subscriptions
**Collection ID:** `store_subscriptions`
**Name:** Store Subscriptions

**Attributes:**
- `subscription_id` (string, size: 50, required)
- `title` (string, size: 100, required)
- `price_display` (string, size: 50, required)
- `eligibility` (string, size: 20, required) // 'age_13_17', 'age_18_plus', 'any_age'
- `features` (string, size: 2000, required) // Comma-separated list
- `badge` (string, size: 50, optional)
- `rc_product_id` (string, size: 100, required) // RevenueCat product identifier
- `sort_order` (integer, required, default: 0)
- `is_active` (boolean, required, default: true)

**Indexes:**
- `subscription_active_sort` (key, ASC on is_active, ASC on sort_order)
- `subscription_eligibility` (key, ASC on eligibility)

**Permissions:**
- Read: Any
- Write: Users

---

### 3. store_coins
**Collection ID:** `store_coins`
**Name:** Store Coins

**Attributes:**
- `coin_package_id` (string, size: 50, required)
- `amount` (integer, required)
- `price_display` (string, size: 50, required)
- `badge` (string, size: 50, optional) // 'Most Popular', 'Best Value', etc.
- `rc_product_id` (string, size: 100, required)
- `sort_order` (integer, required, default: 0)
- `is_active` (boolean, required, default: true)

**Indexes:**
- `coins_active_sort` (key, ASC on is_active, ASC on sort_order)

**Permissions:**
- Read: Any
- Write: Users

---

### 4. store_events
**Collection ID:** `store_events`
**Name:** Store Events

**Attributes:**
- `event_id` (string, size: 50, required)
- `title` (string, size: 100, required)
- `description` (string, size: 500, optional)
- `price_display` (string, size: 50, required)
- `cta_text` (string, size: 50, required) // Call-to-action button text
- `rc_product_id` (string, size: 100, optional) // Optional RevenueCat product
- `start_date` (datetime, optional)
- `end_date` (datetime, optional)
- `sort_order` (integer, required, default: 0)
- `is_active` (boolean, required, default: true)

**Indexes:**
- `events_active_sort` (key, ASC on is_active, ASC on sort_order)
- `events_dates` (key, ASC on start_date, ASC on end_date)

**Permissions:**
- Read: Any
- Write: Users

## 🎯 Sample Data to Add

After creating the collections, add this sample data:

### store_config documents:

```json
{
  "config_key": "teen_plans_enabled",
  "config_value": "true",
  "is_active": true
}

{
  "config_key": "coin_purchases_enabled",
  "config_value": "true",
  "is_active": true
}

{
  "config_key": "events_enabled",
  "config_value": "true",
  "is_active": true
}
```

### store_subscriptions documents:

```json
{
  "subscription_id": "teen_monthly",
  "title": "Teen Plan (13–17)",
  "price_display": "$4.99/mo",
  "eligibility": "age_13_17",
  "features": "Join debates, Ranked profile, Basic analytics, Parental controls",
  "badge": "Requires parent OK",
  "rc_product_id": "arena_teen_monthly",
  "sort_order": 1,
  "is_active": true
}

{
  "subscription_id": "adult_monthly",
  "title": "Adult Plan (18+)",
  "price_display": "$9.99/mo",
  "eligibility": "age_18_plus",
  "features": "Join & host debates, Advanced analytics, Priority queue, Full moderation tools",
  "badge": "Most popular",
  "rc_product_id": "arena_adult_monthly",
  "sort_order": 2,
  "is_active": true
}
```

### store_coins documents:

```json
{
  "coin_package_id": "coins_100",
  "amount": 100,
  "price_display": "$0.99",
  "rc_product_id": "arena_coins_100",
  "sort_order": 1,
  "is_active": true
}

{
  "coin_package_id": "coins_600",
  "amount": 600,
  "price_display": "$4.99",
  "badge": "Most Popular",
  "rc_product_id": "arena_coins_600",
  "sort_order": 2,
  "is_active": true
}

{
  "coin_package_id": "coins_2000",
  "amount": 2000,
  "price_display": "$14.99",
  "badge": "Best Value",
  "rc_product_id": "arena_coins_2000",
  "sort_order": 3,
  "is_active": true
}
```

### store_events documents (optional):

```json
{
  "event_id": "winter_tournament",
  "title": "Winter Debate Tournament",
  "description": "Compete against top debaters for prizes and recognition",
  "price_display": "$5 entry",
  "cta_text": "Join Tournament",
  "start_date": "2025-01-15T00:00:00.000Z",
  "end_date": "2025-02-15T23:59:59.000Z",
  "sort_order": 1,
  "is_active": true
}
```

## 🔧 Setup Steps

1. **Login to Appwrite Console**
   - Go to https://cloud.appwrite.io/console
   - Navigate to your Arena project (`683a37a8003719978879`)

2. **Navigate to Database**
   - Click on "Database" in the left sidebar
   - Select your `arena_db` database

3. **Create Each Collection**
   - Click "Create Collection"
   - Enter the Collection ID and Name
   - Set up attributes as specified above
   - Create the indexes
   - Configure permissions

4. **Add Sample Data**
   - Go to each collection
   - Click "Add Document"
   - Copy and paste the sample JSON data
   - Modify as needed for your pricing strategy

## 🎨 Customization Tips

- **Teen Plan Pricing**: Adjust `price_display` in store_subscriptions
- **Coin Packages**: Add or remove coin packages as needed
- **Features List**: Update the `features` field (comma-separated)
- **Badges**: Use "Most Popular", "Best Value", "Limited Time", etc.
- **Events**: Create seasonal tournaments or special events
- **A/B Testing**: Set `is_active` to false to temporarily disable options

## 🚀 Testing

After setup, the Arena app will automatically:
1. Load store configuration on app launch
2. Show age-appropriate subscription plans
3. Display active coin packages and events
4. Handle RevenueCat integration for purchases

You can update pricing and offerings without requiring an app update! 🎉