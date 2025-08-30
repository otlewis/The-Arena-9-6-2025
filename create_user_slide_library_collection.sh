#!/bin/bash

# Create user_slide_library collection for personal slide management
# This collection stores users' uploaded slide presentations

echo "Creating user_slide_library collection..."

# Set Appwrite credentials
export APPWRITE_ENDPOINT="https://cloud.appwrite.io/v1"
export APPWRITE_PROJECT_ID="683a37a8003719978879"
export APPWRITE_DATABASE_ID="arena_db"

# Check if appwrite CLI is available
if ! command -v appwrite &> /dev/null; then
    echo "Appwrite CLI not found. Please install it first:"
    echo "npm install -g appwrite-cli"
    exit 1
fi

# Create collection
appwrite databases create-collection \
    --database-id="$APPWRITE_DATABASE_ID" \
    --collection-id="user_slide_library" \
    --name="User Slide Library" \
    --permissions='["read(\"any\")",\"write(\"any\")",\"create(\"any\")",\"update(\"any\")",\"delete(\"any\")\"]'

echo "Collection created. Now creating attributes..."

# Create attributes
appwrite databases create-string-attribute \
    --database-id="$APPWRITE_DATABASE_ID" \
    --collection-id="user_slide_library" \
    --key="userId" \
    --size=50 \
    --required=true

appwrite databases create-string-attribute \
    --database-id="$APPWRITE_DATABASE_ID" \
    --collection-id="user_slide_library" \
    --key="title" \
    --size=255 \
    --required=true

appwrite databases create-string-attribute \
    --database-id="$APPWRITE_DATABASE_ID" \
    --collection-id="user_slide_library" \
    --key="fileName" \
    --size=255 \
    --required=true

appwrite databases create-string-attribute \
    --database-id="$APPWRITE_DATABASE_ID" \
    --collection-id="user_slide_library" \
    --key="fileId" \
    --size=50 \
    --required=true

appwrite databases create-integer-attribute \
    --database-id="$APPWRITE_DATABASE_ID" \
    --collection-id="user_slide_library" \
    --key="totalSlides" \
    --required=true \
    --min=1

appwrite databases create-string-attribute \
    --database-id="$APPWRITE_DATABASE_ID" \
    --collection-id="user_slide_library" \
    --key="thumbnailUrl" \
    --size=500 \
    --required=false

appwrite databases create-string-attribute \
    --database-id="$APPWRITE_DATABASE_ID" \
    --collection-id="user_slide_library" \
    --key="description" \
    --size=1000 \
    --required=false

appwrite databases create-string-attribute \
    --database-id="$APPWRITE_DATABASE_ID" \
    --collection-id="user_slide_library" \
    --key="fileType" \
    --size=10 \
    --required=true

appwrite databases create-string-attribute \
    --database-id="$APPWRITE_DATABASE_ID" \
    --collection-id="user_slide_library" \
    --key="uploadedAt" \
    --size=50 \
    --required=true

appwrite databases create-string-attribute \
    --database-id="$APPWRITE_DATABASE_ID" \
    --collection-id="user_slide_library" \
    --key="lastUsedAt" \
    --size=50 \
    --required=false

echo "Creating indexes..."

# Create index on userId for fast user-specific lookups
appwrite databases create-index \
    --database-id="$APPWRITE_DATABASE_ID" \
    --collection-id="user_slide_library" \
    --key="userId_index" \
    --type="key" \
    --attributes='["userId"]'

# Create index on uploadedAt for chronological sorting
appwrite databases create-index \
    --database-id="$APPWRITE_DATABASE_ID" \
    --collection-id="user_slide_library" \
    --key="uploadedAt_index" \
    --type="key" \
    --attributes='["uploadedAt"]'

echo "✅ user_slide_library collection created successfully!"
echo "Users can now upload and manage their personal slide presentations."