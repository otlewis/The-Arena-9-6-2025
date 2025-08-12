#!/bin/bash

# This script runs on the Linode server

set -e

echo "📦 Installing Docker and Docker Compose..."

# Update system
sudo apt update

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "✅ Docker installed"
else
    echo "✅ Docker already installed"
fi

# Install Docker Compose if not already installed
if ! command -v docker-compose &> /dev/null; then
    echo "🐳 Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed"
else
    echo "✅ Docker Compose already installed"
fi

echo "🔥 Setting up firewall rules..."
# Open required ports
sudo ufw allow 7880/tcp  # LiveKit WebSocket
sudo ufw allow 7881/tcp  # LiveKit RTC TCP
sudo ufw allow 50000:50100/udp  # LiveKit RTC UDP range

echo "🚀 Starting LiveKit server..."
# Stop any existing containers
docker-compose down 2>/dev/null || true

# Start LiveKit
docker-compose up -d

echo "⏳ Waiting for LiveKit to start..."
sleep 10

echo "🔍 Checking LiveKit status..."
docker-compose ps
docker-compose logs --tail=20

echo ""
echo "🎉 LiveKit deployment complete!"
echo "📡 Server should be running at: ws://$HOSTNAME:7880"
echo "🔍 Check logs: docker-compose logs -f"
echo "🛑 Stop server: docker-compose down"

