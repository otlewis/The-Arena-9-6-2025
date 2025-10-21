#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           🆓 Self-Hosted LiveKit Setup (FREE)                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "This will set up LiveKit locally - completely FREE!"
echo ""

# Option 1: Docker
echo "Option 1: Using Docker (Recommended)"
echo "──────────────────────────────────────"
echo "docker run -d \\"
echo "  --name livekit-server \\"
echo "  -p 7880:7880 \\"
echo "  -p 7881:7881 \\"
echo "  -p 7882:7882/udp \\"
echo "  -e LIVEKIT_KEYS=\"devkey: secret\" \\"
echo "  livekit/livekit-server \\"
echo "  --dev"
echo ""

# Option 2: Direct installation
echo "Option 2: Direct Installation"
echo "──────────────────────────────────────"
echo "# macOS:"
echo "brew install livekit"
echo ""
echo "# Linux:"
echo "curl -sSL https://get.livekit.io | bash"
echo ""
echo "# Then run:"
echo "livekit-server --dev --config livekit.yaml"
echo ""

echo "📝 Create livekit.yaml:"
echo "──────────────────────────────────────"
cat << 'EOF'
port: 7880
rtc:
  tcp_port: 7881
  udp_port: 7882
  use_external_ip: false
keys:
  devkey: secret
webhook:
  api_key: devkey
  api_secret: secret
room:
  enable_room_preset: true
  auto_create: true
egress:
  enable_chrome_sandbox: false
EOF

echo ""
echo "🔧 Then update your Flutter app:"
echo "──────────────────────────────────────"
echo "In lib/services/recording_service.dart:"
echo ""
echo "static const String _liveKitApiKey = 'devkey';"
echo "static const String _liveKitApiSecret = 'secret';"
echo "static const String _liveKitUrl = 'ws://localhost:7880';"
echo ""
echo "✅ Benefits of Self-Hosting:"
echo "• Completely FREE - no limits"
echo "• Full control over your data"
echo "• No external dependencies"
echo "• Can run on your existing server"
echo ""
echo "📋 Requirements:"
echo "• Docker OR direct installation"
echo "• 2GB RAM minimum"
echo "• Ports 7880-7882 available"