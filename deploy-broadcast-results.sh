#!/bin/bash

# Deploy broadcast-arena-results function to Appwrite Cloud

echo "🚀 Deploying broadcast-arena-results function..."

cd appwrite-functions/broadcast-arena-results

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Create deployment package
echo "📦 Creating deployment package..."
tar -czf ../../broadcast-arena-results-deployment.tar.gz .

cd ../..

echo "✅ Deployment package created: broadcast-arena-results-deployment.tar.gz"
echo ""
echo "Next steps:"
echo "1. Go to Appwrite Console: https://cloud.appwrite.io/console/project-683a37a8003719978879/functions"
echo "2. Create a new function named 'Broadcast Arena Results' with ID: broadcast-arena-results"
echo "3. Set runtime to Node.js 18"
echo "4. Set entrypoint to: index.js"
echo "5. Upload the tar.gz file: broadcast-arena-results-deployment.tar.gz"
echo "6. Add execute permission for: users"
echo "7. Add scopes: documents.read, documents.write"
echo ""
echo "OR use the Appwrite CLI (if it works):"
echo "  appwrite push functions"
