#!/bin/bash

# WebRTC Audio Signaling Server Startup Script

echo "🚀 Starting WebRTC Audio Signaling Server..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    echo "🔗 Download from: https://nodejs.org/"
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm first."
    exit 1
fi

# Create server directory if it doesn't exist
if [ ! -d "webrtc-server" ]; then
    echo "📁 Creating server directory..."
    mkdir webrtc-server
fi

# Copy files to server directory
echo "📋 Setting up server files..."
cp signaling-server.js webrtc-server/
cp server-package.json webrtc-server/package.json

# Navigate to server directory
cd webrtc-server

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
else
    echo "✅ Dependencies already installed"
fi

echo "🎯 Starting signaling server on port 3001..."
echo "🔗 Test endpoint: http://localhost:3001/"
echo "📱 Use this server URL in the Flutter app"
echo ""
echo "Press Ctrl+C to stop the server"
echo "----------------------------------------"

# Start the server
node signaling-server.js