# HubSpot Manual Property Creation Guide

## Quick Setup - Essential 20 Properties (30 minutes)

Go to: **Settings → Data Management → Properties → Create property → Contact properties**

---

### 1. Arena Identity (Group: Arena Info)

| Label | Internal Name | Type | Field Type |
|-------|---------------|------|------------|
| Arena User ID | arena_user_id | Single-line text | Text |
| Arena Username | arena_username | Single-line text | Text |
| Arena Signup Date | arena_signup_date | Date picker | Date |

---

### 2. Activity Metrics (Group: Arena Metrics)

| Label | Internal Name | Type | Field Type |
|-------|---------------|------|------------|
| Total Debates | arena_total_debates | Number | Number |
| Total Wins | arena_total_wins | Number | Number |
| Total Losses | arena_total_losses | Number | Number |
| Win Rate (%) | arena_win_rate | Number | Number |
| Last Activity Date | arena_last_activity_date | Date picker | Date |
| Days Since Last Activity | arena_days_since_last_activity | Number | Number |

---

### 3. Engagement (Group: Arena Metrics)

| Label | Internal Name | Type | Field Type | Options |
|-------|---------------|------|------------|---------|
| Engagement Score (0-100) | arena_engagement_score | Number | Number | |
| Lifecycle Stage | arena_lifecycle_stage | Dropdown select | Select | New, Active, Cooling, Inactive, At Risk, Churned |
| User Tier | arena_user_tier | Dropdown select | Select | Bronze, Silver, Gold, Platinum, Diamond |

---

### 4. Subscription (Group: Arena Monetization)

| Label | Internal Name | Type | Field Type | Options |
|-------|---------------|------|------------|---------|
| Is Premium | arena_is_premium | Single checkbox | Checkbox | |
| Premium Type | arena_premium_type | Dropdown select | Select | None, Monthly, Yearly, Lifetime |
| Premium Expiry Date | arena_premium_expiry | Date picker | Date | |
| Coin Balance | arena_coin_balance | Number | Number | |
| Lifetime Value ($) | arena_lifetime_value | Number | Number | |

---

### 5. Roles (Group: Arena Roles)

| Label | Internal Name | Type | Field Type |
|-------|---------------|------|------------|
| Is Moderator | arena_is_moderator | Single checkbox | Checkbox |
| Is Judge | arena_is_judge | Single checkbox | Checkbox |

---

### 6. Sync (Group: Arena Sync)

| Label | Internal Name | Type | Field Type |
|-------|---------------|------|------------|
| Last Sync Date | arena_last_sync_date | Date picker | Date |

---

## Instructions for Each Property:

1. Click **"Create property"**
2. Select **"Contact properties"**
3. Fill in:
   - **Label**: Copy from "Label" column
   - **Internal name**: Copy from "Internal Name" column
   - **Group**: Create new groups as needed (Arena Info, Arena Metrics, Arena Monetization, Arena Roles, Arena Sync)
   - **Field type**: Select from "Field Type" column
   - **Type**: Select from "Type" column
4. For dropdown selects, add the options listed
5. Click **"Create"**
6. Repeat for all properties

---

## After Creating These 20:

Once these essential properties are created, we can test the integration. The remaining 20 properties can be added later as needed.

---

## Complete List (40 Properties Total)

If you want to create all 40 properties, refer to the `create_hubspot_properties.js` script for the complete list.
