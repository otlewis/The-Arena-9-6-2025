#!/bin/bash

# MediaSoup Server Deployment Script for jitsi.dialecticlabs.com
# Run this script on your Linode server as root

echo "🚀 Setting up MediaSoup server on jitsi.dialecticlabs.com..."

# Create directory
mkdir -p /opt/mediasoup-server
cd /opt/mediasoup-server

# Copy the server files (you'll need to upload these manually)
# Required files:
# - simple-server.js
# - package.json (to be created)

# Create package.json
cat > package.json << 'EOF'
{
  "name": "arena-mediasoup-server",
  "version": "1.0.0",
  "description": "Arena MediaSoup signaling server",
  "main": "simple-server.js",
  "scripts": {
    "start": "node simple-server.js",
    "dev": "nodemon simple-server.js"
  },
  "dependencies": {
    "express": "^4.21.2",
    "socket.io": "^4.8.1",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^3.1.10"
  }
}
EOF

# Install dependencies
npm install

# Create systemd service
cat > /etc/systemd/system/mediasoup.service << 'EOF'
[Unit]
Description=Arena MediaSoup Signaling Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mediasoup-server
ExecStart=/usr/bin/node simple-server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=8443

[Install]
WantedBy=multi-user.target
EOF

# Open firewall port
ufw allow 8443/tcp

# Start and enable service
systemctl daemon-reload
systemctl enable mediasoup
systemctl start mediasoup

# Check status
systemctl status mediasoup

echo "✅ MediaSoup server setup complete!"
echo "🌐 Server will be available at: https://jitsi.dialecticlabs.com:8443"
echo "🔍 Check logs with: journalctl -u mediasoup -f"