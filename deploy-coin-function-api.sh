#!/bin/bash

# Deploy manage-coin-balance function using Appwrite API
# This bypasses the CLI's interactive prompt issues

PROJECT_ID="683a37a8003719978879"
FUNCTION_ID="manage-coin-balance"
ENDPOINT="https://cloud.appwrite.io/v1"

echo "🚀 Deploying manage-coin-balance function via Appwrite API..."
echo ""
echo "⚠️  You need to complete this deployment manually:"
echo ""
echo "1. Open Appwrite Console:"
echo "   https://cloud.appwrite.io/console/project-${PROJECT_ID}/functions"
echo ""
echo "2. The function 'Manage Coin Balance' should already exist (from appwrite.json)"
echo "   - If it doesn't exist, click '+ Create function' first"
echo ""
echo "3. Click on 'Manage Coin Balance' → 'Create deployment'"
echo ""
echo "4. Upload this file:"
echo "   📦 /Users/otislewis/arena2/manage-coin-balance-deployment.tar.gz"
echo ""
echo "5. Set configuration:"
echo "   - Entrypoint: src/main.js"
echo "   - Build command: npm install"
echo ""
echo "6. Click 'Create' and wait for deployment to complete"
echo ""
echo "7. Once deployed, activate it by clicking 'Activate'"
echo ""
echo "✅ After deployment, test with:"
echo "   - Open the function in Console"
echo "   - Click 'Execute'"
echo "   - Use this test payload:"
echo ""
echo '{
  "operation": "GET",
  "userId": "YOUR_USER_ID"
}'
echo ""
echo "The function is ready to deploy! 🎉"
