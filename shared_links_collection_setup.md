# Shared Links Collection Setup

This document explains how to set up the `shared_links` collection in Appwrite for the Arena link sharing system.

## Collection Details

**Collection ID**: `shared_links`
**Database**: `arena_db`

## Attributes to Create

1. **roomId** (string, required)
   - Size limit: 255 characters
   - Used to associate links with specific debate rooms

2. **url** (string, required)
   - Size limit: 2000 characters
   - The actual URL being shared

3. **title** (string, optional)
   - Size limit: 255 characters
   - Display title for the link

4. **description** (string, optional)
   - Size limit: 500 characters
   - Optional description of the link content

5. **sharedBy** (string, required)
   - Size limit: 255 characters
   - User ID who shared the link

6. **sharedByName** (string, required)
   - Size limit: 255 characters
   - Display name of the user who shared the link

7. **sharedAt** (datetime, required)
   - Timestamp when the link was shared

8. **isActive** (boolean, required, default: true)
   - Whether the link is currently active/visible

9. **type** (string, required, default: "link")
   - Size limit: 50 characters
   - Type of content: 'video', 'docs', 'code', 'image', 'link'

## Indexes to Create

1. **roomId_active** (compound index)
   - Fields: `roomId` (ASC), `isActive` (ASC)
   - For efficiently querying active links in a room

2. **sharedAt** (single field index)
   - Field: `sharedAt` (DESC)
   - For ordering links by newest first

3. **sharedBy** (single field index)
   - Field: `sharedBy` (ASC)
   - For user-specific queries

## Permissions

Set the following permissions on the collection:

**Read**: 
- `any()` - Anyone can read shared links

**Create**: 
- `users` - Only authenticated users can create links

**Update**: 
- `users` - Users can update their own links (handled by document-level permissions)

**Delete**: 
- `users` - Users can delete their own links (handled by document-level permissions)

## Document-Level Permissions

When creating documents, the app sets permissions so:
- Anyone can read the shared link
- Only the creator can update/delete their link

## Setting Up via Appwrite Console

1. Go to your Appwrite Console
2. Navigate to Database → `arena_db`
3. Create new collection with ID `shared_links`
4. Add all the attributes listed above
5. Create the indexes as specified
6. Set collection permissions as outlined
7. Test by creating a sample document

## Usage in App

The SharedLinksService handles all CRUD operations for this collection:

```dart
// Share a link
await sharedLinksService.shareLink(
  roomId: 'room_123',
  url: 'https://example.com',
  title: 'Example Link',
);

// Subscribe to real-time updates
sharedLinksService.subscribeToSharedLinks('room_123');

// Remove a link
await sharedLinksService.deactivateLink(linkId);
```