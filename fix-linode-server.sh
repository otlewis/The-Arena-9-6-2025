#!/bin/bash

echo "🔧 Fixing Linode server stability..."

SERVER_IP="172.236.109.9"
SERVER_USER="root"

# Upload the server files again (in case they got corrupted)
echo "📁 Re-uploading server files..."
scp arena-webrtc-server.cjs ${SERVER_USER}@${SERVER_IP}:~/
scp server-package.json ${SERVER_USER}@${SERVER_IP}:~/package.json

# Connect and set up a robust server
ssh ${SERVER_USER}@${SERVER_IP} << 'EOF'
echo "🔧 Setting up robust Arena WebRTC server..."

# Clean up any existing processes
pkill -f arena-webrtc-server || true
pkill -f "node.*3000" || true

# Install PM2 for process management
npm install -g pm2

# Install dependencies
npm install

# Create PM2 ecosystem file for better process management
cat > ecosystem.config.js << 'ECOSYSTEM'
module.exports = {
  apps: [{
    name: 'arena-webrtc',
    script: 'arena-webrtc-server.cjs',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production'
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
}
ECOSYSTEM

# Create logs directory
mkdir -p logs

# Start server with PM2
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Set up PM2 to start on boot
pm2 startup

echo "✅ PM2 server setup complete"

# Show server status
pm2 status

# Test the server
sleep 3
if curl -s http://localhost:3000/ > /dev/null; then
    echo "✅ Server is running and responding"
    curl http://localhost:3000/
else
    echo "❌ Server test failed"
    pm2 logs arena-webrtc --lines 10
fi

EOF

echo "🎉 Robust server deployment complete!"
echo ""
echo "🔍 To check server status:"
echo "ssh root@172.236.109.9 'pm2 status'"
echo ""
echo "📋 To view server logs:"
echo "ssh root@172.236.109.9 'pm2 logs arena-webrtc'"
echo ""
echo "🔄 To restart server if needed:"
echo "ssh root@172.236.109.9 'pm2 restart arena-webrtc'"