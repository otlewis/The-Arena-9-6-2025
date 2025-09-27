#!/bin/bash

echo "🤖 Setting up Android build for Arena app..."

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found. Please run this from your Flutter project root."
    exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Error: Flutter is not installed or not in PATH."
    exit 1
fi

# Add Android platform if it doesn't exist
if [ ! -d "android" ]; then
    echo "📱 Adding Android platform to the project..."
    flutter create --platforms android .
else
    echo "✅ Android platform already exists"
fi

# Clean and get dependencies
echo "🧹 Cleaning project..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

# Check Android setup
echo "🔍 Checking Android setup..."
flutter doctor --android-licenses

# Create keystore for release signing (if it doesn't exist)
KEYSTORE_PATH="android/app/key.jks"
if [ ! -f "$KEYSTORE_PATH" ]; then
    echo "🔐 Creating release keystore..."

    # Generate keystore
    keytool -genkey -v -keystore android/app/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key \
        -dname "CN=Arena App, OU=Arena, O=Arena Inc, L=City, ST=State, C=US" \
        -storepass arena123 -keypass arena123

    # Create key.properties file
    cat > android/key.properties << EOF
storePassword=arena123
keyPassword=arena123
keyAlias=key
storeFile=key.jks
EOF

    echo "✅ Keystore created at $KEYSTORE_PATH"
else
    echo "✅ Keystore already exists"
fi

# Update build.gradle for release signing
GRADLE_FILE="android/app/build.gradle"
if [ -f "$GRADLE_FILE" ]; then
    echo "⚙️  Configuring release signing..."

    # Backup original
    cp "$GRADLE_FILE" "$GRADLE_FILE.backup"

    # Add signing configuration if not present
    if ! grep -q "signingConfigs" "$GRADLE_FILE"; then
        # Create a new build.gradle with signing config
        cat > "$GRADLE_FILE" << 'EOF'
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '1.0'
}

// Load keystore properties
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    namespace "com.thearenadtd.app"
    compileSdk flutter.compileSdkVersion
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "com.thearenadtd.app"
        minSdkVersion flutter.minSdkVersion
        targetSdkVersion flutter.targetSdkVersion
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
        multiDexEnabled true
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
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation 'androidx.multidex:multidex:2.0.1'
}
EOF
        echo "✅ Updated build.gradle with signing configuration"
    else
        echo "✅ Signing configuration already present"
    fi
else
    echo "❌ Error: build.gradle not found at $GRADLE_FILE"
    exit 1
fi

echo "🚀 Building Android App Bundle (AAB)..."
flutter build appbundle --release

# Check if build was successful
if [ $? -eq 0 ]; then
    # Find the AAB file
    AAB_FILE=$(find build -name "*.aab" -type f | head -1)

    if [ -n "$AAB_FILE" ]; then
        AAB_SIZE=$(ls -lh "$AAB_FILE" | awk '{print $5}')
        echo ""
        echo "🎉 SUCCESS! Android App Bundle created:"
        echo "📍 Location: $AAB_FILE"
        echo "📦 Size: $AAB_SIZE"
        echo ""
        echo "📋 Beta Testing Instructions:"
        echo "1. Upload the AAB file to Google Play Console"
        echo "2. Create a closed testing track"
        echo "3. Add your beta testers' email addresses"
        echo "4. Publish the release to the testing track"
        echo ""
        echo "🔗 Google Play Console: https://play.google.com/console"
    else
        echo "❌ Error: AAB file not found after build"
        exit 1
    fi
else
    echo "❌ Error: Build failed"
    exit 1
fi