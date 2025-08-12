#!/bin/bash

# Setup Nginx with SSL for WebRTC Server

SERVER="root@jitsi.dialecticlabs.com"

echo "🔐 Setting up Nginx with SSL for WebRTC..."

# Create setup script
cat > nginx-setup.sh << 'EOF'
#!/bin/bash

echo "📦 Installing Nginx and Certbot..."
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx

echo "🔧 Configuring Nginx..."
# Backup existing config
cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup

# Copy new config
cp /tmp/nginx-webrtc-config.conf /etc/nginx/sites-available/webrtc

# Enable the site
ln -sf /etc/nginx/sites-available/webrtc /etc/nginx/sites-enabled/webrtc

# Test nginx config
nginx -t

echo "🔐 Getting SSL certificate..."
certbot --nginx -d jitsi.dialecticlabs.com --non-interactive --agree-tos --email your-email@example.com

echo "🔄 Reloading Nginx..."
systemctl reload nginx

echo "✅ Nginx SSL setup complete!"
echo "🌐 Your WebRTC server is now available at:"
echo "   - Health: https://jitsi.dialecticlabs.com/health"
echo "   - Signaling: wss://jitsi.dialecticlabs.com/signaling"
echo "   - MediaSoup: wss://jitsi.dialecticlabs.com/mediasoup"
EOF

# Upload files
echo "📤 Uploading configuration..."
scp nginx-webrtc-config.conf $SERVER:/tmp/
scp nginx-setup.sh $SERVER:/tmp/
ssh $SERVER "chmod +x /tmp/nginx-setup.sh"

echo "🚀 Running setup on server..."
ssh $SERVER "/tmp/nginx-setup.sh"

echo "✅ Setup complete!"