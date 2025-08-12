#!/bin/bash
# Server Resource Monitoring Script for Audio Capacity Testing
# Run this on your Linode server: ssh root@172.236.109.9

echo "🖥️  Starting Arena Audio Capacity Monitoring..."
echo "📊 Server: $(hostname) - $(date)"
echo "📈 Monitoring WebSocket P2P Audio Server (Port 3006)"
echo "=================================================="

# Function to get process info
get_process_info() {
    echo "🔍 WebSocket Server Processes:"
    ps aux | grep -E "(node.*3006|webrtc|websocket)" | grep -v grep
    echo ""
    
    echo "📊 Port Usage:"
    netstat -tulpn | grep -E "(3005|3006|10000|11000|12000)" | head -10
    echo ""
}

# Function to monitor resources
monitor_resources() {
    echo "💾 Memory Usage:"
    free -h
    echo ""
    
    echo "🖥️  CPU Usage:"
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
    echo ""
    
    echo "🌐 Network Connections:"
    ss -tuln | grep -E "(3005|3006)" | wc -l
    echo " active WebRTC connections"
    echo ""
    
    echo "📊 WebRTC Port Range Usage (10000-12000):"
    netstat -an | grep -E ":1[0-2][0-9][0-9][0-9]" | wc -l
    echo " ports in use"
    echo ""
}

# Initial status
get_process_info
monitor_resources

echo "🔄 Starting continuous monitoring (press Ctrl+C to stop)..."
echo "=================================================="

# Continuous monitoring every 5 seconds
while true; do
    echo "$(date) - Active connections: $(ss -tuln | grep -E '(3005|3006)' | wc -l) WebRTC, $(netstat -an | grep -E ':1[0-2][0-9][0-9][0-9]' | wc -l) media ports"
    sleep 5
done