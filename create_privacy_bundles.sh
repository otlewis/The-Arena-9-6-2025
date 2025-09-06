#!/bin/bash

# Create missing privacy bundles for iOS build
echo "Creating missing privacy bundles..."

bundles=(
    "workmanager_apple/flutter_workmanager_privacy.bundle/flutter_workmanager_privacy"
    "webview_flutter_wkwebview/webview_flutter_wkwebview_privacy.bundle/webview_flutter_wkwebview_privacy"
    "url_launcher_ios/url_launcher_ios_privacy.bundle/url_launcher_ios_privacy"
    "sqflite_darwin/sqflite_darwin_privacy.bundle/sqflite_darwin_privacy"
    "shared_preferences_foundation/shared_preferences_foundation_privacy.bundle/shared_preferences_foundation_privacy"
    "share_plus/share_plus_privacy.bundle/share_plus_privacy"
    "permission_handler_apple/permission_handler_apple_privacy.bundle/permission_handler_apple_privacy"
    "firebase_messaging/firebase_messaging_Privacy.bundle/firebase_messaging_Privacy"
    "firebase_core/firebase_core_Privacy.bundle/firebase_core_Privacy"
    "firebase_auth/firebase_auth_Privacy.bundle/firebase_auth_Privacy"
    "cloud_firestore/cloud_firestore_Privacy.bundle/cloud_firestore_Privacy"
    "firebase_database/firebase_database_Privacy.bundle/firebase_database_Privacy"
    "leveldb-library/leveldb_Privacy.bundle/leveldb_Privacy"
    "nanopb/nanopb_Privacy.bundle/nanopb_Privacy"
    "BoringSSL-GRPC/BoringSSL_Privacy.bundle/BoringSSL_Privacy"
    "gRPC-Core/grpc_Privacy.bundle/grpc_Privacy"
    "abseil/abseil_Privacy.bundle/abseil_Privacy"
    "GoogleUtilities/GoogleUtilities_Privacy.bundle/GoogleUtilities_Privacy"
)

for config in "Debug-iphonesimulator" "Debug-iphoneos"; do
    echo "Creating bundles for $config..."
    for bundle in "${bundles[@]}"; do
        bundle_dir="build/ios/$config/${bundle%/*}"
        bundle_file="build/ios/$config/${bundle}"
        
        mkdir -p "$bundle_dir"
        touch "$bundle_file"
        echo "Created: $bundle_file"
    done
done

echo "Privacy bundles created successfully!"