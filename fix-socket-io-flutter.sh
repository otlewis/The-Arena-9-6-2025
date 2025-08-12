#!/bin/bash

# Alternative fix for Flutter Socket.IO v3.x WebSocket upgrade issue

echo "🔧 Applying alternative Socket.IO fix..."

# Create a patch for the server to explicitly reject WebSocket connections
cat > socket-io-patch.js << 'EOF'
// Add this to your mediasoup-production-server.js after Socket.IO initialization

// Override Socket.IO transport handling for Flutter compatibility
io.engine.on('connection', (socket) => {
  // Force polling-only for all connections
  socket.transport.name = 'polling';
  socket.transport.writable = true;
  
  // Disable upgrade mechanism
  socket.on('upgrade', (transport) => {
    console.log('🚫 Blocking WebSocket upgrade attempt');
    transport.close();
  });
});

// Alternative: Completely disable WebSocket transport
io.engine.generateId = (req) => {
  // Force polling transport in the session
  if (req._query && req._query.transport === 'websocket') {
    req._query.transport = 'polling';
  }
  return require('base64id').generateId();
};
EOF

echo "✅ Patch file created: socket-io-patch.js"
echo ""
echo "📋 To apply this fix on your server:"
echo "1. Add the patch code to your mediasoup-production-server.js"
echo "2. Place it right after the Socket.IO initialization (after line 23)"
echo "3. Restart the server"
echo ""
echo "🎯 This will:"
echo "- Force all connections to use polling"
echo "- Block any WebSocket upgrade attempts"
echo "- Override Flutter client's transport negotiation"