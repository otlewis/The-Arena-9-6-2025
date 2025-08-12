# Premium Store Integration Setup

## 1. App Store Connect Configuration (iOS)

### Create Subscription Products:
1. Log into [App Store Connect](https://appstoreconnect.apple.com/)
2. Go to your Arena app
3. Click **Features** → **In-App Purchases**
4. Click **+** to create new products:

**Monthly Subscription:**
- Product ID: `arena_pro_monthly`
- Reference Name: `Arena Pro Monthly`
- Price: $10.00/month
- Subscription Duration: 1 month
- Free Trial: 14 days

**Yearly Subscription:**
- Product ID: `arena_pro_yearly`  
- Reference Name: `Arena Pro Yearly`
- Price: $100.00/year
- Subscription Duration: 1 year
- Free Trial: 14 days

### Configure Subscription Groups:
1. Create subscription group: "Arena Pro"
2. Add both monthly and yearly to the same group
3. Enable "Introductory Offers" for 14-day free trial

## 2. Google Play Console Configuration (Android)

### Create Subscription Products:
1. Log into [Google Play Console](https://play.google.com/console/)
2. Go to your Arena app
3. Click **Monetization** → **Subscriptions**
4. Click **Create subscription**:

**Monthly Subscription:**
- Product ID: `arena_pro_monthly`
- Name: `Arena Pro Monthly`
- Price: $10.00/month
- Billing period: 1 month
- Free trial: 14 days

**Yearly Subscription:**
- Product ID: `arena_pro_yearly`
- Name: `Arena Pro Yearly`  
- Price: $100.00/year
- Billing period: 1 year
- Free trial: 14 days

## 3. Current Implementation Status

✅ **Completed:**
- Added `in_app_purchase` plugin to pubspec.yaml
- Created `InAppPurchaseService` class
- Started updating `PremiumScreen` with purchase integration

🔄 **Next Steps:**
1. Finish updating PremiumScreen UI
2. Configure subscription products in both stores
3. Test with sandbox/test accounts
4. Add server-side receipt validation (optional but recommended)
5. Update user premium status in Appwrite database

## 4. Testing

### iOS Testing:
- Use TestFlight for sandbox purchases
- Create sandbox test accounts in App Store Connect
- Test on physical device (simulator doesn't support payments)

### Android Testing:
- Use internal testing track
- Add test accounts in Google Play Console
- Test on physical device

## 5. Important Notes

- Both stores require real developer accounts ($99/year Apple, $25 one-time Google)
- Products must be approved before going live
- Always test thoroughly with sandbox accounts first
- Keep receipt validation for security
- Handle all purchase states (pending, success, error, canceled)

## 6. Revenue Split

- Apple takes 30% (15% after year 1 for subscriptions)
- Google takes 30% (15% after year 1 for subscriptions)
- Your $10/month becomes ~$7/month after fees