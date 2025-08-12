#!/bin/bash

# LiveKit Server Setup Script for Arena Testing
# This script downloads and runs LiveKit server locally for testing

set -e

LIVEKIT_VERSION="v1.5.2"
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Map architecture names
case $ARCH in
    x86_64) ARCH="amd64" ;;
    arm64) ARCH="arm64" ;;
    aarch64) ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

BINARY_NAME="livekit-server"
DOWNLOAD_URL="https://github.com/livekit/livekit/releases/download/${LIVEKIT_VERSION}/livekit_${LIVEKIT_VERSION}_${PLATFORM}_${ARCH}.tar.gz"

echo "🚀 Setting up LiveKit Server for Arena testing..."
echo "Platform: $PLATFORM, Architecture: $ARCH"
echo "Download URL: $DOWNLOAD_URL"

# Create livekit directory
mkdir -p livekit-server
cd livekit-server

# Download if not already present
if [ ! -f "$BINARY_NAME" ]; then
    echo "📥 Downloading LiveKit Server..."
    curl -L -o livekit-server.tar.gz "$DOWNLOAD_URL"
    
    echo "📦 Extracting..."
    tar -xzf livekit-server.tar.gz
    chmod +x livekit-server
    rm livekit-server.tar.gz
    
    echo "✅ LiveKit Server downloaded successfully"
else
    echo "✅ LiveKit Server already exists"
fi

# Start the server
echo "🏃 Starting LiveKit Server..."
echo "Server will be available at: ws://localhost:7880"
echo "Press Ctrl+C to stop the server"
echo ""

export LIVEKIT_KEYS="LKAPI1234567890: your-secret-key-here"

./livekit-server \
    --bind 0.0.0.0 \
    --port 7880 \
    --rtc-port 7881 \
    --rtc-port-range-start 50000 \
    --rtc-port-range-end 50100 \
    --dev \
    --log-level debug