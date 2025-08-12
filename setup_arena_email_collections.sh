#!/bin/bash

# Setup Arena Email Collections Script
# This script creates the necessary collections for the Arena email system

echo "🚀 Setting up Arena Email Collections..."

# Check if appwrite CLI is installed
if ! command -v appwrite &> /dev/null; then
    echo "❌ Appwrite CLI is not installed. Please install it first:"
    echo "npm install -g appwrite-cli"
    exit 1
fi

# Get current project info
echo "📋 Getting current project info..."
PROJECT_ID="683a37a8003719978879"
echo "Using project ID: $PROJECT_ID"

DATABASE_ID="arena_db"

echo "📧 Creating arena_emails collection..."

# Create arena_emails collection
appwrite databases create-collection \
    --database-id "$DATABASE_ID" \
    --collection-id "arena_emails" \
    --name "Arena Emails" \
    --document-security true

if [ $? -eq 0 ]; then
    echo "✅ arena_emails collection created successfully"
else
    echo "❌ Failed to create arena_emails collection"
    exit 1
fi

# Add attributes to arena_emails
echo "🔧 Adding attributes to arena_emails..."

# String attributes
appwrite databases create-string-attribute --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "senderId" --size 255 --required true
appwrite databases create-string-attribute --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "recipientId" --size 255 --required true
appwrite databases create-string-attribute --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "senderUsername" --size 255 --required true
appwrite databases create-string-attribute --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "recipientUsername" --size 255 --required true
appwrite databases create-string-attribute --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "subject" --size 500 --required true
appwrite databases create-string-attribute --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "body" --size 10000 --required true
appwrite databases create-string-attribute --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "emailType" --size 50 --required true --default "personal"
appwrite databases create-string-attribute --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "threadId" --size 255 --required false

# Boolean attributes
appwrite databases create-boolean-attribute --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "isRead" --required true --default false
appwrite databases create-boolean-attribute --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "isStarred" --required true --default false
appwrite databases create-boolean-attribute --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "isArchived" --required true --default false

# DateTime attribute
appwrite databases create-datetime-attribute --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "createdAt" --required true

echo "⏳ Waiting for attributes to be created..."
sleep 10

# Create indexes for arena_emails
echo "📊 Creating indexes for arena_emails..."
appwrite databases create-index --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "senderId_idx" --type "key" --attributes "senderId"
appwrite databases create-index --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "recipientId_idx" --type "key" --attributes "recipientId"
appwrite databases create-index --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "emailType_idx" --type "key" --attributes "emailType"
appwrite databases create-index --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "createdAt_idx" --type "key" --attributes "createdAt"
appwrite databases create-index --database-id "$DATABASE_ID" --collection-id "arena_emails" --key "unread_emails_idx" --type "key" --attributes "recipientId,isRead"

echo "📝 Creating email_templates collection..."

# Create email_templates collection
appwrite databases create-collection \
    --database-id "$DATABASE_ID" \
    --collection-id "email_templates" \
    --name "Email Templates" \
    --document-security false

if [ $? -eq 0 ]; then
    echo "✅ email_templates collection created successfully"
else
    echo "❌ Failed to create email_templates collection"
    exit 1
fi

# Add attributes to email_templates
echo "🔧 Adding attributes to email_templates..."

appwrite databases create-string-attribute --database-id "$DATABASE_ID" --collection-id "email_templates" --key "templateType" --size 100 --required true
appwrite databases create-string-attribute --database-id "$DATABASE_ID" --collection-id "email_templates" --key "subject" --size 500 --required true
appwrite databases create-string-attribute --database-id "$DATABASE_ID" --collection-id "email_templates" --key "bodyTemplate" --size 10000 --required true

echo "⏳ Waiting for attributes to be created..."
sleep 8

# Create index for email_templates
echo "📊 Creating indexes for email_templates..."
appwrite databases create-index --database-id "$DATABASE_ID" --collection-id "email_templates" --key "templateType_idx" --type "key" --attributes "templateType"

echo "📧 Adding default email templates..."

# Add challenge template
appwrite databases create-document \
    --database-id "$DATABASE_ID" \
    --collection-id "email_templates" \
    --document-id "challenge_template" \
    --data '{
        "templateType": "challenge",
        "subject": "Debate Challenge from {{senderName}}",
        "bodyTemplate": "Hello {{recipientName}},\n\nI challenge you to a debate on the topic: \"{{topic}}\"\n\nProposed format: {{format}}\nProposed time: {{time}}\n\nDo you accept this challenge?\n\nBest regards,\n{{senderName}}"
    }'

# Add results template
appwrite databases create-document \
    --database-id "$DATABASE_ID" \
    --collection-id "email_templates" \
    --document-id "results_template" \
    --data '{
        "templateType": "results",
        "subject": "Debate Results: {{topic}}",
        "bodyTemplate": "Congratulations on completing your debate!\n\nTopic: {{topic}}\nDate: {{date}}\nWinner: {{winner}}\n\nScores:\n{{scores}}\n\nJudge Feedback:\n{{feedback}}\n\nThank you for participating in The Arena!"
    }'

# Add rematch template
appwrite databases create-document \
    --database-id "$DATABASE_ID" \
    --collection-id "email_templates" \
    --document-id "rematch_template" \
    --data '{
        "templateType": "rematch",
        "subject": "Rematch Request from {{senderName}}",
        "bodyTemplate": "Hello {{recipientName}},\n\nGreat debate on \"{{topic}}\"!\n\nI would like to challenge you to a rematch. Are you interested?\n\n{{message}}\n\nBest regards,\n{{senderName}}"
    }'

# Add feedback template
appwrite databases create-document \
    --database-id "$DATABASE_ID" \
    --collection-id "email_templates" \
    --document-id "feedback_template" \
    --data '{
        "templateType": "feedback",
        "subject": "Judge Feedback on Your Debate",
        "bodyTemplate": "Dear {{recipientName}},\n\nHere is the detailed feedback from the judges on your recent debate:\n\nTopic: {{topic}}\n\n{{feedbackContent}}\n\nKeep up the great work!\n\nThe Arena Team"
    }'

echo "✅ Email collections setup completed successfully!"
echo ""
echo "📋 Summary:"
echo "  ✅ arena_emails collection created with all attributes and indexes"
echo "  ✅ email_templates collection created with all attributes and indexes"
echo "  ✅ Default email templates added (challenge, results, rematch, feedback)"
echo ""
echo "🎉 Arena email system is now ready to use!"