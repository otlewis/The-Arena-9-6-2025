#!/bin/bash

# Deploy Unified WebRTC Server Update
# This replaces the existing server with proper MediaSoup namespace support

SERVER="root@jitsi.dialecticlabs.com"
REMOTE_DIR="/opt/arena-webrtc"

echo "🚀 Deploying unified WebRTC server update..."

# Upload new unified server
echo "📤 Uploading unified server..."
scp unified-webrtc-server.cjs $SERVER:$REMOTE_DIR/
scp arena-webrtc-unified.service $SERVER:/etc/systemd/system/

echo "🔄 Updating server on remote..."
ssh $SERVER << 'EOF'
cd /opt/arena-webrtc

echo "⏹️ Stopping old arena-webrtc service..."
systemctl stop arena-webrtc
systemctl disable arena-webrtc

echo "🔄 Reloading systemd and starting unified service..."
systemctl daemon-reload
systemctl enable arena-webrtc-unified
systemctl start arena-webrtc-unified

echo "✅ Unified server started!"

echo "📊 Service status:"
systemctl status arena-webrtc-unified --no-pager -l

echo "🔍 Checking if server is responding..."
sleep 3
curl -s http://localhost:3001/health || echo "❌ Health check failed"

echo "📋 Recent logs:"
journalctl -u arena-webrtc-unified --lines=10 --no-pager
EOF

echo "✅ Deployment complete!"
echo "🌐 Server endpoints:"
echo "   - Health: http://jitsi.dialecticlabs.com:3001/health"
echo "   - Default: ws://jitsi.dialecticlabs.com:3001/"
echo "   - Signaling: ws://jitsi.dialecticlabs.com:3001/signaling"
echo "   - MediaSoup: ws://jitsi.dialecticlabs.com:3001/mediasoup"