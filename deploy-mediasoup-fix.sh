#!/bin/bash

# Deploy MediaSoup Server Fix - Force Polling Only Transport
# This script deploys the updated server configuration to fix WebSocket upgrade issues

set -e

echo "🚀 Deploying MediaSoup server fix to production..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SERVER_HOST="root@jitsi.dialecticlabs.com"
SERVER_FILE="mediasoup-production-server.js"

echo -e "${YELLOW}📋 Deployment Steps:${NC}"
echo "1. Upload updated server file"
echo "2. Stop current MediaSoup server"
echo "3. Start server with new configuration"
echo "4. Verify server is running"
echo ""

# Step 1: Upload the updated server file
echo -e "${YELLOW}📤 Step 1: Uploading updated server file...${NC}"
if scp "$SERVER_FILE" "$SERVER_HOST:/root/"; then
    echo -e "${GREEN}✅ Server file uploaded successfully${NC}"
else
    echo -e "${RED}❌ Failed to upload server file${NC}"
    exit 1
fi

# Step 2: Stop current server
echo -e "${YELLOW}🛑 Step 2: Stopping current MediaSoup server...${NC}"
ssh "$SERVER_HOST" "pkill -f 'node.*mediasoup-production-server' || true"
sleep 2

# Step 3: Start server with new configuration
echo -e "${YELLOW}🚀 Step 3: Starting MediaSoup server with new configuration...${NC}"
ssh "$SERVER_HOST" "cd /root && nohup node mediasoup-production-server.js > mediasoup.log 2>&1 &"
sleep 3

# Step 4: Verify server is running
echo -e "${YELLOW}🔍 Step 4: Verifying server is running...${NC}"
sleep 2

# Check if server is responding
if curl -s -f "http://jitsi.dialecticlabs.com/health" > /dev/null; then
    echo -e "${GREEN}✅ MediaSoup server is running successfully${NC}"
    
    # Get server status
    echo -e "${YELLOW}📊 Server Status:${NC}"
    curl -s "http://jitsi.dialecticlabs.com/health" | jq '.' || curl -s "http://jitsi.dialecticlabs.com/health"
    
    echo ""
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
    echo -e "${YELLOW}📝 Changes applied:${NC}"
    echo "   - Server now forces polling-only transport"
    echo "   - WebSocket upgrades are disabled server-side"
    echo "   - Engine.IO v3 compatibility enabled"
    echo ""
    echo -e "${YELLOW}🧪 Next steps:${NC}"
    echo "   1. Test camera toggle in Debates & Discussions room"
    echo "   2. Verify no WebSocket upgrade errors in Flutter logs"
    echo "   3. Confirm MediaSoup connection establishes successfully"
    
else
    echo -e "${RED}❌ Server verification failed${NC}"
    echo "Checking server logs..."
    ssh "$SERVER_HOST" "tail -20 /root/mediasoup.log" || true
    exit 1
fi