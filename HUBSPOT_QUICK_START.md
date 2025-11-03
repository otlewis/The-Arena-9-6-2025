# HubSpot CRM Quick Start Guide

This is the **fast-track deployment guide** for getting the Arena HubSpot CRM integration up and running in **under 2 hours**.

---

## Prerequisites

- [ ] HubSpot account (Free tier is fine)
- [ ] n8n instance (Cloud or self-hosted)
- [ ] Appwrite project access (API key with full permissions)
- [ ] Basic familiarity with webhooks and APIs

---

## Phase 1: HubSpot Setup (30 minutes)

### Step 1: Create HubSpot Account & Get API Key

1. Go to [HubSpot](https://www.hubspot.com/) and sign up for a free account
2. Complete account setup with your business information
3. Navigate to Settings → Integrations → Private Apps
4. Click "Create a private app"
5. Name it "Arena CRM Integration"
6. Grant these scopes:
   - `crm.objects.contacts.read`
   - `crm.objects.contacts.write`
   - `crm.lists.read`
   - `crm.lists.write`
   - `timeline`
7. Copy the API key (you'll need this for n8n)

### Step 2: Create Custom Properties (Automated)

Use the HubSpot API to create all 40+ custom properties at once:

```bash
# Set your HubSpot API key
export HUBSPOT_API_KEY="your-api-key-here"

# Run the property creation script
node scripts/create_hubspot_properties.js
```

Or manually create in HubSpot UI (Settings → Properties → Create property):
- See `HUBSPOT_PROPERTY_MAPPING.md` for the complete list

### Step 3: Create Contact Lists

Create these dynamic lists in HubSpot (Contacts → Lists → Create list):

**Essential Lists:**
1. **Active Users** - `arena_days_since_last_activity < 7`
2. **Inactive Users** - `arena_days_since_last_activity >= 14`
3. **Premium Users** - `arena_is_premium = true`
4. **New Users (This Week)** - `arena_signup_date is in last 7 days`
5. **High Engagement** - `arena_engagement_score >= 80`

Full list available in `HUBSPOT_PROPERTY_MAPPING.md` under "Tags & Lists"

### Step 4: Create Timeline Event Templates

Create 3 timeline event templates (Settings → Data Management → Timeline):

1. **Debate Completed**
   - Template ID: Save this for n8n configuration
   - Properties: `debate_result`, `opponent_name`, `debate_date`

2. **Milestone Achieved**
   - Template ID: Save this for n8n configuration
   - Properties: `milestone_type`, `milestone_value`, `achievement_date`

3. **Subscription Update**
   - Template ID: Save this for n8n configuration
   - Properties: `subscription_status`, `premium_type`, `days_until_expiry`

---

## Phase 2: n8n Setup (45 minutes)

### Step 1: Install n8n

**Option A: n8n Cloud (Recommended for beginners)**
1. Go to [n8n.cloud](https://n8n.cloud/)
2. Sign up for Starter plan ($20/month)
3. Your instance URL will be: `https://[your-instance].app.n8n.cloud`

**Option B: Self-Hosted (For developers)**
```bash
# Using Docker
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  n8nio/n8n

# Access at: http://localhost:5678
```

### Step 2: Configure HubSpot Credentials in n8n

1. Log into n8n
2. Go to Credentials → Add Credential → HubSpot
3. Name: "HubSpot API"
4. Enter your HubSpot API key from Phase 1
5. Click "Save"

### Step 3: Import n8n Workflows

Import these 5 workflows in order:

1. **Arena User Sync** (`n8n-arena-user-sync.json`)
   - Import workflow
   - Update HubSpot credential reference
   - Activate workflow
   - Copy webhook URL (you'll need this for Appwrite)

2. **Arena Debate Tracker** (`n8n-arena-debate-tracker.json`)
   - Import workflow
   - Update HubSpot credential reference
   - Activate workflow
   - Copy webhook URL

3. **Arena Subscription Manager** (`n8n-arena-subscription-manager.json`)
   - Import workflow
   - Update HubSpot credential reference
   - Activate workflow
   - Copy webhook URL

4. **Arena Milestone Handler** (`n8n-arena-milestone-handler.json`)
   - Import workflow
   - Update HubSpot credential reference
   - This workflow is called by Debate Tracker (no webhook needed)
   - Activate workflow

5. **Arena Inactivity Detector** (`n8n-arena-inactivity-detector.json`)
   - Import workflow
   - Update HubSpot credential reference
   - Runs daily at midnight (schedule trigger)
   - Activate workflow

### Step 4: Update Workflow Configuration

For each imported workflow, replace these placeholders:

- `HUBSPOT_API_CREDENTIALS_ID` → Your HubSpot credential ID (from Step 2)
- `MILESTONE_FIRST_DEBATE_LIST_ID` → Your HubSpot list ID
- `MILESTONE_10_DEBATES_LIST_ID` → Your HubSpot list ID
- `MILESTONE_50_DEBATES_LIST_ID` → Your HubSpot list ID
- Timeline event template IDs from Phase 1 Step 4

---

## Phase 3: Appwrite Webhook Setup (20 minutes)

### Step 1: Set Environment Variables

```bash
export APPWRITE_API_KEY="your-appwrite-api-key"
export N8N_WEBHOOK_URL="https://your-n8n-instance.com/webhook"
```

### Step 2: Run Webhook Setup Script

```bash
cd /path/to/arena2
./scripts/setup_hubspot_webhooks.sh
```

This creates 3 webhooks in your Appwrite project:
1. **HubSpot User Sync** - Triggers on user create/update
2. **HubSpot Debate Tracker** - Triggers on arena_rooms update
3. **HubSpot Subscription Manager** - Triggers on user subscription changes

### Step 3: Verify Webhooks

1. Go to Appwrite Console → Your Project → Webhooks
2. You should see 3 new webhooks created
3. Each webhook should show:
   - ✅ Active status
   - ✅ Correct n8n URL
   - ✅ Proper event triggers

---

## Phase 4: Testing & Verification (20 minutes)

### Test 1: User Sync

1. Create a test user in Arena app
2. Check n8n execution log - should show successful run
3. Check HubSpot Contacts - new contact should appear with `arena_user_id`

**Expected Result:**
- New HubSpot contact created
- All properties populated (name, email, signup date, etc.)
- Contact added to "New Users" list

### Test 2: Debate Tracking

1. Complete a test debate in Arena
2. Update arena_rooms document with `status: "completed"`
3. Check n8n execution log
4. Check HubSpot Contacts - both debaters should have updated stats

**Expected Result:**
- Total debates incremented
- Wins/losses updated
- Win rate recalculated
- Timeline event added
- Engagement score updated

### Test 3: Subscription Update

1. Update a test user's premium status in Appwrite
2. Set `isPremium: true`, `premiumType: "monthly"`
3. Check n8n execution log
4. Check HubSpot contact

**Expected Result:**
- Premium status updated
- Contact added to "Premium Users" list
- Subscription metrics calculated
- Timeline event added

### Test 4: Milestone Detection

1. Create a user with exactly 10 completed debates
2. Check n8n milestone handler execution
3. Check HubSpot contact

**Expected Result:**
- Milestone date recorded
- Contact added to "10 Debates Milestone" list
- Celebration email enrolled (if email campaigns active)

### Test 5: Inactivity Detection

1. Wait for scheduled run (midnight) or manually execute workflow
2. Check n8n execution log
3. Check HubSpot contacts with `arena_days_since_last_activity >= 7`

**Expected Result:**
- Lifecycle stage updated (cooling/inactive/at_risk/churned)
- Re-engagement priority calculated
- Inactive users enrolled in re-engagement emails

---

## Phase 5: Production Deployment (15 minutes)

### Step 1: Batch Import Existing Users

```bash
# Export all Arena users to CSV
appwrite databases listDocuments \
  --databaseId arena_db \
  --collectionId users \
  --limit 10000 \
  > arena_users.json

# Convert to HubSpot-compatible CSV
node scripts/convert_users_to_hubspot_csv.js

# Import to HubSpot
# Go to HubSpot → Contacts → Import → Upload CSV
# Map columns to properties using arena_user_id as unique identifier
```

### Step 2: Enable Email Campaigns (Optional)

If you want automated emails, create these 4 campaigns in HubSpot:

1. **Welcome Sequence** (new users)
   - Trigger: Contact added to "New Users" list
   - Delay: Send immediately
   - Content: Welcome to Arena, getting started tips

2. **Re-engagement** (inactive users)
   - Trigger: Contact lifecycle stage = "inactive"
   - Delay: Send after 14 days inactivity
   - Content: "We miss you! Here's what's new..."

3. **Milestone Celebration** (10 debates)
   - Trigger: Contact added to "10 Debates Milestone" list
   - Delay: Send immediately
   - Content: "Congrats on 10 debates! Here's a reward..."

4. **Premium Upsell** (active free users)
   - Trigger: Contact has 5+ debates AND is_premium = false
   - Delay: Send after 7 days
   - Content: "Unlock premium features..."

### Step 3: Set Up Monitoring

**n8n Monitoring:**
1. Enable error notifications in n8n settings
2. Set up email alerts for failed workflows
3. Check execution log daily for first week

**HubSpot Monitoring:**
1. Create dashboard with key metrics:
   - Total contacts
   - Active users (7 days)
   - Premium conversion rate
   - Email engagement rates
2. Set up weekly email report

---

## Troubleshooting

### Webhook not firing

**Check:**
1. Appwrite webhook is active (green dot)
2. n8n workflow is activated
3. n8n webhook URL is correct (no typos)
4. Firewall allows Appwrite → n8n traffic

**Fix:**
```bash
# Test webhook manually
curl -X POST https://your-n8n-instance.com/webhook/arena-user-sync \
  -H "Content-Type: application/json" \
  -d '{"userId": "test123", "email": "test@example.com"}'
```

### HubSpot API rate limit

**Error:** "Too many requests"

**Fix:**
1. n8n workflows have built-in retry logic
2. Add delay node (500ms) between batch operations
3. Process in smaller batches (max 100 contacts per workflow run)

### Contact not found in HubSpot

**Error:** "Contact with arena_user_id not found"

**Fix:**
1. Check if contact exists in HubSpot with correct `arena_user_id`
2. Re-run user sync workflow for that specific user
3. If still fails, manually create contact and re-sync

### Properties not updating

**Error:** Properties show old values

**Fix:**
1. Check property names match exactly (case-sensitive)
2. Verify HubSpot API key has write permissions
3. Check n8n execution log for specific error messages

### Email campaigns not sending

**Error:** Users not receiving emails

**Fix:**
1. Check email campaign is active (not draft)
2. Verify users are enrolled in sequence
3. Check HubSpot email sending limits (2,000/month on free tier)
4. Ensure users haven't unsubscribed

---

## Success Metrics to Monitor

### Week 1 (Validation Phase)
- ✅ 100% of new users syncing to HubSpot
- ✅ Debate stats updating correctly
- ✅ No webhook errors in n8n
- ✅ All properties populating correctly

### Week 2-4 (Optimization Phase)
- 📊 Email open rate: Target 25%+
- 📊 Re-engagement rate: Target +25%
- 📊 Premium conversion: Track baseline
- 📊 Webhook success rate: Target 99%+

### Month 2+ (Growth Phase)
- 📈 User lifetime value increasing
- 📈 Churn rate decreasing
- 📈 Engagement score trends upward
- 📈 Campaign ROI positive

---

## Cost Summary

| Service | Plan | Cost |
|---------|------|------|
| HubSpot | Free | $0/month |
| n8n Cloud | Starter | $20/month |
| **Total** | | **$20/month** |

**Cost Scaling:**
- **10,000 users:** $20/month (same)
- **100,000 users:** $20/month (same) + potential HubSpot upgrade
- **1M+ users:** Consider HubSpot Marketing Hub ($50/month for 10k emails)

---

## Next Steps After Deployment

1. ✅ Monitor for 48 hours - check all metrics
2. ✅ Create first email campaign (welcome sequence)
3. ✅ Set up weekly analytics report
4. ✅ Train team on HubSpot usage
5. ✅ Plan Phase 2 enhancements:
   - Partnership deal tracking
   - Advanced segmentation
   - A/B testing campaigns
   - Revenue attribution

---

## Support & Resources

**Documentation:**
- Full Architecture: `HUBSPOT_INTEGRATION_ARCHITECTURE.md`
- Property Mapping: `HUBSPOT_PROPERTY_MAPPING.md`
- Detailed Setup: `HUBSPOT_SETUP_GUIDE.md`
- Implementation Summary: `HUBSPOT_CRM_IMPLEMENTATION_SUMMARY.md`

**n8n Workflows:**
- `n8n-arena-user-sync.json`
- `n8n-arena-debate-tracker.json`
- `n8n-arena-subscription-manager.json`
- `n8n-arena-milestone-handler.json`
- `n8n-arena-inactivity-detector.json`

**Scripts:**
- `scripts/setup_hubspot_webhooks.sh`
- `scripts/create_hubspot_properties.js` (coming soon)
- `scripts/convert_users_to_hubspot_csv.js` (coming soon)

**External Resources:**
- [HubSpot API Docs](https://developers.hubspot.com/docs/api/overview)
- [n8n Documentation](https://docs.n8n.io/)
- [Appwrite Webhooks Guide](https://appwrite.io/docs/webhooks)

---

## 🎉 You're Done!

Your HubSpot CRM integration is now live and processing Arena user data in real-time!

**What happens now:**
- Every new user automatically syncs to HubSpot
- All debate activity tracked and stats updated
- Subscription changes monitored
- Milestones celebrated
- Inactive users re-engaged

**Enjoy your automated CRM!** 🚀
