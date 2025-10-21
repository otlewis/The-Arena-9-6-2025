import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  final client = Client()
      .setEndpoint('https://cloud.appwrite.io/v1')
      .setProject('683a37a8003719978879')
      .setKey('standard_a208ff4a370b36ef18f5827decfe8df2df923cd0f151b9caee106fd2bd8c7fe66fb597fead8e8cd3ca8c7ac3acf7bc55fa5d29db9d13d1aa2ab5e0c5af95fd48a29a8e6f8e8dfae3c1a0a0eac73d44b5629ee6a53e45fc1a1b3d66c5eb33c29f37bb21b311fa2b8bf8f137a1a0d7a20a3f77a51d7dc2c5c2da5c9f0ffcc59cd');

  final databases = Databases(client);

  print('Adding videoReady and audioReady attributes to debate_discussion_participants collection...\n');

  try {
    // Add videoReady attribute (boolean, default: false)
    print('📝 Creating videoReady attribute...');
    await databases.createBooleanAttribute(
      databaseId: 'arena_db',
      collectionId: 'debate_discussion_participants',
      key: 'videoReady',
      required: false,
      defaultValue: false,
    );
    print('✅ videoReady attribute created successfully\n');

    // Add audioReady attribute (boolean, default: false)
    print('📝 Creating audioReady attribute...');
    await databases.createBooleanAttribute(
      databaseId: 'arena_db',
      collectionId: 'debate_discussion_participants',
      key: 'audioReady',
      required: false,
      defaultValue: false,
    );
    print('✅ audioReady attribute created successfully\n');

    // Add videoTrackSid attribute (string, optional)
    print('📝 Creating videoTrackSid attribute...');
    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'debate_discussion_participants',
      key: 'videoTrackSid',
      size: 255,
      required: false,
    );
    print('✅ videoTrackSid attribute created successfully\n');

    // Add audioTrackSid attribute (string, optional)
    print('📝 Creating audioTrackSid attribute...');
    await databases.createStringAttribute(
      databaseId: 'arena_db',
      collectionId: 'debate_discussion_participants',
      key: 'audioTrackSid',
      size: 255,
      required: false,
    );
    print('✅ audioTrackSid attribute created successfully\n');

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🎉 All attributes created successfully!');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('\n⏳ Note: Attributes may take a few seconds to become available.');
    print('   Check the Appwrite console to confirm they are ready.');

  } catch (e) {
    if (e.toString().contains('Attribute already exists')) {
      print('ℹ️ Attributes already exist - nothing to do!');
    } else {
      print('❌ Error: $e');
    }
  }
}
