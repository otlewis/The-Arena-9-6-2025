#!/bin/bash

# Arena Performance Testing Script
echo "🎯 Arena Performance Testing Setup"
echo "================================="

# Function to test specific scenarios
test_scenario() {
    local scenario=$1
    echo ""
    echo "🧪 Testing: $scenario"
    echo "Instructions:"
    
    case $scenario in
        "audience-visibility")
            echo "1. Join a Debates & Discussions room"
            echo "2. Watch the audience grid as users join/leave"
            echo "3. Check if users appear immediately"
            echo "4. Monitor FPS during participant updates"
            echo "5. Look for 'Performance Report' logs every 5 seconds"
            ;;
        "real-time-updates")
            echo "1. Have multiple devices join the same room"
            echo "2. Raise/lower hands rapidly"
            echo "3. Change roles (audience ↔ speaker)"
            echo "4. Monitor frame times during updates"
            echo "5. Check for slow frame warnings"
            ;;
        "grid-scrolling")
            echo "1. Join a room with 20+ audience members"
            echo "2. Scroll through the audience grid"
            echo "3. Look for frame drops or stutters"
            echo "4. Monitor avatar image loading"
            echo "5. Check memory usage in DevTools"
            ;;
        "memory-usage")
            echo "1. Join/leave multiple rooms in sequence"
            echo "2. Switch between room types rapidly"
            echo "3. Check for memory leaks in DevTools"
            echo "4. Monitor widget rebuild counts"
            echo "5. Look for disposal warnings"
            ;;
    esac
}

echo ""
echo "📋 Available Performance Tests:"
echo ""
echo "1. Audience Visibility Test"
echo "2. Real-time Updates Test" 
echo "3. Grid Scrolling Performance Test"
echo "4. Memory Usage Test"
echo "5. Run All Tests"
echo "6. Launch DevTools Only"
echo ""

read -p "Select test (1-6): " choice

case $choice in
    1)
        test_scenario "audience-visibility"
        ;;
    2)
        test_scenario "real-time-updates"
        ;;
    3)
        test_scenario "grid-scrolling"
        ;;
    4)
        test_scenario "memory-usage"
        ;;
    5)
        echo "🚀 Running comprehensive performance test..."
        test_scenario "audience-visibility"
        test_scenario "real-time-updates"
        test_scenario "grid-scrolling"
        test_scenario "memory-usage"
        ;;
    6)
        echo "🔧 Launching DevTools only..."
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "🚀 Starting performance monitoring..."
echo ""

# Start Flutter with performance flags
echo "📱 Launching Arena with performance monitoring..."
flutter run -d chrome \
  --web-renderer html \
  --dart-define=FLUTTER_WEB_USE_SKIA=false \
  --dart-define=FLUTTER_WEB_DEBUG_SHOW_SEMANTICS=false \
  --verbose \
  --enable-software-rendering=false &

# Give the app time to start
sleep 3

echo ""
echo "🔧 Launching Flutter DevTools..."
dart devtools &

echo ""
echo "✅ Performance monitoring active!"
echo ""
echo "📊 What to monitor in DevTools:"
echo "- Performance tab: Frame rendering times, rebuild counts"
echo "- Memory tab: Heap usage, garbage collection"
echo "- CPU Profiler: Widget build times, hot spots"
echo "- Network tab: Image loading, API calls"
echo ""
echo "📱 What to watch in the app:"
echo "- Real-time FPS display (top-right corner)"
echo "- Console logs for performance warnings"
echo "- Smooth scrolling in audience grids"
echo "- Instant participant updates"
echo ""
echo "🎯 Key metrics to track:"
echo "- Target: 60 FPS (16.67ms per frame)"
echo "- Good: <5% slow frames"
echo "- Warning: >10% slow frames"
echo "- Memory: Stable heap size"
echo ""

wait