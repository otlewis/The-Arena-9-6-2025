#!/bin/bash

echo "🍎 Building Arena iOS App for Beta Testing"
echo "=========================================="

# Build iOS app
echo "📱 Building iOS release..."
flutter build ios --release

# Create IPA using xcodebuild
echo "📦 Creating IPA file..."
cd ios
xcodebuild -workspace Runner.xcworkspace \
           -scheme Runner \
           -sdk iphoneos \
           -configuration Release \
           -archivePath ../build/ios/Runner.xcarchive \
           archive

xcodebuild -exportArchive \
           -archivePath ../build/ios/Runner.xcarchive \
           -exportOptionsPlist ExportOptions.plist \
           -exportPath ../build/ios/ipa

cd ..

# Deploy to Firebase
echo "🚀 Deploying to Firebase App Distribution..."
firebase appdistribution:distribute build/ios/ipa/Runner.ipa \
    --app "1:18237618385:ios:159de79359b3a43e52edf0" \
    --release-notes "Arena v1.0.14+15 iOS Beta
- Updated pricing: 14 days free, \$5 first month, then \$10/month
- Audio-only focus (removed video tiers)
- Added Rankings feature
- Performance improvements" \
    --groups "beta-testers"

echo "✅ iOS app deployed to Firebase App Distribution!"