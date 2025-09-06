# Arena Production Launch Checklist 🚀

## Pre-Launch Setup (Complete These First)

### 1. App Store / Play Store Setup
- [ ] **iOS App Store Connect**: Products created (`arena_pro_monthly`, `arena_pro_yearly`)
- [ ] **Google Play Console**: Products created and activated
- [ ] **App Review Guidelines**: Ensure compliance with subscription policies
- [ ] **Screenshots**: Update with premium badge and features shown
- [ ] **App Description**: Mention subscription pricing and features

### 2. RevenueCat Dashboard Configuration  
- [ ] **iOS API Key**: Added to production (`_iosApiKey`)
- [ ] **Android API Key**: Added to production (`_androidApiKey`) 
- [ ] **Web API Key**: Added for Stripe integration (`_webApiKey`)
- [ ] **Webhook URL**: Configure to point to your server endpoint
- [ ] **Entitlements**: "Arena Pro" entitlement created and mapped
- [ ] **Offerings**: Current offering configured with both products
- [ ] **Sandbox Access**: Set to allowed testers only

### 3. Appwrite Database Setup
- [ ] **feature_flags collection**: Created with `payments_enabled: false` initially
- [ ] **webhook_events collection**: Created for audit trail  
- [ ] **subscription_records collection**: Created for history tracking
- [ ] **user_aliases collection**: Created for ID tracking
- [ ] **users collection**: Updated to remove payment fields, add entitlement fields
- [ ] **Indexes**: All required indexes created for performance
- [ ] **Security Rules**: Configured for webhook-only writes

### 4. Backend/Server Setup (If Self-Hosting Webhooks)
- [ ] **Webhook Endpoint**: Server endpoint to receive RevenueCat webhooks
- [ ] **Authentication**: API key authentication for Appwrite writes  
- [ ] **SSL Certificate**: HTTPS required for webhook security
- [ ] **Error Handling**: Proper logging and retry mechanisms
- [ ] **Rate Limiting**: Protect against webhook spam

## Testing Phase

### 5. Sandbox Testing
- [ ] **Apple TestFlight**: Beta testers invited and can make sandbox purchases
- [ ] **Google Play Internal Testing**: Licensed testers can make test purchases  
- [ ] **RevenueCat Sandbox**: Webhook events properly sync to Appwrite
- [ ] **Premium Features**: Challenge system works for premium users only
- [ ] **Restore Purchases**: Works correctly across devices
- [ ] **Account Deletion**: Premium status properly handled

### 6. Feature Flag Testing
- [ ] **Kill Switch**: `payments_enabled: false` properly disables payments
- [ ] **Gradual Rollout**: Test with small percentage of users first
- [ ] **Premium Features**: Can be toggled via `premium_enabled` flag
- [ ] **Sandbox Mode**: `sandbox_enabled` controls debug purchases

### 7. Edge Cases Testing  
- [ ] **Network Failures**: App handles RevenueCat API failures gracefully
- [ ] **Webhook Delays**: Premium status eventually consistent if webhook delayed
- [ ] **Account Switching**: Premium status transfers correctly
- [ ] **Refunds**: Premium status revoked when Apple/Google processes refund
- [ ] **Expired Cards**: Billing issues handled gracefully

## Go-Live Process

### 8. Production Deployment
- [ ] **Feature Flag**: Set `payments_enabled: true` in production
- [ ] **RevenueCat**: Switch from sandbox to production mode
- [ ] **App Store**: Submit app update with subscription features
- [ ] **Monitoring**: Set up alerts for webhook failures, payment issues
- [ ] **Support**: Team trained on subscription troubleshooting

### 9. Launch Day
- [ ] **Soft Launch**: Enable for 5% of users first 
- [ ] **Monitor**: Watch webhook events, error rates, user feedback
- [ ] **Support**: Ready to handle subscription questions
- [ ] **Rollback Plan**: Can quickly disable payments if issues arise

### 10. Post-Launch
- [ ] **Analytics**: Track conversion rates, churn, revenue
- [ ] **User Feedback**: Monitor reviews for payment issues
- [ ] **Performance**: Database query optimization as user base grows
- [ ] **Compliance**: Regular audits for App Store/Play Store policies

## Emergency Procedures

### Kill Switch Activation
1. Set `payments_enabled: false` in feature_flags collection
2. App will immediately hide all payment UI  
3. Existing premium users keep their benefits
4. No new purchases can be made

### Webhook Failure Recovery
1. Check RevenueCat webhook logs for delivery failures
2. Manually sync premium status via Customer Info API
3. Run cleanup script to fix any inconsistencies  
4. Monitor for patterns in failed webhooks

### Critical Bug Response
1. Immediately disable payments via feature flag
2. Assess impact on existing premium users
3. Prepare hotfix app update if needed
4. Communicate transparently with affected users

## Legal & Compliance  

### Required Legal Pages
- [ ] **Terms of Service**: Subscription terms clearly stated
- [ ] **Privacy Policy**: Payment data handling disclosed  
- [ ] **Refund Policy**: Apple/Google refund processes explained
- [ ] **Contact Info**: Support email for subscription issues

### Store Compliance
- [ ] **Auto-Renewal**: Clearly disclosed in app and store listing
- [ ] **Free Trial**: Terms clearly stated if offering trial period
- [ ] **Price Display**: Correct currency and pricing shown
- [ ] **Subscription Management**: Link to Apple/Google subscription settings

## Success Metrics

### Week 1 Targets  
- [ ] 0% payment processing errors
- [ ] 100% webhook delivery rate  
- [ ] <5% subscription support tickets
- [ ] >90% user satisfaction in reviews

### Month 1 Targets
- [ ] Subscription conversion rate benchmarked
- [ ] Premium feature usage tracked
- [ ] Churn rate analysis complete  
- [ ] Revenue projections vs actuals

---

## Quick Launch Commands

```bash
# Enable payments for production launch
# Set in Appwrite feature_flags collection:
{
  "name": "payments_enabled", 
  "enabled": true,
  "description": "Enable RevenueCat payments"
}

# Emergency kill switch  
{
  "name": "payments_enabled",
  "enabled": false, 
  "description": "EMERGENCY: Payments disabled"
}
```

**Remember**: You can deploy this entire production-ready system safely while keeping payments disabled via feature flags. Test everything thoroughly in sandbox, then simply flip the switch when ready! 🎯