#\!/bin/bash

# Deploy MediaSoup server to Linode
echo "🚀 Deploying MediaSoup server to Linode..."

# Server details
SERVER="root@172.236.109.9"
SERVER_DIR="/opt/mediasoup-server"

# Create directory on server
echo "📁 Creating server directory..."
ssh $SERVER "mkdir -p $SERVER_DIR"

# Copy MediaSoup server file
echo "📤 Copying MediaSoup server..."
scp mediasoup-production-server.cjs $SERVER:$SERVER_DIR/

# Copy package.json for dependencies
echo "📦 Copying package.json..."
scp mediasoup-package.json $SERVER:$SERVER_DIR/package.json

# Install dependencies on server
echo "⚙️ Installing dependencies on server..."
ssh $SERVER "cd $SERVER_DIR && npm install"

# Create systemd service for auto-start
echo "🔧 Creating systemd service..."
ssh $SERVER "cat > /etc/systemd/system/mediasoup-server.service << 'INNER_EOF'
[Unit]
Description=MediaSoup WebRTC Server for Arena
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mediasoup-server
ExecStart=/usr/bin/node mediasoup-production-server.cjs
Restart=always
RestartSec=10
Environment=PORT=3005
Environment=NODE_ENV=production

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mediasoup-server

[Install]
WantedBy=multi-user.target
INNER_EOF"

# Enable and start the service
echo "🚀 Starting MediaSoup server service..."
ssh $SERVER "systemctl daemon-reload"
ssh $SERVER "systemctl enable mediasoup-server"
ssh $SERVER "systemctl start mediasoup-server"

# Check service status
echo "📊 Checking service status..."
ssh $SERVER "systemctl status mediasoup-server --no-pager"

# Open firewall port
echo "🔥 Opening firewall port 3005..."
ssh $SERVER "ufw allow 3005/tcp"

echo "✅ MediaSoup server deployment complete\!"
echo "🔍 Check logs with: ssh $SERVER 'journalctl -u mediasoup-server -f'"
echo "🌐 Server will be available on: http://172.236.109.9:3005"
EOF < /dev/null