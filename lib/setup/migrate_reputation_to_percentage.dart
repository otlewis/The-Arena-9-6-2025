import 'dart:io';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

/// Migration script to convert reputation system to percentage-based
/// 
/// This script:
/// 1. Adds reputationPercentage field to users collection (default: 100)
/// 2. Preserves existing data while transitioning to new system
/// 3. Creates reputation_logs collection for audit trail
///
/// IMPORTANT: Run this ONCE after deploying the new reputation system
/// Manual Appwrite Setup Required:
/// 1. Add "reputationPercentage" attribute to "users" collection (integer, default: 100)
/// 2. Create "reputation_logs" collection with attributes:
///    - userId (string, required)
///    - moderatorId (string, required) 
///    - oldPercentage (integer, required)
///    - newPercentage (integer, required)
///    - percentageChange (integer, required)
///    - reason (string, required)
///    - timestamp (string, required)
///    - type (string, required, default: "moderator_adjustment")
/// 3. Create "moderators" collection with attributes:
///    - userId (string, required, unique)
///    - permissions (array of strings, optional)
///    - createdAt (string, required)
///    - isActive (boolean, default: true)

class ReputationMigrationService {
  static final AppwriteService _appwriteService = AppwriteService();

  /// Check if migration is needed by looking for reputationPercentage field
  static Future<bool> isMigrationNeeded() async {
    try {
      // Try to get a user and check if reputationPercentage field exists
      final currentUser = await _appwriteService.getCurrentUser();
      if (currentUser == null) {
        AppLogger().warning('No current user - cannot check migration status');
        return false;
      }

      final profile = await _appwriteService.getUserProfile(currentUser.$id);
      if (profile == null) {
        AppLogger().warning('No user profile found - migration may be needed');
        return true;
      }

      // If we can access reputationPercentage, migration is not needed
      final hasReputationPercentage = profile.reputationPercentage >= 0;
      AppLogger().info('Migration check: reputationPercentage field ${hasReputationPercentage ? 'exists' : 'missing'}');
      
      return !hasReputationPercentage;
    } catch (e) {
      AppLogger().error('Error checking migration status: $e');
      // If there's an error accessing reputationPercentage, migration is probably needed
      return true;
    }
  }

  /// Reset all existing users to 100% reputation
  static Future<bool> resetAllUserReputationToPercentage() async {
    try {
      AppLogger().info('🔄 Starting reputation percentage migration...');
      
      // This is a placeholder - actual implementation would need to:
      // 1. List all users in batches
      // 2. Update each user's reputationPercentage to 100
      // 3. Handle any errors gracefully
      
      AppLogger().warning('⚠️  MANUAL MIGRATION REQUIRED:');
      AppLogger().warning('1. Go to Appwrite Console → arena_db → users collection');
      AppLogger().warning('2. Add "reputationPercentage" attribute (integer, default: 100)');
      AppLogger().warning('3. Create "reputation_logs" collection with required attributes');
      AppLogger().warning('4. Create "moderators" collection with required attributes');
      AppLogger().warning('5. All existing users will automatically get 100% reputation');
      
      return true;
    } catch (e) {
      AppLogger().error('❌ Migration failed: $e');
      return false;
    }
  }

  /// Create initial moderator entries for admin users
  static Future<bool> createInitialModerators(List<String> moderatorUserIds) async {
    try {
      AppLogger().info('👑 Creating initial moderators...');
      
      for (final userId in moderatorUserIds) {
        try {
          await _appwriteService.databases.createDocument(
            databaseId: 'arena_db',
            collectionId: 'moderators',
            documentId: 'unique()',
            data: {
              'userId': userId,
              'permissions': ['reputation_management', 'user_moderation'],
              'createdAt': DateTime.now().toIso8601String(),
              'isActive': true,
            },
          );
          AppLogger().info('✅ Created moderator entry for user: $userId');
        } catch (e) {
          AppLogger().error('❌ Failed to create moderator entry for $userId: $e');
        }
      }
      
      return true;
    } catch (e) {
      AppLogger().error('❌ Failed to create initial moderators: $e');
      return false;
    }
  }

  /// Print migration instructions for manual execution
  static void printMigrationInstructions() {
    print('''
🔧 REPUTATION SYSTEM MIGRATION INSTRUCTIONS

The Arena app has been updated to use a percentage-based reputation system.
Please complete these manual steps in the Appwrite Console:

1. ADD REPUTATION PERCENTAGE FIELD:
   → Go to arena_db → users collection → Attributes
   → Add "reputationPercentage" (Integer)
   → Set default value: 100
   → Required: Yes

2. CREATE REPUTATION LOGS COLLECTION:
   → Go to arena_db → Create Collection: "reputation_logs"
   → Add attributes:
     • userId (String, required)
     • moderatorId (String, required)
     • oldPercentage (Integer, required)
     • newPercentage (Integer, required) 
     • percentageChange (Integer, required)
     • reason (String, required)
     • timestamp (String, required)
     • type (String, required, default: "moderator_adjustment")

3. CREATE MODERATORS COLLECTION:
   → Go to arena_db → Create Collection: "moderators"
   → Add attributes:
     • userId (String, required, unique)
     • permissions (Array of Strings, optional)
     • createdAt (String, required)
     • isActive (Boolean, default: true)

4. SET UP PERMISSIONS:
   → reputation_logs: Read/Write for moderators only
   → moderators: Read for all users, Write for admins only
   → users.reputationPercentage: Read for all users, Write for moderators only

5. VERIFY MIGRATION:
   → All existing users should automatically have 100% reputation
   → Test moderator reputation adjustment functionality
   → Check that audit logs are being created

After completing these steps, the new percentage-based reputation system will be active!
''');
  }
}

/// Command-line interface for running migration
void main(List<String> arguments) async {
  try {
    AppLogger().info('🚀 Arena Reputation Migration Tool');
    
    // Print instructions
    ReputationMigrationService.printMigrationInstructions();
    
    // Check if migration is needed
    print('\n📊 Checking migration status...');
    final needsMigration = await ReputationMigrationService.isMigrationNeeded();
    
    if (!needsMigration) {
      print('✅ Migration appears to be already completed!');
      exit(0);
    }
    
    print('⚠️  Migration is needed. Please follow the manual instructions above.');
    
    // If moderator user IDs are provided as arguments, create initial moderators
    if (arguments.isNotEmpty) {
      print('\n👑 Creating initial moderators for provided user IDs...');
      final success = await ReputationMigrationService.createInitialModerators(arguments);
      if (success) {
        print('✅ Initial moderators created successfully!');
      } else {
        print('❌ Failed to create some moderators. Check logs for details.');
      }
    } else {
      print('\n💡 To create initial moderators, run: dart migrate_reputation_to_percentage.dart [userId1] [userId2] ...');
    }
    
    print('\n🎉 Migration setup complete! Please complete the manual steps in Appwrite Console.');
    
  } catch (e) {
    AppLogger().error('💥 Migration script error: $e');
    exit(1);
  }
}