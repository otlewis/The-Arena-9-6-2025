#!/bin/bash

echo "📦 Installing Arena WebRTC Signaling Server..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js (if not already installed)
if ! command -v node &> /dev/null; then
    echo "📥 Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Install PM2 globally (if not already installed)
if ! command -v pm2 &> /dev/null; then
    echo "📥 Installing PM2..."
    sudo npm install -g pm2
fi

# Create application directory
sudo mkdir -p /opt/arena-webrtc
sudo chown $USER:$USER /opt/arena-webrtc

# Copy files
cp signaling-server.js /opt/arena-webrtc/
cp package.json /opt/arena-webrtc/
cp ecosystem.config.js /opt/arena-webrtc/

# Install dependencies
cd /opt/arena-webrtc
npm install --production

# Setup PM2
pm2 start ecosystem.config.js --env production
pm2 save
pm2 startup

echo "✅ Arena WebRTC Signaling Server installed!"
echo "🔗 Server running on http://localhost:3001"
echo ""
echo "🔥 To manage the service:"
echo "   pm2 status           # Check status"
echo "   pm2 restart all      # Restart"
echo "   pm2 logs             # View logs"
echo "   pm2 monit            # Monitor"
echo ""
echo "🌐 Test endpoints:"
echo "   curl http://localhost:3001/"
echo "   curl http://localhost:3001/health"
echo "   curl http://localhost:3001/stats"
