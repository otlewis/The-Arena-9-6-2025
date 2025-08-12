#!/bin/bash

echo "🚀 Uploading Arena WebRTC server files to Linode..."

SERVER_IP="172.236.109.9"
SERVER_USER="root"

# Upload files
echo "📁 Uploading server files..."
scp arena-webrtc-server.cjs ${SERVER_USER}@${SERVER_IP}:~/
scp server-package.json ${SERVER_USER}@${SERVER_IP}:~/package.json

echo "✅ Files uploaded successfully!"

echo ""
echo "🔧 Now SSH into your server and run:"
echo "ssh root@172.236.109.9"
echo "npm install"
echo "node arena-webrtc-server.cjs &"
echo ""
echo "🧪 Then test with:"
echo "curl http://172.236.109.9:3000/"