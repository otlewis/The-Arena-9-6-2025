#!/bin/bash

# Arena Jitsi Server Setup Script for Linode
# Run this script on your fresh Ubuntu 22.04 Linode instance

set -e

echo "🚀 Starting Arena Jitsi Server Setup on Linode..."

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "🔧 Installing required packages..."
sudo apt install -y curl wget gnupg2 nginx certbot python3-certbot-nginx ufw

# Configure firewall
echo "🔒 Configuring firewall..."
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 4443/tcp
sudo ufw allow 10000:20000/udp
sudo ufw --force enable

# Get server IP and domain setup
SERVER_IP=$(curl -s https://api.ipify.org)
echo "🌐 Server IP: $SERVER_IP"

# Prompt for domain name
read -p "🌍 Enter your domain name (e.g., jitsi.yourdomain.com): " JITSI_DOMAIN

if [ -z "$JITSI_DOMAIN" ]; then
    echo "❌ Domain name is required. Please run the script again."
    exit 1
fi

echo "📋 Using domain: $JITSI_DOMAIN"
echo "⚠️  Make sure $JITSI_DOMAIN points to $SERVER_IP before continuing."
read -p "🔄 Press Enter when DNS is configured..."

# Install Jitsi Meet
echo "🎥 Installing Jitsi Meet..."

# Add Jitsi repository
curl https://download.jitsi.org/jitsi-key.gpg.key | sudo sh -c 'gpg --dearmor > /usr/share/keyrings/jitsi-keyring.gpg'
echo 'deb [signed-by=/usr/share/keyrings/jitsi-keyring.gpg] https://download.jitsi.org stable/' | sudo tee /etc/apt/sources.list.d/jitsi-stable.list > /dev/null

# Update package list
sudo apt update

# Install Jitsi Meet (this will prompt for domain)
echo "jitsi-meet-web-config jitsi-meet/jvb-hostname string $JITSI_DOMAIN" | sudo debconf-set-selections
echo "jitsi-meet-web-config jitsi-meet/jvb-serve boolean false" | sudo debconf-set-selections
sudo apt install -y jitsi-meet

# Generate SSL certificate
echo "🔐 Generating SSL certificate..."
sudo /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh

# Configure Jitsi for Arena
echo "⚙️ Configuring Jitsi for Arena..."

# Create Arena-specific configuration
sudo tee /etc/jitsi/meet/${JITSI_DOMAIN}-config.js > /dev/null << EOF
var config = {
    hosts: {
        domain: '$JITSI_DOMAIN',
        muc: 'conference.$JITSI_DOMAIN'
    },

    // Arena-specific settings
    prejoinPageEnabled: false,
    enableLobbyChat: false,
    requireDisplayName: false,
    enableWelcomePage: false,
    enableClosePage: false,
    disableProfile: true,
    startWithAudioMuted: false,
    startWithVideoMuted: true,
    
    // Disable lobby for Arena rooms
    lobby: {
        enabled: false
    },
    
    // Enhanced stability
    p2p: {
        enabled: false
    },
    
    // Audio-only mode support
    disableAP: false,
    disableAEC: false,
    disableNS: false,
    disableAGC: false,
    disableHPF: false,
    
    // Recording disabled
    hiddenDomain: 'recorder.$JITSI_DOMAIN',
    fileRecordingsEnabled: false,
    liveStreamingEnabled: false,
    
    // UI customization for Arena
    DEFAULT_WELCOME_PAGE_LOGO_URL: 'https://arena.app/logo.png',
    DISPLAY_WELCOME_PAGE_CONTENT: false,
    DISPLAY_WELCOME_PAGE_TOOLBAR_ADDITIONAL_CONTENT: false,
    
    // Toolbar configuration
    toolbarButtons: [
        'microphone', 'camera', 'closedcaptions', 'desktop', 'fullscreen',
        'fodeviceselection', 'hangup', 'profile', 'info', 'chat', 'recording',
        'livestreaming', 'etherpad', 'sharedvideo', 'settings', 'raisehand',
        'videoquality', 'filmstrip', 'invite', 'feedback', 'stats', 'shortcuts',
        'tileview', 'videobackgroundblur', 'download', 'help', 'mute-everyone',
        'security'
    ],
    
    // Connection settings
    useHostPageLocalStorage: true,
    
    // Analytics disabled
    analytics: {
        disabled: true
    }
};

// Interface configuration
var interfaceConfig = {
    TOOLBAR_BUTTONS: [
        'microphone', 'camera', 'hangup', 'chat', 'raisehand', 'settings'
    ],
    
    SETTINGS_SECTIONS: ['devices', 'language'],
    
    // Branding
    SHOW_JITSI_WATERMARK: false,
    SHOW_WATERMARK_FOR_GUESTS: false,
    
    // UI
    DISABLE_VIDEO_BACKGROUND: true,
    INITIAL_TOOLBAR_TIMEOUT: 20000,
    TOOLBAR_TIMEOUT: 4000,
    
    // Mobile
    MOBILE_APP_PROMO: false
};
EOF

# Configure Jicofo for no authentication
sudo tee -a /etc/jitsi/jicofo/config >> /dev/null << EOF

# Arena configuration - allow guests
jicofo.authentication.enabled=false
jicofo.authentication.type=NONE
EOF

# Configure Prosody for Arena
sudo tee -a /etc/prosody/conf.avail/${JITSI_DOMAIN}.cfg.lua >> /dev/null << EOF

-- Arena-specific configuration
muc_lobby_whitelist = {}
muc_access_whitelist = {}
lobby_muc = "lobby.$JITSI_DOMAIN"
main_muc = "conference.$JITSI_DOMAIN"

-- Disable lobby by default
modules_enabled = {
    "bosh";
    "pubsub";
    "ping";
    "speakerstats";
    "turncredentials";
    "conference_duration";
    "end_conference";
    "version";
}
EOF

# Restart services
echo "🔄 Restarting Jitsi services..."
sudo systemctl restart prosody
sudo systemctl restart jicofo
sudo systemctl restart jitsi-videobridge2
sudo systemctl restart nginx

# Display connection info
echo ""
echo "✅ Arena Jitsi Server Setup Complete!"
echo "🌐 Server URL: https://$JITSI_DOMAIN"
echo "🎯 Test URL: https://$JITSI_DOMAIN/ArenaTest"
echo ""
echo "📋 Configuration Summary:"
echo "   - Domain: $JITSI_DOMAIN"
echo "   - SSL: Enabled (Let's Encrypt)"
echo "   - Lobby: Disabled"
echo "   - Authentication: Guest access enabled"
echo "   - Audio-only: Supported"
echo ""
echo "🔧 Next Steps:"
echo "1. Test the server by visiting: https://$JITSI_DOMAIN/ArenaTest"
echo "2. Update your Arena app to use: https://$JITSI_DOMAIN"
echo "3. Monitor logs: sudo journalctl -u jitsi-videobridge2 -f"
echo ""
echo "💡 Server Status Commands:"
echo "   sudo systemctl status jitsi-videobridge2"
echo "   sudo systemctl status jicofo"
echo "   sudo systemctl status prosody"