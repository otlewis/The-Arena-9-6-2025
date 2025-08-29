#!/bin/bash

# Create the debate_slides storage bucket in Appwrite
# This script creates the necessary storage bucket for PDF slide uploads

echo "Creating debate_slides storage bucket..."

# Set Appwrite environment variables
export APPWRITE_ENDPOINT="https://cloud.appwrite.io/v1"
export APPWRITE_PROJECT_ID="683a37a8003719978879"

# You'll need to set your API key - get it from Appwrite console
if [ -z "$APPWRITE_API_KEY" ]; then
    echo "Please set APPWRITE_API_KEY environment variable"
    echo "Get your API key from: https://cloud.appwrite.io/console/project-683a37a8003719978879/keys"
    exit 1
fi

# Create the storage bucket using Appwrite CLI
appwrite storage create-bucket \
    --bucketId "debate_slides" \
    --name "Debate Slides" \
    --permissions "read(\"any\")" \
    --fileSecurity false \
    --enabled true \
    --maximumFileSize 10485760 \
    --allowedFileExtensions "pdf" \
    --compression "none" \
    --encryption false \
    --antivirus false

echo "Bucket created successfully!"
echo "You can now upload PDF slides through the Arena app."