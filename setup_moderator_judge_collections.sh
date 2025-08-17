#!/bin/bash

# Moderator and Judge Collections Setup Script for Arena App
# This script creates the moderator, judge, ping request, and rating collections in Appwrite

echo "Setting up Moderator and Judge Collections..."

# Configuration
PROJECT_ID="683a37a8003719978879"
DATABASE_ID="arena_db"

# Create moderators collection
echo "Creating moderators collection..."
appwrite databases create-collection \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --name "Moderators" \
    --permissions 'read("any")' 'write("users")' \
    --documentSecurity true

# Moderator attributes
appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "userId" \
    --size 255 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "username" \
    --size 255 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "displayName" \
    --size 255 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "avatar" \
    --size 500 \
    --required false

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "categories" \
    --size 1000 \
    --required true \
    --array true

appwrite databases create-boolean-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "isAvailable" \
    --required true \
    --default true

appwrite databases create-integer-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "totalModerated" \
    --required true \
    --default 0

appwrite databases create-float-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "rating" \
    --required true \
    --default 5.0

appwrite databases create-integer-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "ratingCount" \
    --required true \
    --default 0

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "bio" \
    --size 1000 \
    --required false

appwrite databases create-datetime-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "createdAt" \
    --required true

appwrite databases create-datetime-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "lastActive" \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "specializations" \
    --size 500 \
    --required false \
    --array true

appwrite databases create-integer-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "experienceYears" \
    --required false \
    --default 0

# Create judges collection
echo "Creating judges collection..."
appwrite databases create-collection \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --name "Judges" \
    --permissions 'read("any")' 'write("users")' \
    --documentSecurity true

# Judge attributes (similar to moderators but with totalJudged and certifications)
appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "userId" \
    --size 255 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "username" \
    --size 255 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "displayName" \
    --size 255 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "avatar" \
    --size 500 \
    --required false

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "categories" \
    --size 1000 \
    --required true \
    --array true

appwrite databases create-boolean-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "isAvailable" \
    --required true \
    --default true

appwrite databases create-integer-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "totalJudged" \
    --required true \
    --default 0

appwrite databases create-float-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "rating" \
    --required true \
    --default 5.0

appwrite databases create-integer-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "ratingCount" \
    --required true \
    --default 0

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "bio" \
    --size 1000 \
    --required false

appwrite databases create-datetime-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "createdAt" \
    --required true

appwrite databases create-datetime-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "lastActive" \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "specializations" \
    --size 500 \
    --required false \
    --array true

appwrite databases create-integer-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "experienceYears" \
    --required false \
    --default 0

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "certifications" \
    --size 500 \
    --required false \
    --array true

# Create ping_requests collection
echo "Creating ping_requests collection..."
appwrite databases create-collection \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --name "Ping Requests" \
    --permissions 'read("users")' 'write("users")' \
    --documentSecurity true

# Ping request attributes
appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "fromUserId" \
    --size 255 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "fromUsername" \
    --size 255 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "toUserId" \
    --size 255 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "toUsername" \
    --size 255 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "roleType" \
    --size 50 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "debateTitle" \
    --size 500 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "debateDescription" \
    --size 2000 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "category" \
    --size 100 \
    --required true

appwrite databases create-datetime-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "scheduledTime" \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "status" \
    --size 50 \
    --required true \
    --default "pending"

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "message" \
    --size 1000 \
    --required false

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "response" \
    --size 1000 \
    --required false

appwrite databases create-datetime-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "createdAt" \
    --required true

appwrite databases create-datetime-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "respondedAt" \
    --required false

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "arenaRoomId" \
    --size 255 \
    --required false

# Create moderator_judge_ratings collection
echo "Creating moderator_judge_ratings collection..."
appwrite databases create-collection \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderator_judge_ratings" \
    --name "Moderator Judge Ratings" \
    --permissions 'read("users")' 'write("users")' \
    --documentSecurity true

# Rating attributes
appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderator_judge_ratings" \
    --key "ratedUserId" \
    --size 255 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderator_judge_ratings" \
    --key "raterUserId" \
    --size 255 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderator_judge_ratings" \
    --key "raterUsername" \
    --size 255 \
    --required true

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderator_judge_ratings" \
    --key "roleType" \
    --size 50 \
    --required true

appwrite databases create-integer-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderator_judge_ratings" \
    --key "rating" \
    --required true \
    --min 1 \
    --max 5

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderator_judge_ratings" \
    --key "review" \
    --size 1000 \
    --required false

appwrite databases create-string-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderator_judge_ratings" \
    --key "arenaRoomId" \
    --size 255 \
    --required true

appwrite databases create-datetime-attribute \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderator_judge_ratings" \
    --key "createdAt" \
    --required true

# Create indexes
echo "Creating indexes..."

# Moderator indexes
appwrite databases create-index \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "userId_idx" \
    --type "key" \
    --attributes "userId"

appwrite databases create-index \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderators" \
    --key "available_rating_idx" \
    --type "key" \
    --attributes "isAvailable" "rating" \
    --orders "ASC" "DESC"

# Judge indexes
appwrite databases create-index \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "userId_idx" \
    --type "key" \
    --attributes "userId"

appwrite databases create-index \
    --databaseId "$DATABASE_ID" \
    --collectionId "judges" \
    --key "available_rating_idx" \
    --type "key" \
    --attributes "isAvailable" "rating" \
    --orders "ASC" "DESC"

# Ping request indexes
appwrite databases create-index \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "toUser_status_idx" \
    --type "key" \
    --attributes "toUserId" "status"

appwrite databases create-index \
    --databaseId "$DATABASE_ID" \
    --collectionId "ping_requests" \
    --key "fromUser_idx" \
    --type "key" \
    --attributes "fromUserId"

# Rating indexes
appwrite databases create-index \
    --databaseId "$DATABASE_ID" \
    --collectionId "moderator_judge_ratings" \
    --key "ratedUser_role_idx" \
    --type "key" \
    --attributes "ratedUserId" "roleType"

echo "Moderator and Judge collections setup complete!"
echo ""
echo "Collections created:"
echo "  - moderators"
echo "  - judges" 
echo "  - ping_requests"
echo "  - moderator_judge_ratings"
echo ""
echo "Features:"
echo "  - Community-driven moderation system"
echo "  - Category-based filtering"
echo "  - Ping system for requesting moderators/judges"
echo "  - Rating and review system"