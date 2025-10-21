// @dart=2.17
// ignore_for_file: unused_import, undefined_identifier, undefined_function
// This is a utility script, not part of the main app.
// To use: Install dart_appwrite package separately and uncomment the import below.
// import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  // Check if user is super moderator
  // Note: This script requires dart_appwrite (server SDK) instead of appwrite (client SDK)
  // Run: dart pub add dart_appwrite (in a separate test project)
  // Then uncomment the import and code below.

  /* Uncomment to use with dart_appwrite:
  final client = Client()
    .setEndpoint('https://cloud.appwrite.io/v1')
    .setProject('683a37a8003719978879')
    .setKey('YOUR_API_KEY'); // Need API key from Appwrite Console

  final databases = Databases(client);

  try {
    final result = await databases.listDocuments(
      databaseId: 'arena_db',
      collectionId: 'super_moderators',
      queries: [
        Query.equal('isActive', true),
      ],
    );

    print('Super Moderators:');
    for (final doc in result.documents) {
      print('- ${doc.data['username']} (${doc.data['userId']})');
    }
  } catch (e) {
    print('Error: $e');
  }
  */

  print('This script is commented out. See instructions above to use it.');
}
