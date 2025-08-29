# Appwrite Storage Bucket Setup for Arena

This document explains how to create the required storage bucket for PDF slide uploads in Arena.

## Required Bucket: debate_slides

The Arena app needs a storage bucket called `debate_slides` for uploading PDF presentation files.

### Option 1: Using Appwrite Console (Recommended)

1. Go to [Appwrite Console](https://cloud.appwrite.io/console/project-683a37a8003719978879/storage)
2. Click "Create Bucket"
3. Set the following:
   - **Bucket ID**: `debate_slides`
   - **Name**: `Debate Slides`
   - **Permissions**: `read("any")`
   - **File Security**: Disabled
   - **Maximum File Size**: `10 MB` (10485760 bytes)
   - **Allowed Extensions**: `pdf`
   - **Compression**: None
   - **Encryption**: Disabled
   - **Antivirus**: Disabled

### Option 2: Using Appwrite CLI

```bash
# Set environment variables
export APPWRITE_ENDPOINT="https://cloud.appwrite.io/v1"
export APPWRITE_PROJECT_ID="683a37a8003719978879"
export APPWRITE_API_KEY="your-api-key-here"

# Create the bucket
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
```

### Option 3: Run the Setup Script

```bash
# Make sure you have APPWRITE_API_KEY set in your environment
export APPWRITE_API_KEY="your-api-key-here"

# Run the setup script
./create_debate_slides_bucket.sh
```

## Current Fallback Behavior

Until the `debate_slides` bucket is created, the app will:

1. Try to upload to `debate_slides` bucket first
2. If that fails, fallback to the existing `profile_images` bucket
3. PDF files will still work, but they'll be stored in the wrong bucket

## Getting Your API Key

1. Go to [Project Settings > API Keys](https://cloud.appwrite.io/console/project-683a37a8003719978879/keys)
2. Create a new API key with:
   - **Name**: "Arena Development"
   - **Scopes**: `storage.read`, `storage.write`
3. Copy the key and use it in the commands above

## Verification

After creating the bucket, verify it works by:

1. Running the Arena app
2. Going to any debate room
3. Opening "Show Materials" 
4. Switching to "Slides" tab
5. Trying to upload a PDF file

The upload should now succeed without the "storage_bucket_not_found" error.