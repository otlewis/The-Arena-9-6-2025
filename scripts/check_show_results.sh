#!/bin/bash

# Script to check if showResults field is set on arena rooms

API_KEY="standard_00d440e0d9e7f53faaccdfac1ecfe49e4c0b30f2c4770b75a5cbaba5ea6375ea2d6e68483697726bfe1b8d67d8c8bb447ff97fce0f13893b38c5fe46c315aeff46cb38d109055f59689663b6214b480b346fddf7009dc776f183abdd3b07e4ceb78477b769d5f0631b696f0f342d5541d224b4305b9b4c40e7f3809c958e8bdd"
PROJECT_ID="683a37a8003719978879"
DATABASE_ID="arena_db"
COLLECTION_ID="arena_rooms"

echo "🔍 Checking recent arena rooms for showResults field..."
echo ""

# List recent documents
curl -s -X GET \
  "https://cloud.appwrite.io/v1/databases/${DATABASE_ID}/collections/${COLLECTION_ID}/documents?queries[]=limit(10)&queries[]=orderDesc(\$createdAt)" \
  -H "X-Appwrite-Project: ${PROJECT_ID}" \
  -H "X-Appwrite-Key: ${API_KEY}" \
  -H "Content-Type: application/json" | python3 -c "
import sys, json

try:
    data = json.load(sys.stdin)
    docs = data.get('documents', [])

    print(f'Found {len(docs)} recent arena rooms:\n')

    for doc in docs:
        print(f'Room ID: {doc.get(\"\$id\", \"N/A\")}')
        print(f'  Topic: {doc.get(\"topic\", \"N/A\")}')
        print(f'  Status: {doc.get(\"status\", \"N/A\")}')
        print(f'  Winner: {doc.get(\"winner\", \"NOT SET\")}')
        print(f'  ShowResults: {doc.get(\"showResults\", \"NOT SET\")}')
        print(f'  JudgingComplete: {doc.get(\"judgingComplete\", \"NOT SET\")}')
        print(f'  Created: {doc.get(\"\$createdAt\", \"N/A\")}')
        print('')

    print('\n✅ Debug complete!')
    print('\nIf showResults shows \"NOT SET\", the n8n workflow is not setting it.')
    print('Check your n8n workflow \"Force Broadcast Winner Update\" node.')
except Exception as e:
    print(f'❌ Error parsing response: {e}')
    print('Raw response:')
    print(sys.stdin.read())
"
