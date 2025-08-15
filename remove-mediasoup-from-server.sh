#!/bin/bash

echo "🗑️ Removing MediaSoup completely from Linode server..."

# Server details from deploy-fixed-mediasoup.sh
SERVER_IP="172.236.109.9"
SERVER_USER="root"
SERVER_DIR="/opt/mediasoup-server"

echo "🛑 Stopping all MediaSoup processes..."
ssh ${SERVER_USER}@${SERVER_IP} "pkill -f mediasoup || true"
ssh ${SERVER_USER}@${SERVER_IP} "pkill -f 'node.*mediasoup' || true"
ssh ${SERVER_USER}@${SERVER_IP} "pkill -f 'mediasoup.*server' || true"

echo "🗂️ Removing MediaSoup server directory..."
ssh ${SERVER_USER}@${SERVER_IP} "rm -rf ${SERVER_DIR}"

echo "🔍 Checking for other MediaSoup installations..."
ssh ${SERVER_USER}@${SERVER_IP} "find /opt -name '*mediasoup*' -type d 2>/dev/null | head -10" || echo "No other MediaSoup directories found"

echo "🔄 Removing any MediaSoup services..."
ssh ${SERVER_USER}@${SERVER_IP} "systemctl stop mediasoup* 2>/dev/null || true"
ssh ${SERVER_USER}@${SERVER_IP} "systemctl disable mediasoup* 2>/dev/null || true"
ssh ${SERVER_USER}@${SERVER_IP} "rm -f /etc/systemd/system/mediasoup* /etc/systemd/system/*mediasoup*"

echo "🔌 Checking for MediaSoup ports (3005, 3002, 3000)..."
ssh ${SERVER_USER}@${SERVER_IP} "netstat -tlnp | grep ':3005\|:3002\|:3000' || echo 'No MediaSoup ports active'"

echo "🧹 Cleaning up any remaining MediaSoup processes..."
ssh ${SERVER_USER}@${SERVER_IP} "ps aux | grep -i mediasoup | grep -v grep || echo 'No MediaSoup processes found'"

echo "🔄 Reloading systemd..."
ssh ${SERVER_USER}@${SERVER_IP} "systemctl daemon-reload"

echo "📊 Final system status..."
ssh ${SERVER_USER}@${SERVER_IP} "ps aux | grep -E '(mediasoup|node.*3005|node.*3002)' | grep -v grep || echo 'All MediaSoup processes removed'"

echo "✅ MediaSoup completely removed from server!"
echo "🎯 Only LiveKit should remain active for Arena audio functionality"
echo "🔗 Verify LiveKit is still running if needed"