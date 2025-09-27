#!/bin/bash

# Create speaker_queue collection for debates & discussions
echo "🔥 Creating speaker_queue collection..."

# Set your Appwrite endpoint and project details
ENDPOINT="https://cloud.appwrite.io/v1"
PROJECT_ID="683a37a8003719978879"
DATABASE_ID="arena_db"
API_KEY="$APPWRITE_API_KEY"  # Make sure this is set

# Create the collection
curl -X POST \
  "$ENDPOINT/databases/$DATABASE_ID/collections" \
  -H "X-Appwrite-Project: $PROJECT_ID" \
  -H "X-Appwrite-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "collectionId": "speaker_queue",
    "name": "Speaker Queue",
    "documentSecurity": true,
    "permissions": [
      "read(\"any\")",
      "create(\"any\")",
      "update(\"any\")",
      "delete(\"any\")"
    ]
  }'

echo ""
echo "✅ Collection created! Now creating attributes..."

sleep 2

# Create roomId attribute
curl -X POST \
  "$ENDPOINT/databases/$DATABASE_ID/collections/speaker_queue/attributes/string" \
  -H "X-Appwrite-Project: $PROJECT_ID" \
  -H "X-Appwrite-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "roomId",
    "size": 100,
    "required": true
  }'

sleep 1

# Create userId attribute
curl -X POST \
  "$ENDPOINT/databases/$DATABASE_ID/collections/speaker_queue/attributes/string" \
  -H "X-Appwrite-Project: $PROJECT_ID" \
  -H "X-Appwrite-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "userId",
    "size": 100,
    "required": true
  }'

sleep 1

# Create userName attribute
curl -X POST \
  "$ENDPOINT/databases/$DATABASE_ID/collections/speaker_queue/attributes/string" \
  -H "X-Appwrite-Project: $PROJECT_ID" \
  -H "X-Appwrite-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "userName",
    "size": 200,
    "required": true
  }'

sleep 1

# Create queuePosition attribute
curl -X POST \
  "$ENDPOINT/databases/$DATABASE_ID/collections/speaker_queue/attributes/integer" \
  -H "X-Appwrite-Project: $PROJECT_ID" \
  -H "X-Appwrite-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "queuePosition",
    "required": true,
    "min": 1
  }'

sleep 1

# Create status attribute
curl -X POST \
  "$ENDPOINT/databases/$DATABASE_ID/collections/speaker_queue/attributes/string" \
  -H "X-Appwrite-Project: $PROJECT_ID" \
  -H "X-Appwrite-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "status",
    "size": 50,
    "required": true,
    "xdefault": "queued"
  }'

sleep 1

# Create joinedAt attribute
curl -X POST \
  "$ENDPOINT/databases/$DATABASE_ID/collections/speaker_queue/attributes/datetime" \
  -H "X-Appwrite-Project: $PROJECT_ID" \
  -H "X-Appwrite-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "joinedAt",
    "required": true
  }'

echo ""
echo "✅ All attributes created! Waiting for them to be ready..."
sleep 10

# Create indexes
echo "Creating indexes..."

# roomId index
curl -X POST \
  "$ENDPOINT/databases/$DATABASE_ID/collections/speaker_queue/indexes" \
  -H "X-Appwrite-Project: $PROJECT_ID" \
  -H "X-Appwrite-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "roomId_index",
    "type": "key",
    "attributes": ["roomId"]
  }'

sleep 2

# Queue order index
curl -X POST \
  "$ENDPOINT/databases/$DATABASE_ID/collections/speaker_queue/indexes" \
  -H "X-Appwrite-Project: $PROJECT_ID" \
  -H "X-Appwrite-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "queue_order_index",
    "type": "key",
    "attributes": ["roomId", "queuePosition"]
  }'

sleep 2

# Unique user per room index
curl -X POST \
  "$ENDPOINT/databases/$DATABASE_ID/collections/speaker_queue/indexes" \
  -H "X-Appwrite-Project: $PROJECT_ID" \
  -H "X-Appwrite-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "unique_user_per_room",
    "type": "unique",
    "attributes": ["roomId", "userId"]
  }'

echo ""
echo "🎉 Speaker queue collection setup complete!"
echo "Collection: speaker_queue"
echo "Database: arena_db"
echo ""
echo "Schema:"
echo "- roomId (string): The room ID"
echo "- userId (string): User ID in queue"
echo "- userName (string): Display name"
echo "- queuePosition (integer): Position in queue (1, 2, 3, etc.)"
echo "- status (string): 'queued' or 'speaking'"
echo "- joinedAt (datetime): When they joined the queue"