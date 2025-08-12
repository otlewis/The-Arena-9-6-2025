#!/bin/bash

echo "🚀 Deploying Arena iOS to Firebase App Distribution"
echo "================================================="

# Use the existing built app if available, or build a new one
if [ -f "build/ios/iphoneos/Runner.app" ]; then
    echo "✅ Found existing iOS build"
else
    echo "📱 Building iOS app..."
    flutter build ios --release --no-codesign
fi

# Create IPA from the app bundle
echo "📦 Creating IPA file..."
cd build/ios/iphoneos
mkdir -p Payload
cp -r Runner.app Payload/
zip -r ../../../Arena-1.0.14+15.ipa Payload
rm -rf Payload
cd ../../..

# Deploy to Firebase
echo "🔥 Uploading to Firebase App Distribution..."
firebase appdistribution:distribute Arena-1.0.14+15.ipa \
    --app "1:18237618385:ios:159de79359b3a43e52edf0" \
    --release-notes "Arena v1.0.14+15
    
🎉 What's New:
- Premium pricing: 14 days free, then \$5 first month, then \$10/month
- Audio-only focus (removed video tiers)
- Added Rankings to home screen
- Fixed home screen card sizing
- Improved performance

🐛 Bug Fixes:
- Removed all test screens
- Fixed Flutter analysis errors
- Optimized WebRTC connections" \
    --groups "arena-beta-testers,The Arena-Test"

echo "✅ Done! Check Firebase Console for the new release"