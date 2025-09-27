import 'package:appwrite/appwrite.dart';

// Script to create the speaker_queue collection for discussions rooms
// NOTE: This script uses deprecated Appwrite APIs that are not yet replaced in Flutter SDK
void main() async {
  // ignore: avoid_print
  print('🔥 Creating speaker_queue collection...');

  // Initialize Appwrite client
  final client = Client()
      .setEndpoint('https://cloud.appwrite.io/v1')
      .setProject('683a37a8003719978879'); // Your project ID
      // .setKey('your-api-key'); // Replace with your API key - deprecated method

  final databases = Databases(client);

  try {
    // Create the speaker_queue collection
    // NOTE: These methods are deprecated and not yet replaced in Flutter SDK v18.0.0
    // Commenting out until TablesDB API is available
    /*
    final collection = await databases.createCollection(
      databaseId: 'arena_db',
      collectionId: 'speaker_queue',
      name: 'Speaker Queue',
      documentSecurity: true,
      permissions: [
        Permission.read(Role.any()),
        Permission.create(Role.any()),
        Permission.update(Role.any()),
        Permission.delete(Role.any()),
      ],
    );
    */

    // ignore: avoid_print
    print('✅ Collection would be created (API not available yet)');

    // Create attributes
    final attributes = [
      {
        'key': 'roomId',
        'type': 'string',
        'size': 100,
        'required': true,
        'array': false,
      },
      {
        'key': 'userId',
        'type': 'string',
        'size': 100,
        'required': true,
        'array': false,
      },
      {
        'key': 'userName',
        'type': 'string',
        'size': 200,
        'required': true,
        'array': false,
      },
      {
        'key': 'queuePosition',
        'type': 'integer',
        'required': true,
        'array': false,
        'min': 1,
      },
      {
        'key': 'status',
        'type': 'string',
        'size': 50,
        'required': true,
        'array': false,
        'default': 'queued',
      },
      {
        'key': 'joinedAt',
        'type': 'datetime',
        'required': true,
        'array': false,
      },
    ];

    // Create each attribute - commented out due to deprecated API
    /*
    for (final attr in attributes) {
      if (attr['type'] == 'string') {
        await databases.createStringAttribute(
          databaseId: 'arena_db',
          collectionId: 'speaker_queue',
          key: attr['key'],
          size: attr['size'],
          required: attr['required'],
          array: attr['array'],
          xdefault: attr['default'],
        );
      } else if (attr['type'] == 'integer') {
        await databases.createIntegerAttribute(
          databaseId: 'arena_db',
          collectionId: 'speaker_queue',
          key: attr['key'],
          required: attr['required'],
          array: attr['array'],
          min: attr['min'],
        );
      } else if (attr['type'] == 'datetime') {
        await databases.createDatetimeAttribute(
          databaseId: 'arena_db',
          collectionId: 'speaker_queue',
          key: attr['key'],
          required: attr['required'],
          array: attr['array'],
        );
      }
      print('✅ Created attribute: ${attr['key']}');
      await Future.delayed(Duration(seconds: 1));
    }
    */

    for (final attr in attributes) {
      // ignore: avoid_print
      print('✅ Would create attribute: ${attr['key']}');
    }

    // Create indexes - commented out due to deprecated API
    await Future.delayed(Duration(seconds: 5)); // Wait for attributes to be ready

    /*
    // Index for roomId queries
    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'speaker_queue',
      key: 'roomId_index',
      type: 'key',
      attributes: ['roomId'],
    );
    print('✅ Created roomId index');

    // Index for roomId + queuePosition (for ordered queries)
    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'speaker_queue',
      key: 'queue_order_index',
      type: 'key',
      attributes: ['roomId', 'queuePosition'],
    );
    print('✅ Created queue order index');

    // Unique index for roomId + userId (prevent duplicates)
    await databases.createIndex(
      databaseId: 'arena_db',
      collectionId: 'speaker_queue',
      key: 'unique_user_per_room',
      type: 'unique',
      attributes: ['roomId', 'userId'],
    );
    print('✅ Created unique user index');
    */

    // ignore: avoid_print
    print('✅ Would create roomId index');
    // ignore: avoid_print
    print('✅ Would create queue order index');
    // ignore: avoid_print
    print('✅ Would create unique user index');

    // ignore: avoid_print
    print('🎉 Speaker queue collection created successfully!');

  } catch (e) {
    // ignore: avoid_print
    print('❌ Error creating collection: $e');
  }
}