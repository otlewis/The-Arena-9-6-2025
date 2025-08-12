# n8n Arena-to-Notion Workflow Setup Guide

## Overview
This n8n workflow automatically updates your Notion database with daily Arena launch readiness scores and progress tracking.

## Prerequisites
1. n8n instance running (self-hosted or cloud)
2. Arena MCP server running on `http://localhost:3001`
3. Notion integration created with database access
4. Slack workspace (optional, for notifications)

## Setup Instructions

### 1. Import the Workflow
1. Open your n8n instance
2. Click "Import" and select `n8n-arena-notion-workflow.json`
3. The workflow will appear in your editor

### 2. Configure Notion Credentials
1. Click on the "Add to Notion" node
2. Click on "Credential to connect with"
3. Select "Create New" and choose "Notion API"
4. Enter your credentials:
   - **Name**: "Arena Notion Integration"
   - **API Key**: Your Notion integration token
5. Click "Create"

### 3. Update Database ID
1. In the "Add to Notion" node
2. Replace `YOUR_DATABASE_ID_HERE` with your actual Notion database ID
3. Ensure your database has these columns:
   - Date (Date type)
   - Launch Score (Number type)
   - Key Accomplishment (Title type)
   - Tomorrow's Priority (Text type)
   - Status (Select type with options: "Launch Ready", "In Progress")
   - Critical Issues (Number type)

### 4. Configure MCP Server URL (if needed)
1. Click on "Get Launch Readiness" node
2. Update the URL if your MCP server runs on a different port
3. Default: `http://localhost:3001/`

### 5. Configure Slack Notifications (Optional)
1. Click on "Send Error Alert" and "Send Success Alert" nodes
2. Create Slack credentials if you want notifications
3. Update the channel name (default: #arena-monitoring)
4. If you don't want Slack notifications, delete these nodes

### 6. Test the Workflow
1. Click "Execute Workflow" to test manually
2. Check the output of each node for errors
3. Verify the Notion database received a new entry

### 7. Activate the Workflow
1. Toggle the "Active" switch at the top
2. The workflow will now run daily at 9 AM

## Troubleshooting

### Common Issues

1. **MCP Server Connection Failed**
   - Ensure Arena MCP server is running on port 3001
   - Check firewall settings
   - Verify the URL in the HTTP Request node

2. **Notion API Error**
   - Verify your integration has access to the database
   - Check that all required columns exist in your database
   - Ensure column names match exactly (case-sensitive)

3. **No Data in Format Node**
   - Check the response structure from your MCP server
   - Update the JavaScript code in "Format Data" node if needed

### Debug Mode
1. Click on any node to see its output
2. Use "Execute Previous Nodes" to test step by step
3. Check the execution log for detailed error messages

## Customization

### Modify Schedule
1. Click on "Daily 9AM Trigger" node
2. Change the cron expression:
   - `0 9 * * *` = 9 AM daily
   - `0 */6 * * *` = Every 6 hours
   - `0 9 * * 1-5` = 9 AM weekdays only

### Add More Data Fields
1. Edit the "Format Data" node to extract additional metrics
2. Add corresponding properties in the "Add to Notion" node
3. Ensure your Notion database has matching columns

### Change Notification Format
1. Edit the text in Slack notification nodes
2. Use n8n expressions to include dynamic data
3. Add email notifications by adding an email node

## Security Best Practices

1. **Never commit credentials** to version control
2. **Use environment variables** for sensitive data in n8n
3. **Restrict Notion integration** to only necessary databases
4. **Use HTTPS** for MCP server in production
5. **Rotate API tokens** regularly

## Maintenance

- Check workflow execution history weekly
- Update MCP server connection if it changes
- Monitor Notion API rate limits
- Keep n8n updated for security patches