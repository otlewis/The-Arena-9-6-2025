#!/bin/bash

echo "🎬 Setting up Arena Playback System database collections..."

# Check if APPWRITE_API_KEY is set
if [ -z "$APPWRITE_API_KEY" ]; then
    echo "⚠️ APPWRITE_API_KEY environment variable is not set"
    echo "Please export your Appwrite API key:"
    echo "export APPWRITE_API_KEY='your_api_key_here'"
    echo ""
    echo "You can get your API key from:"
    echo "https://cloud.appwrite.io/console/project-683a37a8003719978879/settings/keys"
    exit 1
fi

echo "🔧 Running database schema setup..."
dart scripts/setup_playback_collections.dart

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Arena Playback System database setup completed successfully!"
    echo ""
    echo "🚀 Next steps:"
    echo "1. Add playback toggle to arena room creation UI"
    echo "2. Implement LiveKit recording integration"
    echo "3. Create playback room UI and controls"
    echo ""
else
    echo "❌ Setup failed. Please check the error messages above."
    exit 1
fi