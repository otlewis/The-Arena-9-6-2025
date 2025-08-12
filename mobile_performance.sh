#!/bin/bash

# Arena Mobile Performance Testing Script
echo "📱 Arena Mobile Performance Monitoring Setup"
echo "============================================="

# Function to detect available devices
detect_devices() {
    echo "🔍 Scanning for connected devices..."
    
    # Check for iOS devices
    ios_devices=$(xcrun xcdevice list | grep -E "iPhone|iPad" | grep -v "Simulator" | wc -l)
    
    # Check for Android devices  
    android_devices=$(adb devices | grep -v "List of devices attached" | grep "device" | wc -l)
    
    # Check for iOS simulators
    ios_simulators=$(xcrun simctl list devices | grep "Booted" | grep -E "iPhone|iPad" | wc -l)
    
    # Check for Android emulators
    android_emulators=$(adb devices | grep -v "List of devices attached" | grep "emulator" | wc -l)
    
    echo ""
    echo "📱 Available Devices:"
    echo "• Physical iOS devices: $ios_devices"
    echo "• Physical Android devices: $android_devices" 
    echo "• iOS simulators: $ios_simulators"
    echo "• Android emulators: $android_emulators"
    echo ""
    
    total_devices=$((ios_devices + android_devices + ios_simulators + android_emulators))
    
    if [ $total_devices -eq 0 ]; then
        echo "❌ No devices found!"
        echo ""
        echo "📋 Setup Instructions:"
        echo "For iOS:"
        echo "1. Connect iPhone/iPad via USB"
        echo "2. Trust computer in device settings"
        echo "3. Or start iOS Simulator: 'open -a Simulator'"
        echo ""
        echo "For Android:"
        echo "1. Enable Developer Options & USB Debugging"
        echo "2. Connect device via USB and accept debugging"
        echo "3. Or start Android Emulator from Android Studio"
        echo ""
        echo "Run this script again once devices are connected."
        exit 1
    fi
    
    return $total_devices
}

# Function to select target device
select_device() {
    echo "📱 Available Flutter Devices:"
    flutter devices --no-color
    echo ""
    
    read -p "🎯 Enter device ID or name to test: " device_id
    
    if [ -z "$device_id" ]; then
        echo "❌ No device selected"
        exit 1
    fi
    
    # Validate device exists
    if ! flutter devices | grep -q "$device_id"; then
        echo "❌ Device '$device_id' not found"
        echo "Please check 'flutter devices' and try again"
        exit 1
    fi
    
    echo "✅ Selected device: $device_id"
    return 0
}

# Function to run performance test
run_mobile_performance_test() {
    local device_id=$1
    local test_type=$2
    
    echo "🚀 Starting mobile performance test..."
    echo "Device: $device_id"
    echo "Test Type: $test_type"
    echo ""
    
    # Performance flags for mobile
    local flutter_flags="--verbose --dart-define=FLUTTER_PERFORMANCE_MONITORING=true"
    
    # iOS specific flags
    if echo "$device_id" | grep -iq "iphone\|ipad\|ios"; then
        flutter_flags="$flutter_flags --dart-define=PLATFORM_OPTIMIZATIONS=ios"
        echo "📱 iOS Performance Optimizations: ENABLED"
    fi
    
    # Android specific flags  
    if echo "$device_id" | grep -iq "android"; then
        flutter_flags="$flutter_flags --dart-define=PLATFORM_OPTIMIZATIONS=android"
        echo "🤖 Android Performance Optimizations: ENABLED"
    fi
    
    echo ""
    echo "🎯 Mobile Performance Test Instructions:"
    
    case $test_type in
        "audience-mobile")
            echo "📋 Audience Visibility Test (Mobile):"
            echo "1. Join a Debates & Discussions room"
            echo "2. Rotate device (portrait ↔ landscape)"
            echo "3. Scroll audience grid with finger"
            echo "4. Watch for lag, stutters, missing users"
            echo "5. Join/leave room multiple times"
            echo "6. Monitor battery usage and heat"
            ;;
        "realtime-mobile")
            echo "📋 Real-time Updates Test (Mobile):"
            echo "1. Join room with multiple participants"
            echo "2. Raise/lower hand rapidly (tap test)"
            echo "3. Switch between apps and return"
            echo "4. Put device to sleep and wake"
            echo "5. Test during low battery/power save mode"
            echo "6. Monitor network reconnection"
            ;;
        "memory-mobile")
            echo "📋 Mobile Memory Test:"
            echo "1. Join/leave 10+ rooms in sequence"
            echo "2. Background/foreground app repeatedly"
            echo "3. Rotate device during heavy usage"
            echo "4. Open other apps while Arena running"
            echo "5. Monitor memory warnings"
            echo "6. Test during low memory conditions"
            ;;
        "battery-mobile")
            echo "📋 Battery/Thermal Test:"
            echo "1. Run Arena for 30+ minutes continuously"
            echo "2. Join busy rooms with many participants"
            echo "3. Keep screen on at full brightness"
            echo "4. Monitor device temperature"
            echo "5. Check battery drain rate"
            echo "6. Test thermal throttling impact"
            ;;
    esac
    
    echo ""
    echo "📊 Watch for these mobile-specific issues:"
    echo "• Frame drops during touch scrolling"
    echo "• Memory warnings or crashes"
    echo "• Network reconnection delays"
    echo "• Battery drain or device heating"
    echo "• App backgrounding/foregrounding issues"
    echo "• Device rotation performance"
    echo ""
    
    # Start the app with mobile performance monitoring
    echo "🚀 Launching Arena with mobile performance monitoring..."
    flutter run -d "$device_id" $flutter_flags &
    
    # Give app time to start
    sleep 10
    
    # Launch DevTools for mobile
    echo "🔧 Starting mobile DevTools session..."
    dart devtools --enable-logging &
    
    echo ""
    echo "✅ Mobile performance monitoring active!"
    echo ""
    echo "📱 Mobile DevTools Features:"
    echo "• Memory tab: Track heap usage and GC"
    echo "• Performance tab: Frame times and rebuilds" 
    echo "• Network tab: API calls and image loading"
    echo "• Logging: Real-time performance alerts"
    echo ""
    echo "🎯 Mobile-specific metrics to monitor:"
    echo "• Target: 60 FPS (iPhone), 60 FPS (Android flagship)"
    echo "• Acceptable: 30 FPS (older Android devices)"
    echo "• Memory: <100MB heap usage"
    echo "• Network: <3s reconnection time"
    echo "• Battery: <10%/hour drain rate"
    echo ""
    
    wait
}

# Main script
echo "🔍 Step 1: Detecting mobile devices..."
detect_devices

echo "📱 Step 2: Select target device..."
select_device
selected_device_id="$device_id"

echo ""
echo "🧪 Step 3: Select performance test type..."
echo ""
echo "📋 Available Mobile Performance Tests:"
echo "1. Audience Visibility (Mobile-optimized)"
echo "2. Real-time Updates (Touch/Network)"
echo "3. Memory Management (Background/Foreground)"
echo "4. Battery & Thermal Performance"
echo "5. Comprehensive Mobile Test (All)"
echo "6. Quick Mobile Performance Check"
echo ""

read -p "Select test (1-6): " test_choice

case $test_choice in
    1)
        run_mobile_performance_test "$selected_device_id" "audience-mobile"
        ;;
    2)
        run_mobile_performance_test "$selected_device_id" "realtime-mobile"
        ;;
    3)
        run_mobile_performance_test "$selected_device_id" "memory-mobile"
        ;;
    4)
        run_mobile_performance_test "$selected_device_id" "battery-mobile"
        ;;
    5)
        echo "🚀 Running comprehensive mobile performance test..."
        run_mobile_performance_test "$selected_device_id" "audience-mobile"
        echo "⏳ Next test in 30 seconds... (Press Ctrl+C to skip)"
        sleep 30
        run_mobile_performance_test "$selected_device_id" "realtime-mobile"
        ;;
    6)
        echo "⚡ Quick mobile performance check..."
        run_mobile_performance_test "$selected_device_id" "audience-mobile"
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "📱 Mobile Performance Testing Complete!"
echo ""
echo "📊 Next Steps:"
echo "1. Analyze DevTools data for bottlenecks"
echo "2. Check console logs for performance warnings"
echo "3. Monitor device temperature and battery"
echo "4. Test on different device types/OS versions"
echo "5. Compare performance vs other debate apps"
echo ""