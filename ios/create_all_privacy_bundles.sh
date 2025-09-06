#!/bin/bash
set -e

# Create all privacy bundles needed for iOS build
echo "Creating privacy bundles for iOS build..."

# Core privacy bundles from CocoaPods resource script
mkdir -p "build/ios/Debug-iphonesimulator/firebase_messaging/firebase_messaging_Privacy.bundle"
echo '' > "build/ios/Debug-iphonesimulator/firebase_messaging/firebase_messaging_Privacy.bundle/firebase_messaging_Privacy"

mkdir -p "build/ios/Debug-iphonesimulator/google_sign_in_ios/google_sign_in_ios_privacy.bundle"
echo '' > "build/ios/Debug-iphonesimulator/google_sign_in_ios/google_sign_in_ios_privacy.bundle/google_sign_in_ios_privacy"

mkdir -p "build/ios/Debug-iphonesimulator/permission_handler_apple/permission_handler_apple_privacy.bundle"
echo '' > "build/ios/Debug-iphonesimulator/permission_handler_apple/permission_handler_apple_privacy.bundle/permission_handler_apple_privacy"

# Additional privacy bundles found during build
mkdir -p "build/ios/Debug-iphonesimulator/url_launcher_ios/url_launcher_ios_privacy.bundle"
echo '' > "build/ios/Debug-iphonesimulator/url_launcher_ios/url_launcher_ios_privacy.bundle/url_launcher_ios_privacy"

mkdir -p "build/ios/Debug-iphonesimulator/workmanager_apple/flutter_workmanager_privacy.bundle"
echo '' > "build/ios/Debug-iphonesimulator/workmanager_apple/flutter_workmanager_privacy.bundle/flutter_workmanager_privacy"

mkdir -p "build/ios/Debug-iphonesimulator/webview_flutter_wkwebview/webview_flutter_wkwebview_privacy.bundle"
echo '' > "build/ios/Debug-iphonesimulator/webview_flutter_wkwebview/webview_flutter_wkwebview_privacy.bundle/webview_flutter_wkwebview_privacy"

mkdir -p "build/ios/Debug-iphonesimulator/sqflite_darwin/sqflite_darwin_privacy.bundle"
echo '' > "build/ios/Debug-iphonesimulator/sqflite_darwin/sqflite_darwin_privacy.bundle/sqflite_darwin_privacy"

mkdir -p "build/ios/Debug-iphonesimulator/abseil/xcprivacy.bundle"
echo '' > "build/ios/Debug-iphonesimulator/abseil/xcprivacy.bundle/xcprivacy"

# Also create for iphoneos configuration
mkdir -p "build/ios/Debug-iphoneos/firebase_messaging/firebase_messaging_Privacy.bundle"
echo '' > "build/ios/Debug-iphoneos/firebase_messaging/firebase_messaging_Privacy.bundle/firebase_messaging_Privacy"

mkdir -p "build/ios/Debug-iphoneos/google_sign_in_ios/google_sign_in_ios_privacy.bundle"
echo '' > "build/ios/Debug-iphoneos/google_sign_in_ios/google_sign_in_ios_privacy.bundle/google_sign_in_ios_privacy"

mkdir -p "build/ios/Debug-iphoneos/permission_handler_apple/permission_handler_apple_privacy.bundle"
echo '' > "build/ios/Debug-iphoneos/permission_handler_apple/permission_handler_apple_privacy.bundle/permission_handler_apple_privacy"

mkdir -p "build/ios/Debug-iphoneos/url_launcher_ios/url_launcher_ios_privacy.bundle"
echo '' > "build/ios/Debug-iphoneos/url_launcher_ios/url_launcher_ios_privacy.bundle/url_launcher_ios_privacy"

mkdir -p "build/ios/Debug-iphoneos/workmanager_apple/flutter_workmanager_privacy.bundle"
echo '' > "build/ios/Debug-iphoneos/workmanager_apple/flutter_workmanager_privacy.bundle/flutter_workmanager_privacy"

mkdir -p "build/ios/Debug-iphoneos/webview_flutter_wkwebview/webview_flutter_wkwebview_privacy.bundle"
echo '' > "build/ios/Debug-iphoneos/webview_flutter_wkwebview/webview_flutter_wkwebview_privacy.bundle/webview_flutter_wkwebview_privacy"

mkdir -p "build/ios/Debug-iphoneos/sqflite_darwin/sqflite_darwin_privacy.bundle"
echo '' > "build/ios/Debug-iphoneos/sqflite_darwin/sqflite_darwin_privacy.bundle/sqflite_darwin_privacy"

mkdir -p "build/ios/Debug-iphoneos/abseil/xcprivacy.bundle"
echo '' > "build/ios/Debug-iphoneos/abseil/xcprivacy.bundle/xcprivacy"

echo "Privacy bundles created successfully!"