#!/bin/bash

# Deploy assign-arena-role Appwrite Function
# This script deploys the atomic role assignment function

set -e  # Exit on error

echo "🚀 Deploying assign-arena-role function..."

# Change to function directory
cd appwrite-functions/assign-arena-role

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Deploy using Appwrite CLI
echo "☁️  Deploying to Appwrite..."
appwrite deploy function \
  --function-id assign-arena-role \
  || appwrite functions create \
    --functionId assign-arena-role \
    --name "Assign Arena Role" \
    --runtime "node-18.0" \
    --execute "users" \
    --events "" \
    --schedule "" \
    --timeout 15

# Update function code
echo "📤 Uploading function code..."
cd ../..
tar -czf assign-arena-role.tar.gz -C appwrite-functions/assign-arena-role .
appwrite functions updateDeployment \
  --functionId assign-arena-role \
  --code assign-arena-role.tar.gz \
  --activate true

# Clean up
rm assign-arena-role.tar.gz

echo "✅ Deployment complete!"
echo ""
echo "⚙️  Next steps:"
echo "1. Set environment variables in Appwrite Console:"
echo "   - APPWRITE_API_KEY"
echo "   - LIVEKIT_HOST"
echo "   - LIVEKIT_API_KEY"
echo "   - LIVEKIT_API_SECRET"
echo "2. Test the function with a sample request"
echo "3. Monitor function logs for any errors"
