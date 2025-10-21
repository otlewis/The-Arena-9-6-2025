#!/bin/bash

# Script to create Appwrite webhook for Arena Challenge Navigation
# Usage: ./create_arena_challenge_webhook.sh [YOUR_N8N_WEBHOOK_URL]

if [ -z "$1" ]; then
    echo "❌ Error: No webhook URL provided"
    echo ""
    echo "Usage: ./create_arena_challenge_webhook.sh [YOUR_N8N_WEBHOOK_URL]"
    echo ""
    echo "Example:"
    echo "  ./create_arena_challenge_webhook.sh https://n8n.dialectlabs.com/webhook/arena-challenge-accepted"
    echo ""
    echo "To get your webhook URL:"
    echo "  1. Open the 'Webhook - Challenge Update' node in n8n"
    echo "  2. Look for the 'Production URL' or 'Webhook URL'"
    echo "  3. Copy the URL and paste it as the argument to this script"
    exit 1
fi

WEBHOOK_URL="$1"

echo "🎯 Creating Appwrite webhook for Arena Challenge Navigation..."
echo "📍 Target URL: $WEBHOOK_URL"
echo ""

# Create the webhook using Appwrite CLI
appwrite webhooks create \
  --name "Arena Challenge Navigation" \
  --events "databases.arena_db.collections.challenge_messages.documents.*.update" \
  --url "$WEBHOOK_URL" \
  --security true \
  --enabled true

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Webhook created successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "  1. Test the instant challenge flow"
    echo "  2. Watch for logs with 🎯 emoji in Flutter app"
    echo "  3. Check n8n executions to verify workflow triggers"
    echo ""
    echo "🐛 Debugging:"
    echo "  - Check n8n Executions tab for workflow runs"
    echo "  - Check Appwrite Console → Webhooks for delivery status"
    echo "  - Check Flutter logs for navigation notifications"
else
    echo ""
    echo "❌ Failed to create webhook"
    echo ""
    echo "💡 Manual setup:"
    echo "  1. Go to Appwrite Console → Your Project → Webhooks"
    echo "  2. Click 'Create Webhook'"
    echo "  3. Set Name: 'Arena Challenge Navigation'"
    echo "  4. Set Events: Database → challenge_messages → Update"
    echo "  5. Set URL: $WEBHOOK_URL"
    echo "  6. Enable 'HTTP Basic Authentication' if needed"
    echo "  7. Click 'Create'"
fi
