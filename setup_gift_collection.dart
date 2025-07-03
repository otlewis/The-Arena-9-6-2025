import 'package:appwrite/appwrite.dart';

void main() async {
  // Initialize Appwrite client
  final client = Client()
    ..setEndpoint('https://cloud.appwrite.io/v1')
    ..setProject('YOUR_PROJECT_ID') // Replace with your actual project ID
    ..setKey('YOUR_SERVER_API_KEY'); // Replace with your server API key

  final databases = Databases(client);

  try {
    print('🚀 Creating gift_transactions collection...');

    // Create the collection
    final collection = await databases.createCollection(
      databaseId: 'arena_db',
      collectionId: 'gift_transactions',
      name: 'Gift Transactions',
    );

    print('✅ Collection created: ${collection.name}');

    // Add attributes
    print('📝 Adding attributes...');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'gift_transactions',
      key: 'giftId',
      size: 100,
      required: true,
    );
    print('✅ Added giftId attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'gift_transactions',
      key: 'senderId',
      size: 100,
      required: true,
    );
    print('✅ Added senderId attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'gift_transactions',
      key: 'recipientId',
      size: 100,
      required: true,
    );
    print('✅ Added recipientId attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'gift_transactions',
      key: 'roomId',
      size: 100,
      required: true,
    );
    print('✅ Added roomId attribute');

    await databases.createIntegerAttribute(
      databaseId: 'arena_db',
      collectionId: 'gift_transactions',
      key: 'cost',
      required: true,
    );
    print('✅ Added cost attribute');

    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'gift_transactions',
      key: 'message',
      size: 500,
      required: false,
    );
    print('✅ Added message attribute');

    await databases.createDatetimeAttribute(
      databaseId: 'arena_db',
      collectionId: 'gift_transactions',
      key: 'sentAt',
      required: true,
    );
    print('✅ Added sentAt attribute');

    // Wait a moment for attributes to be created
    await Future.delayed(Duration(seconds: 2));

    // Create indexes
    print('📚 Creating indexes...');

    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'gift_transactions',
      key: 'roomId_index',
      type: 'key',
      attributes: ['roomId'],
    );
    print('✅ Created roomId index');

    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'gift_transactions',
      key: 'senderId_index',
      type: 'key',
      attributes: ['senderId'],
    );
    print('✅ Created senderId index');

    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'gift_transactions',
      key: 'recipientId_index',
      type: 'key',
      attributes: ['recipientId'],
    );
    print('✅ Created recipientId index');

    print('🎉 Gift transactions collection setup complete!');
    print('🎁 Your gift system is now ready to use!');

  } catch (e) {
    print('❌ Error setting up collection: $e');
  }
} 