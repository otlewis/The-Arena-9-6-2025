# HubSpot CRM Setup Guide for Arena DTD

## Complete Step-by-Step Instructions

This guide will walk you through setting up HubSpot CRM and connecting it to your Arena DTD app via n8n automation.

---

## Prerequisites

✅ **What You Need:**
- Arena DTD app with Appwrite backend (already have)
- HubSpot account (free tier is fine)
- n8n instance (self-hosted or cloud)
- Access to create webhooks in Appwrite
- Basic understanding of APIs and webhooks

⏱️ **Estimated Time:** 2-3 hours for complete setup

---

## Phase 1: HubSpot Account Setup (30 minutes)

### Step 1: Create HubSpot Account

1. Go to [https://www.hubspot.com/products/get-started](https://www.hubspot.com/products/get-started)
2. Click "Get started free"
3. Fill in your details:
   - Email: [Your email]
   - Company name: "The Arena DTD"
   - Industry: "Technology"
   - Employees: "1-10"
4. Complete email verification
5. Skip the onboarding wizard for now (we'll configure manually)

### Step 2: Get HubSpot API Key

1. In HubSpot, click the ⚙️ settings icon (top right)
2. Navigate to: **Integrations** → **Private Apps**
3. Click "Create a private app"
4. Fill in:
   - **Name:** "Arena DTD Integration"
   - **Description:** "Sync user data from Arena debate platform"
5. Go to **Scopes** tab and enable:
   - ✅ `crm.objects.contacts.read`
   - ✅ `crm.objects.contacts.write`
   - ✅ `crm.schemas.contacts.read`
   - ✅ `crm.schemas.contacts.write`
   - ✅ `crm.objects.deals.read`
   - ✅ `crm.objects.deals.write`
   - ✅ `crm.lists.read`
   - ✅ `crm.lists.write`
   - ✅ `timeline`
6. Click "Create app"
7. Click "Show token" and **copy the API key** (save it securely!)
   ```
   Example: pat-na1-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```

### Step 3: Create Custom Contact Properties

We need to create ~40 custom properties for Arena data.

#### Option A: Manual Creation (Slow but Educational)

1. Go to **Settings** → **Data Management** → **Properties**
2. Click **"Create property"**
3. Select object type: **Contact**
4. For each property in the table below, create it:

| Property Name | Label | Type | Field Type | Group |
|--------------|-------|------|------------|-------|
| `arena_user_id` | Arena User ID | Single-line text | Text | Arena Integration |
| `arena_username` | Arena Username | Single-line text | Text | Arena Integration |
| `arena_total_debates` | Total Debates | Number | Number | Arena Engagement |
| `arena_total_wins` | Total Wins | Number | Number | Arena Engagement |
| `arena_total_losses` | Total Losses | Number | Number | Arena Engagement |
| `arena_win_rate` | Win Rate (%) | Number | Number | Arena Engagement |
| `arena_coin_balance` | Coin Balance | Number | Number | Arena Economy |
| `arena_is_premium` | Is Premium | Single checkbox | Checkbox | Arena Subscription |
| `arena_premium_type` | Premium Type | Dropdown | Dropdown | Arena Subscription |

**IMPORTANT:** For `arena_user_id`, check the box "This property should have a unique value for every contact"

For the complete list of 40+ properties, see `HUBSPOT_PROPERTY_MAPPING.md`

#### Option B: API Batch Creation (Fast - Recommended)

I've prepared a script. Run it after setting up n8n in Phase 2.

### Step 4: Create Contact Lists (Tags)

1. Go to **Contacts** → **Lists**
2. Click "Create list"
3. Select **"Active list"** (dynamic, updates automatically)
4. Name it and set filter criteria:

**Create these 10 essential lists:**

| List Name | Filter Criteria |
|-----------|----------------|
| `arena-new-user` | `arena_signup_date` is less than 7 days ago |
| `arena-active-user` | `arena_days_since_last_activity` is less than or equal to 7 |
| `arena-power-user` | `arena_total_debates` is greater than or equal to 20 |
| `arena-inactive-7d` | `arena_days_since_last_activity` is between 7 and 14 |
| `arena-inactive-14d` | `arena_days_since_last_activity` is between 14 and 30 |
| `arena-inactive-30d` | `arena_days_since_last_activity` is greater than 30 |
| `arena-premium-monthly` | `arena_is_premium` is TRUE AND `arena_premium_type` is equal to MONTHLY |
| `arena-premium-yearly` | `arena_is_premium` is TRUE AND `arena_premium_type` is equal to YEARLY |
| `arena-first-debate` | `arena_total_debates` is equal to 1 |
| `arena-10-debates` | `arena_total_debates` is greater than or equal to 10 |

### Step 5: Create Timeline Event Templates

1. Go to **Settings** → **Data Management** → **Timeline Events**
2. Click "Create event template"

**Create these 3 event templates:**

#### Event 1: User Sync
- **Name:** `arena_user_sync`
- **Event Display Name:** "Arena User Synced"
- **Icon:** 🔄
- **Detail Template:**
  ```
  {{event_type}} - Arena User ID: {{arena_user_id}}
  ```
- **Custom Properties:**
  - `event_type` (Text)
  - `arena_user_id` (Text)

#### Event 2: Debate Completed
- **Name:** `arena_debate_completed`
- **Event Display Name:** "Debate Completed"
- **Icon:** 🎭
- **Detail Template:**
  ```
  {{result}} as {{role}} in "{{topic}}" ({{duration_seconds}}s)
  ```
- **Custom Properties:**
  - `room_id` (Text)
  - `topic` (Text)
  - `role` (Text)
  - `result` (Text) - WON/LOST/PARTICIPATED
  - `judgment_type` (Text)
  - `duration_seconds` (Number)

#### Event 3: Milestone Achieved
- **Name:** `arena_milestone`
- **Event Display Name:** "Milestone Achieved"
- **Icon:** 🏆
- **Detail Template:**
  ```
  Achieved {{milestone_name}}!
  ```
- **Custom Properties:**
  - `milestone_name` (Text)
  - `milestone_type` (Text)

---

## Phase 2: n8n Setup (45 minutes)

### Step 1: Install n8n (Choose One)

#### Option A: Self-Hosted Docker (Recommended)
```bash
# Create directory for n8n
mkdir -p ~/arena-n8n
cd ~/arena-n8n

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=your_secure_password_here
      - N8N_HOST=localhost
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://your-domain.com/
    volumes:
      - ./n8n-data:/home/node/.n8n
EOF

# Start n8n
docker-compose up -d

# Check logs
docker-compose logs -f
```

Access n8n at: `http://localhost:5678`

#### Option B: n8n Cloud (Easier but Paid)
1. Go to [https://n8n.io/cloud](https://n8n.io/cloud)
2. Sign up for account (free trial available)
3. Create new workspace: "Arena DTD"

### Step 2: Connect HubSpot to n8n

1. In n8n, go to **Settings** → **Credentials**
2. Click "Add Credential"
3. Search for "HubSpot"
4. Select **"HubSpot API"**
5. Paste your API key from Step 2
6. Click "Test" to verify connection
7. Click "Save"

### Step 3: Import Workflows

I've created 3 pre-built workflows for you.

1. In n8n, go to **Workflows**
2. Click the menu (⋮) → **Import from File**
3. Import these 3 files:
   - `n8n-arena-user-sync.json`
   - `n8n-arena-debate-tracker.json`
   - `n8n-arena-milestone-handler.json` (create next)

### Step 4: Configure Workflow Settings

For each imported workflow:

1. Open the workflow
2. Click on any **HubSpot node**
3. Select your HubSpot credential from dropdown
4. Click **Execute Node** to test
5. Save workflow

### Step 5: Get Webhook URLs

Each workflow has a webhook URL you'll need.

1. Open **"Arena User Sync to HubSpot"** workflow
2. Click the **Webhook** node (first node)
3. Copy the **Webhook URL**
   ```
   Example: https://your-n8n.com/webhook/arena-user-sync
   ```
4. Repeat for other workflows:
   - Debate tracker: `https://your-n8n.com/webhook/arena-debate-activity`
   - Milestone handler: `https://your-n8n.com/webhook/arena-milestone-handler`

**Save these URLs** - you'll need them for Appwrite webhooks!

---

## Phase 3: Appwrite Webhook Configuration (30 minutes)

### Step 1: Create Appwrite Webhooks

1. Log into Appwrite Console: `https://cloud.appwrite.io`
2. Select your Arena project
3. Go to **Settings** → **Webhooks**
4. Click "Add Webhook"

#### Webhook 1: User Events

**Name:** Arena User Sync
**URL:** `https://your-n8n.com/webhook/arena-user-sync`
**Events:** Select these:
- ✅ `users.*.create`
- ✅ `databases.arena_db.collections.users.documents.*.create`
- ✅ `databases.arena_db.collections.users.documents.*.update`

**Headers:** (Optional - for security)
```
X-Webhook-Secret: your_secret_token_here
```

**Security:** Check "Verify SSL Certificate"

Click **Create**

#### Webhook 2: Debate Events

**Name:** Arena Debate Activity
**URL:** `https://your-n8n.com/webhook/arena-debate-activity`
**Events:** Select these:
- ✅ `databases.arena_db.collections.arena_rooms.documents.*.update`

**Filter (Important!):** Add this condition:
```javascript
// Only trigger when debate is completed (status changes to 'completed')
return data.status === 'completed'
```

**Headers:** (Optional - for security)
```
X-Webhook-Secret: your_secret_token_here
```

Click **Create**

### Step 2: Test Webhooks

#### Test User Sync:
1. Create a test user in your Arena app
2. Check n8n **Executions** tab (left sidebar)
3. You should see a successful execution of "Arena User Sync"
4. Check HubSpot **Contacts** - test user should appear

#### Test Debate Tracking:
1. Complete a test debate in your Arena app
2. Check n8n **Executions** for "Arena Debate Activity Tracker"
3. Check HubSpot contact - stats should be updated

---

## Phase 4: Create Email Campaigns (1 hour)

### Campaign 1: Welcome Sequence (New Users)

1. Go to **Marketing** → **Email** → **Create email**
2. Name: "Welcome to Arena DTD"
3. Type: **Automated email**
4. Enrollment trigger: **List membership** → `arena-new-user`
5. Delay: Send immediately
6. Email template:

```
Subject: Welcome to The Arena DTD - Let's Get Started! 🎭

Hi {{contact.firstname}},

Welcome to The Arena DTD - where debate is royalty!

Here's how to get started:

✅ Complete your first debate
🏆 Earn coins and reputation
👥 Challenge other debaters
🎓 Learn from judges' feedback

Your first debate is waiting. Ready?

[Start Debating Now]

See you in the Arena,
The Arena Team
```

### Campaign 2: Re-Engagement (Inactive Users)

1. Create automated email
2. Name: "We Miss You in the Arena"
3. Enrollment trigger: **List membership** → `arena-inactive-7d`
4. Delay: 7 days after joining list
5. Email template:

```
Subject: Your opponents are waiting... 🎭

Hi {{contact.firstname}},

It's been a week since your last debate!

Here's what you've missed:
• {{contact.arena_total_debates}} debates completed
• {{contact.arena_total_wins}} wins so far
• {{contact.arena_coin_balance}} coins earned

Top debaters this week are crushing it. Will you join them?

[Return to Arena]

Your crown awaits,
The Arena Team
```

### Campaign 3: Milestone Celebration

1. Create automated email
2. Name: "You Hit 10 Debates!"
3. Enrollment trigger: **List membership** → `arena-10-debates`
4. Delay: Send immediately
5. Email template:

```
Subject: 🏆 Congratulations! You've completed 10 debates!

Hi {{contact.firstname}},

Incredible work! You've officially completed 10 debates in The Arena.

Your Stats:
📊 Win Rate: {{contact.arena_win_rate}}%
🏆 Total Wins: {{contact.arena_total_wins}}
💰 Coin Balance: {{contact.arena_coin_balance}}
⭐ Reputation: {{contact.arena_reputation_percentage}}%

As a reward, we've added 100 bonus coins to your account!

Ready for your next 10?

[Continue Debating]

Royally yours,
The Arena Team
```

### Campaign 4: Premium Upsell

1. Create automated email
2. Name: "Unlock Arena Pro"
3. Enrollment trigger: **Contact property value** → `arena_total_debates` is greater than or equal to 5 AND `arena_is_premium` is FALSE
4. Delay: Send immediately
5. Email template:

```
Subject: You're Ready for Arena Pro 👑

Hi {{contact.firstname}},

You're on fire! {{contact.arena_total_debates}} debates completed.

You're clearly serious about debating. That's why we think you'll love Arena Pro:

✨ Arena Pro Benefits:
• Unlimited debates (no waiting)
• Advanced statistics dashboard
• Priority matchmaking
• Exclusive tournaments
• Premium badges & effects
• Ad-free experience

Special offer: 20% off your first month!

[Upgrade to Pro]

Level up your game,
The Arena Team
```

---

## Phase 5: Testing & Verification (30 minutes)

### Test Checklist

Use this checklist to verify everything works:

#### User Sync Tests
- [ ] Create new user in Arena app
- [ ] Verify user appears in HubSpot within 5 seconds
- [ ] Check all fields populated correctly
- [ ] Verify tags assigned (e.g., `arena-new-user`)
- [ ] Check timeline event appears
- [ ] Verify welcome email sent (if enrolled in campaign)

#### Debate Activity Tests
- [ ] Complete a debate as 2 users
- [ ] Verify both contacts updated in HubSpot
- [ ] Check `arena_total_debates` incremented
- [ ] Check `arena_total_wins` for winner
- [ ] Check `arena_total_losses` for loser
- [ ] Verify timeline event shows debate details
- [ ] Check milestone email sent (if applicable)

#### Campaign Tests
- [ ] Create test user
- [ ] Verify welcome email received
- [ ] Wait 7 days (or manually add to `arena-inactive-7d` list)
- [ ] Verify re-engagement email received
- [ ] Complete 10 debates
- [ ] Verify milestone email received

#### Error Handling Tests
- [ ] Send invalid webhook payload
- [ ] Verify n8n handles error gracefully
- [ ] Check error logs in n8n
- [ ] Verify user experience not affected

---

## Phase 6: Production Launch (1 hour)

### Step 1: Batch Import Existing Users

You already have users in Arena. Let's import them to HubSpot.

1. Export all users from Appwrite:
```bash
# Run this script to export users to CSV
dart run scripts/export_users_to_csv.dart
```

2. In HubSpot, go to **Contacts** → **Import**
3. Upload the CSV file
4. Map columns to HubSpot properties:
   - `email` → `email`
   - `name` → `firstname` (split first name)
   - `arena_user_id` → `arena_user_id`
   - etc.
5. Click **Import**
6. Wait for import to complete (may take 10-30 minutes for 1000+ users)

### Step 2: Enable Production Webhooks

1. In Appwrite Console, verify all webhooks are enabled
2. Check webhook logs for any errors
3. Test with 5-10 real user actions
4. Monitor n8n execution logs

### Step 3: Activate Email Campaigns

1. In HubSpot, go to each email campaign
2. Click **Review and publish**
3. Enable the campaign
4. Set send limits:
   - Daily send limit: 500 emails
   - Enrollment: Once per contact
5. Click **Turn on**

### Step 4: Monitor First 48 Hours

**Key Metrics to Watch:**

| Metric | Expected | Alert If |
|--------|----------|----------|
| Webhook success rate | >99% | <95% |
| Email send rate | ~10% of users/day | 0 sends |
| Contact sync latency | <5 seconds | >30 seconds |
| n8n execution errors | <0.1% | >1% |

**Monitoring Dashboard:**
1. n8n: Check **Executions** tab hourly
2. HubSpot: Check **Marketing** → **Email** → **Analyze** daily
3. Appwrite: Check **Webhooks** logs for failures

---

## Troubleshooting Guide

### Issue: Webhook not triggering

**Symptoms:** User created in Arena, but doesn't appear in HubSpot

**Solutions:**
1. Check Appwrite webhook logs:
   - Go to Appwrite Console → Settings → Webhooks
   - Click on webhook name
   - Check "Recent Deliveries" tab
   - Look for errors (4xx, 5xx status codes)

2. Verify n8n workflow is active:
   - Go to n8n → Workflows
   - Check workflow toggle is ON
   - Click "Execute Workflow" to test manually

3. Check webhook URL is correct:
   - Appwrite webhook URL should match n8n webhook URL exactly
   - Include `https://` prefix
   - No trailing slash

4. Test with curl:
```bash
curl -X POST https://your-n8n.com/webhook/arena-user-sync \
  -H "Content-Type: application/json" \
  -d '{
    "event": "user.created",
    "userId": "test123",
    "userData": {
      "id": "test123",
      "email": "test@example.com",
      "name": "Test User",
      "totalDebates": 0,
      "totalWins": 0,
      "totalLosses": 0,
      "coinBalance": 100
    }
  }'
```

### Issue: Contact duplicates in HubSpot

**Symptoms:** Same user appears multiple times

**Solutions:**
1. Check `arena_user_id` is set as unique identifier:
   - HubSpot → Settings → Properties
   - Find `arena_user_id`
   - Enable "Unique value"

2. Merge duplicates:
   - HubSpot → Contacts
   - Search for duplicate
   - Select both contacts
   - Click "Merge"

3. Update n8n workflow to check for existing contact first (already built in)

### Issue: Email campaigns not sending

**Symptoms:** Campaign active but emails not received

**Solutions:**
1. Check contact enrolled in list:
   - HubSpot → Contacts
   - Open test contact
   - Check "Lists" tab
   - Verify they're in the trigger list

2. Check email send settings:
   - Marketing → Email → [Campaign Name]
   - Check "Send to" filter
   - Verify no exclusion lists active

3. Check spam folder (test emails often land there)

4. Verify contact has email address:
   - HubSpot → Contacts
   - Check `email` field is populated

### Issue: Timeline events not appearing

**Symptoms:** Debate completed but no timeline event in HubSpot

**Solutions:**
1. Verify timeline event template exists:
   - Settings → Data Management → Timeline Events
   - Check `arena_debate_completed` exists

2. Check n8n node configuration:
   - Open workflow
   - Click "Add Timeline Event" node
   - Verify `eventTemplateId` matches HubSpot template name

3. Test timeline API manually:
```bash
curl -X POST https://api.hubapi.com/crm/v3/timeline/events \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "eventTemplateId": "arena_debate_completed",
    "email": "test@example.com",
    "properties": {
      "topic": "Test Debate",
      "result": "WON"
    }
  }'
```

---

## Maintenance Tasks

### Daily
- [ ] Check n8n execution logs for errors
- [ ] Verify webhook success rate >99%
- [ ] Monitor email send rates
- [ ] Review any failed syncs

### Weekly
- [ ] Analyze email campaign performance
- [ ] Review user engagement metrics in HubSpot
- [ ] Check for contact duplicates
- [ ] Update user segmentation lists

### Monthly
- [ ] Review and optimize email templates
- [ ] Analyze churn risk scores
- [ ] Update milestone thresholds
- [ ] Audit property usage
- [ ] Review API usage quotas

---

## Next Steps

Once everything is working:

1. **Create more email campaigns:**
   - Subscription renewal reminders
   - Tournament invitations
   - Weekly digest of upcoming debates

2. **Build partnership pipeline:**
   - Add sponsor contacts
   - Create deal stages
   - Set up follow-up tasks

3. **Advanced segmentation:**
   - Create predictive churn models
   - Build engagement scoring
   - Identify VIP users for special treatment

4. **Integrate more tools:**
   - Connect Discord for moderator notifications
   - Add Slack for team alerts
   - Integrate analytics platforms

---

## Support Resources

- **HubSpot Help:** https://knowledge.hubspot.com
- **n8n Documentation:** https://docs.n8n.io
- **Arena DTD Docs:** See `/docs` folder in repo
- **Emergency Contact:** [Your email/Slack]

---

## Success! 🎉

You now have a fully integrated CRM system that:
- ✅ Automatically syncs users from Arena to HubSpot
- ✅ Tracks debate activity and engagement
- ✅ Sends automated email campaigns
- ✅ Manages user lifecycle
- ✅ Provides analytics and insights

Your Arena DTD platform is now equipped with enterprise-level marketing automation!
