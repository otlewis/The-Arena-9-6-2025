#!/bin/bash

# Arena HubSpot Webhooks Setup Script
# This script creates Appwrite webhooks for HubSpot CRM integration

set -e

# Configuration
PROJECT_ID="676cd3120028b01ad06c"
DATABASE_ID="arena_db"
API_ENDPOINT="https://cloud.appwrite.io/v1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if APPWRITE_API_KEY is set
if [ -z "$APPWRITE_API_KEY" ]; then
    echo -e "${RED}Error: APPWRITE_API_KEY environment variable is not set${NC}"
    echo "Please set it with: export APPWRITE_API_KEY='your-api-key'"
    exit 1
fi

# Check if N8N_WEBHOOK_URL is set
if [ -z "$N8N_WEBHOOK_URL" ]; then
    echo -e "${YELLOW}Warning: N8N_WEBHOOK_URL not set${NC}"
    echo "Please enter your n8n webhook base URL (e.g., https://n8n.yourdomain.com/webhook):"
    read N8N_WEBHOOK_URL
fi

echo -e "${GREEN}=== Arena HubSpot Webhooks Setup ===${NC}\n"

# Function to create webhook
create_webhook() {
    local name=$1
    local events=$2
    local url=$3

    echo -e "${YELLOW}Creating webhook: $name${NC}"

    response=$(curl -s -w "\n%{http_code}" -X POST \
        "${API_ENDPOINT}/projects/${PROJECT_ID}/webhooks" \
        -H "X-Appwrite-Project: ${PROJECT_ID}" \
        -H "X-Appwrite-Key: ${APPWRITE_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$name\",
            \"events\": [$events],
            \"url\": \"$url\",
            \"security\": true,
            \"httpUser\": \"\",
            \"httpPass\": \"\"
        }")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" -eq 201 ]; then
        webhook_id=$(echo "$body" | grep -o '"$id":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo -e "${GREEN}✓ Webhook created successfully: $webhook_id${NC}\n"
        return 0
    else
        echo -e "${RED}✗ Failed to create webhook${NC}"
        echo "Response: $body"
        echo "HTTP Code: $http_code\n"
        return 1
    fi
}

# 1. User Sync Webhook
echo -e "${GREEN}1. Setting up User Sync Webhook${NC}"
create_webhook \
    "HubSpot User Sync" \
    "\"databases.${DATABASE_ID}.collections.users.documents.*.create\",\"databases.${DATABASE_ID}.collections.users.documents.*.update\"" \
    "${N8N_WEBHOOK_URL}/arena-user-sync"

# 2. Debate Tracker Webhook
echo -e "${GREEN}2. Setting up Debate Tracker Webhook${NC}"
create_webhook \
    "HubSpot Debate Tracker" \
    "\"databases.${DATABASE_ID}.collections.arena_rooms.documents.*.update\"" \
    "${N8N_WEBHOOK_URL}/arena-debate-tracker"

# 3. Subscription Manager Webhook
echo -e "${GREEN}3. Setting up Subscription Manager Webhook${NC}"
create_webhook \
    "HubSpot Subscription Manager" \
    "\"databases.${DATABASE_ID}.collections.users.documents.*.update\"" \
    "${N8N_WEBHOOK_URL}/arena-subscription-update"

echo -e "${GREEN}=== Webhook Setup Complete ===${NC}\n"
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Import n8n workflows from the project root:"
echo "   - n8n-arena-user-sync.json"
echo "   - n8n-arena-debate-tracker.json"
echo "   - n8n-arena-subscription-manager.json"
echo "   - n8n-arena-milestone-handler.json"
echo "   - n8n-arena-inactivity-detector.json"
echo ""
echo "2. Configure HubSpot credentials in n8n"
echo "3. Test each webhook with sample data"
echo "4. Monitor webhook execution in n8n dashboard"
echo ""
echo -e "${GREEN}Setup script completed successfully!${NC}"
