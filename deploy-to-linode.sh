#!/bin/bash

SERVER_IP="172.236.109.9"
SERVER_USER="root"
APP_DIR="/var/www/arena"

echo "🚀 Deploying Arena MediaSoup to Linode server..."
echo "📡 Server: $SERVER_IP"
echo "📁 Directory: $APP_DIR"
echo "💪 Capacity: 1,000-1,500 concurrent users"
echo ""

# Create directory on server
echo "📁 Creating app directory..."
ssh $SERVER_USER@$SERVER_IP "mkdir -p $APP_DIR"

# Copy files to server
echo "📤 Uploading files..."
scp start-mediasoup-single.cjs $SERVER_USER@$SERVER_IP:$APP_DIR/
scp package.json $SERVER_USER@$SERVER_IP:$APP_DIR/
scp start-single-server.sh $SERVER_USER@$SERVER_IP:$APP_DIR/

# Install Node.js if needed
echo "🔧 Setting up Node.js environment..."
ssh $SERVER_USER@$SERVER_IP "curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && apt-get install -y nodejs"

# Install PM2 globally
ssh $SERVER_USER@$SERVER_IP "npm install -g pm2"

# Install dependencies
echo "📦 Installing dependencies on server..."
ssh $SERVER_USER@$SERVER_IP "cd $APP_DIR && npm install express socket.io mediasoup cors"

# Configure firewall
echo "🔥 Configuring firewall..."
ssh $SERVER_USER@$SERVER_IP "ufw allow 3001 && ufw allow 10000:10100/udp"

# Stop existing process if running
echo "🛑 Stopping existing processes..."
ssh $SERVER_USER@$SERVER_IP "cd $APP_DIR && pm2 stop arena-mediasoup 2>/dev/null || true"

# Start MediaSoup server
echo "🚀 Starting MediaSoup server..."
ssh $SERVER_USER@$SERVER_IP "cd $APP_DIR && pm2 start start-mediasoup-single.cjs --name arena-mediasoup"
ssh $SERVER_USER@$SERVER_IP "pm2 save && pm2 startup"

# Test deployment
echo "🧪 Testing deployment..."
sleep 5
HEALTH_CHECK=$(curl -s http://$SERVER_IP:3001/health | grep -o '"status":"ok"' || echo "failed")

if [ "$HEALTH_CHECK" = '"status":"ok"' ]; then
    echo ""
    echo "✅ DEPLOYMENT SUCCESSFUL!"
    echo "🌐 MediaSoup server running at: http://$SERVER_IP:3001"
    echo "🏥 Health check: http://$SERVER_IP:3001/health"
    echo "💪 Ready to handle 1,000-1,500 concurrent users"
    echo ""
    echo "📊 Monitor with: ssh $SERVER_USER@$SERVER_IP 'pm2 status'"
    echo "📋 View logs: ssh $SERVER_USER@$SERVER_IP 'pm2 logs arena-mediasoup'"
    echo "🔄 Restart: ssh $SERVER_USER@$SERVER_IP 'pm2 restart arena-mediasoup'"
else
    echo ""
    echo "❌ DEPLOYMENT FAILED - server not responding"
    echo "🔍 Debug with: ssh $SERVER_USER@$SERVER_IP 'pm2 logs arena-mediasoup'"
    echo "🔍 Check status: ssh $SERVER_USER@$SERVER_IP 'pm2 status'"
fi