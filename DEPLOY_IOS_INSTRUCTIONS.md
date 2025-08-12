# iOS Beta Deployment Instructions

## Quick Deploy (if build completes)

Once the `flutter build ipa` command completes, run:

```bash
firebase appdistribution:distribute build/ios/archive/Runner.ipa \
    --app "1:18237618385:ios:159de79359b3a43e52edf0" \
    --release-notes "Arena v1.0.14+15 - Updated pricing, audio-only focus" \
    --groups "beta-testers"
```

## Manual Xcode Deploy (if Flutter build times out)

1. Open Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. In Xcode:
   - Select "Any iOS Device (arm64)" as the destination
   - Click Product → Archive
   - Wait for archive to complete

3. In the Archives window:
   - Select the new archive
   - Click "Distribute App"
   - Choose "Ad Hoc" or "Development"
   - Follow the wizard

4. Export the IPA and deploy:
   ```bash
   firebase appdistribution:distribute [path-to-exported.ipa] \
       --app "1:18237618385:ios:159de79359b3a43e52edf0" \
       --groups "beta-testers"
   ```

## Alternative: TestFlight

1. In Xcode Archives window:
   - Click "Distribute App"
   - Choose "App Store Connect"
   - Upload to TestFlight

2. In App Store Connect:
   - Add beta testers
   - Submit for beta review

## What's New in v1.0.14+15
- ✅ Premium pricing: 14 days free, $5 first month, then $10/month
- ✅ Removed video tiers (audio-only focus)
- ✅ Added Rankings card to home screen
- ✅ Fixed card sizing on home screen
- ✅ Cleaned up test screens
- ✅ Optimized WebRTC performance