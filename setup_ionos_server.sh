#!/bin/bash

# IONOS VPS Setup Script for The Arena DTD
# Server IP: 50.21.187.76

echo "🚀 Setting up IONOS VPS for The Arena DTD..."
echo "========================================="
echo ""
echo "Step 1: Connect to your server"
echo "Run this command:"
echo ""
echo "ssh root@50.21.187.76"
echo ""
echo "When prompted, enter your root password from IONOS"
echo ""
echo "Step 2: Once connected, run these commands:"
echo "========================================="

cat << 'EOF'

# Update system
apt update && apt upgrade -y

# Install nginx web server
apt install nginx -y

# Create directory for your website
mkdir -p /var/www/thearenadtd

# Start nginx
systemctl start nginx
systemctl enable nginx

# Configure firewall
ufw allow 'Nginx Full'
ufw allow OpenSSH
ufw --force enable

# Create nginx site configuration
cat > /etc/nginx/sites-available/thearenadtd << 'NGINX_CONFIG'
server {
    listen 80;
    listen [::]:80;
    server_name 50.21.187.76;
    root /var/www/thearenadtd;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX_CONFIG

# Enable the site
ln -s /etc/nginx/sites-available/thearenadtd /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# Test and reload nginx
nginx -t && systemctl reload nginx

echo "✅ Web server setup complete!"
echo "Now upload your HTML files to /var/www/thearenadtd/"

EOF