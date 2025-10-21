// Migration script to add versioning fields to existing arena_participants documents
// This ensures all old participant records have version, updatedAt, and livekitSynced fields
//
// Usage: dart run scripts/migrate_arena_participants_versioning.dart

import 'dart:io';
import 'package:appwrite/appwrite.dart';

void main() async {
  print('🔄 Starting arena_participants migration to add versioning fields...\n');

  // Check for API key
  const apiKey = 'standard_a4a4e8b68621469710dbd7dd2ff8efe9685bb6256812eff9ce5599a5cc88f5ba091c787aae6eee94e75bf30403008aaa6cba47de6b1bbe5450d259e1806672ef35cbdd02f7bb6ccf07e020404b52cac9d12acdfb5df8732a596452a7d99e762eb9cfd63dc0f4c487ea4295850aa0f3e6da188f2cc8068c12699c2bbd27034a93';

  // Initialize Appwrite client
  final client = Client()
      .setEndpoint('https://cloud.appwrite.io/v1')
      .setProject('67509dcf00195afbc92f')
      .setKey(apiKey)
      .setSelfSigned(status: true); // Allow self-signed certificates

  final databases = Databases(client);

  try {
    // Step 1: Fetch all arena_participants documents
    print('📋 Fetching all arena_participants documents...');

    int total = 0;
    int updated = 0;
    int skipped = 0;
    int failed = 0;
    String? cursor;

    do {
      final response = await databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        queries: cursor != null ? ['cursorAfter("$cursor")'] : [],
      );

      print('Fetched ${response.documents.length} documents in this batch...');

      for (final doc in response.documents) {
        total++;

        final docId = doc.$id;
        final data = doc.data;

        // Check if document already has versioning fields
        final hasVersion = data.containsKey('version');
        final hasUpdatedAt = data.containsKey('updatedAt');
        final hasLivekitSynced = data.containsKey('livekitSynced');

        if (hasVersion && hasUpdatedAt && hasLivekitSynced) {
          print('⏭️  Skipping $docId (already has versioning fields)');
          skipped++;
          continue;
        }

        try {
          // Update document with versioning fields
          final now = DateTime.now().toUtc().toIso8601String();

          final updateData = <String, dynamic>{};

          if (!hasVersion) {
            updateData['version'] = 1; // Start all old documents at version 1
          }

          if (!hasUpdatedAt) {
            updateData['updatedAt'] = now;
          }

          if (!hasLivekitSynced) {
            updateData['livekitSynced'] = true; // Assume old documents are synced
          }

          await databases.updateDocument(
            databaseId: 'arena_db',
            collectionId: 'arena_participants',
            documentId: docId,
            data: updateData,
          );

          print('✅ Updated $docId with ${updateData.keys.join(", ")}');
          updated++;
        } catch (e) {
          print('❌ Failed to update $docId: $e');
          failed++;
        }
      }

      // Update cursor for pagination
      cursor = response.documents.isNotEmpty
          ? response.documents.last.$id
          : null;

    } while (cursor != null);

    // Print summary
    print('\n' + '=' * 60);
    print('📊 Migration Summary');
    print('=' * 60);
    print('Total documents processed: $total');
    print('✅ Successfully updated: $updated');
    print('⏭️  Skipped (already migrated): $skipped');
    print('❌ Failed: $failed');
    print('=' * 60);

    if (failed > 0) {
      print('\n⚠️  Some documents failed to migrate. Review errors above.');
      exit(1);
    } else {
      print('\n🎉 Migration completed successfully!');
    }

  } catch (e) {
    print('\n❌ Migration failed with error: $e');
    exit(1);
  }
}
