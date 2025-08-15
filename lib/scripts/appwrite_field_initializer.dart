import 'package:flutter/foundation.dart';
import '../services/appwrite_service.dart';

/// Script to programmatically initialize coin system data for users
/// Note: Database schema fields must be added manually in Appwrite Console
/// This script only initializes user data, not database schema
class AppwriteFieldInitializer {
  static final AppwriteService _appwrite = AppwriteService();
  
  /// Initialize coin system data for the current user
  /// Note: This assumes the database fields already exist in Appwrite Console
  static Future<void> initializeCoinSystemFields() async {
    try {
      debugPrint('🔧 Starting coin system initialization...');
      debugPrint('ℹ️  Note: Database fields must exist in Appwrite Console first');
      
      // Try to initialize current user's coins
      await _initializeCurrentUserCoins();
      
      debugPrint('✅ Successfully initialized coin system!');
      
    } catch (e) {
      debugPrint('❌ Error initializing coin system: $e');
      
      // Provide helpful instructions for missing fields
      if (e.toString().toLowerCase().contains('attribute') || 
          e.toString().toLowerCase().contains('column') ||
          e.toString().toLowerCase().contains('field')) {
        _showFieldSetupInstructions();
      }
      
      rethrow;
    }
  }
  
  /// Show instructions for manually setting up database fields
  static void _showFieldSetupInstructions() {
    debugPrint('');
    debugPrint('🛠️  MANUAL SETUP REQUIRED:');
    debugPrint('💡 Database schema fields must be added manually in Appwrite Console.');
    debugPrint('🌐 Go to: https://cloud.appwrite.io');
    debugPrint('📁 Navigate to: Your Project → Databases → arena_db → users collection');
    debugPrint('➕ Add these attributes:');
    debugPrint('   • reputation (Integer, default: 500, required: false)');
    debugPrint('   • coinBalance (Integer, default: 1000, required: false)');
    debugPrint('   • totalGiftsSent (Integer, default: 0, required: false)');
    debugPrint('   • totalGiftsReceived (Integer, default: 0, required: false)');
    debugPrint('');
    debugPrint('✨ After adding fields, run this debug tool again!');
    debugPrint('');
  }
  
  /// Initialize the current user's coin balance after fields are created
  static Future<void> _initializeCurrentUserCoins() async {
    try {
      debugPrint('💰 Initializing current user coins...');
      
      final currentUser = await _appwrite.getCurrentUser();
      if (currentUser == null) {
        debugPrint('❌ No current user found');
        return;
      }
      
      debugPrint('🔧 Setting initial coin balance for user: ${currentUser.$id}');
      
      // Wait a bit more for field creation to propagate
      await Future.delayed(const Duration(seconds: 2));
      
      // Update user document with initial coin values
      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'users',
        documentId: currentUser.$id,
        data: {
          'reputation': 500,
          'coinBalance': 1000,
          'totalGiftsSent': 0,
          'totalGiftsReceived': 0,
        },
      );
      
      debugPrint('✅ Successfully initialized coins for user ${currentUser.$id}');
      
    } catch (e) {
      debugPrint('❌ Error initializing user coins: $e');
      rethrow;
    }
  }
  
  /// Run the complete initialization process
  static Future<void> run() async {
    try {
      debugPrint('🚀 Starting complete Appwrite coin system setup...');
      await initializeCoinSystemFields();
      debugPrint('🎉 Coin system setup completed successfully!');
    } catch (e) {
      debugPrint('💥 Setup failed: $e');
      rethrow;
    }
  }
}