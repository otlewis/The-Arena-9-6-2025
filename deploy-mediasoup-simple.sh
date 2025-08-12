#!/bin/bash

# Simple MediaSoup server deployment to existing Linode server
# Uses the same server as your WebRTC signaling but on different service

echo "🚀 Deploying MediaSoup server alongside existing WebRTC server..."

LINODE_IP="172.236.109.9"
MEDIASOUP_PORT="3000"

echo "📡 Target: $LINODE_IP:$MEDIASOUP_PORT"

# Create deployment package
echo "📦 Creating deployment package..."
tar -czf mediasoup-deploy.tar.gz -C mediasoup-server --exclude=node_modules .

# Upload to server
echo "📤 Uploading to Linode server..."
scp mediasoup-deploy.tar.gz root@$LINODE_IP:/tmp/

# Connect and deploy
echo "🔧 Setting up MediaSoup server on Linode..."
ssh root@$LINODE_IP << 'EOF'
# Stop any existing MediaSoup processes
sudo pkill -f "mediasoup" || true

# Create MediaSoup directory
mkdir -p /opt/arena-mediasoup
cd /opt/arena-mediasoup

# Extract files
tar -xzf /tmp/mediasoup-deploy.tar.gz

# Install dependencies
npm install

# Configure for production
export NODE_ENV=development
export ANNOUNCED_IP=172.236.109.9

# Start MediaSoup server
echo "🔥 Starting MediaSoup server..."
nohup node server.js > mediasoup.log 2>&1 &

# Configure firewall for MediaSoup WebRTC ports
echo "🔥 Configuring firewall..."
ufw allow 10000:10100/udp
ufw allow 10000:10100/tcp

echo "✅ MediaSoup server started!"
echo "📋 Server running on port 3000 (HTTP)"
echo "🎯 WebRTC ports: 10000-10100"
EOF

# Cleanup
rm mediasoup-deploy.tar.gz

echo ""
echo "🎉 MediaSoup deployment complete!"
echo ""
echo "📋 Server endpoints:"
echo "  • HTTP: http://172.236.109.9:3000"
echo "  • WebRTC: UDP/TCP 10000-10100"
echo ""
echo "🔗 Test connection:"
echo "  curl http://172.236.109.9:3000/"