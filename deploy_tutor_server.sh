#!/bin/bash
# Deploy AI Debate Tutor Server to remote host

SERVER="50.21.187.76"
SERVER_USER="root"  # Change this to your actual username

echo "Deploying AI Debate Tutor Server to $SERVER..."

# Copy the Python server file
echo "1. Copying debate_tutor_server.py..."
scp debate_tutor_server.py $SERVER_USER@$SERVER:/root/

# SSH and setup
echo "2. Setting up on remote server..."
ssh $SERVER_USER@$SERVER << 'ENDSSH'
# Install dependencies
pip3 install flask flask-cors requests

# Create systemd service for auto-start
cat > /etc/systemd/system/debate-tutor.service << 'EOF'
[Unit]
Description=AI Debate Tutor Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/bin/python3 /root/debate_tutor_server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable debate-tutor
systemctl restart debate-tutor

# Check status
systemctl status debate-tutor --no-pager

echo ""
echo "Deployment complete!"
echo "Server is running at: http://50.21.187.76:5555/webhook/debate-tutor"
echo ""
echo "To check logs: journalctl -u debate-tutor -f"
echo "To restart: systemctl restart debate-tutor"
ENDSSH

echo ""
echo "Done! Update your Flutter app to use:"
echo "http://50.21.187.76:5555/webhook/debate-tutor"
