import 'package:flutter/material.dart';
import 'services/appwrite_service.dart';
import 'scripts/appwrite_field_initializer.dart';

/// Debug utility to initialize coin balance for users
/// This is a temporary solution for beta testing
class DebugCoinInitializer {
  static final AppwriteService _appwrite = AppwriteService();

  /// Initialize coins for the current user with automatic field creation
  static Future<void> initializeCurrentUserCoins() async {
    try {
      print('🚀 Starting complete coin system initialization...');
      
      // First, try to add missing fields to Appwrite
      await AppwriteFieldInitializer.run();
      
      print('✅ Coin system initialization completed successfully!');
      
    } catch (e) {
      print('❌ Error during initialization: $e');
      
      // Fallback: try manual coin setting if fields exist
      try {
        print('🔄 Attempting fallback coin initialization...');
        await _fallbackCoinInitialization();
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');
        rethrow;
      }
    }
  }

  /// Fallback method to set coins without field creation
  static Future<void> _fallbackCoinInitialization() async {
    final currentUser = await _appwrite.getCurrentUser();
    if (currentUser == null) {
      print('❌ No current user found');
      return;
    }

    print('🔧 Setting coins for user: ${currentUser.$id}');
    
    // Try to update with coins
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
    
    print('✅ Fallback coin initialization successful');
  }

  /// Widget that shows a debug button to initialize coins
  static Widget debugButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: () async {
          try {
            await initializeCurrentUserCoins();
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Coins initialized! Check your gift balance now.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ Error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.monetization_on),
        label: const Text('🔧 DEBUG: Initialize My Coins'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  /// Show a dialog with instructions for adding Appwrite fields
  static void showAppwriteInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🛠️ Appwrite Setup Required'),
        content: const SingleChildScrollView(
          child: Text(
            'To make the coin system work, you need to add these attributes to your "users" collection in Appwrite:\n\n'
            '1. Go to: Appwrite Console → Databases → arena_db → users\n\n'
            '2. Add these attributes:\n'
            '   • reputation (Integer, default: 500)\n'
            '   • coinBalance (Integer, default: 1000)\n'
            '   • totalGiftsSent (Integer, default: 0)\n'
            '   • totalGiftsReceived (Integer, default: 0)\n\n'
            '3. After adding fields, use the "Initialize My Coins" button\n\n'
            'This is a one-time setup for beta testing.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}