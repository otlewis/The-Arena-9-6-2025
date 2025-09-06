# Arena Appwrite Collections for Production Payment System

## Core Collections (Clean & Payment-Free)

### 1. `feature_flags`
Controls app features and kill switches
```json
{
  "name": "string", // e.g. "payments_enabled", "premium_enabled"
  "enabled": "boolean",
  "description": "string",
  "updatedAt": "datetime"
}
```

### 2. `webhook_events` 
Audit trail for all webhook events
```json
{
  "eventType": "string", // INITIAL_PURCHASE, RENEWAL, CANCELLATION, etc.
  "userId": "string", // Arena user ID
  "payload": "string", // JSON string of full webhook payload
  "processedAt": "datetime",
  "source": "string" // "revenuecat", "stripe", etc.
}
```

### 3. `subscription_records`
Historical record of all subscription events
```json
{
  "userId": "string",
  "productId": "string", // arena_pro_monthly, arena_pro_yearly
  "status": "string", // active, cancelled, expired, billing_issue
  "eventTime": "datetime", // when the event occurred
  "expiryDate": "datetime", // when subscription expires
  "isTestSubscription": "boolean",
  "createdAt": "datetime"
}
```

### 4. `user_aliases`
Track when RevenueCat user IDs change
```json
{
  "originalUserId": "string",
  "newUserId": "string", 
  "createdAt": "datetime"
}
```

## Enhanced User Collection

### Updated `users` collection
Only store entitlement state, never payment info
```json
{
  // Existing user fields...
  "isPremium": "boolean",
  "premiumType": "string", // "monthly", "yearly", null
  "premiumExpiry": "datetime", // when subscription expires
  "isTestSubscription": "boolean", // true for sandbox purchases
  "lastWebhookUpdate": "datetime", // last sync from RevenueCat
  
  // Remove any payment-related fields like:
  // ❌ "creditCard", "paymentMethod", "billingAddress", etc.
}
```

## Indexes Required

### `feature_flags`
- Primary: `name` (unique)

### `webhook_events`  
- Primary: `$id`
- Index: `userId` + `eventType` + `createdAt`
- Index: `processedAt` (for cleanup)

### `subscription_records`
- Primary: `$id`  
- Index: `userId` + `status` + `createdAt`
- Index: `eventTime` (for analytics)
- Index: `expiryDate` (for cleanup)

### `user_aliases`
- Primary: `$id`
- Index: `originalUserId` (unique)
- Index: `newUserId`

### `users` (updated indexes)
- Existing indexes...
- Index: `isPremium` + `premiumExpiry`
- Index: `isTestSubscription` + `createdAt`

## Security Rules

All collections should have:
- Read: Only authenticated users can read their own data
- Write: Only server-side webhooks can write (via API key)
- Delete: Only admins can delete (for GDPR compliance)

## Migration Notes

1. **Backup existing data** before migration
2. **Remove any payment-sensitive fields** from users collection  
3. **Create new collections** with proper indexes
4. **Set up RevenueCat webhook URL** pointing to your server
5. **Test thoroughly** in sandbox before going live

## Production Checklist

- [ ] All payment data removed from Appwrite
- [ ] RevenueCat webhook endpoint configured  
- [ ] Feature flags collection created with `payments_enabled: false`
- [ ] Subscription records collection ready for audit trail
- [ ] Proper indexes created for performance
- [ ] Security rules configured properly
- [ ] Backup and rollback plan ready