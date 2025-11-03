# HubSpot Contact Property Mapping for Arena DTD

## Overview
This document maps Arena DTD user fields to HubSpot CRM contact properties. All custom properties must be created in HubSpot before the integration can function.

## Standard HubSpot Properties (Built-in)

| HubSpot Property | Arena Field | Type | Description |
|-----------------|-------------|------|-------------|
| `email` | `email` | Email | User's email address (unique identifier) |
| `firstname` | `name` (parsed) | Text | User's first name |
| `lastname` | `name` (parsed) | Text | User's last name |
| `phone` | N/A | Phone | Optional phone number |
| `lifecyclestage` | Calculated | Dropdown | lead/subscriber/customer |
| `hs_lead_status` | Calculated | Dropdown | NEW/ACTIVE/CHURNED |

## Custom Contact Properties (Must Create in HubSpot)

### Core Identity

| HubSpot Property | Arena Field | Type | Description |
|-----------------|-------------|------|-------------|
| `arena_user_id` | `id` | Text | Appwrite user ID (CRITICAL - must be unique) |
| `arena_username` | `name` | Text | Full display name |
| `arena_avatar_url` | `avatar` | Text | Profile image URL |
| `arena_bio` | `bio` | Multi-line text | User biography |
| `arena_location` | `location` | Text | User location |
| `arena_website` | `website` | Text | Personal website |

### Social Media Links

| HubSpot Property | Arena Field | Type | Description |
|-----------------|-------------|------|-------------|
| `arena_twitter_handle` | `xHandle` | Text | Twitter/X handle |
| `arena_linkedin_handle` | `linkedinHandle` | Text | LinkedIn profile |
| `arena_youtube_handle` | `youtubeHandle` | Text | YouTube channel |
| `arena_facebook_handle` | `facebookHandle` | Text | Facebook profile |
| `arena_instagram_handle` | `instagramHandle` | Text | Instagram handle |

### Engagement Metrics

| HubSpot Property | Arena Field | Type | Description |
|-----------------|-------------|------|-------------|
| `arena_total_debates` | `totalDebates` | Number | Total debates participated in |
| `arena_total_wins` | `totalWins` | Number | Total debates won |
| `arena_total_losses` | `totalLosses` | Number | Total debates lost |
| `arena_win_rate` | Calculated | Number | (totalWins / totalDebates) * 100 |
| `arena_total_rooms_created` | `totalRoomsCreated` | Number | Rooms user created |
| `arena_total_rooms_joined` | `totalRoomsJoined` | Number | Rooms user joined |
| `arena_reputation_percentage` | `reputationPercentage` | Number | 0-100 reputation score |
| `arena_reputation_points` | `reputation` | Number | Reputation points earned |

### Economic Data

| HubSpot Property | Arena Field | Type | Description |
|-----------------|-------------|------|-------------|
| `arena_coin_balance` | `coinBalance` | Number | Current coin balance |
| `arena_total_gifts_sent` | `totalGiftsSent` | Number | Total gifts sent to others |
| `arena_total_gifts_received` | `totalGiftsReceived` | Number | Total gifts received |
| `arena_lifetime_value` | Calculated | Currency | Total money spent (subscriptions + purchases) |

### Activity Status

| HubSpot Property | Arena Field | Type | Description |
|-----------------|-------------|------|-------------|
| `arena_last_activity_date` | Calculated | Date | Last time user was active |
| `arena_last_debate_date` | Calculated | Date | Last debate participation |
| `arena_signup_date` | `createdAt` | Date | Account creation date |
| `arena_days_since_last_activity` | Calculated | Number | Days since last login |
| `arena_activity_status` | Calculated | Dropdown | ACTIVE/INACTIVE_7D/INACTIVE_14D/INACTIVE_30D/CHURNED |

### Role & Status

| HubSpot Property | Arena Field | Type | Description |
|-----------------|-------------|------|-------------|
| `arena_is_verified` | `isVerified` | Checkbox | Email verified status |
| `arena_is_moderator` | `isAvailableAsModerator` | Checkbox | Available as moderator |
| `arena_is_judge` | `isAvailableAsJudge` | Checkbox | Available as judge |
| `arena_is_super_mod` | Calculated | Checkbox | Super moderator status |
| `arena_is_public_profile` | `isPublicProfile` | Checkbox | Public profile visibility |
| `arena_is_banned` | `isBanned` | Checkbox | Account banned status |
| `arena_ban_reason` | `banReason` | Text | Reason for ban |
| `arena_banned_at` | `bannedAt` | Date | Date of ban |

### Subscription Data

| HubSpot Property | Arena Field | Type | Description |
|-----------------|-------------|------|-------------|
| `arena_is_premium` | `isPremium` | Checkbox | Premium subscriber |
| `arena_premium_type` | `premiumType` | Dropdown | FREE/MONTHLY/YEARLY |
| `arena_premium_expiry` | `premiumExpiry` | Date | Subscription expiration date |
| `arena_is_test_subscription` | `isTestSubscription` | Checkbox | Test/trial subscription |
| `arena_subscription_status` | Calculated | Dropdown | ACTIVE/EXPIRING_SOON/EXPIRED/NEVER |

### Interests & Preferences

| HubSpot Property | Arena Field | Type | Description |
|-----------------|-------------|------|-------------|
| `arena_interests` | `interests` | Multi-checkbox | User interests (politics, science, etc.) |
| `arena_joined_clubs` | `joinedClubs` | Text | Comma-separated club IDs |
| `arena_notification_preferences` | `preferences` | JSON | Notification settings |

### Challenge Activity

| HubSpot Property | Arena Field | Calculated | Description |
|-----------------|-------------|------------|-------------|
| `arena_challenges_sent` | Query | Number | Total challenges sent |
| `arena_challenges_received` | Query | Number | Total challenges received |
| `arena_challenges_accepted` | Query | Number | Challenges accepted |
| `arena_challenges_declined` | Query | Number | Challenges declined |
| `arena_challenge_acceptance_rate` | Calculated | Number | (accepted / received) * 100 |

### Engagement Scores

| HubSpot Property | Calculation | Type | Description |
|-----------------|-------------|------|-------------|
| `arena_engagement_score` | Algorithm | Number | 0-100 overall engagement |
| `arena_debate_frequency` | Calculated | Dropdown | DAILY/WEEKLY/MONTHLY/RARELY |
| `arena_user_tier` | Calculated | Dropdown | BRONZE/SILVER/GOLD/PLATINUM/DIAMOND |
| `arena_churn_risk_score` | Algorithm | Number | 0-100 likelihood to churn |

## HubSpot Tags (Contact Lists)

These will be used for segmentation and email campaigns:

### Lifecycle Tags
- `arena-new-user` - Signed up < 7 days ago
- `arena-active-user` - Active in last 7 days
- `arena-power-user` - 20+ debates
- `arena-inactive-7d` - No activity in 7 days
- `arena-inactive-14d` - No activity in 14 days
- `arena-inactive-30d` - No activity in 30 days
- `arena-churned` - No activity in 90+ days

### Role Tags
- `arena-debater` - Participated in debates
- `arena-moderator` - Available as moderator
- `arena-judge` - Available as judge
- `arena-super-mod` - Super moderator
- `arena-creator` - Created rooms

### Subscription Tags
- `arena-free-user` - Free tier
- `arena-premium-monthly` - Monthly subscriber
- `arena-premium-yearly` - Yearly subscriber
- `arena-trial-user` - In trial period
- `arena-expired-subscriber` - Subscription expired
- `arena-at-risk-subscriber` - Expiring in 7 days

### Engagement Tags
- `arena-first-debate` - Completed 1 debate
- `arena-10-debates` - Completed 10 debates
- `arena-50-debates` - Completed 50 debates
- `arena-100-debates` - Completed 100 debates
- `arena-winner` - Won 5+ debates
- `arena-champion` - Won 20+ debates

### Behavior Tags
- `arena-challenge-sender` - Actively sends challenges
- `arena-challenge-acceptor` - Accepts most challenges
- `arena-challenge-avoider` - Declines most challenges
- `arena-room-creator` - Creates debate rooms
- `arena-spectator` - Watches but doesn't debate
- `arena-gift-giver` - Sends gifts frequently

### Status Tags
- `arena-verified` - Email verified
- `arena-banned` - Account banned
- `arena-at-risk` - High churn risk
- `arena-vip` - Top 5% by engagement

## HubSpot Deal Properties (for Subscriptions & Partnerships)

### Subscription Deals

| HubSpot Property | Arena Field | Type | Description |
|-----------------|-------------|------|-------------|
| `dealname` | Auto-generated | Text | "Arena Pro - [Username]" |
| `amount` | Subscription price | Currency | Monthly or yearly amount |
| `dealstage` | Status | Dropdown | TRIAL/ACTIVE/RENEWAL_DUE/CHURNED |
| `closedate` | `premiumExpiry` | Date | Subscription end date |
| `subscription_type` | `premiumType` | Dropdown | MONTHLY/YEARLY |
| `original_signup_date` | First subscription | Date | When first subscribed |
| `renewal_count` | Calculated | Number | How many times renewed |

### Partnership Deals (Sponsors/Brands)

| HubSpot Property | Manual Entry | Type | Description |
|-----------------|-------------|------|-------------|
| `dealname` | Manual | Text | "[Company Name] - Sponsorship" |
| `amount` | Manual | Currency | Sponsorship value |
| `dealstage` | Manual | Dropdown | LEAD/CONTACTED/PROPOSAL/NEGOTIATION/CLOSED |
| `closedate` | Manual | Date | Expected close date |
| `partnership_type` | Manual | Dropdown | SPONSOR/MEDIA/EDUCATOR/PLATFORM |
| `contract_length` | Manual | Number | Months of partnership |
| `contract_start_date` | Manual | Date | Partnership start |
| `contract_end_date` | Manual | Date | Partnership end |
| `renewal_status` | Manual | Dropdown | AUTO/MANUAL/NOT_RENEWING |

## Calculated Fields Logic

### `arena_win_rate`
```javascript
if (arena_total_debates > 0) {
  arena_win_rate = (arena_total_wins / arena_total_debates) * 100;
} else {
  arena_win_rate = 0;
}
```

### `arena_activity_status`
```javascript
if (arena_days_since_last_activity <= 7) return "ACTIVE";
if (arena_days_since_last_activity <= 14) return "INACTIVE_7D";
if (arena_days_since_last_activity <= 30) return "INACTIVE_14D";
if (arena_days_since_last_activity <= 90) return "INACTIVE_30D";
return "CHURNED";
```

### `arena_engagement_score`
```javascript
// 0-100 score based on multiple factors
let score = 0;

// Debate frequency (40 points)
if (arena_total_debates >= 50) score += 40;
else if (arena_total_debates >= 20) score += 30;
else if (arena_total_debates >= 10) score += 20;
else if (arena_total_debates >= 5) score += 10;

// Recency (30 points)
if (arena_days_since_last_activity <= 1) score += 30;
else if (arena_days_since_last_activity <= 7) score += 20;
else if (arena_days_since_last_activity <= 14) score += 10;

// Win rate (15 points)
if (arena_win_rate >= 60) score += 15;
else if (arena_win_rate >= 40) score += 10;
else if (arena_win_rate >= 20) score += 5;

// Premium subscriber (15 points)
if (arena_is_premium) score += 15;

return score;
```

### `arena_user_tier`
```javascript
if (arena_engagement_score >= 80) return "DIAMOND";
if (arena_engagement_score >= 60) return "PLATINUM";
if (arena_engagement_score >= 40) return "GOLD";
if (arena_engagement_score >= 20) return "SILVER";
return "BRONZE";
```

### `arena_churn_risk_score`
```javascript
// 0-100 score (higher = more likely to churn)
let risk = 0;

// Inactivity (50 points)
if (arena_days_since_last_activity >= 30) risk += 50;
else if (arena_days_since_last_activity >= 14) risk += 30;
else if (arena_days_since_last_activity >= 7) risk += 15;

// Low engagement (30 points)
if (arena_total_debates < 5) risk += 30;
else if (arena_total_debates < 10) risk += 15;

// Expiring subscription (20 points)
if (arena_is_premium && daysUntilExpiry <= 7) risk += 20;
else if (arena_is_premium && daysUntilExpiry <= 30) risk += 10;

return risk;
```

### `lifecyclestage`
```javascript
if (arena_is_premium) return "customer";
if (arena_total_debates >= 5) return "subscriber";
return "lead";
```

## Data Sync Frequency

| Property Type | Sync Method | Frequency |
|--------------|-------------|-----------|
| Core identity | Real-time webhook | On change |
| Engagement metrics | Real-time webhook | On debate completion |
| Activity status | Scheduled job | Daily at 9 AM |
| Calculated fields | Scheduled job | Daily at 9 AM |
| Subscription data | Real-time webhook | On subscription change |
| Tags | Real-time webhook + scheduled | On change + daily review |

## HubSpot API Endpoints Used

### Contacts API
- `POST /crm/v3/objects/contacts` - Create contact
- `PATCH /crm/v3/objects/contacts/{contactId}` - Update contact
- `GET /crm/v3/objects/contacts/{contactId}` - Get contact
- `POST /crm/v3/objects/contacts/search` - Search contacts by arena_user_id
- `POST /crm/v3/objects/contacts/batch/update` - Bulk update (max 100)

### Lists API
- `POST /contacts/v1/lists/{listId}/add` - Add contact to list (tag)
- `POST /contacts/v1/lists/{listId}/remove` - Remove contact from list

### Timeline API
- `POST /crm/v3/timeline/events` - Add activity timeline event

### Deals API
- `POST /crm/v3/objects/deals` - Create deal
- `PATCH /crm/v3/objects/deals/{dealId}` - Update deal

## Property Creation Script

For easy setup, here's the HubSpot property creation data:

```json
{
  "properties": [
    {
      "name": "arena_user_id",
      "label": "Arena User ID",
      "type": "string",
      "fieldType": "text",
      "groupName": "arena_integration",
      "description": "Unique Appwrite user ID from Arena app",
      "hasUniqueValue": true
    },
    {
      "name": "arena_total_debates",
      "label": "Total Debates",
      "type": "number",
      "fieldType": "number",
      "groupName": "arena_engagement"
    },
    {
      "name": "arena_total_wins",
      "label": "Total Wins",
      "type": "number",
      "fieldType": "number",
      "groupName": "arena_engagement"
    }
    // ... (see separate property creation script)
  ]
}
```

See `hubspot-property-setup.json` for the complete property creation script.

## Data Privacy & GDPR

### User Data Rights
- **Right to Access**: Users can request their HubSpot data via admin dashboard
- **Right to Deletion**: Deleting Arena account triggers HubSpot contact deletion
- **Right to Opt-out**: Users can opt out of marketing emails in preferences
- **Data Portability**: Users can export their data from admin panel

### Data Retention
- Active users: Indefinite
- Inactive users (90+ days): 1 year then anonymize
- Deleted accounts: 30-day grace period, then permanent deletion
- Email engagement data: 2 years

### Compliance
- Only sync data necessary for CRM functionality
- Obtain consent for marketing emails
- Respect email unsubscribe requests
- Log all data sync operations for audit trail

## Testing Checklist

- [ ] Create test contact in HubSpot manually
- [ ] Verify all custom properties are created
- [ ] Test webhook creates new contact
- [ ] Test webhook updates existing contact
- [ ] Verify calculated fields compute correctly
- [ ] Test tag assignment logic
- [ ] Verify deal creation for subscriptions
- [ ] Test timeline event creation
- [ ] Verify batch update works for 100+ users
- [ ] Test error handling for invalid data
- [ ] Verify GDPR deletion flow

## Maintenance Tasks

### Monthly
- Audit property usage in HubSpot
- Review and clean up unused properties
- Optimize calculated field formulas
- Update engagement scoring algorithm

### Quarterly
- Review and update user tier thresholds
- Analyze churn risk score accuracy
- Update interest/preference categories
- Optimize tag assignment rules

## Related Files
- `hubspot-property-setup.json` - HubSpot property creation script
- `n8n-user-sync-workflow.json` - n8n workflow export
- `HUBSPOT_SETUP_GUIDE.md` - Step-by-step setup instructions
