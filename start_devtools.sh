#!/bin/bash

echo "🔧 Starting Flutter DevTools for Arena Performance Monitoring"
echo "============================================================="

# Check if app is already running
if pgrep -f "flutter run" > /dev/null; then
    echo "✅ Flutter app is already running"
else
    echo "🚀 Starting Arena app in debug mode..."
    flutter run -d chrome --web-renderer html &
    echo "⏳ Waiting for app to start..."
    sleep 5
fi

echo "🔧 Opening DevTools..."
dart devtools

echo ""
echo "📖 Quick DevTools Guide:"
echo "1. Copy the VM Service URL from your terminal"
echo "2. Paste it into DevTools connection field"  
echo "3. Click 'Connect'"
echo "4. Go to 'Performance' tab"
echo "5. Click 'Record' and test your app"
echo ""
echo "🎯 Focus on these Arena features:"
echo "- Join/leave rooms (check audience visibility)"
echo "- Scroll audience lists (check for frame drops)" 
echo "- Real-time participant updates (check rebuild frequency)"
echo "- Role changes (audience ↔ speaker)"
echo ""