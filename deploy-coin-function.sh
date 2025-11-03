#!/bin/bash

# Deploy the manage-coin-balance function to Appwrite
echo "🚀 Deploying manage-coin-balance function..."

# Navigate to function directory
cd appwrite-functions/manage-coin-balance

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Navigate back to root
cd ../..

# Create deployment using appwrite CLI
echo "📤 Creating deployment..."
cd appwrite-functions/manage-coin-balance

# Create a tarball of the function
tar -czf deployment.tar.gz package.json src/

# Use curl to deploy (alternative to CLI)
echo "✅ Function code ready for deployment"
echo ""
echo "To deploy manually:"
echo "1. Go to Appwrite Console: https://cloud.appwrite.io/console/project-683a37a8003719978879"
echo "2. Navigate to Functions → 'Manage Coin Balance'"
echo "3. Click 'Create Deployment'"
echo "4. Upload: deployment.tar.gz"
echo "5. Entrypoint: src/main.js"
echo "6. Click 'Deploy'"
echo ""
echo "Or run this command in Appwrite Console Functions:"
echo "appwrite functions createDeployment --functionId=manage-coin-balance --activate=true --entrypoint=src/main.js --code=./deployment.tar.gz"
