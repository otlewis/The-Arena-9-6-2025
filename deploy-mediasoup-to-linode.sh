#!/bin/bash

# Deploy MediaSoup server to Linode (172.236.109.9) on port 3001

echo "🚀 Deploying MediaSoup server to Linode..."

LINODE_IP="172.236.109.9"
MEDIASOUP_PORT="3001"

echo "📡 Target: $LINODE_IP:$MEDIASOUP_PORT"

# Create deployment package (exclude node_modules to save bandwidth)
echo "📦 Creating MediaSoup deployment package..."
cd mediasoup-server
tar -czf ../mediasoup-deploy.tar.gz --exclude=node_modules .
cd ..

# Check if we can connect to server
echo "🔍 Testing server connectivity..."
if ! curl -s --connect-timeout 5 http://$LINODE_IP:3000/ > /dev/null; then
    echo "❌ Cannot reach Linode server"
    exit 1
fi

echo "✅ Server reachable, uploading MediaSoup..."

# For now, let's create the commands that would deploy MediaSoup
echo ""
echo "🚀 MediaSoup deployment commands ready!"
echo ""
echo "To deploy manually, run these commands on your Linode server:"
echo ""
echo "# 1. Create MediaSoup directory"
echo "mkdir -p /opt/arena-mediasoup"
echo "cd /opt/arena-mediasoup"
echo ""
echo "# 2. Upload and extract files"
echo "# (Upload mediasoup-deploy.tar.gz to server)"
echo "tar -xzf mediasoup-deploy.tar.gz"
echo ""
echo "# 3. Install dependencies"
echo "npm install"
echo ""
echo "# 4. Update config for Linode IP"
echo "sed -i 's/192.168.4.94/172.236.109.9/g' config.js"
echo ""
echo "# 5. Start MediaSoup server on port 3001"
echo "PORT=3001 ANNOUNCED_IP=172.236.109.9 nohup node server.js > mediasoup.log 2>&1 &"
echo ""
echo "# 6. Configure firewall"
echo "ufw allow 3001"
echo "ufw allow 10000:10100/udp"
echo "ufw allow 10000:10100/tcp"
echo ""
echo "📋 After deployment, MediaSoup will be available at:"
echo "  • HTTP: http://172.236.109.9:3001"
echo "  • WebRTC: UDP/TCP 10000-10100"