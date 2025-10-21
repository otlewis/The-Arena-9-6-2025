#!/bin/bash

# Add showResults attribute to arena_rooms collection

echo "Adding showResults attribute to arena_rooms collection..."

appwrite databases create-boolean-attribute \
  --database-id arena_db \
  --collection-id arena_rooms \
  --key showResults \
  --required false \
  --xdefault false

echo "✅ showResults attribute added successfully!"

echo ""
echo "Adding resultsAnnouncedAt attribute to arena_rooms collection..."

appwrite databases create-string-attribute \
  --database-id arena_db \
  --collection-id arena_rooms \
  --key resultsAnnouncedAt \
  --size 255 \
  --required false

echo "✅ resultsAnnouncedAt attribute added successfully!"
echo ""
echo "Done! You can now test the results bottom sheet."
