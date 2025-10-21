#!/bin/bash

echo "Creating arena_notifications collection..."

# Create the collection
appwrite databases create-collection \
  --database-id arena_db \
  --collection-id arena_notifications \
  --name "Arena Notifications" \
  --permissions 'read("any")' 'create("users")' 'update("users")' 'delete("users")'

echo "✅ Collection created!"
echo ""
echo "Adding attributes..."

# roomId - which arena room this notification is for
appwrite databases create-string-attribute \
  --database-id arena_db \
  --collection-id arena_notifications \
  --key roomId \
  --size 255 \
  --required true

# type - type of notification (e.g., 'results_ready', 'voting_complete', etc.)
appwrite databases create-string-attribute \
  --database-id arena_db \
  --collection-id arena_notifications \
  --key type \
  --size 100 \
  --required true

# data - JSON string with notification data
appwrite databases create-string-attribute \
  --database-id arena_db \
  --collection-id arena_notifications \
  --key data \
  --size 10000 \
  --required false

echo "✅ Attributes added!"
echo ""
echo "Creating index on roomId..."

# Index on roomId for fast lookups
appwrite databases create-index \
  --database-id arena_db \
  --collection-id arena_notifications \
  --key idx_roomId \
  --type key \
  --attributes roomId

echo "✅ Index created!"
echo ""
echo "Done! Arena notifications collection is ready."
