#!/bin/bash

echo "🚀 Starting Arena MediaSoup Single Server..."
echo "📋 Server specs: 2 CPU cores, 4GB RAM"
echo "🌐 Target capacity: 1,000-1,500 concurrent users"
echo ""

# Check if node is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Check if required packages are installed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing packages..."
    npm install
fi

# Set environment variables
export ANNOUNCED_IP="172.236.109.9"
export PORT=3001
export MEDIASOUP_WORKERS=2

# Start the server
echo "🔥 Starting MediaSoup server on port 3001..."
node start-mediasoup-single.cjs