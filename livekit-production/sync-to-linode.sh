#!/bin/bash

echo "📤 Syncing LiveKit configuration to Linode server..."

# Copy files to server
scp -r . root@172.236.109.9:/opt/livekit-arena/

echo "🚀 Running deployment on server..."
ssh root@172.236.109.9 "cd /opt/livekit-arena && ./deploy-to-server.sh"

echo "✅ LiveKit deployed to production server!"
echo "🔗 Production LiveKit URL: ws://172.236.109.9:7880"

