#!/bin/bash

# Script to manually set showResults=true on an arena room

if [ -z "$1" ]; then
  echo "Usage: ./scripts/set_show_results.sh <room_id> [winner]"
  echo "Example: ./scripts/set_show_results.sh 67a1b2c3d4e5f6g7h8i9 affirmative"
  exit 1
fi

ROOM_ID="$1"
WINNER="${2:-affirmative}"

API_KEY="standard_00d440e0d9e7f53faaccdfac1ecfe49e4c0b30f2c4770b75a5cbaba5ea6375ea2d6e68483697726bfe1b8d67d8c8bb447ff97fce0f13893b38c5fe46c315aeff46cb38d109055f59689663b6214b480b346fddf7009dc776f183abdd3b07e4ceb78477b769d5f0631b696f0f342d5541d224b4305b9b4c40e7f3809c958e8bdd"
PROJECT_ID="683a37a8003719978879"
DATABASE_ID="arena_db"
COLLECTION_ID="arena_rooms"

echo "🔍 Fetching current room state for: $ROOM_ID"
echo ""

# Get current room data
RESPONSE=$(curl -s -X GET \
  "https://cloud.appwrite.io/v1/databases/${DATABASE_ID}/collections/${COLLECTION_ID}/documents/${ROOM_ID}" \
  -H "X-Appwrite-Project: ${PROJECT_ID}" \
  -H "X-Appwrite-Key: ${API_KEY}" \
  -H "Content-Type: application/json")

echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print('Current room state:')
    print(f'  Topic: {data.get(\"topic\", \"N/A\")}')
    print(f'  Status: {data.get(\"status\", \"N/A\")}')
    print(f'  Winner: {data.get(\"winner\", \"NOT SET\")}')
    print(f'  ShowResults: {data.get(\"showResults\", \"NOT SET\")}')
    print(f'  JudgingComplete: {data.get(\"judgingComplete\", \"NOT SET\")}')
    print('')
except Exception as e:
    print(f'Error: {e}')
"

echo "🚀 Broadcasting results..."
echo "  Setting showResults = true"
echo "  Setting winner = $WINNER"
echo "  Setting judgingComplete = true"
echo ""

# Update room with showResults flag
curl -s -X PATCH \
  "https://cloud.appwrite.io/v1/databases/${DATABASE_ID}/collections/${COLLECTION_ID}/documents/${ROOM_ID}" \
  -H "X-Appwrite-Project: ${PROJECT_ID}" \
  -H "X-Appwrite-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"data\": {
      \"showResults\": true,
      \"winner\": \"$WINNER\",
      \"judgingComplete\": true
    }
  }" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if '\$id' in data:
        print('✅ Results broadcast sent!')
        print('')
        print('Updated values:')
        print(f'  ShowResults: {data.get(\"showResults\")}')
        print(f'  Winner: {data.get(\"winner\")}')
        print(f'  JudgingComplete: {data.get(\"judgingComplete\")}')
        print('')
        print('Check your app - the trophy icon should now appear in the bottom nav bar.')
        print('If it doesn\\'t appear, check the app logs for:')
        print('  - \"🏆 RESULTS STATE CHANGE DETECTED!\"')
        print('  - \"🏆 TROPHY ICON APPEARING!\"')
    else:
        print('❌ Error updating room:')
        print(json.dumps(data, indent=2))
except Exception as e:
    print(f'❌ Error: {e}')
    print(sys.stdin.read())
"
