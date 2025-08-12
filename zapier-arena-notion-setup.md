# Zapier Arena-to-Notion Automation Setup

## Overview
This guide helps you create a Zapier automation that adds daily Arena launch readiness scores to your Notion database.

## What You'll Need
1. Zapier account (free tier works)
2. Your Notion database URL
3. Arena MCP server running locally
4. About 15 minutes

## Step 1: Connect Notion to Zapier

1. Go to [zapier.com](https://zapier.com) and sign in
2. Click "Create Zap" 
3. Search for "Notion" in the app directory
4. Click "Connect Notion"
5. Authorize Zapier to access your workspace
6. Select your "Arena Launch Dashboard" database

## Step 2: Create the Automation

### Trigger: Schedule by Zapier
1. Choose "Schedule by Zapier" as trigger
2. Select "Every Day" 
3. Set time to 9:00 AM
4. Choose your timezone

### Action 1: Webhooks by Zapier (Call MCP Server)
1. Add action → "Webhooks by Zapier"
2. Choose "POST" request
3. Configure:
   ```
   URL: http://localhost:3001/
   Payload Type: JSON
   Data:
   {
     "jsonrpc": "2.0",
     "method": "analyze_launch_readiness",
     "params": {"includeDetails": true},
     "id": "{{zap_id}}"
   }
   Headers:
   Content-Type: application/json
   ```

### Action 2: Code by Zapier (Format Data)
1. Add action → "Code by Zapier"
2. Choose "Run Javascript"
3. Input Data:
   - `mcp_response`: (map from webhook response)
4. Code:
   ```javascript
   const response = JSON.parse(inputData.mcp_response);
   const result = response.result || {};
   
   // Format today's date
   const today = new Date().toISOString().split('T')[0];
   
   // Extract metrics
   const launchScore = result.overallScore || 0;
   const improvements = result.recentImprovements || [];
   const priorities = result.nextSteps || [];
   
   // Determine accomplishment
   let accomplishment = 'Maintained system stability';
   if (improvements.length > 0) {
     accomplishment = `Fixed: ${improvements[0]}`;
   }
   
   // Set tomorrow's priority  
   let priority = 'Continue monitoring';
   if (priorities.length > 0) {
     priority = priorities[0];
   }
   
   output = {
     date: today,
     score: launchScore,
     accomplishment: accomplishment,
     priority: priority,
     status: launchScore >= 90 ? 'Launch Ready' : 'In Progress'
   };
   ```

### Action 3: Create Database Item in Notion
1. Add action → "Notion"
2. Choose "Create Database Item"
3. Select your database
4. Map fields:
   - **Date** → `date` from Code step
   - **Launch Score** → `score` from Code step  
   - **Key Accomplishment** → `accomplishment` from Code step
   - **Tomorrow's Priority** → `priority` from Code step
   - **Status** → `status` from Code step

## Step 3: Test Your Zap

1. Click "Test" on each step
2. Verify data flows correctly
3. Check your Notion database for test entry
4. Delete test entry if successful

## Step 4: Alternative - Manual Trigger

If you can't expose localhost:3001, create a simpler version:

### Trigger: Email by Zapier
1. Use "Email by Zapier" as trigger
2. You'll get a unique email like: `abc123@zapiermail.com`
3. Save this email address

### Daily Process:
1. Run this command locally:
   ```bash
   curl -X POST http://localhost:3001/ \
     -H "Content-Type: application/json" \
     -d '{
       "jsonrpc": "2.0",
       "method": "analyze_launch_readiness",
       "params": {"includeDetails": true},
       "id": "1"
     }' | mail -s "Arena Score" abc123@zapiermail.com
   ```

2. Zapier receives email → Parses JSON → Adds to Notion

## Step 5: Even Simpler - Form-Based

Create a simple form trigger:

1. Use "Zapier Interfaces" → Create form with:
   - Launch Score (number)
   - Key Accomplishment (text)
   - Tomorrow's Priority (text)

2. Bookmark the form URL

3. Each day:
   - Ask Claude for Arena metrics
   - Fill out the form
   - Zapier automatically adds to Notion

## Troubleshooting

**MCP Server Connection Issues:**
- Use ngrok to expose localhost: `ngrok http 3001`
- Or use the email/form alternatives above

**Notion Permission Errors:**
- Re-authorize Notion in Zapier
- Ensure database has all required columns
- Check column names match exactly

**Data Formatting Issues:**
- Test with static data first
- Use Zapier's built-in formatter tools
- Add error handling to Code step

## Cost Considerations

- **Free tier**: 100 tasks/month (3 daily updates)
- **Starter**: $19.99/month for 750 tasks
- **Recommendation**: Use manual trigger to control usage

## Next Steps

1. Set up the basic automation
2. Test thoroughly
3. Add error notifications (email/Slack)
4. Consider adding:
   - Weekly summary reports
   - Trend analysis
   - Alert when score drops

---

**Quick Alternative**: Since Arena MCP runs locally, the simplest approach might be:
1. Daily: Ask Claude for launch metrics
2. Copy the data
3. Paste into Notion directly

This takes 30 seconds and doesn't require any automation!