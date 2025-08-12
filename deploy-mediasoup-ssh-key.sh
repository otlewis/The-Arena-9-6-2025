#!/bin/bash

# Deploy MediaSoup Server to Linode using SSH keys (no password needed)
echo "🚀 Deploying MediaSoup server to Linode using SSH keys..."

LINODE_IP="172.236.109.9"

# Copy setup script using SSH key
echo "📤 Copying setup script to Linode server..."
scp -o StrictHostKeyChecking=no setup-mediasoup-server.sh root@$LINODE_IP:/tmp/

# Connect and run setup using SSH key
echo "🔧 Setting up MediaSoup on Linode..."
ssh -o StrictHostKeyChecking=no root@$LINODE_IP bash << 'EOF'
cd /tmp
chmod +x setup-mediasoup-server.sh
./setup-mediasoup-server.sh

# Start the server
cd ~/mediasoup-server
nohup ./start-server.sh > server.log 2>&1 &

# Configure firewall
ufw allow 4443
ufw allow 40000:49999/udp
ufw allow 40000:49999/tcp

echo "✅ MediaSoup server started successfully!"
echo "📡 Server running at: https://172.236.109.9:4443"
EOF

echo "🎉 Deployment complete! Your Arena app can now bypass MediaSFU interface!"