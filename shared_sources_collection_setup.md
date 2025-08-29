# Shared Sources Collection Setup

## Collection: shared_sources

This collection stores the shared web sources/links for each debate room to support arguments with research materials.

### Collection Configuration

**Collection ID**: `shared_sources`
**Name**: Shared Sources
**Permissions**: 
- Create: `users`
- Read: `users` 
- Update: `users`
- Delete: `users`

### Attributes

| Attribute Name | Type | Size | Required | Default | Array |
|---------------|------|------|----------|---------|-------|
| roomId | String | 255 | Yes | - | No |
| url | String | 2000 | Yes | - | No |
| title | String | 255 | Yes | - | No |
| description | String | 1000 | No | - | No |
| sharedBy | String | 255 | Yes | - | No |
| sharedByName | String | 255 | No | - | No |
| sharedAt | String | 255 | Yes | - | No |

### Indexes

| Key | Type | Attributes |
|-----|------|------------|
| roomId_index | Key | roomId |
| roomId_sharedAt_index | Key | roomId, sharedAt |

### Usage

- **Sources**: Store web links with title and optional description
- **Room-based**: Each source is associated with a specific room
- **Persistence**: Sources persist throughout the room session
- **Real-time**: Sources are shared via LiveKit and saved to database
- **Attribution**: Track who shared each source

### Setup Commands

Using Appwrite Console:
1. Go to Database > Collections
2. Create new collection with ID: `shared_sources`  
3. Add the attributes listed above
4. Set the permissions as specified
5. Create the indexes

Using Appwrite CLI:
```bash
# Create collection
appwrite databases create-collection \
    --database-id "arena_db" \
    --collection-id "shared_sources" \
    --name "Shared Sources" \
    --permissions "read(\"users\")" "create(\"users\")" "update(\"users\")" "delete(\"users\")"

# Add attributes (run these commands one by one)
appwrite databases create-string-attribute --database-id "arena_db" --collection-id "shared_sources" --key "roomId" --size 255 --required true
appwrite databases create-string-attribute --database-id "arena_db" --collection-id "shared_sources" --key "url" --size 2000 --required true
appwrite databases create-string-attribute --database-id "arena_db" --collection-id "shared_sources" --key "title" --size 255 --required true
appwrite databases create-string-attribute --database-id "arena_db" --collection-id "shared_sources" --key "description" --size 1000 --required false
appwrite databases create-string-attribute --database-id "arena_db" --collection-id "shared_sources" --key "sharedBy" --size 255 --required true
appwrite databases create-string-attribute --database-id "arena_db" --collection-id "shared_sources" --key "sharedByName" --size 255 --required false
appwrite databases create-string-attribute --database-id "arena_db" --collection-id "shared_sources" --key "sharedAt" --size 255 --required true

# Create indexes
appwrite databases create-index --database-id "arena_db" --collection-id "shared_sources" --key "roomId_index" --type "key" --attributes "roomId"
appwrite databases create-index --database-id "arena_db" --collection-id "shared_sources" --key "roomId_sharedAt_index" --type "key" --attributes "roomId" "sharedAt"
```