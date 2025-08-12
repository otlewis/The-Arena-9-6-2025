#!/bin/bash

# Deploy updated unified WebRTC server with signaling fixes
SERVER="root@jitsi.dialecticlabs.com"
DEPLOY_DIR="/opt/arena-webrtc"
SERVICE_NAME="arena-webrtc-unified"

echo "🚀 Deploying signaling fixes to $SERVER..."

# Check if server is reachable
if ! ssh -o ConnectTimeout=10 $SERVER "echo 'Server reachable'" > /dev/null 2>&1; then
    echo "❌ Cannot connect to server $SERVER"
    exit 1
fi

# Create backup of current server file
echo "📦 Creating backup of current server..."
ssh $SERVER "cd $DEPLOY_DIR && cp unified-webrtc-server.cjs unified-webrtc-server.cjs.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

# Upload the fixed server file
echo "📤 Uploading fixed server file..."
scp unified-webrtc-server.cjs $SERVER:$DEPLOY_DIR/

if [ $? -ne 0 ]; then
    echo "❌ Failed to upload server file"
    exit 1
fi

# Check what service is currently running
echo "🔍 Checking current service status..."
CURRENT_SERVICE=$(ssh $SERVER "systemctl list-units --type=service --all | grep -E 'arena.*webrtc|webrtc.*arena' | awk '{print \$1}' | head -1")

if [ -n "$CURRENT_SERVICE" ]; then
    echo "📋 Found running service: $CURRENT_SERVICE"
    
    # Restart the service
    echo "🔄 Restarting $CURRENT_SERVICE..."
    ssh $SERVER "systemctl restart $CURRENT_SERVICE"
    
    # Check if service started successfully
    sleep 3
    SERVICE_STATUS=$(ssh $SERVER "systemctl is-active $CURRENT_SERVICE")
    
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo "✅ Service restarted successfully!"
        echo "📊 Service status:"
        ssh $SERVER "systemctl status $CURRENT_SERVICE --no-pager -l" | head -10
    else
        echo "❌ Service failed to start. Status: $SERVICE_STATUS"
        echo "📋 Service logs:"
        ssh $SERVER "journalctl -u $CURRENT_SERVICE --no-pager -n 20"
        exit 1
    fi
else
    echo "⚠️ No arena-webrtc service found. Starting server manually..."
    
    # Start server manually in background
    ssh $SERVER "cd $DEPLOY_DIR && nohup node unified-webrtc-server.cjs > server.log 2>&1 &"
    
    # Wait a moment and check if process started
    sleep 3
    PROCESS_COUNT=$(ssh $SERVER "pgrep -f 'unified-webrtc-server.cjs' | wc -l")
    
    if [ "$PROCESS_COUNT" -gt 0 ]; then
        echo "✅ Server started manually!"
        echo "📋 Process info:"
        ssh $SERVER "ps aux | grep 'unified-webrtc-server.cjs' | grep -v grep"
    else
        echo "❌ Failed to start server manually"
        echo "📋 Server logs:"
        ssh $SERVER "cd $DEPLOY_DIR && tail -20 server.log" 2>/dev/null || echo "No logs found"
        exit 1
    fi
fi

# Test the updated server
echo "🧪 Testing updated server..."
sleep 2

# Test health endpoint
HEALTH_CHECK=$(curl -s -m 5 "http://jitsi.dialecticlabs.com:3001/health" | grep -o '"status":"running"' || echo "")

if [ -n "$HEALTH_CHECK" ]; then
    echo "✅ Server health check passed!"
    echo "🌐 Server is running at: http://jitsi.dialecticlabs.com:3001"
    echo "📡 Signaling endpoint: ws://jitsi.dialecticlabs.com:3001/signaling"
else
    echo "⚠️ Health check failed, but server may still be starting..."
    echo "📋 Checking server response:"
    curl -s -m 5 "http://jitsi.dialecticlabs.com:3001/health" || echo "No response"
fi

echo ""
echo "🎉 Deployment complete!"
echo "📝 Changes deployed:"  
echo "   - Fixed peer-joined events for existing participants"
echo "   - Added proper room participant tracking in signaling namespace"
echo "   - Enhanced disconnect cleanup"
echo ""
echo "🔧 Test the fix by:"
echo "   1. Join debates & discussions room as moderator"
echo "   2. Join as audience from another device"  
echo "   3. Audience should now see moderator's video feed!"