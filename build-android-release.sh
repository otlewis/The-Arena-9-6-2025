#!/bin/bash

# Arena Android APK Build Script
# This script builds a release APK for Android

echo "========================================="
echo "Arena Android APK Build Script"
echo "========================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}Error: pubspec.yaml not found!${NC}"
    echo "Please run this script from the arena2 project root directory"
    exit 1
fi

echo -e "${GREEN}Step 1: Cleaning previous builds...${NC}"
flutter clean

echo -e "${GREEN}Step 2: Getting dependencies...${NC}"
flutter pub get

echo -e "${GREEN}Step 3: Building release APK...${NC}"
flutter build apk --release --no-sound-null-safety

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo -e "${GREEN}Build Successful!${NC}"
    echo "========================================="
    echo ""
    echo "APK Location:"
    echo -e "${YELLOW}build/app/outputs/flutter-apk/app-release.apk${NC}"
    echo ""
    echo "File size:"
    ls -lh build/app/outputs/flutter-apk/app-release.apk | awk '{print $5}'
    echo ""
    echo "To install on a device:"
    echo "1. Enable 'Unknown Sources' in Android Settings"
    echo "2. Transfer the APK to your device"
    echo "3. Open the APK file to install"
    echo ""
    echo "Or install via ADB:"
    echo "adb install build/app/outputs/flutter-apk/app-release.apk"
    
    # Copy to desktop for easy access
    if [ -d "$HOME/Desktop" ]; then
        cp build/app/outputs/flutter-apk/app-release.apk "$HOME/Desktop/Arena-$(date +%Y%m%d-%H%M%S).apk"
        echo ""
        echo -e "${GREEN}APK also copied to your Desktop!${NC}"
    fi
else
    echo ""
    echo -e "${RED}Build failed!${NC}"
    echo "Check the error messages above for details."
    exit 1
fi