#!/bin/bash

echo "🔧 Updating MediaSoup server to enable WebSocket upgrades..."

# SSH into the server and update the configuration
ssh root@172.236.109.9 << 'EOF'

# Navigate to the MediaSoup directory
cd /opt/arena-mediasoup

# Create a backup of the current configuration
cp mediasoup-production-server.cjs mediasoup-production-server.cjs.backup

# Update the Socket.IO configuration to allow WebSocket upgrades
sed -i "s/transports: \['polling'\]/transports: ['polling', 'websocket']/g" mediasoup-production-server.cjs

# Also ensure allowUpgrades is set to true
sed -i "s/allowUpgrades: false/allowUpgrades: true/g" mediasoup-production-server.cjs

# Show the changes
echo "📋 Updated configuration:"
grep -A 5 "transports:" mediasoup-production-server.cjs
grep "allowUpgrades:" mediasoup-production-server.cjs

# Restart the PM2 service
echo "🔄 Restarting PM2 service arena-mediasoup..."
pm2 restart arena-mediasoup

# Check the status
pm2 status arena-mediasoup

# Show recent logs
echo "📜 Recent logs:"
pm2 logs arena-mediasoup --lines 10 --nostream

EOF

echo "✅ MediaSoup server configuration updated and service restarted!"