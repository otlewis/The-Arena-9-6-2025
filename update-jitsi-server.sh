#!/bin/bash

# Script to update Arena app to use your new Linode Jitsi server

echo "🔧 Updating Arena app to use your Linode Jitsi server..."

# Prompt for the Jitsi domain
read -p "🌍 Enter your Jitsi server domain (e.g., jitsi.yourdomain.com): " JITSI_DOMAIN

if [ -z "$JITSI_DOMAIN" ]; then
    echo "❌ Domain name is required."
    exit 1
fi

# Validate domain format
if [[ ! "$JITSI_DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    echo "❌ Invalid domain format. Please use format: jitsi.yourdomain.com"
    exit 1
fi

JITSI_SERVER_URL="https://$JITSI_DOMAIN"

echo "🎯 Updating JitsiService to use: $JITSI_SERVER_URL"

# Update the Jitsi server URL in the service file
sed -i '' "s|return 'https://jitsi.org';|return '$JITSI_SERVER_URL';|g" lib/services/jitsi_service.dart

# Update the comment as well
sed -i '' "s|// Use jitsi.org - sometimes has different lobby behavior|// Use Arena's dedicated Linode Jitsi server|g" lib/services/jitsi_service.dart

echo "✅ Updated JitsiService configuration!"
echo ""
echo "📋 Changes made:"
echo "   - Server URL: $JITSI_SERVER_URL"
echo "   - Lobby: Disabled on your server"
echo "   - Authentication: Guest access enabled"
echo ""
echo "🔄 Next steps:"
echo "1. Test the app with: flutter run"
echo "2. Create a debate room to test voice functionality"
echo "3. Monitor server performance in Linode dashboard"
echo ""
echo "💡 Your server gives you complete control over:"
echo "   - Lobby settings (disabled)"
echo "   - Authentication (guest access)"
echo "   - Audio quality settings"
echo "   - Connection limits"
echo "   - Custom branding"