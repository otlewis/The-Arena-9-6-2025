import 'dart:io';
import 'package:appwrite/appwrite.dart';

/// Quick script to check super moderator status
void main() async {
  print('🔍 Checking Super Moderator Status\n');

  // Initialize Appwrite
  final client = Client()
      .setEndpoint('https://cloud.appwrite.io/v1')
      .setProject('arena-dtd')
      .setKey(Platform.environment['APPWRITE_API_KEY'] ?? '');

  final databases = Databases(client);

  try {
    // List all active super moderators
    print('📋 Listing all active super moderators...\n');

    final response = await databases.listDocuments(
      databaseId: 'arena_db',
      collectionId: 'super_moderators',
      queries: [
        Query.equal('isActive', true),
      ],
    );

    if (response.documents.isEmpty) {
      print('❌ No active super moderators found in database\n');
      print('To add a super moderator, you need to:');
      print('1. Go to Appwrite Console');
      print('2. Navigate to arena_db > super_moderators collection');
      print('3. Create a document with:');
      print('   - userId: <your user ID>');
      print('   - username: <your username>');
      print('   - isActive: true');
      print('   - permissions: ["manage_users", "timeout_users", "kick_users", "ban_users", "assign_roles"]');
      print('   - grantedAt: <current timestamp>');
      print('   - grantedBy: "admin"');
    } else {
      print('✅ Found ${response.documents.length} active super moderators:\n');

      for (final doc in response.documents) {
        final data = doc.data;
        print('---');
        print('ID: ${doc.$id}');
        print('User ID: ${data['userId']}');
        print('Username: ${data['username']}');
        print('Permissions: ${data['permissions']}');
        print('Granted At: ${data['grantedAt']}');
        print('Granted By: ${data['grantedBy']}');
        print('Is Active: ${data['isActive']}');
        print('---\n');
      }
    }

    // Also check the hardcoded user
    print('ℹ️ Hardcoded super moderator in code: 6843c3781d2c1c7154a0 (Kritik)');

  } catch (e) {
    print('❌ Error: $e');
    print('\nMake sure to set APPWRITE_API_KEY environment variable');
  }
}
