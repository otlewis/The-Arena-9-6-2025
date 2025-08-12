#!/bin/bash

echo "🔍 Arena WebRTC Server Connectivity Diagnosis"
echo "=============================================="

SERVER_IP="172.236.109.9"
PORT="3000"

echo ""
echo "1. 🌐 Testing basic server connectivity..."
if ping -c 3 $SERVER_IP > /dev/null 2>&1; then
    echo "✅ Server $SERVER_IP is reachable"
else
    echo "❌ Server $SERVER_IP is NOT reachable"
    exit 1
fi

echo ""
echo "2. 🔌 Testing port $PORT connectivity..."
if command -v nc >/dev/null 2>&1; then
    if nc -zv $SERVER_IP $PORT 2>&1 | grep -q "succeeded\|Connected"; then
        echo "✅ Port $PORT is OPEN"
    else
        echo "❌ Port $PORT is CLOSED or filtered"
    fi
else
    echo "⚠️ netcat not available, using curl..."
    if curl -s --connect-timeout 5 http://$SERVER_IP:$PORT/ > /dev/null; then
        echo "✅ Port $PORT is OPEN"
    else
        echo "❌ Port $PORT is CLOSED or filtered"
    fi
fi

echo ""
echo "3. 🔄 Testing HTTP response..."
HTTP_RESPONSE=$(curl -s --connect-timeout 10 http://$SERVER_IP:$PORT/ 2>/dev/null)
if [ $? -eq 0 ] && [ ! -z "$HTTP_RESPONSE" ]; then
    echo "✅ HTTP server is responding"
    echo "Response: $HTTP_RESPONSE"
else
    echo "❌ HTTP server is NOT responding"
fi

echo ""
echo "4. 🕵️ Testing other common ports..."
for test_port in 22 80 443 8080; do
    if nc -zv $SERVER_IP $test_port 2>&1 | grep -q "succeeded\|Connected"; then
        echo "✅ Port $test_port is OPEN"
    else
        echo "❌ Port $test_port is CLOSED"
    fi
done

echo ""
echo "5. 🔧 Suggested fixes:"
echo ""
echo "If port 3000 is closed, you need to:"
echo ""
echo "A) Check server firewall (ufw):"
echo "   ssh root@$SERVER_IP"
echo "   sudo ufw status"
echo "   sudo ufw allow 3000"
echo "   sudo ufw reload"
echo ""
echo "B) Check if server is running:"
echo "   ssh root@$SERVER_IP"
echo "   ps aux | grep node"
echo "   netstat -tlnp | grep 3000"
echo ""
echo "C) Start the server:"
echo "   ssh root@$SERVER_IP"
echo "   cd ~/"
echo "   node arena-webrtc-server.cjs &"
echo ""
echo "D) Check cloud provider firewall:"
echo "   - Linode Cloud Firewall"
echo "   - Security Groups"
echo "   - Network ACLs"
echo ""
echo "E) Alternative: Use a different port"
echo "   - Try port 8080 or 80"
echo "   - Update both server and client"

echo ""
echo "6. 🚀 Quick local test:"
echo "For immediate testing, use localhost:"
echo "   # In terminal 1:"
echo "   node arena-webrtc-server.cjs"
echo ""
echo "   # In terminal 2 (update client to localhost):"
echo "   # Change line 190 in lib/screens/arena_webrtc_screen.dart:"
echo "   # _socket = io.io('http://localhost:3000', ..."
echo "   flutter run test_arena_webrtc.dart -d chrome"