import 'package:appwrite/appwrite.dart';

void main() async {
  final client = Client()
      .setEndpoint('https://fra.cloud.appwrite.io/v1')
      .setProject('683a37a8003719978879')
      .setKey('standard_9eb533155b87619154f399a46a8edcc321b0076b56a37767075b8b8b254edc6328abb380594edfab634ee531470e84773d6bf5951295ad1687c82e258da45758f3c4ff0101b4217cb828723f1b4acac507f092afe799f8548b2e1de14e1028dc8459fcd32387ef74b8de8a505f90cc03a2958d69b020ca74ab6481ec8411f3e3');

  final databases = Databases(client);

  try {
    // Get the timer document
    final doc = await databases.getDocument(
      databaseId: 'arena_db',
      collectionId: 'timers',
      documentId: '68e82c6d644eff2ddb4a',
    );

    print('Timer document:');
    print('Status: ${doc.data['status']}');
    print('Duration: ${doc.data['durationSeconds']}');
    print('StartTime: ${doc.data['startTime']}');
    print('PausedAt: ${doc.data['pausedAt']}');
    print('All fields: ${doc.data}');

    // Delete the document
    print('\nDeleting timer document...');
    await databases.deleteDocument(
      databaseId: 'arena_db',
      collectionId: 'timers',
      documentId: '68e82c6d644eff2ddb4a',
    );
    print('Timer deleted successfully!');
  } catch (e) {
    print('Error: $e');
  }
}
