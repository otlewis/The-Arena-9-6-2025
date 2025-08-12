#\!/bin/bash

# Create discussion_chat_messages collection
appwrite databases createCollection \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --name "Discussion Chat Messages" \
  --documentSecurity true \
  --enabled true

# Create attributes
appwrite databases createStringAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "roomId" \
  --size 255 \
  --required true

appwrite databases createStringAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "senderId" \
  --size 255 \
  --required true

appwrite databases createStringAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "senderName" \
  --size 255 \
  --required true

appwrite databases createStringAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "content" \
  --size 10000 \
  --required true

appwrite databases createDatetimeAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "timestamp" \
  --required true

appwrite databases createEnumAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "type" \
  --elements "text,image,video,voice,file,system,announcement" \
  --required true

appwrite databases createStringAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "senderAvatar" \
  --size 2048 \
  --required false

appwrite databases createStringAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "replyToId" \
  --size 255 \
  --required false

appwrite databases createStringAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "replyToContent" \
  --size 1000 \
  --required false

appwrite databases createStringAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "replyToSender" \
  --size 255 \
  --required false

appwrite databases createStringAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "reactions" \
  --size 2048 \
  --required false \
  --default "{}"

appwrite databases createStringAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "mentions" \
  --size 255 \
  --required false \
  --array true

appwrite databases createStringAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "attachments" \
  --size 2048 \
  --required false \
  --array true

appwrite databases createBooleanAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "isEdited" \
  --required false \
  --default false

appwrite databases createBooleanAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "isDeleted" \
  --required false \
  --default false

appwrite databases createDatetimeAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "editedAt" \
  --required false

appwrite databases createDatetimeAttribute \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "deletedAt" \
  --required false

# Create indexes
appwrite databases createIndex \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "roomId_timestamp" \
  --type "key" \
  --attributes "roomId,timestamp"

appwrite databases createIndex \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "senderId" \
  --type "key" \
  --attributes "senderId"

appwrite databases createIndex \
  --databaseId "your_database_id" \
  --collectionId "discussion_chat_messages" \
  --key "replyToId" \
  --type "key" \
  --attributes "replyToId"

echo "Collection created\! Now set permissions..."
echo "Run: appwrite databases updateCollection --databaseId your_database_id --collectionId discussion_chat_messages --permissions 'role:member' --enabled true"
