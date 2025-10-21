import 'dart:io';
// import 'package:appwrite/appwrite.dart';  // Unused - commented out

// NOTE: This file contains database setup methods that are not available in the client-side Appwrite SDK
// These methods (createStringAttribute, createDatetimeAttribute, etc.) are only available in server-side SDKs
// Database schema should be set up through the Appwrite Console instead
// This file is commented out to prevent compilation errors

void main() async {
  // print('⚠️  This setup script is disabled - use Appwrite Console for database schema setup');
  // print('Database schema methods are not available in client-side SDK');
  exit(0);
  
  /*
  // Initialize Appwrite client
  final client = Client()
    ..setEndpoint('https://cloud.appwrite.io/v1')
    ..setProject('arena-flutter')
    ..setKey('standard_00d440e0d9e7f53faaccdfac1ecfe49e4c0b30f2c4770b75a5cbaba5ea6375ea2d6e68483697726bfe1b8d67d8c8bb447ff97fce0f13893b38c5fe46c315aeff46cb38d109055f59689663b6214b480b346fddf7009dc776f183abdd3b07e4ceb78477b769d5f0631b696f0f342d5541d224b4305b9b4c40e7f3809c958e8bdd');

  final databases = Databases(client);

  try {
    print('🚀 Creating messages collection...');

    // Create the collection
    final collection = await databases.createCollection(
      databaseId: 'arena_db',
      collectionId: 'messages',
      name: 'Messages',
    );

    print('✅ Collection created: ${collection.name}');

    // Add attributes
    print('📝 Adding attributes...');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'roomId',
      size: 100,
      required: true,
    );
    print('✅ Added roomId attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'senderId',
      size: 100,
      required: true,
    );
    print('✅ Added senderId attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'senderName',
      size: 200,
      required: true,
    );
    print('✅ Added senderName attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'senderAvatar',
      size: 500,
      required: false,
    );
    print('✅ Added senderAvatar attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'type',
      size: 50,
      required: true,
      default: 'text',
    );
    print('✅ Added type attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'content',
      size: 2000,
      required: true,
    );
    print('✅ Added content attribute');

    await databases.createDatetimeAttribute(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'timestamp',
      required: true,
    );
    print('✅ Added timestamp attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'replyToMessageId',
      size: 100,
      required: false,
    );
    print('✅ Added replyToMessageId attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'mentions',
      size: 1000,
      required: false,
      array: true,
    );
    print('✅ Added mentions attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'metadata',
      size: 2000,
      required: false,
    );
    print('✅ Added metadata attribute');

    await databases.createBooleanAttribute(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'isEdited',
      required: false,
      default: false,
    );
    print('✅ Added isEdited attribute');

    await databases.createDatetimeAttribute(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'editedAt',
      required: false,
    );
    print('✅ Added editedAt attribute');

    await databases.createBooleanAttribute(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'isDeleted',
      required: false,
      default: false,
    );
    print('✅ Added isDeleted attribute');

    // Wait a moment for attributes to be created
    await Future.delayed(Duration(seconds: 3));

    // Create indexes
    print('📚 Creating indexes...');

    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'roomId_index',
      type: 'key',
      attributes: ['roomId'],
    );
    print('✅ Created roomId index');

    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'senderId_index',
      type: 'key',
      attributes: ['senderId'],
    );
    print('✅ Created senderId index');

    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'timestamp_index',
      type: 'key',
      attributes: ['timestamp'],
      orders: ['DESC'],
    );
    print('✅ Created timestamp index');

    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'messages',
      key: 'room_timestamp_index',
      type: 'key',
      attributes: ['roomId', 'timestamp'],
      orders: ['ASC', 'DESC'],
    );
    print('✅ Created room_timestamp compound index');

    print('🎉 Messages collection setup complete!');
    print('💬 Your chat system is now ready to use!');
    print('');
    print('Next steps:');
    print('1. Update permissions in Appwrite console');
    print('2. Test sending messages in your app');
    print('3. Enjoy your modern chat system! 🚀');

    exit(0);

  } catch (e) {
    print('❌ Error setting up collection: $e');
    print('');
    print('Note: If you get a "Collection already exists" error, that\'s fine!');
    print('The collection might already be created. You can check in your Appwrite console.');
    exit(1);
  }
  */
} 