import 'dart:async';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../services/super_moderator_service.dart';
import '../models/super_moderator.dart';
import '../core/logging/app_logger.dart';

/// Script to grant Kritik Super Moderator privileges
/// This should be run once to set up the initial Super Moderator
class GrantKritikSuperModScript {
  static final AppwriteService _appwriteService = AppwriteService();
  static final SuperModeratorService _superModService = SuperModeratorService();
  static final AppLogger _logger = AppLogger();
  
  /// Grant Kritik Super Moderator status
  static Future<bool> grantSuperModStatus() async {
    try {
      _logger.info('🛡️ Starting Kritik Super Mod grant process...');
      
      // Initialize services
      await _superModService.initialize();
      
      // Find Kritik's user profile
      final users = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [
          Query.equal('username', 'Kritik'),
        ],
      );
      
      if (users.documents.isEmpty) {
        _logger.error('❌ User "Kritik" not found in database');
        return false;
      }
      
      final kritikUser = users.documents.first;
      final userId = kritikUser.$id;
      final username = kritikUser.data['username'] as String;
      final profileImageUrl = kritikUser.data['profileImageUrl'] as String?;
      
      // Check if Kritik is already a Super Moderator
      if (_superModService.isSuperModerator(userId)) {
        _logger.info('✅ Kritik is already a Super Moderator');
        return true;
      }
      
      // Grant Super Moderator status with all permissions
      final superMod = await _superModService.grantSuperModeratorStatus(
        userId: userId,
        username: username,
        grantedBy: 'system',
        profileImageUrl: profileImageUrl,
        customPermissions: SuperModPermissions.allPermissions,
      );
      
      if (superMod != null) {
        _logger.info('🎖️ Successfully granted Super Moderator status to Kritik');
        _logger.info('   User ID: $userId');
        _logger.info('   Username: $username');
        _logger.info('   Permissions: ${superMod.permissions.join(', ')}');
        return true;
      } else {
        _logger.error('❌ Failed to grant Super Moderator status to Kritik');
        return false;
      }
      
    } catch (e, stackTrace) {
      _logger.error('❌ Error granting Super Moderator status: $e');
      _logger.error('Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// Verify Kritik's Super Moderator status
  static Future<bool> verifySuperModStatus() async {
    try {
      // Initialize services
      await _superModService.initialize();
      
      // Find Kritik's user profile
      final users = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'users',
        queries: [
          Query.equal('username', 'Kritik'),
        ],
      );
      
      if (users.documents.isEmpty) {
        _logger.error('❌ User "Kritik" not found');
        return false;
      }
      
      final kritikUser = users.documents.first;
      final userId = kritikUser.$id;
      
      // Check Super Moderator status
      final isSuperMod = _superModService.isSuperModerator(userId);
      
      if (isSuperMod) {
        _logger.info('✅ Kritik has Super Moderator privileges');
        
        // Check specific permissions
        for (final permission in SuperModPermissions.allPermissions) {
          final hasPermission = _superModService.hasPermission(userId, permission);
          _logger.info('   $permission: ${hasPermission ? '✅' : '❌'}');
        }
        
        return true;
      } else {
        _logger.info('❌ Kritik does not have Super Moderator privileges');
        return false;
      }
      
    } catch (e) {
      _logger.error('❌ Error verifying Super Moderator status: $e');
      return false;
    }
  }
  
  /// Create the required Appwrite collections if they don't exist
  static Future<void> ensureCollectionsExist() async {
    try {
      _logger.info('📊 Ensuring required Appwrite collections exist...');
      
      // List of collections that need to exist
      final requiredCollections = [
        'super_moderators',
        'room_bans',
        'room_events',
        'moderation_actions',
      ];
      
      for (final collectionId in requiredCollections) {
        try {
          await _appwriteService.databases.listDocuments(
            databaseId: 'arena_db',
            collectionId: collectionId,
            queries: [Query.limit(1)],
          );
          _logger.info('✅ Collection "$collectionId" exists');
        } catch (e) {
          _logger.info('⚠️ Collection "$collectionId" does not exist - it should be created manually');
          // Note: We can't create collections programmatically, they need to be created in Appwrite Console
        }
      }
      
    } catch (e) {
      _logger.error('❌ Error checking collections: $e');
    }
  }
}

/// Helper function to run the script
Future<void> runKritikSuperModScript() async {
  final logger = AppLogger();
  
  try {
    logger.info('🚀 Starting Kritik Super Moderator setup script...');
    
    // Ensure collections exist (informational check)
    await GrantKritikSuperModScript.ensureCollectionsExist();
    
    // Grant Super Moderator status
    final success = await GrantKritikSuperModScript.grantSuperModStatus();
    
    if (success) {
      // Verify the status
      await GrantKritikSuperModScript.verifySuperModStatus();
      logger.info('🎉 Kritik Super Moderator setup completed successfully!');
    } else {
      logger.error('💥 Failed to set up Kritik as Super Moderator');
    }
    
  } catch (e) {
    logger.error('💥 Script execution failed: $e');
  }
}