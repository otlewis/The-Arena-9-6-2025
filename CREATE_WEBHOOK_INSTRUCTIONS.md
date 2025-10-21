# Create Arena Challenge Navigation Webhook

Since Appwrite CLI doesn't support webhooks, you need to create it through the Console.

## Step-by-Step Instructions:

### 1. Go to Webhooks Page
You're already there! Click the **"+ Create webhook"** button.

### 2. Fill in the Form

**Name:**
```
Arena Challenge Navigation
```

**Events:**
Click the "Edit event" button or "Add custom event" and enter:
```
databases.arena_db.collections.challenge_messages.documents.*.update
```

**URL (Post URL):**
```
http://n8n.dialecticlabs.com/webhook/arena-challenge-accepted
```

**Security:**
- Leave unchecked (or check if you want, doesn't matter for testing)

**Enabled:**
- Make sure the toggle is ON (enabled)

### 3. Click "Create"

The webhook should appear in the list with:
- Name: "Arena Challenge Navigation"
- Post URL: http://n8n.dialecticlabs.com/w... (truncated)
- Events: 1
- Status: Enabled (green)

### 4. Verify It Works

After creating the webhook, test it by:
1. Opening two instances of the Arena app (two different users)
2. User A sends challenge to User B
3. User B accepts the challenge
4. Both users should automatically navigate to the Arena

Look for these logs in the Flutter console:
- `🎯 Setting up arena navigation listener`
- `🎯 ✅ Navigation notification received`
- `🚀 CHALLENGE: Preparing to navigate to Arena room`

### Troubleshooting

If the webhook doesn't show up after clicking "Create":
- Try refreshing the page
- Check for any error messages
- Make sure you're connected to the internet
- Try using a different browser

If you get stuck, take a screenshot and I can help debug!
