# Room Slide State Collection Setup

## Collection: room_slide_state

This collection stores the persistent slide data for each debate room to ensure slides remain available even when users close and reopen the materials panel.

### Collection Configuration

**Collection ID**: `room_slide_state`
**Name**: Room Slide State
**Permissions**: 
- Create: `users`
- Read: `users` 
- Update: `users`
- Delete: `users`

### Attributes

| Attribute Name | Type | Size | Required | Default | Array |
|---------------|------|------|----------|---------|-------|
| roomId | String | 255 | Yes | - | No |
| slideFileId | String | 255 | Yes | - | No |
| fileName | String | 255 | Yes | - | No |
| pdfUrl | String | 2000 | No | - | No |
| currentSlide | Integer | - | Yes | 1 | No |
| totalSlides | Integer | - | Yes | 0 | No |
| uploadedBy | String | 255 | Yes | - | No |
| updatedAt | String | 255 | Yes | - | No |

### Indexes

| Key | Type | Attributes |
|-----|------|------------|
| roomId_unique | Unique | roomId |
| roomId_index | Key | roomId |

### Usage

- **Document ID**: Uses roomId as the document ID to ensure one slide state per room
- **Persistence**: Slides persist until explicitly removed by the host
- **Auto-load**: When users open materials panel, slides automatically load from this collection
- **Real-time**: Updates when host changes slides or removes slides

### Setup Commands

Using Appwrite Console:
1. Go to Database > Collections
2. Create new collection with ID: `room_slide_state`  
3. Add the attributes listed above
4. Set the permissions as specified
5. Create the indexes

Using Appwrite CLI:
```bash
# Create collection
appwrite databases create-collection \
    --database-id "arena_db" \
    --collection-id "room_slide_state" \
    --name "Room Slide State" \
    --permissions "read(\"users\")" "create(\"users\")" "update(\"users\")" "delete(\"users\")"

# Add attributes (run these commands one by one)
appwrite databases create-string-attribute --database-id "arena_db" --collection-id "room_slide_state" --key "roomId" --size 255 --required true
appwrite databases create-string-attribute --database-id "arena_db" --collection-id "room_slide_state" --key "slideFileId" --size 255 --required true  
appwrite databases create-string-attribute --database-id "arena_db" --collection-id "room_slide_state" --key "fileName" --size 255 --required true
appwrite databases create-string-attribute --database-id "arena_db" --collection-id "room_slide_state" --key "pdfUrl" --size 2000 --required false
appwrite databases create-integer-attribute --database-id "arena_db" --collection-id "room_slide_state" --key "currentSlide" --required true --default 1
appwrite databases create-integer-attribute --database-id "arena_db" --collection-id "room_slide_state" --key "totalSlides" --required true --default 0
appwrite databases create-string-attribute --database-id "arena_db" --collection-id "room_slide_state" --key "uploadedBy" --size 255 --required true
appwrite databases create-string-attribute --database-id "arena_db" --collection-id "room_slide_state" --key "updatedAt" --size 255 --required true

# Create indexes
appwrite databases create-index --database-id "arena_db" --collection-id "room_slide_state" --key "roomId_unique" --type "unique" --attributes "roomId"
appwrite databases create-index --database-id "arena_db" --collection-id "room_slide_state" --key "roomId_index" --type "key" --attributes "roomId"
```