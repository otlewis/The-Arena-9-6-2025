#!/bin/bash

# Test script to manually trigger the navigation system
# This simulates what happens when a challenge is accepted

echo "🧪 Testing Arena Challenge Navigation System"
echo ""
echo "This will manually trigger the n8n workflow to test the navigation system."
echo ""
echo "Prerequisites:"
echo "  - Two users must be logged in on different devices/browsers"
echo "  - A challenge must have been accepted (to get real IDs)"
echo ""
read -p "Do you have a recent accepted challenge? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please accept a challenge first, then run this script again."
    exit 1
fi

echo ""
echo "Enter the challenge details (you can find these in Appwrite Console):"
echo ""
read -p "Challenge ID: " CHALLENGE_ID
read -p "Arena Room ID: " ARENA_ROOM_ID
read -p "Challenger User ID: " CHALLENGER_ID
read -p "Challenged User ID: " CHALLENGED_ID
read -p "Topic: " TOPIC

echo ""
echo "📡 Sending request to n8n workflow..."
echo ""

curl -X POST http://50.218.7.76/webhook/arena-challenge-accepted \
  -H "Content-Type: application/json" \
  -d "{
    \"events\": [\"databases.arena_db.collections.challenge_messages.documents.update\"],
    \"status\": \"accepted\",
    \"arenaRoomId\": \"$ARENA_ROOM_ID\",
    \"\$id\": \"$CHALLENGE_ID\",
    \"challengerId\": \"$CHALLENGER_ID\",
    \"challengedId\": \"$CHALLENGED_ID\",
    \"topic\": \"$TOPIC\",
    \"description\": \"Manual test\"
  }"

echo ""
echo ""
echo "✅ Request sent!"
echo ""
echo "Now check:"
echo "  1. n8n Executions tab - should show a new execution"
echo "  2. Appwrite arena_navigation_notifications collection - should have 2 new documents"
echo "  3. Both Flutter apps - should show navigation notification logs (🎯)"
echo "  4. Both users should navigate to the Arena!"
echo ""
