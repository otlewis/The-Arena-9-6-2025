import 'package:flutter/material.dart';
import '../core/logging/app_logger.dart';

/// Debug widget to update database schema for premium features
/// This widget should only be used during development/beta testing
class DebugDatabaseSchemaButton extends StatefulWidget {
  const DebugDatabaseSchemaButton({super.key});

  @override
  State<DebugDatabaseSchemaButton> createState() => _DebugDatabaseSchemaButtonState();
}

class _DebugDatabaseSchemaButtonState extends State<DebugDatabaseSchemaButton> {
  String _status = '';

  Future<void> _showManualSetupInstructions() async {
    setState(() {
      _status = '📋 Please follow manual setup instructions';
    });

    AppLogger().info('🧪 Manual database setup required - client SDK limitations');

    // Show detailed instructions dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Manual Database Setup Required'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Database schema creation is not available in client-side Appwrite SDK. Please set up manually via Appwrite Console:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text(
                  '1. Add to "users" collection:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text('• isPremium (Boolean, optional, default: false)'),
                const Text('• premiumType (String, size: 20, optional)'),
                const Text('• premiumExpiry (DateTime, optional)'),
                const Text('• isTestSubscription (Boolean, optional, default: false)'),
                const SizedBox(height: 12),
                const Text(
                  '2. Create "received_gifts" collection:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text('• giftId (String, size: 50, required)'),
                const Text('• senderId (String, size: 50, required)'),
                const Text('• senderName (String, size: 100, required)'),
                const Text('• receiverId (String, size: 50, required)'),
                const Text('• message (String, size: 200, optional)'),
                const Text('• isRead (Boolean, required, default: false)'),
                const SizedBox(height: 12),
                const Text(
                  '3. Create "mock_transactions" collection:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text('• transactionId (String, size: 100, required)'),
                const Text('• productId (String, size: 50, required)'),
                const Text('• userId (String, size: 50, required)'),
                const Text('• amount (Integer, required)'),
                const Text('• currency (String, size: 10, required)'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _copySetupInstructions();
              },
              child: const Text('Copy Instructions'),
            ),
          ],
        ),
      );
    }
  }

  void _copySetupInstructions() {
    // This would copy the setup instructions to clipboard
    // For now, just show a message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setup instructions logged to console'),
          backgroundColor: Colors.blue,
        ),
      );
    }
    
    AppLogger().info('''
🧪 PREMIUM FEATURES DATABASE SETUP INSTRUCTIONS:

1. Go to Appwrite Console → Your Project → Databases → arena_db

2. Update "users" collection:
   - Add isPremium (Boolean, optional, default: false)
   - Add premiumType (String, size: 20, optional)
   - Add premiumExpiry (DateTime, optional)
   - Add isTestSubscription (Boolean, optional, default: false)

3. Create "received_gifts" collection:
   - giftId (String, size: 50, required)
   - senderId (String, size: 50, required)
   - senderName (String, size: 100, required)
   - senderAvatar (String, size: 500, optional)
   - receiverId (String, size: 50, required)
   - receiverName (String, size: 100, required)
   - message (String, size: 200, optional)
   - roomId (String, size: 50, optional)
   - roomType (String, size: 30, optional)
   - roomName (String, size: 100, optional)
   - isRead (Boolean, required, default: false)
   - isNotified (Boolean, required, default: false)

4. Create "mock_transactions" collection:
   - transactionId (String, size: 100, required)
   - productId (String, size: 50, required)
   - userId (String, size: 50, required)
   - amount (Integer, required)
   - currency (String, size: 10, required)
   - status (String, size: 20, required)
   - testMode (Boolean, required, default: true)

5. Set appropriate permissions for all collections (read/write for users)

Once complete, premium features and gift system will work!
''');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🧪 DEBUG: Database Schema Updater',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Shows manual setup instructions for premium features database schema. Client SDK cannot create schema automatically.',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_status.isNotEmpty) ...[
            Text(
              _status,
              style: TextStyle(
                fontSize: 12,
                color: _status.startsWith('✅') ? Colors.green : (_status.startsWith('❌') ? Colors.red : Colors.blue),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          ElevatedButton(
            onPressed: _showManualSetupInstructions,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Show Setup Instructions'),
          ),
        ],
      ),
    );
  }
}