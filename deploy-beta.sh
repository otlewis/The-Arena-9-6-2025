#!/bin/bash

echo "🚀 Deploying Arena App to Firebase App Distribution for Beta Testing"
echo "=================================================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null
then
    echo -e "${RED}❌ Firebase CLI is not installed${NC}"
    echo "Please install it with: npm install -g firebase-tools"
    exit 1
fi

# Build Android APK if not already built
if [ ! -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    echo -e "${YELLOW}📱 Building Android release APK...${NC}"
    flutter build apk --release
else
    echo -e "${GREEN}✅ Android APK already built${NC}"
fi

# Build iOS IPA (optional, can be skipped if Xcode build takes too long)
echo -e "${YELLOW}📱 For iOS deployment:${NC}"
echo "1. Open ios/Runner.xcworkspace in Xcode"
echo "2. Select 'Any iOS Device' as the build target"
echo "3. Product > Archive"
echo "4. Distribute App > Ad Hoc or Development"
echo ""

# Deploy Android APK to Firebase App Distribution
echo -e "${YELLOW}🔥 Deploying Android APK to Firebase App Distribution...${NC}"

# Check if logged in to Firebase
firebase login:list &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Please log in to Firebase:${NC}"
    firebase login
fi

# Deploy to Firebase App Distribution
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
    --app "1:18237618385:android:010406bf45cc714852edf0" \
    --release-notes "Arena v1.0.14+15 Beta Release

🎉 What's New:
- Updated premium pricing: 14 days free, then $5 first month, then $10/month
- Removed video tiers (audio-only focus)
- Cleaned up codebase - removed test screens
- Added Rankings feature card to home screen
- All feature cards now same size with proper grid layout
- Fixed pixel overflow issues
- Optimized WebRTC connections for better performance

🐛 Bug Fixes:
- Fixed MediaSoup test screen removal
- Resolved Flutter analysis errors
- Improved app performance and stability

📱 Features:
- Real-time audio debates
- Instant messaging system
- Challenge notifications
- Timer synchronization
- Premium subscription options" \
    --groups "beta-testers" \
    --debug

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Android APK deployed successfully!${NC}"
else
    echo -e "${RED}❌ Failed to deploy Android APK${NC}"
fi

echo ""
echo -e "${GREEN}📋 Next Steps:${NC}"
echo "1. Beta testers will receive an email invitation"
echo "2. They can download the app from the Firebase App Distribution link"
echo "3. Monitor crash reports and user feedback in Firebase Console"
echo "4. For iOS deployment, follow the Xcode steps above"
echo ""
echo -e "${YELLOW}🔗 Firebase Console:${NC} https://console.firebase.google.com/project/arena-flutter/appdistribution"