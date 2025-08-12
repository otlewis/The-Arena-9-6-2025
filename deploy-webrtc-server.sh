#!/bin/bash

echo "🚀 Deploying Arena WebRTC server to Linode..."

# Server details
SERVER_IP="172.236.109.9"
SERVER_USER="root"

# Copy files to server
echo "📁 Copying server files..."
scp arena-webrtc-server.cjs ${SERVER_USER}@${SERVER_IP}:~/
scp server-package.json ${SERVER_USER}@${SERVER_IP}:~/package.json

# Connect to server and set up
ssh ${SERVER_USER}@${SERVER_IP} << 'EOF'
echo "🔧 Setting up Arena WebRTC server..."

# Install dependencies
npm install

# Stop any existing processes on port 3000
pkill -f "node.*3000" || true
pkill -f "arena-webrtc-server" || true

# Open firewall for port 3000
ufw allow 3000

# Start the server in background
nohup node arena-webrtc-server.cjs > arena-webrtc.log 2>&1 &

# Wait a moment for server to start
sleep 3

# Check if server is running
if curl -s http://localhost:3000/ > /dev/null; then
    echo "✅ Arena WebRTC server is running on port 3000"
    echo "📡 WebSocket endpoint: ws://172.236.109.9:3000"
    echo "🔗 Health check: http://172.236.109.9:3000/"
else
    echo "❌ Server failed to start"
    echo "📋 Last few log lines:"
    tail -10 arena-webrtc.log
fi
EOF

echo "🎉 Deployment complete!"
echo ""
echo "🔍 To check server status:"
echo "curl http://172.236.109.9:3000/"
echo ""
echo "📋 To view server logs:"
echo "ssh root@172.236.109.9 'tail -f arena-webrtc.log'"