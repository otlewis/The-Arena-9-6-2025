#!/bin/bash
echo "📦 Installing dependencies..."
npm install

echo "🔧 Setting up environment..."
PUBLIC_IP=$(curl -s ifconfig.me)
sed -i "s/YOUR_SERVER_IP/$PUBLIC_IP/g" /etc/systemd/system/arena-webrtc.service

echo "🚀 Starting service..."
systemctl daemon-reload
systemctl enable arena-webrtc
systemctl restart arena-webrtc

echo "✅ Service status:"
systemctl status arena-webrtc --no-pager
