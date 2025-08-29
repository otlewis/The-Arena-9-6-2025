#!/bin/bash

echo "🚀 Arena Connection Optimization Script"
echo "========================================"
echo ""
echo "This script will help optimize Arena audio connections to reduce the 30-45 second delay"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Step 1: Analyzing Current Configuration${NC}"
echo "----------------------------------------"
echo ""

echo "Current LiveKit Service Configuration:"
echo "• ICE Servers: 1 STUN + 2 TURN (optimized from 3 STUN)"
echo "• ICE Candidate Pool: 10 (increased from 2)"
echo "• Connection Timeouts: 12s, 14s, 16s (reduced from 25s, 30s, 35s)"
echo "• Mute Sync Timer: DISABLED (was causing random mute/unmute)"
echo ""

echo -e "${YELLOW}Step 2: Further Optimizations to Apply${NC}"
echo "----------------------------------------"
echo ""

echo "1. Reduce ICE Gathering Timeout:"
echo "   - Add iceCandidatePoolSize: 0 to gather candidates on-demand"
echo "   - Or set continualGatheringPolicy: 'gather_once'"
echo ""

echo "2. Use TCP TURN as Primary:"
echo "   - TCP is more reliable through firewalls"
echo "   - Move TCP TURN server to first position"
echo ""

echo "3. Add Connection Quality Monitoring:"
echo "   - Track connection establishment time"
echo "   - Log each phase of connection"
echo ""

echo -e "${YELLOW}Step 3: Server-Side Optimizations${NC}"
echo "----------------------------------------"
echo ""

echo "Run these commands on your server:"
echo ""
echo -e "${GREEN}1. Check server resources during connection:${NC}"
echo "   htop  # Watch CPU/memory during Arena join"
echo ""
echo -e "${GREEN}2. Check LiveKit configuration:${NC}"
echo "   cd /opt/livekit-arena"
echo "   cat livekit-production.yaml | grep -E 'ice|turn|stun|timeout'"
echo ""
echo -e "${GREEN}3. Monitor ICE candidate gathering:${NC}"
echo "   docker-compose logs -f | grep -E 'ICE|candidate|gathering'"
echo ""
echo -e "${GREEN}4. Check for rate limiting:${NC}"
echo "   docker-compose logs --tail=100 | grep -i 'rate.*limit'"
echo ""

echo -e "${YELLOW}Step 4: Client-Side Quick Fixes${NC}"
echo "----------------------------------------"
echo ""

echo "Applying these optimizations to lib/services/livekit_service.dart..."
echo ""

cat << 'EOF' > optimize-livekit-connection.dart
// Optimized LiveKit connection configuration

// Option 1: Prioritize TCP TURN (more reliable through firewalls)
iceServers: [
  // TCP TURN first for reliability
  RTCIceServer(
    urls: ['turn:openrelay.metered.ca:443?transport=tcp'],
    username: 'openrelayproject',
    credential: 'openrelayproject',
  ),
  // Then UDP TURN for performance
  RTCIceServer(
    urls: ['turn:openrelay.metered.ca:80'],
    username: 'openrelayproject',
    credential: 'openrelayproject',
  ),
  // STUN last as fallback
  RTCIceServer(urls: ['stun:stun.l.google.com:19302']),
],

// Option 2: Use on-demand ICE gathering
iceCandidatePoolSize: 0,  // Gather candidates only when needed
continualGatheringPolicy: RTCContinualGatheringPolicy.gatherOnce,

// Option 3: Add connection monitoring
final stopwatch = Stopwatch()..start();
print('[LiveKit] Starting connection to room: $roomId');

// After connection:
print('[LiveKit] Connected in ${stopwatch.elapsedMilliseconds}ms');

// Option 4: Parallel initialization
await Future.wait([
  _room!.connect(url, token, roomOptions: roomOptions),
  _initializeLocalParticipant(),
], eagerError: false);
EOF

echo -e "${GREEN}✅ Optimization guide created!${NC}"
echo ""

echo -e "${YELLOW}Step 5: Testing Connection Speed${NC}"
echo "----------------------------------------"
echo ""

echo "After applying optimizations, test with:"
echo "1. Join Arena room and time the connection"
echo "2. Check console for '[LiveKit] Connected in Xms' message"
echo "3. Target: < 5 seconds for good experience"
echo ""

echo -e "${YELLOW}Step 6: Emergency Fallback${NC}"
echo "----------------------------------------"
echo ""

echo "If connection still takes > 10 seconds:"
echo "1. Consider using a closer TURN server (deploy your own)"
echo "2. Use WebSocket signaling before WebRTC connection"
echo "3. Show 'Connecting audio...' UI with progress indicator"
echo "4. Allow users to join room without audio initially"
echo ""

echo -e "${GREEN}Expected Results:${NC}"
echo "• Connection time: 2-5 seconds (from 30-45 seconds)"
echo "• No random mute/unmute issues"
echo "• Reliable connection through firewalls"
echo ""

echo "Run 'bash optimize-arena-connection.sh' to see this guide"