#!/bin/bash

echo "🚀 Deploying WebSocket WebRTC server to Linode on port 3002..."

# Server details
SERVER="jitsi.dialecticlabs.com"
SERVER_USER="root"

# Copy files to server
echo "📁 Copying server files..."
scp simple-webrtc-server.cjs ${SERVER_USER}@${SERVER}:~/
scp websocket-package.json ${SERVER_USER}@${SERVER}:~/package.json

# Connect to server and set up
ssh ${SERVER_USER}@${SERVER} << 'EOF'
echo "🔧 Setting up WebSocket WebRTC server..."

# Install dependencies
npm install

# Stop any existing processes on port 3002
pkill -f "node.*3002" || true
pkill -f "simple-webrtc-server" || true

# Open firewall for port 3002
ufw allow 3002

# Start the server in background
nohup node simple-webrtc-server.cjs > websocket-webrtc.log 2>&1 &

# Wait a moment for server to start
sleep 3

# Check if server is running
if lsof -Pi :3002 -sTCP:LISTEN -t >/dev/null; then
    echo "✅ WebSocket WebRTC server is running on port 3002"
    echo "📡 WebSocket endpoint: ws://172.236.109.9:3002"
else
    echo "❌ Server failed to start"
    echo "📋 Last few log lines:"
    tail -10 websocket-webrtc.log
fi
EOF

echo "🎉 Deployment complete!"
echo ""
echo "🔍 To check server status:"
echo "ssh root@jitsi.dialecticlabs.com 'lsof -Pi :3002 -sTCP:LISTEN'"
echo ""
echo "📋 To view server logs:"
echo "ssh root@jitsi.dialecticlabs.com 'tail -f websocket-webrtc.log'"