#!/bin/bash

# Deploy MediaSoup SFU Server
SERVER="root@jitsi.dialecticlabs.com"
DEPLOY_DIR="/opt/arena-webrtc"
SERVICE_NAME="mediasoup-sfu"

echo "🚀 Deploying MediaSoup SFU server to $SERVER..."

# Check if server is reachable
if ! ssh -o ConnectTimeout=10 $SERVER "echo 'Server reachable'" > /dev/null 2>&1; then
    echo "❌ Cannot connect to server $SERVER"
    exit 1
fi

# Create deployment directory
echo "📁 Creating deployment directory..."
ssh $SERVER "mkdir -p $DEPLOY_DIR"

# Upload server file
echo "📤 Uploading MediaSoup SFU server..."
scp mediasoup-sfu-server.js $SERVER:$DEPLOY_DIR/

if [ $? -ne 0 ]; then
    echo "❌ Failed to upload server file"
    exit 1
fi

# Create package.json for MediaSoup dependencies
echo "📦 Creating package.json..."
cat > temp-package.json << 'EOF'
{
  "name": "arena-mediasoup-sfu",
  "version": "1.0.0",
  "description": "Arena MediaSoup SFU Server",
  "main": "mediasoup-sfu-server.js",
  "scripts": {
    "start": "node mediasoup-sfu-server.js"
  },
  "dependencies": {
    "express": "^4.21.2",
    "socket.io": "^4.8.1",
    "mediasoup": "^3.16.7",
    "cors": "^2.8.5"
  }
}
EOF

scp temp-package.json $SERVER:$DEPLOY_DIR/package.json
rm temp-package.json

# Create systemd service file
echo "⚙️ Creating systemd service..."
cat > temp-service << 'EOF'
[Unit]
Description=Arena MediaSoup SFU Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/arena-webrtc
ExecStart=/usr/bin/node mediasoup-sfu-server.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=mediasoup-sfu
Environment="NODE_ENV=production"
Environment="PORT=3001"
Environment="ANNOUNCED_IP=172.236.109.9"
Environment="DEBUG=mediasoup:INFO,mediasoup:WARN,mediasoup:ERROR"

[Install]
WantedBy=multi-user.target
EOF

scp temp-service $SERVER:/etc/systemd/system/mediasoup-sfu.service
rm temp-service

# Install dependencies and configure server
echo "🔧 Installing dependencies and configuring server..."
ssh $SERVER << 'ENDSSH'
cd /opt/arena-webrtc

# Install Node.js if not present
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
fi

# Install dependencies
npm install

# Open required ports for MediaSoup
ufw allow 3001/tcp
ufw allow 10000:10100/udp

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable mediasoup-sfu

# Stop any existing services that might conflict
systemctl stop arena-webrtc-unified 2>/dev/null || true

# Start the new service
systemctl restart mediasoup-sfu

# Wait for service to start
sleep 5

# Check service status
systemctl is-active mediasoup-sfu
ENDSSH

# Verify deployment
echo "🧪 Testing server deployment..."
sleep 3

HEALTH_CHECK=$(curl -s -m 10 "http://jitsi.dialecticlabs.com:3001/health" | grep -o '"status":"healthy"' || echo "")

if [ -n "$HEALTH_CHECK" ]; then
    echo "✅ MediaSoup SFU server deployed successfully!"
    echo "🌐 Server health: http://jitsi.dialecticlabs.com:3001/health"
    echo "📊 Service status:"
    ssh $SERVER "systemctl status mediasoup-sfu --no-pager -l" | head -10
else
    echo "⚠️ Health check failed, checking service status..."
    ssh $SERVER "systemctl status mediasoup-sfu --no-pager -l"
    echo "📋 Service logs:"
    ssh $SERVER "journalctl -u mediasoup-sfu --no-pager -n 20"
fi

echo ""
echo "🎉 Deployment complete!"
echo "📝 MediaSoup SFU Features:"
echo "  - Supports large rooms (100+ audience members)"
echo "  - Role-based permissions (moderators/speakers publish)"
echo "  - Selective Forwarding Unit architecture"
echo "  - Auto-scaling with multiple workers"
echo ""
echo "🔧 Next steps:"
echo "  1. Update Flutter client to use sfuMode: true"
echo "  2. Test with moderator + audience"
echo "  3. Monitor logs: journalctl -u mediasoup-sfu -f"
echo "  4. Scale test with many audience members"