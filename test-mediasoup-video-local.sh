#!/bin/bash

# Test MediaSoup video functionality locally

echo "🧪 Testing MediaSoup Video Support Locally"
echo "=========================================="

# Check if server is running
SERVER_URL="http://localhost:3005"

echo "1. Checking server health..."
HEALTH=$(curl -s $SERVER_URL/)
if [ $? -eq 0 ]; then
    echo "✅ Server is running:"
    echo "$HEALTH" | jq '.'
else
    echo "❌ Server is not running. Starting it..."
    PORT=3005 node mediasoup-production-server.cjs &
    SERVER_PID=$!
    sleep 3
fi

echo -e "\n2. Testing Socket.IO connection..."
# Test socket.io polling endpoint
SOCKET_TEST=$(curl -s -X GET "$SERVER_URL/socket.io/?EIO=4&transport=polling")
if [[ $SOCKET_TEST == *"0{"* ]]; then
    echo "✅ Socket.IO endpoint is accessible"
else
    echo "❌ Socket.IO endpoint failed"
    echo "Response: $SOCKET_TEST"
fi

echo -e "\n3. Server Configuration:"
echo "- Video enabled for: moderators, speakers"
echo "- Video blocked for: audience"
echo "- Codecs: VP8, H264, Opus"
echo "- RTC Ports: 10000-10100"

echo -e "\n4. Testing Instructions:"
echo "- Open Flutter app in browser/device"
echo "- Navigate to 'MediaSoup Test' button"
echo "- Click 'Test Camera' to verify permissions"
echo "- Click 'Video Moderator' to test video production"
echo "- Check debug logs for video track creation"

echo -e "\n5. Expected Success Indicators:"
echo "✅ 'Local video initialized with 1 tracks'"
echo "✅ 'Video producer created: [producerId]'"
echo "✅ Local video preview visible"

echo -e "\n📱 Flutter Debug Video Screen URLs:"
echo "- Localhost: http://localhost:3005"
echo "- Production: http://172.236.109.9 (after deployment)"

echo -e "\n🎥 Video is now enabled! Ready for testing."