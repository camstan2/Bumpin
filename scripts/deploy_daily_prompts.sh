#!/bin/bash

# Daily Prompts Feature Deployment Script
# This script sets up Firebase indexes and deploys security rules for the Daily Prompts feature

set -e  # Exit on any error

echo "🚀 Deploying Daily Prompts Feature to Firebase..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install it first:"
    echo "npm install -g firebase-tools"
    exit 1
fi

# Check if we're in the correct directory
if [ ! -f "firebase.json" ]; then
    echo "❌ firebase.json not found. Please run this script from the project root."
    exit 1
fi

echo "📋 Creating Firestore indexes for Daily Prompts..."

# Create firestore.indexes.json with required indexes
cat > firestore.indexes.json << 'EOF'
{
  "indexes": [
    {
      "collectionGroup": "dailyPrompts",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "isActive", "order": "ASCENDING"},
        {"fieldPath": "isArchived", "order": "ASCENDING"},
        {"fieldPath": "date", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "dailyPrompts",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "category", "order": "ASCENDING"},
        {"fieldPath": "date", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "promptResponses",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "promptId", "order": "ASCENDING"},
        {"fieldPath": "isPublic", "order": "ASCENDING"},
        {"fieldPath": "submittedAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "promptResponses",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "promptId", "order": "ASCENDING"},
        {"fieldPath": "isHidden", "order": "ASCENDING"},
        {"fieldPath": "submittedAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "promptResponses",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "userId", "order": "ASCENDING"},
        {"fieldPath": "submittedAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "promptResponseLikes",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "responseId", "order": "ASCENDING"},
        {"fieldPath": "userId", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "promptResponseLikes",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "promptId", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "promptResponseComments",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "responseId", "order": "ASCENDING"},
        {"fieldPath": "isHidden", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "promptResponseComments",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "promptId", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "promptResponseCommentLikes",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "commentId", "order": "ASCENDING"},
        {"fieldPath": "userId", "order": "ASCENDING"}
      ]
    }
  ],
  "fieldOverrides": []
}
EOF

echo "✅ Created firestore.indexes.json"

# Deploy Firestore rules and indexes
echo "📤 Deploying Firestore rules and indexes..."
firebase deploy --only firestore

# Check deployment status
if [ $? -eq 0 ]; then
    echo "✅ Firestore rules and indexes deployed successfully!"
else
    echo "❌ Firestore deployment failed!"
    exit 1
fi

# Create initial prompt templates (optional)
echo "📝 Would you like to create initial prompt templates? (y/n)"
read -r create_templates

if [ "$create_templates" = "y" ] || [ "$create_templates" = "Y" ]; then
    echo "🎯 Creating initial prompt templates..."
    
    # This would typically be done through a Node.js script or admin panel
    # For now, we'll just provide instructions
    echo "📋 To create initial prompt templates:"
    echo "1. Use the admin interface (once created)"
    echo "2. Or run the template seeding script"
    echo "3. Templates will be automatically available from PromptTemplateLibrary"
fi

# Verify deployment
echo "🔍 Verifying deployment..."

# Check if indexes are being built
echo "⏳ Firestore indexes are being built. This may take several minutes."
echo "📊 You can monitor index status in the Firebase Console:"
echo "https://console.firebase.google.com/project/$(firebase use --current)/firestore/indexes"

echo ""
echo "🎉 Daily Prompts feature deployment complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Wait for Firestore indexes to finish building"
echo "2. Test the feature in your app"
echo "3. Create your first daily prompt using the admin tools"
echo "4. Monitor analytics for user engagement"
echo ""
echo "🔗 Useful Links:"
echo "- Firebase Console: https://console.firebase.google.com/project/$(firebase use --current)"
echo "- Firestore Rules: https://console.firebase.google.com/project/$(firebase use --current)/firestore/rules"
echo "- Firestore Indexes: https://console.firebase.google.com/project/$(firebase use --current)/firestore/indexes"
echo ""
echo "✨ Happy prompting!"
