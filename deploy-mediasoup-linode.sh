#!/bin/bash

# Deploy MediaSoup Server to Linode (172.236.109.9) for Arena App
# This script sets up your MediaSoup server for direct bypass of MediaSFU interface

echo "🚀 Deploying MediaSoup server to Linode for Arena app..."

LINODE_IP="172.236.109.9"
SERVER_PORT="4443"

echo "📡 Server: $LINODE_IP:$SERVER_PORT"
echo "🎯 Purpose: Direct MediaSoup connection bypassing MediaSFU interface"

# Copy setup script to Linode server
echo "📤 Copying setup script to Linode server..."
scp setup-mediasoup-server.sh root@$LINODE_IP:/tmp/

# Connect to server and run setup
echo "🔧 Connecting to Linode and setting up MediaSoup..."
ssh root@$LINODE_IP << 'EOF'
cd /tmp
chmod +x setup-mediasoup-server.sh
./setup-mediasoup-server.sh

# Start the MediaSoup server
cd ~/mediasoup-server
echo "🔥 Starting MediaSoup server for Arena..."
./start-server.sh &

# Configure firewall for MediaSoup
echo "🔥 Configuring firewall for MediaSoup..."
ufw allow 4443
ufw allow 40000:49999/udp
ufw allow 40000:49999/tcp

echo "✅ MediaSoup server is now running!"
echo "📡 WebSocket endpoint: wss://172.236.109.9:4443"
echo "🎯 Your Arena app can now connect directly without MediaSFU interface"
EOF

echo ""
echo "🎉 MediaSoup deployment complete!"
echo ""
echo "📋 Next steps:"
echo "1. Build your Arena app: flutter build ios --no-codesign"
echo "2. Tap 'ZERO UI - Linode Server' button in Arena app"
echo "3. You'll go directly to conference room - NO MediaSFU interface!"
echo ""
echo "🔗 Server status: https://172.236.109.9:4443/"
echo "🎥 Conference endpoint: wss://172.236.109.9:4443"