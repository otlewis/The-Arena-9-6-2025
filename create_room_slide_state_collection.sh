#!/bin/bash

# Create room_slide_state collection for slide persistence
# This collection stores the current slide state for each room

echo "Creating room_slide_state collection..."

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
appwrite databases createCollection \
    --databaseId="$APPWRITE_DATABASE_ID" \
    --collectionId="room_slide_state" \
    --name="Room Slide State" \
    --permissions='["read(\"any\")","write(\"any\")","create(\"any\")","update(\"any\")","delete(\"any\")"]'

echo "Collection created. Now creating attributes..."

# Create attributes
appwrite databases createStringAttribute \
    --databaseId="$APPWRITE_DATABASE_ID" \
    --collectionId="room_slide_state" \
    --key="roomId" \
    --size=50 \
    --required=true

appwrite databases createStringAttribute \
    --databaseId="$APPWRITE_DATABASE_ID" \
    --collectionId="room_slide_state" \
    --key="slideFileId" \
    --size=50 \
    --required=true

appwrite databases createStringAttribute \
    --databaseId="$APPWRITE_DATABASE_ID" \
    --collectionId="room_slide_state" \
    --key="fileName" \
    --size=255 \
    --required=true

appwrite databases createStringAttribute \
    --databaseId="$APPWRITE_DATABASE_ID" \
    --collectionId="room_slide_state" \
    --key="pdfUrl" \
    --size=500 \
    --required=false

appwrite databases createIntegerAttribute \
    --databaseId="$APPWRITE_DATABASE_ID" \
    --collectionId="room_slide_state" \
    --key="currentSlide" \
    --required=true \
    --min=1

appwrite databases createIntegerAttribute \
    --databaseId="$APPWRITE_DATABASE_ID" \
    --collectionId="room_slide_state" \
    --key="totalSlides" \
    --required=true \
    --min=1

appwrite databases createStringAttribute \
    --databaseId="$APPWRITE_DATABASE_ID" \
    --collectionId="room_slide_state" \
    --key="uploadedBy" \
    --size=50 \
    --required=true

appwrite databases createStringAttribute \
    --databaseId="$APPWRITE_DATABASE_ID" \
    --collectionId="room_slide_state" \
    --key="updatedAt" \
    --size=50 \
    --required=true

echo "Creating indexes..."

# Create index on roomId for fast lookups
appwrite databases createIndex \
    --databaseId="$APPWRITE_DATABASE_ID" \
    --collectionId="room_slide_state" \
    --key="roomId_index" \
    --type="key" \
    --attributes='["roomId"]'

echo "✅ room_slide_state collection created successfully!"
echo "The collection will store slide presentation state for real-time sync across participants."