#!/bin/bash

echo "📤 Uploading policy files to IONOS server..."
echo "You'll be prompted for the root password twice"
echo ""

# Upload terms.html
echo "Uploading terms.html..."
scp /Users/otislewis/arena2/terms.html root@50.21.187.76:/var/www/thearenadtd/

# Upload privacy.html  
echo "Uploading privacy.html..."
scp /Users/otislewis/arena2/privacy.html root@50.21.187.76:/var/www/thearenadtd/

echo ""
echo "✅ Files uploaded!"
echo ""
echo "Your policy URLs are now live at:"
echo "📜 Terms: http://50.21.187.76/terms.html"
echo "🔒 Privacy: http://50.21.187.76/privacy.html"