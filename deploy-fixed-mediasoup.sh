#!/bin/bash

echo "🔄 Deploying fixed MediaSoup server for Flutter compatibility..."

# Server details
SERVER_IP="172.236.109.9"
SERVER_USER="root"
SERVER_DIR="/opt/mediasoup-server"

echo "📁 Creating server directory structure..."
ssh ${SERVER_USER}@${SERVER_IP} "mkdir -p ${SERVER_DIR}"

echo "📦 Uploading fixed MediaSoup server..."
scp mediasoup-flutter-compatible-server.cjs ${SERVER_USER}@${SERVER_IP}:${SERVER_DIR}/

echo "📝 Creating package.json..."
ssh ${SERVER_USER}@${SERVER_IP} "cd ${SERVER_DIR} && cat > package.json << 'EOF'
{
  \"name\": \"arena-mediasoup-sfu\",
  \"version\": \"1.0.0\",
  \"description\": \"MediaSoup SFU server for Arena app with Flutter client compatibility\",
  \"main\": \"mediasoup-flutter-compatible-server.cjs\",
  \"scripts\": {
    \"start\": \"node mediasoup-flutter-compatible-server.cjs\",
    \"dev\": \"nodemon mediasoup-flutter-compatible-server.cjs\"
  },
  \"dependencies\": {
    \"express\": \"^4.18.2\",
    \"socket.io\": \"^4.7.2\",
    \"mediasoup\": \"^3.12.5\",
    \"cors\": \"^2.8.5\"
  },
  \"engines\": {
    \"node\": \">=16.0.0\"
  }
}
EOF"

echo "📦 Installing dependencies..."
ssh ${SERVER_USER}@${SERVER_IP} "cd ${SERVER_DIR} && npm install"

echo "🛑 Stopping existing MediaSoup server..."
ssh ${SERVER_USER}@${SERVER_IP} "pkill -f mediasoup || true"

echo "🚀 Starting fixed MediaSoup server..."
ssh ${SERVER_USER}@${SERVER_IP} "cd ${SERVER_DIR} && PORT=3005 ANNOUNCED_IP=172.236.109.9 nohup node mediasoup-flutter-compatible-server.cjs > mediasoup.log 2>&1 &"

echo "⏳ Waiting for server to start..."
sleep 3

echo "🔍 Checking server status..."
ssh ${SERVER_USER}@${SERVER_IP} "ps aux | grep mediasoup | grep -v grep" || echo "⚠️ Server process not found"

echo "🩺 Testing health endpoint..."
curl -s http://172.236.109.9:3005/health | jq . || echo "⚠️ Health check failed"

echo "📋 Server logs:"
ssh ${SERVER_USER}@${SERVER_IP} "cd ${SERVER_DIR} && tail -20 mediasoup.log"

echo "✅ Fixed MediaSoup server deployment complete!"
echo "🔗 Server URL: http://172.236.109.9:3005"
echo "🩺 Health check: http://172.236.109.9:3005/health"
echo "🔌 Socket.IO: http://172.236.109.9:3005/socket.io/"