# HubSpot CRM Integration Architecture for Arena DTD

## Overview
This document outlines the integration architecture between The Arena DTD (Flutter app + Appwrite backend) and HubSpot CRM using n8n automation workflows.

## System Components

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│   Arena DTD     │         │      n8n        │         │  HubSpot CRM    │
│   (Flutter)     │────────▶│   Automation    │────────▶│                 │
│                 │ Webhook │    Platform     │   API   │                 │
│   Appwrite DB   │◀────────│                 │◀────────│                 │
└─────────────────┘         └─────────────────┘         └─────────────────┘
```

## Data Flow Architecture

### 1. User Lifecycle Sync
**Trigger:** New user signs up in Arena app
**Flow:**
```
User signs up → Appwrite creates user document → Webhook triggers n8n →
n8n creates/updates HubSpot contact → Returns success confirmation
```

### 2. Activity Tracking
**Trigger:** User completes debate, wins/loses, reaches milestone
**Flow:**
```
Activity occurs → Appwrite updates user stats → Webhook triggers n8n →
n8n updates HubSpot contact properties & timeline → Triggers email campaigns if needed
```

### 3. Subscription Management
**Trigger:** User subscribes to Arena Pro, upgrades, or cancels
**Flow:**
```
Subscription change → Appwrite updates premium fields → Webhook triggers n8n →
n8n updates HubSpot deal pipeline → Creates renewal reminder task
```

### 4. Role Changes
**Trigger:** User becomes moderator, judge, or super moderator
**Flow:**
```
Role assigned → Appwrite updates user role → Webhook triggers n8n →
n8n adds role tag in HubSpot → Enrolls in role-specific email sequence
```

## n8n Workflow Structure

### Core Workflows

#### 1. **User Sync Workflow** (Primary)
- **Name:** `arena-user-sync-to-hubspot`
- **Trigger:** Webhook from Appwrite (user creation/update)
- **Actions:**
  1. Receive webhook payload
  2. Validate user data
  3. Check if contact exists in HubSpot (by arena_user_id)
  4. Create or update HubSpot contact
  5. Return success/error response

#### 2. **Debate Activity Tracker** (High Frequency)
- **Name:** `arena-debate-activity-tracker`
- **Trigger:** Webhook from Appwrite (debate completion)
- **Actions:**
  1. Receive debate result payload
  2. Fetch participant user IDs
  3. Update HubSpot contacts for all participants
  4. Add timeline event to each contact
  5. Check for milestone achievements
  6. Trigger appropriate email campaigns

#### 3. **Milestone Achievement Handler** (Engagement)
- **Name:** `arena-milestone-handler`
- **Trigger:** Called by debate activity tracker or subscription workflow
- **Actions:**
  1. Calculate if user hit milestone (10 debates, 5 wins, etc.)
  2. Update HubSpot contact property
  3. Add achievement tag
  4. Enroll in milestone celebration email sequence
  5. Create internal Slack/Discord notification

#### 4. **Subscription Lifecycle Manager** (Revenue)
- **Name:** `arena-subscription-manager`
- **Trigger:** Webhook from Appwrite (subscription change)
- **Actions:**
  1. Receive subscription event
  2. Update HubSpot contact subscription properties
  3. Create/update deal in HubSpot pipeline
  4. Set renewal reminder task
  5. Enroll in appropriate email sequence (onboarding, upsell, churn prevention)

#### 5. **Role Assignment Sync** (Permissions)
- **Name:** `arena-role-assignment-sync`
- **Trigger:** Webhook from Appwrite (role change)
- **Actions:**
  1. Receive role change event
  2. Update HubSpot contact role properties
  3. Add role-specific tags
  4. Remove old role tags if changed
  5. Enroll in role-specific email sequence
  6. Create onboarding task if new moderator/judge

#### 6. **Inactivity Detector** (Scheduled)
- **Name:** `arena-inactivity-detector`
- **Trigger:** Scheduled (daily at 9 AM)
- **Actions:**
  1. Query Appwrite for users with no activity in 7/14/30 days
  2. Update HubSpot contact property: last_activity_date
  3. Add "Inactive" tag with duration
  4. Enroll in re-engagement email campaign
  5. Create internal report

#### 7. **Partnership Pipeline Sync** (Manual + Automated)
- **Name:** `arena-partnership-pipeline`
- **Trigger:** Manual or form submission
- **Actions:**
  1. Create company record in HubSpot
  2. Create deal with pipeline stages
  3. Assign to appropriate team member
  4. Create follow-up tasks
  5. Set reminder notifications

## Webhook Endpoints (n8n)

### 1. User Events
**Endpoint:** `https://your-n8n-instance.com/webhook/arena-user-sync`
**Events:**
- `user.created`
- `user.updated`
- `user.profile.updated`

### 2. Debate Events
**Endpoint:** `https://your-n8n-instance.com/webhook/arena-debate-activity`
**Events:**
- `debate.completed`
- `debate.won`
- `debate.lost`
- `challenge.accepted`
- `challenge.declined`

### 3. Subscription Events
**Endpoint:** `https://your-n8n-instance.com/webhook/arena-subscription`
**Events:**
- `subscription.created`
- `subscription.upgraded`
- `subscription.downgraded`
- `subscription.cancelled`
- `subscription.renewed`

### 4. Role Events
**Endpoint:** `https://your-n8n-instance.com/webhook/arena-role-change`
**Events:**
- `role.moderator.assigned`
- `role.judge.assigned`
- `role.super_mod.assigned`
- `role.removed`

## HubSpot Contact Properties Mapping

See `HUBSPOT_PROPERTY_MAPPING.md` for complete field mapping.

## Error Handling Strategy

### 1. Webhook Failures
- n8n retries failed webhooks 3 times with exponential backoff
- After 3 failures, logs error to monitoring system
- Sends alert to admin dashboard

### 2. HubSpot API Errors
- Catch rate limit errors (429) and retry after delay
- Catch authentication errors (401) and alert admin
- Catch validation errors (400) and log details
- All other errors logged and monitored

### 3. Data Validation
- Validate all incoming webhook payloads
- Check required fields before HubSpot API calls
- Sanitize email addresses and phone numbers
- Handle missing/null values gracefully

### 4. Monitoring & Alerts
- Log all workflow executions to n8n database
- Send daily summary report of sync status
- Alert on repeated failures (>5 per hour)
- Dashboard showing sync health metrics

## Security Considerations

### 1. Webhook Security
- Use webhook secret tokens for authentication
- Validate webhook signatures
- Whitelist Appwrite IP addresses
- Use HTTPS only

### 2. API Key Management
- Store HubSpot API key in n8n credentials (encrypted)
- Rotate API keys every 90 days
- Use separate API keys for production/staging
- Never log API keys

### 3. Data Privacy
- Only sync necessary user data to HubSpot
- Respect user privacy preferences
- Implement data retention policies
- Support GDPR deletion requests

### 4. Rate Limiting
- Respect HubSpot API rate limits (100 requests/10 seconds)
- Implement request queuing for bulk operations
- Use batch endpoints when available
- Monitor API usage quotas

## Performance Optimization

### 1. Batch Processing
- Group multiple user updates into single API calls
- Process debate results in batches
- Use HubSpot batch endpoints (up to 100 records)

### 2. Caching
- Cache HubSpot contact lookups for 5 minutes
- Cache property definitions for 1 hour
- Use n8n's built-in caching where possible

### 3. Async Processing
- Use n8n's async webhook responses
- Don't block Appwrite operations waiting for HubSpot
- Process heavy operations in background

### 4. Deduplication
- Check for duplicate webhook events
- Use idempotency keys for critical operations
- Deduplicate based on event timestamp + user ID

## Testing Strategy

### 1. Unit Testing (n8n Workflows)
- Test each workflow node individually
- Mock webhook payloads
- Verify HubSpot API call formats
- Test error handling branches

### 2. Integration Testing
- Test full workflow end-to-end
- Use HubSpot sandbox account
- Verify data appears correctly in HubSpot
- Test all event types

### 3. Load Testing
- Simulate high-volume webhook traffic
- Test 100+ concurrent users syncing
- Monitor n8n performance under load
- Verify rate limiting works

### 4. Manual Testing Checklist
- [ ] New user creates HubSpot contact
- [ ] Debate completion updates stats
- [ ] Milestone triggers email campaign
- [ ] Subscription creates deal
- [ ] Role change adds correct tags
- [ ] Inactive users get re-engagement emails
- [ ] Error handling works for all scenarios

## Deployment Plan

### Phase 1: Foundation (Week 1)
1. Set up n8n instance (self-hosted)
2. Configure HubSpot API connection
3. Create basic webhook endpoints
4. Build user sync workflow
5. Test with 10 test users

### Phase 2: Core Workflows (Week 2)
1. Build debate activity tracker
2. Build milestone handler
3. Build subscription manager
4. Test with 100 test users
5. Monitor error rates

### Phase 3: Advanced Features (Week 3)
1. Build role assignment sync
2. Build inactivity detector
3. Create email campaign templates in HubSpot
4. Test complete user journey
5. Performance optimization

### Phase 4: Production Launch (Week 4)
1. Migrate existing users to HubSpot (batch import)
2. Enable webhooks in production Appwrite
3. Monitor sync health for 48 hours
4. Train team on HubSpot usage
5. Document common troubleshooting

## Maintenance & Monitoring

### Daily Tasks
- Check n8n execution logs for errors
- Verify sync count matches expected activity
- Monitor HubSpot API usage quotas

### Weekly Tasks
- Review failed workflow executions
- Analyze user engagement metrics
- Update email campaign performance
- Check for HubSpot property schema changes

### Monthly Tasks
- Review and optimize workflow performance
- Audit data quality in HubSpot
- Update user segmentation rules
- Plan new automation workflows
- Review API usage and costs

## Success Metrics

### Technical KPIs
- Webhook success rate: >99%
- Average sync latency: <5 seconds
- API error rate: <0.1%
- n8n uptime: >99.9%

### Business KPIs
- User re-engagement rate: +25%
- Email open rates: >30%
- Subscription conversion rate: +15%
- Partnership pipeline velocity: +20%

## Support & Troubleshooting

### Common Issues

**Issue:** User not syncing to HubSpot
**Solution:** Check webhook logs, verify API key, check HubSpot rate limits

**Issue:** Duplicate contacts in HubSpot
**Solution:** Ensure arena_user_id is set as unique identifier, run deduplication

**Issue:** Email campaigns not triggering
**Solution:** Verify workflow enrollment logic, check HubSpot list memberships

**Issue:** n8n workflows timing out
**Solution:** Optimize workflow, split into smaller workflows, increase timeout

### Getting Help
- n8n Community Forum: https://community.n8n.io
- HubSpot Developer Docs: https://developers.hubspot.com
- Arena DTD Internal Docs: See `/docs` folder
- Emergency Contact: [Your email/Slack]

## Future Enhancements

### Phase 5+ (Future)
- AI-powered user segmentation
- Predictive churn modeling
- Advanced tournament management
- Sponsor ROI tracking dashboard
- Mobile app for moderators
- Automated content generation for campaigns
- Integration with Discord/Slack for community
- WhatsApp notifications via HubSpot
- Advanced analytics dashboards
- Multi-language email campaigns

## Appendix

### Useful Resources
- [HubSpot API Documentation](https://developers.hubspot.com/docs/api/overview)
- [n8n Documentation](https://docs.n8n.io/)
- [Appwrite Webhooks Guide](https://appwrite.io/docs/webhooks)
- [Arena DTD Backend Architecture](./BACKEND_ARCHITECTURE.md)

### Related Documents
- `HUBSPOT_PROPERTY_MAPPING.md` - Complete field mapping
- `N8N_WORKFLOW_LIBRARY.md` - All workflow JSON exports
- `HUBSPOT_SETUP_GUIDE.md` - Step-by-step HubSpot configuration
- `EMAIL_CAMPAIGN_TEMPLATES.md` - Pre-built email sequences
- `TROUBLESHOOTING_GUIDE.md` - Common issues and solutions
