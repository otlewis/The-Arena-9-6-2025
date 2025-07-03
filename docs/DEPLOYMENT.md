# Deployment Guide

## Overview

This guide covers deployment procedures for the Arena Flutter application across different platforms and environments.

## Environment Configuration

### Development Environment
```bash
# Install Flutter SDK
flutter doctor

# Install dependencies
flutter pub get

# Run in development mode
flutter run --debug
```

### Staging Environment
```bash
# Build for staging
flutter build apk --flavor staging --debug
flutter build ios --flavor staging --debug

# Environment variables for staging
APPWRITE_ENDPOINT=https://staging-api.arena.app
APPWRITE_PROJECT_ID=staging-project-id
AGORA_APP_ID=staging-agora-app-id
```

### Production Environment
```bash
# Build for production
flutter build apk --release
flutter build ios --release
flutter build web --release

# Environment variables for production
APPWRITE_ENDPOINT=https://api.arena.app
APPWRITE_PROJECT_ID=production-project-id
AGORA_APP_ID=production-agora-app-id
```

## Platform-Specific Deployment

### Android Deployment

#### Prerequisites
```bash
# Install Android SDK
# Configure signing keys
# Set up Google Play Console
```

#### Build Configuration
```gradle
// android/app/build.gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        applicationId "com.arena.debate"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

#### Build Commands
```bash
# Build AAB for Play Store
flutter build appbundle --release

# Build APK for direct distribution
flutter build apk --release --split-per-abi

# Upload to Play Store
# Use Play Console or fastlane
```

#### Permissions
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

### iOS Deployment

#### Prerequisites
```bash
# Install Xcode
# Configure Apple Developer Account
# Set up provisioning profiles
```

#### Build Configuration
```plist
<!-- ios/Runner/Info.plist -->
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice debates</string>
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for profile pictures</string>
```

#### Build Commands
```bash
# Build for iOS
flutter build ios --release

# Archive and upload to App Store
# Use Xcode or fastlane
```

#### Code Signing
```bash
# Configure automatic signing in Xcode
# Or use manual provisioning profiles
# Set up distribution certificates
```

### Web Deployment

#### Build Configuration
```html
<!-- web/index.html -->
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="description" content="Arena - Advanced Debate Platform">
<link rel="manifest" href="manifest.json">
```

#### Build Commands
```bash
# Build for web
flutter build web --release --web-renderer html

# Deploy to hosting service
# Firebase Hosting, Netlify, or Vercel
```

#### Web-Specific Considerations
```dart
// lib/services/agora_service_web.dart
// Implement web-specific voice functionality
// Handle browser permissions for microphone
```

## Backend Deployment (Appwrite)

### Infrastructure Setup
```yaml
# docker-compose.yml for Appwrite
version: '3'
services:
  appwrite:
    image: appwrite/appwrite:latest
    container_name: appwrite
    restart: unless-stopped
    networks:
      - appwrite
    ports:
      - "80:80"
      - "443:443"
    environment:
      - _APP_ENV=production
      - _APP_WORKER_PER_CORE=6
      - _APP_LOCALE=en
      - _APP_CONSOLE_WHITELIST_ROOT=enabled
      - _APP_CONSOLE_WHITELIST_EMAILS=admin@arena.app
      - _APP_SYSTEM_EMAIL_NAME=Arena
      - _APP_SYSTEM_EMAIL_ADDRESS=noreply@arena.app
```

### Database Collections
```bash
# Create collections via Appwrite Console
# Or use setup scripts
```

### Functions Deployment
```javascript
// functions/agora-token-generator/src/index.js
module.exports = async (req, res) => {
  const { channelName, uid, role } = JSON.parse(req.payload);
  
  // Generate Agora token
  const token = generateAgoraToken(channelName, uid, role);
  
  res.json({
    success: true,
    token: token,
    expiration: Math.floor(Date.now() / 1000) + 3600,
    uid: uid
  });
};
```

## CI/CD Pipeline

### GitHub Actions Configuration
```yaml
# .github/workflows/deploy.yml
name: Deploy Arena App

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Run tests
        run: flutter test
      
      - name: Run analysis
        run: flutter analyze

  build-android:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      
      - name: Build Android APK
        run: flutter build apk --release
      
      - name: Upload to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: com.arena.debate
          releaseFiles: build/app/outputs/apk/release/app-release.apk
          track: production

  build-ios:
    needs: test
    runs-on: macos-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      
      - name: Build iOS
        run: flutter build ios --release --no-codesign
      
      - name: Upload to App Store
        uses: apple-actions/upload-testflight-build@v1
        with:
          app-path: build/ios/ipa/arena.ipa
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_API_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_API_PRIVATE_KEY }}

  build-web:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      
      - name: Build Web
        run: flutter build web --release
      
      - name: Deploy to Firebase Hosting
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          projectId: arena-debate-platform
```

### Fastlane Configuration
```ruby
# fastlane/Fastfile
default_platform(:android)

platform :android do
  desc "Deploy to Play Store"
  lane :deploy do
    gradle(task: "clean assembleRelease")
    upload_to_play_store(
      track: 'production',
      apk: 'app/build/outputs/apk/release/app-release.apk'
    )
  end
end

platform :ios do
  desc "Deploy to App Store"
  lane :deploy do
    build_app(scheme: "Runner")
    upload_to_app_store(
      force: true,
      skip_metadata: true,
      skip_screenshots: true
    )
  end
end
```

## Monitoring and Analytics

### Firebase Analytics Setup
```dart
// lib/services/analytics_service.dart
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  static Future<void> logDebateStarted(String arenaId) async {
    await _analytics.logEvent(
      name: 'debate_started',
      parameters: {'arena_id': arenaId},
    );
  }
  
  static Future<void> logChallengeAccepted(String challengeId) async {
    await _analytics.logEvent(
      name: 'challenge_accepted',
      parameters: {'challenge_id': challengeId},
    );
  }
}
```

### Crashlytics Integration
```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Set up Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  
  runApp(const ArenaApp());
}
```

### Performance Monitoring
```dart
// lib/services/performance_service.dart
class PerformanceService {
  static Future<void> trackArenaLoadTime() async {
    final trace = FirebasePerformance.instance.newTrace('arena_load_time');
    await trace.start();
    
    // Arena loading logic
    
    await trace.stop();
  }
}
```

## Security Considerations

### Environment Variables
```bash
# Use secure environment variable management
# Encrypt sensitive configuration
# Rotate API keys regularly
```

### Code Obfuscation
```bash
# Build with obfuscation for release
flutter build apk --obfuscate --split-debug-info=debug-info/
flutter build ios --obfuscate --split-debug-info=debug-info/
```

### Network Security
```dart
// lib/core/network/security.dart
class NetworkSecurity {
  static bool validateCertificate(X509Certificate cert, String host, int port) {
    // Certificate pinning implementation
    return true;
  }
}
```

## Rollback Procedures

### Mobile App Rollback
```bash
# Android: Release previous version on Play Store
# iOS: Submit previous version to App Store
# Emergency: Use staged rollout to limit impact
```

### Backend Rollback
```bash
# Appwrite: Revert to previous Docker image
docker-compose down
docker-compose up -d --scale appwrite=1 appwrite:previous-version

# Database: Restore from backup if needed
```

### Monitoring Rollback Success
```bash
# Monitor key metrics post-rollback
# Check error rates
# Verify user engagement
# Monitor performance metrics
```

## Post-Deployment Checklist

### Verification Steps
- [ ] App launches successfully
- [ ] User authentication works
- [ ] Voice chat functionality operational
- [ ] Challenge system functional
- [ ] Real-time messaging working
- [ ] Database operations successful
- [ ] Analytics data flowing
- [ ] Crash reports minimal

### Performance Monitoring
- [ ] App load times acceptable
- [ ] API response times normal
- [ ] Memory usage within limits
- [ ] Battery consumption reasonable
- [ ] Network usage optimized

### User Experience
- [ ] UI renders correctly
- [ ] Navigation flows smoothly
- [ ] Voice quality acceptable
- [ ] Notifications working
- [ ] Error handling graceful

This deployment guide ensures consistent, reliable releases across all platforms while maintaining security and performance standards.