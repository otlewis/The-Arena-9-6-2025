#!/bin/bash

# Arena Performance Monitoring Script
echo "🚀 Starting Arena with Flutter DevTools Performance Monitoring..."

# Kill any existing flutter processes
pkill -f flutter

# Start the app in debug mode with detailed logging
echo "📱 Launching Arena app in debug mode..."
flutter run -d chrome --web-renderer html --dart-define=FLUTTER_WEB_USE_SKIA=false --verbose &

# Wait for the app to start
sleep 5

# Launch DevTools
echo "🔧 Opening Flutter DevTools..."
flutter pub global run devtools &

echo ""
echo "✅ Setup Complete!"
echo ""
echo "📊 To monitor performance:"
echo "1. Wait for both windows to open"
echo "2. Copy the VM Service URL from terminal"
echo "3. Paste it into DevTools connection field"
echo "4. Navigate to 'Performance' tab"
echo "5. Start recording and test your app"
echo ""
echo "🎯 Focus areas to test:"
echo "- Join/leave rooms (audience visibility)"
echo "- Scroll through audience list"
echo "- Real-time participant updates"
echo "- Role changes (speaker/audience)"
echo ""