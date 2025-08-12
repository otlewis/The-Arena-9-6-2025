# Instant Messages Collection Setup

## Create the Collection
```bash
appwrite databases createCollection \
    --databaseId arena_db \
    --collectionId instant_messages \
    --name "Instant Messages" \
    --permissions 'read("users")' 'write("users")'
```

## Create Attributes
```bash
# Sender ID
appwrite databases createStringAttribute \
    --databaseId arena_db \
    --collectionId instant_messages \
    --key senderId \
    --size 255 \
    --required true

# Receiver ID  
appwrite databases createStringAttribute \
    --databaseId arena_db \
    --collectionId instant_messages \
    --key receiverId \
    --size 255 \
    --required true

# Message content
appwrite databases createStringAttribute \
    --databaseId arena_db \
    --collectionId instant_messages \
    --key content \
    --size 2000 \
    --required true

# Conversation ID
appwrite databases createStringAttribute \
    --databaseId arena_db \
    --collectionId instant_messages \
    --key conversationId \
    --size 255 \
    --required true

# Sender username
appwrite databases createStringAttribute \
    --databaseId arena_db \
    --collectionId instant_messages \
    --key senderUsername \
    --size 255 \
    --required true

# Sender avatar URL
appwrite databases createStringAttribute \
    --databaseId arena_db \
    --collectionId instant_messages \
    --key senderAvatar \
    --size 500 \
    --required false

# Read status
appwrite databases createBooleanAttribute \
    --databaseId arena_db \
    --collectionId instant_messages \
    --key isRead \
    --required true \
    --default false

# Timestamp
appwrite databases createDatetimeAttribute \
    --databaseId arena_db \
    --collectionId instant_messages \
    --key timestamp \
    --required true
```

## Create Indexes
```bash
# Index by sender
appwrite databases createIndex \
    --databaseId arena_db \
    --collectionId instant_messages \
    --key senderId_index \
    --type key \
    --attributes senderId

# Index by receiver
appwrite databases createIndex \
    --databaseId arena_db \
    --collectionId instant_messages \
    --key receiverId_index \
    --type key \
    --attributes receiverId

# Index by conversation
appwrite databases createIndex \
    --databaseId arena_db \
    --collectionId instant_messages \
    --key conversationId_index \
    --type key \
    --attributes conversationId

# Index for unread messages
appwrite databases createIndex \
    --databaseId arena_db \
    --collectionId instant_messages \
    --key unread_messages_index \
    --type key \
    --attributes receiverId,isRead

# Index by timestamp for ordering
appwrite databases createIndex \
    --databaseId arena_db \
    --collectionId instant_messages \
    --key timestamp_index \
    --type key \
    --attributes timestamp \
    --orders DESC
```

## Verify Collection
```bash
appwrite databases listCollections --databaseId arena_db
appwrite databases getCollection --databaseId arena_db --collectionId instant_messages
```