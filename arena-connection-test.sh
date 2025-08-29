#!/bin/bash

echo "🔧 Arena Connection Diagnostics"
echo "==============================="
echo ""

echo "1️⃣ Testing LiveKit Server Connectivity..."
echo "   WebSocket connection test:"
echo "   curl -I http://172.236.109.9:7880"
curl -I http://172.236.109.9:7880
echo ""

echo "2️⃣ Testing TURN Server Connectivity..."
echo "   OpenRelay TURN server test:"
echo "   curl -I http://openrelay.metered.ca"
curl -I http://openrelay.metered.ca
echo ""

echo "3️⃣ DNS Resolution Test..."
echo "   nslookup openrelay.metered.ca"
nslookup openrelay.metered.ca
echo ""

echo "4️⃣ Network Route Test..."
echo "   traceroute to LiveKit server:"
echo "   traceroute 172.236.109.9"
traceroute 172.236.109.9
echo ""

echo "5️⃣ Port Connectivity Test..."
echo "   Testing LiveKit WebSocket port:"
echo "   nc -zv 172.236.109.9 7880"
nc -zv 172.236.109.9 7880
echo ""
echo "   Testing TURN server ports:"
echo "   nc -zv openrelay.metered.ca 80"
nc -zv openrelay.metered.ca 80
echo "   nc -zv openrelay.metered.ca 443"
nc -zv openrelay.metered.ca 443
echo ""

echo "📋 SUMMARY:"
echo "============"
echo "If any of the above tests fail, that indicates the network issue."
echo ""
echo "Common issues:"
echo "- LiveKit server not running (7880 connection fails)"
echo "- Firewall blocking WebRTC traffic"
echo "- TURN server credentials incorrect"
echo "- Network provider blocking UDP traffic"
echo "- Corporate firewall restrictions"
echo ""
echo "Next steps based on results:"
echo "- If 7880 fails: Check LiveKit server status"
echo "- If TURN fails: Check TURN server configuration"
echo "- If traceroute shows timeouts: Network routing issue"
echo "- If DNS fails: Network DNS configuration issue"