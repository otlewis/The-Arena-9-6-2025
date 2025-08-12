#!/bin/bash

# Deploy MediaSoup server with video support to Linode
# This script uploads the updated server and restarts it

SERVER_IP="172.236.109.9"
SERVER_USER="root"
SERVER_PATH="/root/mediasoup-server"

echo "🚀 Deploying MediaSoup server with video support..."

# Create deployment package
echo "📦 Creating deployment package..."
cat > mediasoup-package.json << 'EOF'
{
  "name": "arena-mediasoup-server",
  "version": "2.0.0",
  "description": "Arena MediaSoup SFU Server with Video Support",
  "main": "mediasoup-production-server.cjs",
  "scripts": {
    "start": "node mediasoup-production-server.cjs"
  },
  "dependencies": {
    "express": "^4.18.2",
    "socket.io": "^4.6.1",
    "mediasoup": "^3.13.24",
    "cors": "^2.8.5"
  }
}
EOF

# Copy the updated server file
cp mediasoup-production-server.cjs mediasoup-production-server-deploy.cjs

# Create tar archive with server files
tar -czf mediasoup-video-update.tar.gz \
  mediasoup-production-server-deploy.cjs \
  mediasoup-package.json

echo "📤 Uploading to server..."
scp mediasoup-video-update.tar.gz $SERVER_USER@$SERVER_IP:~/

echo "🔧 Installing and starting server..."
ssh $SERVER_USER@$SERVER_IP << 'ENDSSH'
# Stop existing server
echo "🛑 Stopping existing MediaSoup server..."
pkill -f mediasoup-production-server || true
systemctl stop mediasoup-server 2>/dev/null || true
systemctl stop mediasoup-sfu 2>/dev/null || true

# Extract update
cd ~
tar -xzf mediasoup-video-update.tar.gz

# Move to server directory
mkdir -p /root/mediasoup-server
mv mediasoup-production-server-deploy.cjs /root/mediasoup-server/mediasoup-production-server.cjs
mv mediasoup-package.json /root/mediasoup-server/package.json

# Install dependencies
cd /root/mediasoup-server
echo "📦 Installing dependencies..."
npm install

# Create systemd service
echo "🔧 Creating systemd service..."
cat > /etc/systemd/system/mediasoup-sfu.service << 'EOF'
[Unit]
Description=Arena MediaSoup SFU Server with Video
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/mediasoup-server
ExecStart=/usr/bin/node /root/mediasoup-server/mediasoup-production-server.cjs
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mediasoup-sfu
Environment="NODE_ENV=production"
Environment="PORT=3001"
Environment="ANNOUNCED_IP=172.236.109.9"

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
systemctl daemon-reload
systemctl enable mediasoup-sfu
systemctl start mediasoup-sfu

# Check status
sleep 3
systemctl status mediasoup-sfu --no-pager

# Test the server
echo "🧪 Testing server health..."
curl -s http://localhost:3001/ | jq '.' || echo "Server may need a moment to start..."

# Show logs
echo "📋 Recent logs:"
journalctl -u mediasoup-sfu -n 20 --no-pager

ENDSSH

# Cleanup
rm -f mediasoup-video-update.tar.gz mediasoup-package.json mediasoup-production-server-deploy.cjs

echo "✅ Deployment complete! MediaSoup server should now support video."
echo "🎥 Video is enabled for moderators and speakers"
echo "🔗 Server running at http://$SERVER_IP:3001"