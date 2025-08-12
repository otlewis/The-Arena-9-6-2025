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
      print('🔧 Starting coin system initialization...');
      print('ℹ️  Note: Database fields must exist in Appwrite Console first');
      
      // Try to initialize current user's coins
      await _initializeCurrentUserCoins();
      
      print('✅ Successfully initialized coin system!');
      
    } catch (e) {
      print('❌ Error initializing coin system: $e');
      
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
    print('');
    print('🛠️  MANUAL SETUP REQUIRED:');
    print('💡 Database schema fields must be added manually in Appwrite Console.');
    print('🌐 Go to: https://cloud.appwrite.io');
    print('📁 Navigate to: Your Project → Databases → arena_db → users collection');
    print('➕ Add these attributes:');
    print('   • reputation (Integer, default: 500, required: false)');
    print('   • coinBalance (Integer, default: 1000, required: false)');
    print('   • totalGiftsSent (Integer, default: 0, required: false)');
    print('   • totalGiftsReceived (Integer, default: 0, required: false)');
    print('');
    print('✨ After adding fields, run this debug tool again!');
    print('');
  }
  
  /// Initialize the current user's coin balance after fields are created
  static Future<void> _initializeCurrentUserCoins() async {
    try {
      print('💰 Initializing current user coins...');
      
      final currentUser = await _appwrite.getCurrentUser();
      if (currentUser == null) {
        print('❌ No current user found');
        return;
      }
      
      print('🔧 Setting initial coin balance for user: ${currentUser.$id}');
      
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
      
      print('✅ Successfully initialized coins for user ${currentUser.$id}');
      
    } catch (e) {
      print('❌ Error initializing user coins: $e');
      rethrow;
    }
  }
  
  /// Run the complete initialization process
  static Future<void> run() async {
    try {
      print('🚀 Starting complete Appwrite coin system setup...');
      await initializeCoinSystemFields();
      print('🎉 Coin system setup completed successfully!');
    } catch (e) {
      print('💥 Setup failed: $e');
      rethrow;
    }
  }
}